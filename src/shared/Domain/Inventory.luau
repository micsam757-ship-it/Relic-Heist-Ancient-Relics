--!strict
-- Pure inventory and museum ownership transitions. No Roblox APIs.
-- Owned relics are stored once per unique instance. Museum pedestal assignments
-- reference owned instances, which makes duplication impossible by construction.

local Inventory = {}

export type OwnedRelic = {
	id: string,
	acquiredAt: number,
}

export type InventoryProfile = {
	relics: { [string]: OwnedRelic },
	museum: { [string]: string },
}

function Inventory.countOwned(profile: InventoryProfile): number
	local count = 0
	for _ in profile.relics do
		count += 1
	end
	return count
end

function Inventory.hasRelic(profile: InventoryProfile, uid: string): boolean
	return profile.relics[uid] ~= nil
end

function Inventory.isExhibited(profile: InventoryProfile, uid: string): boolean
	for _, displayedUid in profile.museum do
		if displayedUid == uid then
			return true
		end
	end
	return false
end

function Inventory.addOwned(
	profile: InventoryProfile,
	uid: string,
	definitionId: string,
	now: number,
	maxRelics: number
): (boolean, string?)
	if profile.relics[uid] ~= nil then
		return false, "That relic is already owned."
	end
	if Inventory.countOwned(profile) >= maxRelics then
		return false, "Your relic archive is full."
	end
	profile.relics[uid] = { id = definitionId, acquiredAt = now }
	return true, nil
end

function Inventory.removeOwned(profile: InventoryProfile, uid: string): (boolean, string?)
	if profile.relics[uid] == nil then
		return false, "You do not own that relic."
	end
	for pedestalId, displayedUid in profile.museum do
		if displayedUid == uid then
			profile.museum[pedestalId] = nil
		end
	end
	profile.relics[uid] = nil
	return true, nil
end

function Inventory.exhibit(
	profile: InventoryProfile,
	uid: string,
	pedestalId: string,
	unlockedPedestals: number
): (boolean, string?)
	local slot = tonumber(pedestalId)
	if slot == nil or slot < 1 or slot > unlockedPedestals or slot % 1 ~= 0 then
		return false, "That pedestal is not available."
	end
	if profile.relics[uid] == nil then
		return false, "You do not own that relic."
	end
	if profile.museum[pedestalId] ~= nil then
		return false, "That pedestal is already occupied."
	end
	if Inventory.isExhibited(profile, uid) then
		return false, "That relic is already on display."
	end
	profile.museum[pedestalId] = uid
	return true, nil
end

function Inventory.unexhibit(profile: InventoryProfile, pedestalId: string): (string?, string?)
	local uid = profile.museum[pedestalId]
	if uid == nil then
		return nil, "That pedestal is empty."
	end
	if profile.relics[uid] == nil then
		profile.museum[pedestalId] = nil
		return nil, "The displayed relic record was invalid and has been cleared."
	end
	profile.museum[pedestalId] = nil
	return uid, nil
end

function Inventory.unexhibitUid(profile: InventoryProfile, uid: string): boolean
	for pedestalId, displayedUid in profile.museum do
		if displayedUid == uid then
			profile.museum[pedestalId] = nil
			return true
		end
	end
	return false
end

return Inventory
