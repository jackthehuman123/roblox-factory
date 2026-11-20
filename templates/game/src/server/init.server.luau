--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local ArtLoader = require(ServerScriptService.Kit.ArtLoader)

local GrayboxLoader = require(ServerScriptService.Kit.GrayboxLoader)
local RoundService = require(ServerScriptService.Kit.RoundService)
local config = require(script.config)
local graybox = require(script.graybox)

-- Cast: graybox.luau stays plain data (Lune-loadable); GrayboxLoader validates it.
local _, errs = GrayboxLoader.load(graybox :: any, workspace)
for _, err in errs do
	warn(`graybox: {err}`)
end

-- Art sits on top of the graybox; it never changes gameplay. No art folder means no art.
-- Spawned: loading meshes yields, and gameplay must not wait for art.
local artFolder = ServerStorage:FindFirstChild("Art")
if artFolder ~= nil then
	task.spawn(function()
		local _, artErrs = ArtLoader.load(artFolder, workspace)
		for _, err in artErrs do
			warn(`art: {err}`)
		end
	end)
end

RoundService.start(config.round)
