local CLASS = require "libs.middleclass"

--https://github.com/kikito/tween.lua
-- Adapted from https://github.com/EmmanuelOga/easing. See LICENSE.txt for credits.
-- For all easing functions:
-- t = time == how much time has to pass for the tweening to complete
-- b = begin == starting property value
-- c = change == ending - beginning
-- d = duration == running time. How much time has passed *right now*

local tween = {}

local pow, sin, cos, pi, sqrt, abs, asin = math.pow, math.sin, math.cos, math.pi, math.sqrt, math.abs, math.asin

local pi_half = pi / 2
local pi2 = pi * 2
-- linear
local function linear(t, b, c, d) return c * t / d + b end

-- quad
local function inQuad(t, b, c, d) return c * pow(t / d, 2) + b end
local function outQuad(t, b, c, d)
	t = t / d
	return -c * t * (t - 2) + b
end
local function inOutQuad(t, b, c, d)
	t = t / d * 2
	if t < 1 then return c / 2 * pow(t, 2) + b end
	return -c / 2 * ((t - 1) * (t - 3) - 1) + b
end
local function outInQuad(t, b, c, d)
	if t < d / 2 then return outQuad(t * 2, b, c / 2, d) end
	return inQuad((t * 2) - d, b + c / 2, c / 2, d)
end

-- cubic
local function inCubic (t, b, c, d) return c * pow(t / d, 3) + b end
local function outCubic(t, b, c, d) return c * (pow(t / d - 1, 3) + 1) + b end
local function inOutCubic(t, b, c, d)
	t = t / d * 2
	if t < 1 then return c / 2 * t * t * t + b end
	t = t - 2
	return c / 2 * (t * t * t + 2) + b
end
local function outInCubic(t, b, c, d)
	if t < d / 2 then return outCubic(t * 2, b, c / 2, d) end
	return inCubic((t * 2) - d, b + c / 2, c / 2, d)
end

-- quart
local function inQuart(t, b, c, d) return c * pow(t / d, 4) + b end
local function outQuart(t, b, c, d) return -c * (pow(t / d - 1, 4) - 1) + b end
local function inOutQuart(t, b, c, d)
	t = t / d * 2
	if t < 1 then return c / 2 * pow(t, 4) + b end
	return -c / 2 * (pow(t - 2, 4) - 2) + b
end
local function outInQuart(t, b, c, d)
	if t < d / 2 then return outQuart(t * 2, b, c / 2, d) end
	return inQuart((t * 2) - d, b + c / 2, c / 2, d)
end

-- quint
local function inQuint(t, b, c, d) return c * pow(t / d, 5) + b end
local function outQuint(t, b, c, d) return c * (pow(t / d - 1, 5) + 1) + b end
local function inOutQuint(t, b, c, d)
	t = t / d * 2
	if t < 1 then return c / 2 * pow(t, 5) + b end
	return c / 2 * (pow(t - 2, 5) + 2) + b
end
local function outInQuint(t, b, c, d)
	if t < d / 2 then return outQuint(t * 2, b, c / 2, d) end
	return inQuint((t * 2) - d, b + c / 2, c / 2, d)
end

-- sine
local function inSine(t, b, c, d) return -c * cos(t / d * (pi_half)) + c + b end
local function outSine(t, b, c, d) return c * sin(t / d * (pi_half)) + b end

local function inOutSine(t, b, c, d) return -c / 2 * (cos(pi * t / d) - 1) + b end
local function outInSine(t, b, c, d)
	if t < d / 2 then return outSine(t * 2, b, c / 2, d) end
	return inSine((t * 2) - d, b + c / 2, c / 2, d)
end

-- expo
local function inExpo(t, b, c, d)
	if t == 0 then return b end
	return c * pow(2, 10 * (t / d - 1)) + b - c * 0.001
end
local function outExpo(t, b, c, d)
	if t == d then return b + c end
	return c * 1.001 * (-pow(2, -10 * t / d) + 1) + b
end
local function inOutExpo(t, b, c, d)
	if t == 0 then return b end
	if t == d then return b + c end
	t = t / d * 2
	if t < 1 then return c / 2 * pow(2, 10 * (t - 1)) + b - c * 0.0005 end
	return c / 2 * 1.0005 * (-pow(2, -10 * (t - 1)) + 2) + b
end
local function outInExpo(t, b, c, d)
	if t < d / 2 then return outExpo(t * 2, b, c / 2, d) end
	return inExpo((t * 2) - d, b + c / 2, c / 2, d)
end

-- circ
local function inCirc(t, b, c, d) return (-c * (sqrt(1 - pow(t / d, 2)) - 1) + b) end
local function outCirc(t, b, c, d) return (c * sqrt(1 - pow(t / d - 1, 2)) + b) end
local function inOutCirc(t, b, c, d)
	t = t / d * 2
	if t < 1 then return -c / 2 * (sqrt(1 - t * t) - 1) + b end
	t = t - 2
	return c / 2 * (sqrt(1 - t * t) + 1) + b
end
local function outInCirc(t, b, c, d)
	if t < d / 2 then return outCirc(t * 2, b, c / 2, d) end
	return inCirc((t * 2) - d, b + c / 2, c / 2, d)
end

-- elastic
local function calculatePAS(p, a, c, d)
	p, a = p or d * 0.3, a or 0
	if a < abs(c) then return p, c, p / 4 end -- p, a, s
	return p, a, p / (pi2) * asin(c / a) -- p,a,s
end
local function inElastic(t, b, c, d, a, p)
	local s
	if t == 0 then return b end
	t = t / d
	if t == 1 then return b + c end
	p, a, s = calculatePAS(p, a, c, d)
	t = t - 1
	return -(a * pow(2, 10 * t) * sin((t * d - s) * (pi2) / p)) + b
end
local function outElastic(t, b, c, d, a, p)
	local s
	if t == 0 then return b end
	t = t / d
	if t == 1 then return b + c end
	p, a, s = calculatePAS(p, a, c, d)
	return a * pow(2, -10 * t) * sin((t * d - s) * (pi2) / p) + c + b
end
local function inOutElastic(t, b, c, d, a, p)
	local s
	if t == 0 then return b end
	t = t / d * 2
	if t == 2 then return b + c end
	p, a, s = calculatePAS(p, a, c, d)
	t = t - 1
	if t < 0 then return -0.5 * (a * pow(2, 10 * t) * sin((t * d - s) * (pi2) / p)) + b end
	return a * pow(2, -10 * t) * sin((t * d - s) * (pi2) / p) * 0.5 + c + b
end
local function outInElastic(t, b, c, d, a, p)
	if t < d / 2 then return outElastic(t * 2, b, c / 2, d, a, p) end
	return inElastic((t * 2) - d, b + c / 2, c / 2, d, a, p)
end

-- back
local function inBack(t, b, c, d, s)
	s = s or 1.70158
	t = t / d
	return c * t * t * ((s + 1) * t - s) + b
end
local function outBack(t, b, c, d, s)
	s = s or 1.70158
	t = t / d - 1
	return c * (t * t * ((s + 1) * t + s) + 1) + b
end
local function inOutBack(t, b, c, d, s)
	s = (s or 1.70158) * 1.525
	t = t / d * 2
	if t < 1 then return c / 2 * (t * t * ((s + 1) * t - s)) + b end
	t = t - 2
	return c / 2 * (t * t * ((s + 1) * t + s) + 2) + b
end
local function outInBack(t, b, c, d, s)
	if t < d / 2 then return outBack(t * 2, b, c / 2, d, s) end
	return inBack((t * 2) - d, b + c / 2, c / 2, d, s)
end

-- bounce
local function outBounce(t, b, c, d)
	t = t / d
	if t < 1 / 2.75 then return c * (7.5625 * t * t) + b end
	if t < 2 / 2.75 then
		t = t - (1.5 / 2.75)
		return c * (7.5625 * t * t + 0.75) + b
	elseif t < 2.5 / 2.75 then
		t = t - (2.25 / 2.75)
		return c * (7.5625 * t * t + 0.9375) + b
	end
	t = t - (2.625 / 2.75)
	return c * (7.5625 * t * t + 0.984375) + b
end
local function inBounce(t, b, c, d) return c - outBounce(d - t, 0, c, d) + b end
local function inOutBounce(t, b, c, d)
	if t < d / 2 then return inBounce(t * 2, 0, c, d) * 0.5 + b end
	return outBounce(t * 2 - d, 0, c, d) * 0.5 + c * .5 + b
end
local function outInBounce(t, b, c, d)
	if t < d / 2 then return outBounce(t * 2, b, c / 2, d) end
	return inBounce((t * 2) - d, b + c / 2, c / 2, d)
end

tween.easing = {
	linear = linear,
	inQuad = inQuad, outQuad = outQuad, inOutQuad = inOutQuad, outInQuad = outInQuad,
	inCubic = inCubic, outCubic = outCubic, inOutCubic = inOutCubic, outInCubic = outInCubic,
	inQuart = inQuart, outQuart = outQuart, inOutQuart = inOutQuart, outInQuart = outInQuart,
	inQuint = inQuint, outQuint = outQuint, inOutQuint = inOutQuint, outInQuint = outInQuint,
	inSine = inSine, outSine = outSine, inOutSine = inOutSine, outInSine = outInSine,
	inExpo = inExpo, outExpo = outExpo, inOutExpo = inOutExpo, outInExpo = outInExpo,
	inCirc = inCirc, outCirc = outCirc, inOutCirc = inOutCirc, outInCirc = outInCirc,
	inElastic = inElastic, outElastic = outElastic, inOutElastic = inOutElastic, outInElastic = outInElastic,
	inBack = inBack, outBack = outBack, inOutBack = inOutBack, outInBack = outInBack,
	inBounce = inBounce, outBounce = outBounce, inOutBounce = inOutBounce, outInBounce = outInBounce
}



-- private stuff
--recursive make copy of table. Values of result tables is change between endTable value and startTableValue
local function copyTablesChanges(destination, keysTable, valuesStartTable, valuesEndTable)
	valuesStartTable = valuesStartTable or keysTable
	for k, v in pairs(keysTable) do
		if type(v) == 'table' then
			destination[k] = copyTablesChanges({}, v, valuesStartTable[k], valuesEndTable[k])
		else
			destination[k] = valuesEndTable[k] - valuesStartTable[k]
		end
	end
	return destination
end

local function copyTables(destination, keysTable, valuesTable)
	valuesTable = valuesTable or keysTable
	for k, v in pairs(keysTable) do
		if type(v) == 'table' then
			destination[k] = copyTables({}, v, valuesTable[k])
		else
			destination[k] = valuesTable[k]
		end
	end
	return destination
end

local function checkSubjectAndTargetRecursively(subject, target, path)
	path = path or {}
	local targetType, newPath
	for k, targetValue in pairs(target) do
		targetType, newPath = type(targetValue), copyTables({}, path)
		table.insert(newPath, tostring(k))
		if targetType == 'number' then
			assert(type(subject[k]) == 'number', "Parameter '" .. table.concat(newPath, '/') .. "' is missing from subject or isn't a number")
		elseif targetType == 'table' then
			checkSubjectAndTargetRecursively(subject[k], targetValue, newPath)
		else
			assert(targetType == 'number', "Parameter '" .. table.concat(newPath, '/') .. "' must be a number or table of numbers")
		end
	end
end

local function checkNewParams(duration, subject, target, easing)
	assert(type(duration) == 'number' and duration > 0, "duration must be a positive number. Was " .. tostring(duration))
	local tsubject = type(subject)
	assert(tsubject == 'table' or tsubject == 'userdata', "subject must be a table or userdata. Was " .. tostring(subject))
	assert(type(target) == 'table', "target must be a table. Was " .. tostring(target))
	assert(type(easing) == 'function', "easing must be a function. Was " .. tostring(easing))
	checkSubjectAndTargetRecursively(subject, target)
end

local function getEasingFunction(easing)
	easing = easing or "linear"
	if type(easing) == 'string' then
		local name = easing
		easing = tween.easing[name]
		if type(easing) ~= 'function' then
			error("The easing function name '" .. name .. "' is invalid")
		end
	end
	return easing
end

local function performEasing(subject, initial, changes, a)
	for k, v in pairs(initial) do
		if type(v) == 'table' then
			performEasing(subject[k], v, initial[k], changes[k], a)
		else
			subject[k] = initial[k] + changes[k] * a
		end
	end
end

local function performEasingOnSubject(subject, initial, changes, clock, duration, easing)
	local t, b, c, d = clock, 0, 1, duration
	local a = easing(t, b, c, d)
	performEasing(subject, initial, changes, a)
end

-- Tween methods

---@class Tween
local Tween = CLASS.class("Tween")

function Tween:set(clock)
	assert(type(clock) == 'number', "clock must be a positive number or 0")

	self.initial = self.initial or copyTables({}, self.target, self.subject)
	self.clock = clock

	if self.clock <= 0 then
		self.clock = 0
		copyTables(self.subject, self.initial)
	elseif self.clock >= self.duration then
		-- the tween has expired
		self.clock = self.duration
		copyTables(self.subject, self.target)
	else
		performEasingOnSubject(self.subject, self.initial, self.changes, self.clock, self.duration, self.easing)
	end

	self.a = self.clock / self.duration

	return self.clock >= self.duration
end

function Tween:reset()
	return self:set(0)
end

function Tween:update(dt)
	assert(type(dt) == 'number', "dt must be a number")
	return self:set(self.clock + dt)
end

function Tween:initialize(duration, subject, target, easing)
	easing = getEasingFunction(easing)
	checkNewParams(duration, subject, target, easing)
	self.duration = duration
	self.subject = subject
	self.target = target
	self.easing = easing
	self.changes = {}
	self.clock = 0
	copyTablesChanges(self.changes, subject, subject, target)
	return self
end

function tween.new(...)
	return Tween(...)
end

return tween
