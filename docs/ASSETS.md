# Assets

## Current state

All geometry and props are **procedural blockout** built from anchored Roblox
`Part`/`WedgePart` instances in `src/server/World/`. There are no imported meshes,
textures, sounds, animations, or external assets in this repository.

| System | Builder | File |
| --- | --- | --- |
| Hub plaza, portals, kiosks | `HubBuilder` | `src/server/World/HubBuilder.luau` |
| Temples, traps, altars | `TempleBuilder` | `src/server/World/TempleBuilder.luau` |
| Museum plots, pedestals | `PlotBuilder` | `src/server/World/PlotBuilder.luau` |
| Relic models (8 kinds) | `RelicVisuals` | `src/server/World/RelicVisuals.luau` |
| Shared part helpers | `BuilderUtil` | `src/server/World/BuilderUtil.luau` |

Relic visual kinds: `scarab`, `ankh`, `idol`, `mask`, `urn`, `jackal`,
`crystal`, `core`.

## Lighting

`WorldBuilder.Build()` sets a warm desert atmosphere (clock time, ambient,
outdoor ambient) and an `Atmosphere` instance. Temples are darker; the catacombs
intentionally lower visibility is achieved with lighting/material choices rather
than client fog hacks.

## Replacement plan

Blockout geometry is designed to be replaced without touching logic:

- Relic models are produced by `RelicVisuals.build(definition)`; swap the builder
  table for mesh-backed templates keyed by `definition.visual.kind`.
- Temples and the hub should migrate to authored models referenced from config
  (e.g. a `modelId`/asset id per temple) while keeping the runtime handles
  (`spawnCFrame`, `extraction`, `portals`, `traps`, `pedestals`) intact.
- UI uses no image assets; it is built from `Frame`/`TextLabel` primitives so it
  can be reskinned via `Theme.luau`.

## Audio

No audio is shipped. `Settings.soundEnabled` exists in the data model so audio
can be added without a schema change.
