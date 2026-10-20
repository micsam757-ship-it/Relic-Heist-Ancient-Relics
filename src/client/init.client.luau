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
local Preferences = require(script.Preferences)
local Audio = require(script.Controllers.SoundController)
local InputController = require(script.Controllers.InputController)
local EffectsController = require(script.Controllers.EffectsController)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

UIRoot.build(playerGui)

local tutorialShown = false

State.onChanged(function(snapshot)
	Preferences.apply(snapshot.settings)
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
		Audio.play(data.success and "ExtractionSuccess" or "ExtractionFail")
	elseif name == "PedestalSelected" then
		UIRoot.showPedestalPrompt(data)
	elseif name == "RelicCollected" then
		Audio.play("RelicCollect")
	elseif name == "TutorialStep" then
		UIRoot.tutorialAdvance()
	elseif name == "TutorialComplete" then
		UIRoot.tutorialComplete()
	elseif name == "Damage" then
		UIRoot.damageFlash()
		Audio.play("Damage")
	elseif name == "HazardWarning" then
		local kind = data.kind
		if kind == "collapse" then
			UIRoot.toast("error", "The temple is collapsing!")
		elseif kind == "guardian" then
			UIRoot.toast("warning", string.format("%s strikes!", tostring(data.label or "Guardian")))
		else
			UIRoot.toast("warning", string.format("%s — incoming!", tostring(data.label or "Trap")))
		end
	elseif name == "ExpeditionWarning" and data.level ~= "collapse" then
		UIRoot.toast("warning", string.format("Escape in %d seconds!", math.floor(tonumber(data.remaining) or 0)))
	elseif name == "WelcomeBack" then
		UIRoot.showWelcomeBack(data)
	elseif name == "WelcomeBackClosed" then
		UIRoot.closeWelcomeBack()
	elseif name == "ReviveOffer" then
		UIRoot.showRevivePrompt(data)
	elseif name == "ReviveClosed" then
		UIRoot.closeRevivePrompt()
	end
end)

Audio.start()
InputController.start()
EffectsController.start()

Net.send("RequestState")
