# Burial Protocol - Run HUD UI Improvement

## 0. Purpose

This document records the current HUD structure and the remaining improvement targets
based on the live implementation in `scenes/ui/HUD.gd`.

The HUD is already much more than a mockup. It is part of the core run readability layer.

---

## 1. Current HUD Layout

The current HUD is divided into four main zones:

- top left: stage progress
- center left: sensor panel
- bottom left: player status and debug
- top right: economy and weight load

This structure is already implemented in code.

---

## 2. Current Implemented Panels

### 2-1. Top Left - Stage Progress

Currently shown:

- current day and total day count
- difficulty name
- next boss day warning
- remaining day time text
- remaining day time progress bar

Current goals this panel already satisfies:

- makes run pacing easy to read
- gives medium-term boss awareness
- shows exact remaining time and visual time pressure

### 2-2. Center Left - Sensor Panel

This panel currently acts as a vertical awareness tool, not a literal minimap.

Currently shown:

- visible vertical window relative to the camera
- active falling blocks in the center lane
- player position marker

This panel helps answer:

- what is falling above me
- where am I in the current visible vertical space
- how crowded is the center lane around the player

### 2-3. Bottom Left - Player Status

Currently shown:

- level box
- HP bar and exact HP text
- XP bar and exact XP text
- optional debug text panel

The debug panel is toggled with `Tab`.

### 2-4. Top Right - Economy And Weight

Currently shown:

- total gold
- gold earned during the current day
- current weight load
- weight load bar
- weight status label

Current weight states:

- `SAFE`
- `SLOW`
- `CRUSH`
- flashing critical state near overload

The weight meter is one of the most important survival signals in the current prototype.

---

## 3. What The Current HUD Does Well

- separates pacing, survival, economy, and player-state information
- keeps important numeric values paired with bars where needed
- gives the player a readable overload warning
- exposes day progression clearly
- supports the XP and level-up loop
- includes a debug layer for rapid iteration

---

## 4. Current Gaps

### 4-1. Status Text Is Not Surfaced

Gameplay constantly updates `GameState.status_text`, but the HUD currently ignores it.

That means the player does not get a dedicated on-screen feed for:

- attack hit or miss
- mining results
- crush warnings
- block destroy notifications beyond popups

### 4-2. Localization Coverage Is Incomplete

Some visible HUD strings are still hardcoded directly in `HUD.gd`, including:

- `CURRENT DAY`
- `TIME REMAINING`
- `NEXT BOSS`
- `GOLD`
- `WEIGHT LOAD`
- `THIS DAY`
- `SAFE`, `SLOW`, `CRUSH`

The project already has a locale layer, so these should move into `Locale.gd`.

### 4-3. Sensor Panel Can Be More Informative

The current sensor panel already works, but it does not yet show:

- sand density directly
- weight threshold markers
- stronger boss emphasis
- better visual distinction between normal and dangerous block groups

### 4-4. HUD Messaging Consistency Needs Cleanup

Some systems use polished bars and labels.
Others still rely on implicit understanding.

The next UI pass should align:

- panel naming
- font hierarchy
- localization
- status feedback placement

---

## 5. Recommended Improvement Order

### Step 1

Add a dedicated status feed area to the HUD and connect it to `GameState.status_text_changed`.

### Step 2

Move hardcoded HUD strings into `Locale.gd`.

### Step 3

Improve sensor readability for:

- boss threats
- near-camera falling danger
- overload pressure context

### Step 4

Polish visual consistency across all panels after the information structure is complete.

---

## 6. Non-Goals For The Next HUD Pass

The next pass should not:

- replace the current HUD with a full-screen menu overlay
- turn the sensor into a detailed minimap
- hide numeric data behind pure visuals
- add excessive decorative animation before core readability is done

The HUD should stay practical and run-focused.

---

## 7. Summary

The run HUD is already a real gameplay interface, not a future-only concept.
The biggest remaining improvement is not layout invention.
It is completing the information loop:

- surface status text
- localize panel labels
- sharpen sensor communication

That will make the existing run systems much easier to read without requiring a major redesign.
