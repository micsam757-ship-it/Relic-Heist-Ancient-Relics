# Requirements Traceability Matrix

Maps requirements (`docs/SRS.md`, `docs/NFR.md`) to implementation, tests, and
evidence.

Status legend:

- **Implemented** - source exists.
- **Tested** - covered by the automated suite (`tests/run_tests.luau`).
- **Validated** - a command was run and passed in this environment.
- **Manual-only** - requires Roblox Studio; not automated here.

`Studio` in Evidence means the item was observed in a live Studio play session
(see `docs/PROJECT_STATUS.md`).

## Functional requirements

| Requirement | Implementation | Evidence |
| --- | --- | --- |
| FR-001 enter temple | `ExpeditionService:RequestEnter`, `HubBuilder` portals | Validated (build); Studio boot |
| FR-002 collect relic | `RelicService:TryCollect` | Validated (build); Studio (collect path) |
| FR-003 weight slows | `Encumbrance.multiplier/walkSpeed`, `ExpeditionService:RecalculateMovement` | Tested |
| FR-004 countdown/warnings | `ExpeditionService` timer loop | Validated (build); Manual-only |
| FR-005 extraction | `ExtractionService`, `TempleBuilder` altar | Studio (extraction confirmed) |
| FR-006 death/abandon loss | `ExpeditionService:onDeath`, `AbandonExpedition` | Validated (build); Manual-only |
| FR-007 server hazards | `HazardService` (dart, boulder, blade, collapse), `Util.distanceToSegment2D` | Tested (blade sweep math); Validated (build); Manual-only |
| FR-007b guardian enemies | `GuardianService`, `TempleBuilder.buildGuardian`, `GameConfig.Enemies` | Tested (config integrity); Validated (build); Manual-only (behaviour) |
| FR-008 plot assignment | `PlotService`, `PlotBuilder` | Validated (build); Manual-only |
| FR-009 exhibit rules | `Inventory.exhibit/unexhibit`, `MuseumService` | Tested |
| FR-010 income rate | `Economy.incomeRatePerSecond`, `ViewService` | Tested |
| FR-011 income deposit | `EconomyService` 1s auto-tick; offline held in `pendingOfflineGold` with VIP-aware cap | Tested (offline math, VIP caps); Manual-only (live tick) |
| FR-012 upgrades | `Economy.upgradeCost`, `UpgradeService` | Tested |
| FR-013 unlock rules | `Progression.canUnlock`, `ProgressionService` | Tested |
| FR-014 client display | `UIRoot`, `Panels`, `ViewService` | Validated (build); Manual-only |
| FR-015 tutorial | `Tutorial`, `TutorialService`, `UIRoot.renderTutorial`, `GameConfig.Tutorial.Steps` | Tested (domain + config); Validated (build); Manual-only |
| FR-016 admin commands | `AdminService` | Validated (build); Manual-only |
| FR-017 versioned profiles | `Schema.migrate/normalize`, `PlayerDataService` | Tested |
| FR-018 safe saves | `PlayerDataService` conflict guard | Validated (build); Manual-only |
| FR-019 Welcome Back / 2x | `MonetizationService` (ProcessReceipt, VIP cache), `UIRoot.showWelcomeBack`, `Economy.ClaimPending` | Validated (build); Tested (schema v2, VIP caps); Manual-only (purchase) |
| FR-020 responsive HUD | `UIRoot` viewport `UIScale`, device-aware nav sizing | Validated (build); Manual-only |
| FR-021 cross-platform input | `InputController` (keyboard/touch/gamepad), `ContextActionService` bindings | Validated (build); Manual-only |
| FR-022 accessibility settings | `SettingsService` validation, `Preferences`, `Theme.applyPreferences`, `Schema` v3 | Tested (schema + config); Validated (build); Manual-only |
| FR-023 audio/visual feedback | `SoundController`, `EffectsController`, `GameConfig.Audio` | Tested (config); Validated (build); Manual-only (playback) |

## Non-functional requirements

| Requirement | Implementation | Evidence |
| --- | --- | --- |
| NFR-001 server authority | `NetworkService`, all services | Selene clean; build |
| NFR-002 input validation | `Validate` (pure payload check), `NetworkService:handleRequest` | Tested (payload shape); Selene clean |
| NFR-003 rate limiting | `RateLimiter`, `NetworkService` | Tested (token bucket); Validated (build) |
| NFR-004 no blind writes | `Persist.canCommit`, `PlayerDataService:attemptSave` | Tested (conflict guard); Manual-only (live) |
| NFR-005 bounded shutdown | `BindToClose` in `PlayerDataService` | Validated (build) |
| NFR-006 Studio safety | `enterEphemeral`, `IsEphemeral` | Validated (build) |
| NFR-007 testability | `src/shared/Domain` | `luau tests/run_tests.luau` |
| NFR-008 readability | Stylua/Selene configs | `stylua --check`, `selene` |
| NFR-009 deterministic rules | pure domain modules | Tested |
| NFR-010 performance budget | on-demand income, 0.5s timer | Code review |
| NFR-011 accessibility | `Theme` (colorblind palette + text scale), `Preferences`, input parity across devices | Tested (settings/schema); Manual-only |
| NFR-012 configurability | `GameConfig` | Code review |

## Content integrity (M4)

Guards against config drift as content grows. Each row is a `tests/run_tests.luau`
assertion; this supports NFR-007 (testability) and NFR-012 (configurability).

| Check | Implementation | Evidence |
| --- | --- | --- |
| Relic spawns resolve to a defined relic | `GameConfig.Temples` x `GameConfig.Relics` | Tested |
| Relic visual kinds are renderer-supported | `GameConfig.Relics` x `RelicVisuals` kinds | Tested |
| Trap kinds are hazard-service-supported | `GameConfig.Temples[].traps` x `HazardService` | Tested |
| Relic `templeIds` resolve to a defined temple | `GameConfig.Relics` x `GameConfig.Temples` | Tested |
| Unlock chain is monotonic by `order` | `GameConfig.Temples[].minExtractions` | Tested |
| Blade sweep distance math | `Util.distanceToSegment2D` | Tested |

## Content integrity (M5)

| Check | Implementation | Evidence |
| --- | --- | --- |
| Tutorial steps are well-formed and uniquely id'd | `GameConfig.Tutorial.Steps` | Tested |
| Tutorial completion actions are known teachable actions | `GameConfig.Tutorial.Steps` x service call sites | Tested |
| Settings defaults sit inside the text-scale options | `GameConfig.Settings` | Tested |
| Every audio cue has a volume and non-negative asset id | `GameConfig.Audio.Sounds` | Tested |

## Exploit resistance (M6)

Each row is a `tests/run_tests.luau` assertion over a pure module extracted from
the server hot path; this supports NFR-002/NFR-003/NFR-004.

| Check | Implementation | Evidence |
| --- | --- | --- |
| Request payload must be a table with a non-empty string action | `Validate.isValidPayload` / `checkPayload` | Tested |
| Token bucket allows the burst then throttles, per key | `RateLimiter:Allow/Clear` | Tested |
| Rate-limit costs above the burst are always rejected | `RateLimiter:Allow` | Tested |
| Save conflict guard blocks newer foreign writes and allows our own | `Persist.canCommit` | Tested |
| Load outcome fails closed: corrupt/future/unavailable never overwrites | `Persist.loadOutcome` | Tested |
| Retry backoff is bounded and reuses the final value | `Persist.retryBackoff` | Tested |
| A failed load never silently creates and saves over existing data | `Persist.isWritable` + `PlayerDataService:loadProfile` | Tested (classification) |
| Action registry matches the documented action set | `Contracts.Actions` x `API_CONTRACTS.md` | Tested (drift guard) |
| Every handler tolerates nil/wrong-typed data per its declared shape | `Contracts.check` + handler call sites | Tested |
| NFR-010 has a measured baseline and budgets for the hot loops | `tests/bench.luau` + `docs/PERFORMANCE.md` | Measured (report) |

## How to reproduce validation

```
rojo build default.project.json -o out.rbxlx
stylua --check .
selene src tests
luau tests/run_tests.luau
luau-analyze src/shared/Domain
```

Or run them all: `pwsh scripts/check.ps1`.
