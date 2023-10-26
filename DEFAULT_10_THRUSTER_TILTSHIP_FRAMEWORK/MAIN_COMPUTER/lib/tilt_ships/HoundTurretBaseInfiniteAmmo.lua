local quaternion = require "lib.quaternions"
local utilities = require "lib.utilities"
local targeting_utilities = require "lib.targeting_utilities"
local player_spatial_utilities = require "lib.player_spatial_utilities"
local flight_utilities = require "lib.flight_utilities"
local list_manager = require "lib.list_manager"

local HoundTurretBase = require "lib.tilt_ships.HoundTurretBase"
local TenThrusterTemplateVerticalCompact = require "lib.tilt_ships.TenThrusterTemplateVerticalCompact"

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
local IndexedListScroller = list_manager.IndexedListScroller


local HoundTurretBaseInfiniteAmmo = HoundTurretBase:subclass()


--overridden functions--
function HoundTurretBaseInfiniteAmmo:setShipFrameClass(configs) --override this to set ShipFrame Template
	self.ShipFrame = TenThrusterTemplateVerticalCompact(configs)
end

function HoundTurretBaseInfiniteAmmo:alternateFire(step)
	local seq_1 = step==0
	local seq_2 = step==1
	--{hub_index, redstoneIntegrator_index, side_index}
	self:activateGun({"front",1,3},seq_1)
	self:activateGun({"front",2,3},seq_1)
	
	self:activateGun({"front",1,4},seq_2)
	self:activateGun({"front",2,4},seq_2)

end

function HoundTurretBase:CustomThreads()
	local htb = self
	local threads = {
		function()
			sync_step = 0
			while self.ShipFrame.run_firmware do
				
				if (htb.activate_weapons) then
					htb:alternateFire(sync_step)
					
					sync_step = math.fmod(sync_step+1,2)
				else
					htb:reset_guns()
				end
				os.sleep(htb.GUNS_COOLDOWN_DELAY)
			end
			htb:reset_guns()
		end,
	}
	return threads
end

function HoundTurretBaseInfiniteAmmo:init(instance_configs)
	local configs = instance_configs
	
	configs.ship_constants_config = configs.ship_constants_config or {}
	
	
	--REMOVE WHEN VS2-COMPUTERS UPDATE RELEASES--
	--unrotated inertia tensors--
	
	--bare template--
	--hound_4b_inf_it.nbt--
	configs.ship_constants_config.LOCAL_INERTIA_TENSOR = configs.ship_constants_config.LOCAL_INERTIA_TENSOR or
	{
	x=vector.new(24918.76912497852,5.6843418860808015E-14,-299.9999999999999),
	y=vector.new(5.6843418860808015E-14,13279.999999999998,-2.8421709430404007E-14),
	z=vector.new(-299.9999999999999,-2.8421709430404007E-14,18638.769124978513)
	}
	configs.ship_constants_config.LOCAL_INV_INERTIA_TENSOR = configs.ship_constants_config.LOCAL_INV_INERTIA_TENSOR or
	{
	x=vector.new(4.013817086883722E-5,-1.704238859222406E-22,6.460432649768677E-7),
	y=vector.new(-1.704238859222405E-22,7.530120481927712E-5,1.1208153195891727E-22),
	z=vector.new(6.460432649768682E-7,1.120815319589173E-22,5.3662009882352995E-5)
	}
	--bare template--
	
	--steampunk skin, paste in firmwareScript.lua--
	--[[
	LOCAL_INERTIA_TENSOR = 
	{
	x=vector.new(363679.29381836695,9.094947017729282E-13,0.0),
	y=vector.new(9.094947017729282E-13,421000.0,1.0231815394945443E-12),
	z=vector.new(0.0,1.0231815394945443E-12,358679.29381836683)
	},
	LOCAL_INV_INERTIA_TENSOR = 
	{
	x=vector.new(2.7496753788227273E-6,-5.9401785953319215E-24,1.694516852462093E-41),
	y=vector.new(-5.940178595331924E-24,2.375296912114014E-6,-6.775857968885637E-24),
	z=vector.new(1.6945168524620946E-41,-6.775857968885637E-24,2.788005935202923E-6)
	}
	]]--
	--steampunk skin, paste in firmwareScript.lua--
	
	--unrotated inertia tensors--
	--REMOVE WHEN VS2-COMPUTERS UPDATE RELEASES--

	HoundTurretBaseInfiniteAmmo.superClass.init(self,configs)
end
--overridden functions--

function HoundTurretBaseInfiniteAmmo:overrideShipFrameCustomFlightLoopBehavior()
	local htb = self
	function self.ShipFrame:customFlightLoopBehavior()
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
				self:debugProbe({
				aim_ex=self.aimTargeting:isUsingExternalRadar(),
				orb_ex=self.orbitTargeting:isUsingExternalRadar()
				})
				--Aiming
				local bullet_convergence_point = vector.new(0,1,0)
				if (self.aimTargeting:isUsingExternalRadar()) then
					bullet_convergence_point = getTargetAimPos(target_aim_position,target_aim_velocity,self.ship_global_position,self.ship_global_velocity,htb.bullet_velocity_squared)
					htb.activate_weapons = (self.rotation_error:length() < 10) and self.rc_variables.weapons_free
				else
					if (self:getAutoAim()) then
						bullet_convergence_point = getTargetAimPos(target_aim_position,target_aim_velocity,self.ship_global_position,self.ship_global_velocity,htb.bullet_velocity_squared)
						
						--only fire when aim is close enough and if user says "fire"
						--self:debugProbe({rotation_error=self.rotation_error:length()})
						htb.activate_weapons = (self.rotation_error:length() < 10) and self.rc_variables.weapons_free  
						
						
					else	
					--Manual Aiming
						
						local aim_target_mode = self:getTargetMode(true)
						local orbit_target_mode = self:getTargetMode(false)
						
						local aim_z = vector.new()
						if (aim_target_mode == orbit_target_mode) then
							aim_z = target_orbit_orientation:localPositiveZ()
							bullet_convergence_point = target_orbit_position:add(aim_z:mul(htb.bulletRange:get()))
						else
							aim_z = target_aim_orientation:localPositiveZ()
							if (self.rc_variables.player_mounting_ship) then
								aim_z = target_orbit_orientation:rotateVector3(aim_z)
							end
							bullet_convergence_point = target_aim_position:add(aim_z:mul(htb.bulletRange:get()))
						end
						
						htb.activate_weapons = self.rc_variables.weapons_free
						
					end
				end
				
				
				
				local aiming_vector = bullet_convergence_point:sub(self.ship_global_position):normalize()
				
				self.target_rotation = quaternion.fromToRotation(self.target_rotation:localPositiveY(),aiming_vector)*self.target_rotation
				
				--positioning

				if (self.rc_variables.dynamic_positioning_mode) then
					if (self.rc_variables.hunt_mode) then
						self.target_global_position = adjustOrbitRadiusPosition(self.target_global_position,target_aim_position,25)
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


				--self:debugProbe({})
				
			end
		else
			htb:reset_guns()
		end
		
	end

end

return HoundTurretBaseInfiniteAmmo