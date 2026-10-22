--!strict
-- Pure stamina rules for sprinting. No Roblox APIs.
--
-- The pool is runtime state: it is never persisted, it drains while the player
-- sprints and refills while they do not. Running dry exhausts the player, who
-- then has to recover part of the pool before sprinting again.

local Stamina = {}

export type StaminaState = {
	current: number,
	max: number,
	exhausted: boolean,
	sprinting: boolean,
}

export type StaminaRules = {
	drainPerSecond: number,
	recoveryPerSecond: number,
	-- Share of the pool that must be recovered before sprinting is allowed
	-- again after running dry.
	recoverRatio: number,
}

function Stamina.new(max: number): StaminaState
	local pool = math.max(0, max)
	return {
		current = pool,
		max = pool,
		exhausted = false,
		sprinting = false,
	}
end

-- Sprinting may only start with a pool that is not empty and no active
-- exhaustion.
function Stamina.startSprint(state: StaminaState): (StaminaState, boolean)
	if state.exhausted or state.current <= 0 then
		return state, false
	end
	if state.sprinting then
		return state, true
	end
	return {
		current = state.current,
		max = state.max,
		exhausted = state.exhausted,
		sprinting = true,
	},
		true
end

function Stamina.stopSprint(state: StaminaState): StaminaState
	if not state.sprinting then
		return state
	end
	return {
		current = state.current,
		max = state.max,
		exhausted = state.exhausted,
		sprinting = false,
	}
end

-- Advances the pool by `deltaSeconds`. Sprinting drains it, everything else
-- refills it. `sprinting` overrides the stored flag, which lets the server
-- stop draining while the player stands still.
function Stamina.update(
	state: StaminaState,
	deltaSeconds: number,
	rules: StaminaRules,
	sprinting: boolean?
): StaminaState
	local delta = math.max(0, deltaSeconds)
	local active = state.sprinting
	if sprinting ~= nil then
		active = sprinting
	end

	local current = state.current
	local exhausted = state.exhausted

	if active and not exhausted then
		current -= math.max(0, rules.drainPerSecond) * delta
		if current <= 0 then
			current = 0
			active = false
			exhausted = true
		end
	else
		active = false
		current = math.min(state.max, current + math.max(0, rules.recoveryPerSecond) * delta)
		if exhausted and current >= state.max * rules.recoverRatio then
			exhausted = false
		end
	end

	return {
		current = current,
		max = state.max,
		exhausted = exhausted,
		sprinting = active,
	}
end

function Stamina.ratio(state: StaminaState): number
	if state.max <= 0 then
		return 0
	end
	return math.clamp(state.current / state.max, 0, 1)
end

return Stamina
