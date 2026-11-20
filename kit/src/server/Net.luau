--!strict
-- Server side of remotes. Remotes live in ReplicatedStorage.Remotes.
-- Incoming calls that fail RateLimit or Schema.check are dropped silently.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RateLimit = require(ReplicatedStorage.Kit.RateLimit)
local Schema = require(ReplicatedStorage.Kit.Schema)

local Net = {}

type Handler = (player: Player, ...any) -> ()
type Def = {
	remote: RemoteEvent,
	spec: { string },
	limiter: RateLimit.Limiter,
	handlers: { Handler },
}

local defs: { [string]: Def } = {}

local function remotesFolder(): Instance
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if folder == nil then
		local created = Instance.new("Folder")
		created.Name = "Remotes"
		created.Parent = ReplicatedStorage
		folder = created
	end
	return folder :: Instance
end

local function get(name: string): Def
	local def = defs[name]
	if def == nil then
		error(`Net: remote "{name}" is not defined`)
	end
	return def
end

function Net.define(name: string, spec: { string }, maxPerSecond: number?): ()
	assert(defs[name] == nil, `Net: remote "{name}" defined twice`)
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	local def: Def = {
		remote = remote,
		spec = table.clone(spec),
		limiter = RateLimit.new(maxPerSecond or 10, 1),
		handlers = {},
	}
	defs[name] = def

	remote.OnServerEvent:Connect(function(player: Player, ...: any)
		if not def.limiter:allow(tostring(player.UserId), os.clock()) then
			return
		end
		if select("#", ...) ~= #def.spec or not Schema.check(def.spec, { ... }) then
			return
		end
		for _, handler in def.handlers do
			task.spawn(handler, player, ...)
		end
	end)
	remote.Parent = remotesFolder()
end

function Net.onServer(name: string, handler: Handler): ()
	table.insert(get(name).handlers, handler)
end

function Net.fireClient(name: string, player: Player, ...: any): ()
	get(name).remote:FireClient(player, ...)
end

function Net.fireAll(name: string, ...: any): ()
	get(name).remote:FireAllClients(...)
end

return Net
