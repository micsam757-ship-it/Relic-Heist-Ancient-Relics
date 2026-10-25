# Release Plan

## Version 0.1.0 - vertical slice (current)

Goal: a single-server, Studio-playable slice that proves the loop.

Included:

- Two temples, eight relics, five upgrades, museum plots, extraction, hazards,
  persistence, and a complete client UI.
- Pure-logic test suite and static analysis.

Exit criteria:

- All automated checks pass (see `docs/PROJECT_STATUS.md`).
- Manual playtest checklist in `docs/TEST_STRATEGY.md` completed in Studio.

## Version 0.2.0 - content and balance (in progress)

- [done] Third temple `SunkenSanctum`, four new relics, and a new `blade`
  hazard - config-driven, plus config-integrity tests.
- [done] Passive training, sprint stamina, the unified effective-stat resolver,
  and temple-time XP.
- [done] Relic Companions MVP: three gold-purchased companions, one equipped
  slot, resolver-fed bonuses, schema v6, and a client panel.
- [done] Museum Prestige: optional repeatable reset, derived museum-income bonus,
  schema v7, forced-save rollback, and typed confirmation UI.
- Complete the Studio playtest checklist and record results (Session M covers
  prestige and its save/reset paths).
- Tune hazard timings and economy from playtest data.
- Add audio cues behind `settings.soundEnabled`.
- Fix any boot/runtime errors found in Studio.

## Version 0.3.0 - deeper progression

- Introduce soft progression (daily income multiplier or research).
- Difficulty pass on the catacombs and the sanctum.
- Author proper art to replace blockout geometry.

## Version 0.4.0 - live readiness

- DataStore integration test with API access enabled.
- Crash/disconnect hardening review against `docs/THREAT_MODEL.md`.
- Basic analytics export and a minimal leaderboard.

## Known risks for release

- No live DataStore run yet; persistence must be proven before any public test.
- Balance is untested; expect churn.
- Blockout art may not read well on small screens until reviewed.
