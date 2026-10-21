# Studio Test Plan

A step-by-step script for the manual play sessions that cover what the standalone
CLI cannot: Roblox instances, remotes, DataStore, physics, GUI, and multiplayer.
Every item here is currently **unverified** (see `docs/PROJECT_STATUS.md`); record
real observations only — do not tick an item that was not seen.

## How to run a session

1. Open the project and start a Play session (F5). Watch the Output window.
2. Work the sessions in order. Each row is one check.
3. For every row, mark **Pass / Fail / Blocked** and note the observed behaviour,
   plus any Output errors. A "Fail" with a good note is more useful than a guess.
4. When done, copy the results into `docs/PROJECT_STATUS.md` under
   "Studio playtest results" and clear the matching "Not yet verified" bullets.

Prerequisites for the DataStore and monetization sessions (see Blockers):

- **DataStore:** Studio → Game Settings → Security → enable *Enable Studio Access
  to API Services*, then restart the session.
- **Monetization:** real Developer Product ids in
  `GameConfig.Monetization.OfflineDoubleProductId` and
  `GameConfig.Monetization.InstantReviveProductId`, plus a Game Pass id in
  `GameConfig.Monetization.VipPassId` (all `0` today).
- **Audio:** real asset ids in `GameConfig.Audio.Sounds[*].assetId` (all `0`
  today; the pool is intentionally silent until then).

Admin commands are available in Studio via chat: `!rh_help`, `!rh_state`,
`!rh_gold <n>`, `!rh_relic <id>`, `!rh_save`, `!rh_unlock <temple>`, `!rh_reset`.

---

## Session A — Boot, world, and movement

| # | Check | Steps | Expected | Result |
| --- | --- | --- | --- | --- |
| A1 | Clean boot | Start Play; watch Output | No red errors after boot; `Server` and `Client` start | |
| A2 | Spawn on plot | Observe spawn | Player spawns on their museum plot ring | |
| A3 | Walk to hub | Walk inward | Hub at origin is reachable; no collision traps | |
| A4 | World integrity | Look around | 4 temples (incl. Void Citadel) and 14 relic pedestals/display slots render; one continuous ground plane; marble avenues reach every plot and temple entrance; hub intact | |
| A5 | HUD legible | Read top bar | Gold, capacity, and objectives are readable | |
| A6 | New footprint | Walk to the map edge from the hub in each direction | The ground is a rounded rectangle (1300 x 2180) with rounded corners; the world edge sits just behind the forest, with no wide empty margin, and every plot, avenue and temple still sits fully on the ground | |
| A7 | Forest belt | Look out from the hub, a plot and a temple | A dense belt of trees rings the playable content, its canopy edge 30-60 studs beyond the museum, hub and temple walls; the belt thins into scattered trees further out; no tree stands on a plot, an avenue, a temple or the hub, and the trees may lean over the edge of an avenue without blocking it | |
| A8 | Escarpment | Walk the rim in one direction all the way round | A continuous, layered rocky wall closes the horizon just behind the grove with no visible gap, including at the rounded corners; the blocks vary in height and depth, and the second course of rock steps back on top of the first | |
| A9 | Map edge | Walk off the edge | The player falls off the ground and respawns at their plot; nothing is caught on an invisible wall | |

---

## Session B — Core loop: portal, collect, trap, extract

| # | Check | Steps | Expected | Result |
| --- | --- | --- | --- | --- |
| B1 | Enter temple | Approach a portal prompt, press E/button | Entering the tutorial ruins works; locked temple is refused with a message | |
| B2 | Collect relic | Walk to a relic, collect | Prompt works; relic is carried; weight bar rises; walk speed drops | |
| B3 | Capacity | Fill the satchel | Collection is refused when overweight/over-count | |
| B4 | Dart trap | Cross a dart line | Trap telegraphs, then damages on the server | |
| B5 | Boulder trap | Stand in a boulder path | Longer tell (2.4s) and 26 damage — dodgeable | |
| B6 | Blades | Cross the sweep | Blades spin/sweep; damage only within the hit radius | |
| B7 | Escape warning | Trigger collapse countdown | Warnings at 60/30/10; collapse ticks damage | |
| B8 | Extract | Reach extraction with relics | Relics transfer, stipend granted, summary shows | |
| B9 | Death/abandon | Die or abandon mid-run | Carried relics lost; summary shows | |

---

## Session C — Guardians

| # | Check | Steps | Expected | Result |
| --- | --- | --- | --- | --- |
| C1 | Spawn/patrol | Enter `ForgottenCatacombs` | Stone Guardian spawns on the floor and patrols 4 waypoints without stopping | |
| C2 | Facing | Watch while walking | Guardian faces its movement direction | |
| C3 | Aggro | Enter ~54 studs with line of sight | Chase starts; speed visibly increases (~1.35x) | |
| C4 | De-aggro | Break line of sight behind a pillar | Aggro lingers ~5s; with line of sight broken the guardian hunts the last-known position ~4s before returning to patrol | |
| C5 | Contact | Let it reach you | "<label> strikes!" warning, then damage after windup; dodging during the tell avoids it | |
| C6 | Invuln window | Take repeated contact | No chain-hits faster than the 0.85s contact cooldown, and never faster than the 0.35s invulnerability window | |
| C7 | Two guardians | Enter `SunkenSanctum` | Both spawn and patrol; Deep Sentinel is visibly faster than Drowned Warden | |
| C8 | Clean up | Leave/extract, then re-enter | Guardians stop on leave; patrol resets on re-enter; none remain when empty | |
| C9 | No warning | Check Output | No "Guardian ... has no RootPart" warning | |

---

## Session D — Museum and economy

| # | Check | Steps | Expected | Result |
| --- | --- | --- | --- | --- |
| D1 | Exhibit | Place an owned relic on a pedestal | Relic appears on the pedestal and rotates | |
| D2 | Occupancy | Try an occupied/invalid pedestal | Refused cleanly | |
| D3 | Income | Exhibit and wait | Income rate rises; top bar eases smoothly (not jumpy) | |
| D4 | Auto-deposit | Watch gold without acting | Gold climbs on the 1s tick | |
| D5 | Upgrades | Buy speed/capacity/health/pedestal upgrades | Effects match descriptions immediately | |
| D6 | Unlock 1 | `!rh_state`; earn 1 extraction + 500 gold | `ForgottenCatacombs` unlocks | |
| D7 | Unlock 2 | Earn 2 extractions + 4000 gold | `SunkenSanctum` unlocks and spawns its four relics | |
| D8 | Locked panel | Open Expeditions | Locked rows show `current/required` extractions and remaining count | |
| D9 | Museum wings | Buy Museum Expansion to level 1, then level 2 | Exhibition Hall, then Secure Vault appear; the plot rebuilds in place and the player keeps standing on it | |
| D10 | Enhancements | Buy a visual upgrade (e.g. Marble Colonnade) | Plot rebuilds with the new fixtures; existing exhibits re-home onto their pedestals | |
| D11 | Void Citadel unlock | Earn 4 extractions + 10000 gold | `VoidCitadel` unlocks on its hub portal; the `void` hall and its guardians render | |
| D12 | Economy ratio | Collect every relic, exhibit all, wait 10 min; then run one best Void Citadel haul | Passive gain over the window is a small fraction of the single-run gold; extraction gold is ~15% of carried relic value | |

---

## Session E — Persistence and offline income

Requires API services enabled (see prerequisites).

| # | Check | Steps | Expected | Result |
| --- | --- | --- | --- | --- |
| E1 | Save | Earn gold/relics, then `!rh_save` | No save error in Output | |
| E2 | Rejoin | Leave and rejoin | Gold, relics, exhibits, upgrades, and settings restored | |
| E3 | Offline grant | Leave for a few minutes, rejoin | Welcome Back modal shows held offline gold | |
| E4 | Claim 1x | Choose the free claim | Gold granted once; pending cleared | |
| E5 | Claim 2x | Choose the double (with product id) | Purchase prompt; on success the double is granted | |
| E6 | VIP | With the Pass id set, join as a VIP | Longer offline window and higher ceiling apply | |
| E7 | Studio ephemeral | Disable API services and rejoin | Profile runs ephemerally; player is told progress will not save | |

---

## Session F — Tutorial (fresh profile)

Use `!rh_reset` to get a new profile.

| # | Check | Steps | Expected | Result |
| --- | --- | --- | --- | --- |
| F1 | Intro | Join fresh | Intro card and step 1 objective ("Enter the Tutorial Ruins portal."), `0 / 4` | |
| F2 | Advance | Enter → collect → extract → exhibit | Step advances 2→3→4; exhibiting completes | |
| F3 | Order guard | Collect before entering | Step does not advance out of order | |
| F4 | Completion | Finish final step | Celebration plays; objective HUD stops | |
| F5 | Resume | Rejoin after step 2 | Resumes at the recorded step | |

---

## Session G — Accessibility settings

| # | Check | Steps | Expected | Result |
| --- | --- | --- | --- | --- |
| G1 | Toggles | Toggle sound, effects, reduced motion, colorblind | Each applies and persists across rejoin | |
| G2 | Text size | Cycle Normal → Large → Huge | UI and open panels visibly rescale | |
| G3 | Reduced motion | Enable it | HUD bob and full-screen damage flash stop | |
| G4 | Effects off | Disable visual effects | Transient effects are suppressed | |
| G5 | Palette | Enable colorblind palette | Rarity/state colors change, but glyph + text still encode rarity | |
| G6 | Invalid value | Send a bad setting via the client/exploit | Rejected server-side; not stored | |

---

## Session H — Input and cross-platform

Test each where you can: desktop, phone aspect ratio (emulator), and a gamepad.

| # | Check | Steps | Expected | Result |
| --- | --- | --- | --- | --- |
| H1 | Keyboard | Press `E/B/I/M/O`, then `Esc` | Panels open/close as mapped | |
| H2 | Touch | Tap top-bar nav on a phone viewport | Nav is reachable and touch-sized; every panel opens | |
| H3 | Gamepad | `ButtonY/X/B/A`, then `ButtonB`/`Esc` | Panels open; native focus moves; the active panel closes | |
| H4 | Responsive | Resize phone → desktop | HUD stays legible/on-screen; top bar and expedition HUD do not clip | |
| H5 | Rendering | During a run | Generated relics and museum displays render correctly | |

---

## Session I — Multiplayer concurrency

Start a local server with a second player (Studio → Test → Clients: 2).

| # | Check | Steps | Expected | Result |
| --- | --- | --- | --- | --- |
| I1 | Isolation | Both players act | Each sees only their own gold/relics/plot | |
| I2 | Shared world | Both enter the same temple | Traps/guardians behave per-player without cross-talk | |
| I3 | Income | Both exhibit relics | Each player's income ticks independently | |
| I4 | Rate limit | Spam an action | Excessive requests are dropped without erroring the server | |
| I5 | Save conflict | Simulate a second session | The older session stops writing (conflict guard) | |

---

## Session J — Monetization and audio

Requires real ids (see prerequisites).

| # | Check | Steps | Expected | Result |
| --- | --- | --- | --- | --- |
| J1 | Product prompt | Choose 2x offline | Roblox purchase prompt appears with 199 R$ | |
| J2 | Product grant | Complete purchase | Double is granted once; no double-grant on retry | |
| J3 | Pass | Join with the Pass owned | VIP entitlements granted | |
| J4 | Audio | With asset ids set, trigger cues | Click/open/close, collect, damage, extract, warning, tutorial cues play | |
| J5 | Silent default | With ids at 0 | No errors; the pool is silent by design | |
| J6 | Revive offer | Die in `SunkenSanctum`/`VoidCitadel` with the revive product id set | Revive modal appears; death is held while the 12s window runs | |
| J7 | Revive grant | Choose Revive Now and complete the purchase | Character revives in place at full health with carried relics intact; no grant on a repeated receipt | |
| J8 | Revive decline/expire | Choose "Let me perish", or let the window lapse | Death resolves normally; carried relics are lost | |

---

## Session K — Replayable expeditions and extraction credit

| # | Check | Steps | Expected | Result |
| --- | --- | --- | --- | --- |
| K1 | Full-pool replay | Enter the Tutorial Ruins; note 4 relics; extract (or die/abandon); re-enter | The second entry finds a full pool of 4 relics again (relics are not one-per-server-session) | |
| K2 | Whispering Mask spawn | In the Tutorial Ruins, check the right side of the hall near z ≈ 64 | The teal Rare "Whispering Mask" spawns there with a collect prompt and is missing only after you collect it | |
| K3 | Empty-hand no credit | Unlock `ForgottenCatacombs`; enter and extract with 0 relics | "Empty-Handed" summary; `!rh_state` shows the extractions stat unchanged | |
| K4 | Short-haul no credit | In `ForgottenCatacombs` (required 2), extract with 1 relic | Success summary with an "Objective incomplete" line and a warning toast; gold stipend still paid; extractions stat unchanged | |
| K5 | Qualifying haul | In `ForgottenCatacombs`, extract with 2+ relics | Counted-run toast ("Extracted N relic(s)!"); extractions stat +1; unlock progress advances | |
| K6 | Shared pool | Two players enter the same temple | One shared relic set (no stacked duplicates); when one extracts the other keeps the remaining pool; when the last player leaves everything despawns; re-entry respawns a full pool | |

---

## Results log

Copy completed rows here (or straight into `docs/PROJECT_STATUS.md`):

| Session | Pass | Fail | Blocked | Notes / defects found |
| --- | --- | --- | --- | --- |
| A | A6, A7, A8, A9 | | | New footprint, grove belt, escarpment rim and the walk-off-the-edge respawn were playtested in Studio by the owner; rows A1-A5 not yet recorded |
| B | | | | |
| C | | | | |
| D | | | | |
| E | | | | |
| F | | | | |
| G | | | | |
| H | | | | |
| I | | | | |
| J | | | | |
| K | | | | |
