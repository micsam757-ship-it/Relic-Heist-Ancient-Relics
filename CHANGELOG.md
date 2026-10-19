# Changelog

All notable changes are recorded here. This project follows a simple
major.minor.patch scheme while pre-1.0.

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
