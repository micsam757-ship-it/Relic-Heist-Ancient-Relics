--!nonstrict
-- Client-side view of the player's accessibility/feedback preferences. Other
-- client code (effects, audio, UI) reads these flags instead of the raw snapshot
-- so the behavior stays consistent and one place applies the theme.

local Theme = require(script.Parent.UI.Theme)

local Preferences = {}

local state = {
	reducedMotion = false,
	soundEnabled = true,
	visualEffects = true,
	colorblindMode = false,
	textScale = "Normal",
	applied = false,
}

-- Applies a snapshot's settings. Returns true when the values changed so callers
-- can react (e.g. rebuild UI on a text-size change).
function Preferences.apply(settings): boolean
	if settings == nil then
		return false
	end
	local changed = not state.applied
		or state.reducedMotion ~= (settings.reducedMotion == true)
		or state.soundEnabled ~= (settings.soundEnabled ~= false)
		or state.visualEffects ~= (settings.visualEffects ~= false)
		or state.colorblindMode ~= (settings.colorblindMode == true)
		or state.textScale ~= (settings.textScale or "Normal")

	state.reducedMotion = settings.reducedMotion == true
	state.soundEnabled = settings.soundEnabled ~= false
	state.visualEffects = settings.visualEffects ~= false
	state.colorblindMode = settings.colorblindMode == true
	state.textScale = settings.textScale or "Normal"
	state.applied = true

	Theme.applyPreferences(settings)
	return changed
end

function Preferences.reducedMotion(): boolean
	return state.reducedMotion
end

function Preferences.soundEnabled(): boolean
	return state.soundEnabled
end

function Preferences.visualEffects(): boolean
	return state.visualEffects
end

function Preferences.textScale(): string
	return state.textScale
end

return Preferences
