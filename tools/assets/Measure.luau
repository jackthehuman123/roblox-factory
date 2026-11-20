--!strict
-- Measures a library model (plain art data) against its criteria. Pure: Lune-testable, no Roblox types.
local Art = require("../../kit/src/shared/Art")
local Criteria = require("./Criteria")
local Review = require("./Review")

local Measure = {}

export type Box = { min: { number }, max: { number } }

-- Rotation matrix for CFrame.fromOrientation(rx, ry, rz) (degrees): R = Ry · Rx · Rz.
local function rotation(rot: { number }): { { number } }
	local x, y, z = math.rad(rot[1]), math.rad(rot[2]), math.rad(rot[3])
	local cx, sx, cy, sy, cz, sz = math.cos(x), math.sin(x), math.cos(y), math.sin(y), math.cos(z), math.sin(z)
	return {
		{ cy * cz + sy * sx * sz, -cy * sz + sy * sx * cz, sy * cx },
		{ cx * sz, cx * cz, -sx },
		{ -sy * cz + cy * sx * sz, sy * sz + cy * sx * cz, cy * cx },
	}
end

-- Axis-aligned box around every part, rotation included.
function Measure.box(model: Art.ModelData): Box
	local min = { math.huge, math.huge, math.huge }
	local max = { -math.huge, -math.huge, -math.huge }
	for _, p in model.parts do
		local r = rotation(p.rot or { 0, 0, 0 })
		for i = 1, 3 do
			local half = 0
			for j = 1, 3 do
				half += math.abs(r[i][j]) * p.size[j] / 2
			end
			min[i] = math.min(min[i], p.at[i] - half)
			max[i] = math.max(max[i], p.at[i] + half)
		end
	end
	return { min = min, max = max }
end

local function triple(t: { number }): string
	return `{Review.num(t[1])}×{Review.num(t[2])}×{Review.num(t[3])}`
end

-- Lines for REVIEW.md: information only, no pass/fail (the user judges).
function Measure.compare(model: Art.ModelData, c: Criteria.Criteria): { string }
	local b = Measure.box(model)
	local got = { b.max[1] - b.min[1], b.max[2] - b.min[2], b.max[3] - b.min[3] }
	return {
		`size {triple(got)} (criteria {triple(c.size)})`,
		`base y={Review.num(b.min[2])}`,
		`parts {#model.parts}`,
	}
end

return Measure
