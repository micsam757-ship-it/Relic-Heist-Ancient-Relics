--!strict
-- Client-side observable store for the latest server-authoritative state.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Shared.Utilities.Signal)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

local State = {}

local value: any = nil
local changed = Signal.new()

function State.set(nextValue: any)
	value = nextValue
	changed:Fire(nextValue)
end

function State.get()
	return value
end

function State.onChanged(handler: (any) -> ())
	return changed:Connect(handler)
end

function State.relicDefinition(definitionId: string)
	return GameConfig.Relics[definitionId]
end

function State.rarityColor(rarity: string): Color3
	local entry = GameConfig.Rarities[rarity]
	if entry then
		return Color3.fromRGB(entry.color[1], entry.color[2], entry.color[3])
	end
	return Color3.fromRGB(230, 230, 230)
end

function State.findOwned(uid: string)
	local current = value
	if current == nil then
		return nil
	end
	for _, relic in current.relics do
		if relic.uid == uid then
			return relic
		end
	end
	return nil
end

return State
