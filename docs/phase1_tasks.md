# Burial Protocol - Phase 1 Tasks

## 0. Snapshot

Updated for current source state on `2026-04-19`.

Phase 1 is no longer just a bootstrap task list.
The project already has a playable run loop, so this document now tracks:

- what has been completed
- what still needs cleanup or polish
- what should come next without breaking the current loop

---

## 1. Completed In The Current Phase

### 1-1. Menu And Flow

- title screen to main hub flow
- main hub to gameplay flow
- character list scene and selection state
- result screen flow back to hub
- placeholder achievement, growth, and item-list scenes

### 1-2. State And Persistence

- save profile bootstrap at `user://profile.save`
- selected character persistence
- last selected difficulty persistence
- difficulty clear tracking
- per-character best record tracking
- placeholder currencies, settings, growth, unlock arrays

### 1-3. World And Run Loop

- fixed-size world layout
- center lane plus mineable side walls
- bottom floor
- camera follow in vertical play space
- spawn timer driven falling blocks
- rush days and boss days
- day timer and automatic day advance
- Day 30 clear and failure flow

### 1-4. Player Core Systems

- movement
- jump, coyote time, buffer jump
- extra jump
- wall jump and wall slide
- fast fall
- attack
- mining
- double-tap dash
- falling block support riding

### 1-5. Environment Systems

- falling block HP and destruction
- block decomposition into sand
- sand simulation with active-cell stepping
- wall subcell mining
- player sand push and jump-space clearance helpers
- temporary weight overload fail condition

### 1-6. Progression And Feedback

- gold gain from block destruction
- XP gain from block destruction and sand mining
- level-up popup with three random cards
- temporary run bonuses
- damage popup
- gold popup
- HUD for day, gold, weight, HP, XP, and level
- optional debug panel

### 1-7. Data And Localization

- centralized tunables in `GameConstants.gd`
- block bases and block types data tables
- locale autoload with Korean and English tables

---

## 2. Current Open Work

These are the most important unfinished areas that already touch the live loop.

### 2-1. Inter-Day Structure

- merchant/shop phase between days is still not implemented
- day transition currently auto-advances from timer expiry to next day
- related UI and economy decision flow are still missing

### 2-2. Menu Depth

- achievement screen is still placeholder-only
- growth screen is still placeholder-only
- item list screen is still placeholder-only
- title-side settings/profile/ranking buttons are still placeholder-only

### 2-3. HUD Polish

- `GameState.status_text` is updated but not surfaced as a dedicated HUD widget
- some HUD labels are hardcoded rather than routed through `Locale`
- sensor panel can be improved further for clarity and consistency

### 2-4. Run Presentation

- result screen is functional but minimal
- boss presentation is currently rule-based, not event-driven or cinematic
- current block special-result ids exist in data but are only lightly expressed

### 2-5. Localization And Text Cleanup

- runtime locale support exists, but not every visible label is localized
- some recent UI strings are still direct English strings in code

---

## 3. Recommended Next Priorities

### Priority A - Make Day Transitions A Real Gameplay Layer

Target:

- implement the missing inter-day merchant/shop phase
- connect day end to a real decision moment instead of instant advance

Suggested scope:

- day-end pause or overlay
- next-day button or shop confirmation
- gold spending path
- explicit day transition messaging

### Priority B - Promote Status Feedback Into HUD

Target:

- expose gameplay status text directly in the HUD

Suggested scope:

- recent attack result
- mining result
- crush warning
- block destruction reward text

### Priority C - Turn Placeholder Meta Screens Into Real Systems

Target:

- choose one of achievements, permanent growth, or inventory and make it real

Recommendation:

- start with permanent growth or achievements before inventory breadth

### Priority D - Tighten Localization Pass

Target:

- move recent hardcoded UI text into `Locale.gd`
- keep Korean and English outputs consistent

---

## 4. Guardrails For The Next Phase

The next phase should not destabilize the current playable loop.

Before adding new content, preserve:

- movement feel
- dash usability
- attack and mining responsiveness
- block spawn readability
- sand overload tension
- day timer progression
- result screen return flow

Do not replace the current loop with a large speculative refactor unless the
project is explicitly moving to a new architecture.

---

## 5. Verification Checklist

Use this checklist after major gameplay or UI changes:

- title opens the hub correctly
- hub starts a run only after difficulty selection
- locked difficulties stay locked until previous clear
- character selection persists
- attack hits falling blocks
- mining affects sand and walls
- dash still triggers on double tap
- day timer counts down correctly
- day 1 to 29 still advance
- Day 30 still clears or fails correctly
- result screen shows the latest run data
- docs are updated in the same cycle

---

## 6. Phase Summary

Phase 1 has already moved beyond bootstrap.
The current milestone is best described as:

"a playable vertical run prototype with strong core movement and environment systems,
but incomplete inter-day meta structure."

That means the best next work is not rebuilding the core loop.
It is turning the missing day-end and meta layers into real gameplay while keeping
the current run systems stable.
