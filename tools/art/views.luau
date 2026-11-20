--!strict
-- Studio-side snippet: paste into execute_luau (Edit DataModel) after setting ITEMS (or CLEANUP).
-- Builds Workspace.ArtPreview (graybox + art) and prints one line per view:
--   VIEW <Name> <1-4> <px,py,pz> <lx,ly,lz>
-- Views: 1 eye level from -Z, 2 three-quarter left, 3 three-quarter right, 4 close from above.
-- Pass each position pair to screen_capture as camera_position / look_at_position.
-- Set CLEANUP = true to delete ArtPreview and do nothing else.
-- Not part of any game; Rojo never syncs tools/.

local ITEMS: { string } = { "MyModel" } -- edit me: model names from the art data
local CLEANUP = false -- true: delete ArtPreview and stop

local CollectionService = game:GetService("CollectionService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local function destroyPreview()
	local old = workspace:FindFirstChild("ArtPreview")
	if old ~= nil then
		old:Destroy()
	end
end

destroyPreview() -- always delete first: ArtLoader leaves connections, so a preview is never reloaded in place
if CLEANUP then
	print("ARTPREVIEW cleaned")
	return "ARTPREVIEW cleaned"
end

local preview = Instance.new("Folder")
preview.Name = "ArtPreview"
preview.Parent = workspace

local gameFolder = ServerScriptService:FindFirstChild("Game")
assert(gameFolder ~= nil, "no ServerScriptService.Game (is Rojo synced?)")
local graybox = gameFolder:FindFirstChild("graybox")
assert(graybox ~= nil and graybox:IsA("ModuleScript"), "no ServerScriptService.Game.graybox module")
local GrayboxLoader = require(ServerScriptService.Kit.GrayboxLoader) :: any
local ArtLoader = require(ServerScriptService.Kit.ArtLoader) :: any
local ArtBuild = require(ServerScriptService.Kit.ArtBuild) :: any

local artFolder = ServerStorage:FindFirstChild("Art")
assert(artFolder ~= nil, "no ServerStorage.Art")

-- require caches by instance, so load Clones: a re-run after Rojo changes the data sees the new data.
local grayClone = graybox:Clone()
grayClone.Parent = preview
local artData = artFolder:Clone()
artData.Name = "ArtData" -- not "Art": ArtLoader replaces preview.Art
artData.Parent = preview
artFolder = artData

local lines: { string } = {} -- returned at the end, so the caller need not read the shared console
local _, grayErrs = GrayboxLoader.load(require(grayClone :: ModuleScript) :: any, preview)
for _, e in grayErrs do
	warn(`graybox: {e}`)
	table.insert(lines, `WARN graybox: {e}`)
end
local _, artErrs = ArtLoader.load(artFolder, preview)
for _, e in artErrs do
	warn(`art: {e}`)
	table.insert(lines, `WARN art: {e}`)
end

local placements: any = require(artFolder:WaitForChild("placements") :: ModuleScript)
local floorY: number = ArtBuild.floorHit(preview, 0, 2, 0) or 0

-- The preview copy of an item: a placed copy, an attached onTag copy, or a fresh template copy at (0, floor, 0).
local function findCopy(name: string): Model?
	local art = preview:FindFirstChild("Art")
	local placed = if art ~= nil then art:FindFirstChild(name) else nil
	if placed ~= nil and placed:IsA("Model") then
		return placed
	end
	local tagged = false
	for _, pl in placements do
		if pl.model == name and type(pl.onTag) == "string" then
			for _, inst in CollectionService:GetTagged(pl.onTag) do
				if not inst:IsDescendantOf(preview) then
					continue
				end
				tagged = true
				local attached = inst:FindFirstChild(`Art_{name}`)
				if attached ~= nil and attached:IsA("Model") then
					return attached
				end
			end
		end
	end
	if tagged then
		return nil -- tagged parts exist but carry no copy; nothing sensible to view
	end
	local models = artFolder:FindFirstChild("models")
	local mod = if models ~= nil then models:FindFirstChild(name) else nil
	if mod == nil or not mod:IsA("ModuleScript") then
		return nil
	end
	local template: Model = ArtBuild.buildTemplate(name, require(mod) :: any, {})
	template:PivotTo(CFrame.new(0, floorY, 0))
	template.Parent = preview
	return template
end

-- First visible hit inside the preview along origin + dir, skipping `skip` and invisible parts.
local function cast(origin: Vector3, dir: Vector3, skip: Instance?, onlyGraybox: boolean): RaycastResult?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = if skip ~= nil then { skip } else {}
	local scope = if onlyGraybox then preview:FindFirstChild("Graybox") else preview
	local from = origin
	for _ = 1, 20 do
		local hit = workspace:Raycast(from, dir, params)
		if hit == nil then
			return nil
		end
		if hit.Instance.Transparency < 1 and scope ~= nil and hit.Instance:IsDescendantOf(scope) then
			return hit
		end
		local excluded = params.FilterDescendantsInstances
		table.insert(excluded, hit.Instance)
		params.FilterDescendantsInstances = excluded
		from = origin
	end
	return nil
end

local function fmt(v: Vector3): string
	return string.format("%.2f,%.2f,%.2f", v.X, v.Y, v.Z)
end

-- Pull the camera in front of whatever lies between the target and the wanted position.
local function clearCamera(target: Vector3, want: Vector3, skip: Instance): Vector3
	local delta = want - target
	local hit = cast(target, delta, skip, false)
	if hit ~= nil then
		local dir = delta.Unit
		return hit.Position - dir * 0.5
	end
	return want
end

local views: { { string } } = {}
for _, name in ITEMS do
	local copy = findCopy(name)
	if copy == nil then
		print(`NOVIEW {name} no copy to view`)
		table.insert(lines, `NOVIEW {name} no copy to view`)
		continue
	end
	local boxCf, boxSize = copy:GetBoundingBox()
	local center = boxCf.Position
	local dist = math.max(8, 1.5 * math.max(boxSize.X, boxSize.Y, boxSize.Z))
	-- Floor and ceiling come from the copy's own position, so eye level stays inside the space.
	local down = cast(center, Vector3.new(0, -500, 0), copy, true)
	local itemFloor = if down ~= nil then down.Position.Y else floorY
	local eye = itemFloor + 5
	local up = cast(center, Vector3.new(0, 500, 0), copy, true)
	if up ~= nil then
		eye = math.min(eye, up.Position.Y - 0.5)
	end
	local dirs: { Vector3 } = {
		Vector3.new(0, 0, -1),
		Vector3.new(-1, 0, -1).Unit,
		Vector3.new(1, 0, -1).Unit,
	}
	for i, d in dirs do
		local eyeTarget = Vector3.new(center.X, eye, center.Z)
		local pos = clearCamera(eyeTarget, eyeTarget + d * dist, copy)
		table.insert(views, { `VIEW {name} {i} {fmt(pos)} {fmt(center)}` })
	end
	local top = clearCamera(center, center + Vector3.new(0, dist, -dist * 0.2), copy)
	table.insert(views, { `VIEW {name} 4 {fmt(top)} {fmt(center)}` })
end

-- Let textures and meshes load before the judge captures anything (bounded).
local loaded = false
task.spawn(function()
	pcall(function()
		game:GetService("ContentProvider"):PreloadAsync(preview:GetDescendants())
	end)
	loaded = true
end)
local waited = 0
while not loaded and waited < 10 do
	waited += task.wait(0.1)
end
if not loaded then
	warn("preload timed out after 10s; textures may be missing")
	table.insert(lines, "WARN preload timed out after 10s; textures may be missing")
end

for _, v in views do
	print(v[1])
	table.insert(lines, v[1])
end
return table.concat(lines, "\n")
