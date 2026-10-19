# ADR 0004: Rojo init-script directory layout

- Status: Accepted
- Date: 2026-10-19

## Context

Rojo maps a `src/server` directory into `ServerScriptService.Server`. The
directory contains a `init.server.luau` entry point. Rojo treats a directory with
an `init` script as the script itself: `Server` becomes a Script whose children
are the directory's other entries.

## Decision

- `src/server/init.server.luau` becomes `ServerScriptService.Server` (a Script);
  `Services`, `Utilities`, `World`, and `Security` are its children. The entry
  script references them as `script.Services.*`, `script.Utilities.*`,
  `script.World.*`.
- Modules that live one level deeper at `src/server/Services/*` reach shared
  server folders with `script.Parent.Parent.*` (their grandparent is the `Server`
  Script).
- The same layout applies on the client: `src/client/init.client.luau` becomes
  `StarterPlayerScripts.Client` (a LocalScript), and its modules use
  `script.Net`, `script.State`, `script.UI.*`, `script.Controllers.*`.

## Consequences

- The DataModel is tidy: one entry script per side, with nested folders.
- The `script.Parent` misunderstanding is a recurring source of "not a valid
  member of ServerScriptService" errors; this ADR is the reference for the
  correct relative paths.
- Renaming the entry script or moving it out of the directory changes all these
  paths; do not do so casually.

## Alternatives considered

- A non-init entry script (e.g. `Server.server.luau`) with the folder mapping to
  a plain folder: also valid, but was not the chosen layout.
