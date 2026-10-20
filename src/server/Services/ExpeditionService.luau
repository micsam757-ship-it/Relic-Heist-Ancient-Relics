--!nonstrict
-- Expedition lifecycle: entry, timers, warnings, death, and abandonment.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Contracts = require(ReplicatedStorage.Shared.Net.Contracts)
local Encumbrance = require(ReplicatedStorage.Shared.Domain.Encumbrance)
local Progression = require(ReplicatedStorage.Shared.Domain.Progression)
local PlayerUtil = require(script.Parent.Parent.Utilities.PlayerUtil)
local Logger = require(script.Parent.Parent.Utilities.Logger)

local ExpeditionService = {}

local state = {
	ctx = nil,
	logger = nil,
	expeditions = {},
	characterConnections = {},
}

function ExpeditionService:Init(ctx)
	state.ctx = ctx
	state.logger = Logger.new("Expedition")
end

function ExpeditionService:GetState(player: Player)
	return state.expeditions[player]
end

function ExpeditionService:GetCarriedWeight(player: Player): number
	local expedition = state.expeditions[player]
	if expedition == nil then
		return 0
	end
	local total = 0
	for _, item in expedition.carried do
		local definition = GameConfig.Relics[item.definitionId]
		if definition then
			total += definition.weight
		end
	end
	return total
end

function ExpeditionService:GetPlayersInTemple(templeId: string): { Player }
	local result = {}
	for player, expedition in state.expeditions do
		if expedition.templeId == templeId then
			table.insert(result, player)
		end
	end
	return result
end

function ExpeditionService:IsInTemple(player: Player, templeId: string): boolean
	local expedition = state.expeditions[player]
	return expedition ~= nil and expedition.templeId == templeId
end

function ExpeditionService:RecalculateMovement(player: Player)
	local expedition = state.expeditions[player]
	local humanoid = PlayerUtil.getHumanoid(player)
	if expedition == nil or humanoid == nil then
		return
	end
	local profile = state.ctx.Services.PlayerData:GetProfile(player)
	local bootsLevel = profile and (profile.upgrades.SprintBoots or 0) or 0
	local reduction = bootsLevel * GameConfig.Upgrades.SprintBoots.perLevel
	local weight = ExpeditionService:GetCarriedWeight(player)
	humanoid.WalkSpeed = Encumbrance.walkSpeed(weight, GameConfig.Movement, reduction)
end

function ExpeditionService:AddCarried(player: Player, definitionId: string, uid: string)
	local expedition = state.expeditions[player]
	if expedition == nil then
		return false
	end
	table.insert(expedition.carried, { uid = uid, definitionId = definitionId })
	ExpeditionService:RecalculateMovement(player)
	return true
end

function ExpeditionService:TeleportToPlot(player: Player)
	local plot = state.ctx.Services.Plot:GetPlot(player)
	if plot == nil then
		return
	end
	local character = player.Character
	if character then
		character:PivotTo(plot.spawnCFrame)
	end
end

local function clearExpedition(player: Player)
	local expedition = state.expeditions[player]
	if expedition == nil then
		return nil
	end
	state.ctx.Services.Hazard:StopCollapse(player)
	state.expeditions[player] = nil
	return expedition
end

function ExpeditionService:RequestEnter(player: Player, templeId: string, source: string, anchor: Vector3?)
	if not state.ctx.Services.PlayerData:IsLoaded(player) then
		return false, "Your profile is still loading."
	end
	if state.expeditions[player] ~= nil then
		return false, "You are already on an expedition."
	end
	if not PlayerUtil.isAlive(player) then
		return false, "You must be alive to enter a temple."
	end

	local temple = GameConfig.Temples[templeId]
	if temple == nil then
		return false, "That expedition does not exist."
	end

	local profile = state.ctx.Services.PlayerData:GetProfile(player)
	if not Progression.isUnlocked(profile.unlockedTemples, templeId) then
		return false, "That expedition is locked. Unlock it in the Expeditions menu."
	end

	local root = PlayerUtil.getRoot(player)
	if root == nil then
		return false, "Your character is not ready."
	end
	if source == "prompt" and anchor ~= nil then
		if (root.Position - anchor).Magnitude > 24 then
			return false, "Move closer to the portal."
		end
	else
		if root.Position.Magnitude > 320 then
			return false, "Return to the hub to start an expedition."
		end
	end

	local runtime = state.ctx.World.Temples[templeId]
	if runtime == nil then
		return false, "That temple is unavailable."
	end

	local now = os.time()
	state.expeditions[player] = {
		templeId = templeId,
		startedAt = now,
		endsAt = now + temple.durationSeconds,
		carried = {},
		warned60 = false,
		warned30 = false,
		warned10 = false,
		collapsing = false,
		extracting = false,
	}

	player:SetAttribute("LastDamageSource", "")
	root.CFrame = runtime.spawnCFrame
	ExpeditionService:RecalculateMovement(player)

	state.ctx.Services.Analytics:Track("expedition_entered", { temple = templeId })
	if state.ctx.Services.Tutorial then
		state.ctx.Services.Tutorial:Advance(player, "enteredTemple")
	end
	state.ctx.Services.Network:PushEvent(player, "ExpeditionStarted", {
		templeId = templeId,
		templeName = temple.name,
		endsAt = state.expeditions[player].endsAt,
		durationSeconds = temple.durationSeconds,
		requiredRelics = temple.requiredRelics,
	})
	state.ctx.Services.Network:Toast(
		player,
		"info",
		string.format("Entering %s. Collect relics and escape!", temple.name)
	)
	state.ctx.Services.Network:PushState(player)
	return true
end

function ExpeditionService:EndExpedition(player: Player)
	return clearExpedition(player)
end

local function onDeath(player: Player)
	local expedition = state.expeditions[player]
	if expedition == nil then
		return
	end
	local lostCount = #expedition.carried
	local cause = player:GetAttribute("LastDamageSource") or "Unknown"
	local profile = state.ctx.Services.PlayerData:GetProfile(player)

	clearExpedition(player)

	if profile then
		profile.stats.deaths += 1
		state.ctx.Services.PlayerData:MarkDirty(player)
	end

	state.ctx.Services.Analytics:Track("player_died", { temple = expedition.templeId, cause = cause })
	state.ctx.Services.Network:PushEvent(player, "ExpeditionSummary", {
		success = false,
		title = "You Perished",
		subtitle = string.format("Killed by %s", cause),
		lostRelics = lostCount,
		lines = {
			string.format("Relics lost: %d", lostCount),
			"Return to the surface and try again.",
		},
	})
	state.ctx.Services.Network:Toast(player, "error", "You died. Carried relics were lost.")
	state.ctx.Services.Network:PushState(player)
end

local function onCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	state.ctx.Services.Upgrade:ApplyEffects(player)
	if state.expeditions[player] == nil then
		humanoid.WalkSpeed = GameConfig.Movement.BaseWalkSpeed
	end
	humanoid.Died:Connect(function()
		onDeath(player)
	end)
end

local function bindPlayer(player: Player)
	if state.characterConnections[player] then
		return
	end
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
	state.characterConnections[player] = player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
end

function ExpeditionService:Start()
	local services = state.ctx.Services

	for templeId, portal in state.ctx.World.Hub.portals do
		portal.prompt.Triggered:Connect(function(player)
			local position = portal.position
			local ok, reason = ExpeditionService:RequestEnter(player, templeId, "prompt", position)
			if not ok and reason then
				services.Network:Toast(player, "warning", reason)
			end
		end)
	end

	Players.PlayerAdded:Connect(bindPlayer)
	Players.PlayerRemoving:Connect(function(player)
		if state.characterConnections[player] then
			state.characterConnections[player]:Disconnect()
			state.characterConnections[player] = nil
		end
	end)
	for _, player in Players:GetPlayers() do
		bindPlayer(player)
	end

	services.Network:RegisterAction("EnterExpedition", function(player, data)
		local valid = Contracts.check("EnterExpedition", data)
		if not valid then
			return false, "Invalid request."
		end
		local ok, enterReason = ExpeditionService:RequestEnter(player, data.templeId, "remote", nil)
		if ok then
			return true
		end
		return false, enterReason
	end, { perSecond = 1, burst = 3 })

	services.Network:RegisterAction("AbandonExpedition", function(player, _data)
		local expedition = state.expeditions[player]
		if expedition == nil then
			return false, "You are not on an expedition."
		end
		local lostCount = #expedition.carried
		clearExpedition(player)
		ExpeditionService:TeleportToPlot(player)
		services.Analytics:Track("expedition_abandoned", { temple = expedition.templeId, lost = lostCount })
		services.Network:PushEvent(player, "ExpeditionSummary", {
			success = false,
			title = "Expedition Abandoned",
			subtitle = "You left the temple early.",
			lostRelics = lostCount,
			lines = { string.format("Relics lost: %d", lostCount) },
		})
		services.Network:PushState(player)
		return true
	end, { perSecond = 1, burst = 3 })

	task.spawn(function()
		while true do
			task.wait(0.5)
			local now = os.time()
			for player, expedition in pairs(state.expeditions) do
				if player.Parent == nil then
					clearExpedition(player)
					continue
				end
				local remaining = expedition.endsAt - now
				if remaining <= 10 and not expedition.warned10 then
					expedition.warned10 = true
					services.Network:PushEvent(
						player,
						"ExpeditionWarning",
						{ remaining = remaining, level = "critical" }
					)
				elseif remaining <= 30 and not expedition.warned30 then
					expedition.warned30 = true
					services.Network:PushEvent(player, "ExpeditionWarning", { remaining = remaining, level = "high" })
				elseif remaining <= 60 and not expedition.warned60 then
					expedition.warned60 = true
					services.Network:PushEvent(player, "ExpeditionWarning", { remaining = remaining, level = "medium" })
				end

				if remaining <= 0 and not expedition.collapsing then
					expedition.collapsing = true
					services.Hazard:StartCollapse(player)
					services.Network:PushEvent(player, "ExpeditionWarning", { remaining = 0, level = "collapse" })
					services.Network:Toast(player, "error", "The temple is collapsing! Escape immediately!")
				end
			end
		end
	end)
end

return ExpeditionService
