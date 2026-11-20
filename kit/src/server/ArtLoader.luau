--!strict
-- Rebuilds art models from plain data (ServerStorage.Art) and places them in the world.
-- Art never affects gameplay: no collision, queries or touches. All-or-nothing on invalid data.
-- Art folder layout: ModuleScript "placements" + Folder "models" of ModuleScripts named after each model.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Art = require(ReplicatedStorage.Kit.Art)
local ArtBuild = require(script.Parent.ArtBuild)
local ArtFit = require(ReplicatedStorage.Kit.ArtFit)
local ArtPlacement = require(ReplicatedStorage.Kit.ArtPlacement)

local ArtLoader = {}

-- Copies that follow a base. Art stays anchored (no welds): setting a base's Position re-welds
-- instead of dragging welded parts, and a base can change Anchored at any time.
type Follower = { copy: Model, base: BasePart, offset: CFrame, last: CFrame }
local followers: { Follower } = {}

local function follow(f: Follower)
	local target = f.base.CFrame
	if target ~= f.last then
		f.last = target
		f.copy:PivotTo(target * f.offset)
	end
end

-- Physics moves unanchored bases without firing CFrame signals, so they are followed every frame.
RunService.Heartbeat:Connect(function()
	for i = #followers, 1, -1 do
		local f = followers[i]
		if f.copy.Parent ~= f.base then
			table.remove(followers, i)
		elseif not f.base.Anchored then
			follow(f)
		end
	end
end)

local function attach(template: Model, base: BasePart, placement: ArtPlacement.Placement, box: ArtFit.Box3?): number
	if base:FindFirstChild(`Art_{template.Name}`) ~= nil then
		return 0
	end
	local copy = template:Clone()
	copy.Name = `Art_{template.Name}`
	local o = placement.offset or { 0, 0, 0 }
	local oy = o[2]
	if placement.sit ~= nil and box ~= nil then
		oy += ArtFit.sitY(placement.sit, base.Size.Y, box)
	end
	local f: Follower = { copy = copy, base = base, offset = CFrame.new(o[1], oy, o[3]), last = base.CFrame }
	copy:PivotTo(base.CFrame * f.offset)
	local count = 0
	for _, d in copy:GetDescendants() do
		if d:IsA("BasePart") then
			count += 1
		end
	end
	-- Scripted moves (Position or CFrame) fire this whether or not the base is anchored.
	local conn = base:GetPropertyChangedSignal("CFrame"):Connect(function()
		follow(f)
	end)
	copy.AncestryChanged:Connect(function()
		if copy.Parent ~= base then
			conn:Disconnect()
		end
	end)
	table.insert(followers, f)
	if placement.hideBase then
		base.Transparency = 1
	end
	copy.Parent = base
	return count
end

local function requireAll(artFolder: Instance): (any, { [string]: any }, { string })
	local problems: { string } = {}
	local placements: any = {}
	local models: { [string]: any } = {}
	local pm = artFolder:FindFirstChild("placements")
	if pm ~= nil and pm:IsA("ModuleScript") then
		local ok, res = pcall(require, pm)
		if ok then
			placements = res
		else
			table.insert(problems, `placements: cannot load: {res}`)
		end
	end
	local folder = artFolder:FindFirstChild("models")
	if folder ~= nil then
		for _, m in folder:GetChildren() do
			if m:IsA("ModuleScript") then
				local ok, res = pcall(require, m)
				if ok then
					models[m.Name] = res
				else
					table.insert(problems, `model {m.Name}: cannot load: {res}`)
				end
			end
		end
	end
	return placements, models, problems
end

function ArtLoader.load(artFolder: Instance, parent: Instance): (number, { string })
	local placements, models, problems = requireAll(artFolder)
	if #problems > 0 then
		return 0, problems
	end
	local tagCounts: { [string]: number } = {}
	for _, pl in placements do
		if type(pl) == "table" and type(pl.onTag) == "string" then
			tagCounts[pl.onTag] = #CollectionService:GetTagged(pl.onTag)
		end
	end
	for name, data in models do
		for _, e in Art.validateModel(name, data, ArtBuild.checkSurfaces) do
			table.insert(problems, e)
		end
	end
	for _, e in ArtPlacement.validatePlacements(placements, models, tagCounts) do
		table.insert(problems, e)
	end
	if #problems > 0 then
		return 0, problems
	end

	local templates: { [string]: Model } = {}
	local boxes: { [string]: ArtFit.Box3 } = {}
	for name, data in models do
		boxes[name] = ArtFit.modelBox(data)
		templates[name] = ArtBuild.buildTemplate(name, data, problems)
	end

	local old = parent:FindFirstChild("Art")
	if old ~= nil then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Art"
	local count = 0
	-- onTag first so hideBase is applied before any floor ray; floor rays then match ArtFit.hidden.
	for pass = 1, 2 do
		for i, pl in placements :: { ArtPlacement.Placement } do
			if (pl.onTag ~= nil) ~= (pass == 1) then
				continue
			end
			local template = templates[pl.model]
			local box = boxes[pl.model]
			if pl.at ~= nil then
				local copy = template:Clone()
				local y = pl.at[2]
				if pl.sit == "floor" then
					local floor = ArtBuild.floorHit(parent, pl.at[1], pl.at[2], pl.at[3])
					if floor ~= nil then
						y = floor + ArtFit.LIFT - box.min[2]
					else
						table.insert(problems, `placement {i}: no floor under sit = "floor"`)
					end
				end
				copy:PivotTo(CFrame.new(pl.at[1], y, pl.at[3]) * CFrame.Angles(0, math.rad(pl.rot or 0), 0))
				copy.Parent = folder
				count += #copy:GetChildren()
			elseif pl.onTag ~= nil then
				local function onAdded(inst: Instance)
					if not inst:IsA("BasePart") then
						return
					end
					if inst:IsDescendantOf(workspace) then
						attach(template, inst, pl, box)
						return
					end
					-- Tagged before being parented: attach once it enters the workspace.
					local conn: RBXScriptConnection
					conn = inst.AncestryChanged:Connect(function()
						if inst:IsDescendantOf(workspace) then
							conn:Disconnect()
							attach(template, inst, pl, box)
						elseif inst.Parent == nil then
							conn:Disconnect()
						end
					end)
				end
				for _, inst in CollectionService:GetTagged(pl.onTag) do
					if inst:IsA("BasePart") and inst:IsDescendantOf(workspace) then
						count += attach(template, inst, pl, box)
					else
						onAdded(inst) -- tagged but outside workspace: attach once it enters
					end
				end
				CollectionService:GetInstanceAddedSignal(pl.onTag):Connect(onAdded)
			end
		end
	end
	folder.Parent = parent
	return count, problems
end

return ArtLoader
