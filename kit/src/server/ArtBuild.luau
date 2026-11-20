--!strict
-- Builds one art part (and its light) from plain data. Art never affects gameplay: no collision, queries or touches.

local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Art = require(ReplicatedStorage.Kit.Art)
local ArtFit = require(ReplicatedStorage.Kit.ArtFit)
local ArtSurface = require(ReplicatedStorage.Kit.ArtSurface)

local ArtBuild = {}

local function color3(c: { number }?): Color3?
	if c == nil then
		return nil
	end
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function addLight(part: BasePart, l: Art.LightData)
	local color = color3(l.color) or Color3.new(1, 1, 1)
	if l.kind == "SpotLight" then
		local spot = Instance.new("SpotLight")
		spot.Angle = l.angle or 90
		spot.Face = Enum.NormalId.Bottom
		spot.Brightness = l.brightness
		spot.Range = l.range
		spot.Color = color
		spot.Parent = part
	else
		local point = Instance.new("PointLight")
		point.Brightness = l.brightness
		point.Range = l.range
		point.Color = color
		point.Parent = part
	end
end

local function addSurface(mesh: MeshPart, sf: ArtSurface.SurfaceData)
	local sa = Instance.new("SurfaceAppearance")
	if sf.colorMap ~= nil then
		sa.ColorMapContent = Content.fromUri(sf.colorMap)
	end
	if sf.normalMap ~= nil then
		sa.NormalMapContent = Content.fromUri(sf.normalMap)
	end
	if sf.roughnessMap ~= nil then
		sa.RoughnessMapContent = Content.fromUri(sf.roughnessMap)
	end
	if sf.metalnessMap ~= nil then
		sa.MetalnessMapContent = Content.fromUri(sf.metalnessMap)
	end
	sa.Color = color3(sf.color) or sa.Color
	if sf.alphaMode ~= nil then
		sa.AlphaMode = (Enum.AlphaMode :: any)[sf.alphaMode]
	end
	sa.Parent = mesh
end

local function addDecal(part: BasePart, d: ArtSurface.DecalData)
	local tiled = d.studsU ~= nil and d.studsV ~= nil
	local decal: Decal = if tiled then Instance.new("Texture") else Instance.new("Decal")
	decal.Face = (Enum.NormalId :: any)[d.face]
	decal.Texture = d.texture
	decal.Color3 = color3(d.color) or decal.Color3
	decal.Transparency = d.transparency or 0
	if tiled then
		local tex = decal :: any
		tex.StudsPerTileU = d.studsU
		tex.StudsPerTileV = d.studsV
	end
	decal.Parent = part
end

local function makePart(p: Art.PartData): (BasePart?, string?)
	local part: BasePart
	if p.meshId ~= nil then
		local meshId = p.meshId
		local ok, res = pcall(function()
			return AssetService:CreateMeshPartAsync(Content.fromUri(meshId))
		end)
		if not ok then
			return nil, `mesh failed: {res}`
		end
		local mesh = res :: MeshPart
		if p.textureId ~= nil then
			mesh.TextureID = p.textureId
		end
		part = mesh
	else
		local block = Instance.new("Part")
		block.Shape = (Enum.PartType :: any)[p.shape or "Block"]
		block.TopSurface = Enum.SurfaceType.Smooth
		block.BottomSurface = Enum.SurfaceType.Smooth
		part = block
	end
	part.Size = Vector3.new(p.size[1], p.size[2], p.size[3])
	local r = p.rot or { 0, 0, 0 }
	part.CFrame = CFrame.new(p.at[1], p.at[2], p.at[3])
		* CFrame.fromOrientation(math.rad(r[1]), math.rad(r[2]), math.rad(r[3]))
	part.Color = color3(p.color) or part.Color
	part.Material = (Enum.Material :: any)[p.material or "Plastic"]
	part.Transparency = p.transparency or 0
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	if p.surface ~= nil and part:IsA("MeshPart") then
		addSurface(part, p.surface)
	end
	if p.decals ~= nil then
		for _, d in p.decals do
			addDecal(part, d)
		end
	end
	if p.light ~= nil then
		addLight(part, p.light)
	end
	return part, nil
end

ArtBuild.makePart = makePart

function ArtBuild.checkSurfaces(part: any, add: (string) -> ())
	if part.surface ~= nil then
		ArtSurface.checkSurface(part.surface, add)
	end
	if part.decals ~= nil then
		ArtSurface.checkDecals(part.decals, add)
	end
end

-- Y of the first visible Graybox surface under (x, z), or nil.
function ArtBuild.floorHit(parent: Instance, x: number, y: number, z: number): number?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { parent:FindFirstChild("Graybox") or workspace }
	local from = y + ArtFit.FLOOR_SLOP
	for _ = 1, 20 do
		local hit = workspace:Raycast(Vector3.new(x, from, z), Vector3.new(0, -ArtFit.FLOOR_RAY, 0), params)
		if hit == nil then
			return nil
		end
		if hit.Instance.Transparency < 1 then
			return hit.Position.Y
		end
		from = hit.Position.Y - 0.01
	end
	return nil
end

-- Template models are built at the origin (pivot = identity).
function ArtBuild.buildTemplate(name: string, data: Art.ModelData, problems: { string }): Model
	local model = Instance.new("Model")
	model.Name = name
	for i, p in data.parts do
		local part, err = ArtBuild.makePart(p)
		if part == nil then
			table.insert(problems, `model {name}: part {i}: {err}`)
		else
			part.Name = `Part{i}`
			part.Parent = model
		end
	end
	model.WorldPivot = CFrame.identity
	-- A PrimaryPart keeps the pivot moving with physics; its PivotOffset puts the pivot at the model origin.
	local first = model:FindFirstChildWhichIsA("BasePart")
	if first ~= nil then
		first.PivotOffset = first.CFrame:Inverse()
		model.PrimaryPart = first
	end
	return model
end

return ArtBuild
