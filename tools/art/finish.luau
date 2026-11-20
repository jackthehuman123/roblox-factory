--!strict
-- Studio-side ModuleScript: finish(tag, name, x, y, z) -> string. Takes the Model that generate_mesh tagged
-- `tag`, names it and its parts (<name>_1, <name>_2, ...), empties Workspace.Workshop and moves it there as
-- <name>, turns it 90° about Y when its width and depth fit the criteria size (x, z) better that way, scales it
-- so its height is `y` studs, pivots it at its bottom centre on the origin, and dumps it with ArtDump.
-- The asset workshop syncs it as ServerStorage.ArtFinish, so in execute_luau (Edit):
--   return require(game.ServerStorage.ArtFinish:Clone())("Assistant-<guid>", "MyModel", 1, 2.2, 1)
-- (:Clone() because Studio caches require for the session, so an edited module would not be picked up.)
-- Returns "ERROR <why>" (nothing changed) or two lines: "CAMERA px,py,pz lx,ly,lz" then the "ARTDUMP ..." line.
-- Not part of any game.

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

local CAMERA_DISTANCE = 1.6 -- times the largest extent
local CAMERA_MIN = 3 -- studs

-- World-space axis-aligned box around every BasePart in the model.
local function box(model: Model): (Vector3, Vector3)
	local min = Vector3.new(math.huge, math.huge, math.huge)
	local max = -min
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local cf, half = d.CFrame, d.Size / 2
			local extent = Vector3.new(
				math.abs(cf.XVector.X) * half.X + math.abs(cf.YVector.X) * half.Y + math.abs(cf.ZVector.X) * half.Z,
				math.abs(cf.XVector.Y) * half.X + math.abs(cf.YVector.Y) * half.Y + math.abs(cf.ZVector.Y) * half.Z,
				math.abs(cf.XVector.Z) * half.X + math.abs(cf.YVector.Z) * half.Y + math.abs(cf.ZVector.Z) * half.Z
			)
			min = min:Min(cf.Position - extent)
			max = max:Max(cf.Position + extent)
		end
	end
	return min, max
end

local function fmt(v: Vector3): string
	return string.format("%.2f,%.2f,%.2f", v.X, v.Y, v.Z)
end

return function(tag: string, name: string, x: number, height: number, z: number): string
	if type(name) ~= "string" or string.match(name, "^[A-Z][A-Za-z0-9]*$") == nil then
		return `ERROR name must be PascalCase letters and digits`
	end
	for _, v in { x, height, z } do
		if type(v) ~= "number" or not (v > 0) then
			return `ERROR size x, y, z must be numbers > 0`
		end
	end
	local models: { Model } = {}
	for _, inst in CollectionService:GetTagged(tag) do
		if inst:IsA("Model") then
			table.insert(models, inst)
		end
	end
	if #models ~= 1 then
		return `ERROR {#models} models tagged {tag}, need exactly 1`
	end
	local model = models[1]
	local hasPart = false
	for _, d in model:GetDescendants() do
		hasPart = hasPart or d:IsA("BasePart")
	end
	if not hasPart then
		return `ERROR model tagged {tag} has no parts`
	end

	local workshop = workspace:FindFirstChild("Workshop")
	if workshop == nil then
		workshop = Instance.new("Folder")
		workshop.Name = "Workshop"
		workshop.Parent = workspace
	end
	for _, other in (workshop :: Instance):GetChildren() do
		if other ~= model then
			other:Destroy()
		end
	end
	model.Name = name
	local n = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
			d.Name = `{name}_{n}`
		end
	end
	model.Parent = workshop

	local min, max = box(model)
	local k = height / (max.Y - min.Y) -- compare at the size it will have after scaling
	local sx, sz = (max.X - min.X) * k, (max.Z - min.Z) * k
	if math.abs(sx - x) + math.abs(sz - z) > math.abs(sz - x) + math.abs(sx - z) then
		model:PivotTo(model:GetPivot() * CFrame.Angles(0, math.rad(90), 0))
		min, max = box(model)
	end
	model:ScaleTo(model:GetScale() * height / (max.Y - min.Y))
	min, max = box(model)
	model.PrimaryPart = nil
	model.WorldPivot = CFrame.new((min.X + max.X) / 2, min.Y, (min.Z + max.Z) / 2)
	model:PivotTo(CFrame.new())

	min, max = box(model)
	local size = max - min
	local centre = (min + max) / 2
	local distance = math.max(CAMERA_MIN, CAMERA_DISTANCE * math.max(size.X, size.Y, size.Z))
	local camera = centre + Vector3.new(-1, 0.7, -1).Unit * distance

	local dump = require(ServerStorage:WaitForChild("ArtDump") :: ModuleScript) :: any
	return `CAMERA {fmt(camera)} {fmt(centre)}\n{dump(`Workspace.Workshop.{name}`)}`
end
