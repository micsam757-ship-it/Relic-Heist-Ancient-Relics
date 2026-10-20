# Performance Budget and Benchmarks

NFR-010 bounds the server to coarse loops (1s income tick, 0.5s expedition /
guardian timer, save tick) with no per-frame work over all players. The cost of
those loops is the pure math in `src/shared/Domain` and the request admission
path. `tests/bench.luau` measures it so a regression (an accidental O(n^2) scan,
a stray allocation in a hot loop) shows up before it ships.

Run it with the Luau CLI:

```
luau tests/bench.luau
```

The script never fails the build. It reports microseconds per call on the
machine it runs on; treat the numbers as a relative baseline, not absolutes.

## Method

- Warmup passes run first so the VM settles; each benchmark then runs until at
  least 0.25s of work has elapsed, and reports `us/call` and `calls/s`.
- Fixtures use the worst realistic load: a 40-relic satchel, a museum with all
  96 pedestals filled out of a 500-relic archive, and 20 guardians.

## Baseline (2026-10-20, developer workstation)

| Benchmark | Work per call | us/call | calls/s |
| --- | --- | --- | --- |
| `Economy.incomeRatePerSecond` | one plot | 0.41 | 2,420,000 |
| `Economy.pendingIncome` | one player | 0.14 | 7,040,000 |
| `Encumbrance.totalWeight` | 40 relics | 1.55 | 647,000 |
| `Encumbrance.walkSpeed` | — | 0.21 | 4,740,000 |
| `Encumbrance.checkCapacity` | — | 0.11 | 8,816,000 |
| `Economy.upgradeCost` | — | 0.19 | 5,327,000 |
| `Economy.extractionBonus` | — | 0.12 | 8,682,000 |
| `Inventory.countOwned` | 500 owned | 7.66 | 131,000 |
| `Inventory.isExhibited` | 96-pedestal worst case | 1.86 | 536,000 |
| `Util.distanceToSegment2D` | 20 guardians | 7.10 | 141,000 |
| `Contracts.check` | — | 0.35 | 2,835,000 |
| `RateLimiter:Allow` | — | 0.32 | 3,160,000 |

## Budget

Derived from NFR-010 and the loop cadences. The 1s income tick across N players
must stay well under the 1s budget; the 0.5s timer likewise.

| Loop | Cadence | Worst workload | Budget |
| --- | --- | --- | --- |
| Income tick | 1s | all plots of every player | < 50% of the 1s tick at 50 players |
| Expedition / guardian timer | 0.5s | all live guardians | < 50% of the 0.5s tick |
| Save tick | periodic | dirty profiles only | must not block the frame |
| Request admission | per request | validation + limiter | < 10 us |

At the baseline above, the income tick for 50 players with 4 active plots each is
about `50 x 4 x 0.41 us = 82 us` — four orders of magnitude under the 1s budget.
`Inventory.countOwned` over a full 500-relic archive is the most expensive
measured call (7.66 us) and only runs on archive mutations, not per tick.

## Guardrails

- These functions are pure and allocation-light by design; adding a nested scan
  over owned relics to a per-tick path would show up as a large jump here.
- This measurement is single-threaded CLI timing. Frame-time behavior in Roblox
  Studio (render, physics, replication) is separate and must be profiled there;
  see the Studio checklist in `docs/PROJECT_STATUS.md`.
