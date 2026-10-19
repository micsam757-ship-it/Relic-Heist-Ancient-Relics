# Test Strategy

## Layers

1. **Unit tests (automated, runnable now).** Pure modules under
   `src/shared/Domain` and `src/shared/Config` have no Roblox dependencies and are
   covered by `tests/run_tests.luau` under the standalone Luau CLI.

   ```
   luau tests/run_tests.luau
   ```

   Current coverage: upgrade pricing, armor health, pedestal math, income rate
   and cap, pending income window/ceiling, extraction bonus, carry capacity and
   speed clamping, capacity checks, relic ownership/uniqueness, exhibit/unexhibit
   invariants, unlock rules, and schema create/migrate/normalize.

2. **Static analysis (automated, runnable now).**

   ```
   selene src tests          # lint (0 errors / 0 warnings required)
   stylua --check .          # formatting
   luau-analyze src/shared/Domain   # types for pure modules
   rojo build default.project.json -o out.rbxlx   # project graph
   ```

3. **Integration / playtest (manual, requires Studio).** Not yet executed from
   this environment. See the checklist below.

## Manual playtest checklist

- [ ] Build loads without server boot errors in Output.
- [ ] Player spawns on their museum plot and can walk to the hub.
- [ ] Every portal prompt enters its temple (and locked temple is refused).
- [ ] Relic prompts collect; weight bar and speed change; capacity is enforced.
- [ ] Dart and boulder traps telegraph, then damage on the server.
- [ ] Whirling blades spin, sweep, and damage only within their hit radius.
- [ ] Escape countdown warns at 60/30/10; collapse ticks damage.
- [ ] Extraction transfers relics, grants the stipend, and shows the summary.
- [ ] Death and abandon lose carried relics and show the summary.
- [ ] Exhibited relics appear on pedestals, rotate, and raise income.
- [ ] Claim income adds gold and resets the timer.
- [ ] Upgrades change speed/capacity/health/pedestals as described.
- [ ] `ForgottenCatacombs` unlocks after 1 extraction + 500 gold.
- [ ] `SunkenSanctum` unlocks after 2 extractions + 1500 gold and spawns its four relics.
- [ ] Rejoin restores gold, relics, exhibits, upgrades, and settings.
- [ ] Studio-only admin commands (`!rh_...`) work; unknown commands are ignored.

## Regression guardrails

- Any new pure rule must add a test in `tests/run_tests.luau`.
- Any new action must document its contract in `docs/API_CONTRACTS.md`.
- Keep `selene` at zero warnings; do not disable lints without a note.

## Not covered by automation

Roblox runtime behaviour (instances, remotes, DataStore, physics, GUI) cannot be
exercised by the standalone CLI. Those paths are validated only by manual play and
must be reported honestly in `docs/PROJECT_STATUS.md`.
