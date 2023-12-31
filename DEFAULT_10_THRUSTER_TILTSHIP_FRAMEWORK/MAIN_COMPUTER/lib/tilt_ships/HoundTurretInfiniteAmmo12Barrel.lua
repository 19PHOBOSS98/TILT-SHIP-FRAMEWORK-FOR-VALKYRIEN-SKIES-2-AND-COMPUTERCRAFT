local quaternion = require "lib.quaternions"
local utilities = require "lib.utilities"
local targeting_utilities = require "lib.targeting_utilities"
local player_spatial_utilities = require "lib.player_spatial_utilities"
local flight_utilities = require "lib.flight_utilities"
local list_manager = require "lib.list_manager"

local HoundTurretBaseInfiniteAmmo = require "lib.tilt_ships.HoundTurretBaseInfiniteAmmo"

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


local HoundTurretInfiniteAmmo12Barrel = HoundTurretBaseInfiniteAmmo:subclass()


--overridden functions--
function HoundTurretInfiniteAmmo12Barrel:alternateFire(step)
	local seq_1 = step==0
	local seq_2 = step==1

	self:activateGun({"front",1,4},seq_1)
	self:activateGun({"front",2,4},seq_1)
	self:activateGun({"front",3,4},seq_1)
	self:activateGun({"front",4,4},seq_1)
	self:activateGun({"front",5,4},seq_1)
	self:activateGun({"front",6,4},seq_1)
	self:activateGun({"front",7,4},seq_1)
	self:activateGun({"front",8,4},seq_1)
	
	self:activateGun({"front",1,2},seq_2)
	self:activateGun({"front",2,2},seq_2)
	self:activateGun({"front",3,2},seq_2)
	self:activateGun({"front",4,2},seq_2)
	self:activateGun({"front",5,2},seq_2)
	self:activateGun({"front",6,2},seq_2)
	self:activateGun({"front",7,2},seq_2)
	self:activateGun({"front",8,2},seq_2)
end

function HoundTurretInfiniteAmmo12Barrel:init(instance_configs)
	local configs = instance_configs
	
	configs.ship_constants_config = configs.ship_constants_config or {}
	
	
	--REMOVE WHEN VS2-COMPUTERS UPDATE RELEASES--
	--unrotated inertia tensors--
	
	--bare template--
	--it_hound_12b_inf.nbt--
	configs.ship_constants_config.LOCAL_INERTIA_TENSOR = configs.ship_constants_config.LOCAL_INERTIA_TENSOR or
	{
	x=vector.new(30990.23199023199,0.0,200.0),
	y=vector.new(0.0,25180.0,-5.6843418860808015E-14),
	z=vector.new(200.0,-5.6843418860808015E-14,25530.23199023199)
	}
	configs.ship_constants_config.LOCAL_INV_INERTIA_TENSOR = configs.ship_constants_config.LOCAL_INV_INERTIA_TENSOR or
	{
	x=vector.new(3.22698636062945E-5,-5.706854883669621E-25,-2.5279726105615596E-7),
	y=vector.new(-5.7068548836696175E-25,3.971405877680699E-5,8.842837838975495E-23),
	z=vector.new(-2.5279726105615596E-7,8.842837838975499E-23,3.917122883312757E-5)
	}
	--bare template--
	
	--unrotated inertia tensors--
	--REMOVE WHEN VS2-COMPUTERS UPDATE RELEASES--

	HoundTurretInfiniteAmmo12Barrel.superClass.init(self,configs)
end
--overridden functions--

return HoundTurretInfiniteAmmo12Barrel