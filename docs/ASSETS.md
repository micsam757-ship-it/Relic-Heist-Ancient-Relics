# Assets

## Current state

All geometry and props are **procedural blockout** built from anchored Roblox
`Part`/`WedgePart` instances in `src/server/World/`. There are no imported meshes,
textures, sounds, animations, or external assets in this repository.

| System | Builder | File |
| --- | --- | --- |
| Hub plaza, portals, kiosks | `HubBuilder` | `src/server/World/HubBuilder.luau` |
| Temples, traps, altars, guardians | `TempleBuilder` | `src/server/World/TempleBuilder.luau` |
| Museum plots, wings, pedestals | `PlotBuilder` | `src/server/World/PlotBuilder.luau` |
| Ground slab and inlaid grid | `GroundBuilder` | `src/server/World/GroundBuilder.luau` |
| Grove and rocky escarpment | `SceneryBuilder` | `src/server/World/SceneryBuilder.luau` |
| Relic models (8 kinds) | `RelicVisuals` | `src/server/World/RelicVisuals.luau` |
| Shared part helpers | `BuilderUtil` | `src/server/World/BuilderUtil.luau` |
| Guardian rig blockout | `TempleBuilder.buildGuardian` | `src/server/World/TempleBuilder.luau` |

The horizon scenery is procedural blockout as well: a dense belt of two-part
trees (a trunk and a canopy) that hugs the playable area, and a layered wall of
rock blocks that closes the world edge. Both are **decorative only** - anchored,
no collision, no raycast, no touch, no shadow - so they can never change
gameplay or the lighting cost. Their placement is decided by the pure
`SceneryLayout` module, which measures the belt to the canopy edge (30 to 60
studs beyond the playable content), keeps the grove clear of the temple
halls, the hub plaza and the museum plot ring, lets the forest border and
partly overhang the avenues, and keeps the rock wall gapless around the whole
footprint.

The world footprint is a rounded rectangle (a 1300 x 2180 stud slab with
300-stud quarter-circle corners) described by `GameConfig.World.Ground`. It is
sized to the playable content plus the forest belt plus the rocky rim, so the
map has no wide empty margin. The ground is built from a central slab, four
edge slabs and four corner discs, so the outline the scenery hugs and the
outline the ground has are the same shape.

Relic visual kinds: `scarab`, `ankh`, `idol`, `mask`, `urn`, `jackal`,
`crystal`, `core`.

Museum pedestal styling is data-driven per rarity (ADR 0010):
`PlotBuilder.applyPedestalTier` re-materials the shared pedestal geometry from
`GameConfig.MuseumBuilding.PedestalTiers` (column/top material, trim colour, and
a glow light at Legendary/Mythic), so no per-tier models are needed. Wing rooms,
pillars, sconces, glass cases, velvet ropes, and chandeliers are all procedural
blockout fixtures built from the same theme data.

The museum is finished blockout rather than a bare box: layered marble walls
(wainscot + crown molding), arched doorways with gate columns and a keystone,
polished marble floors with border inlay and runner, coffered ceilings with warm
recessed `SpotLight` units, and per-pedestal floating label cards plus a translucent
glass-dome locked indicator. All of it is still built from `Part`/GUI primitives
and is replaceable with authored models without touching logic.

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

Audio is **data-driven and currently silent**: `GameConfig.Audio.Sounds` defines
the cue set with `assetId = 0` ("not configured"). A pooled `SoundController`
plays a cue only when its asset id is non-zero and the player's sound setting is
on, so the game is fully playable before audio is authored and authoring a sound
is a config edit (`assetId`, `volume`), not a code change.

| Cue | When |
| --- | --- |
| `UiClick` / `UiOpen` / `UiClose` | Panel and button interaction |
| `RelicCollect` | A relic is collected |
| `Damage` | The player takes hazard/guardian damage |
| `ExtractionSuccess` / `ExtractionFail` | Expedition ends via altar / death-abandon |
| `Warning` | Hazard windup telegraph |
| `TutorialAdvance` / `TutorialComplete` | Tutorial step advances / finishes |

`GameConfig.Audio.MasterVolume` scales all cues.
