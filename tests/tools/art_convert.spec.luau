--!strict
local luau = require("@lune/luau")
local Art = require("../../kit/src/shared/Art")
local convert = require("../../tools/art/convert")

local function find(s: string, needle: string): boolean
	return string.find(s, needle, 1, true) ~= nil
end

local function dump(parts: { any }, unsupported: { string }?): any
	return { name = "Lamp", parts = parts, unsupported = unsupported or {} }
end

return function(test: (name: string, fn: () -> ()) -> ())
	test("block part converts with rounding", function()
		local src = convert(dump({
			{
				class = "Part",
				shape = "Block",
				size = { 1.00049, 2, 3 },
				at = { 0.12345, -0.0001, 5 },
				rot = { 0, 89.96, 0 },
				color = { 10.4, 20.6, 30 },
				material = "Brick",
				transparency = 0,
			},
		}))
		assert(find(src, "size = { 1, 2, 3 }"), src)
		assert(find(src, "at = { 0.123, 0, 5 }"), src)
		assert(find(src, "rot = { 0, 90, 0 }"), src)
		assert(find(src, "color = { 10, 21, 30 }"), src)
		assert(find(src, 'material = "Brick"'), src)
		assert(not find(src, "transparency"), "default transparency should be dropped")
	end)

	test("mesh part keeps ids and normalises legacy urls", function()
		local src = convert(dump({
			{
				class = "MeshPart",
				size = { 1, 1, 1 },
				at = { 0, 0, 0 },
				rot = { 0, 0, 0 },
				color = { 255, 255, 255 },
				material = "Plastic",
				transparency = 0,
				meshId = "rbxassetid://123",
				textureId = "http://www.roblox.com/asset/?id=456",
			},
		}))
		assert(find(src, 'meshId = "rbxassetid://123"'), src)
		assert(find(src, 'textureId = "rbxassetid://456"'), src)
	end)

	test("empty texture id is dropped", function()
		local src = convert(dump({
			{
				class = "MeshPart",
				size = { 1, 1, 1 },
				at = { 0, 0, 0 },
				rot = { 0, 0, 0 },
				color = { 1, 2, 3 },
				material = "Plastic",
				transparency = 0,
				meshId = "rbxassetid://123",
				textureId = "",
			},
		}))
		assert(not find(src, "textureId"), src)
	end)

	test("lights are kept", function()
		local src = convert(dump({
			{
				class = "Part",
				shape = "Ball",
				size = { 1, 1, 1 },
				at = { 0, 0, 0 },
				rot = { 0, 0, 0 },
				color = { 1, 2, 3 },
				material = "Neon",
				transparency = 0,
				light = { kind = "SpotLight", brightness = 2.0004, range = 16, color = { 255, 200, 100 }, angle = 45 },
			},
		}))
		assert(find(src, 'kind = "SpotLight"'), src)
		assert(find(src, "angle = 45"), src)
	end)

	test("unsupported items are returned, not dropped", function()
		local _, unsupported = convert(dump({
			{
				class = "Part",
				shape = "Block",
				size = { 1, 1, 1 },
				at = { 0, 0, 0 },
				rot = { 0, 0, 0 },
				color = { 1, 2, 3 },
				material = "Plastic",
				transparency = 0,
			},
		}, { "UnionOperation Model.Base" }))
		assert(#unsupported == 1 and unsupported[1] == "UnionOperation Model.Base", "unsupported list lost")
	end)

	test("hostile strings stay inert and bad ids drop the part", function()
		local src, unsupported = convert(dump({
			{
				class = "MeshPart",
				size = { 1, 1, 1 },
				at = { 0, 0, 0 },
				rot = { 0, 0, 0 },
				color = { 1, 2, 3 },
				material = "Plastic",
				transparency = 0,
				meshId = "rbxassetid://1",
				textureId = 'x" .. (function() error("pwned") end)() .. "',
			},
			{
				class = "Part",
				shape = 'Block" .. error("pwned") .. "',
				size = { 1, 1, 1 },
				at = { 0, 0, 0 },
				rot = { 0, 0, 0 },
				color = { 1, 2, 3 },
				material = 'Brick" .. error("pwned") .. "',
				transparency = 0,
			},
		}))
		local ok, data = pcall(function()
			return luau.load(src)()
		end)
		assert(ok, `generated source ran code: {data}`)
		assert(#data.parts == 1, `expected the bad-id part dropped, got {#data.parts}`)
		assert(#unsupported == 1 and find(unsupported[1], "asset id"), table.concat(unsupported, "; "))
	end)

	test("output loads and validates", function()
		local src = convert(dump({
			{
				class = "Part",
				shape = "Cylinder",
				size = { 1, 4, 1 },
				at = { 0, 2, 0 },
				rot = { 0, 0, 90 },
				color = { 1, 2, 3 },
				material = "Metal",
				transparency = 0.25,
			},
			{
				class = "MeshPart",
				size = { 2, 2, 2 },
				at = { 0, 5, 0 },
				rot = { 0, 0, 0 },
				color = { 255, 255, 255 },
				material = "Plastic",
				transparency = 0,
				meshId = "rbxassetid://9",
			},
		}))
		local data = luau.load(src)()
		local errs = Art.validateModel("Lamp", data)
		assert(#errs == 0, table.concat(errs, "; "))
		assert(#data.parts == 2, "expected 2 parts")
	end)

	local function plain(extra: { [string]: any }): any
		local part: { [string]: any } = {
			class = "MeshPart",
			size = { 1, 1, 1 },
			at = { 0, 0, 0 },
			rot = { 0, 0, 0 },
			color = { 255, 255, 255 },
			material = "Plastic",
			transparency = 0,
			meshId = "rbxassetid://9",
		}
		for k, v in extra do
			part[k] = v
		end
		return part
	end

	test("surface round trip", function()
		local src = convert(dump({
			plain({ surface = { colorMap = "http://www.roblox.com/asset/?id=5", alphaMode = "Overlay" } }),
		}))
		assert(find(src, 'colorMap = "rbxassetid://5"'), src)
		assert(find(src, 'alphaMode = "Overlay"'), src)
		local errs = Art.validateModel("Lamp", luau.load(src)())
		assert(#errs == 0, table.concat(errs, "; "))
	end)

	test("decal round trip", function()
		local src = convert(dump({
			plain({
				decals = {
					{ face = "Front", texture = "rbxassetid://7", studsU = 2, studsV = 3, transparency = 0.5 },
					{ face = "Top", texture = "rbxassetid://8" },
				},
			}),
		}))
		assert(find(src, "studsU"), src)
		local data = luau.load(src)()
		assert(#data.parts[1].decals == 2, "expected 2 decals")
		local errs = Art.validateModel("Lamp", data)
		assert(#errs == 0, table.concat(errs, "; "))
	end)

	test("source written", function()
		local d = dump({ plain({}) })
		d.source = "generated"
		local src = convert(d)
		assert(find(src, 'source = "generated"'), src)
		d.source = "rbxassetid://12"
		assert(find(convert(d), 'source = "rbxassetid://12"'), "id source")
	end)

	test("effects are blocking", function()
		local _, unsupported, blocking =
			convert(dump({ plain({}) }, { "Beam Workspace.X.Beam", "Sound Workspace.X.S" }))
		assert(#unsupported == 2, "both reported")
		assert(blocking ~= nil and #blocking == 1 and find(blocking[1], "Beam"), "only the Beam blocks")
	end)

	test("only visual leftovers block", function()
		local _, _, blocking =
			convert(dump({ plain({}) }, { "ClickDetector W.C", "StringValue W.S", "ParticleEmitter W.P" }))
		assert(#blocking == 1 and find(blocking[1], "ParticleEmitter"), "only the emitter blocks")
	end)

	test("dropped part blocks", function()
		local _, _, blocking = convert(dump({ plain({ meshId = "bogus" }) }))
		assert(#blocking == 1, "bad asset id part must block")
	end)

	test("empty decal texture is skipped", function()
		local src, _, blocking = convert(dump({ plain({ decals = { { face = "Front", texture = "" } } }) }))
		assert(#blocking == 0 and not find(src, "decals"), src)
	end)

	test("decal with unknown-form texture blocks", function()
		local _, unsupported, blocking =
			convert(dump({ plain({ decals = { { face = "Front", texture = "rbxasset://x" } } }) }))
		assert(#unsupported == 1 and #blocking == 1, "part dropped with a blocking reason")
	end)
end
