# Test Strategy

## Layers

1. **Unit tests (automated, runnable now).** Pure modules under
   `src/shared/Domain` and `src/shared/Config` have no Roblox dependencies and are
   covered by `tests/run_tests.luau` under the standalone Luau CLI.

   ```
   luau tests/run_tests.luau
   ```

   Current coverage: upgrade pricing, armor health, pedestal math, income rate
   and cap, offline income window/ceiling, extraction bonus, carry capacity and
   speed clamping, capacity checks, relic ownership/uniqueness, exhibit/unexhibit
   invariants, unlock rules, schema create/migrate/normalize (v1-v3), tutorial
   progression rules, and config integrity (relics, traps, guardians, tutorial
   steps, settings, audio).

2. **Static analysis (automated, runnable now).**

   ```
   selene src tests          # lint (0 errors / 0 warnings required)
   stylua --check .          # formatting
   luau-analyze src/shared/Domain   # types for pure modules
   rojo build default.project.json -o out.rbxlx   # project graph
   ```

3. **Micro-benchmarks (automated report).** `tests/bench.luau` measures the hot
   pure functions against worst-realistic loads and prints `us/call`. It is a
   report, not a gate: budgets and the recorded baseline live in
   `docs/PERFORMANCE.md`. `scripts/check.ps1` runs it after the unit tests.

   ```
   luau tests/bench.luau
   ```

4. **Integration / playtest (manual, requires Studio).** Not yet executed from
   this environment. See the checklist below, and the step-by-step sessions in
   `docs/STUDIO_TEST_PLAN.md` (with prerequisites for DataStore, monetization,
   and audio).

## Manual playtest checklist

- [ ] Build loads without server boot errors in Output.
- [ ] Player spawns on their museum plot and can walk to the hub.
- [ ] Every portal prompt enters its temple (and locked temple is refused).
- [ ] Relic prompts collect; weight bar and speed change; capacity is enforced.
- [ ] Dart and boulder traps telegraph, then damage on the server.
- [ ] Whirling blades spin, sweep, and damage only within their hit radius.
- [ ] Escape countdown warns at 60/30/10; collapse ticks damage.
- [ ] Extraction transfers relics, grants the stipend, and shows the summary.
- [ ] Relic pools respawn when a temple empties; a re-entered run finds a full pool.
- [ ] Short or empty hauls pay the gold stipend but do not advance the next
      unlock's extraction gate (summary shows "Objective incomplete").
- [ ] Death and abandon lose carried relics and show the summary.
- [ ] Exhibited relics appear on pedestals, rotate, and raise income.
- [ ] Museum income auto-deposits: gold climbs on its own and the top bar eases smoothly.
- [ ] Upgrades change speed/capacity/health/pedestals as described.
- [ ] `ForgottenCatacombs` unlocks after 1 extraction + 500 gold.
- [ ] `SunkenSanctum` unlocks after 2 extractions + 1500 gold and spawns its four relics.
- [ ] Rejoin restores gold, relics, exhibits, upgrades, and settings.
- [ ] Studio-only admin commands (`!rh_...`) work; unknown commands are ignored.

## M4 playtest: guardians, balance, feedback

Run these in Studio after the M4 changes. Report each result honestly in
`docs/PROJECT_STATUS.md`; do not record a pass that was not observed.

### Guardians

- [ ] In `ForgottenCatacombs`, the "Stone Guardian" spawns on the floor (does not
      fall through or float) and patrols its four-waypoint loop without stopping.
- [ ] The guardian faces its movement direction while walking.
- [ ] Entering aggro range (~46 studs) with line of sight starts a chase; speed
      visibly increases (chase = `walkSpeed × 1.15`).
- [ ] Breaking line of sight (behind a pillar/obstacle) drops aggro after ~2.5 s
      and the guardian returns to patrol.
- [ ] On contact, a "<label> strikes!" warning appears, then damage lands after
      the windup; dodging out of range during the tell avoids the hit.
- [ ] Contact damage respects the shared invulnerability window (no chain-hits
      faster than ~1.1 s).
- [ ] In `SunkenSanctum`, both guardians spawn and patrol; "Deep Sentinel" moves
      noticeably faster than "Drowned Warden".
- [ ] Leaving the temple / extracting stops the guardians; re-entering resets the
      patrol. No guardian remains if the temple is empty.
- [ ] Output shows no `Guardian ... has no RootPart` warning (root assembled).

### Balance and feedback

- [ ] Tutorial boulder gives a longer tell (2.4 s) and lower damage (26) than
      before, so a new player can dodge it.
- [ ] Locked-temple rows in the Expeditions panel show `current/required`
      extractions and the remaining count.
- [ ] The economy still feels earned after the guardian/balance pass (gold rate,
      upgrade prices unchanged).

## M5 playtest: tutorial, accessibility, cross-platform

Run these in Studio after the M5 changes. Report each result honestly in
`docs/PROJECT_STATUS.md`; do not record a pass that was not observed.

### Tutorial

- [ ] A new profile shows the intro card and the first objective (`Enter the
      Tutorial Ruins portal.`) with `0 / 4` progress.
- [ ] Entering the ruins advances to step 2; collecting a relic advances to step
      3; extracting advances to step 4; exhibiting completes the tutorial.
- [ ] Out-of-order actions do not advance the step (e.g. collecting before
      entering).
- [ ] The completion of the final step plays the celebration and stops showing the
      objective HUD.
- [ ] Rejoining resumes at the recorded step (persistence).

### Accessibility settings

- [ ] Settings panel toggles sound, visual effects, reduced motion, and the
      colorblind palette; each persists across a rejoin.
- [ ] Text size cycles Normal -> Large -> Huge and visibly rescales the UI and
      open panels.
- [ ] Reduced motion stops HUD bob and the full-screen damage flash; visual
      effects off suppresses transient effects.
- [ ] The colorblind palette changes rarity/state colors while the badge glyph +
      text encoding still conveys rarity.
- [ ] An invalid setting value is rejected server-side (not stored).

### Cross-platform

- [ ] Keyboard `E/B/I/M/O` and `Esc` open/close panels.
- [ ] Touch: the top-bar nav is reachable and sized for touch; every panel opens.
- [ ] Gamepad: `ButtonY/X/B/A` open panels; native focus moves between buttons;
      `ButtonB`/`Esc` closes the active panel.
- [ ] The HUD stays legible and on-screen from a phone aspect ratio up to
      desktop, without clipping the top bar or the expedition HUD.

## Regression guardrails

- Any new pure rule must add a test in `tests/run_tests.luau`.
- Any new action must document its contract in `docs/API_CONTRACTS.md`.
- Keep `selene` at zero warnings; do not disable lints without a note.

## Not covered by automation

Roblox runtime behaviour (instances, remotes, DataStore, physics, GUI) cannot be
exercised by the standalone CLI. Those paths are validated only by manual play and
must be reported honestly in `docs/PROJECT_STATUS.md`.
