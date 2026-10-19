--!strict
-- Shared type definitions for runtime data and network payloads.

export type Rarity = "Common" | "Rare" | "Legendary" | "Mythic"

export type RelicDefinition = {
	name: string,
	description: string,
	rarity: Rarity,
	weight: number,
	value: number,
	incomePerMinute: number,
	templeIds: { string },
	visual: {
		kind: string,
		primary: { number },
		secondary: { number },
		glow: boolean,
	},
}

export type OwnedRelic = {
	id: string,
	acquiredAt: number,
}

export type MuseumState = {
	[string]: string,
}

export type UpgradeLevels = {
	[string]: number,
}

export type PlayerStats = {
	extractions: number,
	deaths: number,
	relicsCollected: number,
	incomeClaimed: number,
}

export type PlayerSettings = {
	soundEnabled: boolean,
	visualEffects: boolean,
}

export type PlayerProfile = {
	schemaVersion: number,
	sessionId: string,
	updatedAt: number,
	gold: number,
	tutorialComplete: boolean,
	stats: PlayerStats,
	relics: { [string]: OwnedRelic },
	museum: MuseumState,
	upgrades: UpgradeLevels,
	unlockedTemples: { [string]: boolean },
	lastIncomeClaimAt: number,
	settings: PlayerSettings,
}

export type CarriedRelic = {
	uid: string,
	definitionId: string,
}

export type ExpeditionState = {
	templeId: string,
	startedAt: number,
	endsAt: number,
	carried: { CarriedRelic },
	warned60: boolean,
	warned30: boolean,
	warned10: boolean,
	collapsing: boolean,
}

export type RemoteAction = {
	action: string,
	data: any?,
}

export type ToastPayload = {
	kind: string,
	message: string,
}

export type UIPayload = {
	name: string,
	data: any?,
}

export type ActionResponse = {
	ok: boolean,
	message: string?,
}

return {}
