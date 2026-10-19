# Project Status

Updated: 2026-10-20

## Summary

`Relic Heist: Ancient Relics` is a Roblox round-based "steal, carry, escape, exhibit"
game built with Rojo + Luau. This repository contains the full source, a pure-Logic
test suite, static-analysis configuration, and design documentation.

The build is a **single-player-viable vertical slice**: three playable temples,
twelve relics, five upgrades, a 12-plot museum ring, server-authoritative hazards
(dart, boulder, blade, collapse), and a complete client HUD. It boots and runs in
a Roblox Studio play session (see "Studio playtest results"); live DataStore and
multiplayer behaviour remain partially verified.

## Milestone status

| Area | Status | Notes |
| --- | --- | --- |
| Project scaffolding (Rojo, Stylua, Selene) | Implemented + validated | `rojo build`, `stylua --check`, `selene` all pass |
| Shared domain logic (Economy, Encumbrance, Inventory, Progression, Schema, Util) | Implemented + tested | 25 assertions pass under the standalone Luau CLI |
| Content set (3 temples, 12 relics, 4 trap kinds) | Implemented + tested | Config-integrity tests validate spawns, visuals, trap kinds, and the unlock chain |
| Persistence (DataStore, migrations, conflict guard) | Implemented, not run against live DataStore | Logic reviewed; Studio/live run pending |
| Networking (single `Request` action channel + `State`/`Event` streams) | Implemented + validated (build) | Server + client wired |
| World generation (hub, temples, plots) | Implemented + validated (build) | Procedural blockout geometry |
| Server services (13 domain services) | Implemented + validated (build) | See `docs/ARCHITECTURE.md` |
| Client UI (top bar, HUD, 5 panels, summaries, prompts) | Implemented + validated (build) | Keyboard + pointer |
| Hazards (dart, boulder, blade, collapse) | Implemented | Damage math server-side; blade sweep math unit-tested; zones not yet playtested |
| Static analysis | Implemented + validated | `selene`: 0 errors / 0 warnings |
| Type check (pure modules) | Implemented + validated | `luau-analyze src/shared/Domain` clean |
| Automated logic tests | Implemented + validated | `luau tests/run_tests.luau` |
| Studio playtest | In progress | Server + client boot clean; collect -> extract path exercised and works (see below) |
| DataStore integration | Implemented, not run against live DataStore | Studio API-services run pending |
| Live multiplayer / economy telemetry | Planned | post-slice |

Legend: **Implemented** = source written; **validated** = a command was run and passed;
**tested** = covered by the automated suite.

## Validation performed in this environment

All commands were run from the repository root on Windows.

```
rojo build default.project.json -o <out>.rbxlx   -> Built project ... (success)
stylua --check .                                 -> no diff
selene src tests                                 -> 0 errors, 0 warnings, 0 parse errors
luau tests/run_tests.luau                         -> 25 passed, 0 failed
luau-analyze src/shared/Domain                    -> no output (clean)
```

The same set runs via `pwsh scripts/check.ps1` (used by CI); verified locally with
`RELIC_HEIST_TOOLS` pointing at the downloaded toolchain:

Note: `luau-analyze` on the full tree reports `Unknown global 'warn'` for
`src/shared/Utilities/Signal.luau` because the standalone analyzer does not ship
Roblox's `warn` global. This is an analyzer-environment artifact, not a code defect.

## Studio playtest results

Observed in a live Roblox Studio Play session (developer-reported):

- Server boot: clean, no errors after the bootstrap/module-path fixes.
- Client boot: clean, no errors after the module-path fix.
- Collect -> extract path: exercised end-to-end and works (extraction grants the
  stipend and resolves without error).

Defects found and fixed during playtest (see `CHANGELOG.md`):

1. Module resolution in the entry scripts (init-script layout).
2. `ExtractionService` reading the world from `ctx.Services.World` instead of
   `ctx.World`.
3. Client `Script timeout: exhausted allowed execution time` during temple runs,
   traced to the expedition HUD refreshing every `Heartbeat` and creating a
   `TweenService` tween every frame. The HUD now refreshes at 10 Hz and the weight
   bar only tweens on change. (If it recurs, capture the full multi-line stack —
   this error is also reported for Roblox `CorePackages`/Studio issues that are
   unrelated to game code.)

## Not yet verified

These items are intentionally listed as unverified; do not assume they work:

- DataStore load/save against a live or Studio API-services session.
- Hazard damage timing and line-of-sight under real movement.
- Museum exhibition, passive income, upgrades, and unlock flow as experienced
  in-session (logic is unit-tested; the in-Studio UX is not confirmed).
- Client rendering of generated relics and museum displays.
- Multiplayer concurrency (two or more players).

## Blockers

- A `rojo serve` process is running against this project. `aftman install` cannot
  replace `bin/rojo.exe` while it is locked (`os error 32`). Use direct tool paths
  (see `README.md`) or stop `rojo serve` before running `aftman install`.

## How to continue

1. Keep the checklist in `docs/TEST_STRATEGY.md` open while playing; tick each
   item and record anything unexpected in the Output window.
2. Confirm DataStore persistence by replaying a session with API services enabled
   and rejoining.
3. Run the full CI check set before committing: `pwsh scripts/check.ps1` (or the
   individual commands above).
4. Update this document with the observed results.
