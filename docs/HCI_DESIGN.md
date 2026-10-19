# HCI and Visual Design

## Goals

- Communicate the steal/carry/escape loop without a wall of text.
- Keep the moment-to-moment HUD minimal; put the vertical slice's depth in panels.
- Make risk legible: players should always know weight, remaining time, and carry.
- Remain usable by mouse, touch, and keyboard.

## Layout

- **Top bar**: gold, income rate, claim button, and five nav buttons
  (`Expeditions`, `Shop`, `Inventory`, `Museum`, `Settings`).
- **Expedition HUD** (left, only during an expedition): temple name, escape
  countdown (or `COLLAPSE`), weight bar with `weight / capacity` and speed
  percent, carried count, abandon button.
- **Toast stack** (top center): transient success/warning/error/info notices.
- **Modal host**: one panel open at a time.
- **Summary overlay**: post-expedition results (success, death, abandon).
- **Pedestal prompt**: relic picker or "remove display" for an activated pedestal.
- **Tutorial card**: one-time, dismissible.

## Visual language

- Warm sandstone/gold palette with cyan accents for "magic/tech".
- Rarity is always encoded twice: a colored badge glyph (`C/R/L/M`) plus text,
  so it is not color-only.
- Buttons disable to a dimmed state; destructive actions use the danger red.
- `Theme.luau` holds all colors, fonts, radii, spacing, and rarity colors.

## Input

- Keyboard: `E` Expeditions, `B` Shop, `I` Inventory, `M` Museum, `O` Settings,
  `C` claim, `Esc` close.
- Pointer/touch: all of the above are also on-screen buttons. No feature is
  keyboard-only.

## Feedback

- Collecting, extracting, purchasing, and dying all produce a toast; extraction
  and death also produce a summary overlay.
- Damage flashes the screen; hazard warnings toast with the trap name.
- The weight bar recolors as it fills (cyan -> warning -> danger).

## Copy tone

- Short, action-first sentences. Requirements are phrased as "Needs N
  extraction(s)" rather than as opaque locks.

## Open HCI work

- Playtest readability at typical 1080p and on mobile aspect ratios.
- Add audio cues (out of scope for this slice).
- Consider a radial or minimap aid for locating the altar (currently a labelled
  ProximityPrompt and portals carry the navigation load).
