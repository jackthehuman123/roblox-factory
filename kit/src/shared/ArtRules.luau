--!strict
-- Pure art placement rules: doubled, sunk, flush, floating, overlap.
type Box3 = { min: { number }, max: { number } }
type GrayBox = { size: { number }, at: { number }, rot: number?, tags: { string }? }
type Copy = { placement: number, model: string, box: Box3, base: number? }

local ArtRules = {}

local EPS = 1e-6
local LIFT = 0.02
local SUNK_DEPTH = 0.1
local FLUSH_DROP = 0.1
local NEAR = 0.1
local DOUBLED_SHARE = 0.5
local OVERLAP_SHARE = 0.25
local RULES = { "doubled", "sunk", "flush", "floating" }
local HINTS: { [string]: string } = {
	doubled = "hide the base (hideBase) or move the model",
	sunk = "raise it or use sit",
	flush = "lift it or use sit",
	floating = "rest it on, or attach it to, a surface",
}

local function worldBox(box: GrayBox): Box3
	local a = math.rad(box.rot or 0)
	local c, s = math.abs(math.cos(a)), math.abs(math.sin(a))
	local hx = c * box.size[1] / 2 + s * box.size[3] / 2
	local hz = s * box.size[1] / 2 + c * box.size[3] / 2
	local hy = box.size[2] / 2
	return {
		min = { box.at[1] - hx, box.at[2] - hy, box.at[3] - hz },
		max = { box.at[1] + hx, box.at[2] + hy, box.at[3] + hz },
	}
end

local function extent(a: Box3, b: Box3, axis: number, grow: number): number
	return math.min(a.max[axis], b.max[axis] + grow) - math.max(a.min[axis], b.min[axis] - grow)
end

local function volume(b: Box3): number
	return (b.max[1] - b.min[1]) * (b.max[2] - b.min[2]) * (b.max[3] - b.min[3])
end

local function overlapVolume(a: Box3, b: Box3): number
	local x, y, z = extent(a, b, 1, 0), extent(a, b, 2, 0), extent(a, b, 3, 0)
	if x <= 0 or y <= 0 or z <= 0 then
		return 0
	end
	return x * y * z
end

local function touches(a: Box3, b: Box3): boolean
	return extent(a, b, 1, NEAR) >= 0 and extent(a, b, 2, NEAR) >= 0 and extent(a, b, 3, NEAR) >= 0
end

local function isDoubled(copy: Copy, visible: { [number]: Box3 }): boolean
	local base = copy.base and visible[copy.base]
	if not base then
		return false
	end
	return overlapVolume(copy.box, base) > DOUBLED_SHARE * math.min(volume(copy.box), volume(base))
end

local function isSunk(copy: Copy, visible: { [number]: Box3 }): boolean
	for i, box in visible do
		if i ~= copy.base then
			local x, y, z = extent(copy.box, box, 1, 0), extent(copy.box, box, 2, 0), extent(copy.box, box, 3, 0)
			if x > 0 and y > 0 and z > 0 and math.min(x, y, z) > SUNK_DEPTH then
				return true
			end
		end
	end
	return false
end

local function isFlush(copy: Copy, visible: { [number]: Box3 }): boolean
	for _, box in visible do
		if extent(copy.box, box, 1, 0) > 0 and extent(copy.box, box, 3, 0) > 0 then
			local d = copy.box.min[2] - box.max[2]
			if d >= -FLUSH_DROP and d < LIFT - EPS then
				return true
			end
		end
	end
	return false
end

local function isFloating(copy: Copy, visible: { [number]: Box3 }, copies: { Copy }): boolean
	for _, box in visible do
		if touches(copy.box, box) then
			return false
		end
	end
	for _, other in copies do
		if other ~= copy and touches(copy.box, other.box) then
			return false
		end
	end
	return true
end

function ArtRules.check(
	copies: { Copy },
	boxes: { GrayBox },
	hidden: { [number]: boolean },
	placements: { any }
): { string }
	local visible: { [number]: Box3 } = {}
	for i, box in boxes do
		if not hidden[i] then
			visible[i] = worldBox(box)
		end
	end

	local byPlacement: { [number]: { Copy } } = {}
	local order: { number } = {}
	for _, copy in copies do
		if not byPlacement[copy.placement] then
			byPlacement[copy.placement] = {}
			table.insert(order, copy.placement)
		end
		table.insert(byPlacement[copy.placement], copy)
	end
	table.sort(order)

	local out: { string } = {}
	local function report(index: number, rule: string, hint: string, failing: number)
		if failing == 0 then
			return
		end
		local placement = placements[index]
		local text = `placement {index} ({placement.model}): {rule}: {hint}`
		if placement.onTag then
			text ..= ` ({failing} of {#byPlacement[index]} copies)`
		end
		table.insert(out, text)
	end

	for _, index in order do
		local placement = placements[index]
		local allowed: { [string]: boolean } = {}
		for _, rule in placement.allow or {} do
			allowed[rule] = true
		end
		local mine = byPlacement[index]
		local counts: { [string]: number } = { doubled = 0, sunk = 0, flush = 0, floating = 0 }
		for _, copy in mine do
			if not allowed.doubled and isDoubled(copy, visible) then
				counts.doubled += 1
			end
			if not allowed.sunk and isSunk(copy, visible) then
				counts.sunk += 1
			end
			if not allowed.flush and isFlush(copy, visible) then
				counts.flush += 1
			end
			if not allowed.floating and isFloating(copy, visible, copies) then
				counts.floating += 1
			end
		end
		for _, rule in RULES do
			report(index, rule, HINTS[rule], counts[rule])
		end
		if not allowed.overlap then
			for _, j in order do
				if j > index then
					local n = 0
					for _, a in mine do
						for _, b in byPlacement[j] do
							local limit = OVERLAP_SHARE * math.min(volume(a.box), volume(b.box))
							if overlapVolume(a.box, b.box) > limit then
								n += 1
								break
							end
						end
					end
					report(index, "overlap", `move one (overlaps placement {j})`, n)
				end
			end
		end
	end
	return out
end

return ArtRules
