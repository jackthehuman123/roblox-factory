--!strict
-- Pure round state machine: Lobby -> Intermission -> Playing -> Ended -> Lobby.

local RoundState = {}

export type Phase = "Lobby" | "Intermission" | "Playing" | "Ended"
export type Config = { minPlayers: number, intermission: number, roundLength: number, endedLength: number }
export type State = { phase: Phase, timeLeft: number }

local function isNumber(v: any): boolean
	return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

function RoundState.validateConfig(config: Config): { string }
	local errs: { string } = {}
	local c: any = config
	if not (isNumber(c.minPlayers) and c.minPlayers >= 1 and c.minPlayers % 1 == 0) then
		table.insert(errs, "minPlayers must be an integer >= 1")
	end
	if not (isNumber(c.intermission) and c.intermission >= 0) then
		table.insert(errs, "intermission must be a number >= 0")
	end
	if not (isNumber(c.roundLength) and c.roundLength > 0) then
		table.insert(errs, "roundLength must be a number > 0")
	end
	if not (isNumber(c.endedLength) and c.endedLength >= 0) then
		table.insert(errs, "endedLength must be a number >= 0")
	end
	return errs
end

function RoundState.new(): State
	return { phase = "Lobby", timeLeft = 0 }
end

function RoundState.step(state: State, config: Config, dt: number, playerCount: number): State
	local enough = playerCount >= config.minPlayers
	local timeLeft = state.timeLeft - dt
	local phase = state.phase

	if phase == "Lobby" then
		if enough then
			return { phase = "Intermission", timeLeft = config.intermission }
		end
		return { phase = "Lobby", timeLeft = 0 }
	elseif phase == "Intermission" then
		if not enough then
			return { phase = "Lobby", timeLeft = 0 }
		end
		if timeLeft <= 0 then
			return { phase = "Playing", timeLeft = config.roundLength }
		end
		return { phase = "Intermission", timeLeft = timeLeft }
	elseif phase == "Playing" then
		if not enough or timeLeft <= 0 then
			return { phase = "Ended", timeLeft = config.endedLength }
		end
		return { phase = "Playing", timeLeft = timeLeft }
	else
		if timeLeft <= 0 then
			return { phase = "Lobby", timeLeft = 0 }
		end
		return { phase = "Ended", timeLeft = timeLeft }
	end
end

return RoundState
