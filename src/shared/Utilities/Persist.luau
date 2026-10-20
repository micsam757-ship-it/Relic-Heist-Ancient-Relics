--!strict
-- Pure persistence safety rules. No Roblox APIs, so the load/save failure
-- decisions can be unit tested outside of Studio (see docs/DATA_MODEL.md and
-- docs/THREAT_MODEL.md T-11/T-12).

local Persist = {}

Persist.LoadStatus = {
	OK = "OK",
	NOT_FOUND = "NOT_FOUND",
	UNAVAILABLE = "UNAVAILABLE",
}

-- The outcome of a profile load, decided purely from the store availability, the
-- DataStore load status, and whether the stored record migrated cleanly. The
-- caller maps each outcome to side effects (ephemeral mode, kick, or a normal
-- live profile). Studio never kicks, so a bad record degrades to ephemeral there.
export type LoadOutcome = "LIVE" | "NEW" | "EPHEMERAL" | "KICK"

-- Decides what to do after attempting to load a profile.
--
--  * storeAvailable=false           -> EPHEMERAL (no DataStore; never overwrites)
--  * status == NOT_FOUND            -> NEW (a fresh default profile)
--  * status == UNAVAILABLE          -> EPHEMERAL in Studio, else KICK
--  * status == OK and migrated==nil -> corrupt/future record: EPHEMERAL in
--                                      Studio, else KICK (never overwrite it)
--  * status == OK and migrated~=nil -> LIVE
function Persist.loadOutcome(storeAvailable: boolean, status: string, migrated: any, isStudio: boolean): LoadOutcome
	if not storeAvailable then
		return "EPHEMERAL"
	end
	if status == Persist.LoadStatus.NOT_FOUND then
		return "NEW"
	end
	if status == Persist.LoadStatus.UNAVAILABLE then
		return if isStudio then "EPHEMERAL" else "KICK"
	end
	if status == Persist.LoadStatus.OK then
		if migrated == nil then
			return if isStudio then "EPHEMERAL" else "KICK"
		end
		return "LIVE"
	end
	-- Unknown status is treated like a transient failure: fail closed, never write.
	return if isStudio then "EPHEMERAL" else "KICK"
end

-- Whether a load outcome permits later writes (only a live or new profile is
-- persisted; ephemeral and kicked profiles are never saved).
function Persist.isWritable(outcome: LoadOutcome): boolean
	return outcome == "LIVE" or outcome == "NEW"
end

-- Returns the backoff (seconds) before the next retry, or nil when retries are
-- exhausted. `attempt` is 1-based. Retries stop at `maxRetries`.
function Persist.retryBackoff(attempt: number, maxRetries: number, backoffTable: { number }): number?
	if attempt >= maxRetries then
		return nil
	end
	return backoffTable[attempt] or backoffTable[#backoffTable] or 3
end

-- Decides whether an in-flight write must be aborted to protect a newer record
-- written by another server session.
--
-- `current` is the record already stored (or nil/not a table when none exists).
-- The write is allowed unless a *different* session wrote after this handle
-- loaded the profile. Matching session ids are always allowed (our own prior
-- write); an equal-or-older timestamp from another session is allowed because we
-- loaded at least that recently.
--
-- Returns true when it is safe to commit the write.
function Persist.canCommit(current: any, sessionId: string, loadedAt: number): boolean
	if type(current) ~= "table" then
		return true
	end
	local remoteSession = current.sessionId
	local remoteUpdated = tonumber(current.updatedAt) or 0
	if remoteSession ~= sessionId and remoteUpdated > loadedAt then
		return false
	end
	return true
end

return Persist
