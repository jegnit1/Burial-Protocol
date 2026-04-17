# CODEX_SCREEN_LAYOUT_SPEC

This document is a strict implementation spec for Codex.
Do not reinterpret the intent. Do not make alternative design choices unless this file explicitly allows them.
If any existing code conflicts with this spec, update the code to match this spec.

---

## Goal

Refactor the current screen, sizing, camera, and falling-block spawn behavior to match the following gameplay presentation:

1. The game must target **1920x1080** as the standard gameplay resolution.
2. The player character must appear **visibly large enough** on screen.
3. The full gameplay width must remain visible at all times. **Left and right edges must always be visible in one fixed view.**
4. Vertical space may scroll. The camera may move upward following the player. Assume the player can keep jumping upward forever.
5. Falling block spawn selection must be updated to fit the new vertical camera behavior.

---

## Non-negotiable fixed values

These values are locked unless this document explicitly says otherwise.

- `VIEWPORT_WIDTH = 1920`
- `VIEWPORT_HEIGHT = 1080`
- `UNIT_SIZE = 64`
- `CELL_SIZE = 64`
- `WALL_COLUMNS = 10`
- `CENTER_COLUMNS = 10`
- `WORLD_COLUMNS = 30`
- Horizontal world width must remain exactly `30U = 1920px`
- Camera horizontal center must remain fixed at the center of the world width
- The camera must not zoom out to fit the whole world height
- The camera must not pan horizontally during gameplay

Important interpretation:

- Because `1U = 64px` and gameplay width is `1920px`, exactly **30U** fit across the screen.
- Therefore `10U left wall + 10U center shaft + 10U right wall` must all be visible at once.

---

## Required high-level behavior

### Resolution and layout

Update the game so that the base gameplay resolution is **1920x1080**.

This requires updating both project configuration and constant definitions that currently assume a taller viewport.

### Horizontal presentation

The game must always show the full horizontal gameplay width.

Required result:

- The screen always shows the entire width from the far left gameplay edge to the far right gameplay edge.
- No horizontal camera following.
- No horizontal shake or drift unless already implemented as a temporary effect and it does not break full-width visibility.

### Vertical presentation

The camera may move vertically.

Required result:

- The camera follows the player only on the **Y axis**.
- The camera can continue moving upward indefinitely as gameplay rises.
- The design must support effectively unbounded vertical progression.
- The current implementation that treats the whole world as a one-screen-tall fixed-height area must be removed or refactored where necessary.

### Player on-screen size

The player must be made visually larger than the current 1U x 1U body.

Use this target:

- **Target player gameplay body size: 2U tall**
- Preferred implementation target: `PLAYER_SIZE = Vector2(128.0, 128.0)`

Rules:

- Keep `CELL_SIZE = 64` unchanged.
- Increase the player display/body scale by increasing player size, not by changing the entire world unit size.
- Update movement, collisions, attack preview shapes, mining rectangles, and supporting-block snapping logic as needed so the larger body behaves correctly.

This is intentional. The player should feel clearly larger on a 1920x1080 view while the full 30U width remains visible.

---

## Files expected to change

At minimum, inspect and update the following files if needed:

- `project.godot`
- `scripts/autoload/GameConstants.gd`
- `scenes/main/Main.gd`
- `scenes/main/Main.tscn`
- `scenes/player/Player.gd`
- `scenes/world/WorldGrid.gd`
- `scenes/blocks/FallingBlock.gd`
- Any HUD/layout files that assume the old 1920x1664 viewport

Do not limit changes only to these files if additional fixes are required.

---

## Detailed implementation rules

### 1. Update base resolution

Change the project and constant viewport assumptions from `1920x1664` to `1920x1080`.

Required result:

- Gameplay is authored for `1920x1080`.
- HUD/layout values that depended on the taller viewport are adjusted so they still render correctly.
- Remove old assumptions that the visible world height equals the entire designed world height.

### 2. Keep width fixed at 30U

Do not change the horizontal unit math.

Required result:

- `WORLD_COLUMNS` remains 30.
- Total visible gameplay width remains `30 * 64 = 1920`.
- The camera shows all 30 columns at once.

### 3. Replace current fit-to-whole-world camera behavior

The current camera logic computes a fit zoom using world rect and viewport size.
That behavior must be replaced.

Required camera behavior:

- `zoom = Vector2.ONE`
- Camera X position is fixed to the horizontal center of the gameplay world
- Camera Y position follows gameplay vertically
- Camera does not auto-fit the whole world height
- Camera does not resize the world to keep the top and bottom simultaneously visible

Recommended implementation shape:

- Keep a single gameplay camera
- Set fixed X once
- Update only Y during runtime
- A small vertical dead zone or smoothing is allowed if it does not conflict with the intended feel

Preferred framing:

- The player does not need to be vertically centered exactly
- It is acceptable, and preferable, to keep the player slightly below center so the player can see more space above

### 4. Convert vertical world model away from one-screen fixed height

The current model assumes a fixed number of world rows.
That is no longer sufficient.

Required result:

- The game must support vertical progression beyond the original one-screen height
- The camera must be able to keep moving upward
- The world representation must no longer depend on the idea that the whole playable world height is always visible or permanently capped to the old screen-sized design

Codex may choose one of these implementation directions:

#### Acceptable direction A: very tall bounded world

- Expand the world height to a much larger vertical space
- Keep bottom floor semantics for the starting area
- Ensure camera can keep following upward for a long duration

#### Acceptable direction B: dynamic/chunked vertical extension

- Generate or maintain world data in vertical chunks/bands
- Extend world upward as needed
- Retain correct collision and mining logic

Preferred direction:

- **Direction B is preferred** if manageable
- **Direction A is acceptable** if it is the safer and less error-prone implementation for now

Important:

- Prioritize correctness and low bug risk over architectural ambition.
- It is acceptable to choose a simpler vertically large world first if that reduces implementation mistakes.

### 5. Update falling block spawn logic

The current spawn position is anchored to the old top-of-world logic.
That must change.

Required new spawn behavior:

- Falling blocks must spawn relative to the **current visible upper gameplay area**, not relative to the old fixed world top.
- Spawn X must still stay within the center shaft span.
- Spawn Y must be above the visible gameplay area so the block enters from above.

Use these rules:

- Spawn blocks **above the current camera top edge**
- Preferred margin: **2U to 4U above the visible top**
- The exact value may depend on block height, but must keep spawn off-screen at creation time
- Prevent unfair spawns directly intersecting the player
- Prevent spawn positions that overlap existing active falling blocks at creation time

Spawn fairness requirements:

- Do not spawn a falling block already intersecting the player
- Do not spawn a falling block already intersecting a settled obstacle at its spawn frame
- Avoid repeated obviously unfair same-column spam if easy to prevent

### 6. Preserve center-shaft-only falling behavior

Falling blocks should still spawn in the center shaft region, not inside the solid wall regions.

Required result:

- Spawn columns are restricted to the playable center shaft columns
- Block size must still be respected when choosing a valid spawn column

### 7. Update gameplay math impacted by larger player size

Because the player becomes 128x128 instead of 64x64, audit all logic that assumes 1U body size.

This includes at least:

- floor probes
- wall probes
- sand probes
- attack preview placement
- mining rect placement
- crush checks
- support snapping
- collision stepping assumptions
- body local rect logic

Required result:

- Player collision feels stable
- Larger player does not clip into walls or sand unexpectedly
- Supporting block ride/snap logic still works
- Attack and mining visuals remain aligned with the larger body

### 8. Preserve current horizontal composition

Do not redesign the width partition.

Required composition:

- Left wall: `10U`
- Center shaft: `10U`
- Right wall: `10U`

This composition is intentional for this pass.

---

## Explicitly forbidden changes

Do **not** do any of the following unless absolutely required to make the build run, and if done, keep the change minimal and explain it in the final summary:

- Do not change `UNIT_SIZE` from 64
- Do not change `CELL_SIZE` from 64
- Do not change `WALL_COLUMNS` from 10
- Do not change `CENTER_COLUMNS` from 10
- Do not change `WORLD_COLUMNS` from 30
- Do not solve the visibility problem by zooming out
- Do not reintroduce whole-world fit zoom behavior
- Do not add horizontal camera follow
- Do not shrink world units to make more columns fit
- Do not redesign the game into a different camera philosophy

---

## Acceptance criteria

Implementation is complete only if all of the following are true:

1. The game runs using a **1920x1080** gameplay resolution.
2. The full 30U width is visible at once.
3. The camera does not move horizontally during normal gameplay.
4. The camera can move upward following the player.
5. The player is visibly larger than before and uses the new larger body size.
6. Falling blocks spawn from above the current visible area, not from the old static world-top rule.
7. Falling blocks still spawn only within the center shaft.
8. Core movement, attack, mining, and collision behavior remain functional after the size change.
9. No old fit-to-full-world-height camera behavior remains active.

---

## Final output expected from Codex

After implementation, provide a concise change summary listing:

- which files were changed
- the final player body size
- the final camera behavior
- the final spawn rule
- whether the vertical world is large bounded or dynamically extended
- any known remaining caveats

Do not provide speculative design discussion.
Implement the spec.
