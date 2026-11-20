--!strict
-- Validates art placements against known models and the part budget. Pure; shares no code with Art.

local ArtPlacement = {}

export type Placement = {
	model: string,
	at: { number }?,
	rot: number?,
	onTag: string?,
	offset: { number }?,
	hideBase: boolean?,
	sit: string?, -- onTag: "top" | "base" | "under"; at: "floor"
	allow: { string }?, -- placement check rules to skip
}

local MAX_PARTS = 3000
local RULES = { "doubled", "sunk", "flush", "floating", "overlap" }
local SIT_TAG = { top = true, base = true, under = true }

local function isNumber(v: any): boolean
	return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

local function isTriple(v: any): boolean
	if type(v) ~= "table" or #v ~= 3 then
		return false
	end
	for i = 1, 3 do
		if not isNumber(v[i]) then
			return false
		end
	end
	return true
end

function ArtPlacement.validatePlacements(
	placements: { Placement },
	models: { [string]: { parts: { any } } },
	tagCounts: { [string]: number }
): { string }
	local errs: { string } = {}
	local total = 0
	for i, pl in placements do
		local p: any = pl
		local function add(msg: string)
			table.insert(errs, `placement {i}: {msg}`)
		end
		if type(p) ~= "table" then
			add("must be a table")
			continue
		end
		local model = models[p.model]
		if model == nil then
			add(`unknown model {tostring(p.model)}`)
		end
		local hasAt, hasTag = p.at ~= nil, p.onTag ~= nil
		if hasAt == hasTag then
			add("needs exactly one of at or onTag")
		end
		if hasAt and not isTriple(p.at) then
			add("at must be 3 numbers")
		end
		if hasTag and (type(p.onTag) ~= "string" or p.onTag == "") then
			add("onTag must be a non-empty string")
		end
		if p.rot ~= nil and not isNumber(p.rot) then
			add("rot must be a number")
		end
		if p.offset ~= nil and not isTriple(p.offset) then
			add("offset must be 3 numbers")
		end
		if p.hideBase ~= nil and type(p.hideBase) ~= "boolean" then
			add("hideBase must be a boolean")
		end
		if p.sit ~= nil then
			if hasTag and not SIT_TAG[p.sit] then
				add("sit with onTag must be top, base or under")
			elseif hasAt and p.sit ~= "floor" then
				add("sit with at must be floor")
			elseif not hasAt and not hasTag then
				add("sit needs at or onTag")
			end
		end
		if p.allow ~= nil then
			if type(p.allow) ~= "table" then
				add("allow must be a list of rule names")
			else
				for _, rule in p.allow do
					if not table.find(RULES, rule) then
						add(`allow rule {tostring(rule)} not known`)
					end
				end
			end
		end
		if model ~= nil and type(model.parts) == "table" then
			local copies = 1
			if hasTag and type(p.onTag) == "string" then
				copies = math.max(tagCounts[p.onTag] or 0, 1)
			end
			total += #model.parts * copies
		end
	end
	if total > MAX_PARTS then
		table.insert(errs, `art has {total} parts, max {MAX_PARTS}`)
	end
	return errs
end

return ArtPlacement
