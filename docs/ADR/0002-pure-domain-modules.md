# ADR 0002: Pure, Roblox-free domain modules

- Status: Accepted
- Date: 2026-10-19

## Context

Core rules (pricing, encumbrance, capacity, income, migrations) are the easiest
place to introduce silent bugs, yet they are also the hardest to test inside
Roblox. Roblox runtime testing is slow and manual; the CI environment cannot run
a Studio session.

## Decision

Game rules live in `src/shared/Domain` (`Economy`, `Encumbrance`, `Inventory`,
`Progression`, `Schema`) and are written with no Roblox API usage, under
`--!strict`. They are exercised by `tests/run_tests.luau` under the standalone
Luau CLI, which runs in CI.

## Consequences

- Fast, deterministic tests that run anywhere Luau runs.
- Services become thin: validate input, call the domain, persist, notify.
- The domain must take plain data, never Instances or Players.
- New rules require a new domain function and a new test.

## Alternatives considered

- Test via Roblox Studio only: slow, manual, not CI-runnable.
- Put rules inside services: untestable without a live server.
