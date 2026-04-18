# Burial Protocol - Base State Specification

## 0. Purpose

This document describes the current shared state model used by the project.
It covers what is persisted, what exists only during a run, and which UI/runtime
systems depend on that shared state.

The primary owner of this state is `scripts/autoload/GameState.gd`.

---

## 1. State Categories

The project currently uses three practical state layers:

1. persistent profile state
2. current run state
3. temporary UI-facing signals

---

## 2. Persistent Profile State

Persistent data is stored in:

- path: `user://profile.save`
- format: JSON string
- save version field: `save_version`

### 2-1. Current Persistent Fields

The current save payload includes:

- `selected_character_id`
- `last_selected_difficulty_id`
- `persistent_currencies`
- `settings`
- `growth`
- `unlocked_character_ids`
- `unlocked_achievement_ids`
- `best_records_by_character`
- `cleared_difficulty_ids`

### 2-2. Persistent Data Meaning

#### Character State

- selected character id
- unlocked character ids
- per-character best records by difficulty

#### Difficulty State

- last selected difficulty id
- cleared difficulty ids for unlock chaining

#### Meta Placeholder State

- currencies
- settings
- growth
- achievements

These structures already persist, even where gameplay usage is still placeholder-only.

---

## 3. Character State

Current character-slot rules:

- one default worker slot starts unlocked
- nine additional slots exist as locked placeholders
- each slot stores a best record summary through `best_records_by_character`

The active selection shown in menus is:

- `selected_character_id`
- `selected_character_name`

The active run copies that into:

- `current_run_character_id`
- `current_run_character_name`

This separation matters because the result screen reflects the finished run,
not just the current menu selection.

---

## 4. Difficulty State

Current difficulty state fields:

- `last_selected_difficulty_id`
- `last_selected_difficulty_name`
- `current_run_difficulty_id`
- `current_run_difficulty_name`
- `cleared_difficulty_ids`

Unlock logic:

- `normal` is open by default
- each next difficulty unlocks only after the previous one is cleared

The hub uses this state to build the difficulty popup and disable locked buttons.

---

## 5. Current Run State

The following state resets at run start:

- `gold`
- `player_health`
- `status_text`
- `current_run_stage_reached`
- `current_day`
- `day_time_remaining`
- `run_cleared`
- `player_level`
- `player_current_xp`
- `player_next_level_xp`
- `run_bonus_attack_damage`
- `run_bonus_move_speed`
- `run_bonus_max_hp`
- `run_attack_speed_mult`
- `run_bonus_mining_damage`
- `run_mining_speed_mult`

### 5-1. Starting Values

Current defaults at run reset:

- gold: `0`
- health: `GameConstants.PLAYER_MAX_HEALTH`
- current day: `1`
- day time remaining: `GameConstants.DAY_DURATION`
- cleared flag: `false`
- level: `1`
- XP: `0`
- next level XP: `50`

### 5-2. Run Result State

When a run finishes, `finish_temporary_run()` stores:

- `latest_run_record`
- `latest_run_reason_id`
- `latest_run_reason_label`
- `latest_run_stage_reached`
- `latest_run_difficulty_name`
- `latest_run_character_name`

This is the data source for the result screen.

---

## 6. UI Signal Layer

`GameState` currently exposes these signals:

- `gold_changed`
- `health_changed`
- `status_text_changed`
- `selected_character_changed`
- `xp_changed`
- `level_changed`
- `level_up_ready`

### 6-1. Current Consumers

Current primary UI consumers:

- `HUD`
- menu scenes using `GameState` directly
- `LevelUpUI`

### 6-2. Important Note

`status_text` is actively updated by gameplay systems, but the current HUD does not
yet surface that text in a dedicated visual widget.

So this state exists and changes correctly, but its presentation layer is incomplete.

---

## 7. XP And Temporary Bonus State

Current XP flow:

- block destruction adds XP
- sand mining adds XP
- hitting level threshold emits `level_up_ready`

Current temporary run bonus fields:

- attack damage bonus
- move speed bonus
- max HP bonus
- attack speed multiplier
- mining damage bonus
- mining speed multiplier

These are temporary run modifiers, not permanent profile growth.

---

## 8. Best Record State

Best records are tracked as:

- per character
- per difficulty
- integer highest stage/day reached

The current menu summary converts this into a single text line such as the best
difficulty/day combination for a selected character.

This means the record system is already structurally ready for more complete
meta-progression later.

---

## 9. Save Lifecycle Rules

Current save lifecycle:

- load defaults first
- if file does not exist, create it
- normalize missing or malformed fields
- save again after load normalization
- save on most selection or unlock changes
- save when a run finishes

This approach favors resilience and predictable default recovery.

---

## 10. What This State Model Already Supports

The current base state is already enough to support:

- menu-to-run flow
- character selection
- difficulty unlock chain
- run result reporting
- persistent best records
- placeholder long-term currencies and settings
- run-time XP and level-up bonuses

---

## 11. Current Gaps

The following state structures still exist mainly as future-facing scaffolding:

- detailed permanent growth spending
- achievement reward logic
- inventory ownership logic
- more meaningful persistent currencies
- richer post-run reward application

Those systems do not need a new state layer yet.
They should extend the current `GameState` model carefully instead of bypassing it.
