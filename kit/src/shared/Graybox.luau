--!strict
-- Validates graybox data (plain tables, no Roblox datatypes). Returns every problem found.

local Graybox = {}

export type Box = {
	size: { number },
	at: { number },
	rot: number?,
	color: { number }?,
	material: string?,
	tags: { string }?,
}

local MATERIALS = {
	SmoothPlastic = true,
	Concrete = true,
	Wood = true,
	Grass = true,
	Slate = true,
	Metal = true,
	Neon = true,
}

local function isNumber(v: any): boolean
	return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

local function isTriple(v: any, ok: (number) -> boolean): boolean
	if type(v) ~= "table" or #v ~= 3 then
		return false
	end
	for i = 1, 3 do
		if not isNumber(v[i]) or not ok(v[i]) then
			return false
		end
	end
	return true
end

function Graybox.validate(boxes: { Box }): { string }
	local errs: { string } = {}
	for i, box in boxes do
		local b: any = box
		local function add(msg: string)
			table.insert(errs, `box {i}: {msg}`)
		end
		if type(b) ~= "table" then
			add("must be a table")
			continue
		end
		if not isTriple(b.size, function(n)
			return n > 0
		end) then
			add("size must be 3 numbers > 0")
		end
		if not isTriple(b.at, function()
			return true
		end) then
			add("at must be 3 numbers")
		end
		if b.rot ~= nil and not isNumber(b.rot) then
			add("rot must be a number")
		end
		if b.color ~= nil and not isTriple(b.color, function(n)
			return n >= 0 and n <= 255
		end) then
			add("color must be 3 numbers 0-255")
		end
		if b.material ~= nil and not MATERIALS[b.material] then
			add(`material {tostring(b.material)} not allowed`)
		end
		if b.tags ~= nil then
			local ok = type(b.tags) == "table"
			if ok then
				for _, t in b.tags do
					if type(t) ~= "string" then
						ok = false
					end
				end
			end
			if not ok then
				add("tags must be a list of strings")
			end
		end
	end
	return errs
end

return Graybox
