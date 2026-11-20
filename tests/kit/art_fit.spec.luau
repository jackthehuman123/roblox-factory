--!strict
local ArtFit = require("../../kit/src/shared/ArtFit")

local function near(a: number, b: number): boolean
	return math.abs(a - b) < 1e-6
end

local function expect(label: string, a: number, b: number)
	assert(near(a, b), `{label}: expected {b}, got {a}`)
end

return function(test: (name: string, fn: () -> ()) -> ())
	test("modelBox unions parts", function()
		local box = ArtFit.modelBox({
			parts = {
				{ size = { 2, 2, 2 }, at = { 0, 1, 0 } },
				{ size = { 1, 1, 1 }, at = { 3, 0.5, 0 } },
			},
		})
		expect("min x", box.min[1], -1)
		expect("min y", box.min[2], 0)
		expect("min z", box.min[3], -1)
		expect("max x", box.max[1], 3.5)
		expect("max y", box.max[2], 2)
		expect("max z", box.max[3], 1)
	end)

	test("modelBox rotates parts", function()
		local box = ArtFit.modelBox({ parts = { { size = { 4, 1, 1 }, at = { 0, 0, 0 }, rot = { 0, 90, 0 } } } })
		expect("x extent", box.max[1] - box.min[1], 1)
		expect("z extent", box.max[3] - box.min[3], 4)
	end)

	test("sitY top/base/under", function()
		local box = { min = { 0, 0, 0 }, max = { 1, 2, 1 } }
		expect("top", ArtFit.sitY("top", 1, box), 0.52)
		expect("base", ArtFit.sitY("base", 1, box), -0.48)
		expect("under", ArtFit.sitY("under", 1, box), -2.5)
	end)

	test("onTag copy sits on top", function()
		local boxes = { { size = { 8, 1, 8 }, at = { 0, 0.5, 0 }, tags = { "Spawn" } } }
		local models = { Pad = { parts = { { size = { 8, 1, 8 }, at = { 0, 0.5, 0 } } } } }
		local copies = ArtFit.copies({ { model = "Pad", onTag = "Spawn", sit = "top" } }, models, boxes)
		assert(#copies == 1, "expected 1 copy")
		expect("min y", copies[1].box.min[2], 1.02)
		assert(copies[1].base == 1 and copies[1].placement == 1, "indices")
	end)

	test("offset follows base yaw", function()
		local boxes = { { size = { 2, 2, 2 }, at = { 0, 0, 0 }, rot = 90, tags = { "B" } } }
		local models = { Bar = { parts = { { size = { 4, 1, 1 }, at = { 0, 0, 0 } } } } }
		local copies = ArtFit.copies({ { model = "Bar", onTag = "B", offset = { 2, 0, 0 } } }, models, boxes)
		local b = copies[1].box
		expect("centre x", (b.min[1] + b.max[1]) / 2, 0)
		expect("centre z", (b.min[3] + b.max[3]) / 2, -2)
		expect("x width", b.max[1] - b.min[1], 1)
		expect("z width", b.max[3] - b.min[3], 4)
	end)

	local lamp = { Lamp = { parts = { { size = { 1, 1, 1 }, at = { 0, 0.5, 0 } } } } }

	test("floor sit for at", function()
		local boxes = { { size = { 10, 1, 10 }, at = { 0, -0.5, 0 } } }
		local copies = ArtFit.copies({ { model = "Lamp", at = { 3, 5, 3 }, sit = "floor" } }, lamp, boxes)
		expect("min y", copies[1].box.min[2], 0.02)
	end)

	test("floor at exactly the placement Y is found", function()
		local boxes = { { size = { 10, 1, 10 }, at = { 0, -0.5, 0 } } }
		expect("floor", ArtFit.floorY(boxes, {}, 0, 0, 0) or -1, 0)
	end)

	test("floor beyond ray length is ignored", function()
		local boxes = { { size = { 10, 1, 10 }, at = { 0, -0.5, 0 } } }
		assert(ArtFit.floorY(boxes, {}, 0, 0, ArtFit.FLOOR_RAY + 1) == nil, "too far")
	end)

	test("hidden box is not a floor", function()
		local boxes = {
			{ size = { 10, 1, 10 }, at = { 0, -0.5, 0 } },
			{ size = { 10, 1, 10 }, at = { 0, 1.5, 0 }, tags = { "Wall" } },
		}
		local placements = {
			{ model = "Lamp", onTag = "Wall", hideBase = true, sit = "top" },
			{ model = "Lamp", at = { 3, 5, 3 }, sit = "floor" },
		}
		local copies = ArtFit.copies(placements, lamp, boxes)
		local found = false
		for _, c in copies do
			if c.placement == 2 then
				found = true
				expect("min y", c.box.min[2], 0.02)
			end
		end
		assert(found, "floor copy missing")
	end)

	test("hidden follows hideBase", function()
		local boxes = {
			{ size = { 1, 1, 1 }, at = { 0, 0, 0 }, tags = { "Wall" } },
			{ size = { 1, 1, 1 }, at = { 2, 0, 0 } },
			{ size = { 1, 1, 1 }, at = { 4, 0, 0 }, tags = { "Wall" } },
		}
		local hidden = ArtFit.hidden({ { model = "X", onTag = "Wall", hideBase = true } }, boxes)
		assert(hidden[1] and hidden[3] and not hidden[2], "wall boxes hidden only")
	end)
end
