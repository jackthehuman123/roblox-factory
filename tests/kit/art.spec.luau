--!strict
local Art = require("../../kit/src/shared/Art")

local function block(): Art.PartData
	return { size = { 1, 1, 1 }, at = { 0, 0, 0 } }
end

local function modelOf(n: number): Art.ModelData
	local parts = {}
	for _ = 1, n do
		table.insert(parts, block())
	end
	return { parts = parts }
end

local function joined(errs: { string }): string
	return table.concat(errs, "; ")
end

return function(test: (name: string, fn: () -> ()) -> ())
	test("valid model has no errors", function()
		local errs = Art.validateModel("Lamp", {
			parts = {
				{
					size = { 1, 2, 3 },
					at = { 0, 1, 0 },
					rot = { 0, 90, 0 },
					color = { 10, 20, 30 },
					material = "Brick",
				},
				{
					size = { 2, 8, 2 },
					at = { 0, 4, 0 },
					meshId = "rbxassetid://123",
					textureId = "rbxassetid://456",
					transparency = 0.5,
					light = { kind = "SpotLight", brightness = 2, range = 20, color = { 255, 240, 200 }, angle = 60 },
				},
			},
		})
		assert(#errs == 0, `expected 0 errors, got {#errs}: {joined(errs)}`)
	end)

	test("bad part lists every problem", function()
		local errs = Art.validateModel("Lamp", {
			parts = {
				{
					size = { 0, 1, 1 },
					at = { 0, 0 } :: any,
					color = { 300, 0, 0 },
					material = "Lava",
					meshId = "123",
					transparency = 2,
				},
			},
		})
		assert(#errs == 6, `expected 6 errors, got {#errs}: {joined(errs)}`)
		for _, e in errs do
			assert(string.sub(e, 1, 19) == "model Lamp: part 1:", `bad prefix: {e}`)
		end
	end)

	test("textureId without meshId is an error", function()
		local errs = Art.validateModel(
			"Lamp",
			{ parts = { { size = { 1, 1, 1 }, at = { 0, 0, 0 }, textureId = "rbxassetid://1" } } }
		)
		assert(#errs == 1, `expected 1 error, got {#errs}: {joined(errs)}`)
	end)

	test("bad light kind is an error", function()
		local errs = Art.validateModel("Lamp", {
			parts = {
				{ size = { 1, 1, 1 }, at = { 0, 0, 0 }, light = { kind = "Sun", brightness = 1, range = 8 } :: any },
			},
		})
		assert(#errs == 1, `expected 1 error, got {#errs}: {joined(errs)}`)
	end)

	test("bad model name", function()
		local errs = Art.validateModel("lamp", modelOf(1))
		assert(#errs == 1, `expected 1 error, got {#errs}: {joined(errs)}`)
		assert(string.find(errs[1], "lamp", 1, true) ~= nil, `name not mentioned: {errs[1]}`)
	end)

	test("model with no parts is an error", function()
		local errs = Art.validateModel("Lamp", { parts = {} })
		assert(#errs == 1, `expected 1 error, got {#errs}: {joined(errs)}`)
	end)

	test("old-shape data still validates", function()
		local model = {
			parts = {
				{
					size = { 3, 8, 2 },
					at = { 0, 4, 0 },
					color = { 163, 162, 165 },
					meshId = "rbxassetid://94271971316857",
					textureId = "rbxassetid://102930592188427",
				},
			},
		}
		assert(#Art.validateModel("PorcelainStalker", model) == 0, "old model")
	end)

	test("surface needs meshId", function()
		local errs = Art.validateModel("Lamp", {
			parts = { { size = { 1, 1, 1 }, at = { 0, 0, 0 }, surface = { colorMap = "rbxassetid://1" } } },
		})
		assert(string.find(joined(errs), "surface needs meshId", 1, true), joined(errs))
	end)

	test("source format", function()
		local function errsFor(src: string): number
			return #Art.validateModel("Lamp", { parts = { block() }, source = src })
		end
		assert(errsFor("generated") == 0, "errsFor")
		assert(errsFor("rbxassetid://9") == 0, "errsFor")
		assert(errsFor("store") == 1, "errsFor")
	end)
end
