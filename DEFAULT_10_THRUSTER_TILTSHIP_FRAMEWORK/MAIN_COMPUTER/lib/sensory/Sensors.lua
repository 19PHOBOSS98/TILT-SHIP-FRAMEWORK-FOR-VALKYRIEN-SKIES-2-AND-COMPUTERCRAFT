local targeting_utilities = require "lib.targeting_utilities"
local RadarSystems = targeting_utilities.RadarSystems
local TargetingSystem = targeting_utilities.TargetingSystem

local ShipReader = require "lib.sensory.ShipReader"
local ShipRadar = require "lib.sensory.ShipRadar"
local PlayerRadar = require "lib.sensory.PlayerRadar"

local Object = require "lib.object.Object"

local Sensors = Object:subclass()

function Sensors:init()
	self.shipReader = ShipReader()
	self.shipRadar = ShipRadar()
	self.playerRadar = PlayerRadar()
	
	Sensors.superClass.init(self)
end

function Sensors:initRadar(radar_config)
	self.MY_SHIP_ID = self.shipReader:getShipID()
	local radar_arguments = {
	ship_radar_component=self.shipRadar,
	ship_reader_component=self.shipReader,
	player_radar_component=self.playerRadar,
	
	--if target_mode is "2" and hunt_mode is false, drone orbits this ship if detected
	designated_ship_id=tostring(radar_config.designated_ship_id),
	
	--if target_mode is "1" and hunt_mode is false, drone orbits this player if detected
	designated_player_name=radar_config.designated_player_name,
	
	--ships excluded from being aimed at
	ship_id_whitelist={
		[tostring(self.MY_SHIP_ID)]=true,
		[tostring(radar_config.designated_ship_id)]=true,
	},
	
	--players excluded from being aimed at
	player_name_whitelist={
		[tostring(radar_config.designated_player_name)]=true,
	},
	
	--player detector range is defined by a box area around the turret
	player_radar_box_size=radar_config.player_radar_box_size or 50,
	ship_radar_range=radar_config.ship_radar_range or 500
	}
	
	for id,validation in pairs(radar_config.ship_id_whitelist) do
		radar_arguments.ship_id_whitelist[id] = validation
	end
	
	for name,validation in pairs(radar_config.player_name_whitelist) do
		radar_arguments.player_name_whitelist[name] = validation
	end
	
	self.radars = RadarSystems(radar_arguments)
	self.aimTargeting = TargetingSystem(radar_config.EXTERNAL_AIM_TARGETING_CHANNEL,"PLAYER",false,false,self.radars)
	self.orbitTargeting = TargetingSystem(radar_config.EXTERNAL_ORBIT_TARGETING_CHANNEL,"PLAYER",false,false,self.radars)

	function Sensors:scrollUpShipTargets()
		self.radars.onboardShipRadar.listScroller:scrollUp()
	end
	function Sensors:scrollDownShipTargets()
		self.radars.onboardShipRadar.listScroller:scrollDown()
	end

	function Sensors:scrollUpPlayerTargets()
		self.radars.onboardPlayerRadar.listScroller:scrollUp()
	end
	function Sensors:scrollDownPlayerTargets()
		self.radars.onboardPlayerRadar.listScroller:scrollDown()
	end
end

--RADAR SYSTEM FUNCTIONS--
function Sensors:useExternalRadar(is_aim,mode)
	--(turn these on and transmit target info yourselves from a ground radar station, or something... idk)
	if (is_aim) then
		self.aimTargeting:useExternalRadar(mode)--activate to use external radar system instead to get aim_target 
	else
		self.orbitTargeting:useExternalRadar(mode)--activate to use external radar system instead to get orbit_target
	end
end

function Sensors:isUsingExternalRadar(is_aim)
	if (is_aim) then
		return self.aimTargeting:isUsingExternalRadar()
	else
		return self.orbitTargeting:isUsingExternalRadar()
	end
end

function Sensors:setTargetMode(is_aim,target_mode)
	if (is_aim) then
		self.aimTargeting:setTargetMode(target_mode)--aim at either players or ships (etity radar has not yet been implemented)
	else
		self.orbitTargeting:setTargetMode(target_mode)--orbit either players or ships (etity radar has not yet been implemented)
	end
end

function Sensors:getTargetMode(is_aim)
	if (is_aim) then
		return self.aimTargeting:getTargetMode()
	else
		return self.orbitTargeting:getTargetMode()
	end
end

function Sensors:setDesignatedMaster(is_player,designation)
	if (not is_player and designation == tostring(self.MY_SHIP_ID)) then
		self:setTargetMode(false,"PLAYER")
	else
		self.radars:setDesignatedMaster(is_player,designation)
	end
end

function Sensors:getDesignatedMaster(is_player)
	self.radars:getDesignatedMaster(is_player)
end


function Sensors:addToWhitelist(is_player,designation)
	self.radars:addToWhitelist(is_player,designation)
end

function Sensors:removeFromWhitelist(is_player,designation)
	self.radars:removeFromShipWhitelist(is_player,designation)
end

function Sensors:getAutoAim()
	return self.aimTargeting:getAutoAimActive()
end

function Sensors:setAutoAim(lock_true,mode)
	self.aimTargeting:setAutoAimActive(lock_true,mode)
end

function Sensors:targetedPlayersAreUndetected()
	return self.radars.targeted_players_undetected
end

function Sensors:updateTargetingSystem()
	
	self.radars:updateTargetingTables()
	self.aimTargeting:listenToExternalRadar()
	self.orbitTargeting:listenToExternalRadar()

end
--RADAR SYSTEM FUNCTIONS--

return Sensors