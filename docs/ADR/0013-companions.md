# ADR 0013: Relic Companions MVP

- Status: Accepted
- Date: 2026-10-23

## Context

The Phase 2 resolver (`Stats.luau`) already combines shop upgrades and passive
training into one set of effective stats. The design's first progression system
is a small roster of collectible companions that help a hunter prepare for an
expedition. The MVP needs ownership, a single equipment slot, server-validated
bonuses, persistence, gold costs, and UI feedback, without introducing a second
calculation of capacity, health, stamina, or gold.

## Decision

### Roster and economy

- Three original definitions live in `GameConfig.Companions.Definitions`:
  - **Sun Scarab** (Rare, 1200 gold): `GoldMultiplier = 0.1` (+10%).
  - **Temple Hound** (Rare, 1800 gold): `StaminaRecovery = 3`/s and
    `WeightPenaltyReduction = 0.05`.
  - **Stone Guardian** (Legendary, 3000 gold): `Capacity = 20` and
    `StaminaMax = 20`.
- A companion is bought once with gold (`Economy:Spend`) and then owned forever.
  `GameConfig.Companions.MaxEquipped` is `1`; recruiting the first companion
  auto-equips it so the purchase has an immediate, visible effect. Equipping a
  different owned companion replaces the current one.
- `GoldMultiplier` is an additive fraction that applies to both museum income
  and the extraction stipend. The resolver clamps it to `[1, 2]`, so no stored
  or damaged value can multiply the economy without bound. The extraction
  summary shows the companion portion as a separate loot line.

### Rules and persistence

- `src/shared/Domain/Companions.luau` is the pure rule module: ownership checks,
  definition lookups, bonus aggregation, equip/replace, and unequip. It never
  computes an existing stat itself.
- The profile stores `companions: { [definitionId] = true }` and
  `equippedCompanion: string?` (schema v6, migration 5 → 6). Bonuses and prices
  are never stored.
- `Schema.normalize` drops ownership entries that are not `true`, keeps unknown
  owned ids so a newer build's data is not destroyed, and clears
  `equippedCompanion` unless it is a non-empty string that is still owned. An
  unknown or missing equipped id grants no bonus.
- `StatsUtil.forProfile` reads the equipped id, asks `Companions.bonuses`, and
  passes the result to `Stats.resolve`. No service recomputes a companion
  effect.

### Server and client

- `CompanionService` registers three actions: `BuyCompanion` and
  `EquipCompanion` (each requires a string `companionId`) and
  `UnequipCompanion` (no data). All are server-validated and rate-limited.
  Purchase, equip, and unequip re-apply existing effects (health, stamina pool,
  movement) and mark the profile dirty. With these, the documented action
  registry had 16 actions at the time; it has 17 after ADR 0014 adds `Prestige`.
- The client's `Relic Companions` panel lists definitions by cost, shows rarity,
  ownership, the equipped state, and a Recruit/Equip/Unequip button. The Recruit
  button is disabled when the player cannot afford the cost. The panel is
  reachable from the top bar or the `C` key.
- The snapshot exposes
  `companions = { owned, equipped, maxEquipped, goldMultiplier }`; ownership of
  unknown ids is filtered from the client view.

## Consequences

- Companions are a pure additive layer on the Phase 2 resolver; future companions
  need only a definition and tests, not a new stat path.
- One equipped slot keeps the UI and balance simple. The schema can add more
  slots later without changing how bonuses are aggregated.
- The gold multiplier intentionally affects both income streams. Its 2x ceiling
  bounds the long-term compounding of the single current gold companion.
- The extra profile data is tiny: at most a handful of boolean keys and one id,
  well inside the profile-size budget recorded in `docs/DATA_MODEL.md`.
- Companion leveling, fusion, trading, eggs, and cosmetic skins remain out of
  scope for the MVP.

## Alternatives

- **Stat-specific fields on the profile** (for example `goldBonus`): rejected
  because it duplicates derived values and can drift from the resolver.
- **Multiple equipped slots immediately**: rejected for the MVP; one slot keeps
  choices legible and avoids combinatorial balance work before playtest data.
- **Free companions or Robux-only acquisition**: rejected; gold costs keep the
  progression loop connected to expeditions and museum income.
