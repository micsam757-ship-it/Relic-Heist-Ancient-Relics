# Contributing

## Layout

- `src/shared` - config, pure domain logic, utilities (no Roblox APIs in
  `Config`/`Domain`/`Utilities`).
- `src/server` - services, world builders, security, utilities.
- `src/client` - networking, state store, UI, controllers.
- `tests` - standalone Luau tests for pure modules.
- `docs` - design and process documentation.

## Ground rules

1. **Server authority.** The client requests; the server decides. Never trust a
   client-supplied amount, id list, or position for a reward.
2. **Pure logic lives in `src/shared/Domain`.** If a rule can be expressed without
   Roblox, it belongs there and needs a test.
3. **Data over code.** Tune numbers in `GameConfig`; do not hardcode balance in
   services.
4. **One responsibility per service.** Use `Init(ctx)` for wiring and `Start()`
   for connections/loops.
5. **Validation before use.** Validate payload shape, then ids, then ranges.

## Before committing

Run and keep green:

```
stylua .
stylua --check .
selene src tests
luau tests/run_tests.luau
luau-analyze src/shared/Domain
rojo build default.project.json -o out.rbxlx
```

## Style

- Luau, tabs, 120-column limit, double quotes (enforced by Stylua).
- `--!strict` for pure modules; `--!nonstrict` where Roblox instance typing makes
  strict mode impractical.
- Comments explain intent, not mechanics. Avoid comments that restate code.
- Keep `selene` at zero warnings; do not add blanket disables.

## Docs

When you add an action, update `docs/API_CONTRACTS.md`. When you change the
profile shape, update `docs/DATA_MODEL.md` and add a migration. When you change
requirements, update `docs/SRS.md` and `docs/traceability/requirements-matrix.md`.
Record user-visible
changes in `CHANGELOG.md`.
