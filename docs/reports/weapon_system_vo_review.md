# Burial Protocol Weapon System VO Review

- Review date: 2026-06-01
- Scope: current weapon VO, catalog, runtime slot state, combat calculation, and sand interaction
- Purpose: expose the current transitional structure before the next equipment-system migration phase. This report does not start a large combat refactor.

## 1. Current Weapon-System VO List

| VO / Resource | File | Role |
| --- | --- | --- |
| `ShopItemDefinition` | `scripts/data/ShopItemDefinition.gd` | Shared item Resource. It currently carries weapon, drone protocol, passive module, shop, combat, visual, and compatibility fields. This is the effective weapon definition VO. |
| `ShopItemResourceCatalog` | `scripts/data/ShopItemResourceCatalog.gd` | Resource catalog that indexes `ShopItemDefinition` entries and exposes equipment-category queries. It still provides legacy `attack_module` accessors. |
| `ShopItemCatalog` | `scripts/data/ShopItemCatalog.gd` | Runtime dictionary adapter. It maps legacy raw categories such as `attack_module` to new equipment categories such as `weapon`. |
| `AttackModuleStyleResolver` | `scripts/data/AttackModuleStyleResolver.gd` | Legacy style compatibility helper for `module_type`, `attack_style`, shape, projectile, and visual defaults. |
| weapon slot entry dictionary | `scripts/autoload/GameState.gd` | Runtime weapon-instance value object. Stores `instance_id`, `module_id`, and `grade` for equipped and owned weapons. |
| `AttackModuleProjectile` | `scenes/projectiles/AttackModuleProjectile.gd` | Runtime projectile object. Resolves mixed block/sand collision candidates, shared penetration, and optional explosion behavior. |
| `SandCellData` | `scripts/data_models/SandCellData.gd` | Sand-cell runtime value object. Stores per-cell HP and supports weapon damage application through `SandField`. |

There is no dedicated `WeaponDefinition` Resource yet. Weapons are represented by the shared `ShopItemDefinition` VO and distinguished by `equipment_category == "weapon"`.

## 2. Role of Each VO

### `ShopItemDefinition`

This is the source VO for generated `.tres` item data. Its weapon-relevant fields are:

| Group | Fields |
| --- | --- |
| identity | `item_id`, `name`, `item_category`, `equipment_category`, `rank` |
| classification | `attribute`, `attack_type`, `weapon_type`, `module_type`, `attack_style`, `effect_style` |
| grade data | `base_damage_by_grade`, `price_by_grade` |
| timing | `weapon_base_cooldown`, `attack_speed_multiplier` |
| shape/range | `hit_shape`, `base_shape_units`, `range_units`, `range_width_u`, `range_height_u`, growth fields |
| projectile | `projectile_count`, `spread_angle`, `pierce_count`, `is_hitscan`, `projectile_speed`, `projectile_lifetime`, `projectile_max_distance`, `projectile_visual_size`, `projectile_homing` |
| equipment effects | `conditions`, `effects`, `apply_timing`, `allowed_weapon_ids`, `allowed_weapon_types`, `allowed_attack_styles`, `exclusive_group` |
| presentation | `icon_path`, `world_visual_scene_path`, `short_desc`, `desc`, `tags` |

### Catalog Resources and Adapter

`ShopItemResourceCatalog` stores generated Resource entries. `ShopItemCatalog` provides runtime dictionaries and normalizes legacy categories:

| Raw category | Runtime equipment category |
| --- | --- |
| `attack_module` | `weapon` |
| `function_module` | `drone_protocol` |
| `enhance_module` | `passive_module` |

### Runtime Weapon Slot Entry

`GameState` uses a compact dictionary as the equipped weapon instance VO:

```gdscript
{
    "instance_id": String,
    "module_id": String,
    "grade": String
}
```

The dictionary is suitable as a transitional runtime entry, but its `module_id` and `grade` names preserve the old attack-module terminology.

## 3. Parts Matching the New Equipment Spec

| Spec item | Current implementation |
| --- | --- |
| two weapon slots | `GameState.equipped_weapon_left` and `GameState.equipped_weapon_right` exist. |
| left-click fires both weapons | `Player.consume_attack_module_triggers()` iterates both equipped entries. Each entry has its own cooldown keyed by `instance_id`. Right click is not used for the right weapon. |
| D-S weapon grades | `GameConstants.ATTACK_MODULE_GRADE_ORDER` and grade damage maps support `D`, `C`, `B`, `A`, and `S`. |
| weapon attack damage stat | `GameState.run_bonus_weapon_attack_damage` and `get_weapon_attack_damage_flat()` are present. |
| attack-speed stat | `GameState.run_weapon_attack_speed_mult` participates in weapon cooldown calculation. |
| drone attack damage stat | `GameState.run_bonus_drone_attack_damage` is separate from weapon damage. |
| drone cooldown reduction | `GameState.run_drone_cooldown_reduction` is separate from weapon attack speed. |
| weapon attributes and types | `attribute`, `attack_type`, and `weapon_type` fields are present in the VO and TSV schema. |
| sand is weapon-only damage | `SandField` accepts weapon-source damage through weapon-specific APIs. Drone protocol attacks do not call these APIs. |
| sand damage ratio | `GameConstants.SAND_WEAPON_DAMAGE_RATIO` is `0.10`; `SandField` applies the ratio once internally. |
| sand collision and penetration | Projectile collision candidates include blocks and sand cells. Both consume the same penetration budget. |

## 4. Conflicts and Ambiguities

| Priority | Area | Current state | Required next decision or fix |
| --- | --- | --- | --- |
| P1 | dedicated weapon VO | The shared `ShopItemDefinition` Resource is still the effective weapon VO. | Decide whether to keep one extensible equipment VO or split out `WeaponDefinition`. |
| P1 | category naming | Source TSV and generated `.tres` data still use raw `item_category == "attack_module"` for weapons. The adapter converts it to `weapon`. | Migrate the source schema after compatibility requirements are settled. |
| P1 | per-weapon cooldown | `weapon_base_cooldown` exists in data, but `GameState.get_attack_module_cooldown_duration()` currently starts from global `GameConstants.PLAYER_ATTACK_COOLDOWN`. | Consume the VO field so Spreadsheet-defined weapon cooldowns become authoritative. |
| P1 | explosion fields | `AttackModuleProjectile` supports runtime `explosion_radius`, but the value is not wired through `ShopItemDefinition`, TSV schema, catalog generation, or `Main.gd` projectile setup. | Add data-driven explosion fields before adding explosive catalog rows. |
| P2 | duplicated type fields | `weapon_type`, `module_type`, and `attack_style` coexist. Runtime attack dispatch still depends heavily on legacy `module_type == melee/ranged`. | Define the canonical classification fields and retain compatibility only at an explicit boundary. |
| P2 | attributes and attack types | Metadata is loaded and available to conditions, but the core damage formula does not yet apply a complete attribute/type ruleset. | Specify multipliers, resistance ownership, and effect hooks before implementation. |
| P2 | rank terminology | Equipment data exposes `rank`, while owned weapon entries use `grade`. | Standardize naming when runtime save migration is planned. |
| P2 | legacy stat hooks | Weapon damage still reads compatibility hooks such as `melee_attack_damage_flat`, `ranged_attack_damage_flat`, `weapon_melee_damage_flat`, and `weapon_ranged_damage_flat`. | Remove or migrate these hooks after old items and saves no longer require them. |
| P2 | drone protocol source row | `drone_attack_module` remains in `attack_module_items.tsv` although its normalized equipment category is `drone_protocol`. | Move it to the protocol source table during schema migration. |

## 5. Current Weapon Data Fields

The generated weapon source is currently `data_tsv/attack_module_items.tsv`. Implemented weapon rows are:

| weapon id | name | attribute | attack type | legacy style | D-S base damage | cooldown | projectile summary |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `sword_module` | 소드 모듈 | `physical` | `area` | `melee/slash` | `10/15/20/25/30` | `0.3` | shape attack |
| `dagger_module` | 대거 모듈 | `physical` | `area` | `melee/stab` | `9/14/18/23/27` | `0.3` | shape attack |
| `lance_module` | 랜스 모듈 | `physical` | `area` | `melee/pierce` | `13/20/26/33/39` | `0.3` | shape attack |
| `axe_module` | 액스 모듈 | `physical` | `area` | `melee/smash` | `17/26/34/43/51` | `0.3` | shape attack |
| `greatsword_module` | 그레이트소드 모듈 | `physical` | `area` | `melee/cleave` | `24/36/48/60/72` | `0.3` | shape attack |
| `pistol_module` | 피스톨 모듈 | `physical` | `projectile` | `ranged/revolver` | `5/8/10/13/15` | `0.3` | one projectile, no pierce |
| `shotgun_module` | 샷건 모듈 | `physical` | `projectile` | `ranged/shotgun` | `4/6/8/10/12` | `0.3` | three projectiles, spread `26`, no pierce |
| `sniper_module` | 스나이퍼 모듈 | `physical` | `projectile` | `ranged/sniper` | `4/6/8/10/12` | `0.3` | one projectile, pierce `2` |
| `laser_module` | 레이저 모듈 | `energy` | `beam` | `ranged/laser` | `3/5/6/8/9` | `0.3` | hitscan |

`shotgun_module` is the current default-start weapon.

## 6. Current Damage, Cooldown, Penetration, and Sand Flow

### Weapon Damage

The current calculation is owned by `GameState`:

```text
grade base damage
+ weapon attack damage flat
+ compatible part-effect flat damage
-> global damage multiplier and part percent effects
-> floor()
```

Legacy melee/ranged subtype flat effects can still contribute based on `module_type`.

### Weapon Cooldown

The active cooldown path is:

```text
GameConstants.PLAYER_ATTACK_COOLDOWN
* run weapon attack-speed multiplier
/ definition attack-speed multiplier
/ grade speed multiplier
/ compatible part-effect speed multiplier
```

The stored `weapon_base_cooldown` VO field is not yet authoritative. This is the most important issue before Spreadsheet-driven balancing.

### Sand Damage

All normal weapon sand damage is reduced exactly once in `SandField`:

```gdscript
var sand_damage := weapon_damage * GameConstants.SAND_WEAPON_DAMAGE_RATIO
```

`GameConstants.SAND_WEAPON_DAMAGE_RATIO` is `0.10`. Callers pass original weapon damage, not pre-reduced damage.

### Sand Collision and Penetration

`AttackModuleProjectile` builds a distance-sorted list containing both block and sand candidates.

| Attack kind | Current behavior |
| --- | --- |
| non-piercing projectile | damages the first block or sand cell, then removes the projectile |
| piercing projectile | damages the first target and consumes `pierce_count` for each additional block or sand target |
| non-piercing hitscan | stops at the first distance-sorted block or sand target |
| piercing hitscan | continues only while the shared penetration count permits |
| explosion runtime path | explodes at the first collision point and can damage each sand cell in the radius; catalog wiring is still pending |
| melee/shape attack | applies 10% weapon damage independently to sand cells inside the shape |

Drone protocols do not use weapon sand-damage APIs. The cleaner protocol uses its own explicit sand-removal behavior rather than weapon damage.

## 7. Left and Right Weapon Slot Handling

`GameState` owns:

```gdscript
equipped_weapon_left
equipped_weapon_right
```

`get_equipped_weapon_entries()` returns the left entry followed by the right entry. `Player.consume_attack_module_triggers()` checks both entries on left click and tracks separate per-instance cooldowns. Therefore:

- both weapons use left click;
- the right weapon is not bound to right click;
- each weapon can fire when its own cooldown is ready;
- right-click mining remains independent.

The slot implementation matches the requested control concept.

## 8. Remaining `attack_module` Structure

The old structure remains as a compatibility layer and is still visible in active code:

| Area | Remaining legacy structure |
| --- | --- |
| data source | `data_tsv/attack_module_items.tsv` |
| generated data | weapon rows still use raw `item_category == "attack_module"` |
| runtime methods | names such as `get_attack_module_damage()`, `get_attack_module_cooldown_duration()`, and `consume_attack_module_triggers()` |
| runtime state | `owned_attack_module_ids`, `equipped_attack_module_id`, and `equipped_attack_modules` mirror weapon state |
| projectile class | `AttackModuleProjectile` |
| style resolution | `AttackModuleStyleResolver` |
| tests and docs | several compatibility-oriented filenames and references remain |

The old five-orbiting-module gameplay is not the intended active equipment model, but legacy naming and adapters are still substantial.

## 9. Remaining Melee/Ranged Attack-Power Traces

The new level-up card pool uses weapon attack damage and drone attack damage. Old melee/ranged attack-up cards are removed from the basic pool.

Compatibility traces remain in `GameState`:

- `get_melee_base_attack_damage()` aliases weapon base damage;
- `get_ranged_base_attack_damage()` aliases weapon base damage;
- `get_melee_attack_damage_flat()` aliases weapon flat damage;
- `get_ranged_attack_damage_flat()` aliases weapon flat damage;
- subtype part-effect hooks for melee and ranged can still modify weapon damage.

These traces should be removed only as part of an explicit save/data migration phase.

## 10. Next Code Files to Modify

Recommended order for the next phase:

1. `scripts/data/ShopItemDefinition.gd`
   Define the canonical weapon VO boundary and add missing data-driven fields such as explosion radius where approved.
2. `scripts/tools/data_pipeline/TsvSchema.gd`
   Introduce the canonical weapon Spreadsheet schema and decide how legacy TSV import remains supported.
3. `scripts/tools/data_pipeline/TsvToTresConverter.gd`
   Map canonical weapon rows into Resource definitions.
4. `scripts/tools/data_pipeline/TsvValidationService.gd`
   Validate weapon-only sand flags, ranks, cooldowns, pierce counts, and optional explosive fields.
5. `scripts/data/ShopItemCatalog.gd` and `scripts/data/ShopItemResourceCatalog.gd`
   Move normalization and compatibility to a narrow adapter boundary.
6. `scripts/autoload/GameData.gd`
   Add weapon-first accessors and deprecate attack-module naming.
7. `scripts/autoload/GameState.gd`
   Consume `weapon_base_cooldown`, standardize runtime weapon entry terminology, and retire old melee/ranged hooks when migration is ready.
8. `scenes/main/Main.gd`
   Dispatch from canonical weapon fields and wire optional explosion data.
9. `scenes/player/Player.gd`
   Rename compatibility trigger APIs after runtime migration while preserving left-click dual-weapon behavior.
10. `scenes/projectiles/AttackModuleProjectile.gd`
    Rename only after callers are migrated; preserve the current shared block/sand penetration behavior.
11. `data/items/ShopItemCatalog.tres`
    Regenerate after schema conversion.
12. `data_tsv/attack_module_items.tsv`
    Retire or convert after the canonical Spreadsheet export/import path is agreed.

The Spreadsheet planning draft is `data_tsv/weapon_catalog_draft.tsv`. It intentionally mirrors implemented weapons first and leaves future balance decisions open.
