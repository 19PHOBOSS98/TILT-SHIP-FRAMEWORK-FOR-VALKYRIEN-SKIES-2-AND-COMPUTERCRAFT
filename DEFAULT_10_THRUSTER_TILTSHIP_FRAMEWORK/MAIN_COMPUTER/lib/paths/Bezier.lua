os.loadAPI("lib/quaternions.lua")
os.loadAPI("lib/pidcontrollers.lua")
os.loadAPI("lib/targeting_utilities.lua")
os.loadAPI("lib/player_spatial_utilities.lua")
os.loadAPI("lib/flight_utilities.lua")
os.loadAPI("lib/utilities.lua")

local Object = require "lib.object.Object"

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
local quaternion = quaternions.Quaternion


local Bezier = Object:subclass()

function Bezier:init()
	Bezier.superClass.init(self)
	self.points = {}
	self.autoStepScale = .1
	
end

function Bezier:getPoints()
	return self.points
end

function Bezier:setPoints(points)
	self.points = points
end

function Bezier:setAutoStepScale(scale)
	self.autoStepScale = scale
end

function Bezier:getAutoStepScale()
	return self.autoStepScale
end

function Bezier:pointDistance(p1, p2)
	local dx = p2.x - p1.x
	local dy = p2.y - p1.y
	local dz = p2.z - p1.z
	return math.sqrt(dx*dx + dy*dy + dz*dz)
end

function Bezier:getLength()
	local length = 0
	local last = nil
	
	for i,point in ipairs(self.points) do
		if last then
			length = length + self:pointDistance(point, last)
		end
		last = point
	end
	
	return(length)
end

function Bezier:draw(isClosed)
	self:beginPath()

	for i,point in ipairs(self.points) do
		self:lineTo(point.x, point.y)
	end

	if isClosed then self:closePath() end

	self:endPath()
end

-- Estimate number of steps based on the distance between each point/control
-- Inspired by http://antigrain.com/research/adaptive_bezier/
function Bezier:estimateSteps(p1, p2, p3, p4)
	local distance = 0
	if p1 and p2 then
		distance = distance + self:pointDistance(p1, p2)
	end
	if p2 and p3 then
		distance = distance + self:pointDistance(p2, p3)
	end
	if p3 and p4 then
		distance = distance + self:pointDistance(p3, p4)
	end

	return math.max(1, math.floor(distance * self.autoStepScale))
end

-- Bezier functions from Paul Bourke
-- http://paulbourke.net/geometry/bezier/
function Bezier:createQuadraticCurve(p1, p2, p3, steps)
	self.points = {}
	steps = steps or self:estimateSteps(p1, p2, p3)
	for i = 0, steps do
		table.insert(self.points, self:bezier3(p1, p2, p3, i/steps))
	end
end

function Bezier:createCubicCurve(p1, p2, p3, p4, steps)
	self.points = {}
	steps = steps or self:estimateSteps(p1, p2, p3, p4)
	for i = 0, steps do
		table.insert(self.points, self:bezier4(p1, p2, p3, p4, i/steps))
	end
end

function Bezier:bezier3(p1,p2,p3,mu)
	local mum1,mum12,mu2
	local p = {}
	mu2 = mu * mu
	mum1 = 1 - mu
	mum12 = mum1 * mum1
	p.x = p1.x * mum12 + 2 * p2.x * mum1 * mu + p3.x * mu2
	p.y = p1.y * mum12 + 2 * p2.y * mum1 * mu + p3.y * mu2
	p.z = p1.z * mum12 + 2 * p2.z * mum1 * mu + p3.z * mu2
	
	return p
end

function Bezier:bezier4(p1,p2,p3,p4,mu)
	local mum1,mum13,mu3;
	local p = {}

	mum1 = 1 - mu
	mum13 = mum1 * mum1 * mum1
	mu3 = mu * mu * mu

	p.x = mum13*p1.x + 3*mu*mum1*mum1*p2.x + 3*mu*mu*mum1*p3.x + mu3*p4.x
	p.y = mum13*p1.y + 3*mu*mum1*mum1*p2.y + 3*mu*mu*mum1*p3.y + mu3*p4.y
	p.z = mum13*p1.z + 3*mu*mum1*mum1*p2.z + 3*mu*mu*mum1*p3.z + mu3*p4.z

	return p	
end

-- Reduce nodes based on Ramer-Douglas-Peucker algorithm
-- http://en.wikipedia.org/wiki/Ramer%E2%80%93Douglas%E2%80%93Peucker_algorithm
-- Additional help from http://quangnle.wordpress.com/2012/12/30/corona-sdk-curve-fitting-1-implementation-of-ramer-douglas-peucker-algorithm-to-reduce-points-of-a-curve/
function Bezier:reduce(epsilon)
	epsilon = epsilon or .1

	if #self.points > 1 then
		-- Keep first and last
		self.points[1].keep = true
		self.points[#self.points].keep = true

		-- Figure out the rest
		self:douglasPeucker(1, #self.points, epsilon)
	end

	-- Replace point list with only those that are marked to keep
	local old = self.points
	self.points = {}

	for i,point in ipairs(old) do
		if point.keep then
			table.insert(self.points, {x=point.x, y=point.y})
		end
	end
end

function Bezier:douglasPeucker(first, last, epsilon)
	local dmax = 0
	local index = 0

	for i=first+1, last-1 do
		local d = self:pointLineDistance(self.points[i], self.points[first], self.points[last])

		if d > dmax then
			index = i
			dmax = d
		end
	end

	if dmax >= epsilon then
		self.points[index].keep = true

		-- Recursive call
		self:douglasPeucker(first, index, epsilon)
		self:douglasPeucker(index, last, epsilon)
	end
end

function Bezier:pointLineDistance(p, a, b)
	-- calculates area of the triangle
	local area = math.abs(0.5 * (a.x * b.y + b.x * p.y + p.x * a.y - b.x * a.y - p.x * b.y - a.x * p.y))
	-- calculates the length of the bottom edge
	local dx = a.x - b.x
	local dy = a.y - b.y
	local bottom = math.sqrt(dx*dx + dy*dy)
	-- the triangle's height is also the distance found
	return area / bottom
end

return Bezier