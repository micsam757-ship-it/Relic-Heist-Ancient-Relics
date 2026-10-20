# Project Status

Updated: 2026-10-20

## Summary

`Relic Heist: Ancient Relics` is a Roblox round-based "steal, carry, escape, exhibit"
game built with Rojo + Luau. This repository contains the full source, a pure-Logic
test suite, static-analysis configuration, and design documentation.

The build is a **single-player-viable vertical slice**: four playable temples
including the endgame Void Citadel, sixteen relics, ten upgrades, a 12-plot museum
ring, server-authoritative hazards (dart, boulder, blade, collapse) and aggressive
guardian enemies, a data-driven tutorial and accessibility settings, and a
responsive cross-platform client HUD. It boots and runs in a Roblox Studio play
session (see "Studio playtest results"); live DataStore, multiplayer behaviour,
and the M5 UX features (tutorial flow, accessibility, touch/gamepad) remain
partially verified.

## Milestone status

| Area | Status | Notes |
| --- | --- | --- |
| Project scaffolding (Rojo, Stylua, Selene) | Implemented + validated | `rojo build`, `stylua --check`, `selene` all pass |
| Shared domain logic (Economy, Encumbrance, Inventory, Progression, Schema, Tutorial, Util) | Implemented + tested | 90 assertions pass under the standalone Luau CLI |
| Content set (4 temples, 16 relics, 4 trap kinds, guardians) | Implemented + tested | Config-integrity tests validate spawns, visuals, trap kinds, guardians, tutorial steps, audio, and the unlock chain |
| Persistence (DataStore, schema v4 migrations, conflict guard) | Implemented, not run against live DataStore | Logic reviewed + migration tested; Studio/live run pending |
| Networking (single `Request` action channel + `State`/`Event` streams) | Implemented + validated (build) | Server + client wired |
| World generation (unified ground, hub, connecting avenues, temples, plots) | Implemented + validated (build) | `GroundBuilder` lays one solid ground plane flush with every structure; `PathBuilder` builds marble avenues from the hub to each plot and temple; `WorldBuilder` composes ground → hub → temples → avenues |
| Museum wings + building enhancements (ADR 0010) | Implemented + tested (domain/config) | Three cosy grand wings within a 90x90 footprint (Foyer 90x90x16, Hall 80x56x14, Vault 76x52x14), human-scale 1.5-stud walls and 2x2 pillars, slim 8-stud inter-wing gaps, gated by `MuseumFloor`; marble walls/crown molding, arched entries, tiled floors, coffered ceilings with spotlights; staggered pedestal alcoves; floating label cards; glass-dome locked indicator; 5 visual upgrades; per-rarity pedestal tiers; plots rebuilt fresh each session (stale `MuseumPlots` cleared); pure rules in `MuseumBuilder`; in-Studio geometry not yet playtested |
| Server services (17 domain services) | Implemented + validated (build) | Includes `MonetizationService`, `GuardianService`, `TutorialService`; see `docs/ARCHITECTURE.md` |
| Client UI (top bar, HUD, 5 panels, summaries, prompts, tutorial objective) | Implemented + validated (build) | Keyboard + touch + gamepad path wired |
| Tutorial (data-driven step sequencer) | Implemented + tested (domain/config) | Server-authoritative progression; never gates play; in-Studio flow not yet playtested |
| Accessibility settings (text size, reduced motion, colorblind palette) | Implemented + tested (schema/config) | Server-validated; applied via `Preferences`/`Theme`; not yet playtested in Studio |
| Cross-platform input (touch nav, gamepad shortcuts, responsive HUD) | Implemented + validated (build) | Manual-only device playtest pending |
| Audio/visual feedback scaffolding | Implemented | `SoundController` + `EffectsController`; silent until asset ids authored |
| Hazards (dart, boulder, blade, collapse) | Implemented | Damage math server-side; blade sweep math unit-tested; zones not yet playtested |
| Guardian enemies (patrol + chase) | Implemented | Config + behaviour server-side; aggressive tuning + last-known-position hunt added (FR-027); config-integrity tested; chase/contact behaviour not yet playtested |
| Endgame Void Citadel temple (ADR 0011) | Implemented + tested (config) | New final temple with `void` theme, 4 Abyssal relics, VoidWarden kind; builds/unlocks data-driven; geometry not yet playtested |
| Instant Revive product (ADR 0011) | Implemented, stub ID | Offer/grant/`ProcessReceipt` + client modal + contract tested; real Product ID and a live purchase test pending |
| Passive income | Implemented | 1s server auto-deposit + offline held for the Welcome Back modal; live tick and gold interpolation not yet playtested |
| Monetization (Welcome Back offer, VIP Pass, Instant Revive) | Implemented, stub IDs | Flow + policy documented (`docs/MONETIZATION.md`); real Product/Pass IDs and a live purchase test pending |
| Static analysis | Implemented + validated | `selene`: 0 errors / 0 warnings |
| Type check (pure modules) | Implemented + validated | `luau-analyze src/shared` clean |
| Automated logic tests | Implemented + validated | `luau tests/run_tests.luau` — 90 assertions |
| Exploit-resistance tests (input validation, rate limiting, save conflict guard) | Implemented + tested | Pure `Validate` / `RateLimiter` / `Persist` modules extracted from the hot path |
| Persistence failure-mode tests (load outcome, retry bounds) | Implemented + tested | Pure `Persist.loadOutcome`/`retryBackoff`; matrix in `docs/DATA_MODEL.md` |
| Network contract tests (action registry + data shapes) | Implemented + tested | Pure `Contracts` module; drift guard against `docs/API_CONTRACTS.md` |
| Micro-benchmark harness (NFR-010) | Implemented + baselined | `tests/bench.luau` reports us/call; budgets + baseline in `docs/PERFORMANCE.md` |
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
luau tests/run_tests.luau                         -> 90 passed, 0 failed
luau tests/bench.luau                             -> report (see docs/PERFORMANCE.md)
luau-analyze src/shared/Domain src/shared/Config  -> no output (clean)
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
- Sessions A-J in `docs/STUDIO_TEST_PLAN.md` reported as passing, with one
  exception: the Guardian did not chase or attack (see defect 4).

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
4. Guardians never aggroed or chased. `GuardianService.hasLineOfSight` excluded
   player characters but not the guardian's own model; the guardian's
   `HumanoidRootPart` is queryable, so the eye-to-target ray could self-hit the
   guardian and fail the line-of-sight check every tick, preventing a chase from
   ever starting. The ray now excludes the guardian's model, matching
   `HazardService`. **Fix is not yet re-verified in Studio** — replay Guardian
   session C to confirm.

## Not yet verified

These items are intentionally listed as unverified; do not assume they work. The
developer reported all `docs/STUDIO_TEST_PLAN.md` sessions as passing (except the
Guardian defect above), but these specific behaviours have not been independently
confirmed here and the Guardian fix in particular still needs a replay:

- Guardian aggro/chase/attack after defect 4 (replay session C), including the new
  aggressive tuning and the last-known-position hunt through broken line of sight
  (FR-027).
- The endgame Void Citadel: it builds, appears on a hub portal, unlocks at 4
  extractions + 5000 gold, and its `void` geometry renders (ADR 0011).
- The Instant Revive flow end-to-end: the offer after a death in Sunken Sanctum /
  Void Citadel, a real Developer Product purchase through `ProcessReceipt`, the
  in-place revive, and the decline/expiry path (ADR 0011, FR-028).
- DataStore load/save against a live or Studio API-services session.
- Hazard damage timing and line-of-sight under real movement.
- Museum exhibition, upgrades, and unlock flow as experienced in-session (logic
  is unit-tested; the in-Studio UX is not confirmed).
- Museum wing geometry, the in-place plot rebuild on a footprint/visual purchase,
  and per-rarity pedestal tier visuals (ADR 0010; pure rules unit-tested, geometry
  not yet observed in Studio).
- Museum presentation (marble walls/arches/tile floor/coffered ceiling +
  spotlights), the floating label cards, and the glass-dome locked indicator —
  not yet observed in Studio (label overlap and dome collisions in particular
  need a look in first/third person).
- The 1s auto-deposit tick, the offline-income grant on join, and the smooth
  gold interpolation in the top bar (not yet observed in Studio).
- Client rendering of generated relics and museum displays.
- Multiplayer concurrency (two or more players).
- Tutorial step sequencer behaviour in-session (advance order, objective HUD,
  completion celebration).
- Accessibility preferences in-session (text-size rebuild, reduced motion,
  colorblind palette, persistence across rejoin).
- Mobile/touch and gamepad navigation in a real client.
- Audio playback (no asset ids configured yet; the pool is silent by design).
- Responsive HUD scaling across phone/tablet/desktop viewports.

## Blockers

- A `rojo serve` process is running against this project. `aftman install` cannot
  replace `bin/rojo.exe` while it is locked (`os error 32`). Use direct tool paths
  (see `README.md`) or stop `rojo serve` before running `aftman install`.

## How to continue

1. Keep the checklist in `docs/TEST_STRATEGY.md` open while playing; run the
   step-by-step sessions in `docs/STUDIO_TEST_PLAN.md` (boot, core loop,
   guardians, museum/economy, persistence, tutorial, accessibility, input,
   multiplayer, monetization/audio). Tick each item and record anything
   unexpected in the Output window.
2. Confirm DataStore persistence by replaying a session with API services enabled
   and rejoining.
3. Run the full CI check set before committing: `pwsh scripts/check.ps1` (or the
   individual commands above).
4. Update this document with the observed results.
