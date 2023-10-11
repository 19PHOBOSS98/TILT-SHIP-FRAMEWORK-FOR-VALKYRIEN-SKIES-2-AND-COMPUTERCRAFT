local quaternion = require "lib.quaternions"
local utilities = require "lib.utilities"
local targeting_utilities = require "lib.targeting_utilities"
local player_spatial_utilities = require "lib.player_spatial_utilities"
local flight_utilities = require "lib.flight_utilities"
local list_manager = require "lib.list_manager"

local TenThrusterTemplateHorizontalCompact = require "lib.tilt_ships.TenThrusterTemplateHorizontalCompact"

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
local NonBlockingCooldownTimer = utilities.NonBlockingCooldownTimer
local IndexedListScroller = list_manager.IndexedListScroller


local HoundTurretDroneCompact = TenThrusterTemplateHorizontalCompact:subclass()

--overridden functions--
function HoundTurretDroneCompact:getCustomSettings()
	return {
		hunt_mode = self.rc_variables.hunt_mode,
		bullet_range = self:getBulletRange(),
	}
end

function HoundTurretDroneCompact:customRCProtocols(msg)
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



HoundTurretDroneCompact.hub1 = peripheral.find("peripheral_hub",function(name,object) return name == "top" end)


HoundTurretDroneCompact.gun_controllers = {peripheral.find("redstoneIntegrator",
											function(name,object) 
												for i,list_name in ipairs(HoundTurretDroneCompact.hub1.getNamesRemote()) do
													if (list_name == name) then
														return true
													end
												end
												return false
											end)}

HoundTurretDroneCompact.gun_component_map = {
		"south",
		"east",
		"north",
		"west"
}

function HoundTurretDroneCompact:reset_guns()
	self.gun_controllers[1].setOutput("south",false)
	self.gun_controllers[1].setOutput("east",false)
	self.gun_controllers[1].setOutput("north",false)
	self.gun_controllers[1].setOutput("west",false)
end

function HoundTurretDroneCompact:activateGun(gun_index,toggle)
	self.gun_controllers[gun_index[1]]
		.setOutput(
			self.gun_component_map[gun_index[2]],toggle)

end

function HoundTurretDroneCompact:alternateFire(toggle)
	self:activateGun({1,1},toggle)
	self:activateGun({1,2},not toggle)
	self:activateGun({1,3},toggle)
	self:activateGun({1,4},not toggle)
end

HoundTurretDroneCompact.GUNS_COOLDOWN_DELAY = 1 --in seconds -- 5 shots per burst
HoundTurretDroneCompact.activate_weapons = false

function HoundTurretDroneCompact:customThread()
	toggle_fire = false
	
	while self.run_firmware do
		if (self.activate_weapons) then
			self:alternateFire(toggle_fire)
			toggle_fire = not toggle_fire
		else
			self:reset_guns()
		end
		os.sleep(self.GUNS_COOLDOWN_DELAY)
	end
	self:reset_guns()
end

function HoundTurretDroneCompact:customPreFlightLoopBehavior()
	local bullet_velocity = self.AUTOCANNON_BARREL_COUNT/0.05
	self.bullet_velocity_squared = bullet_velocity*bullet_velocity
	self:setHuntMode(self.rc_variables.hunt_mode)	--forces auto_aim to activate if hunt_mode is set to true on initialization
													--toggle it on runtime as you wish
end



function HoundTurretDroneCompact:customFlightLoopBehavior()
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
			local target_aim = self.aimTargeting:getTargetSpatials()
			local target_orbit = self.orbitTargeting:getTargetSpatials()
			
			local target_aim_position = target_aim.position
			local target_aim_velocity = target_aim.velocity
			local target_aim_orientation = target_aim.orientation
			
			local target_orbit_position = target_orbit.position
			local target_orbit_orientation = target_orbit.orientation
			
			--Aiming
			local bullet_convergence_point = vector.new(0,1,0)
			if (self:getAutoAim()) then
				bullet_convergence_point = getTargetAimPos(target_aim_position,target_aim_velocity,self.ship_global_position,self.ship_global_velocity,self.bullet_velocity_squared)
				
				--only fire when aim is close enough and if user says "fire"
				self.activate_weapons = (self.rotation_error:length() < 0.5) and self.rc_variables.weapons_free  
				
				
			else	
			--Manual Aiming
				
				local aim_target_mode = self:getTargetMode(true)
				local orbit_target_mode = self:getTargetMode(false)
				
				local aim_z = vector.new()
				if (aim_target_mode == orbit_target_mode) then
					aim_z = target_orbit_orientation:localPositiveZ()
					bullet_convergence_point = target_orbit_position:add(aim_z:mul(self.bulletRange:get()))
				else
					aim_z = target_aim_orientation:localPositiveZ()
					if (self.rc_variables.player_mounting_ship) then
						aim_z = target_orbit_orientation:rotateVector3(aim_z)
					end
					bullet_convergence_point = target_aim_position:add(aim_z:mul(self.bulletRange:get()))
				end
				
				self.activate_weapons = self.rc_variables.weapons_free
				
			end
			
			
			
			local aiming_vector = bullet_convergence_point:sub(self.ship_global_position)
			
			
			local gun_aim_vector = quaternion.fromRotation(self.target_rotation:localPositiveZ(), -45):rotateVector3(self.target_rotation:localPositiveY())
			
			self.target_rotation = quaternion.fromToRotation(gun_aim_vector,aiming_vector:normalize())*self.target_rotation
			
						--positioning
			if (self.rc_variables.dynamic_positioning_mode) then
				if (self.rc_variables.hunt_mode) then
					self.target_global_position = adjustOrbitRadiusPosition(self.target_global_position,target_aim_position,15)
					--[[
					--position the drone behind target player's line of sight--
					local formation_position = aim_target.orientation:rotateVector3(vector.new(0,0,15))
					target_global_position = formation_position:add(aim_target.position)
					]]--
					
				else --guard_mode
					local formation_position = target_orbit_orientation:rotateVector3(self.rc_variables.orbit_offset)
					--self:debugProbe({target_orbit_position=target_orbit_position})
					self.target_global_position = formation_position:add(target_orbit_position)
				end
				
			end

			
			
		end
	else
		self:reset_guns()
	end
	
end

function HoundTurretDroneCompact:onResetRedstone()
	self:reset_guns()
end

function HoundTurretDroneCompact:init(instance_configs)
	local configs = instance_configs
	
	configs.ship_constants_config = configs.ship_constants_config or {}
	
	configs.ship_constants_config.DRONE_TYPE = "TURRET"
	
	--REMOVE WHEN VS2-COMPUTERS UPDATE RELEASES--
	--unrotated inertia tensors--
	configs.ship_constants_config.LOCAL_INERTIA_TENSOR = configs.ship_constants_config.LOCAL_INERTIA_TENSOR or
	{
	x=vector.new(146782.30998366486,-6.821210263296962E-13,0.0),
	y=vector.new(-6.821210263296962E-13,100360.0,0.0),
	z=vector.new(0.0,0.0,142982.30998366483)
	}
	
	configs.ship_constants_config.LOCAL_INV_INERTIA_TENSOR = configs.ship_constants_config.LOCAL_INV_INERTIA_TENSOR or
	{
	x=vector.new(6.812810073034606E-6,4.6304912307768623E-23,-0.0),
	y=vector.new(4.630491230776861E-23,9.964129135113591E-6,-0.0),
	z=vector.new(-0.0,-0.0,6.993872179811937E-6)
	}

	--unrotated inertia tensors--
	--REMOVE WHEN VS2-COMPUTERS UPDATE RELEASES--
	
	configs.ship_constants_config.MOD_CONFIGURED_THRUSTER_SPEED = configs.ship_constants_config.MOD_CONFIGURED_THRUSTER_SPEED or 10000
		
	configs.ship_constants_config.THRUSTER_TIER = configs.ship_constants_config.THRUSTER_TIER or 5
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
	HoundTurretDroneCompact.superClass.init(self,configs)

end
--overridden functions--


--custom--
function HoundTurretDroneCompact:initCustom(custom_config)
	self.AUTOCANNON_BARREL_COUNT = custom_config.AUTOCANNON_BARREL_COUNT
	
	self.bulletRange = IntegerScroller(100,15,300)
	function HoundTurretDroneCompact:changeBulletRange(delta)
		self.bulletRange:set(delta)
	end
	function HoundTurretDroneCompact:getBulletRange()
		self.bulletRange:get()
	end
	function HoundTurretDroneCompact:overrideBulletRange(new_value)
		self.bulletRange:override(new_value)
	end
end

function HoundTurretDroneCompact:setWeaponsFree(mode)
	self.rc_variables.weapons_free = mode
end

function HoundTurretDroneCompact:setHuntMode(mode)
	self.rc_variables.hunt_mode = mode
	self:setAutoAim(self:getAutoAim())
end
--custom--

return HoundTurretDroneCompact