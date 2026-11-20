--!strict
local Measure = require("../../tools/assets/Measure")
local Criteria = require("../../tools/assets/Criteria")

local function near(a: number, b: number): boolean
	return math.abs(a - b) < 0.001
end

local function criteria(size: { number }): Criteria.Criteria
	return { name = "Chair", size = size, prompt = "A chair.", source = "chair.jpg" }
end

-- n stacked parts filling an x × y × z box whose lowest point is at `base`
local function model(x: number, y: number, z: number, n: number, base: number): any
	local parts = {}
	for i = 1, n do
		local h = y / n
		table.insert(parts, { size = { x, h, z }, at = { 0, base + h * (i - 0.5), 0 } })
	end
	return { parts = parts, source = "generated" }
end

return function(test: (name: string, fn: () -> ()) -> ())
	test("box one part", function()
		local b = Measure.box({ parts = { { size = { 2, 4, 2 }, at = { 0, 2, 0 } } } })
		assert(near(b.min[1], -1) and near(b.min[2], 0) and near(b.min[3], -1), "min")
		assert(near(b.max[1], 1) and near(b.max[2], 4) and near(b.max[3], 1), "max")
	end)

	test("box rotated", function()
		local b = Measure.box({ parts = { { size = { 4, 1, 1 }, at = { 0, 0.5, 0 }, rot = { 0, 90, 0 } } } })
		assert(near(b.max[1] - b.min[1], 1), `x {b.max[1] - b.min[1]}`)
		assert(near(b.max[3] - b.min[3], 4), `z {b.max[3] - b.min[3]}`)
	end)

	test("compare lines are information only", function()
		local lines = Measure.compare(model(0.52, 2.2, 1, 4, 0.3), criteria({ 1, 2.2, 1 }))
		assert(#lines == 3, table.concat(lines, "\n"))
		assert(lines[1] == "size 0.52×2.2×1 (criteria 1×2.2×1)", lines[1])
		assert(lines[2] == "base y=0.3", lines[2])
		assert(lines[3] == "parts 4", lines[3])
		for _, l in lines do
			assert(not string.find(l, "PASS", 1, true) and not string.find(l, "FAIL", 1, true), l)
		end
	end)

	test("criteria check", function()
		assert(Criteria.check(criteria({ 0, 1, 1 })) ~= nil, "zero size")
		local c = criteria({ 1, 1, 1 })
		c.prompt = ""
		assert(Criteria.check(c) ~= nil, "empty prompt")
		assert(Criteria.check(criteria({ 1, 1, 1 })) == nil, "valid")
		assert(Criteria.check({ name = "chair", size = { 1, 1, 1 }, prompt = "x", source = "s" }) ~= nil, "name")
	end)

	test("prompt with notes", function()
		local c = criteria({ 1, 1, 1 })
		c.notes = { "too shiny" }
		assert(Criteria.prompt(c) == "A chair. Fix: too shiny.", Criteria.prompt(c))
		c.notes = nil
		assert(Criteria.prompt(c) == "A chair.", "no notes")
	end)
end
