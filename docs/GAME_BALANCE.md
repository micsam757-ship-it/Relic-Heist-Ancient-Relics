# Game Balance

All values are in `src/shared/Config/GameConfig.luau`. This document explains
intent; the config is the source of truth.

## Currencies and rates

- Start gold: 250.
- Museum income is expressed per minute, additive per exhibit, multiplied by the
  Museum Expansion bonus (`+5%` per level) and capped at `5000/min`.
- Pending income caps at the 8-hour offline window and at `50000`.
- Extraction converts carried relic value to gold at `25%`.

## Carrying

- Base capacity 40 weight; `+20` per Reinforced Backpack level.
- Weight reduces speed at `0.8%` per weight unit; Sprint Boots reduce the
  penalty by `4%` per level; speed floors at `35%`.
- Max 10 carried relics regardless of weight.
- Owned relics cap at 100 per profile; overflow on extraction is lost by design.

## Temples

| Temple | Unlock | Duration | Required relics | Hazard profile |
| --- | --- | --- | --- | --- |
| Tutorial Ruins | free | 5:00 | 1 | one dart trap, one boulder |
| Forgotten Catacombs | 1 extraction + 500 gold | 6:00 | 2 | two dart traps, one boulder, tighter paths |
| Sunken Sanctum | 2 extractions + 1500 gold | 7:00 | 3 | two whirling blades, one dart trap, one boulder |

Relic values span 90 (Clay Ankh) to 15000 (Sunken Idol), with income
90..300/min for the top end.

Blades are rotating sweep hazards. A blade spins at `speed` rad/s; a player
within `hitRadius` of the blade's swept line (checked on the horizontal plane
via `Util.distanceToSegment2D`) takes `damage`. The loop idles at 0.5 s when no
player is in the temple, so blades cost nothing on an empty server.

## Upgrades

| Upgrade | Max | Base price | Growth | Effect |
| --- | --- | --- | --- | --- |
| Sprint Boots | 5 | 200 | 1.75 | -4% weight penalty / level |
| Reinforced Backpack | 5 | 250 | 1.75 | +20 capacity / level |
| Reinforced Armor | 5 | 300 | 1.75 | +20 max health / level |
| Museum Expansion | 2 | 800 | 2.1 | +2 pedestals, +5% income / level |
| Extra Pedestal | 2 | 500 | 2.1 | +1 pedestal / level |

Total pedestals are capped at 8 (4 base + 4 from upgrades).

## Tuning levers

- Run length: temple `durationSeconds`.
- Risk: hazard `interval`, `warning`, `damage`, `radius`, `zone`, and blade
  `speed`, `length`, `hitRadius`.
- Reward: relic `value` and `incomePerMinute`, and
  `ExtractionValueToGold`.
- Pacing: `BasePedestals`, upgrade prices and growth.

## Balance status

Numbers are a first pass chosen for a readable solo slice. They have **not** been
tuned against playtest data; expect to revise after the first Studio session.
