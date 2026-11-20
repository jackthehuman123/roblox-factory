--!strict
local ArtPlacement = require("../../kit/src/shared/ArtPlacement")

local function modelOf(n: number): { parts: { any } }
	local parts = {}
	for _ = 1, n do
		table.insert(parts, { size = { 1, 1, 1 }, at = { 0, 0, 0 } })
	end
	return { parts = parts }
end

local function joined(errs: { string }): string
	return table.concat(errs, "; ")
end

return function(test: (name: string, fn: () -> ()) -> ())
	test("placement needs exactly one of at or onTag", function()
		local models = { Lamp = modelOf(1) }
		local both = ArtPlacement.validatePlacements(
			{ { model = "Lamp", at = { 0, 0, 0 }, onTag = "Light" } },
			models,
			{}
		)
		assert(#both == 1, `both: expected 1 error, got {#both}: {joined(both)}`)
		local neither = ArtPlacement.validatePlacements({ { model = "Lamp" } }, models, {})
		assert(#neither == 1, `neither: expected 1 error, got {#neither}: {joined(neither)}`)
	end)

	test("placement naming a missing model", function()
		local errs = ArtPlacement.validatePlacements({ { model = "Ghost", at = { 0, 0, 0 } } }, {}, {})
		assert(#errs == 1, `expected 1 error, got {#errs}: {joined(errs)}`)
		assert(errs[1] == "placement 1: unknown model Ghost", `got: {errs[1]}`)
	end)

	test("bad placement fields", function()
		local errs = ArtPlacement.validatePlacements({
			{ model = "Lamp", onTag = "Light", offset = { 0, 0 } :: any, hideBase = "yes" :: any, rot = "x" :: any },
		}, { Lamp = modelOf(1) }, {})
		assert(#errs == 3, `expected 3 errors, got {#errs}: {joined(errs)}`)
	end)

	test("budget counts onTag per tagged base", function()
		local models = { Lamp = modelOf(50) }
		local over = ArtPlacement.validatePlacements({ { model = "Lamp", onTag = "Light" } }, models, { Light = 62 })
		assert(#over == 1, `expected 1 error, got {#over}: {joined(over)}`)
		assert(string.find(over[1], "3100", 1, true) ~= nil, `total not mentioned: {over[1]}`)
		local under = ArtPlacement.validatePlacements({ { model = "Lamp", onTag = "Light" } }, models, { Light = 60 })
		assert(#under == 0, `expected 0 errors, got {#under}: {joined(under)}`)
	end)

	test("unknown tag counts once", function()
		local models = { Big = modelOf(3000) }
		local errs = ArtPlacement.validatePlacements({ { model = "Big", onTag = "Stalker" } }, models, {})
		assert(#errs == 0, `expected 0 errors, got {#errs}: {joined(errs)}`)
		local two = ArtPlacement.validatePlacements(
			{ { model = "Big", onTag = "Stalker" }, { model = "Big", at = { 0, 0, 0 } } },
			models,
			{}
		)
		assert(#two == 1, `expected 1 error, got {#two}: {joined(two)}`)
	end)

	test("old-shape placement still validates", function()
		local pl = { { model = "X", onTag = "T", offset = { 0, 1, 0 }, hideBase = true } }
		local errs = ArtPlacement.validatePlacements(pl, { X = modelOf(1) }, { T = 1 })
		assert(#errs == 0, joined(errs))
	end)

	test("sit by kind", function()
		local models = { X = modelOf(1) }
		local function errsFor(pl: any): number
			return #ArtPlacement.validatePlacements({ pl }, models, { T = 1 })
		end
		assert(errsFor({ model = "X", onTag = "T", sit = "floor" }) == 1, "errsFor")
		assert(errsFor({ model = "X", at = { 0, 0, 0 }, sit = "top" }) == 1, "errsFor")
		assert(errsFor({ model = "X", onTag = "T", sit = "base" }) == 0, "errsFor")
		assert(errsFor({ model = "X", at = { 0, 0, 0 }, sit = "floor" }) == 0, "errsFor")
	end)

	test("allow names rules", function()
		local errs = ArtPlacement.validatePlacements(
			{ { model = "X", at = { 0, 0, 0 }, allow = { "doubled", "nope" } } },
			{ X = modelOf(1) },
			{}
		)
		assert(#errs == 1 and string.find(errs[1], "nope", 1, true), joined(errs))
	end)
end
