# ADR 0010: Expanding museum wings and building enhancements

- Status: Accepted
- Date: 2026-10-20

## Context

The museum started as a single-room plot holding up to eight pedestals produced
by `PlotBuilder`. Playtesting feedback (and the blueprint's gallery fantasy) ask
for a museum that visibly grows: more rooms, richer fixtures, and plinths that
read as more valuable when they hold rarer relics. The challenge is to add this
depth without breaking three invariants that already depend on the flat layout:

1. `Economy.pedestalCount` unlocks pedestals by a single 1-based index, and
   `Profile.museum` is keyed by that pedestal id.
2. `MAX_PLOTS = 12` plots sit on a fixed ring; footprints must not overlap.
3. The upgrade pipeline (`UpgradeService`, Shop UI, schema storage, the
   `UpgradePurchased` signal) is the single way players buy permanent power.

## Decision

- **Wings are physical rooms, not cosmetic zones.** `GameConfig.MuseumBuilding
  .Wings` declares Foyer (unlock level 0), Exhibition Hall (level 1), and Vault
  (level 2). A wing carries a plot-local `offset`, interior `size`, `height`,
  a `theme`, and an ordered `pedestalSlots` list. `PlotBuilder` constructs each
  unlocked wing as a room (floor, ceiling, walls with framed doorways) and places
  its pedestals at the declared slots. The rooms are sized to feel monumental:
  each wing fits a 120 x 120 box (the Foyer is 120 x 120 x 56 studs, the Hall
  100 x 70 x 52, and the Vault 88 x 60 x 52) and the three stack to ~280 studs
  deep, so a player walks through spacious halls rather than a diorama.
  Doorways are framed with a lintel, and pedestals (5.6-stud bases, ~8-stud tops)
  are spaced well apart along corridors and alcoves.
- **Pedestal ids stay a stable global 1-based index.** `MuseumBuilder.placements`
  flattens wings Foyer-first, preserving wing and slot order, and assigns ids
  `"1".."N"`. Because Foyer holds pedestals 1–4, the hall 5–6, and the vault 7–8,
  the existing `index <= pedestalCount` unlock rule and all persisted museum keys
  keep working unchanged. `MAX_PEDESTALS` stays 8
  (`GameConfig.Museum.MaxPedestals`), now referenced instead of a magic number.
- **Wing unlock reuses the Museum Expansion upgrade.** The `MuseumFloor` level
  gates wings via each wing's `unlockLevel`; there is no new unlock currency.
- **Visual enhancements are ordinary upgrades.** `MarblePillars`, `Lighting`,
  `GlassCases`, `VelvetRopes`, and `Chandeliers` are `GameConfig.Upgrades`
  entries with `effect = "visual"`. `GameConfig.MuseumBuilding.Enhancements`
  maps a builder *feature* (`pillars`, `lighting`, …) to the upgrade id.
  `MuseumBuilder.featureLevels` resolves the clamped level per feature. Buying
  one follows the normal purchase path and the Shop lists it automatically.
- **Pedestal styling is per-rarity, data-driven.** `GameConfig.MuseumBuilding
  .PedestalTiers` maps a rarity to `{ tier, rank, columnMaterial, topMaterial,
  trim, glow, lightRange, lightBrightness }`. `MuseumBuilder.tierForRarity` maps
  a relic's rarity (or Common for empty/unknown) to a tier, and
  `PlotBuilder.applyPedestalTier` re-skins the existing pedestal parts. There are
  no model swaps; the same pedestal geometry is re-materialed and re-lit.
- **Presentation is finished, not blockout.** Walls are layered marble (base
  wainscot + crown molding), doorways are grand arches with flanking gate columns
  and a keystone, floors are polished marble with a border inlay and central
  runner, and ceilings are coffered beams lit by warm recessed spotlights. A
  floating label card (rarity accent bar + bold title + status line) sits well
  above each pedestal so names and states never overlap the relic or prompt.
  Locked pedestals wear a translucent glass dome with a metal collar as an
  unmistakable status read. Pedestals are placed in distinct alcoves (staggered
  across each room) rather than a crowded row.
- **The plot rebuilds in place on a footprint upgrade.** `PlotService` listens to
  `UpgradePurchased`; when the purchase is `MuseumFloor`, `ExtraPedestal`, or an
  enhancement, it destroys and rebuilds the plot with the new wings/features and
  re-fires `PlotAssigned`. `MuseumService:SetupPlot` drops stale display models,
  re-applies enhancements, re-hooks prompts, and refreshes tiers.
- **The ring is larger.** `PlotService.RING_RADIUS` grows to 680 studs so 12 large three-wing footprints (~120 x 280 studs) do not overlap. `MAX_PLOTS` stays 12.
- **The snapshot carries the layout.** `ViewService` adds `wings`,
  `enhancements`, and per-pedestal `wingId`/`wingName`/`tier` so the client
  Museum panel can group pedestals by wing and label their tier.

## Consequences

- The pure layout/tier/enhancement rules live in `MuseumBuilder` (no Roblox
  APIs), so wing ordering, tier fallback, and level clamping are unit tested and
  shared by the builder and the services.
- `Schema.CURRENT_VERSION` rises to 4 with a forward-only migration that seeds
  the five enhancement upgrade keys at 0 and preserves all existing data.
- A footprint purchase briefly destroys and rebuilds a plot's geometry. This is
  cheap (a few dozen parts, once per purchase) and leaves the player standing;
  `PlotService` re-anchors the respawn and the client state refreshes.
- Relic displays are destroyed and rebuilt across a footprint purchase. No relic
  data changes; only the visual models are reconstructed from `profile.museum`.

## Alternatives considered

- **Cosmetic zones with no geometry.** Rejected: the requirement is a visibly
  expanding building; separate rooms are the point.
- **Add plots / shrink footprints to fit.** Rejected: fewer plots caps concurrent
  players; a larger ring preserves all 12.
- **Model swaps per tier.** Rejected: re-materialing the shared pedestal keeps a
  single geometry code path and a small asset surface.
- **A separate "buildings" currency or service.** Rejected: reusing the upgrade
  pipeline means one purchase path, one schema field, one refresh signal, and no
  new exploit surface.

## Amendments (post-acceptance, same milestone)

The decision above stands; the *dimensions* were retuned twice while the world
was rescaled, so the current numbers differ from the originals:

- **Building scale pass:** wings shrink to a 90×90 footprint — Grand Foyer
  90×90×40, Exhibition Hall 80×56×34, Secure Vault 76×52×34 (stacking with a
  slim 8-stud gap) — and the plot ring shrinks 680 → **380** studs (start angle
  105). Plinth bases drop 5.6 → 4.8 studs with tops at y ≈ 6.5.
- **Human-scale pass:** interior ceilings settle at **16/14/14** studs
  (Foyer/Hall/Vault), walls at 1.5 studs, pillars at 2×2, with human-scale
  doorways and down-sized fixtures so the rooms read at character proportions.
- **Pedestal cap raised 8 → 14** (`GameConfig.Museum.MaxPedestals`, base 6 + 3
  per `MuseumFloor` level + 1 per `ExtraPedestal` level): Foyer holds ids 1–6,
  the Hall 7–10, the Vault 11–14. The stable global 1-based id scheme this ADR
  fixes is unchanged — only the counts per wing grew.
