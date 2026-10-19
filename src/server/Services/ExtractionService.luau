--!nonstrict
-- Secure extraction: the only path that converts carried relics into owned,
-- persistent inventory. Idempotent because the expedition state is cleared
-- before rewards are granted.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Economy = require(ReplicatedStorage.Shared.Domain.Economy)
local Inventory = require(ReplicatedStorage.Shared.Domain.Inventory)
local PlayerUtil = require(script.Parent.Parent.Utilities.PlayerUtil)
local RateLimiter = require(script.Parent.Parent.Security.RateLimiter)
local Logger = require(script.Parent.Parent.Utilities.Logger)

local ExtractionService = {}

local state = {
	ctx = nil,
	logger = nil,
	limiter = nil,
}

function ExtractionService:Init(ctx)
	state.ctx = ctx
	state.logger = Logger.new("Extraction")
	state.limiter = RateLimiter.new(1, 2)
end

local function tryExtract(player: Player, templeId: string)
	local services = state.ctx.Services
	local expedition = services.Expedition:GetState(player)
	if expedition == nil or expedition.templeId ~= templeId then
		return
	end
	if expedition.extracting then
		return
	end
	if not state.limiter:Allow(tostring(player.UserId)) then
		return
	end

	local runtime = state.ctx.World.Temples[templeId]
	if runtime == nil then
		return
	end
	local distance = PlayerUtil.distanceToPoint(player, runtime.extraction.position)
	if distance == nil or distance > 22 then
		return
	end

	local profile = services.PlayerData:GetProfile(player)
	if profile == nil then
		return
	end

	expedition.extracting = true

	local carried = expedition.carried
	local temple = GameConfig.Temples[templeId]
	local lootLines = {}
	local lootRelics = {}
	local totalValue = 0
	local transferred = 0
	local lostOverflow = 0

	for _, item in carried do
		local definition = GameConfig.Relics[item.definitionId]
		if definition then
			totalValue += definition.value
			local added =
				Inventory.addOwned(profile, item.uid, item.definitionId, os.time(), GameConfig.Save.MaxRelicsPerProfile)
			if added then
				transferred += 1
				table.insert(
					lootRelics,
					{ name = definition.name, rarity = definition.rarity, value = definition.value }
				)
			else
				lostOverflow += 1
			end
		end
	end

	local bonus = Economy.extractionBonus(totalValue, GameConfig.Economy.ExtractionValueToGold)
	profile.gold += bonus
	profile.stats.extractions += 1
	profile.stats.relicsCollected += transferred
	if not profile.tutorialComplete then
		profile.tutorialComplete = true
		services.Analytics:Track("tutorial_completed", {})
	end

	services.Expedition:EndExpedition(player)
	services.PlayerData:MarkDirty(player)
	services.Expedition:TeleportToPlot(player)

	table.insert(lootLines, string.format("Relics secured: %d", transferred))
	if lostOverflow > 0 then
		table.insert(lootLines, string.format("Archive full — %d relic(s) left behind", lostOverflow))
	end
	table.insert(lootLines, string.format("Expedition stipend: %d gold", bonus))

	services.Analytics:Track("expedition_extracted", {
		temple = templeId,
		relics = transferred,
		value = totalValue,
		bonus = bonus,
	})

	if transferred == 0 then
		services.Network:PushEvent(player, "ExpeditionSummary", {
			success = false,
			title = "Empty-Handed",
			subtitle = "You escaped, but found no relics.",
			lines = { "Nothing to display in your museum." },
		})
		services.Network:Toast(player, "warning", "You escaped with nothing.")
	else
		services.Network:PushEvent(player, "ExpeditionSummary", {
			success = true,
			title = "Extraction Successful",
			subtitle = temple and temple.name or templeId,
			relics = lootRelics,
			goldEarned = bonus,
			lines = lootLines,
		})
		services.Network:Toast(player, "success", string.format("Extracted %d relic(s)!", transferred))
	end
	services.Network:PushState(player)
end

function ExtractionService:Start()
	for templeId, runtime in state.ctx.World.Temples do
		runtime.extraction.prompt.Triggered:Connect(function(player)
			tryExtract(player, templeId)
		end)
	end
end

return ExtractionService
