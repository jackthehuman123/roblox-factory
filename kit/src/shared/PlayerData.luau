--!strict
-- Merges saved player data onto defaults. Only keys present in defaults with the same type survive.

local PlayerData = {}

local function deepCopy(t: { [string]: any }): { [string]: any }
	local out: { [string]: any } = {}
	for k, v in t do
		out[k] = if type(v) == "table" then deepCopy(v) else v
	end
	return out
end

local function merge(saved: { [string]: any }?, defaults: { [string]: any }): { [string]: any }
	local out: { [string]: any } = {}
	for k, d in defaults do
		local s = if type(saved) == "table" then saved[k] else nil
		if type(d) == "table" then
			out[k] = merge(if type(s) == "table" then s else nil, d)
		elseif s ~= nil and typeof(s) == typeof(d) then
			out[k] = s
		else
			out[k] = d
		end
	end
	return out
end

function PlayerData.withDefaults(saved: { [string]: any }?, defaults: { [string]: any }): { [string]: any }
	if saved == nil then
		return deepCopy(defaults)
	end
	return merge(saved, defaults)
end

return PlayerData
