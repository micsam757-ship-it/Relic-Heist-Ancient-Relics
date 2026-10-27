# Relic Heist: Ancient Relics — Documentation Package

**Start here:** the full project handbook is
[`Relic_Heist_Project_Handbook.docx`](./Relic_Heist_Project_Handbook.docx)
(open it in Microsoft Word; the table of contents updates with F9).
This folder is the beginner-facing documentation set for the game. It was created
by inspecting the actual repository on **2026-10-21**. Nothing in the game itself
was modified.

> Note: the repository root already has its own `README.md` (the developer
> quick-start). This file is a separate, newcomer-oriented introduction and does
> not replace it.

---

## What the game is

**Relic Heist: Ancient Relics** is a Roblox action/adventure/tycoon game: raid
ancient temples, carry heavy relics out before the place collapses, exhibit the
loot in your own museum for passive income, and reinvest into upgrades and
harder expeditions. It is written in Luau and built with Rojo — every script is
a plain file in this repository, not a Studio-only object.

## Main features (current slice, v0.1.0)

- **4 temples** — Tutorial Ruins → Forgotten Catacombs → Sunken Sanctum →
  Void Citadel, each with its own hazards, guardians, relics, and unlock gate.
- **16 relics** (Common → Mythic) with real weight: heavier loads slow you down.
- **Replayable expeditions** — relic pools respawn per temple occupancy, so every
  run starts from a full pool.
- **Server-authoritative extraction** — gold (15% of carried value) is always
  paid; the unlock "extraction" credit only counts if you extract with the
  required number of relics.
- **Personal museum** — 14 pedestals across 3 wings, per-player plots, passive
  income per exhibited relic, plus 5 visual-only upgrades.
- **10 upgrades**, offline income with a Welcome Back claim, a 4-step tutorial,
  accessibility settings (colorblind palette, text scale, reduced motion),
  cross-input UI (keyboard/gamepad/touch).
- **Security-first networking** — one request remote, validated actions, rate
  limiting, conflict-guarded DataStore saves (schema v4).
- Monetisation hooks (offline 2x double, VIP Pass, Instant Revive) — all
  product IDs are stubbed to 0, so nothing is purchasable yet (by design).

## Project structure

| Path | What lives there |
| --- | --- |
| `src/shared/` | Pure, testable code: `GameConfig` (all content/balance data), domain rules (economy, encumbrance, inventory, progression, run rules, schema, tutorial, museum layout), network contracts, utilities |
| `src/server/` | Server services (22), world builders (8), rate limiter, boot script |
| `src/client/` | UI layer (UIRoot, Panels, Components, Theme), input/sound/effects controllers, state store, networking wrapper |
| `tests/` | `run_tests.luau` (151 assertions, no Roblox needed) and `bench.luau` |
| `scripts/check.ps1` | One-command validation pipeline |
| `docs/` | 32 documents: vision, SRS, architecture, balance, threat model, test plans, 14 ADRs, and more |
| `build/` | Local place-file builds (gitignored — not source, not backups) |
| `documentation/` | **This handbook package** (Word handbook, README, recovery guide) |

## How to open and test the game

**Prerequisites:** Git, [Aftman](https://github.com/LPGhatguy/aftman) (then run
`aftman install --no-trust-check`), and Roblox Studio.

**Build and play (simplest):**

```
rojo build default.project.json -o "Relic Heist Ancient Relics.rbxlx"
```

Open the generated `.rbxlx` in Roblox Studio and press Play.

**Live code sync (development):** run `rojo serve` and connect from the Rojo
plugin inside Studio.

**Verify the whole project:**

```
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check.ps1
```

Expected: `All checks passed.` (rojo build, formatting, lint, 151 assertions,
benchmarks, type check). Last full run on this machine: **2026-10-25, all green.**

**Manual playtesting:** follow the session-by-session script in
`docs/STUDIO_TEST_PLAN.md` (Sessions A–M). Enable Studio API services for the
persistence and prestige sessions; without them the game runs in ephemeral
"no save" mode.

**Testing helpers (Studio only):** `!rh_help`, `!rh_state`, `!rh_gold <n>`,
`!rh_relic <id>`, `!rh_fillmuseum`, `!rh_unlock <templeId>`, `!rh_save`,
`!rh_reset`, `!rh_failsave [on|off]` in chat.

## Known issues (summary — full list in the handbook, Section 11)

Verified by code inspection on 2026-10-21; none of these have been fixed yet:

- **Gamepad B cannot open the Museum panel** (a close-binding sinks the input).
- **Panel X button leaves stale state** — reopening the same panel needs two
  presses.
- **"Remove Display" is permanently disabled** — the server never sends the
  occupancy field the UI reads.
- **The game is completely silent** — all audio asset IDs are 0 (deliberate
  stub; no sound assets exist yet).
- **All art is procedural blockout** — no meshes, textures, or animations.
- **Two server events (`ExpeditionStarted`, `HazardFired`) have no client
  handler** and are dropped.
- **DataStore saving has never been tested live** (needs a Studio session with
  API services enabled).
- Smaller UI/layout/document issues are listed in the handbook.

**Status labels used throughout the handbook:** VERIFIED WORKING (test evidence
or owner-confirmed playtest), PRESENT BUT UNTESTED (code exists, no runtime
evidence), PARTIALLY IMPLEMENTED, MISSING, KNOWN ISSUE. Only automated evidence
is labelled verified — nothing is claimed to work just because code exists.

## Where to go next

| Goal | Read |
| --- | --- |
| Complete picture of the game, systems, scripts, and bugs | `documentation/Relic_Heist_Project_Handbook.docx` |
| Backups, recovery points, safe change procedures | `documentation/CHANGELOG_AND_RECOVERY.md` |
| Honest build status and playtest history | `docs/PROJECT_STATUS.md` |
| How the code is shaped | `docs/ARCHITECTURE.md` |
| All balance numbers | `docs/GAME_BALANCE.md` |
| Developer quick-start and conventions | `/README.md` and `/CONTRIBUTING.md` at the repo root |
