--!strict
-- Fixed-window rate limiter keyed by string (e.g. player UserId .. remote name).

local RateLimit = {}

export type Limiter = { allow: (self: Limiter, key: string, now: number) -> boolean }

type Entry = { window: number, count: number }

function RateLimit.new(maxCalls: number, window: number): Limiter
	local entries: { [string]: Entry } = {}

	local limiter = {}
	function limiter.allow(_self: Limiter, key: string, now: number): boolean
		local slot = math.floor(now / window)
		local entry = entries[key]
		if entry == nil or entry.window ~= slot then
			entry = { window = slot, count = 0 }
			entries[key] = entry
		end
		if entry.count >= maxCalls then
			return false
		end
		entry.count += 1
		return true
	end

	return limiter :: Limiter
end

return RateLimit
