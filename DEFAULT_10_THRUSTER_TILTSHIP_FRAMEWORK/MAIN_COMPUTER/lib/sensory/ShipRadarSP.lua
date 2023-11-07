local Object = require "lib.object.Object"

local ShipRadar = Object:subclass()

function ShipRadar:init()
	self.peripheral = peripheral.find("sp_radar")
	ShipRadar.superClass.init(self)
end

function ShipRadar:scan(range)
	return self.peripheral.scan(range)
end

return ShipRadar