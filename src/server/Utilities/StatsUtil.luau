--!nonstrict
-- The bridge between a stored profile and the effective-stat resolver.
--
-- The resolver works on training *levels*; the profile stores training
-- *experience*. This is the one place that turns a profile into the numbers
-- every system uses, so the levels are always derived the same way.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Stats = require(ReplicatedStorage.Shared.Domain.Stats)
local Training = require(ReplicatedStorage.Shared.Domain.Training)

local StatsUtil = {}

-- The training levels a profile has earned.
function StatsUtil.trainingLevels(profile): { [string]: number }
	local experience = profile and profile.training or {}
	return Training.levels(experience, GameConfig.Training.Attributes)
end

-- The effective stats for a profile: upgrades plus training.
function StatsUtil.forProfile(profile)
	return Stats.resolve(
		GameConfig.StatConfig,
		profile and profile.upgrades or {},
		StatsUtil.trainingLevels(profile)
	)
end

return StatsUtil
