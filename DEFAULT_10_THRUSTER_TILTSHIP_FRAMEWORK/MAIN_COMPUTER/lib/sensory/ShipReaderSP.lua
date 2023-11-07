local ShipReader = require "lib.sensory.ShipReader"
local ShipReaderSP = ShipReader:subclass()

function ShipReaderSP:init()
	ShipReaderSP.superClass.init(self)
	self.peripheral = peripheral.find("sp_radar")
	
	self.ship = self:initShip()
	
	self.shipID = self.ship.id
	
	
end

function ShipReaderSP:getRotation(is_quaternion)
	local rot = self.ship.rotation
	return {w=rot.w,x=rot.x,y=rot.y,z=rot.z}
end

function ShipReaderSP:getWorldspacePosition()
	return self.ship.pos
end

function ShipReaderSP:getShipID()
	return self.shipID
end

function ShipReaderSP:getMass()
	return self.ship.mass
end

function ShipReaderSP:initShip()
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

function ShipReaderSP:updateShipReader()
	if (self.peripheral) then
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
end

return ShipReaderSP