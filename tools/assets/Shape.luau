--!strict
-- Shape checks for JSON handed to asset_db. Each returns a problem string, or nil if fine.
local Shape = {}

local function isList(v: any, kind: string): boolean
	if type(v) ~= "table" then
		return false
	end
	local n = 0
	for k, item in v do
		n += 1
		if type(k) ~= "number" or type(item) ~= kind then
			return false
		end
	end
	return n == #v
end

function Shape.entry(e: any): string?
	if type(e) ~= "table" then
		return "entry must be a JSON object"
	end
	if type(e.name) ~= "string" or type(e.built) ~= "string" then
		return "entry needs string name and built"
	end
	if not isList(e.tags, "string") or not isList(e.sources, "string") or not isList(e.size, "number") then
		return "entry tags and sources must be string lists, size a number list"
	end
	for _, field in { "note", "reason", "measure" } do
		if e[field] ~= nil and type(e[field]) ~= "string" then
			return `entry {field} must be a string`
		end
	end
	return nil
end

function Shape.result(r: any): string?
	if type(r) ~= "table" then
		return "result must be a JSON object"
	end
	if r.built ~= nil and not isList(r.built, "string") then
		return "result built must be a list of strings"
	end
	if r.skipped ~= nil then
		if type(r.skipped) ~= "table" then
			return "result skipped must be a list"
		end
		for _, s in r.skipped do
			if type(s) ~= "table" or type(s.object) ~= "string" or type(s.why) ~= "string" then
				return "result skipped items need string object and why"
			end
		end
	end
	return nil
end

return Shape
