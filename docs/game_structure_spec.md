# Burial Protocol - Game Structure Specification

## 0. Purpose

This document describes the game structure that is actually implemented in the
current codebase. It focuses on the scene flow, run loop, day progression,
world layout, and run end rules used by the present prototype.

---

## 1. High-Level Loop

The current game loop is:

1. open the title screen
2. enter the main hub
3. optionally choose a character
4. open the difficulty popup
5. begin a run
6. survive the falling-block and sand-management loop
7. end the run by failure, manual exit, or clear
8. move to the result screen
9. return to the main hub

This loop is already playable end to end.

---

## 2. Scene Structure

### 2-1. Title

`Title.tscn` is the entry scene.

Current behavior:

- shows the title presentation screen
- routes into the main hub
- exposes placeholder buttons for settings, profile, and ranking
- can quit the game

### 2-2. Main Hub

`MainHub.tscn` is the central menu hub.

Current behavior:

- shows placeholder persistent currencies
- shows selected character summary
- shows best record summary
- opens the difficulty popup before gameplay starts
- routes to character list, achievements, growth, and item list

### 2-3. Character List

`CharacterList.tscn` lets the player pick the active character slot.

Current behavior:

- one default character is unlocked
- nine additional character slots exist as locked placeholders
- each slot shows status and best record summary
- locked slots show unlock text as tooltip

### 2-4. Placeholder Menu Screens

These scenes currently exist as navigable placeholders only:

- `Achievement.tscn`
- `Growth.tscn`
- `ItemList.tscn`

They are part of the menu loop, but not full gameplay systems yet.

### 2-5. Main Gameplay

`Main.tscn` owns the active run.

Its core children are:

- `WorldGrid`
- `SandField`
- `Player`
- `Blocks`
- `HUD`
- `WorldCamera`
- `SpawnTimer`

### 2-6. Result

`Result.tscn` displays the last finished run and sends the player back to the hub.

Current output:

- clear or fail header
- run end reason
- character name
- difficulty name
- highest day reached
- latest run record text

---

## 3. Save And Session Structure

The project uses `GameState.gd` as the shared state layer.

There are two important categories of state:

### 3-1. Persistent Profile State

Saved in `user://profile.save`:

- selected character
- last selected difficulty
- cleared difficulty ids
- best records by character and difficulty
- unlocked characters
- unlocked achievements
- placeholder currencies
- placeholder settings
- placeholder growth data

### 3-2. Per-Run State

Reset when a run begins:

- gold
- player health
- current day
- remaining day time
- current run difficulty
- current run character
- current run stage reached
- clear flag
- XP
- level
- temporary run bonuses from level-up cards

---

## 4. Run Start Flow

The current start flow is:

1. player enters `MainHub`
2. player may change character in `CharacterList`
3. player presses `Start Game`
4. hub opens a difficulty popup
5. chosen difficulty is validated against unlock rules
6. `GameState.begin_run()` stores current run selection
7. scene changes to `Main.tscn`
8. `Main._ready()` calls `GameState.reset_run()`

The run always starts at:

- day `1`
- timer `40.0` seconds
- stage reached `1`
- gold `0`
- level `1`
- XP `0 / 50`

---

## 5. Day Structure

### 5-1. Global Day Rules

The current run is defined as:

- total days: `30`
- day duration: `40` seconds each

The game updates a day timer every physics frame.

### 5-2. Day Types

Current day types are:

- normal day
- rush day: `5`, `15`, `25`
- boss day: `10`, `20`, `30`

Rush days reduce spawn interval.
Boss days also reduce spawn interval and force a boss block spawn.

### 5-3. Day Transition

Current implemented behavior:

- days `1` to `29` automatically advance when time expires
- there is no merchant scene or shop scene yet
- advancing to the next day resets the day timer
- the next boss day warning in the HUD updates automatically

This is important: older planning docs referenced a merchant/shop step,
but the current code does not implement that phase yet.

### 5-4. Day 30 Outcome

Day 30 is special.

Clear can happen in two ways:

1. the Day 30 boss block is destroyed
2. the Day 30 boss decomposes into sand, while the player is still alive and
   total sand count stays below the overload threshold

If Day 30 time expires before clear, the run fails.

---

## 6. Difficulty Structure

The current difficulty list is:

- `normal`
- `hard`
- `extreme`
- `hell`
- `nightmare`

Unlock rule:

- `normal` starts unlocked
- each higher difficulty requires clearing the previous one

Current difficulty effects in code:

- multiplier to block HP
- multiplier to mining HP value in definitions exists, but is not yet applied by gameplay code

Difficulty choice is made in the hub before entering the run.

---

## 7. World Layout

### 7-1. Fixed World Dimensions

The current world is fixed-size, not infinite:

- width: `30` columns
- height: `200` rows
- cell size: `64px`

Horizontal structure:

- left wall: `10` columns
- center lane: `10` columns
- right wall: `10` columns

### 7-2. Walls And Floor

The side walls are static mineable regions.
The floor is the last row and acts as solid ground.

The center lane is the active falling-block lane and player movement space.

### 7-3. Camera

The current camera rules are:

- horizontal center is fixed to world center
- vertical position follows the player
- zoom is `Vector2.ONE`
- camera limits are clamped to the world bounds

This means the prototype presents the run as a fixed-width vertical survival space.

---

## 8. Spawn Structure

Falling blocks are spawned by `SpawnTimer`.

Current spawn behavior:

- uses weighted block type selection
- spawns inside the center lane only
- spawns above the current camera view
- avoids immediate overlap with player and active blocks when possible
- avoids repeating the same spawn column on the first attempt

Boss days also inject a guaranteed boss block spawn using the `ember_wide` block type.

---

## 9. Run End Rules

The run currently ends for any of these reasons:

- manual end with `R`
- player health reaches `0`
- sand count reaches or exceeds the temporary overload threshold `240`
- Day 30 time expires before clear
- Day 30 boss clear condition is met

Days `1` to `29` ending by timer are not run-fail states.
They are automatic progression states.

---

## 10. HUD Role In Structure

The HUD is part of the run structure, not just decoration.

It currently provides:

- day number and total day count
- difficulty display
- next boss warning
- day timer
- player level, HP, XP
- total gold and day gold
- weight load meter
- sensor panel for player/block vertical awareness
- optional debug panel via `Tab`

The HUD is therefore one of the main structural layers of the playable loop.

---

## 11. Current Out-Of-Scope Or Placeholder Areas

The following remain outside current implemented structure:

- inter-day merchant or shop scene
- fully realized growth tree
- achievement progression logic
- inventory ownership loop
- detailed result breakdown
- multiple unique playable character kits
- advanced boss scripting beyond current boss spawn and clear rules

These should stay clearly separated from the current structure docs.

---

## 12. Summary

Burial Protocol currently ships as a playable vertical run prototype with:

- title to hub to run to result flow
- persistent selection and record state
- fixed 30-day run structure
- rush and boss day variants
- fixed-width vertical world presentation
- automatic day progression
- multiple fail states and one clear path

The biggest structural gap between older planning documents and current code is that
the day-to-day merchant/shop phase is still not implemented, while run-time combat,
movement, sand handling, and HUD readability are much further along.
