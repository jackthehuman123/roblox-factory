--!strict
-- What a generated asset must be: assets/criteria/<Name>.json, written by asset-builder before generate_mesh.
local Criteria = {}

export type Criteria = {
	name: string,
	size: { number },
	prompt: string,
	notes: { string }?,
	colours: { string }?,
	materials: { string }?,
	source: string,
}

local function goodNumber(v: any): boolean
	return type(v) == "number" and v == v and v > 0 and v ~= math.huge
end

-- nil when valid, else one problem.
function Criteria.check(c: any): string?
	if type(c) ~= "table" then
		return "criteria must be a JSON object"
	end
	if type(c.name) ~= "string" or string.match(c.name, "^[A-Z][A-Za-z0-9]*$") == nil then
		return "criteria name must be PascalCase letters and digits"
	end
	if type(c.size) ~= "table" or #c.size ~= 3 then
		return "criteria size must be 3 numbers > 0"
	end
	for _, n in c.size do
		if not goodNumber(n) then
			return "criteria size must be 3 numbers > 0"
		end
	end
	if type(c.prompt) ~= "string" or c.prompt == "" then
		return "criteria prompt must be non-empty"
	end
	if type(c.source) ~= "string" or c.source == "" then
		return "criteria source must be non-empty"
	end
	for _, field in { "notes", "colours", "materials" } do
		local list = c[field]
		if list ~= nil then
			if type(list) ~= "table" then
				return `criteria {field} must be a list of strings`
			end
			for _, s in list do
				if type(s) ~= "string" then
					return `criteria {field} must be a list of strings`
				end
			end
		end
	end
	return nil
end

-- The text sent to generate_mesh: the prompt, then each of the user's regen notes.
function Criteria.prompt(c: Criteria): string
	local out = c.prompt
	for _, note in c.notes or {} do
		out ..= ` Fix: {note}.`
	end
	return out
end

return Criteria
