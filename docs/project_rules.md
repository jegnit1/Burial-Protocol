# Burial Protocol - Project Rules

## 0. Purpose

This document records the current working rules for the Burial Protocol codebase.
It is not a wish list. It should describe what is actually implemented now,
what is intentionally placeholder-only, and how future work should be added.

The goal is to keep code, docs, and ongoing tasks aligned so the team can make
changes without re-learning the project from scratch every time.

---

## 1. Source Of Truth

When code and docs disagree, the current source code is the final truth.
The priority order for references is:

1. Runtime source files
2. `docs/project_rules.md`
3. `docs/game_structure_spec.md`
4. `docs/gameplay_systems_spec.md`
5. `docs/base_state_spec.md`
6. `docs/phase1_tasks.md`
7. `docs/burial_protocol_run_hud_ui_improvement.md`

The main runtime files to verify before updating docs are:

- `scripts/autoload/GameConstants.gd`
- `scripts/autoload/GameState.gd`
- `scripts/autoload/Locale.gd`
- `scenes/main/Main.gd`
- `scenes/player/Player.gd`
- `scenes/world/WorldGrid.gd`
- `scenes/world/SandField.gd`
- `scenes/blocks/FallingBlock.gd`
- `scenes/ui/HUD.gd`
- `scenes/ui/Title.gd`
- `scenes/ui/MainHub.gd`
- `scenes/ui/CharacterList.gd`
- `scenes/ui/Result.gd`
- `scenes/ui/LevelUpUI.gd`

---

## 2. Current Product Baseline

- Engine: Godot 4.6
- Language: GDScript
- Platform target: PC
- Viewport: `1920 x 1080`
- World unit: `1U = 64px`
- Player display/collision size baseline: `128 x 128`
- World width: `30 columns`
- Side walls: `10 columns` each side
- Center combat lane: `10 columns`
- World height: `200 rows`
- Floor row: last world row

The project is currently a playable vertical-survival prototype built around:

- falling blocks
- sand accumulation and sand simulation
- wall mining and sand mining
- mouse-direction attack and mining
- movement, jump, wall jump, extra jump, fast fall
- double-tap dash
- day-based run progression
- difficulty selection and unlock chain
- XP, level-up card selection, and temporary run bonuses
- HUD-based run readability

---

## 3. Current Implemented Scope

### 3-1. Menu And Run Flow

The current scene flow is:

1. `Title`
2. `MainHub`
3. optional `CharacterList`
4. difficulty popup from hub
5. `Main`
6. `Result`
7. back to `MainHub`

The following menu scenes exist but are still placeholder screens:

- `Achievement`
- `Growth`
- `ItemList`

Title buttons for settings, profile, and ranking are also placeholder-only.

### 3-2. Current Run Systems

The following systems are already active in gameplay:

- run reset and run result recording
- day timer and day progression
- rush day and boss day spawn rules
- falling block spawn fairness checks
- block destruction reward flow
- block decomposition into sand
- sand simulation around the player
- wall subcell mining
- temporary weight fail condition
- XP gain and level-up card popup
- gold and damage popup feedback
- HUD updates for day, gold, weight, HP, XP, level, and debug

### 3-3. Current Persistence

The profile save is stored at `user://profile.save`.
It currently persists:

- selected character
- last selected difficulty
- unlocked difficulties through clear records
- per-character best records by difficulty
- placeholder persistent currencies
- placeholder growth data
- placeholder settings data
- unlocked characters
- unlocked achievements

---

## 4. Intentionally Not Implemented Yet

The following are still outside the current implemented scope:

- real merchant or shop phase between days
- actual inter-day purchase flow
- permanent growth gameplay logic
- achievement gameplay logic
- inventory/item ownership logic
- richer result statistics and reward summary
- multi-character gameplay differences
- full presentation art pass
- advanced boss scripting beyond current boss spawn rule
- polished localization pass for every runtime string

When docs mention these systems, they must be marked as future work or placeholder.
They must not be written as if already shipping.

---

## 5. Implementation Rules

### 5-1. Prefer Current Playability Over Premature Expansion

Changes should keep the playable loop stable first:

- player control
- falling block handling
- sand behavior
- run progression
- HUD readability

Do not add broad speculative systems before the current loop is stable.

### 5-2. Centralize Tunables

Numeric gameplay values should live in `GameConstants.gd` unless there is a strong
reason not to.

This includes:

- player movement values
- dash values
- attack and mining values
- world size values
- HUD layout values
- sand simulation limits
- day and difficulty values
- block base and block type definitions

### 5-3. Keep Runtime State In GameState

Persistent or run-wide state belongs in `GameState.gd`, not scattered across menu scenes.

Examples:

- selected character
- difficulty selection
- latest run result
- gold
- HP
- XP
- level
- temporary run bonuses
- save-backed unlock and record data

### 5-4. Use Placeholder Screens Honestly

Placeholder scenes are allowed when they keep the flow connected,
but they must remain obviously placeholder.

Do not describe a placeholder menu as a completed feature in docs.

---

## 6. Documentation Rules

### 6-1. Docs Must Follow Code Changes Quickly

Update docs whenever any of these change:

- input bindings
- player movement rules
- attack or mining shapes
- dash behavior
- day progression rules
- clear or fail conditions
- HUD structure
- save structure
- block definitions or spawn rules

### 6-2. Separate Current Reality From Future Work

Each doc should distinguish between:

- currently implemented behavior
- placeholder behavior
- planned but not yet implemented behavior

Avoid mixing them in the same sentence.

### 6-3. Prefer Concrete Numbers And File Anchors

If a value is fixed in code, docs should record the concrete value instead of vague phrasing.

Good examples:

- `DAY_DURATION = 40.0`
- `RUN_TOTAL_DAYS = 30`
- weight fail threshold `240`
- dash distance `4 cells`

---

## 7. Validation Checklist After Changes

After changing core gameplay or UI, confirm at least the following:

- title to hub transition still works
- hub to run transition still works
- character selection still updates `GameState`
- difficulty unlock logic still behaves correctly
- attack and mining still use mouse direction
- dash still triggers on double tap
- sand count still updates weight fail logic
- day progression still advances correctly
- result screen still shows latest run data
- docs affected by the change are updated in the same work cycle

---

## 8. Current Direction

The current project direction is:

- keep the vertical survival loop playable
- make state and rules explicit
- tighten HUD readability
- keep the docs synchronized with the code
- expand only after the core run loop is dependable

This means the project should continue to favor clarity and reliable iteration over
large speculative content additions.
