--!nonstrict
-- Client entry point: wires networking into the UI, then starts input and
-- cosmetic effects. The client never decides game outcomes; it renders the
-- server-authoritative state it receives.

local Players = game:GetService("Players")

-- With init.client.luau, this directory becomes the "Client" LocalScript itself,
-- so its children (Net, State, UI, Controllers) are referenced directly off `script`.
local Net = require(script.Net)
local State = require(script.State)
local UIRoot = require(script.UI.UIRoot)
local InputController = require(script.Controllers.InputController)
local EffectsController = require(script.Controllers.EffectsController)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

UIRoot.build(playerGui)

local tutorialShown = false

State.onChanged(function(snapshot)
	if snapshot and snapshot.tutorialComplete == false and not tutorialShown then
		tutorialShown = true
		UIRoot.showTutorial()
	end
end)

Net.onState(function(snapshot)
	State.set(snapshot)
end)

Net.onEvent(function(packet)
	local name = packet.name
	local data = packet.data or {}

	if name == "Toast" then
		UIRoot.toast(data.kind or "info", data.message or "")
	elseif name == "OpenPanel" then
		UIRoot.openPanel(data.panel)
	elseif name == "ExpeditionSummary" then
		UIRoot.showSummary(data)
	elseif name == "PedestalSelected" then
		UIRoot.showPedestalPrompt(data)
	elseif name == "Damage" then
		UIRoot.damageFlash()
	elseif name == "HazardWarning" then
		local kind = data.kind
		if kind == "collapse" then
			UIRoot.toast("error", "The temple is collapsing!")
		else
			UIRoot.toast("warning", string.format("%s — incoming!", tostring(data.label or "Trap")))
		end
	elseif name == "ExpeditionWarning" and data.level ~= "collapse" then
		UIRoot.toast("warning", string.format("Escape in %d seconds!", math.floor(tonumber(data.remaining) or 0)))
	end
end)

InputController.start()
EffectsController.start()

Net.send("RequestState")
