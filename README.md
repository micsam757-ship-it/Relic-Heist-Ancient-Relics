# Relic Heist: Ancient Relics

A round-based Roblox game about raiding ancient temples, carrying heavy relics
out before the place collapses, and exhibiting them in your own museum for passive
income. Built with [Rojo](https://rojo.space) and Luau.

## Quick start

```bash
# build a place file
rojo build default.project.json -o "Relic Heist Ancient Relics.rbxlx"

# live-sync into Roblox Studio (then connect the Rojo plugin)
rojo serve
```

Open the built place in Roblox Studio and play solo to run the loop.

## Verify the build

One command runs the whole suite:

```bash
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check.ps1
```

Or run the steps individually:

```bash
rojo build default.project.json -o out.rbxlx
stylua --check .
selene src tests
luau tests/run_tests.luau
luau-analyze src/shared/Domain src/shared/Config
```

CI (`.github/workflows/ci.yml`) runs the same checks on push and pull request.

Tool resolution: the script uses tools on `PATH`, then `%USERPROFILE%\.aftman\bin`.
Run `aftman install` once to provision them. The standalone tool binaries used
during development were run from
`%LOCALAPPDATA%\Temp\opencode\tools\{stylua,selene,luau}`. `aftman install` may
fail while `rojo serve` holds a lock on `bin/rojo.exe`; stop the server first or
invoke the downloaded binaries directly.

## Project layout

| Path | Contents |
| --- | --- |
| `src/shared/Config` | All balance and content data (`GameConfig`) |
| `src/shared/Domain` | Pure, testable game rules |
| `src/shared/Utilities` | `Signal`, `Util` |
| `src/server/Services` | Gameplay services (server-authoritative) |
| `src/server/World` | Procedural hub, temples, plots, relic models |
| `src/server/Security` | Rate limiting |
| `src/client` | Networking, state store, UI, controllers |
| `tests` | Standalone Luau tests for pure modules |
| `scripts` | Local/CI validation entry point |
| `docs` | Requirements, architecture, ADRs, and process docs |

## Documentation

Start with [`docs/PROJECT_STATUS.md`](docs/PROJECT_STATUS.md) for the honest state
of the build, then [`docs/VISION.md`](docs/VISION.md),
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md), and
[`docs/SRS.md`](docs/SRS.md). Design trade-offs are recorded in
[`docs/ADR/`](docs/ADR/README.md) and requirement coverage lives in
[`docs/traceability/requirements-matrix.md`](docs/traceability/requirements-matrix.md).

## Development admin commands

In Studio only, chat commands are available:

```
!rh_help
!rh_state
!rh_gold <amount>
!rh_relic <definitionId>
!rh_unlock <templeId>
!rh_save
!rh_reset
```

These never connect in a published server.

## Status

Version 0.1.0 is a code-complete vertical slice. Automated checks pass; the
Roblox Studio runtime and DataStore integration are not yet verified. See
`docs/PROJECT_STATUS.md` for details and the manual playtest checklist.
