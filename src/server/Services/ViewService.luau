--!nonstrict
-- Composes the player-facing state snapshot sent to clients.
-- Clients receive definition ids and resolve display data from shared config,
-- keeping payloads small and preventing the client from inventing values.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Encumbrance = require(ReplicatedStorage.Shared.Domain.Encumbrance)
local Economy = require(ReplicatedStorage.Shared.Domain.Economy)
local Inventory = require(ReplicatedStorage.Shared.Domain.Inventory)
local Progression = require(ReplicatedStorage.Shared.Domain.Progression)

local ViewService = {}

local state = { ctx = nil }

function ViewService:Init(ctx)
	state.ctx = ctx
end

local function countExhibited(profile): (number, number)
	local incomePerMinute = 0
	local count = 0
	for _, uid in profile.museum do
		local owned = profile.relics[uid]
		local definition = owned and GameConfig.Relics[owned.id]
		if definition then
			incomePerMinute += definition.incomePerMinute
			count += 1
		end
	end
	return incomePerMinute, count
end

function ViewService:Build(player: Player)
	local services = state.ctx.Services
	local profile = services.PlayerData:GetProfile(player)
	if profile == nil then
		return nil
	end

	local now = os.time()
	local upgrades = profile.upgrades
	local movement = GameConfig.Movement
	local maxPedestals = 8

	local backpackLevel = upgrades.Backpack or 0
	local bootsLevel = upgrades.SprintBoots or 0
	local armorLevel = upgrades.Armor or 0
	local floorLevel = upgrades.MuseumFloor or 0
	local pedestalLevel = upgrades.ExtraPedestal or 0

	local capacity = Encumbrance.capacity(movement, backpackLevel)
	local pedestalCount = Economy.pedestalCount(
		movement.BasePedestals,
		floorLevel,
		GameConfig.Upgrades.MuseumFloor.perLevel,
		pedestalLevel,
		GameConfig.Upgrades.ExtraPedestal.perLevel,
		maxPedestals
	)

	local exhibitedIncome, exhibitedCount = countExhibited(profile)
	local incomeRate = Economy.incomeRatePerMinute(
		exhibitedIncome,
		floorLevel,
		GameConfig.Museum.IncomePerMinuteFloorBonus,
		GameConfig.Museum.MaxIncomeRatePerMinute
	)
	local pendingIncome = Economy.pendingIncome(
		incomeRate,
		profile.lastIncomeClaimAt,
		now,
		GameConfig.Economy.OfflineCapSeconds,
		GameConfig.Economy.MaxPendingIncome
	)

	local relics = {}
	for uid, owned in profile.relics do
		local definition = GameConfig.Relics[owned.id]
		if definition then
			table.insert(relics, {
				uid = uid,
				id = owned.id,
				name = definition.name,
				rarity = definition.rarity,
				weight = definition.weight,
				value = definition.value,
				incomePerMinute = definition.incomePerMinute,
				acquiredAt = owned.acquiredAt,
				exhibited = Inventory.isExhibited(profile, uid),
			})
		end
	end
	table.sort(relics, function(a, b)
		if a.acquiredAt == b.acquiredAt then
			return a.uid < b.uid
		end
		return a.acquiredAt > b.acquiredAt
	end)

	local displayed = table.clone(profile.museum)

	local pedestals = {}
	for index = 1, maxPedestals do
		local id = tostring(index)
		table.insert(pedestals, {
			id = id,
			unlocked = index <= pedestalCount,
			uid = profile.museum[id],
		})
	end

	local temples = {}
	for templeId, config in GameConfig.Temples do
		local unlocked = Progression.isUnlocked(profile.unlockedTemples, templeId)
		local requirementsMet = profile.stats.extractions >= config.minExtractions
		local canUnlock = (not unlocked) and requirementsMet and profile.gold >= config.unlockPrice
		table.insert(temples, {
			id = templeId,
			name = config.name,
			description = config.description,
			difficulty = config.difficulty,
			order = config.order,
			unlocked = unlocked,
			requirementsMet = requirementsMet,
			canUnlock = canUnlock,
			minExtractions = config.minExtractions,
			unlockPrice = config.unlockPrice,
			requiredRelics = config.requiredRelics,
			durationSeconds = config.durationSeconds,
			relicCount = #config.relicSpawns,
		})
	end
	table.sort(temples, function(a, b)
		return a.order < b.order
	end)

	local expedition = nil
	local expeditionState = services.Expedition:GetState(player)
	if expeditionState then
		local temple = GameConfig.Temples[expeditionState.templeId]
		local carried = {}
		local totalWeight = 0
		for _, item in expeditionState.carried do
			local definition = GameConfig.Relics[item.definitionId]
			if definition then
				totalWeight += definition.weight
				table.insert(carried, {
					uid = item.uid,
					id = item.definitionId,
					name = definition.name,
					rarity = definition.rarity,
					weight = definition.weight,
					value = definition.value,
				})
			end
		end
		local reduction = bootsLevel * GameConfig.Upgrades.SprintBoots.perLevel
		local multiplier = Encumbrance.multiplier(totalWeight, movement, reduction)
		expedition = {
			templeId = expeditionState.templeId,
			templeName = temple and temple.name or expeditionState.templeId,
			startedAt = expeditionState.startedAt,
			endsAt = expeditionState.endsAt,
			collapsing = expeditionState.collapsing,
			carried = carried,
			weight = totalWeight,
			capacity = capacity,
			speedMultiplier = multiplier,
			requiredRelics = temple and temple.requiredRelics or 1,
			durationSeconds = temple and temple.durationSeconds or 0,
			remainingRelics = #expeditionState.carried,
		}
	end

	local plot = services.Plot:GetPlot(player)
	local ephemeral = services.PlayerData:IsEphemeral(player)

	return {
		serverNow = now,
		gold = profile.gold,
		incomePerMinute = incomeRate,
		pendingIncome = pendingIncome,
		lastIncomeClaimAt = profile.lastIncomeClaimAt,
		relics = relics,
		displayed = displayed,
		pedestals = pedestals,
		pedestalCount = pedestalCount,
		exhibitedCount = exhibitedCount,
		upgrades = {
			SprintBoots = bootsLevel,
			Backpack = backpackLevel,
			Armor = armorLevel,
			MuseumFloor = floorLevel,
			ExtraPedestal = pedestalLevel,
		},
		capacity = capacity,
		armorLevel = armorLevel,
		temples = temples,
		expedition = expedition,
		stats = profile.stats,
		settings = profile.settings,
		tutorialComplete = profile.tutorialComplete,
		plotIndex = plot and plot.index or nil,
		ephemeral = ephemeral,
		maxCarried = GameConfig.Economy.MaxCarriedRelics,
		offlineCapSeconds = GameConfig.Economy.OfflineCapSeconds,
	}
end

return ViewService
