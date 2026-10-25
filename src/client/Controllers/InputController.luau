--!nonstrict
-- Panel input across devices. Keyboard users get letter shortcuts; touch users
-- use the always-visible top-bar nav; gamepad users get face-button shortcuts and
-- Roblox's native GUI focus navigation between the Selectable buttons. Escape
-- and gamepad ButtonB close the active panel.

local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local Net = require(script.Parent.Parent.Net)
local State = require(script.Parent.Parent.State)
local UIRoot = require(script.Parent.Parent.UI.UIRoot)

local InputController = {}

local KEY_PANELS = {
	[Enum.KeyCode.E] = "Expeditions",
	[Enum.KeyCode.B] = "Shop",
	[Enum.KeyCode.C] = "Companions",
	[Enum.KeyCode.I] = "Inventory",
	[Enum.KeyCode.M] = "Museum",
	[Enum.KeyCode.O] = "Settings",
}

-- Gamepad face buttons open the same panels without needing the mouse.
local GAMEPAD_PANELS = {
	[Enum.KeyCode.ButtonY] = "Expeditions",
	[Enum.KeyCode.ButtonX] = "Shop",
	[Enum.KeyCode.ButtonB] = "Museum",
	[Enum.KeyCode.ButtonA] = "Inventory",
}

-- Sprinting is a hold: shift on keyboard, the left stick click on a gamepad.
local SPRINT_KEYS = {
	[Enum.KeyCode.LeftShift] = true,
	[Enum.KeyCode.ButtonL3] = true,
}

-- Sprinting only applies inside an expedition, so the intent is only sent
-- while a run is active.
local function sprintAllowed(): boolean
	local snapshot = State.get()
	return snapshot ~= nil and snapshot.expedition ~= nil
end

local function setSprint(sprinting: boolean)
	if not sprintAllowed() then
		return
	end
	Net.send("SetSprint", { state = sprinting and "sprint" or "walk" })
end

function InputController.start()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		local panel = KEY_PANELS[input.KeyCode] or GAMEPAD_PANELS[input.KeyCode]
		if panel then
			UIRoot.togglePanel(panel)
			return
		end
		if input.KeyCode == Enum.KeyCode.Escape then
			UIRoot.closePanel()
			return
		end
		if SPRINT_KEYS[input.KeyCode] then
			setSprint(true)
		end
	end)

	UserInputService.InputEnded:Connect(function(input, _gameProcessed)
		if SPRINT_KEYS[input.KeyCode] then
			setSprint(false)
		end
	end)

	-- ContextActionService bindings make the shortcuts work even when a GUI has
	-- focus (the raw InputBegan path is swallowed while navigating with a gamepad).
	ContextActionService:BindAction("RH_ClosePanel", function(_, inputState)
		if inputState == Enum.UserInputState.End then
			return Enum.ContextActionResult.Pass
		end
		UIRoot.closePanel()
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.ButtonB)
end

return InputController
