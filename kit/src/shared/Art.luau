--!strict
-- Validates art data: model files (plain-data parts) and placements. Returns every problem found.
-- Pure: no Roblox services or datatypes, so Lune and tools/art_check can run it.

local Art = {}

export type SurfaceData = {
	colorMap: string?,
	normalMap: string?,
	roughnessMap: string?,
	metalnessMap: string?,
	color: { number }?,
	alphaMode: string?,
}

export type DecalData = {
	face: string,
	texture: string,
	color: { number }?,
	transparency: number?,
	studsU: number?,
	studsV: number?,
}

export type LightData = {
	kind: string, -- "PointLight" | "SpotLight"
	brightness: number,
	range: number,
	color: { number }?,
	angle: number?, -- SpotLight only, degrees
}

export type PartData = {
	shape: string?, -- "Block" | "Ball" | "Cylinder" | "Wedge"; ignored when meshId is set
	size: { number },
	at: { number }, -- offset from the model pivot
	rot: { number }?, -- degrees X, Y, Z (CFrame.fromOrientation)
	color: { number }?,
	material: string?,
	transparency: number?,
	meshId: string?, -- "rbxassetid://<digits>" builds a MeshPart
	textureId: string?,
	light: LightData?,
	surface: SurfaceData?,
	decals: { DecalData }?,
}

export type ModelData = {
	parts: { PartData },
	source: string?, -- "rbxassetid://<digits>" or "generated"
}

export type Placement = {
	model: string,
	at: { number }?,
	rot: number?, -- yaw degrees, fixed placements
	onTag: string?,
	offset: { number }?,
	hideBase: boolean?,
	sit: string?, -- onTag: "top" | "base" | "under"; at: "floor"
	allow: { string }?, -- placement check rules to skip
}

Art.MAX_PARTS = 3000
Art.RULES = { "doubled", "sunk", "flush", "floating", "overlap" }

local MATERIAL_NAMES = table.concat({
	"Plastic SmoothPlastic Neon Wood WoodPlanks Marble Slate Concrete Granite Brick Pebble",
	"Cobblestone Rock Sandstone Basalt CrackedLava Asphalt LeafyGrass Salt Limestone Pavement",
	"CorrodedMetal DiamondPlate Foil Metal Grass Sand Fabric Snow Mud Ground Ice Glacier Glass",
	"ForceField Cardboard Carpet CeramicTiles ClayRoofTiles RoofShingles Leather Plaster Rubber",
}, " ")

Art.MATERIALS = {} :: { [string]: boolean }
for m in string.gmatch(MATERIAL_NAMES, "%S+") do
	Art.MATERIALS[m] = true
end

local SHAPES = { Block = true, Ball = true, Cylinder = true, Wedge = true }
local LIGHTS = { PointLight = true, SpotLight = true }

local function isNumber(v: any): boolean
	return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

local function isTriple(v: any, ok: (number) -> boolean): boolean
	if type(v) ~= "table" or #v ~= 3 then
		return false
	end
	for i = 1, 3 do
		if not isNumber(v[i]) or not ok(v[i]) then
			return false
		end
	end
	return true
end

local function any(): boolean
	return true
end

local function positive(n: number): boolean
	return n > 0
end

local function byte(n: number): boolean
	return n >= 0 and n <= 255
end

local function isAssetId(v: any): boolean
	return type(v) == "string" and string.match(v, "^rbxassetid://%d+$") ~= nil
end

local function checkLight(l: any, add: (string) -> ())
	if type(l) ~= "table" then
		add("light must be a table")
		return
	end
	if not LIGHTS[l.kind] then
		add(`light kind {tostring(l.kind)} not allowed`)
	end
	if not isNumber(l.brightness) or l.brightness < 0 then
		add("light brightness must be a number >= 0")
	end
	if not isNumber(l.range) or l.range < 0 or l.range > 60 then
		add("light range must be 0-60")
	end
	if l.color ~= nil and not isTriple(l.color, byte) then
		add("light color must be 3 numbers 0-255")
	end
	if l.angle ~= nil and (not isNumber(l.angle) or l.angle < 0 or l.angle > 180) then
		add("light angle must be 0-180")
	end
end

local function checkPart(p: any, add: (string) -> (), checkExtra: ((any, (string) -> ()) -> ())?)
	if type(p) ~= "table" then
		add("must be a table")
		return
	end
	if not isTriple(p.size, positive) then
		add("size must be 3 numbers > 0")
	end
	if not isTriple(p.at, any) then
		add("at must be 3 numbers")
	end
	if p.rot ~= nil and not isTriple(p.rot, any) then
		add("rot must be 3 numbers")
	end
	if p.shape ~= nil and not SHAPES[p.shape] then
		add(`shape {tostring(p.shape)} not allowed`)
	end
	if p.color ~= nil and not isTriple(p.color, byte) then
		add("color must be 3 numbers 0-255")
	end
	if p.material ~= nil and not Art.MATERIALS[p.material] then
		add(`material {tostring(p.material)} not allowed`)
	end
	if p.transparency ~= nil and (not isNumber(p.transparency) or p.transparency < 0 or p.transparency > 1) then
		add("transparency must be 0-1")
	end
	if p.meshId ~= nil and not isAssetId(p.meshId) then
		add("meshId must be rbxassetid://<digits>")
	end
	if p.textureId ~= nil then
		if p.meshId == nil then
			add("textureId needs meshId")
		elseif not isAssetId(p.textureId) then
			add("textureId must be rbxassetid://<digits>")
		end
	end
	if p.light ~= nil then
		checkLight(p.light, add)
	end
	if p.surface ~= nil and p.meshId == nil then
		add("surface needs meshId")
	end
	if checkExtra ~= nil then
		checkExtra(p, add)
	end
end

function Art.validateModel(
	name: string,
	model: ModelData,
	checkExtra: ((part: any, add: (string) -> ()) -> ())?
): { string }
	local errs: { string } = {}
	if type(name) ~= "string" or string.match(name, "^[A-Z][A-Za-z0-9]*$") == nil then
		table.insert(errs, `model {tostring(name)}: name must match ^[A-Z][A-Za-z0-9]*$`)
	end
	local m: any = model
	if type(m) ~= "table" or type(m.parts) ~= "table" or #m.parts == 0 then
		table.insert(errs, `model {tostring(name)}: parts must be a non-empty list`)
		return errs
	end
	if m.source ~= nil and m.source ~= "generated" and not isAssetId(m.source) then
		table.insert(errs, `model {name}: source must be generated or rbxassetid://<digits>`)
	end
	for i, p in m.parts do
		checkPart(p, function(msg: string)
			table.insert(errs, `model {name}: part {i}: {msg}`)
		end, checkExtra)
	end
	return errs
end

return Art
