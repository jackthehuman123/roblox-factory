--!strict
local ArtFit = require("../../kit/src/shared/ArtFit")
local ArtRules = require("../../kit/src/shared/ArtRules")

local function run(placements: { any }, models: { [string]: any }, boxes: { any }): { string }
	local hidden = ArtFit.hidden(placements, boxes)
	return ArtRules.check(ArtFit.copies(placements, models, boxes), boxes, hidden, placements)
end

local function has(messages: { string }, rule: string): boolean
	for _, m in messages do
		if string.find(m, `: {rule}: `, 1, true) then
			return true
		end
	end
	return false
end

local function cube(): any
	return { parts = { { size = { 1, 1, 1 }, at = { 0, 0.5, 0 } } } }
end

local floor: any = { size = { 20, 1, 20 }, at = { 0, -0.5, 0 }, tags = { "Floor" } }

local function capScene(extra: any): ({ any }, { [string]: any }, { any })
	local placement = { model = "cap", onTag = "EndCap" }
	for k, v in extra do
		placement[k] = v
	end
	local models = { cap = { parts = { { size = { 16, 14, 2 }, at = { 0, 0, 0 } } } } }
	local boxes = { { size = { 16, 14, 2 }, at = { 0, 7, 0 }, tags = { "EndCap" } } }
	return { placement }, models, boxes
end

return function(test: (name: string, fn: () -> ()) -> ())
	test("doubled", function()
		local p, m, b = capScene({})
		local out = run(p, m, b)
		assert(has(out, "doubled"), "expected doubled")
		assert(
			out[1] == "placement 1 (cap): doubled: hide the base (hideBase) or move the model (1 of 1 copies)",
			out[1]
		)
		local p2, m2, b2 = capScene({ hideBase = true })
		assert(not has(run(p2, m2, b2), "doubled"), "hideBase should clear doubled")
	end)

	test("sunk", function()
		local p = { { model = "cube", at = { 0, -0.5, 2 } } }
		local deep = run(p, { cube = cube() }, { floor })
		assert(has(deep, "sunk"), "expected sunk")
		local p2 = { { model = "cube", at = { 0, -0.05, 2 } } }
		local shallow = run(p2, { cube = cube() }, { floor })
		assert(not has(shallow, "sunk"), "0.05 is not sunk")
		assert(has(shallow, "flush"), "0.05 is flush")
	end)

	test("own base never sunk", function()
		local p = { { model = "lamp", onTag = "Post" } }
		local models = { lamp = { parts = { { size = { 1, 4, 1 }, at = { 0, 0, 0 } } } } }
		local boxes = { { size = { 1, 4, 1 }, at = { 0, 2, 0 }, tags = { "Post" } } }
		local out = run(p, models, boxes)
		assert(has(out, "doubled"), "expected doubled")
		assert(not has(out, "sunk"), "own base is never sunk")
	end)

	test("flush", function()
		local out = run({ { model = "cube", at = { 0, 0, 0 } } }, { cube = cube() }, { floor })
		assert(has(out, "flush"), "expected flush")
	end)

	test("sit lift passes flush", function()
		local p = { { model = "cube", onTag = "Floor", sit = "top" } }
		local out = run(p, { cube = cube() }, { floor })
		assert(#out == 0, table.concat(out, "\n"))
	end)

	test("floating", function()
		local wall: any = { size = { 10, 10, 1 }, at = { 0, 5, 0 } }
		local far = run({ { model = "cube", at = { 0, 5, 2.75 } } }, { cube = cube() }, { wall })
		assert(has(far, "floating"), "expected floating")
		local near = run({ { model = "cube", at = { 0, 5, 1.05 } } }, { cube = cube() }, { wall })
		assert(not has(near, "floating"), "0.05 from wall is not floating")
	end)

	test("touching art counts", function()
		local p = { { model = "cube", at = { 0, 0.05, 0 } }, { model = "cube", at = { 0, 1.05, 0 } } }
		local out = run(p, { cube = cube() }, { floor })
		assert(#out == 0, table.concat(out, "\n"))
	end)

	test("overlap", function()
		local m = { cube = cube() }
		local out = run({ { model = "cube", at = { 0, 0, 0 } }, { model = "cube", at = { 0.7, 0, 0 } } }, m, {})
		assert(out[1] == "placement 1 (cube): overlap: move one (overlaps placement 2)", out[1] or "none")
		local out2 = run({ { model = "cube", at = { 0, 0, 0 } }, { model = "cube", at = { 0.8, 0, 0 } } }, m, {})
		assert(not has(out2, "overlap"), "20 percent is fine")
	end)

	test("allow skips", function()
		local p, m, b = capScene({ allow = { "doubled" } })
		assert(#run(p, m, b) == 0, "allow doubled")
	end)

	test("runtime-only tag is skipped", function()
		local out = run({ { model = "cube", onTag = "Stalker" } }, { cube = cube() }, { floor })
		assert(#out == 0, "no messages")
	end)

	test("one line per placement", function()
		local p, m, _ = capScene({})
		local boxes: { any } = {}
		for i = 1, 60 do
			table.insert(boxes, { size = { 16, 14, 2 }, at = { i * 20, 7, 0 }, tags = { "EndCap" } })
		end
		local out = run(p, m, boxes)
		assert(#out == 1, `expected 1 line, got {#out}`)
		assert(string.sub(out[1], -17) == "(60 of 60 copies)", out[1])
	end)
end
