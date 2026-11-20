--!strict
local luau = require("@lune/luau")
local Serialize = require("../../tools/assets/Serialize")
local Catalog = require("../../tools/assets/Catalog")

local function load(src: string): any
	return luau.load(src)()
end

local function deepEqual(a: any, b: any): boolean
	if type(a) ~= "table" or type(b) ~= "table" then
		return a == b
	end
	for k, v in a do
		if not deepEqual(v, b[k]) then
			return false
		end
	end
	for k in b do
		if a[k] == nil then
			return false
		end
	end
	return true
end

local hostile = '"]] end; error("x")\n\\'

local function indexData(): { Catalog.IndexEntry }
	return {
		{
			name = "Bed",
			tags = { "home", "bedroom" },
			size = { 3.6, 2.1, 7 },
			sources = { "bed.png" },
			built = "code",
			review = "unreviewed",
		},
		{
			name = "Lamp",
			tags = { "home" },
			size = { 1, 1, 0.25 },
			sources = { "a.png", "b.png" },
			built = "mixed",
			review = "rejected",
			note = hostile,
			reason = "ugly",
		},
	}
end

return function(test: (name: string, fn: () -> ()) -> ())
	test("round trip index", function()
		local x = indexData()
		assert(deepEqual(load(Serialize.index(x)), x), "index differs")
	end)

	test("round trip measure", function()
		local index = indexData()
		index[1].measure = "size 2×3.5×2 vs 2×3.5×2 ±15%: ok\nPASS"
		local back = load(Serialize.index(index))
		assert(back[1].measure == index[1].measure, tostring(back[1].measure))
	end)

	test("round trip images", function()
		local x = {
			{ file = "bed.png", hash = string.rep("a", 64), status = "done", built = { "Bed" }, skipped = {} },
			{
				file = "x.png",
				hash = string.rep("b", 64),
				status = "skipped",
				built = {},
				skipped = { { object = "Sofa", why = hostile } },
			},
		}
		assert(deepEqual(load(Serialize.images(x)), x), "images differ")
	end)

	test("quotes hostile strings", function()
		local x = indexData()
		local got = load(Serialize.index(x))
		assert(got[2].note == hostile, "note changed")
	end)
end
