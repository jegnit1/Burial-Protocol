# Burial Protocol - Gameplay Systems Specification

## 0. Purpose

This document describes the gameplay systems that are currently implemented in the
prototype. It focuses on controls, movement, combat, mining, blocks, sand, walls,
progression, and run-end logic.

---

## 1. Input Map

Current default bindings:

- move left: `A`, `Left Arrow`
- move right: `D`, `Right Arrow`
- jump: `W`, `Up Arrow`, `Space`
- move down / fast fall: `S`, `Down Arrow`
- attack: `Left Mouse Button`
- mine: `Right Mouse Button`
- end run: `R`
- toggle HUD debug panel: `Tab`

Input actions are created at runtime by `GameConstants.ensure_input_actions()`.

---

## 2. Player Movement

### 2-1. Baseline Values

- move speed: `426 px/s`
- air speed: `373 px/s`
- sand speed multiplier: `0.62`
- gravity: `2000 px/s^2`
- jump speed: `-853`
- extra jumps: `1`
- wall jump horizontal speed: `480`
- wall slide cap: `200`
- jump buffer: `0.14s`
- coyote time: `0.1s`

### 2-2. Implemented Movement Features

The player currently supports:

- ground movement
- air movement
- buffered jump
- coyote jump
- one extra jump
- wall jump
- wall slide
- fast fall by holding down
- riding on top of falling blocks

The movement controller is pixel-stepped and uses custom collision handling rather
than full rigid-body motion.

### 2-3. Sand Interaction

The player is slowed when standing in sand.

Special support exists for:

- pushing sand sideways while moving through it
- clearing sand above the player to make jump paths possible
- resolving dash movement through sand differently from normal movement

---

## 3. Dash System

The current dash system is active and bound to double-tap input.

### 3-1. Trigger Rules

- double tap left to dash left
- double tap right to dash right
- double tap down to dash downward
- upward dash is currently disabled

### 3-2. Dash Values

- double-tap window: `0.22s`
- dash distance: `4 cells`
- dash duration: `0.08s`
- dash cooldown: `0.45s`

### 3-3. Dash Behavior

During dash:

- the player becomes a special movement state
- horizontal or downward motion is applied in a burst
- sand push attempts are more aggressive than normal movement
- the sprite gains dash feedback visuals
- attack and mining are blocked

Current feedback states include:

- queued
- armed
- cooldown
- blocked

---

## 4. Attack System

### 4-1. Attack Direction

Attack direction is resolved from the mouse position relative to the player.

Rules:

- mouse direction is used when distance exceeds the deadzone
- facing direction is used as fallback
- player facing flips with horizontal aim

### 4-2. Attack Shape

Current attack shape:

- rotated rectangle
- width: `1U`
- height: `1U`
- positioned directly outside the player body in the chosen direction

### 4-3. Attack Values

- base damage: `10`
- cooldown: `0.25s`
- buffer time: `0.12s`
- preview duration: `0.12s`

Current run bonuses can increase attack damage and effective attack speed.

### 4-4. Attack Targets

Attack currently hits active falling blocks through shape query results.

Current behavior:

- can hit multiple blocks in one swing
- applies damage to each block only once per swing
- updates status text for hit or miss

---

## 5. Mining System

### 5-1. Mining Direction

Mining uses the same directional resolution baseline as attack.

### 5-2. Mining Shape

Current mining shape:

- rotated rectangle
- forward distance: `0.25U`
- vertical size: `1U`
- positioned adjacent to the player body

### 5-3. Mining Values

- base mining damage: `1`
- cooldown: `0.15s`
- buffer time: `0.12s`

Current run bonuses can increase mining damage and mining speed.

### 5-4. Mining Targets

Mining can affect:

- sand cells
- wall subcells

Mining does not currently damage falling blocks.

### 5-5. Mining Rewards

Current reward rules:

- removing sand grants XP
- mining wall sections does not grant XP
- mining does not directly grant gold

Status text reports sand and wall hits separately when both are affected.

---

## 6. Falling Block System

### 6-1. Active Falling Blocks

Blocks spawn as active falling entities inside the center lane and fall downward
at a fixed speed.

Current fall speed:

- `226 px/s`

Base spawn interval:

- `1.2s`

### 6-2. Block Outcomes

A falling block can end in three major ways:

1. destroyed by player attack
2. decomposed when it settles on static terrain or sand
3. decomposed after crushing the player

If a falling block touches the player from above but does not crush them,
the current code can briefly position it onto the player's head area.

### 6-3. HP And Overlay

Blocks have HP and show a temporary HP bar overlay when damaged.

The overlay uses:

- short visible duration
- color interpolation from low HP to high HP

### 6-4. Destroyed Block Rewards

When a block is destroyed:

- gold is awarded
- XP is awarded
- a gold popup is spawned
- a status message is updated

When a block decomposes:

- it becomes sand according to its sand unit count
- no gold is awarded

---

## 7. Block Data Model

### 7-1. Block Bases

Current block bases:

- glass
- wood
- rock
- marble
- gold
- cement
- steel
- bomb

Each base defines:

- display name
- color
- spawn weight contribution
- HP multiplier
- reward multiplier
- special result type

### 7-2. Special Result Types

Current special-result ids exist in code for:

- none
- glass shatter damage
- bonus gold
- explosion

These ids are part of the data model, but their gameplay expansion is still limited.

### 7-3. Block Types

Current active block types are:

- `amber_small`
- `amber_tall_wood`
- `cobalt_tall`
- `cobalt_marble`
- `cobalt_gold`
- `ember_cement`
- `ember_wide`
- `ember_bomb`

Each block type defines:

- id
- size in world cells
- base health
- sand unit count
- gold reward
- color key
- spawn weight
- block base

### 7-4. Difficulty And Boss Multipliers

Current block HP may be modified by:

- selected difficulty HP multiplier
- boss extra HP multiplier for boss spawn blocks

Day 30 boss tracking uses the boss block spawned from `ember_wide`.

---

## 8. World Grid And Mining Walls

### 8-1. Static Structure

The world grid currently contains:

- left mining wall
- right mining wall
- center open lane
- bottom floor

### 8-2. Wall Structure

Each wall cell is subdivided into a `4 x 4` grid of subcells.

Each wall subcell currently has:

- max HP `3`

This allows partial wall mining instead of all-or-nothing wall removal.

### 8-3. Wall Collision

Static collision checks respect:

- world bounds
- floor
- remaining wall subcells

Mined wall cells visually track touched cells and partially damaged subcells.

---

## 9. Sand System

### 9-1. Representation

Sand is simulated as a dictionary of small cells.

Current density:

- `6 x 6` sand cells per `1U`

Each sand cell currently has:

- color
- weight value from color family
- HP
- stable flag

### 9-2. Sand Creation

Sand is spawned from block decomposition.

The number of spawned sand cells is based on block data `sand_units`.

### 9-3. Sand Simulation

The simulation is selective, not full-world brute force.

Current behavior:

- active cells are tracked
- only active regions are stepped
- movement priority alternates left/right by frame
- simulation is concentrated near the player and recently modified areas

### 9-4. Sand Movement

Sand currently tries to:

- fall straight down first
- move diagonally down-left or down-right if possible
- react conservatively after mining

### 9-5. Sand And Player Interaction

Current special handling includes:

- pushing sand sideways during movement
- limited chain push logic
- jump clearance attempts through sand above the player
- aggressive push attempts during dash

### 9-6. Weight Load

The run currently fails when:

- total sand cell count reaches or exceeds `240`

The HUD presents this as a weight load meter.

---

## 10. XP, Level, And Temporary Bonuses

### 10-1. XP Sources

Current XP sources:

- destroying a falling block
- removing sand through mining

Current formulas:

- block XP = `width_cells * height_cells * 2`
- sand XP = `removed_sand_count * 1`

### 10-2. Level Thresholds

Current starting values:

- level `1`
- current XP `0`
- next level XP `50`

After each level-up:

- current XP is reduced by the threshold
- level increases by `1`
- next threshold becomes `level * 50`

### 10-3. Level-Up UI

When XP reaches the threshold:

- `GameState.level_up_ready` is emitted
- gameplay pauses
- `LevelUpUI` appears
- three random cards are shown
- the player selects one card
- gameplay resumes

If overflow XP is still enough for another level, the popup can trigger again.

### 10-4. Current Level-Up Cards

Current cards:

- attack damage up
- attack speed up
- max HP up
- move speed up
- mining damage up
- mining speed up

These bonuses are temporary run bonuses, not permanent profile growth.

---

## 11. Gold And Feedback

### 11-1. Gold

Gold is currently granted only from destroyed falling blocks.

The HUD tracks:

- total gold
- gold earned during the current day

### 11-2. Visual Feedback

Current feedback systems include:

- attack preview shape
- mining preview shape
- dash outline and trail
- damage popup
- gold popup
- block HP overlay
- status text updates

Note: `GameState.status_text` is updated during gameplay, but the current HUD
does not display a dedicated status-text widget yet.

---

## 12. Run End And Clear Conditions

Current fail conditions:

- health reaches `0`
- sand count reaches `240` or more
- player presses `R`
- Day 30 timer expires before clear

Current clear conditions:

- Day 30 boss is destroyed
- or Day 30 boss decomposes while the player survives and sand remains below overload

---

## 13. Current Gaps

The following gameplay-adjacent systems are not yet fully realized:

- merchant/shop between days
- permanent growth gameplay
- achievement gameplay effects
- inventory ownership gameplay
- expanded block special-result behaviors
- advanced boss scripting

The current codebase is strongest in movement, falling-block handling, sand simulation,
and run readability systems.
