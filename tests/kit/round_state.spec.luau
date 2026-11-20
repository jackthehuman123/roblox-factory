--!strict
local RoundState = require("../../kit/src/shared/RoundState")

local CONFIG: RoundState.Config = { minPlayers = 2, intermission = 5, roundLength = 10, endedLength = 3 }

return function(test: (name: string, fn: () -> ()) -> ())
	test("new is Lobby with timeLeft 0", function()
		local s = RoundState.new()
		assert(s.phase == "Lobby" and s.timeLeft == 0, `got {s.phase} {s.timeLeft}`)
	end)

	test("Lobby with enough players goes to Intermission", function()
		local s = RoundState.step(RoundState.new(), CONFIG, 0, 2)
		assert(s.phase == "Intermission" and s.timeLeft == 5, `got {s.phase} {s.timeLeft}`)
	end)

	test("Lobby with too few players stays Lobby", function()
		local s = RoundState.step(RoundState.new(), CONFIG, 1, 1)
		assert(s.phase == "Lobby", `got {s.phase}`)
	end)

	test("Intermission with too few players returns to Lobby", function()
		local s = RoundState.step({ phase = "Intermission", timeLeft = 5 }, CONFIG, 0, 1)
		assert(s.phase == "Lobby", `got {s.phase}`)
	end)

	test("Intermission counts down then goes to Playing", function()
		local mid = RoundState.step({ phase = "Intermission", timeLeft = 5 }, CONFIG, 2, 2)
		assert(mid.phase == "Intermission" and mid.timeLeft == 3, `got {mid.phase} {mid.timeLeft}`)
		local s = RoundState.step({ phase = "Intermission", timeLeft = 5 }, CONFIG, 5, 2)
		assert(s.phase == "Playing" and s.timeLeft == 10, `got {s.phase} {s.timeLeft}`)
	end)

	test("Playing with too few players goes to Ended", function()
		local s = RoundState.step({ phase = "Playing", timeLeft = 10 }, CONFIG, 0, 1)
		assert(s.phase == "Ended" and s.timeLeft == 3, `got {s.phase} {s.timeLeft}`)
	end)

	test("Playing times out to Ended", function()
		local s = RoundState.step({ phase = "Playing", timeLeft = 10 }, CONFIG, 10, 2)
		assert(s.phase == "Ended" and s.timeLeft == 3, `got {s.phase} {s.timeLeft}`)
	end)

	test("Ended times out to Lobby", function()
		local s = RoundState.step({ phase = "Ended", timeLeft = 3 }, CONFIG, 3, 2)
		assert(s.phase == "Lobby", `got {s.phase}`)
	end)

	test("step does not mutate its input", function()
		local input: RoundState.State = { phase = "Intermission", timeLeft = 5 }
		local out = RoundState.step(input, CONFIG, 1, 2)
		assert(out ~= input, "expected a new table")
		assert(input.phase == "Intermission" and input.timeLeft == 5, "input was mutated")
	end)

	test("validateConfig reports minPlayers and roundLength", function()
		local errs = RoundState.validateConfig({ minPlayers = 0, intermission = 5, roundLength = 0, endedLength = 3 })
		assert(#errs == 2, `expected 2 errors, got {#errs}`)
	end)

	test("validateConfig accepts a good config", function()
		local errs = RoundState.validateConfig(CONFIG)
		assert(#errs == 0, `expected 0 errors, got {#errs}`)
	end)
end
