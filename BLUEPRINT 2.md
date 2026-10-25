# Relic Heist: Rise of the Relic Hunters
## Game Evolution Blueprint

**Document:** `BLUEPRINT 2.md`  
**Related document:** `Relic Heist blueprit.md` — the original engineering prompt (tracked, 51 KB). This document is the roadmap of record and supersedes it for planning purposes; both remain in the repository.  
**Project:** Relic Heist: Ancient Relics  
**Engine:** Roblox  
**Language:** Luau  
**Architecture:** Rojo-based development  
**Status:** Phase 2 complete; Phase 1 Relic Companions MVP checkpointed (`40426c5`); Phase 3 Museum Prestige implemented and awaiting Studio Session M  
**Last revised:** 2026-10-25 — prestige implementation, schema v7, tests and docs complete; manual/live verification pending  
**Primary goal:** Evolve the existing game without breaking working systems.

> This revision corrects the verified facts in Section 2, re-orders the roadmap in
> Section 8 to match the actual state of the repository, records the approved
> Phase 2 decisions in Section 3, adds the data-persistence safeguards in
> Section 6, and replaces the "reported" issue list in Section 9 with the
> verification results. Phase 2 and the Relic Companions MVP are implemented and
> committed. Phase 3 is implemented: ADR 0014 is accepted, schema v7 and the pure
> prestige rules are in place, the forced-save reset/rollback service and
> confirmation UI are wired, and 151 assertions pass. Studio Session M and live
> DataStore save-failure verification remain outstanding.

---

## 1. Vision

Transform Relic Heist: Ancient Relics into a polished adventure and progression game that combines:

- The satisfying long-term progression of incremental simulator games.
- High-risk temple raids with meaningful decisions.
- Collectible companions that help players prepare for expeditions.
- Hunter training and equipment upgrades.
- A museum economy that rewards successful treasure hunting.
- Visually memorable environments that make exploration exciting.

The game must feel like one connected experience, not a collection of unrelated features.

### Core design principle

**Every upgrade should make the next expedition more exciting, and every successful expedition should give players a reason to progress further.**

We will build on the existing game rather than replace it.

---

## 2. Existing Foundation

The systems below were verified against the repository on 2026-10-22. Entries marked **verified** were read from source or produced by a command in this repository. Anything not listed here as verified remains an assumption and must be inspected before it is relied on.

| System | Verified state | Evidence |
|---|---|---|
| Temple raids | Four temples: TutorialRuins, ForgottenCatacombs, SunkenSanctum, VoidCitadel | `GameConfig.Temples` |
| Relic collection | 16 relic definitions | `GameConfig.Relics` |
| Museum economy | Passive income from displayed relics | `Economy.incomeRatePerSecond` |
| Upgrades | Player and museum upgrades (10 shop ids) | `GameConfig.Upgrades` |
| Persistence | Player profiles with schema migrations, currently schema v7 | `Schema.CURRENT_VERSION = 7`, `Schema.migrations` |
| Networking | `Request`, `State`, and `Event` RemoteEvents | `src/client/Net.luau:8-10` |
| Tests | **151 assertions pass, 0 failures** | `luau tests/run_tests.luau`, 2026-10-25 |
| Toolchain | Rojo, Aftman, StyLua, Selene, Luau | Aftman toolchain, `scripts/check.ps1` |
| CI | GitHub Actions exists at `.github/workflows/ci.yml`. It runs rojo build, StyLua, Selene, the test suite and `luau-analyze` on the pure modules. It does **not** run `scripts/check.ps1`, so the benchmark step and the full local gate are not covered by CI | `.github/workflows/ci.yml` |

The previously reported "97 unit tests" figure was stale; the current suite asserts 151.

### Repository state

- Branch `main`, four commits ahead of `origin/main`; the reviewed checkpoint is `40426c5`. `origin` is `https://github.com/micsam757-ship-it/Relic-Heist-Ancient-Relics.git`.
- **Tags** `checkpoint-pre-m1` (`d546a57`) and `checkpoint-pre-m2` (`9793459`) exist. These are tags, not branches: `main` is the only local branch. There are no other tags and no stashes.
- **The working tree holds uncommitted, uncheckpointed Phase 3 work:** the
  prestige domain/service/UI, schema v7 and the associated tests/docs. The
  existing checkpoint and tags do **not** protect it. See Section 10.
- **Relic Companions are implemented (MVP).** Ownership, one equipped slot, three definitions, resolver-fed bonuses, schema v6 persistence, server actions, a client panel, and domain/config/schema tests are in the working tree. Manual purchase/equip playtesting is still pending.
- **Museum Prestige is implemented (Phase 3).** Pure eligibility/reset/reward rules, schema v7, `PrestigeService` with forced-save rollback, the Museum panel section, typed confirmation, and ten new tests are in the working tree. Studio Session M and live save-failure verification are still pending.
- **The map redesign is substantially complete and must not be treated as a fresh redesign.** The ground is a rounded rectangle (X -650..650, Z -640..1540, 300-stud corner radius) with a 299-tree grove and a layered rocky escarpment (777 decorative parts against a ceiling of 800), covered by 12 map/scenery tests and manually playtested. Remaining map work is verification of material, lighting and landmark gaps only (Section 8, Phase 5).
- **Phase 1 lighting is frozen.** `src/server/World/WorldBuilder.luau` holds the reviewed golden-hour lighting pass and must not be edited without re-approval and re-anchoring. Its anchor script lives **outside the repository**, in `%TEMP%` (`...\opencode\lighting_anchor.ps1`); it verifies the lighting-region hash `52350767...b2eac` and the whole-file hash `73f7ea4c...bbff`. Moving that script into `scripts/` is a separate, small task and is not part of any progression phase.
- The **M2 economy rebalance** in the working tree is the current balance baseline: `ExtractionValueToGold` 0.25 → 0.15, relic `incomePerMinute` values reduced ~5x (total 2326 → 465/min), offline ceilings 50000 → 5000 and 200000 → 20000, and the SunkenSanctum / VoidCitadel unlock prices raised to 4000 / 10000. Upgrade costs are unchanged. Phase 2 must build on this baseline, not on the pre-M2 numbers.

These are the foundation. Existing behavior must remain intact unless a specific change is reviewed and approved.

---

## 3. The Five Connected Progression Systems

### System A — Relic Companions

**Status: implemented (MVP) and unit-tested; in-Studio purchase/equip verification pending. See `docs/ADR/0013-companions.md`.**

Players discover and collect ancient companions that support their treasure hunts.

**Initial companion roster**

Start with three original companions:

1. **Sun Scarab** — improves gold earnings.
2. **Temple Hound** — improves exploration or expedition utility.
3. **Stone Guardian** — improves carrying capacity or stamina efficiency.

These are initial design concepts. Exact bonuses must be balanced against the existing economy and player statistics.

**Rarity tiers**

- Common
- Rare
- Epic
- Legendary
- Mythic

The MVP does not need every tier or a large collection immediately.

**MVP requirements**

- Three companion definitions.
- Server-controlled ownership and inventory.
- Equip and unequip functionality.
- A defined equipment limit.
- Server-validated bonuses, applied through the shared effective-stat resolver from System B. Companions must not introduce a second calculation of an existing stat.
- Saving and loading.
- Gold costs where appropriate.
- UI feedback for ownership and equipment.
- Unit and regression tests.

**Future possibilities**

- Companion leveling.
- Companion fusion.
- Additional companion families.
- Cosmetic skins and visual effects.
- Companion-specific expedition abilities.

**Out of scope for the MVP:** paid eggs, complicated fusion, trading, and a massive collection system.

**Implemented decisions:** `SunScarab` 1200 gold (`+10%` gold from museum income and
extraction), `TempleHound` 1800 gold (`+3/s` stamina recovery, `-5%` weight penalty),
and `StoneGuardian` 3000 gold (`+20` capacity, `+20` stamina). Exactly one companion
is equipped; the first purchase auto-equips. Ownership (boolean map) and the equipped
id persist in schema v6. Bonuses feed `Stats` through `Companions.bonuses` and
`StatsUtil`; the gold multiplier is clamped to `[1, 2]`. The server actions are
`BuyCompanion`, `EquipCompanion`, and `UnequipCompanion`; the client panel is reachable
from the top bar or `C`.

### System B — Hunter Training and Equipment

Translate the repetitive training loop of incremental games into an ancient hunter theme.

Players train to become more capable explorers, not gym bodybuilders.

**Potential training attributes**

- Strength: improves the ability to carry heavy relics.
- Stamina: supports sprinting and expedition endurance.
- Carrying capacity: increases the amount of loot a player can transport.

These attributes must first be compared with existing systems.

**Verified starting point (2026-10-22)**

- There is **no** stamina system, **no** sprinting mechanic and **no** equipment or equip system in the repository. The only sprint-named content is the `SprintBoots` upgrade, which reduces the weight penalty by 0.04 per level and does not create a sprint.
- Carrying capacity already exists: `Encumbrance.capacity` = 40 + 20 × Backpack level (Backpack max level 6), and `RelicService` enforces that capacity together with the `MaxCarriedRelics` count cap at collection time.
- Armor already exists: `Economy.armorMaxHealth`, the `Armor` upgrade and `UpgradeService.ApplyEffects`.
- Because companions (System A) also feed carrying capacity and stamina efficiency, this system owns the effective-stat surface. Companions must plug into it rather than create a parallel one.

**Phase 2 decisions (approved)**

1. **Build new server-authoritative stamina and sprinting mechanics.** They do not exist today and must not be described as reused or "where available". The server owns stamina state, drain and recovery; the client only requests intent and renders the HUD.
2. **Passive, automatic training progression for Phase 2.** No spendable training points, no new currency and no new `Request` action, so the existing network contract and its documented action table stay unchanged. Training advances from play: expeditions completed, relics extracted, and time spent in a temple.
3. **Training does not spend gold in Phase 2.** No new gold sink, and no change to upgrade prices, museum income or the extraction payout. A future paid-training design is out of scope until it is separately reviewed.
4. **Establish one shared effective-stat resolver.** A single server-side resolver computes effective values from existing upgrades, training levels and future companion bonuses. Every consumer — movement, encumbrance, capacity, armor and the client snapshot — reads that one resolver. No system may compute its own variant of an existing stat.
5. **Preserve existing upgrade costs, economy, persistence behavior and gameplay** unless a required change is explicitly documented and approved before it is made.
6. **Add appropriate tests** for stamina, sprinting, encumbrance, carrying capacity, armor, persistence and stat calculations, alongside the existing 110 assertions.

Training should create meaningful preparation decisions without making raids trivial.

### System C — Museum Prestige

Give experienced players a long-term objective after developing their museum.

Prestige should be optional and clearly explained.

**Potential rewards**

- Permanent progression bonuses.
- Exclusive museum decorations.
- Special titles or visual effects.
- Access to advanced expeditions.

**Reset rules**

Before implementation, define exactly what resets and what survives.

Potentially resettable progression includes ordinary gold, selected upgrades, or expedition unlocks. Permanent rewards, purchased entitlements, and protected profile data must be handled explicitly.

No reset behavior should be implemented until the current profile schema, persistence logic, and migration mechanism have been inspected. That inspection is complete (Section 6); the remaining prerequisites are a written schema migration plan, an explicit reset whitelist, and migration/regression tests.

**Prestige is excluded from Phase 2.** No prestige data, prestige flag, prestige reset path or prestige migration may be added while the training and companion systems are in flight.

Prestige must never accidentally erase unrelated data.

### System D — New Expedition Worlds

Expand the existing four temples only after the core progression loop works reliably.

Each new environment must introduce a distinct gameplay reason to visit it.

Potential environments:

- **Sunken Kingdom:** flooded chambers, collapsing bridges, and water-themed hazards.
- **Overgrown Sanctuary:** dense vegetation, concealed traps, and hidden treasure rooms.
- **Ashen Necropolis:** dangerous corridors, ancient guardians, and rare artifacts.
- **Void Archive:** advanced enemies, supernatural hazards, and high-value relics.

These are concepts, not approved map changes.

Each expedition should have:

- Clear entry requirements.
- Distinct environmental identity.
- New hazards or enemy behaviors.
- Meaningful risk and reward.
- Relics appropriate to its difficulty.
- A reliable extraction and failure flow.

New worlds must integrate with the existing raid, relic, museum, and progression systems.

### System E — Trials and Competitive Challenges

Introduce replayable challenges after the core systems have been tested.

Potential activities:

- Timed temple escapes.
- Relic extraction challenges.
- Boss encounters.
- Limited-carry-capacity challenges.
- Daily or rotating objectives.
- Leaderboards for clearly defined achievements.

Competitive features must use server-validated results and appropriate rate limiting.

Leaderboards must not allow clients to submit their own trusted scores or rewards.

---

## 4. Core Gameplay Loop

The intended progression loop is:

1. **Prepare:** equip companions, train, and choose equipment.
2. **Enter:** select an unlocked temple or expedition.
3. **Explore:** avoid hazards, defeat enemies, and discover relics.
4. **Make decisions:** balance relic value, carrying capacity, remaining time, and escape risk.
5. **Extract:** return safely with collected loot.
6. **Display:** place relics in the museum.
7. **Earn:** receive passive museum income.
8. **Invest:** improve training, equipment, companions, and museum capacity.
9. **Unlock:** gain access to more dangerous expeditions.
10. **Repeat:** pursue rarer relics and greater long-term progression.

Every system must reinforce this loop.

If a proposed feature does not improve preparation, exploration, extraction, collection, or progression, it should not be prioritized.

---

## 5. Map and Visual Quality Blueprint

### Problem statement

The map was reported as visually unattractive. That ground has been addressed: the footprint and horizon redesign is implemented, tested and manually playtested (Section 2). The remaining map work is verification of material, lighting and landmark gaps, not a fresh redesign (Section 8, Phase 5).

Any further map change must preserve the reviewed footprint, the frozen Phase 1 lighting block in `WorldBuilder.luau`, and the decorative part budget.

### Visual direction

The initial recommendation is **ancient cinematic adventure**: memorable ruins, dramatic temples, warm lighting, atmospheric environments, and a polished treasure-hunting identity.

The exact direction remains subject to review.

### Visual improvement priorities

**A. World composition**

- Create a strong visual focal point.
- Improve the silhouette of temples and major structures.
- Make the world feel intentionally arranged rather than randomly assembled.
- Use terrain, elevation, paths, and distant scenery to add depth.
- Improve transitions between the hub, museum, and expedition entrances.

**B. Temple environments**

- Introduce distinctive architectural landmarks.
- Improve stone materials, pillars, entrances, and treasure chambers.
- Use lighting to draw attention toward objectives.
- Add environmental details that reinforce each temple's identity.
- Keep traps, enemies, exits, and important routes easy to recognize.

**C. Museum and player plots**

- Improve exhibit presentation and room composition.
- Make rare relics visually special.
- Use consistent materials, lighting, and architectural details.
- Preserve the functionality and positioning of museum interactions.
- Make future museum upgrades visibly rewarding.

**D. Atmosphere**

- Review lighting, color grading, shadows, fog, and environmental effects.
- Establish a coherent palette.
- Avoid excessive effects that obscure gameplay or hurt performance.
- Use original or properly licensed assets.

**E. Performance**

- Prioritize efficient geometry and reusable assets.
- Avoid excessive particle effects and unnecessary part counts.
- Test performance on lower-end devices.
- Use Level of Detail or other appropriate optimizations where useful.

### Map implementation strategy

1. [done] Inspect the existing map-generation code and asset organization.
2. [done] Capture the current appearance and establish a visual baseline.
3. [done] Identify what is structurally wrong versus what needs material, lighting, or decoration improvements.
4. [done] Propose and review the footprint and horizon change (rounded-rectangle ground, grove belt, layered escarpment).
5. [done] Implement and validate it in small, testable batches. The Phase 1 lighting block was frozen and anchored after review.
6. [done] Test the revised area in Roblox Studio and compare visual quality, performance and gameplay readability.
7. [open] Verify the remaining material, lighting and landmark gaps in Roblox Studio.
8. [open] Record the results in the `docs/STUDIO_TEST_PLAN.md` Results log, which is still empty.

**Do not replace the entire map in one uncontrolled operation.** The map has already been replaced once, in reviewed and tested steps. A second wholesale replacement is out of scope: remaining work is incremental and must preserve the frozen lighting block and the part budget.

Map changes must preserve spawn points, collision behavior, raid boundaries, museum interactions, enemy navigation, extraction routes, and other existing gameplay dependencies unless changes to them are explicitly approved.

---

## 6. Technical Architecture and Integration

The existing project reportedly uses three RemoteEvents:

- `Request`
- `State`
- `Event`

Their actual implementation must be inspected before any changes are made.

### Networking requirements

- Keep the existing network contract where practical.
- Do not create a parallel networking system without a demonstrated need.
- Validate player requests on the server.
- Never trust client-submitted prices, ownership, inventory, bonuses, or rewards.
- Apply appropriate rate limits.
- Return clear, predictable responses for successful and failed requests.

### Persistence requirements

Inspect the actual profile data structure, schema version, save process, and migration system.

The schema version is 7 (`Schema.CURRENT_VERSION`), after the v5 training, v6 companion, and v7 prestige migrations.

Any future companion or prestige data must:

- Have a defined data structure.
- Use safe defaults for existing players.
- Be validated before saving.
- Load correctly when fields are missing.
- Avoid overwriting unrelated profile fields.
- Include appropriate migration tests if the schema changes.
- Handle failed saves and invalid data safely.

Do not choose a new schema version before inspecting the actual persistence code.

### Data-persistence safeguards

These apply to every system that adds fields to the saved profile.

- **Inspect schema normalization and migration behavior before changing saved data.** `Schema.normalize` rebuilds `profile.stats` from a fixed list of known keys, so a new stat key that is not added to that list is silently dropped when the profile is loaded. New fields must be added to the schema, the migration chain and `normalize` together, and must be covered by a migration test that loads an older profile and asserts the new field survives a save/load round trip.
- **Measure or estimate serialized profile size before adding bulk data.** The 100-relic cap already bounds the largest part of a profile; training data and future companion data must be added to that budget rather than assumed to be free. Record the estimate and the DataStore key limit it is measured against before the first field is added, and re-measure when companion data lands. The current estimate is recorded in `docs/DATA_MODEL.md` (under 25 KB worst case against a 4 MiB DataStore value limit).
- **Keep prestige out of Phase 2.** Any later prestige work requires a written schema migration plan, an explicit reset whitelist (what resets and what survives) and migration/regression tests, all reviewed before any reset code is written.

### Testing requirements

Tests must cover more than whether a UI appears.

For new systems, test:

- Ownership and inventory rules.
- Equip and unequip limits.
- Server-authoritative bonus calculations.
- Gold deductions and rewards.
- Save/load behavior.
- Missing or malformed profile fields.
- Invalid requests and rate limiting.
- Compatibility with existing upgrades and museum income.
- Existing raid, relic, extraction, and progression behavior.

The existing test suite must remain green, except for any previously documented failures that are explicitly identified and approved for resolution.

**Phase 2 test coverage (required)**

- Stamina: drain rate, recovery, exhaustion and the boundaries of each.
- Sprinting: server-authoritative state transitions, and that a client cannot sprint without stamina or sprint outside an expedition.
- Encumbrance: weight, speed penalty and the sprint/weight interaction.
- Carrying capacity: the capacity value, the capacity ceiling, and the collection-time rejection path.
- Armor: `armorMaxHealth` and the effect of armor changes on player health.
- Persistence: a training profile survives a save/load round trip, older profiles migrate, and no unknown field is dropped.
- Stat calculations: the effective-stat resolver returns the same value for the same inputs, is monotonic, respects every per-level cap, and yields identical results whether or not companions exist.

---

## 7. Monetization Principles

Monetization comes after the game has a satisfying, reliable progression loop.

Potential options:

- Cosmetic companion skins.
- Museum decorations and exhibit themes.
- Visual effects and titles.
- Optional convenience features.
- Clearly explained VIP benefits.
- Fair companion acquisition options.

### Rules

- Do not make the free game intentionally frustrating.
- Avoid unbalanced pay-to-win advantages.
- Do not sell progress that invalidates the game's challenge.
- Make purchase contents and benefits clear.
- Validate purchases and grants on the server.
- Do not assume another game's estimated earnings predict this game's earnings.

Success should be measured using real player behavior, retention, repeat sessions, feedback, and actual revenue—not speculative earnings estimates.

---

## 8. Implementation Roadmap

The order below reflects the verified state of the repository on 2026-10-22. It is deliberately not the original authoring order: the map work (originally Phase 5) is substantially complete, and the companion system (originally Phase 1) is untouched. Phase 2 was moved ahead of Phase 1 on purpose — training owns the effective-stat surface, and companions must plug into it instead of creating a second one.

### Phase 0 — Protect and verify the current work

**Status: complete, with one pending item (the checkpoint commit).**

- [x] Confirm the project root and folder structure.
- [x] Inspect Git status, branch, latest commit, remotes, tags and stashes.
- [x] Confirm the actual test commands and run them (110 assertions pass).
- [x] Locate the server, client, shared, persistence, networking, museum, relic, upgrade and temple modules.
- [x] Verify the reported architecture and test baseline (Section 2).
- [x] Inspect the map-generation code and the existing visual assets.
- [x] Record known defects without fixing them (Section 9).
- [ ] **Pending:** approve and create the reviewed checkpoint commit that captures the map/horizon redesign, the M2 economy rebalance, the updated documentation and this blueprint. A branch alone does not preserve uncommitted work.

**Deliverable:** the repository and map inspection report — Sections 2, 9 and 10 of this document, with confirmed facts separated from assumptions — plus the checkpoint proposal in Section 10.

After Phase 0, OpenCode may implement the approved blueprint in small, testable steps. The user has authorized rewriting, fixing, creating, moving, or deleting project files when genuinely necessary to achieve the plan, subject to the safeguards in Section 10. Do not make broad or unrelated changes just because permission exists.

### Phase 5 — Map: verify the remaining gaps only

**Status: substantially complete. This phase is verification, not redesign.**

The ground footprint, grove, escarpment and lighting work are implemented, reviewed, tested and manually playtested. Do not reopen the footprint and do not rebuild the horizon.

- [ ] Verify remaining material gaps: stone and slate variety, temple facade materials, exhibit presentation for rare relics.
- [ ] Verify remaining lighting gaps, and only where the frozen Phase 1 lighting block is not involved. Editing `WorldBuilder.luau` requires re-approval and re-anchoring of the lighting region.
- [ ] Verify landmark gaps: readable silhouettes for the temple portals, the hub plaza and the museum entrance approach.
- [ ] Confirm performance on lower-end devices (777 decorative parts, ceiling 800) and in Roblox Studio.
- [ ] Record the results in `docs/STUDIO_TEST_PLAN.md`, whose Results log is still empty.

**Acceptance criteria:** the remaining map gaps are listed with evidence and each one is either closed or explicitly accepted. No new footprint work.

### Phase 2 — Hunter Training and Equipment

**Status: implemented and unit-tested; in-Studio verification pending. The approved decisions are in Section 3, System B.**

- Build the shared effective-stat resolver and route the existing consumers through it.
- Add server-authoritative stamina and sprinting. These are new mechanics, not reuse.
- Add passive training progression driven by play, with no spendable points and no gold cost.
- Integrate with the existing armor, health, encumbrance and capacity systems without altering upgrade costs, the economy or persistence behavior.
- Add the validation and regression tests listed in Section 3 and Section 6.

**Acceptance criteria:** training provides meaningful progression without duplicate statistics, without invalidating existing upgrades, and without changing the economy.

### Phase 1 — Relic Companions MVP

**Status: MVP implemented and unit-tested; in-Studio purchase/equip verification pending (ADR 0013).**

- Implement three original companion definitions.
- Add ownership and inventory rules.
- Add equip and unequip.
- Calculate bonuses on the server, through the shared effective-stat resolver from Phase 2 — companions must not introduce a second stat calculation.
- Integrate with existing gold and progression systems.
- Save and load companion data.
- Add UI and automated tests.
- Verify compatibility with all existing gameplay systems.

**Acceptance criteria:** companions work, persist correctly, cannot be exploited through client requests, and do not break the existing game.

### Phase 3 — Museum Prestige

**Status: implemented and covered by pure tests (ADR 0014, Accepted). Studio Session M and live DataStore rollback verification remain outstanding.**

- Define reset and retention rules as an explicit whitelist of what survives.
- Design permanent rewards.
- Model economic balance.
- Plan migrations if needed: a written schema migration plan plus migration and regression tests come first.
- Implement reset safeguards and confirmation flows.
- Test repeated prestige, failed saves, and existing-player data.

**Acceptance criteria:** prestige is optional, understandable, repeatable under defined rules, and safe for player data.

### Phase 4 — New Worlds and Trials

**Status: not started.**

- Design the next expedition around a distinct gameplay mechanic.
- Establish enemy, hazard, reward, and relic requirements.
- Implement one environment at a time.
- Add trials and competitive objectives only when their prerequisites work.
- Test performance and progression balance.

**Acceptance criteria:** new content adds meaningful challenges rather than merely increasing health and rewards.

### Phase 6 — Monetization and polish

- Review actual playtest feedback.
- Fix high-impact usability issues.
- Add approved cosmetic or convenience purchases.
- Test purchase validation and entitlement persistence.
- Measure real player engagement before expanding monetization.

---

## 9. Known Issues — Verified 2026-10-22

Each issue was checked against the current source. They are separate fixes: do not bundle them into a progression feature, and do not touch one only because another is nearby.

| ID | Reported issue | Verification | Status |
|---|---|---|---|
| UI-1 | Gamepad Button B conflicts with museum opening and panel closing. | Confirmed. `src/client/UI/InputController.luau:26` maps Button B to the Museum panel, while `:47-53` binds the same button to `RH_ClosePanel`, which fires on release. One press opens the panel and then closes it again. | **Confirmed — fix separately** |
| UI-2 | Closing a panel through its X button may leave the UI state inconsistent. | Confirmed, root cause located. The modal close button in `src/client/UI/Components.luau` destroys the backdrop directly instead of calling `UIRoot.closePanel()`, so `UIRoot.activePanel` stays set. The next toggle of the same panel closes it instead of opening it, which is the reported "needs two presses" symptom. | **Confirmed — fix separately** |
| UI-3 | Pedestal UI expects `currentUid`, while the server reportedly sends `pedestalId`. | Stale, not reproducible. The client reads `pedestal.uid` (`src/client/UI/Panels.luau:325`) and the server sends `uid` (`src/server/Services/ViewService.luau:111-125`); both sides agree. The related note in `documentation/README.md` about "Remove Display" being permanently disabled is stale for the same reason. | **Stale — no code fix; correct the docs** |
| SRV-3 | Default Baseplate and procedural ground overlap at Y=0, causing z-fighting. | Moot after the map redesign. The Baseplate spans Y -20..0 over X/Z -256..256 and is now fully covered by the new ground (visible surface Y 0..0.4, solid base Y -4.05..-0.05) inside the rounded-rectangle footprint, so it is invisible and cannot z-fight. | **Moot — no fix needed** |
| SRV-4 | Museum plot spawn reportedly sits inside the Exhibition Hall footprint. | Confirmed, conditionally. The plot spawn always sits at plot-local (0, 0.4, 60) (`src/server/World/PlotBuilder.luau:668-677`) and the Exhibition Hall occupies plot-local Z 53..109, so a player with Museum Expansion level 1 or higher spawns inside the second wing. Players below that level spawn on open ground. | **Confirmed — fix separately** |

The fixes for UI-1, UI-2 and SRV-4 are small and independent. Each needs its own change, its own review and its own tests, and none of them may be bundled into a training, companion or prestige change.

---

## 10. Git, Change Control, and Recovery

### File-change permission

**The user explicitly authorizes OpenCode to create, edit, rewrite, fix, move, or delete files when necessary for this project.** Do not treat the project as permanently read-only.

This authority includes changing existing code when required for integration, repairing identified defects, updating tests and documentation, and removing files that are demonstrably obsolete or unused. First inspect the project and dependencies, preserve unrelated work, and validate changes. If a file's purpose is uncertain, do not delete it just to tidy the repository.

The user authorizes OpenCode to edit the project as needed to implement this blueprint, including rewriting or fixing existing files and deleting files confirmed to be unnecessary. This is permission to make necessary project changes—not permission to damage or casually discard working code.

Required safeguards:

- Inspect Git status, including tracked, untracked, staged, and modified files, before editing.
- Preserve all pre-existing user changes. Never discard unrelated work or overwrite untracked files without understanding their purpose.
- Confirm the current branch, latest commit, and available recovery points. If possible, create a safe branch or backup before significant changes; do not claim one exists unless verified.
- Inspect references, imports, Rojo mappings, tests, build configuration, and runtime dependencies before deleting or replacing a file.
- Delete a file only when its purpose and lack of required references/dependencies have been checked. If uncertain, leave it in place and report the uncertainty.
- Rewrite or refactor existing files when genuinely needed, but keep each change focused on the blueprint and explain why the file needed changing.
- Do not remove tests, CI checks, assets, project configuration, documentation, or recovery files merely to make checks pass.
- Keep changes small and logically grouped. Review the diff after each group.
- Run relevant safe tests and checks after changes. Report exact commands, actual results, and any checks not run.
- If a proposed change could cause substantial data loss, remove a core system, alter player-data compatibility, or cannot be safely recovered, stop and explain the risk before proceeding.
- Do not expose secrets, API keys, credentials, or private environment variables in reports.
- Do not claim a backup, commit, test, or recovery point exists unless it has been verified.

Do not launch Roblox Studio unnecessarily during code inspection. When Studio is needed for visual validation, use it only at the appropriate testing stage.

### Checkpoint commits

A branch does not preserve uncommitted work. The map and horizon redesign, the M2 economy rebalance, the documentation updates and this blueprint revision exist only in the working tree; the existing `checkpoint-pre-m1` and `checkpoint-pre-m2` tags point at older commits and do not protect them.

- Propose the exact file list and a diff summary, and get approval, before creating a checkpoint commit.
- Stage only the reviewed files. Never use `git add -A` or `git add .` blindly, and never stage build output or Studio lock files.
- Never use `git checkout --`, `git restore`, `git reset --hard`, `git clean` or any other destructive command against this working tree.
- Keep build artifacts out of the repository. The current `/build/` directory is untracked only because the Studio lock file inside it is not matched by the existing ignore rules; the ignore entry belongs in `.gitignore`.
- Do not push without explicit approval.
- Report the real result of the commit. Never claim a checkpoint, backup or recovery point exists unless it has been verified.

---

## 11. Definition of Done

A feature is not complete merely because it appears on screen.

A feature is complete when:

1. Its gameplay behavior works.
2. Its server logic validates relevant actions.
3. Its data persists and loads safely, where applicable.
4. Its error cases are handled.
5. Automated tests pass.
6. Existing systems still behave correctly.
7. Its UI is understandable.
8. Performance remains acceptable.
9. The changes have been reviewed.
10. The documented acceptance criteria have been met.

Map improvements must also be evaluated visually in Roblox Studio, not solely through automated tests.

---

## 12. Immediate Next Step

**Verify the completed Phase 3 work in Studio and against a live DataStore, then checkpoint it.**

Concretely:

1. The reviewed Phase 2 checkpoint is committed as `40426c5`; the Phase 3 implementation is currently uncommitted.
2. Run the Phase 2, companion, and prestige rows in `docs/STUDIO_TEST_PLAN.md` (especially Sessions L and M) and record the results.
3. Verify schema v7 persistence, the forced-save prestige transaction, and rollback behavior with API services enabled.
4. Run the full gate (`powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check.ps1`) and update `docs/PROJECT_STATUS.md` before checkpointing.

Phase 2 must not change upgrade costs, the economy, persistence behavior or existing gameplay without an explicit, documented, approved change. Do not perform unrelated cleanup or risky irreversible changes without first reporting the risk and obtaining clarification.

### Final rule

**Protect the working game. Understand the architecture. Improve one thing at a time. Test every change. Build toward a polished, distinctive treasure-hunting experience.**
