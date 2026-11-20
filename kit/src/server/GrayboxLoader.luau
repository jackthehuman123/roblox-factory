--!strict
-- Builds anchored Parts from graybox data into a "Graybox" folder under parent.
-- All-or-nothing: if any box is invalid, nothing changes and every problem is returned.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Graybox = require(ReplicatedStorage.Kit.Graybox)

local GrayboxLoader = {}

local DEFAULT_COLOR = { 163, 162, 165 }

local function makePart(i: number, box: Graybox.Box): Part
	local part = Instance.new("Part")
	part.Name = `Box{i}`
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Size = Vector3.new(box.size[1], box.size[2], box.size[3])
	-- rot is a yaw in degrees around the Y axis.
	part.CFrame = CFrame.new(box.at[1], box.at[2], box.at[3]) * CFrame.Angles(0, math.rad(box.rot or 0), 0)
	local c = box.color or DEFAULT_COLOR
	part.Color = Color3.fromRGB(c[1], c[2], c[3])
	part.Material = (Enum.Material :: any)[box.material or "SmoothPlastic"]
	local tags = box.tags
	if tags ~= nil then
		for _, tag in tags do
			CollectionService:AddTag(part, tag)
		end
	end
	return part
end

function GrayboxLoader.load(boxes: { Graybox.Box }, parent: Instance): (number, { string })
	local errs = Graybox.validate(boxes)
	if #errs > 0 then
		return 0, errs
	end

	local old = parent:FindFirstChild("Graybox")
	if old ~= nil then
		old:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = "Graybox"
	for i, box in boxes do
		makePart(i, box).Parent = folder
	end
	folder.Parent = parent
	return #boxes, {}
end

return GrayboxLoader
