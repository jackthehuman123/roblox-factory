--!strict
-- Client side of remotes defined on the server with Net.define. Waits for the remote to exist.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NetClient = {}

local function get(name: string): RemoteEvent
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild(name)
	assert(remote:IsA("RemoteEvent"), `NetClient: {name} is not a RemoteEvent`)
	return remote
end

function NetClient.fire(name: string, ...: any): ()
	get(name):FireServer(...)
end

function NetClient.on(name: string, fn: (...any) -> ()): ()
	get(name).OnClientEvent:Connect(fn)
end

return NetClient
