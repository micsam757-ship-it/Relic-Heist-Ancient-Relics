--!nonstrict
-- Temple relic spawning and secure collection.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Encumbrance = require(ReplicatedStorage.Shared.Domain.Encumbrance)
local StatsUtil = require(script.Parent.Parent.Utilities.StatsUtil)
local RelicVisuals = require(script.Parent.Parent.World.RelicVisuals)
local Ids = require(script.Parent.Parent.Utilities.Ids)
local PlayerUtil = require(script.Parent.Parent.Utilities.PlayerUtil)
local RateLimiter = require(script.Parent.Parent.Security.RateLimiter)
local Logger = require(script.Parent.Parent.Utilities.Logger)

local RelicService = {}

local state = {
	ctx = nil,
	logger = nil,
	pickups = {},
	limiter = nil,
}

function RelicService:Init(ctx)
	state.ctx = ctx
	state.logger = Logger.new("Relic")
	state.limiter = RateLimiter.new(GameConfig.RateLimits.RelicCollectPerSecond, 3)
end

local function rarityColor(rarityName: string): Color3
	local rarity = GameConfig.Rarities[rarityName]
	if rarity then
		return Color3.fromRGB(rarity.color[1], rarity.color[2], rarity.color[3])
	end
	return Color3.fromRGB(230, 230, 230)
end

function RelicService:SpawnTempleRelics(templeId: string, runtime)
	state.pickups[templeId] = {}
	for _, spawn in runtime.relicSpawns do
		local definition = GameConfig.Relics[spawn.definitionId]
		if definition == nil then
			continue
		end
		local model = RelicVisuals.build(definition)
		model.Name = "Pickup_" .. spawn.definitionId
		model:PivotTo(CFrame.new(spawn.position))
		model.Parent = runtime.folder
		CollectionService:AddTag(model, "RelicPickup")

		local promptPart = Instance.new("Part")
		promptPart.Name = "PickupPrompt"
		promptPart.Size = Vector3.new(3, 3, 3)
		promptPart.CFrame = CFrame.new(spawn.position + Vector3.new(0, 0.5, 0))
		promptPart.Anchored = true
		promptPart.CanCollide = false
		promptPart.CanQuery = false
		promptPart.CanTouch = false
		promptPart.Transparency = 1
		promptPart.Parent = model

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "Collect"
		prompt.ActionText = "Collect Relic"
		prompt.ObjectText = definition.name
		prompt.HoldDuration = 0.15
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = promptPart

		local billboard = Instance.new("BillboardGui")
		billboard.Name = "Label"
		billboard.Size = UDim2.fromOffset(240, 54)
		billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
		billboard.MaxDistance = 120
		billboard.Adornee = promptPart
		billboard.Parent = promptPart
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.GothamBold
		label.Text = string.format("%s [%s]", definition.name, GameConfig.Rarities[definition.rarity].label)
		label.TextColor3 = rarityColor(definition.rarity)
		label.TextScaled = true
		label.TextWrapped = true
		label.Parent = billboard

		local entry = {
			templeId = templeId,
			definitionId = spawn.definitionId,
			uid = Ids.relicUid(),
			position = spawn.position,
			model = model,
			prompt = prompt,
			collected = false,
		}
		table.insert(state.pickups[templeId], entry)

		prompt.Triggered:Connect(function(player)
			RelicService:TryCollect(player, entry)
		end)
	end
end

function RelicService:TryCollect(player: Player, entry)
	if entry.collected then
		return
	end

	local expedition = state.ctx.Services.Expedition
	local expeditionState = expedition:GetState(player)
	if expeditionState == nil or expeditionState.templeId ~= entry.templeId then
		return
	end
	if expeditionState.collapsing then
		state.ctx.Services.Network:Toast(player, "error", "The temple is collapsing! Escape now!")
		return
	end
	if os.time() > expeditionState.endsAt then
		return
	end

	if not state.limiter:Allow(tostring(player.UserId)) then
		return
	end

	local distance = PlayerUtil.distanceToPoint(player, entry.position)
	if distance == nil or distance > 16 then
		return
	end

	local profile = state.ctx.Services.PlayerData:GetProfile(player)
	if profile == nil then
		return
	end
	local definition = GameConfig.Relics[entry.definitionId]
	if definition == nil then
		return
	end

	local currentWeight = expedition:GetCarriedWeight(player)
	local capacity = StatsUtil.forProfile(profile).capacity
	local ok, reason = Encumbrance.checkCapacity(
		currentWeight,
		definition.weight,
		capacity,
		#expeditionState.carried,
		GameConfig.Economy.MaxCarriedRelics
	)
	if not ok then
		state.ctx.Services.Network:Toast(player, "warning", reason or "Too heavy.")
		return
	end

	-- Single-threaded server guarantees this check and set are atomic.
	entry.collected = true
	entry.prompt.Enabled = false
	entry.model:Destroy()

	expedition:AddCarried(player, entry.definitionId, entry.uid)
	state.ctx.Services.Analytics:Track("relic_collected", { relic = entry.definitionId })
	if state.ctx.Services.Tutorial then
		state.ctx.Services.Tutorial:Advance(player, "collectedRelic")
	end
	if state.ctx.Services.Training then
		state.ctx.Services.Training:OnRelicCollected(player, 1)
	end
	state.ctx.Services.Network:Toast(player, "success", string.format("Collected %s.", definition.name))
	state.ctx.Services.Network:PushEvent(player, "RelicCollected", {
		definitionId = entry.definitionId,
		rarity = definition.rarity,
	})
	state.ctx.Services.Network:PushState(player)
end

-- Relic pools are scoped to temple occupancy: spawned when the first player
-- enters, destroyed when the last one leaves. Every expedition therefore
-- starts from a full pool (replayable runs) without stacking duplicate
-- pickups for players who share a temple.
function RelicService:OnExpeditionStarted(_player: Player, templeId: string)
	if state.pickups[templeId] ~= nil then
		return
	end
	local runtime = state.ctx.World.Temples[templeId]
	if runtime == nil then
		return
	end
	RelicService:SpawnTempleRelics(templeId, runtime)
end

function RelicService:OnExpeditionEnded(_player: Player, templeId: string)
	if #state.ctx.Services.Expedition:GetPlayersInTemple(templeId) > 0 then
		return
	end
	RelicService:DespawnTempleRelics(templeId)
end

function RelicService:DespawnTempleRelics(templeId: string)
	local entries = state.pickups[templeId]
	if entries == nil then
		return
	end
	for _, entry in entries do
		entry.collected = true
		if entry.prompt then
			entry.prompt.Enabled = false
		end
		if entry.model then
			entry.model:Destroy()
		end
	end
	state.pickups[templeId] = nil
end

return RelicService
