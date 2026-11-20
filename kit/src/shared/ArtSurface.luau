--!strict
-- Validates part surface (PBR maps) and decal data. Pure; callers pass these checks to Art.validateModel.

local ArtSurface = {}

export type SurfaceData = {
	colorMap: string?,
	normalMap: string?,
	roughnessMap: string?,
	metalnessMap: string?,
	color: { number }?,
	alphaMode: string?, -- "Overlay" | "Transparency" | "TintMask" | "Opaque"
}

export type DecalData = {
	face: string, -- NormalId name
	texture: string,
	color: { number }?,
	transparency: number?,
	studsU: number?, -- studsU and studsV together make a Texture, else a Decal
	studsV: number?,
}

local ALPHA_MODES = { Overlay = true, Transparency = true, TintMask = true, Opaque = true }
local FACES = { Top = true, Bottom = true, Front = true, Back = true, Left = true, Right = true }
local MAPS = { "colorMap", "normalMap", "roughnessMap", "metalnessMap" }

local function isNumber(v: any): boolean
	return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

local function isAssetId(v: any): boolean
	return type(v) == "string" and string.match(v, "^rbxassetid://%d+$") ~= nil
end

local function isColor(v: any): boolean
	if type(v) ~= "table" or #v ~= 3 then
		return false
	end
	for i = 1, 3 do
		if not isNumber(v[i]) or v[i] < 0 or v[i] > 255 then
			return false
		end
	end
	return true
end

function ArtSurface.checkSurface(s: any, add: (string) -> ())
	if type(s) ~= "table" then
		add("surface must be a table")
		return
	end
	for _, key in MAPS do
		if s[key] ~= nil and not isAssetId(s[key]) then
			add(`surface {key} must be rbxassetid://<digits>`)
		end
	end
	if s.color ~= nil and not isColor(s.color) then
		add("surface color must be 3 numbers 0-255")
	end
	if s.alphaMode ~= nil and not ALPHA_MODES[s.alphaMode] then
		add(`surface alphaMode {tostring(s.alphaMode)} not allowed`)
	end
end

local function checkDecal(d: any, add: (string) -> ())
	if type(d) ~= "table" then
		add("must be a table")
		return
	end
	if not FACES[d.face] then
		add("face must be a NormalId name")
	end
	if not isAssetId(d.texture) then
		add("texture must be rbxassetid://<digits>")
	end
	if d.color ~= nil and not isColor(d.color) then
		add("color must be 3 numbers 0-255")
	end
	if d.transparency ~= nil and (not isNumber(d.transparency) or d.transparency < 0 or d.transparency > 1) then
		add("transparency must be 0-1")
	end
	for _, pair in { { "studsU", "studsV" }, { "studsV", "studsU" } } do
		local a, b = pair[1], pair[2]
		if d[a] ~= nil then
			if not isNumber(d[a]) or d[a] <= 0 then
				add(`{a} must be a number > 0`)
			elseif d[b] == nil then
				add(`{a} needs {b}`)
			end
		end
	end
end

function ArtSurface.checkDecals(d: any, add: (string) -> ())
	if type(d) ~= "table" then
		add("decals must be a list")
		return
	end
	for i, decal in d do
		checkDecal(decal, function(msg: string)
			add(`decal {i}: {msg}`)
		end)
	end
end

return ArtSurface
