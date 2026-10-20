--!strict
-- Pure tutorial progression rules. No Roblox APIs.
--
-- The tutorial is a short ordered list of steps configured in
-- `GameConfig.Tutorial.Steps`. Each step teaches one action and completes when
-- the player performs it. The server records the highest step index reached; the
-- client renders the current step. Nothing here gates gameplay: a player who
-- ignores the tutorial simply stops advancing it.

local Tutorial = {}

export type TutorialStep = {
	id: string,
	title: string,
	text: string,
	hint: string?,
	complete: string,
}

-- Returns the index of the first step whose `complete` action matches, or nil.
function Tutorial.stepIndexForAction(steps: { TutorialStep }, action: string): number?
	for index, step in steps do
		if step.complete == action then
			return index
		end
	end
	return nil
end

-- Given the highest step already completed and an action the player just
-- performed, returns the new completed-step count. Advancing requires the action
-- to match the next step, so out-of-order actions are ignored.
function Tutorial.advance(completedSteps: number, steps: { TutorialStep }, action: string): number
	local nextIndex = completedSteps + 1
	local step = steps[nextIndex]
	if step == nil then
		return completedSteps
	end
	if step.complete == action then
		return nextIndex
	end
	return completedSteps
end

function Tutorial.isComplete(completedSteps: number, steps: { TutorialStep }): boolean
	return completedSteps >= #steps
end

-- Snapshot view for the client: the current step (or nil when done) plus progress.
function Tutorial.view(completedSteps: number, steps: { TutorialStep })
	if #steps == 0 then
		return { active = false, total = 0, completed = 0, step = nil :: any }
	end
	local clamped = math.max(0, math.min(completedSteps, #steps))
	local step: any = steps[clamped + 1]
	return {
		active = clamped < #steps,
		total = #steps,
		completed = clamped,
		step = step,
	}
end

return Tutorial
