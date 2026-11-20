--!strict
-- In-memory player data, created from defaults on PlayerAdded. No persistence yet.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerData = require(ReplicatedStorage.Kit.PlayerData)

local DataService = {}

local defaults: { [string]: any } = {}
local data: { [Player]: { [string]: any } } = {}

local function create(player: Player): { [string]: any }
	local d = PlayerData.withDefaults(nil, defaults)
	data[player] = d
	return d
end

function DataService.setDefaults(newDefaults: { [string]: any }): ()
	defaults = newDefaults
end

function DataService.get(player: Player): { [string]: any }
	return data[player] or create(player)
end

Players.PlayerAdded:Connect(function(player: Player)
	if data[player] == nil then
		create(player)
	end
end)

Players.PlayerRemoving:Connect(function(player: Player)
	data[player] = nil
end)

return DataService
