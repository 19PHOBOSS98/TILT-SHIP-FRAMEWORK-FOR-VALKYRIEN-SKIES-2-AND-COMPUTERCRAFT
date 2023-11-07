local Object = require "lib.object.Object"

local ShipReader = Object:subclass()

function ShipReader:init()
	self.peripheral = peripheral.find("sp_radar")
	
	self.ship = self:initShip()
	
	self.shipID = ship.id
	
	ShipReader.superClass.init(self)
end

function ShipReader:getRotation(is_quaternion)
	return self.ship.rotation
end

function ShipReader:getWorldspacePosition()
	return self.ship.pos
end

function ShipReader:getShipID()
	return self.shipID
end

function ShipReader:getMass()
	return self.ship.mass
end

function ShipReader:initShip()
	local ship = self.peripheral.scan(1)[1]
	if (not ship.is_ship) then
		for i,v in ipairs (self.peripheral.scan(1)) do
			if (v.is_ship) then
				ship = v
				break
			end
		end
	end
	return ship
end

function ShipReader:updateShipReader()
	local ship = self.peripheral.scan(1)[1]
	if (not ship.is_ship) then
		for i,v in ipairs (self.peripheral.scan(1)) do
			if (v.is_ship and v.id == self.shipID) then
				ship = v
				break
			end
		end
	end
	self.ship = ship
end

return ShipReader