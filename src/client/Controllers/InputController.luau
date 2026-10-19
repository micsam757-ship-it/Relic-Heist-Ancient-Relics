--!nonstrict
-- Keyboard shortcuts for panels and quick actions. Mouse/touch users use the
-- on-screen top bar buttons, so no action is keyboard-only here.

local UserInputService = game:GetService("UserInputService")

local UIRoot = require(script.Parent.Parent.UI.UIRoot)
local Net = require(script.Parent.Parent.Net)

local InputController = {}

local KEY_PANELS = {
	[Enum.KeyCode.E] = "Expeditions",
	[Enum.KeyCode.B] = "Shop",
	[Enum.KeyCode.I] = "Inventory",
	[Enum.KeyCode.M] = "Museum",
	[Enum.KeyCode.O] = "Settings",
}

function InputController.start()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		local panel = KEY_PANELS[input.KeyCode]
		if panel then
			UIRoot.togglePanel(panel)
			return
		end
		if input.KeyCode == Enum.KeyCode.C then
			Net.send("ClaimIncome")
		elseif input.KeyCode == Enum.KeyCode.Escape then
			UIRoot.closePanel()
		end
	end)
end

return InputController
