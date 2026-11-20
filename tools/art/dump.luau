--!strict
-- Studio-side ModuleScript: returns dump(modelPath) -> one line "ARTDUMP <json>" describing the model as art data
-- (positions relative to its pivot). The asset workshop syncs it as ServerStorage.ArtDump, so in execute_luau (Edit):
--   return require(game.ServerStorage.ArtDump)("Workspace.Workshop.MyModel")
-- Save that line to a file and run: lune run tools/art_import ... <file> <source>
-- Not part of any game.

local AssetService = game:GetService("AssetService")
local HttpService = game:GetService("HttpService")

local function resolve(path: string): Instance
	local node: Instance = game
	for segment in string.gmatch(path, "[^%.]+") do
		local child = node:FindFirstChild(segment)
		assert(child ~= nil, `no {segment} under {node:GetFullName()}`)
		node = child
	end
	return node
end

-- Classes that carry no look of their own and are fine to skip.
local IGNORED = {
	Model = true,
	Folder = true,
	Attachment = true,
	Camera = true, -- store thumbnails
	WeldConstraint = true,
	Weld = true,
	Motor6D = true,
	SpecialMesh = true,
}

-- Lights copied into a part's data; every other Light is reported as unsupported.
local recorded: { [Instance]: boolean } = {}

local function v3(v: Vector3): { number }
	return { v.X, v.Y, v.Z }
end

local function light(part: BasePart): any
	local l = part:FindFirstChildWhichIsA("Light")
	if l == nil then
		return nil
	end
	if l:IsA("SpotLight") then
		if l.Face ~= Enum.NormalId.Bottom then
			return nil -- the loader always points SpotLights down; report others instead
		end
		recorded[l] = true
		return {
			kind = "SpotLight",
			brightness = l.Brightness,
			range = l.Range,
			color = { l.Color.R * 255, l.Color.G * 255, l.Color.B * 255 },
			angle = l.Angle,
		}
	elseif l:IsA("PointLight") then
		recorded[l] = true
		return {
			kind = "PointLight",
			brightness = l.Brightness,
			range = l.Range,
			color = { l.Color.R * 255, l.Color.G * 255, l.Color.B * 255 },
		}
	end
	return nil
end

local function mapUri(content: Content, legacy: string): string?
	if content.Uri ~= nil and content.Uri ~= "" then
		return content.Uri
	end
	if legacy ~= "" then
		return legacy
	end
	return nil
end

local function legacy(sa: SurfaceAppearance, prop: string): string
	local ok, v = pcall(function()
		return (sa :: any)[prop]
	end)
	return if ok and type(v) == "string" then v else ""
end

local function surface(part: BasePart): any
	local sa = part:FindFirstChildOfClass("SurfaceAppearance")
	if sa == nil or not part:IsA("MeshPart") then
		return nil
	end
	recorded[sa] = true
	return {
		colorMap = mapUri(sa.ColorMapContent, legacy(sa, "ColorMap")),
		normalMap = mapUri(sa.NormalMapContent, legacy(sa, "NormalMap")),
		roughnessMap = mapUri(sa.RoughnessMapContent, legacy(sa, "RoughnessMap")),
		metalnessMap = mapUri(sa.MetalnessMapContent, legacy(sa, "MetalnessMap")),
		color = { sa.Color.R * 255, sa.Color.G * 255, sa.Color.B * 255 },
		alphaMode = sa.AlphaMode.Name,
	}
end

local function decals(part: BasePart): any
	local list = {}
	for _, c in part:GetChildren() do
		if c:IsA("Decal") or c:IsA("Texture") then -- Texture is a Decal subclass
			recorded[c] = true
			local item: any = {
				face = c.Face.Name,
				texture = c.Texture,
				color = { c.Color3.R * 255, c.Color3.G * 255, c.Color3.B * 255 },
				transparency = c.Transparency,
			}
			if c:IsA("Texture") then
				item.studsU = c.StudsPerTileU
				item.studsV = c.StudsPerTileV
			end
			table.insert(list, item)
		end
	end
	return if #list > 0 then list else nil
end

local function dump(modelPath: string): string
	table.clear(recorded)
	local model = resolve(modelPath)
	local pivot = if model:IsA("PVInstance") then model:GetPivot() else CFrame.identity
	local parts = {}
	local unsupported = {}
	local descendants = model:GetDescendants()
	if model:IsA("BasePart") then
		table.insert(descendants, 1, model)
	end

	for _, d in descendants do
		if d:IsA("Part") or d:IsA("MeshPart") or d:IsA("WedgePart") then
			local rel = pivot:ToObjectSpace(d.CFrame)
			local rx, ry, rz = rel:ToOrientation()
			local entry: any = {
				class = d.ClassName,
				size = v3(d.Size),
				at = v3(rel.Position),
				rot = { math.deg(rx), math.deg(ry), math.deg(rz) },
				color = { d.Color.R * 255, d.Color.G * 255, d.Color.B * 255 },
				material = d.Material.Name,
				transparency = d.Transparency,
			}
			if d:IsA("WedgePart") then
				entry.class = "Part"
				entry.shape = "Wedge"
			elseif d:IsA("MeshPart") then
				entry.meshId = d.MeshId
				entry.textureId = d.TextureID
			elseif d:IsA("Part") then
				entry.shape = d.Shape.Name
				local sm = d:FindFirstChildOfClass("SpecialMesh")
				if sm ~= nil then
					if sm.MeshType == Enum.MeshType.FileMesh and sm.MeshId ~= "" then
						-- A SpecialMesh renders at the mesh's native size times Scale; read the native size.
						local ok, res = pcall(function()
							return AssetService:CreateMeshPartAsync(Content.fromUri(sm.MeshId))
						end)
						if ok then
							entry.class = "MeshPart"
							entry.meshId = sm.MeshId
							entry.textureId = sm.TextureId
							entry.size = v3((res :: MeshPart).Size * sm.Scale)
							entry.at = v3(rel.Position + rel:VectorToWorldSpace(sm.Offset))
							res:Destroy()
						else
							table.insert(unsupported, `SpecialMesh {sm:GetFullName()} (mesh failed: {res})`)
							continue
						end
					else
						table.insert(unsupported, `SpecialMesh {sm.MeshType.Name} {sm:GetFullName()}`)
						continue
					end
				end
			end
			entry.surface = surface(d)
			entry.decals = decals(d)
			entry.light = light(d) -- only for parts that are kept, so dropped parts report their lights
			table.insert(parts, entry)
		end
	end

	-- Second pass, after every part's light is recorded.
	for _, d in descendants do
		local isPart = d:IsA("Part") or d:IsA("MeshPart") or d:IsA("WedgePart")
		if not isPart and not IGNORED[d.ClassName] and not recorded[d] then
			table.insert(unsupported, `{d.ClassName} {d:GetFullName()}`)
		end
	end

	local line = "ARTDUMP " .. HttpService:JSONEncode({ parts = parts, unsupported = unsupported })
	return line
end

return dump
