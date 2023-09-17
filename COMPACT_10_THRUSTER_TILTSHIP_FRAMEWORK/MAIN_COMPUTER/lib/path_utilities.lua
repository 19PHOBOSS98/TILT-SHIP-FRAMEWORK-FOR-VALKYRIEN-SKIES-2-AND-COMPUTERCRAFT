local cos = math.cos
local sin = math.sin
local pi = math.pi
local two_pi = 2*pi

function generateHelix(radius,gap,loops,resolution)
	local helix = {}

	for t=0,two_pi*loops,two_pi/resolution do
		local coord = vector.new(radius*cos(t),radius*sin(t),gap*t)
		table.insert(helix,coord)
	end
	return helix
end

function recenterStartToOrigin(coords)
	local coord_i = coords[1]
	for i,coord in ipairs(coords) do
		coords[i] = coord-coord_i
	end
end

function offsetCoords(coords,offset)
	local coord_i = coords[1]
	for i,coord in ipairs(coords) do
		coords[i] = coord+offset
	end
end

