local Object = require "lib.object.Object"

local ShipRadar = Object:subclass()

function ShipRadar:init()
	self.peripheral = peripheral.find("radar")
	ShipRadar.superClass.init(self)
end

function ShipRadar:scan(range)
	return self.peripheral.scan(range)[1]
end

return ShipRadar