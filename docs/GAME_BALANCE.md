# Game Balance

All values are in `src/shared/Config/GameConfig.luau`. This document explains
intent; the config is the source of truth.

## Currencies and rates

- Start gold: 250.
- Museum income is displayed and accrued per second (`/sec`) in the UI, but is
  authored per minute in `GameConfig` for readability. It is additive per
  exhibit, multiplied by the Museum Expansion bonus (`+5%` per level), and the
  per-minute rate is capped at `5000/min` (`~83.3/sec`) before conversion.
- While online, income auto-deposits every second. While offline it caps at the
  4-hour offline window (`24h` for VIP Pass holders) and at the pending ceiling
  (`50000`, or `200000` for VIP), and is held for the Welcome Back modal. The
  free 1x claim grants it as-is; the 199-Robux 2x doubles that one payout.
- Extraction converts carried relic value to gold at `25%`.

## Carrying

- Base capacity 40 weight; `+20` per Reinforced Backpack level (max level 6,
  so a fully upgraded pack holds 160 weight).
- Base walk speed 19 studs/s (`GameConfig.Movement.BaseWalkSpeed`), tuned for the
  tightened 380-stud plot ring so foyer → hub plaza → temple portal crossings stay
  fast and fluid.
- Weight reduces speed at `0.8%` per weight unit; Sprint Boots reduce the
  penalty by `4%` per level; speed floors at `35%`.
- Max 10 carried relics regardless of weight.
- Owned relics cap at 100 per profile; overflow on extraction is lost by design.

## Temples

| Temple | Unlock | Duration | Required relics | Hazard profile |
| --- | --- | --- | --- | --- |
| Tutorial Ruins | free | 5:00 | 1 | one dart trap, one boulder (softened tell: 26 dmg, 2.4 s) |
| Forgotten Catacombs | 1 extraction + 500 gold | 6:00 | 2 | two dart traps, one boulder, one Stone Guardian, tighter paths |
| Sunken Sanctum | 2 extractions + 1500 gold | 7:00 | 3 | two whirling blades, one dart trap, one boulder, two guardians (one faster) |
| Void Citadel | 4 extractions + 5000 gold | 8:00 | 3 | two void darts, two rift blades, a collapsing star, three Void Wardens (one faster Rift Keeper) |

### Extraction credit

An extraction only counts toward the next temple's `minExtractions` gate when
the player extracts at least that temple's `requiredRelics` count
(`RunRules.extractionCredit`). Gold from the 25% stipend is always paid, even
on a short or empty-handed haul; the progression gate is not. This closes the
walk-in walk-out farm at the spawn-adjacent extraction altar.

Every temple's N lightest relics must fit a fully upgraded backpack (enforced
by the `requiredRelics is haulable` test), so a qualifying haul is always
physically possible.

### Relic pools

Relic pickups are scoped to temple occupancy: the pool spawns when the first
player enters and is destroyed when the last player leaves
(`RelicService:OnExpeditionStarted` / `OnExpeditionEnded`). Every expedition
therefore starts from a full pool — temples are replayable, and players who
share a temple share one pool rather than seeing stacked duplicates.

### Guardians

| Enemy | Speed | Damage | Aggro | Windup | Notes |
| --- | --- | --- | --- | --- | --- |
| Stone Guardian | 12 | 24 | 54 | 0.40 s | Base kind; Catacombs patrol. |
| Drowned Warden | 13 | 24 | 54 | 0.40 s | Sanctum; slightly faster. |
| Deep Sentinel | 15 | 26 | 52 | 0.40 s | Sanctum; fast, teal eyes. |
| Void Warden | 17 | 32 | 64 | 0.35 s | Void Citadel; endgame kind. |
| Rift Keeper | 19 | 36 | 70 | 0.35 s | Void Citadel; fastest, one per temple. |

Guardians patrol a waypoint loop; when a player is visible within aggro range the
guardian chases at `speed × 1.35`. Deal damage after the listed windup
(dodgeable). If the player breaks line of sight or stealths, the guardian keeps
chasing toward the player's **last-known position** for `HuntSeconds` (4 s) or
until it arrives, then resumes patrol; aggro also lingers `AggroLingerSeconds`
(5 s). Contact hits share the standard 0.35 s invulnerability window and a 0.85 s
self-cooldown, so they cannot chain-stun. There is no reward for a guardian; they
are a positional hazard within the escape loop.

Relic values span 90 (Clay Ankh) to 40000 (Eye of the Void), with income
90..700/min for the Abyssal top end.

Blades are rotating sweep hazards. A blade spins at `speed` rad/s; a player
within `hitRadius` of the blade's swept line (checked on the horizontal plane
via `Util.distanceToSegment2D`) takes `damage`. The loop idles at 0.5 s when no
player is in the temple, so blades cost nothing on an empty server.

## Upgrades

| Upgrade | Max | Base price | Growth | Effect |
| --- | --- | --- | --- | --- |
| Sprint Boots | 5 | 200 | 1.75 | -4% weight penalty / level |
| Reinforced Backpack | 6 | 250 | 1.75 | +20 capacity / level |
| Reinforced Armor | 5 | 300 | 1.75 | +20 max health / level |
| Museum Expansion | 2 | 800 | 2.1 | +3 pedestals, +5% income / level |
| Extra Pedestal | 2 | 500 | 2.1 | +1 pedestal / level |
| Marble Colonnade | 3 | 400 | 1.9 | visual: pillars in each wing |
| Gallery Lighting | 3 | 500 | 1.9 | visual: sconces and spotlights |
| Glass Display Cases | 2 | 700 | 2.0 | visual: glass over each relic |
| Velvet Ropes | 2 | 650 | 2.0 | visual: cordons around exhibits |
| Crystal Chandeliers | 2 | 900 | 2.1 | visual: chandeliers per wing |

Total pedestals are capped at 14 (6 base + 8 from upgrades), distributed across
the three wings (Grand Foyer 6, Exhibition Hall 4, Secure Vault 4). The five
`effect = "visual"` upgrades (ADR 0010) change only the museum's appearance; they
add no gameplay power, so they are priced as optional prestige buys.

## Monetization

| Product | Price | Effect | Gate |
| --- | --- | --- | --- |
| Offline x2 | 199 R | Doubles one pending offline payout | Offered with the Welcome Back modal |
| VIP Pass | Game Pass | 24h offline window, higher pending ceiling | Read on join |
| Instant Revive | 99 R | Revive in place on death, keep carried relics | Only in `Monetization.ReviveTempleIds` (Sunken Sanctum, Void Citadel) |

The revive window is 12 s; ignoring it (or declining) resolves the death and
loses carried relics. All product IDs default to 0 (unconfigured): paid offers
are suppressed and the game stays fully playable.

## Tuning levers

- Run length: temple `durationSeconds`.
- Risk: hazard `interval`, `warning`, `damage`, `radius`, `zone`, and blade
  `speed`, `length`, `hitRadius`.
- Enemy pressure: `Enemies.AggroLingerSeconds`, `HuntSeconds`,
  `HuntArriveTolerance`, `Chase.SpeedMultiplier`, `ContactCooldownSeconds`, and
  per-kind `aggroRange`/`contactRange`/`attackWindup`.
- Reward: relic `value` and `incomePerMinute` (converted to `/sec` for the UI),
  and `ExtractionValueToGold`.
- Pacing: `BasePedestals`, upgrade prices and growth.

## Balance status

Numbers are a first pass chosen for a readable solo slice. They have **not** been
tuned against playtest data; expect to revise after the first Studio session.
