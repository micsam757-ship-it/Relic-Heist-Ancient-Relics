# Changelog

All notable changes are recorded here. This project follows a simple
major.minor.patch scheme while pre-1.0.

## [Unreleased] - M6 hardening (in progress)

### Added

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

### Changed

- `NetworkService` and `PlayerDataService` delegate their security-critical
  predicates to the pure modules above, so the same rules are exercised by tests
  and production. `PlayerDataService`'s load path now routes every failure through
  `Persist.loadOutcome`.
- `docs/THREAT_MODEL.md` and the traceability matrix note the tested mitigations.

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
