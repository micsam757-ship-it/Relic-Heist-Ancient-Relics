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

## Baseline (2026-10-23, developer workstation)

| Benchmark | Work per call | us/call | calls/s |
| --- | --- | --- | --- |
| `Economy.incomeRatePerSecond` | one plot | 0.276 | 3,620,202 |
| `Economy.pendingIncome` | one player | 0.265 | 3,767,531 |
| `Encumbrance.totalWeight` | 40 relics | 3.580 | 279,351 |
| `Stats.walkSpeed` | 40-relic satchel | 0.394 | 2,539,954 |
| `Stats.resolve` | upgrades + training | 4.053 | 246,740 |
| `Encumbrance.checkCapacity` | — | 0.327 | 3,054,682 |
| `Economy.upgradeCost` | — | 0.511 | 1,957,701 |
| `Economy.extractionBonus` | — | 0.201 | 4,984,460 |
| `Inventory.countOwned` | 500 owned | 13.550 | 73,798 |
| `Inventory.isExhibited` | 96-pedestal worst case | 3.400 | 294,110 |
| `Util.distanceToSegment2D` | 20 guardians | 9.662 | 103,499 |
| `Contracts.check` | — | 0.649 | 1,540,749 |
| `RateLimiter:Allow` | — | 0.568 | 1,759,683 |

## Budget

Derived from NFR-010 and the loop cadences. The 1s income tick across N players
must stay well under the 1s budget; the 0.5s timer likewise.

| Loop | Cadence | Worst workload | Budget |
| --- | --- | --- | --- |
| Income tick | 1s | all plots of every player | < 50% of the 1s tick at 50 players |
| Expedition / guardian timer | 0.5s | all live guardians | < 50% of the 0.5s tick |
| Stamina tick | 0.1s | players with a runtime pool | < 50% of the 0.1s tick |
| Save tick | periodic | dirty profiles only | must not block the frame |
| Request admission | per request | validation + limiter | < 10 us |

At the baseline above, the income tick for 50 players with 4 active plots each is
about `50 x 4 x 0.276 us = 55 us` — well under the 1s budget. The stamina tick
resolves stats once per player every 0.1s (`Stats.resolve`, 4.05 us), so 50
players cost roughly `50 x 4.05 us = 203 us` per 100ms tick. `Inventory.countOwned`
over a full 500-relic archive is the most expensive measured call (13.55 us) and
only runs on archive mutations, not per tick.

## Guardrails

- These functions are pure and allocation-light by design; adding a nested scan
  over owned relics to a per-tick path would show up as a large jump here.
- This measurement is single-threaded CLI timing. Frame-time behavior in Roblox
  Studio (render, physics, replication) is separate and must be profiled there;
  see the Studio checklist in `docs/PROJECT_STATUS.md`.
