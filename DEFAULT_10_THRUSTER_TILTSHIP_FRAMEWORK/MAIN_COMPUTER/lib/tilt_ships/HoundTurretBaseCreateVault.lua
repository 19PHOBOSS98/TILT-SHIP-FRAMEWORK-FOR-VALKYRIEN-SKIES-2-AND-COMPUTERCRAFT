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


local HoundTurretBaseCreateVault = HoundTurretBase:subclass()


--overridden functions--
function HoundTurretBaseCreateVault:setShipFrameClass(configs) --override this to set ShipFrame Template
	self.ShipFrame = TenThrusterTemplateVerticalCompact(configs)
end

function HoundTurretBaseCreateVault:alternateFire(step)
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
	
	local vault = peripheral.find("create:item_vault")
	local cannon_mounts = {peripheral.find("createbigcannons:cannon_mount")}
	
	local cannon_mount_max_ammo_capacity = 5
	local cannon_input_slot = 2
	local cannon_output_slot = 1
	
	local vault_name = peripheral.getName(vault)
	local cannon_mount_names = {}
	for k,v in pairs(cannon_mounts) do
		table.insert(cannon_mount_names,peripheral.getName(v))
	end
	
	function emptyCannonMounts(to_vault_index)
		for i,cannon_name in ipairs(cannon_mount_names) do
			vault.pullItems(cannon_name,cannon_output_slot,64,to_vault_index)
		end
		
	end
	
	function fillCannonMounts(from_vault_index)
		for i,cannon_name in ipairs(cannon_mount_names) do
			vault.pushItems(cannon_name,from_vault_index,cannon_mount_max_ammo_capacity,cannon_input_slot)
		end
	end
	
	--leave the last vault slot empty when repleneshing ammo. It needs the space for spent cartidges
	
	local vault_max_slots = vault.size()
	local spent_shell_index = vault_max_slots
	local ready_shell_index = vault_max_slots-1
	
	local threads = {
		function()--synchronize guns
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
		
		function()--feed ammo
			while true do
				for i=1,2000,1 do
					local ready_index_details = vault.getItemDetail(ready_shell_index)
					if (ready_index_details) then
						if (ready_index_details.displayName ~= "Autocannon Cartridge") then
							ready_shell_index = ready_shell_index > 1 and ready_shell_index - 1 or vault_max_slots-1
						else
							break
						end
					else
						ready_shell_index = ready_shell_index > 1 and ready_shell_index - 1 or vault_max_slots-1
					end
				end
				fillCannonMounts(ready_shell_index)
				os.sleep(0.05)
			end
		end,
		
		function()--remove spent ammo
			while true do
				for i=1,2000,1 do
					local spent_index_details = vault.getItemDetail(spent_shell_index)
					if (spent_index_details) then
						if (spent_index_details.displayName == "Empty Autocannon Cartridge") then
							if (spent_index_details.count >= vault.getItemLimit(spent_shell_index)) then
								spent_shell_index = spent_shell_index > 1 and spent_shell_index - 1 or vault_max_slots
							else
								break
							end
						else
							spent_shell_index = spent_shell_index > 1 and spent_shell_index - 1 or vault_max_slots
						end
					else
						break
					end
				end
				emptyCannonMounts(spent_shell_index)
				os.sleep(0.05)
			end
		end,
	}
	return threads
end

function HoundTurretBaseCreateVault:init(instance_configs)
	local configs = instance_configs
	
	configs.ship_constants_config = configs.ship_constants_config or {}
	
	
	--REMOVE WHEN VS2-COMPUTERS UPDATE RELEASES--
	--unrotated inertia tensors--
	
	--bare template--
	--hound_4b_vault_it.nbt--
	configs.ship_constants_config.LOCAL_INERTIA_TENSOR = configs.ship_constants_config.LOCAL_INERTIA_TENSOR or
	{
	x=vector.new(79934.05745890312,1.1368683772161603E-13,-1780.0),
	y=vector.new(1.1368683772161603E-13,18080.0,0.0),
	z=vector.new(-1780.0,0.0,73334.05745890313)
	}
	configs.ship_constants_config.LOCAL_INV_INERTIA_TENSOR = configs.ship_constants_config.LOCAL_INV_INERTIA_TENSOR or
	{
	x=vector.new(1.2517077607400543E-5,-7.87072439547245E-23,3.0382061095772646E-7),
	y=vector.new(-7.870724395472455E-23,5.5309734513274336E-5,-1.9104206025682108E-24),
	z=vector.new(3.0382061095772657E-7,-1.9104206025682133E-24,1.3643603468255035E-5)
	}
	--bare template--	
	--unrotated inertia tensors--
	--REMOVE WHEN VS2-COMPUTERS UPDATE RELEASES--

	HoundTurretBaseCreateVault.superClass.init(self,configs)
end
--overridden functions--

function HoundTurretBaseCreateVault:overrideShipFrameCustomFlightLoopBehavior()
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

return HoundTurretBaseCreateVault