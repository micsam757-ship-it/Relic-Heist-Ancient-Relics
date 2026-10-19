--!strict
-- Structured server logger. Keeps messages actionable and avoids noisy output.

local Logger = {}
Logger.__index = Logger

export type Logger = {
	info: (self: Logger, message: string, ...any) -> (),
	warn: (self: Logger, message: string, ...any) -> (),
	error: (self: Logger, message: string, ...any) -> (),
}

local function timestamp(): string
	return os.date("!%Y-%m-%dT%H:%M:%SZ") :: string
end

function Logger.new(scope: string): Logger
	return setmetatable({ _scope = scope }, Logger) :: any
end

local function emit(level: string, scope: string, message: string, ...: any)
	local text = string.format(message, ...)
	local line = string.format("[%s][%s][%s] %s", timestamp(), level, scope, text)
	if level == "ERROR" or level == "WARN" then
		warn(line)
	else
		print(line)
	end
end

function Logger:info(message: string, ...: any)
	emit("INFO", (self :: any)._scope, message, ...)
end

function Logger:warn(message: string, ...: any)
	emit("WARN", (self :: any)._scope, message, ...)
end

function Logger:error(message: string, ...: any)
	emit("ERROR", (self :: any)._scope, message, ...)
end

return Logger
