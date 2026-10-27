# Changelog

All notable changes are recorded here. This project follows a simple
major.minor.patch scheme while pre-1.0.

## [Unreleased] - M6 hardening (in progress)

### Added

- **Museum Prestige** (FR-032, schema v7, ADR 0014): optional repeatable reset
  once all seven museum upgrades are maxed and all 14 pedestals are occupied.
  Pure `Prestige` rules compute eligibility, the explicit reset allowlist,
  `+5%` per level museum income (capped at `+50%`) and Curator ranks. The new
  `PrestigeService` validates the exact `PRESTIGE` confirmation, rejects active
  expeditions and ephemeral sessions, builds a non-mutating reset copy, installs
  it through `PlayerDataService:SwapProfile`, forces a save, and rolls back on
  failure. Only a successful save fires `PrestigeApplied`, rebuilding the plot
  and refreshing the museum once. The Museum panel shows level, rank, bonus and
  a requirement checklist; the confirmation modal requires typing `PRESTIGE`.
  Existing profiles migrate to v7 with prestige level 0 and no prior prestige.
- **Studio prestige test helpers:** `!rh_state` now reports museum count,
  `prestigeLevel`, `lastPrestigeAt`, and the ephemeral flag. `!rh_fillmuseum`
  places every owned relic in the available pedestals. `!rh_failsave [on|off]`
  arms a one-shot forced-save failure so Session M can exercise the prestige
  rollback path without a real DataStore outage. All remain Studio-only.
- **Relic Companions** (FR-031, schema v6, ADR 0013): three gold-purchased
  companions (`SunScarab`, `TempleHound`, `StoneGuardian`) with server-owned
  ownership and a single equipped slot. `Companions` holds the pure ownership,
  equip/replace, and bonus-aggregation rules; `CompanionService` validates and
  rate-limits the three new actions, spends gold, applies effects, marks the
  profile dirty, and pushes state. Bonuses feed the existing `Stats` resolver
  through `StatsUtil`, including an additive gold multiplier (applied to museum
  income and the extraction stipend) clamped to `[1, 2]`. A new
  `Relic Companions` panel shows rarity, ownership, equipped state, and a
  disabled-when-unaffordable Recruit button (`C` shortcut). Existing profiles
  migrate to v6 with no companions and no equipped companion.
- **Time-in-temple training XP** (FR-030): `GameConfig.Training.Xp.PerTempleMinute`
  awards Strength and Stamina every minute spent inside a temple. A 5-second
  server tick accrues fractional XP per player, awards only whole points, and
  clears accrual when the player leaves. A training award now pushes a snapshot
  so the Settings bars stay live between relics and extractions.
- Server-authoritative **stamina and sprinting** (FR-029): the pure `Stamina`
  domain module holds the pool, drain/recovery and exhaustion rules; the new
  `StaminaService` owns the runtime pool, applies the sprint speed, and pushes a
  `Stamina` event. The client only sends its hold intent through the new
  `SetSprint` action (Shift on keyboard, L3 on gamepad), so the server decides
  when sprinting applies. Sprinting is scoped to expeditions and every run
  starts with a full pool. The expedition HUD gains a stamina bar.
- A single **effective-stat resolver** (`src/shared/Domain/Stats.luau`) so
  capacity, the weight speed penalty, maximum health and the stamina pool are
  derived exactly once from upgrades, training and (future) companion bonuses.
  `StatsUtil` bridges a stored profile to the resolver (training experience is
  converted to derived levels in one place); `UpgradeService`, `ViewService`,
  `RelicService` and `ExpeditionService` now read it instead of duplicating the
  health/capacity math.
- Passive **training** (schema v5): `Training` holds the experience curve and
  derived levels, `GameConfig.Training` declares the Strength/Stamina/Carrying
  attributes and the XP awarded for relics and extractions, and
  `TrainingService` records experience and announces level-ups. Nothing is
  bought: experience comes only from playing. Training feeds the stat resolver
  (Strength reduces the weight penalty, Stamina grows the pool and lowers the
  drain, Carrying adds capacity) and is shown in the Settings panel.
- 22 new domain/config tests for stats, stamina, training, schema v5 and the
  stamina tuning, plus companion, temple-XP, schema v6, companion-config and
  prestige domain/schema/stats tests - 151 assertions total.

- Pure `Validate` module (`src/shared/Utilities/Validate.luau`) for request-payload
  shape checks, now used by `NetworkService` and unit tested (T-03).
- Pure `Persist.canCommit` module (`src/shared/Utilities/Persist.luau`) for the
  save conflict-guard decision, now used by `PlayerDataService` and unit tested
  (T-11).
- Exploit-resistance regression tests (request validation, token-bucket rate
  limiting, save conflict guard) — 52 assertions total.
- Persistence failure-mode classification in the pure `Persist` module
  (`loadOutcome`, `isWritable`, `retryBackoff`), used by `PlayerDataService` and
  unit tested. Documented as a failure-mode matrix in `docs/DATA_MODEL.md`
  (T-11/T-12) — 60 assertions total.
- Pure `Contracts` module (`src/shared/Net/Contracts.luau`) declaring each request
  action and its required `data` shape. Handlers now validate through
  `Contracts.check`, and a drift test asserts the registry matches
  `docs/API_CONTRACTS.md` — 66 assertions total.
- `tests/bench.luau` micro-benchmark for the hot pure functions (income tick,
  encumbrance, guardian distance, request admission) with a documented baseline
  and budget in `docs/PERFORMANCE.md`; run as a report step by `scripts/check.ps1`.
- `docs/STUDIO_TEST_PLAN.md` — step-by-step Studio playtest sessions covering the
  currently unverified runtime paths, with prerequisites and a results log.
- Expanding museum wings and building enhancements (ADR 0010): `GameConfig
  .MuseumBuilding` declares three wings (Grand Foyer, Exhibition Hall, Secure
  Vault) gated by the `MuseumFloor` level, five purchasable visual upgrades
  (`MarblePillars`, `Lighting`, `GlassCases`, `VelvetRopes`, `Chandeliers`), and
  per-rarity `PedestalTiers`. Pure layout/tier/enhancement rules live in
  `src/shared/Domain/MuseumBuilder.luau`; `PlotBuilder` builds the rooms, fixtures,
  and tiered pedestals. Schema v4 (`migrations[3]`) seeds the enhancement upgrade
  keys. 11 new tests — 77 assertions total.
- Endgame **Void Citadel** temple (`order` 4, difficulty 5, 8:00, unlock at 4
  extractions + 5000 gold) with a `void` theme, four Citadel-exclusive **Abyssal**
  relics (`VoidSigil`, `AbyssalCrown`, `StarlessIdol`, `EyeOfTheVoid`; all
  Legendary/Mythic, top value 40,000), a new `VoidWarden` enemy kind, and a faster
  `Rift Keeper` (ADR 0011).
- **Instant Revive** Developer Product: on death inside a hard temple
  (`Monetization.ReviveTempleIds`), the server offers a revive; purchasing within
  the window restores the player in place with their relics. Config, server
  offer/grant/`ProcessReceipt` path, `ExpeditionService` pending-revive flow, and a
  client modal with Revive/Decline actions (ADR 0011, FR-028).
- 6 new tests covering Void Citadel ordering/hardness/relic exclusivity, the Void
  Warden stat gap, guardian chase tuning, and revive-temple config — 83 assertions
  total; the contract-drift test now documents 12 actions.
- **Unified world layout** (no more floating platforms): `GameConfig.World` holds
  the shared layout constants (plot `RingRadius`/`StartAngleDegrees`/`MaxPlots`,
  `GroundTop`, `Hub.PlazaRadius`, `AvenueWidth`), now read by `PlotService` so the
  plot ring and the world builders share one source of truth. New
  `GroundBuilder.luau` lays one solid stone ground plane beneath the hub, every
  plot and every temple, and new `PathBuilder.luau` builds grand marble avenues
  with inlay runners, balustrades and lantern posts from the hub to every museum
  plot entrance and every temple portal. `WorldBuilder` composes ground → hub →
  temples → avenues. 4 new world-layout tests — 87 assertions total at that point.
- **Replayable expeditions**: relic pools are now scoped to temple occupancy —
  spawned when the first player enters (`RelicService:OnExpeditionStarted`) and
  destroyed when the last leaves (`OnExpeditionEnded`), so every expedition
  starts from a full pool and players who share a temple share one pool instead
  of seeing stacked duplicates. New pure `RunRules` module
  (`src/shared/Domain/RunRules.luau`) holds the spawn plan, the extraction-credit
  rule, and the haulability invariant. 5 new tests (every relic definition
  spawns somewhere; `requiredRelics` haulable at max backpack; credit rule;
  deterministic spawn plans; relic income under the museum rate cap) — 95
  assertions total.
- Pure `SceneryLayout` module (`src/shared/Domain/SceneryLayout.luau`) holds the
  shape of the world: the rounded-rectangle geometry, the protected regions
  (temple halls, hub plaza, museum plot ring, plot avenues, approach avenue,
  district cross-court), the forest bands and the layered escarpment, plus the
  polygon helpers used to prove the rim is gapless. It reads the configuration
  through `SceneryLayout.inputs`, so the world builder and the test suite always
  agree on the horizon. 12 map/scenery tests — 110 assertions total.

### Changed

- `ExpeditionService` and `RelicService` now resolve movement and capacity from
  `StatsUtil`/`Stats`, so upgrades and training stack in one place. The museum
  Settings panel lists the three training attributes with level/XP progress, plus
  carry capacity.
- The stamina pool resizes when a Stamina training level lands, keeping the
  current fill ratio; the resolved pool and drain are re-applied on the next tick.
- **World footprint and horizon redesigned.** The 3600 x 3600 square ground slab
  is replaced by a rounded rectangle (`GameConfig.World.Ground`: X -650..650,
  Z -640..1540, 300-stud corner radius) built from a central slab, four edge
  slabs and four corner discs, so the map edge reads as a carved plateau. The
  slab is sized to the playable content plus the forest belt plus the rocky
  rim, so the map has no wide empty margin. The world edge is now the fall
  line, exactly as before: nothing in the project installs a kill plane or a
  fall guard, so walking off the edge respawns the player at their plot.
- **Denser, closer horizon.** `SceneryBuilder` now builds a 299-tree forest
  whose dense belt is measured to the canopy edge and sits 30 to 60 studs
  beyond the museum, hub and temple walls, plus a layered rocky escarpment
  (119 cliff blocks and 60 crest blocks) that stands close behind the grove
  with no visible gap (777 decorative parts, ceiling 800). The wall varies in
  height and depth, and every second block carries a crest that steps back on
  top of it, so the horizon reads as rock rather than a ribbon. Every part is
  anchored, non-colliding, non-queryable, non-touchable and casts no shadow,
  so the scenery cannot affect gameplay, raycasts or lighting cost. The old
  treeline and ridge ring are gone.
- **Economy rebalance (M2)** so active expeditions clearly out-earn passive
  income and progression cannot be bought out while idle:
  - Extraction conversion `ExtractionValueToGold` `0.25 → 0.15` (a max Void
    Citadel haul now pays ~9000 gold, ~1100-3600 g/min of active play).
  - Every relic's `incomePerMinute` reduced ~5x (sum `2326 → 465/min`, ~511/min
    with the level-2 museum floor bonus; the Eye of the Void `700 → 140/min`).
  - Pending offline ceilings `MaxPendingIncome` `50000 → 5000` and
    `VipMaxPendingIncome` `200000 → 20000` (VIP keeps its 4x ratio; both now sit
    below the ~46.6k total progression sinks).
  - Temple gold gates: `SunkenSanctum` `1500 → 4000`, `VoidCitadel`
    `5000 → 10000` (each costs 1.2-6 runs of the previous tier's best haul;
    Catacombs stays at 500).
  - Upgrade costs unchanged; estimated full completion ~3-4h of active play.
  - 2 new tests (total progression costs exceed both offline ceilings; unlock
    prices sit in the fair-band window against previous-tier earnings, using a
    brute-force best-haul helper) — 97 assertions total.

### Fixed

- Leaving an expedition (extraction, abandon, or death) now restores the
  character's default walk speed. Previously the last weight-penalised or sprint
  speed could persist after the run ended until the next character respawn.
- `TrainingService` was written but never registered in the server bootstrap, so
  no training experience was awarded. It now starts with the other services and
  is called from `RelicService`/`ExtractionService`, and its view is included in
  the state snapshot.
- `WhisperingMask` was defined but never spawned (its `templeIds` listed the
  Tutorial Ruins, whose `relicSpawns` did not include it). It now spawns in the
  Tutorial Ruins at x 22, z 64, and a test asserts every relic definition
  appears in at least one temple.
- Void Citadel's `requiredRelics = 4` was unsatisfiable: the four lightest
  Citadel relics weighed 250 against a maximum capacity of 140. `requiredRelics`
  is now 3, the three lightest relics were trimmed (Void Sigil 42→38, Abyssal
  Crown 48→44, Starless Idol 72→70 = 152), and the backpack max level is 6
  (capacity 160), so a qualifying haul is always possible. Enforced by the
  `requiredRelics is haulable` test for every temple.
- Guardians never aggroed or chased. `GuardianService.hasLineOfSight` excluded
  player characters but not the guardian's own model, whose `HumanoidRootPart` is
  queryable; the eye-to-target ray could self-hit the guardian and fail the check
  every tick, so a chase was never started. The ray now excludes the guardian's
  model (mirroring `HazardService`, which already excluded the moving hazard).

### Changed

- Guardian AI is sharper across every temple (FR-027, ADR 0011): `Enemies` gains a
  longer `AggroLingerSeconds` (5s), a new `HuntSeconds` (4s) last-known-position
  hunt so a chase survives broken line of sight/stealth, a tighter contact cooldown
  (0.85s), a faster `Chase.SpeedMultiplier` (1.35), and a shorter tick (0.08s). The
  base `Guardian` kind has a wider aggro range and shorter windup. `GuardianService`
  now drives to the last-known position before resuming patrol.
- `NetworkService` and `PlayerDataService` delegate their security-critical
  predicates to the pure modules above, so the same rules are exercised by tests
  and production. `PlayerDataService`'s load path now routes every failure through
  `Persist.loadOutcome`.
- `docs/THREAT_MODEL.md` and the traceability matrix note the tested mitigations.
- The museum plot is now a multi-room building. `PlotService.RING_RADIUS` grows to 680 studs so 12 large footprints do not overlap; a `MuseumFloor`,
  `ExtraPedestal`, or enhancement purchase rebuilds the plot in place and
  re-fires `PlotAssigned` so `MuseumService` re-homes displays and tiers. The
  pedestal id scheme is unchanged (global 1-based, Foyer-first), and
  `GameConfig.Museum.MaxPedestals` now replaces the hardcoded cap.
- Plot models are rebuilt from scratch on every server start. `WorldBuilder.Build`
  already destroys the previous `RelicHeistWorld` folder, and `PlotService:Start`
  now also destroys any stray `MuseumPlots` folder left in `Workspace` (from an
  older build or a place copy) before creating its own, so the latest multi-wing
  geometry always replaces the old one with no stale or cached models.
- Museum geometry is scaled up to feel monumental: each wing fits a 120 x 120
  box (Foyer 120 x 120 x 56, Hall 100 x 70 x 52, Vault 88 x 60 x 52; the three
  stack to ~280 studs deep, roughly 4x the old footprint and >2x the ceiling
  height). Pedestals are spaced far apart in staggered alcoves, doorways are
  framed with lintels, and the ground apron (160 x 330) plus a raised owner sign
  were enlarged to match. Glass cases, velvet ropes, chandeliers, sconces, and
  pillars were scaled proportionally. The plot ring grew to radius 680 and starts
  at 105 degrees so plots clear the temple lane.
- Museum presentation overhaul: walls are layered white marble (base wainscot +
  crown molding) instead of brick; doorways are grand arches with flanking gate
  columns and an accent keystone; floors are polished white marble with a subtle
  border inlay and central runner; ceilings are coffered with warm recessed
  `SpotLight` downlights. The winged halls now read as a grand, high-ceiling
  white-marble gallery. Per-pedestal floating labels were replaced with a rounded
  card (rarity accent bar + bold title + status line) mounted well above the relic
  so names and states never overlap. Locked pedestals now wear a translucent glass
  dome with a metal collar. Pedestals sit in widely spaced staggered alcoves across
  each wing (`GameConfig.MuseumBuilding.Wings[*].pedestalSlots`) — the Foyer's six
  plinths sit in two rows of three — so label cards and their interaction prompts
  never crowd each other.
- The hub's expedition portals are now a grand marble colonnade along the hub's
  northern rim, on the same +Z axis as the temple avenue and flanking it
  symmetrically; each arch is styled to its temple's signature accent color, and
  the hub plaza, inlay and lantern pillars are white marble, matching the museum
  and avenues.
- The world is rescaled tighter for short, engaging walking distances while
  keeping the grand marble aesthetic: the museum plot ring shrinks 680 -> 380
  studs (still room for 12 non-overlapping plots), the temple corridor is pulled
  in from z = 600/1000/1400/1800 to 300/540/820/1130 with even spacing, avenues
  narrow 22 -> 16, the plot apron trims 160x330 -> 148x300, and the ground plane
  shrinks 5600 -> 3600. `PathBuilder` now runs a single central approach avenue
  from the hub to the temple district (instead of lateral lanes that clip halls)
  and stops each plot avenue at the plot apron edge so bridges meet the buildings
  with no unused gap.
- **Building scale pass** to match the tightened 380-stud plot ring, making
  interiors feel cosy and grand instead of empty:
  - Museum wings shrink to a 90×90 footprint: Grand Foyer 120×120×56 →
    **90×90×40**, Exhibition Hall 100×70×52 → **80×56×34**, Secure Vault
    88×60×52 → **76×52×34**; wing offsets pull in to z = 81 / −79 so the three
    rooms still stack with a slim 8-stud gap.
  - Doors, wall thickness and pedestals rescale with the rooms: door width/height
    now derive from room size and wall height (character-proportional),
    wall thickness 2.4 → **2**, pedestal base 5.6 → **4.8** with top at y ≈ 6.5 and
    the floating label lowered to y ≈ 11.2 (prompt/ProximityPrompt reach trimmed to
    match), so plinths stay cleanly spaced with clear interaction prompts.
  - Player base walk speed **16 → 19** (`GameConfig.Movement.BaseWalkSpeed`), so
    crossing foyer → hub plaza → temple portal feels fast and fluid.
  - The plot ground apron trims 148×300 → **120×260** and the owner sign/spawn move
    onto the smaller Foyer facade (sign z=45, spawn z=60).
  - `PathBuilder` plot avenues now stop 122 studs inside the ring so every marble
    bridge meets the plot apron flush — no overhang past the plot and no dead gap.
  - 1 new world-layout test asserts every wing fits the foyer footprint and the
    three rooms stack without overlapping — 88 assertions total at that point.
- **Human-scale architectural pass** — the museum was towering over the player,
  so wall/ceiling heights, wall thickness, pillars, arches, fixtures and lights
  all drop to character proportions:
  - Interior ceiling heights `40/34/34 → 16/14/14` (Foyer/Hall/Vault);
    outer walls, partitions and coffered ceilings follow the new heights.
  - Wall thickness `2 → 1.5`; wainscot `3 → 1.6` and crown `1.6 → 0.7`, ceiling
    slab `1 → 0.8`, beams `1.4×1.6 → 0.9×1.1`.
  - Doorways now human-scale (width `~7-9`, height `~7-9`) and the flanking gate
    columns/keystone shrink `2.4×3.2 → 1.4×1.8` / `4×3.2 → 2×1.6`.
  - Colonnade pillars `4×4 → 2×2` (caps `5.2 → 2.6`); chandeliers, sconces and
    recessed spotlights scale down (ranges/brightness trimmed) so the 14-stud
    rooms read warmly lit and cosy rather than cavernous.
  - Pedestal fixtures rescale to the smaller plinths: glass case `6.2×6.4 → 4.8×4.6`,
    velvet ropes `4.4 → 3.4`, locked dome `8 → 6`.
  - 1 new test asserts every wing ceiling is 14-16 studs — **89 assertions total**.
- 1 new world-layout test asserts the pulled-in temple corridor halls never
  overlap along +Z — **90 assertions total**.
- **Extraction credit is now server-authoritative**: `profile.stats.extractions`
  (the gate resource for `minExtractions` unlocks) is incremented only when the
  haul meets the temple's `requiredRelics` (`RunRules.extractionCredit`). Gold
  from the 25% stipend is still always paid. This closes the empty-hand farm at
  the spawn-adjacent extraction altar (walk in, walk out, bank a counted
  extraction). The expedition summary now carries a `credited` field and an
  "Objective incomplete" line, and the toast distinguishes a counted run from a
  payout-only run.

## [0.6.0] - 2026-10-20

### Added

- Data-driven tutorial (M5): an ordered step sequencer in
  `GameConfig.Tutorial.Steps`, pure rules in `src/shared/Domain/Tutorial.luau`,
  and a new `TutorialService` that records progress (`tutorialStep`) and pushes
  `TutorialStep` / `TutorialComplete` events. Teachable actions are reported by
  `ExpeditionService`, `RelicService`, `ExtractionService`, and `MuseumService`.
  The tutorial guides but never gates play. See `docs/ADR/0009-tutorial-and-ux.md`
  and SRS FR-015.
- Accessibility settings (M5): `reducedMotion`, `colorblindMode`, and `textScale`
  (`Normal`/`Large`/`Huge`) alongside the existing sound/visual-effects toggles.
  Server-validated in `SettingsService`, applied client-side through a single
  `Preferences` applier and a base/colorblind `Theme`. See SRS FR-022.
- Cross-platform polish (M5): a viewport-anchored `UIScale` for a responsive HUD,
  device-aware touch nav sizing, and gamepad face-button panel shortcuts with
  `ContextActionService` close bindings. See SRS FR-020/FR-021.
- Audio feedback scaffolding (M5): `GameConfig.Audio` cue set and a pooled
  `SoundController`. Asset ids default to `0`, so the game is silent but fully
  playable until sounds are authored. See SRS FR-023.
- Schema v3 with a `migrations[2]` step (settings + `tutorialStep`), preserving
  existing player values.
- M5 config-integrity and domain tests (43 assertions total): tutorial rules,
  schema v3 migration/normalize, settings coherence, and audio config.

### Changed

- `docs/VISION.md`, `docs/SRS.md`, `docs/HCI_DESIGN.md`, `docs/DATA_MODEL.md`,
  `docs/ASSETS.md`, and the traceability matrix updated for the tutorial,
  accessibility, cross-platform input, and audio scaffolding.

### Fixed

- Removed a dead `lastTextScale` local in `UIRoot` flagged by Selene.

## [0.5.0] - 2026-10-20

### Added

- Guardian enemies (M4): data-driven per temple in `GameConfig.Temples[*].guardians`,
  built by `TempleBuilder.buildGuardian` and run by `GuardianService`. Guardians
  patrol a waypoint route, chase a visible player in aggro range, and deal
  server-authoritative contact damage after a dodgeable windup, sharing
  `HazardService:DamagePlayer`. See `docs/ADR/0008-guardian-enemies.md` and SRS
  FR-007b.
- Catacombs get a Stone Guardian; the Sanctum gets a Drowned Warden and a faster
  Deep Sentinel.
- Config-integrity tests for guardian kinds, patrol routes, and default tuning
  (31 assertions total).

### Changed

- VISION's "no enemies" non-goal is superseded; enemies are now positional
  server-authoritative threats, not a combat system.
- Economy balance pass: the Tutorial boulder is softened (35 → 26 damage, longer
  tell) so the first temple teaches the dodge.
- Progression feedback: locked-temple rows now show `current/required`
  extractions with the remaining count.

## [0.4.0] - 2026-10-20

### Added

- Welcome Back modal: on join, offline museum earnings are held as
  `pendingOfflineGold` and offered as a free **Claim 1x** or a **Claim 2x** that
  doubles that one payout via a 199-Robux Developer Product.
- `MonetizationService`: server-authoritative `ProcessReceipt` handling, VIP Pass
  (`UserOwnsGamePassAsync`, cached on join), and the `ClaimOfflineIncome` /
  `PurchaseOfflineDouble` actions.
- VIP Pass extends the offline window to 24h and raises the pending ceiling to
  `200000` (`GameConfig.Economy.VipOfflineCapSeconds` / `VipMaxPendingIncome`).
- New remotes `WelcomeBack` / `WelcomeBackClosed`; new snapshot fields `vip`,
  `pendingOfflineGold`, and `offlineDouble`.
- `docs/MONETIZATION.md` (policy) and `docs/ADR/0007-monetization.md`; FR-019.

### Changed

- Offline income is no longer auto-granted on join; it is held for the modal.
  Supersedes the offline-grant portion of ADR 0006.
- Standard offline window changed from 8h to 4h; `Schema` bumped to v2 with a
  migration seeding `pendingOfflineGold` and `vip`.
- Monetization brought into scope; VISION/SRS moved it out of the non-goals.

## [0.3.0] - 2026-10-20

### Changed

- Museum income is now deposited automatically into the gold balance on a
  one-second server tick; the `ClaimIncome` action, top-bar claim button, and
  `C` shortcut were removed. Offline income still accrues from
  `lastIncomeClaimAt` and is granted on join. Supersedes ADR 0003 with
  `docs/ADR/0006-auto-tick-income.md`.
- The top-bar gold interpolates client-side between authoritative snapshots so
  it climbs smoothly in real time; downward corrections (purchases) snap, and all
  amounts remain server-decided.
- The snapshot no longer sends `pendingIncome`/`lastIncomeClaimAt`; it sends
  `gold` and `incomePerSecond`.

## [0.2.0] - 2026-10-20

### Added

- Third temple `SunkenSanctum` (difficulty 3, 2 extractions + 1500 gold to
  unlock) with a new `sanctum` visual theme in `TempleBuilder`.
- Four relics for the third temple: `TideAmulet`, `SerpentCrown`,
  `AbyssalPearl`, and the mythic `SunkenIdol`.
- New `blade` hazard kind: a rotating sweep trap built by `TempleBuilder` and
  run by `HazardService`, using a pure `Util.distanceToSegment2D` hit test.
- Config-integrity and geometry tests in `tests/run_tests.luau` (25 assertions
  total): relic spawns resolve, visual kinds are supported, trap kinds are
  handled, relic `templeIds` resolve, and the unlock chain is monotonic.

### Changed

- `docs/GAME_BALANCE.md`, `docs/SRS.md` (FR-007, FR-013), and
  `docs/traceability/requirements-matrix.md` updated for the new content.

## [0.1.0] - 2026-10-19

### Added

- Rojo project with `Remotes` (`Request`, `State`, `Event`) under
  `ReplicatedStorage`.
- Data-driven `GameConfig` (temples, relics, upgrades, economy, hazards, rates).
- Pure domain modules: `Economy`, `Encumbrance`, `Inventory`, `Progression`,
  `Schema`.
- Shared `Signal` and `Util`; `Types` placeholder.
- Server utilities: `Logger`, `Ids`, `PlayerUtil`; `RateLimiter` security.
- Procedural world: `BuilderUtil`, `RelicVisuals`, `HubBuilder`, `TempleBuilder`,
  `PlotBuilder`, `WorldBuilder`.
- Server services: `NetworkService`, `ViewService`, `AnalyticsService`,
  `PlayerDataService`, `EconomyService`, `UpgradeService`, `ProgressionService`,
  `SettingsService`, `PlotService`, `MuseumService`, `RelicService`,
  `ExpeditionService`, `HazardService`, `ExtractionService`, `AdminService`.
- Server bootstrap `init.server.luau` with init/start ordering and signal wiring.
- Client: `Net`, `State`, `Theme`, `Components`, `UIRoot`, `Panels`, `Input`
  and `Effects` controllers, and `init.client.luau`.
- Automated test suite `tests/run_tests.luau` (19 assertions).
- Tooling configs: `stylua.toml`, `selene.toml`, `aftman.toml`.
- Documentation set under `docs/` including `docs/VISION.md`, `docs/ADR/`
  (architecture decision records), and `docs/traceability/requirements-matrix.md`.
- CI: `.github/workflows/ci.yml` and a local `scripts/check.ps1` runner that build,
  format-check, lint, test, and type-check the project.

### Fixed

- Corrected Luau function-type syntax (`->`, not `=>`) in `Schema` and
  `RelicVisuals`, which had prevented the modules from loading.
- Fixed module resolution in the entry scripts: `init.server.luau` and
  `init.client.luau` become the `Server` Script / `Client` LocalScript, so their
  children are referenced as `script.Services.*` / `script.Net`, not
  `script.Parent.*`.
- Fixed `ExtractionService` reading the world from `ctx.Services.World`; the
  world is at `ctx.World` (services table has no `World` key).
- Fixed per-frame UI churn during expeditions: `UIRoot.tick` ran on every
  `Heartbeat` and `Components.bar.set` started a new `TweenService` tween every
  frame. The HUD now refreshes at 10 Hz and the bar only tweens when its ratio
  changes, eliminating the continuous tween allocation that could exhaust the
  client script budget.
- Resolved all Selene errors/warnings (logger branch, signal self-shadowing,
  unused locals, UDim helpers).

### Notes

- Verified via `rojo build`, `stylua --check`, `selene`, and the Luau test
  runner. Roblox Studio runtime and DataStore behaviour remain unverified.
