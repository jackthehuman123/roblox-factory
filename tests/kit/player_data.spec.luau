--!strict
local PlayerData = require("../../kit/src/shared/PlayerData")

local function defaults(): { [string]: any }
	return { coins = 0, settings = { music = true } }
end

return function(test: (name: string, fn: () -> ()) -> ())
	test("keeps matching keys, drops wrong types and unknown keys", function()
		local out = PlayerData.withDefaults({ coins = 5, settings = { music = "loud" }, hacked = 1 }, defaults())
		assert(out.coins == 5, `coins {out.coins}`)
		assert(out.settings.music == true, `music {out.settings.music}`)
		assert(out.hacked == nil, "hacked should be dropped")
	end)

	test("nil saved returns an equal but distinct deep copy", function()
		local d = defaults()
		local out = PlayerData.withDefaults(nil, d)
		assert(out ~= d, "expected a different table")
		assert(out.settings ~= d.settings, "expected nested table copied")
		assert(out.coins == 0 and out.settings.music == true, "values differ")
	end)

	test("saved table replacing a nested default is dropped", function()
		local out = PlayerData.withDefaults({ settings = 7 }, defaults())
		assert(type(out.settings) == "table" and out.settings.music == true, "settings should stay default")
	end)
end
