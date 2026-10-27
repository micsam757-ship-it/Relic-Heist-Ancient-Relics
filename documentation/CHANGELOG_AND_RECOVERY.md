# Changelog & Recovery Guide

**Project:** Relic Heist: Ancient Relics · **Prepared:** 2026-10-21
**Purpose:** know exactly where the project stands, what recovery points exist
(only verified ones are listed), what is fragile, how to change things safely,
and how to record future work.

> Every backup claim in this document was verified by running `git tag`,
> `git log`, `git status`, and a filesystem scan on 2026-10-21. No backup is
> claimed that was not checked.

---

## 1. Current known project state

| Aspect | State (verified 2026-10-21) |
| --- | --- |
| Version | 0.1.0 — "code-complete vertical slice" |
| Branch | `main`, **1 commit ahead of `origin/main`** (the replayable-expeditions commit `9793459` has not been pushed to GitHub) |
| Commits | 6 total |
| Uncommitted work | **9 modified files** — the economy rebalance (extraction 25%→15%, offline ceilings 50k/200k→5k/20k, relic incomes ≈÷5, temple unlocks 1500/5000→4000/10000, 2 new tests, docs). Code-complete and locally verified, but **not committed**. |
| Untracked | `documentation/` (this handbook package) |
| Last full validation | 2026-10-21 — `scripts/check.ps1`: **All checks passed** (rojo build OK, stylua OK, selene 0/0, **97 tests passed / 0 failed**, bench OK, luau-analyze OK) |
| Last owner playtests | Core collect→extract loop, replayable relic respawn, and extraction credit confirmed in Studio (recorded in `docs/PROJECT_STATUS.md`) |
| Never tested | Live DataStore round-trip, multiplayer, monetisation purchases, guardians/hazards at runtime, offline-income modal, most UI panels |
| Confirmed defects | 16 known issues documented with file/line anchors in the handbook Section 11 (top 3: gamepad Museum button, panel X-close state, disabled Remove Display) |

**⚠ Highest-risk fact:** the most recent gameplay work exists only on this
machine — the `9793459` commit is unpushed and the 9 modified files are
uncommitted. A disk failure right now would lose the economy rebalance and its
tests. Committing and pushing is the single safest next action.

## 2. Verified recovery points

| # | Recovery point | What it restores | How to use it |
| --- | --- | --- | --- |
| R1 | Git repository history (6 commits on `main`) | Every committed state of the project | `git log --oneline` to browse; `git checkout <sha>` to inspect |
| R2 | Tag **`checkpoint-pre-m1`** → commit `d546a57` | The state **before** replayable expeditions / extraction credit (Void Citadel era, economy v1: 25% extraction, 50k/200k caps) | `git switch --detach checkpoint-pre-m1` |
| R3 | Tag **`checkpoint-pre-m2`** → commit `9793459` | The state **after** the M1 features, **before** the economy rebalance (includes all M1 work; also the rollback target for the current uncommitted 9 files) | `git switch --detach checkpoint-pre-m2` |
| R4 | GitHub remote `origin` = `https://github.com/micsam757-ship-it/Relic-Heist-Ancient-Relics.git` | Off-machine copy of everything **up to `d546a57`** — i.e. recovery point R2 only, *not* R3 | `git fetch origin` |
| R5 | `build/RelicHeist.rbxlx` (Rojo XML build, 342 KB, 2026-10-20 12:57) and `build/Relic Heist Ancient Relics.rbxlx` (Studio-saved binary, 133 KB, 2026-10-20 17:34) | Runnable *snapshots* of the place at those moments — **not source code**; gitignored; contents not inspected | Open directly in Roblox Studio |

**What does NOT exist (verified by scan):** no `.bak`/`.zip`/`.orig`/copy files
anywhere in the tree, no other tags, no other branches, no release artifacts,
no exported models or DataStore backups. The git tags above and the two place
files in `build/` are the only recovery points.

**Recommended next recovery improvements (not done):**
1. Commit the 9 modified files as the economy-rebalance commit.
2. `git push origin main --tags` so R3 exists off-machine too.
3. After the next successful Studio playtest, tag it (e.g. `checkpoint-playtest-<date>`).

## 3. Important dependencies and fragile systems

### External dependencies
| Dependency | Version / detail | If it breaks |
| --- | --- | --- |
| Aftman toolchain | rojo 7.7.1, stylua 2.6.0, selene 0.32.0, luau 0.743.0 (`aftman.toml`) | CI and local checks fail; reinstall with `aftman install --no-trust-check` |
| Roblox Studio | Any recent version; place opens only if the Rojo-mapped tree is intact | Game cannot be playtested; code/tests still run |
| Roblox DataStore | Name `RelicHeistProfiles`, scope `v1` | Saves fail; game falls back to ephemeral mode (documented failure matrix in `docs/DATA_MODEL.md`) |
| GitHub Actions | `.github/workflows/ci.yml` (same checks as `check.ps1`) | CI signal lost; local checks still authoritative |
| PowerShell | `scripts/check.ps1` targets Windows PowerShell 5.1+ (`powershell.exe`; plain `pwsh` is not installed on this machine) | Use the individual tool commands instead |

### Fragile systems (change with extra care)
| System | Why it is fragile | Rule of thumb |
| --- | --- | --- |
| **Profile schema (`Domain/Schema.luau`, v4)** | Saved data must stay readable forever; migrations are forward-only and tested | Never change the profile shape without: (1) a new migration, (2) `docs/DATA_MODEL.md` update, (3) migration tests |
| **`src/shared/Config/GameConfig.luau`** | Single source of truth for *all* balance/content; many tests assert invariants over it (haulability, unlock band, income cap) | Tune here, never hardcode balance in services; a failing test after an edit is telling you an invariant broke — read it |
| **`Net/Contracts.luau` + `docs/API_CONTRACTS.md`** | A drift test asserts the registry matches the document | Adding/renaming a request action requires updating both in the same commit |
| **Remote layout in `default.project.json`** | The client hard-waits (`WaitForChild`) for `ReplicatedStorage.Remotes.{Request,State,Event}` — if a place is built without them, the client hangs forever | Always build via `rojo build default.project.json`; never hand-assemble the place |
| **`PlayerDataService` save policy** | 3 s tick + 4 s debounce + conflict guard + bounded shutdown flush interact subtly | Do not "simplify" the save path; changes need the failure-mode matrix in `docs/DATA_MODEL.md` |
| **Client `Signal` + dual `Preferences.apply` handlers** | `Signal:Fire` uses `pairs()` (unordered); a known race can swallow settings changes (handbook UI-7) | Fix before adding more state handlers |
| **StyLua Windows line endings** | `stylua.toml` requires CRLF; hand-edited or LF files fail `stylua --check` | Run stylua on edited files before committing |
| **Accepted ADRs (`docs/ADR/0001…0011`)** | Project policy: never edit an accepted decision | Add a new ADR or an Amendments note |

## 4. Safe procedures for future changes

### Before any change
1. `git status` — if there are uncommitted changes, decide deliberately: commit
   them first (preferred) or at minimum know they are in the tree.
2. Note the current commit: `git rev-parse --short HEAD`.
3. For risky experiments, branch: `git switch -c experiment/<topic>`.

### During the change
- **Server authority rule:** the client only requests; the server re-derives
  everything from the profile. Never trust client-sent amounts/ids for rewards.
- **Pure logic rule:** anything without Roblox APIs belongs in
  `src/shared/Domain` and needs a test in `tests/run_tests.luau`.
- **Data-over-code rule:** balance goes in `GameConfig`, not into service code.
- One responsibility per service; `Init(ctx)` for wiring, `Start()` for
  connections/loops.

### After the change
1. Run the full gate and keep it green:
   `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check.ps1`
   (expect `All checks passed.` and `97 passed, 0 failed` — or more, if you
   added tests).
2. Update the docs your change touched (project convention):
   - balance numbers → `docs/GAME_BALANCE.md`
   - user-visible behaviour → `CHANGELOG.md`
   - new request action → `src/shared/Net/Contracts.luau` **and**
     `docs/API_CONTRACTS.md`
   - profile shape → `docs/DATA_MODEL.md` + a migration + tests
   - requirements → `docs/SRS.md` + `docs/traceability/requirements-matrix.md`
3. Playtest in Studio when the change touches runtime behaviour, and record the
   result in the log below (or in `docs/STUDIO_TEST_PLAN.md`).
4. Commit with a clear message; push when the work is confirmed
   (`git push origin main`). Tag milestones as recovery points.

### Studio-specific safety
- Use the Studio-only admin commands (`!rh_gold`, `!rh_relic`,
  `!rh_fillmuseum`, `!rh_unlock`, `!rh_reset`, `!rh_failsave`) for testing —
  they are disabled in published servers.
- To test saving, enable Studio API services; **never destructive-test with a
  real account's data you care about** — use `!rh_reset` or a throwaway account.
- Without API services the game runs ephemerally and warns in the Settings
  panel; that is the safe default for casual tests.

## 5. Change & test log template

Copy one block per change. Keep entries short; the git commit is the detail.

```
### <YYYY-MM-DD> — <one-line summary>
- Branch/commit before: <sha or "uncommitted tree">
- What changed: <files + what, 1-3 lines>
- Tests: <command run> → <result, e.g. 98 passed, 0 failed / All checks passed>
- Playtest: <not run | Studio session X: what was checked, pass/fail>
- Follow-ups / new issues: <none | list>
- Recovery point: <tag name or "none — pushed to origin as <sha>">
```

### Filled example (from the current state)

```
### 2026-10-21 — Economy rebalance (active > passive, fair unlock gates)
- Branch/commit before: 9793459 (checkpoint-pre-m2)
- What changed: GameConfig (extraction 0.25→0.15, pending caps 50k/200k→5k/20k,
  relic incomes ≈÷5, SunkenSanctum 1500→4000, VoidCitadel 5000→10000),
  +2 regression tests, 8 docs updated
- Tests: scripts/check.ps1 → All checks passed (97 passed, 0 failed)
- Playtest: not run — Studio verification pending (D6/D7/D11/D12 of the test plan)
- Follow-ups: commit + push pending; README status + RELEASE_PLAN still stale
- Recovery point: checkpoint-pre-m2 (rollback: git reset --hard checkpoint-pre-m2)
```

---

*This document describes recovery state as verified on 2026-10-21. Re-verify
with `git status`, `git log --oneline -10`, and `git tag -l` after any change.*
