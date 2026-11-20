--!strict
-- Drives RoundState every Heartbeat and publishes it as ReplicatedStorage attributes
-- "RoundPhase" (string) and "RoundTimeLeft" (whole seconds, rounded up).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local RoundState = require(ReplicatedStorage.Kit.RoundState)

local RoundService = {}

local handlers: { [RoundState.Phase]: { () -> () } } = {}
local started = false

local function publish(state: RoundState.State)
	ReplicatedStorage:SetAttribute("RoundPhase", state.phase)
	ReplicatedStorage:SetAttribute("RoundTimeLeft", math.max(0, math.ceil(state.timeLeft)))
end

function RoundService.onPhase(phase: RoundState.Phase, fn: () -> ()): ()
	local list = handlers[phase]
	if list == nil then
		list = {}
		handlers[phase] = list
	end
	table.insert(list, fn)
end

function RoundService.start(config: RoundState.Config): ()
	assert(not started, "RoundService.start called twice")
	local errs = RoundState.validateConfig(config)
	if #errs > 0 then
		error(`RoundService: bad round config: {table.concat(errs, "; ")}`)
	end
	started = true

	local state = RoundState.new()
	publish(state)
	RunService.Heartbeat:Connect(function(dt: number)
		local nextState = RoundState.step(state, config, dt, #Players:GetPlayers())
		local changed = nextState.phase ~= state.phase
		state = nextState
		publish(state)
		local list = if changed then handlers[state.phase] else nil
		if list ~= nil then
			for _, fn in list do
				task.spawn(fn)
			end
		end
	end)
end

return RoundService
