local Object = require "lib.object.Object"

local PlayerRadar = Object:subclass()

function PlayerRadar:init()
	self.peripheral = peripheral.find("playerDetector")
	PlayerRadar.superClass.init(self)
end

function PlayerRadar:getPlayerPos(name)
	return self.peripheral.getPlayerPos(name)
end

function PlayerRadar:getPlayersInCoords(pos1,pos2)
	return self.peripheral.getPlayersInCoords(pos1,pos2)
end

return PlayerRadar