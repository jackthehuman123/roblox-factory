--!strict
-- Studio-side snippet: paste into execute_luau (Edit DataModel) in the workshop place.
-- Rebuilds assets into Workspace.Showcase in a row along +X (4 studs between bounding boxes),
-- each with a name label 1 stud above it. Returns one line per asset: SHOW <Name> at x,y,z
-- NAMES empty = every unreviewed entry in AssetIndex. CLEAR = true deletes Workspace.Showcase.
-- Not part of any game; Rojo never syncs tools/.

local NAMES: { string } = {} -- edit me: asset names, or empty for all unreviewed
local CLEAR = false -- true: delete Showcase and stop

local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local old = workspace:FindFirstChild("Showcase")
if old ~= nil then
	old:Destroy()
end
if CLEAR then
	return "SHOWCASE cleared"
end

local ArtBuild = require(ServerScriptService.Kit.ArtBuild) :: any
local index = require(ServerStorage.AssetIndex :: ModuleScript) :: any
local library = ServerStorage.Library

local wanted: { string } = NAMES
if #wanted == 0 then
	for _, entry in index do
		if entry.review == "unreviewed" then
			table.insert(wanted, entry.name)
		end
	end
end

if #wanted == 0 then
	return "SHOWCASE empty"
end

local folder = Instance.new("Folder")
folder.Name = "Showcase"
folder.Parent = workspace

local lines: { string } = {}
local cursor = 0 -- left edge of the next bounding box
for _, name in wanted do
	local mod = library:FindFirstChild(name)
	if mod == nil or not mod:IsA("ModuleScript") then
		table.insert(lines, `SKIP {name} no library model`)
		continue
	end
	local problems: { string } = {}
	local built, result = pcall(function(): Model
		return ArtBuild.buildTemplate(name, require(mod) :: any, problems)
	end)
	if not built then
		table.insert(lines, `FAIL {name}: {result}`)
		continue
	end
	local model = result :: Model
	for _, p in problems do
		table.insert(lines, `WARN {name}: {p}`)
	end
	model.Parent = folder
	model:PivotTo(CFrame.new(0, 0, 0)) -- pivot is the bottom centre
	local box0, size0 = model:GetBoundingBox()
	model:PivotTo(CFrame.new(cursor - (box0.Position.X - size0.X / 2), 0, 0)) -- left edge at cursor
	local boxCf, boxSize = model:GetBoundingBox()

	local anchor = Instance.new("Part")
	anchor.Name = "Label"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Position = boxCf.Position + Vector3.new(0, boxSize.Y / 2 + 1.5, 0)
	anchor.Parent = model
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(160, 30)
	gui.AlwaysOnTop = true
	gui.Adornee = anchor
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = name
	label.Parent = gui

	local pos = model:GetPivot().Position
	table.insert(lines, string.format("SHOW %s at %.2f,%.2f,%.2f", name, pos.X, pos.Y, pos.Z))
	cursor += boxSize.X + 4
end
return table.concat(lines, "\n")
