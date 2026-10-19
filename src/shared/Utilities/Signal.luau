--!strict
-- Minimal synchronous event signal. Handlers are isolated so one failing
-- listener cannot prevent other listeners from running.

local Signal = {}
Signal.__index = Signal

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

export type Signal = {
	Connect: (self: Signal, handler: (...any) -> ()) -> Connection,
	Fire: (self: Signal, ...any) -> (),
	DisconnectAll: (self: Signal) -> (),
}

function Signal.new(): Signal
	return setmetatable({ _handlers = {} }, Signal) :: any
end

function Signal:Connect(handler: (...any) -> ()): Connection
	local connection = { Connected = true } :: Connection
	local handlers = (self :: any)._handlers

	handlers[connection] = handler

	function connection.Disconnect()
		if not connection.Connected then
			return
		end
		connection.Connected = false
		handlers[connection] = nil
	end

	return connection
end

function Signal:Fire(...: any)
	local handlers = (self :: any)._handlers
	for connection, handler in pairs(handlers) do
		if connection.Connected then
			local ok, err = pcall(handler, ...)
			if not ok then
				warn(string.format("[Signal] handler error: %s", tostring(err)))
			end
		end
	end
end

function Signal:DisconnectAll()
	local handlers = (self :: any)._handlers
	for connection in pairs(handlers) do
		connection.Connected = false
		handlers[connection] = nil
	end
end

return Signal
