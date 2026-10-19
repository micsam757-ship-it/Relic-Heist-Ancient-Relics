--!strict
-- Thin client networking wrapper. All gameplay actions are requests; the
-- server validates and responds with state snapshots and events.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local requestRemote = remotes:WaitForChild("Request") :: RemoteEvent
local stateRemote = remotes:WaitForChild("State") :: RemoteEvent
local eventRemote = remotes:WaitForChild("Event") :: RemoteEvent

local Net = {}

function Net.send(action: string, data: any?)
	requestRemote:FireServer({ action = action, data = data })
end

function Net.onState(handler: (any) -> ())
	return stateRemote.OnClientEvent:Connect(handler)
end

function Net.onEvent(handler: (any) -> ())
	return eventRemote.OnClientEvent:Connect(handler)
end

return Net
