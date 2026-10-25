--!nonstrict
-- Passive training: experience is earned by playing, never bought.
--
-- Relics collected and hauls extracted award experience to the attributes they
-- represent. Levels are derived from the stored experience, so the service
-- only ever writes experience and lets the training rules derive the levels.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Training = require(ReplicatedStorage.Shared.Domain.Training)
local Logger = require(script.Parent.Parent.Utilities.Logger)

local TrainingService = {}

-- How often temple time is converted into experience. The remainder is kept
-- between ticks so slow rates still award whole experience eventually.
local TEMPLE_TICK_SECONDS = 5

local state = {
	ctx = nil,
	logger = nil,
	-- Fractional experience earned by time spent inside a temple, per player.
	templeXp = {},
}

local ATTRIBUTE_LABELS = {
	strength = "Strength",
	stamina = "Stamina",
	carrying = "Carrying",
}

function TrainingService:Init(ctx)
	state.ctx = ctx
	state.logger = Logger.new("Training")
end

-- The training view for the client: level and progress per attribute.
function TrainingService:GetView(profile)
	local experience = profile and profile.training or {}
	local view = {}
	for attribute, definition in GameConfig.Training.Attributes do
		local progress = Training.progress(experience[attribute] or 0, definition.MaxLevel)
		view[attribute] = {
			level = progress.level,
			maxLevel = progress.maxLevel,
			xp = progress.xp,
			intoLevel = progress.intoLevel,
			neededForNext = progress.neededForNext,
			ratio = progress.ratio,
			maxed = progress.maxed,
		}
	end
	return view
end

-- Awards experience to one attribute. Returns the levels gained (0 or 1).
function TrainingService:Award(player: Player, attribute: string, amount: number): number
	if amount <= 0 then
		return 0
	end
	local profile = state.ctx.Services.PlayerData:GetProfile(player)
	if profile == nil then
		return 0
	end
	local definition = GameConfig.Training.Attributes[attribute]
	if definition == nil then
		return 0
	end

	local before = Training.levelForXp(profile.training and profile.training[attribute] or 0, definition.MaxLevel)
	local updated, gained = Training.award(profile.training or {}, attribute, amount, definition.MaxLevel)
	if gained <= 0 then
		return 0
	end
	profile.training = updated
	state.ctx.Services.PlayerData:MarkDirty(player)

	-- A stamina level changes the pool size, so refresh the runtime pool (it
	-- keeps its fill ratio) before the client is told about the new level.
	local stamina = state.ctx.Services.Stamina
	if stamina ~= nil then
		stamina:EnsureState(player)
	end
	-- Awarding from a timer has no other snapshot trigger, so push here. The
	-- client's training bars stay live even between relics and extractions.
	state.ctx.Services.Network:PushState(player)

	local after = Training.levelForXp(updated[attribute], definition.MaxLevel)
	if after <= before then
		return 0
	end
	local label = ATTRIBUTE_LABELS[attribute] or attribute
	state.ctx.Services.Network:Toast(player, "success", string.format("%s training reached level %d!", label, after))
	state.ctx.Services.Analytics:Track("training_level_up", { attribute = attribute, level = after })
	return after - before
end

-- Awards a table of `{ attribute = amount }` in one go.
function TrainingService:AwardAll(player: Player, amounts: { [string]: number })
	local levels = 0
	for attribute, amount in amounts do
		levels += self:Award(player, attribute, amount)
	end
	return levels
end

-- Experience for collecting a relic.
function TrainingService:OnRelicCollected(player: Player, count: number)
	local rewards = GameConfig.Training.Xp.PerRelicCollected
	self:AwardAll(player, {
		carrying = (rewards.carrying or 0) * count,
		stamina = (rewards.stamina or 0) * count,
	})
end

-- Experience for a successful haul.
function TrainingService:OnExtracted(player: Player, count: number)
	local rewards = GameConfig.Training.Xp.PerExtraction
	self:AwardAll(player, {
		strength = (rewards.strength or 0) * count,
		stamina = (rewards.stamina or 0) * count,
		carrying = (rewards.carrying or 0) * count,
	})
end

-- Experience for time spent inside a temple. Called on a slow server tick.
function TrainingService:OnTempleTime(player: Player, seconds: number)
	local expedition = state.ctx.Services.Expedition:GetState(player)
	if expedition == nil or seconds <= 0 then
		state.templeXp[player] = nil
		return
	end
	local rewards = GameConfig.Training.Xp.PerTempleMinute
	local accrual = state.templeXp[player]
	if accrual == nil then
		accrual = {}
		state.templeXp[player] = accrual
	end
	for attribute, perMinute in rewards do
		local amount = (accrual[attribute] or 0) + (perMinute or 0) * seconds / 60
		local whole = math.floor(amount)
		accrual[attribute] = amount - whole
		if whole > 0 then
			self:Award(player, attribute, whole)
		end
	end
end

local function tickTempleTime()
	for player in state.templeXp do
		if player.Parent ~= Players then
			state.templeXp[player] = nil
		end
	end
	for _, player in Players:GetPlayers() do
		TrainingService:OnTempleTime(player, TEMPLE_TICK_SECONDS)
	end
end

function TrainingService:Start()
	task.spawn(function()
		while true do
			task.wait(TEMPLE_TICK_SECONDS)
			pcall(tickTempleTime)
		end
	end)
end

return TrainingService
