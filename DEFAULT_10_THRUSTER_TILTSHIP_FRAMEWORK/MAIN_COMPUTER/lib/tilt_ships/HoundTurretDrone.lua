local TenThrusterTemplateVertical = require "lib.tilt_ships.TenThrusterTemplateVertical"

os.loadAPI("lib/quaternions.lua")
os.loadAPI("lib/pidcontrollers.lua")
os.loadAPI("lib/targeting_utilities.lua")
os.loadAPI("lib/player_spatial_utilities.lua")
os.loadAPI("lib/flight_utilities.lua")
os.loadAPI("lib/utilities.lua")
os.loadAPI("lib/list_manager.lua")


local sqrt = math.sqrt
local abs = math.abs
local max = math.max
local min = math.min
local mod = math.fmod
local cos = math.cos
local sin = math.sin
local acos = math.acos
local pi = math.pi
local clamp = utilities.clamp
local sign = utilities.sign
local quaternion = quaternions.Quaternion--want to learn more about quaternions? here's a simple tutorial video by sociamix that should get you started: https://youtu.be/1yoFjjJRnLY
local quadraticSolver = utilities.quadraticSolver
local getTargetAimPos = targeting_utilities.getTargetAimPos
local getQuaternionRotationError = flight_utilities.getQuaternionRotationError
local getLocalPositionError = flight_utilities.getLocalPositionError
local adjustOrbitRadiusPosition = flight_utilities.adjustOrbitRadiusPosition
local getPlayerLookVector = player_spatial_utilities.getPlayerLookVector
local getPlayerHeadOrientation = player_spatial_utilities.getPlayerHeadOrientation
local rotateVectorWithPlayerHead = player_spatial_utilities.rotateVectorWithPlayerHead
local PlayerVelocityCalculator = player_spatial_utilities.PlayerVelocityCalculator
local RadarSystems = targeting_utilities.RadarSystems
local TargetingSystem = targeting_utilities.TargetingSystem
local IntegerScroller = utilities.IntegerScroller
local IndexedListScroller = list_manager.IndexedListScroller


local HoundTurretDrone = TenThrusterTemplateVertical:subclass()

--overridden functions--
function HoundTurretDrone:getCustomSettings()
	return {
		hunt_mode = self.rc_variables.hunt_mode,
		bullet_range = self:getBulletRange(),
	}
end

function HoundTurretDrone:customRCProtocols(msg)
	self:debugProbe({msg=msg})
	local command = msg.cmd
	command = command and tonumber(command) or command
	case =
	{
	["override_bullet_range"] = function (arguments)
		self:overrideBulletRange(arguments.args)
	end,
	["scroll_bullet_range"] = function (arguments)
		self:changeBulletRange(arguments.args)
	end,
	["hunt_mode"] = function (args)
		self:setHuntMode(args)
	end,
	["burst_fire"] = function (arguments)
		if (arguments.delay>0)then
			os.sleep(arguments.delay)
			self:setWeaponsFree(arguments.mode)
			return
		end
		self:setWeaponsFree(arguments.mode)
	end,
	["weapons_free"] = function (arguments)
		self:setWeaponsFree(arguments.args)
	end,
	["HUSH"] = function (args) --kill command
		self:resetRedstone()
		print("reseting redstone")
		self.run_firmware = false
	end,
	 default = function ( )
		print(textutils.serialize(command)) 
		print("customProtocols: default case executed")   
	end,
	}
	if case[command] then
	 case[command](msg.args)
	else
	 case["default"]()
	end
end

function HoundTurretDrone:customPreFlightLoopBehavior()
	local bullet_velocity = self.AUTOCANNON_BARREL_COUNT/0.05
	self.bullet_velocity_squared = bullet_velocity*bullet_velocity
	self:setHuntMode(self.rc_variables.hunt_mode)	--forces auto_aim to activate if hunt_mode is set to true on initialization
													--toggle it on runtime as you wish
	self.count = 0
	self.prev_time = os.clock()
	self.cooldown_time = 1 -- 5 shots per burst
end

function HoundTurretDrone:customFlightLoopBehavior()
	--[[
	useful variables to work with:
		self.target_global_position
		self.target_rotation
		self.rotation_error
		self.position_error
	]]--
	
	--term.clear()
	--term.setCursorPos(1,1)
	
	if(not self.radars.targeted_players_undetected) then
		if (self.rc_variables.run_mode) then
			local target_aim = self.aimTargeting.target.target_spatial
			local target_orbit = self.orbitTargeting.target.target_spatial
			self:debugProbe({rot_err=self.rotation_error,z=self.target_rotation:localPositiveZ()})
			--positioning
			if (self.rc_variables.dynamic_positioning_mode) then
				if (self.rc_variables.hunt_mode) then
					self.target_global_position = adjustOrbitRadiusPosition(self.target_global_position,target_aim.position,15)
					--[[
					--position the drone behind target player's line of sight--
					local formation_position = aim_target.orientation:rotateVector3(vector.new(0,0,15))
					target_global_position = formation_position:add(aim_target.position)
					]]--
					
				else --guard_mode
					local formation_position = target_orbit.orientation:rotateVector3(self.rc_variables.orbit_offset)
					self.target_global_position = formation_position:add(target_orbit.position)
				end
				
			end

			--Aiming
			local bullet_convergence_point = vector.new(0,1,0)
			if (self:getAutoAim()) then
				bullet_convergence_point = getTargetAimPos(target_aim.position,target_aim.velocity,self.ship_global_position,self.ship_global_velocity,self.bullet_velocity_squared)
				if (self.rotation_error:length() < 0.5) then --only fire when aim is close enough
					self:fire_guns(self.rc_variables.weapons_free)
				else
					self:fire_guns(false)
				end
			else	--Manual Aiming
				
				--burst fire
				local current_time = os.clock()
				if (self.rc_variables.weapons_free) then
					self.count = self.count+(current_time - self.prev_time)
					self.count = mod(self.count,self.cooldown_time*2)
				end
				local not_on_cooldown = self.count < self.cooldown_time
				self:fire_guns(not_on_cooldown and self.rc_variables.weapons_free)
				self.prev_time = current_time
			
				local aim_z = target_aim.orientation:localPositiveZ()
				aim_target_mode = self:getTargetMode(true)
				orbit_target_mode = self:getTargetMode(false)
				if (aim_target_mode == "PLAYER" and orbit_target_mode == "SHIP" and self.rc_variables.player_mounting_ship) then
					aim_z = target_orbit.orientation:rotateVector3(aim_z)
				end
				bullet_convergence_point = target_aim.position:add(aim_z:mul(self.bulletRange:get()))
				
				
			end
			
			local aiming_vector = bullet_convergence_point:sub(self.ship_global_position)
			
			self.target_rotation = quaternion.fromToRotation(self.target_rotation:localPositiveY(),aiming_vector:normalize())*self.target_rotation
		end
	else
		self:fire_guns(false)
	end
	
end

function HoundTurretDrone:onResetRedstone()
	self:fire_guns(false)
end

function HoundTurretDrone:init(instance_configs)
	local configs = instance_configs
	
	configs.ship_constants_config = configs.ship_constants_config or {}
	
	configs.ship_constants_config.DRONE_TYPE = "TURRET"
	
	--REMOVE WHEN VS2-COMPUTERS UPDATE RELEASES--
	--unrotated inertia tensors--
	configs.ship_constants_config.LOCAL_INERTIA_TENSOR = configs.ship_constants_config.LOCAL_INERTIA_TENSOR or
	{
		x=vector.new(78626.56144552086,0.0,0.0),
		y=vector.new(0.0,38960.0,0.0),
		z=vector.new(0.0,0.0,78626.56144552086)
	}
	
	configs.ship_constants_config.LOCAL_INV_INERTIA_TENSOR = configs.ship_constants_config.LOCAL_INV_INERTIA_TENSOR or
	{
		x=vector.new(1.271834837509567E-5,-0.0,-0.0),
		y=vector.new(-0.0,2.566735112936345E-5,-0.0),
		z=vector.new(-0.0,-0.0,1.271834837509567E-5)
	}
	--unrotated inertia tensors--
	--REMOVE WHEN VS2-COMPUTERS UPDATE RELEASES--
	
	configs.ship_constants_config.MOD_CONFIGURED_THRUSTER_SPEED = configs.ship_constants_config.MOD_CONFIGURED_THRUSTER_SPEED or 10000
		
	configs.ship_constants_config.THRUSTER_TIER = configs.ship_constants_config.THRUSTER_TIER or 4
		--these values are specific for the 10-thruster template--

	configs.ship_constants_config.PID_SETTINGS = configs.ship_constants_config.PID_SETTINGS or
	{
		POS = {
			P = 5,
			I = 0,
			D = 4
		},
		ROT = {
			X = {
				P = 0.15,
				I = 0.08,
				D = 0.15
			},
			Y = {
				P = 0.15,
				I = 0.08,
				D = 0.15
			},
			Z = {
				P = 0.15,
				I = 0.08,
				D = 0.15
			}
		}
	}
	
	configs.radar_config = configs.radar_config or {}
	
	configs.radar_config.player_radar_box_size = configs.radar_config.player_radar_box_size or 50
	configs.radar_config.ship_radar_range = configs.radar_config.ship_radar_range or 500
	
	configs.rc_variables = configs.rc_variables or {}
	
	configs.rc_variables.orbit_offset = configs.rc_variables.orbit_offset or vector.new(0,0,0)
	configs.rc_variables.run_mode = false
	configs.rc_variables.dynamic_positioning_mode = false
	configs.rc_variables.player_mounting_ship = false
	configs.rc_variables.weapons_free = false--activate to fire cannons
	configs.rc_variables.hunt_mode = false--activate for the drone to follow what it's aiming at, force-activates auto_aim if set to true
	
	custom_config = {
		AUTOCANNON_BARREL_COUNT = 6,
	}
	self:initCustom(custom_config)
	HoundTurretDrone.superClass.init(self,configs)

end
--overridden functions--


--custom--
function HoundTurretDrone:initCustom(custom_config)
	self.AUTOCANNON_BARREL_COUNT = custom_config.AUTOCANNON_BARREL_COUNT
	
	self.bulletRange = IntegerScroller(100,15,300)
	function HoundTurretDrone:changeBulletRange(delta)
		self.bulletRange:set(delta)
	end
	function HoundTurretDrone:getBulletRange()
		self.bulletRange:get()
	end
	function HoundTurretDrone:overrideBulletRange(new_value)
		self.bulletRange:override(new_value)
	end
end

function HoundTurretDrone:setWeaponsFree(mode)
	self.rc_variables.weapons_free = mode
end

function HoundTurretDrone:fire_guns(toggle)
	--self:debugProbe({toggle=toggle})
	redstone.setOutput("bottom",toggle)
end

function HoundTurretDrone:setHuntMode(mode)
	self.rc_variables.hunt_mode = mode
	self:setAutoAim(self:getAutoAim())
end
--custom--

return HoundTurretDrone