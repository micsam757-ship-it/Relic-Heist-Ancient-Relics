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
| FR-008 plot assignment | `PlotService`, `PlotBuilder` | Validated (build); Manual-only |
| FR-009 exhibit rules | `Inventory.exhibit/unexhibit`, `MuseumService` | Tested |
| FR-010 income rate | `Economy.incomeRatePerMinute`, `ViewService` | Tested |
| FR-011 pending income | `Economy.pendingIncome`, `EconomyService` | Tested |
| FR-012 upgrades | `Economy.upgradeCost`, `UpgradeService` | Tested |
| FR-013 unlock rules | `Progression.canUnlock`, `ProgressionService` | Tested |
| FR-014 client display | `UIRoot`, `Panels`, `ViewService` | Validated (build); Manual-only |
| FR-015 tutorial | `UIRoot.showTutorial`, `tutorialComplete` | Validated (build); Manual-only |
| FR-016 admin commands | `AdminService` | Validated (build); Manual-only |
| FR-017 versioned profiles | `Schema.migrate/normalize`, `PlayerDataService` | Tested |
| FR-018 safe saves | `PlayerDataService` conflict guard | Validated (build); Manual-only |

## Non-functional requirements

| Requirement | Implementation | Evidence |
| --- | --- | --- |
| NFR-001 server authority | `NetworkService`, all services | Selene clean; build |
| NFR-002 input validation | `NetworkService:handleRequest`, handlers | Selene clean |
| NFR-003 rate limiting | `RateLimiter`, `NetworkService` | Validated (build) |
| NFR-004 no blind writes | `PlayerDataService:attemptSave` | Validated (build); Manual-only |
| NFR-005 bounded shutdown | `BindToClose` in `PlayerDataService` | Validated (build) |
| NFR-006 Studio safety | `enterEphemeral`, `IsEphemeral` | Validated (build) |
| NFR-007 testability | `src/shared/Domain` | `luau tests/run_tests.luau` |
| NFR-008 readability | Stylua/Selene configs | `stylua --check`, `selene` |
| NFR-009 deterministic rules | pure domain modules | Tested |
| NFR-010 performance budget | on-demand income, 0.5s timer | Code review |
| NFR-011 accessibility | `Theme`, pointer + keyboard parity | Code review; Manual-only |
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

## How to reproduce validation

```
rojo build default.project.json -o out.rbxlx
stylua --check .
selene src tests
luau tests/run_tests.luau
luau-analyze src/shared/Domain
```

Or run them all: `pwsh scripts/check.ps1`.
