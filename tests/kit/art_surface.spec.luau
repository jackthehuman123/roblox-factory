--!strict
local ArtSurface = require("../../kit/src/shared/ArtSurface")

local function run(check: (any, (string) -> ()) -> (), v: any): string
	local errs: { string } = {}
	check(v, function(m: string)
		table.insert(errs, m)
	end)
	return table.concat(errs, "; ")
end

return function(test: (name: string, fn: () -> ()) -> ())
	test("valid surface passes", function()
		local r = run(ArtSurface.checkSurface, {
			colorMap = "rbxassetid://1",
			normalMap = "rbxassetid://2",
			color = { 255, 255, 255 },
			alphaMode = "TintMask",
		})
		assert(r == "", r)
	end)
	test("bad map id fails", function()
		local r = run(ArtSurface.checkSurface, { colorMap = "http://x" })
		assert(string.find(r, "colorMap", 1, true) and not string.find(r, ";", 1, true), r)
	end)
	test("bad alphaMode fails", function()
		local r = run(ArtSurface.checkSurface, { alphaMode = "Glow" })
		assert(string.find(r, "alphaMode", 1, true), r)
	end)
	test("decal needs face and texture", function()
		local r = run(ArtSurface.checkDecals, { { face = "Top" } })
		assert(string.find(r, "texture", 1, true), r)
		local r2 = run(ArtSurface.checkDecals, { { texture = "rbxassetid://3" } })
		assert(string.find(r2, "face", 1, true), r2)
	end)
	test("studsU without studsV fails", function()
		local r = run(ArtSurface.checkDecals, { { face = "Top", texture = "rbxassetid://3", studsU = 2 } })
		assert(string.find(r, "studsV", 1, true), r)
	end)
	test("valid texture passes", function()
		local r =
			run(ArtSurface.checkDecals, { { face = "Front", texture = "rbxassetid://3", studsU = 2, studsV = 2 } })
		assert(r == "", r)
	end)
	test("Up is not a NormalId", function()
		local r = run(ArtSurface.checkDecals, { { face = "Up", texture = "rbxassetid://3" } })
		assert(string.find(r, "face", 1, true), r)
	end)
end
