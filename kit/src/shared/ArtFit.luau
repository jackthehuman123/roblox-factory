--!strict
-- Pure art geometry: model boxes, sit heights and placed copy boxes.
export type Box3 = { min: { number }, max: { number } }
export type GrayBox = { size: { number }, at: { number }, rot: number?, tags: { string }? }
export type Copy = { placement: number, model: string, box: Box3, base: number? }

local ArtFit = {}
ArtFit.LIFT = 0.02
ArtFit.FLOOR_SLOP = 0.05 -- a floor top at the placement Y still counts
ArtFit.FLOOR_RAY = 500 -- how far below the placement a floor is found

type Mat = { { number } }

local function mul(a: Mat, b: Mat): Mat
	local out: Mat = {}
	for i = 1, 3 do
		out[i] = {}
		for j = 1, 3 do
			local s = 0
			for k = 1, 3 do
				s += a[i][k] * b[k][j]
			end
			out[i][j] = s
		end
	end
	return out
end

-- Same order as CFrame.fromOrientation: Ry * Rx * Rz.
local function orientation(rot: { number }): Mat
	local rx, ry, rz = math.rad(rot[1]), math.rad(rot[2]), math.rad(rot[3])
	local cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
	local mx: Mat = { { 1, 0, 0 }, { 0, cx, -sx }, { 0, sx, cx } }
	local my: Mat = { { cy, 0, sy }, { 0, 1, 0 }, { -sy, 0, cy } }
	local mz: Mat = { { cz, -sz, 0 }, { sz, cz, 0 }, { 0, 0, 1 } }
	return mul(my, mul(mx, mz))
end

function ArtFit.modelBox(model: { parts: { any } }): Box3
	local lo = { math.huge, math.huge, math.huge }
	local hi = { -math.huge, -math.huge, -math.huge }
	for _, part in model.parts do
		local m = orientation(part.rot or { 0, 0, 0 })
		for i = 1, 3 do
			local half = 0
			for j = 1, 3 do
				half += math.abs(m[i][j]) * part.size[j] / 2
			end
			lo[i] = math.min(lo[i], part.at[i] - half)
			hi[i] = math.max(hi[i], part.at[i] + half)
		end
	end
	return { min = lo, max = hi }
end

function ArtFit.sitY(sit: string, baseHeight: number, box: Box3): number
	if sit == "top" then
		return baseHeight / 2 - box.min[2] + ArtFit.LIFT
	elseif sit == "base" then
		return -baseHeight / 2 - box.min[2] + ArtFit.LIFT
	end
	return -baseHeight / 2 - box.max[2]
end

local function hasTag(box: GrayBox, tag: string): boolean
	return box.tags ~= nil and table.find(box.tags, tag) ~= nil
end

function ArtFit.hidden(placements: { any }, boxes: { GrayBox }): { [number]: boolean }
	local out: { [number]: boolean } = {}
	for _, p in placements do
		if p.hideBase and p.onTag then
			for i, box in boxes do
				if hasTag(box, p.onTag) then
					out[i] = true
				end
			end
		end
	end
	return out
end

function ArtFit.floorY(boxes: { GrayBox }, hidden: { [number]: boolean }, x: number, z: number, fromY: number): number?
	local best: number? = nil
	for i, box in boxes do
		if not hidden[i] then
			local a = math.rad(box.rot or 0)
			local dx, dz = x - box.at[1], z - box.at[3]
			local lx = dx * math.cos(a) - dz * math.sin(a)
			local lz = dx * math.sin(a) + dz * math.cos(a)
			local top = box.at[2] + box.size[2] / 2
			if
				math.abs(lx) <= box.size[1] / 2
				and math.abs(lz) <= box.size[3] / 2
				and top <= fromY + ArtFit.FLOOR_SLOP
				and top >= fromY - ArtFit.FLOOR_RAY
			then
				if best == nil or top > best then
					best = top
				end
			end
		end
	end
	return best
end

-- World axis-aligned box of a model box yawed (degrees) about its pivot and moved to pivot.
local function placed(box: Box3, pivot: { number }, yaw: number): Box3
	local a = math.rad(yaw)
	local c, s = math.cos(a), math.sin(a)
	local cx, cz = (box.min[1] + box.max[1]) / 2, (box.min[3] + box.max[3]) / 2
	local hx, hz = (box.max[1] - box.min[1]) / 2, (box.max[3] - box.min[3]) / 2
	local wx = pivot[1] + c * cx + s * cz
	local wz = pivot[3] - s * cx + c * cz
	local ex = math.abs(c) * hx + math.abs(s) * hz
	local ez = math.abs(s) * hx + math.abs(c) * hz
	return {
		min = { wx - ex, pivot[2] + box.min[2], wz - ez },
		max = { wx + ex, pivot[2] + box.max[2], wz + ez },
	}
end

function ArtFit.copies(placements: { any }, models: { [string]: any }, boxes: { GrayBox }): { Copy }
	local out: { Copy } = {}
	local hidden = ArtFit.hidden(placements, boxes)
	for index, p in placements do
		local model = models[p.model]
		if model == nil then
			continue
		end
		local mbox = ArtFit.modelBox(model)
		if p.at then
			local y = p.at[2]
			if p.sit == "floor" then
				local floor = ArtFit.floorY(boxes, hidden, p.at[1], p.at[3], p.at[2])
				if floor then
					y = floor + ArtFit.LIFT - mbox.min[2]
				end
			end
			local pivot = { p.at[1], y, p.at[3] }
			table.insert(out, { placement = index, model = p.model, box = placed(mbox, pivot, p.rot or 0) })
		elseif p.onTag then
			for i, base in boxes do
				if hasTag(base, p.onTag) then
					local off = p.offset or { 0, 0, 0 }
					local dy = off[2] + (p.sit and ArtFit.sitY(p.sit, base.size[2], mbox) or 0)
					local yaw = base.rot or 0
					local a = math.rad(yaw)
					local c, s = math.cos(a), math.sin(a)
					local pivot = {
						base.at[1] + c * off[1] + s * off[3],
						base.at[2] + dy,
						base.at[3] - s * off[1] + c * off[3],
					}
					table.insert(out, { placement = index, model = p.model, box = placed(mbox, pivot, yaw), base = i })
				end
			end
		end
	end
	return out
end

return ArtFit
