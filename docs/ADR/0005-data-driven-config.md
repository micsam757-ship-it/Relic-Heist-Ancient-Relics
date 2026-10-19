# ADR 0005: Content and balance live in GameConfig

- Status: Accepted
- Date: 2026-10-19

## Context

Temples, relics, upgrades, hazards, and economy constants are expected to change
often during balancing. Hardcoding them into services would make every tuning pass
a code change with a chance of regressions.

## Decision

All content and balance values live in `src/shared/Config/GameConfig.luau`, a
pure data module grouped by feature (`Temples`, `Relics`, `Upgrades`, `Economy`,
`Hazards`, `Save`, `Plot`, `Tutorial`). Services read from it and treat it as
read-only. `GameConfig` is itself Roblox-free so it is loadable by tests and the
standalone analyzer.

## Consequences

- Adding a temple or relic is a data edit; world builders and services already
  iterate the config tables.
- Balance changes are reviewable as data, and `docs/GAME_BALANCE.md` documents
  intent alongside it.
- Config shape changes are effectively a contract change; update `docs/DATA_MODEL.md`
  when the profile-facing subset changes.

## Alternatives considered

- Attributes/tags on instances as the source of truth: harder to test and diff.
- External JSON/CSV: workable, but Luau tables keep the toolchain single-language.
