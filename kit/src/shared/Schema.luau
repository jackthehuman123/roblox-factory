--!strict
-- Checks remote arguments against a list of type names. Never errors.

local Schema = {}

local ALLOWED = { number = true, string = true, boolean = true, table = true }

function Schema.check(spec: { string }, args: { any }): boolean
	if type(args) ~= "table" or #args ~= #spec then
		return false
	end
	for i, expected in spec do
		local v = args[i]
		if not ALLOWED[expected] or type(v) ~= expected then
			return false
		end
		if expected == "number" and (v ~= v or v == math.huge or v == -math.huge) then
			return false
		end
	end
	return true
end

return Schema
