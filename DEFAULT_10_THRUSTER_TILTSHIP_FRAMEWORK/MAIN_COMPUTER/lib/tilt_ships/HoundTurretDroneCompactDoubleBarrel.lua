local quaternion = require "lib.quaternions"
local utilities = require "lib.utilities"
local targeting_utilities = require "lib.targeting_utilities"
local player_spatial_utilities = require "lib.player_spatial_utilities"
local flight_utilities = require "lib.flight_utilities"
local list_manager = require "lib.list_manager"

local HoundTurretDroneCompact = require "lib.tilt_ships.HoundTurretDroneCompact"

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


local HoundTurretDroneCompactDoubleBarrel = HoundTurretDroneCompact:subclass()


HoundTurretDroneCompactDoubleBarrel.hub1 = peripheral.find("peripheral_hub",function(name,object) return name == "top" end)

HoundTurretDroneCompactDoubleBarrel.gun_controllers = {peripheral.find("redstoneIntegrator",
											function(name,object) 
												for i,list_name in ipairs(HoundTurretDroneCompactDoubleBarrel.hub1.getNamesRemote()) do
													if (list_name == name) then
														return true
													end
												end
												return false
											end)}


function HoundTurretDroneCompactDoubleBarrel:reset_guns()
	
	self.gun_controllers[1].setOutput("north",false)
	self.gun_controllers[1].setOutput("south",false)
	self.gun_controllers[1].setOutput("east",false)
	self.gun_controllers[1].setOutput("west",false)
	
	self.gun_controllers[2].setOutput("north",false)
	self.gun_controllers[2].setOutput("south",false)
	self.gun_controllers[2].setOutput("east",false)
	self.gun_controllers[2].setOutput("west",false)
end


function HoundTurretDroneCompactDoubleBarrel:alternateFire(step)
	local activate_1s2n = step==0 --gun_controller1:south-side ; gun_controller2:north-side 
	local activate_1e2w = step==1
	local activate_1w2e = step==2
	

	self:activateGun({1,1},activate_1s2n)
	self:activateGun({2,3},activate_1s2n)
	
	self:activateGun({1,3},activate_1s2n)
	self:activateGun({2,1},activate_1s2n)

	
	self:activateGun({1,2},activate_1e2w)
	self:activateGun({2,4},activate_1e2w)
	
	self:activateGun({1,4},activate_1w2e)
	self:activateGun({2,2},activate_1w2e)
end

HoundTurretDroneCompactDoubleBarrel.GUNS_COOLDOWN_DELAY = 1 --in seconds
HoundTurretDroneCompactDoubleBarrel.activate_weapons = false

function HoundTurretDroneCompactDoubleBarrel:customThread()
	sync_step = 0
	while self.run_firmware do
		if (self.activate_weapons) then
			self:alternateFire(sync_step)
			
			sync_step = math.fmod(sync_step+1,3)
		else
			self:reset_guns()
		end
		os.sleep(self.GUNS_COOLDOWN_DELAY)
	end
	self:reset_guns()
end



function HoundTurretDroneCompactDoubleBarrel:init(instance_configs)
	local configs = instance_configs
	
	configs.ship_constants_config = configs.ship_constants_config or {}
	
	
	--REMOVE WHEN VS2-COMPUTERS UPDATE RELEASES--
	--unrotated inertia tensors--
	configs.ship_constants_config.LOCAL_INERTIA_TENSOR = configs.ship_constants_config.LOCAL_INERTIA_TENSOR or
	{
		x=vector.new(293039.323259345,-9.094947017729282E-13,0.0),
		y=vector.new(-9.094947017729282E-13,207580.0,0.0),
		z=vector.new(0.0,0.0,212579.32325934505)
	}
	
	configs.ship_constants_config.LOCAL_INV_INERTIA_TENSOR = configs.ship_constants_config.LOCAL_INV_INERTIA_TENSOR or
	{
		x=vector.new(3.4125112932880417E-6,1.4951637638432198E-23,-0.0),
		y=vector.new(1.4951637638432207E-23,4.817419789960497E-6,-0.0),
		z=vector.new(-0.0,-0.0,4.704126368772038E-6)
	}
	--unrotated inertia tensors--
	--REMOVE WHEN VS2-COMPUTERS UPDATE RELEASES--

	HoundTurretDroneCompactDoubleBarrel.superClass.init(self,configs)

end
--overridden functions--


return HoundTurretDroneCompactDoubleBarrel