# TSV to TRES Pipeline Audit

Date: 2026-05-01

Scope: local TSV to TRES conversion only. Google Sheets is intentionally out of scope.

## Summary

The TSV pipeline is broadly operational: headers match the current `TsvSchema.gd`, `convert_tsv` succeeds, and the core live v1 runtime data round-trips cleanly for shop items, block material/size/type, and stage days.

The main caveat is v2 spawn rule persistence. `data_tsv/block_size_spawn_rules.tsv` and `data_tsv/block_material_size_weight_rules.tsv` are supported by schema/import/export/validation, and a conversion writes them into `BlockCatalog.tres`. However, the current checked working `data/blocks/BlockCatalog.tres` does not yet contain `block_size_spawn_rules` or `block_material_size_weight_rules`. Current v2 simulation still works because `BlockSpawnV2Simulator.gd` loads those two TSV files directly. Live v1 spawning is unchanged and still uses `BlockCatalog.get_spawn_candidates()` plus `BlockSpawnResolver.resolve_random_block()`.

No balance values, attack DPS values, block spawn weights, or live resolver paths were changed during this audit. The conversion was tested with backup/restore around the runtime `.tres` files.

## A. TSV Responsibility Mapping

| TSV | Target `.tres` | Resource | Runtime use | v1/v2 | Import | Export | Validation |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `data_tsv/attack_module_items.tsv` | `data/items/ShopItemCatalog.tres` | `ShopItemDefinition` inside `ShopItemResourceCatalog` | Yes, shop/combat definitions | v1 live | Yes, `TsvToTresConverter._build_attack_module_item_definition()` | Yes, `TsvExportService._build_attack_module_item_row()` | Yes, `validate_shop_item_catalog()` |
| `data_tsv/block_materials.tsv` | `data/blocks/BlockCatalog.tres` | `BlockMaterialData` | Yes, live block spawn and resolve | v1 live | Yes, `BlockDataImporter.import_from_directory()` | Yes, `_build_block_material_rows()` | Yes, `validate_block_catalog()` |
| `data_tsv/block_sizes.tsv` | `data/blocks/BlockCatalog.tres` | `BlockSizeData` | Yes, live block spawn and resolve | v1 live | Yes | Yes, `_build_block_size_rows()` | Yes |
| `data_tsv/block_types.tsv` | `data/blocks/BlockCatalog.tres` | `BlockTypeDefinition` | Yes, optional type path; current random chance is 0 | v1 live | Yes | Yes, `_build_block_type_rows()` | Yes |
| `data_tsv/block_size_spawn_rules.tsv` | `data/blocks/BlockCatalog.tres` when converted; also read directly by simulator | `BlockSizeSpawnRuleData` | Not live; simulation rule source | v2 simulation-only | Yes, `BlockDataImporter` | Yes, `_build_block_size_spawn_rule_rows()` | Yes, `validate_block_catalog()` and `validate_spawn_v2_rules()` |
| `data_tsv/block_material_size_weight_rules.tsv` | `data/blocks/BlockCatalog.tres` when converted; also read directly by simulator | `BlockMaterialSizeWeightRuleData` | Not live; simulation rule source | v2 simulation-only | Yes, `BlockDataImporter` | Yes, `_build_block_material_size_weight_rule_rows()` | Yes |
| `data_tsv/stage_days.tsv` | `data/stages/StageTable.tres` | `StageDayDefinition` in `StageTable` | Yes, day duration/HP/spawn tempo/boss block | v1 live | Yes, `_convert_stage_table()` | Yes, `_build_stage_day_rows()` | Yes, `validate_stage_table()` |

Note: `data_tsv/block_catalog_meta.tsv` is also required by the block importer although it was not listed in the requested TSV set. It maps to `BlockCatalog.default_block_base_id`, `default_block_size_id`, and `random_type_chance`.

## B. Header and Schema Comparison

| TSV | Rows | Columns | Header match | Missing columns | Extra columns | Deprecated columns | Action |
| --- | ---: | ---: | --- | --- | --- | --- | --- |
| `attack_module_items.tsv` | 10 | 48 | Yes | None | None | None; no direct `damage_multiplier`, no legacy projectile aliases | None |
| `block_materials.tsv` | 8 | 16 | Yes | None | None | `max_allowed_area`, `max_allowed_width`, `max_allowed_height` remain as live v1 legacy gates | Keep until resolver migration |
| `block_sizes.tsv` | 8 | 13 | Yes | None vs current schema | None | None | Consider explicit v2 taxonomy columns later |
| `block_types.tsv` | 1 | 10 | Yes | None | None | None | None |
| `block_size_spawn_rules.tsv` | 8 | 16 | Yes | None | None | None | None |
| `block_material_size_weight_rules.tsv` | 88 | 21 | Yes | None | None | None | None |
| `stage_days.tsv` | 30 | 10 | Yes | None | None | None | None |

Additional header notes:

- `TsvValidationService._validate_headers()` checks duplicate headers and missing required headers, but does not reject extra headers or enforce order. The current files nevertheless match the schema order.
- Attack module canonical projectile columns are present: `spread_angle`, `pierce_count`, `is_hitscan`, `projectile_visual_size_x`, `projectile_visual_size_y`.
- Removed/legacy attack columns are absent from `attack_module_items.tsv`: `damage_multiplier`, `projectile_spread_degrees`, `projectile_pierce_count`, `projectile_hit_scan`, `projectile_size`.
- `effect_damage_multiplier` remains only in function/enhance effect columns and maps to `effect_values.damage_multiplier`; this is separate from the removed attack-module direct field.

## C. Field Mapping

| TSV column or group | Resource field | Importer assignment | Exporter assignment | Validator | Missing? |
| --- | --- | --- | --- | --- | --- |
| Attack common: `item_id`, `name`, `item_category`, `rank`, `price_gold`, `shop_enabled`, `shop_spawn_weight`, `stackable`, `max_stack`, `equip_slot`, `is_equippable`, `icon_path`, `short_desc`, `desc`, `tags` | `ShopItemDefinition` common fields | `_build_attack_module_item_definition()` -> `apply_dictionary()` | `_build_common_item_row()` | `_validate_item_rows()` | No |
| `default_start_module`, `module_type`, `attack_style`, `effect_style`, `base_shape_units_x/y`, `range_growth_*`, `hit_shape`, `range_units`, `range_width_u`, `range_height_u` | `ShopItemDefinition` attack/style fields | `_build_attack_module_item_definition()` + `AttackModuleStyleResolver` normalization | `_build_attack_module_item_row()` | `_validate_item_rows()` | No |
| `module_base_damage` | `ShopItemDefinition.module_base_damage` | `_build_attack_module_item_definition()` | `_build_attack_module_item_row()` | Required int | No |
| `base_damage_D/C/B/A/S` | `ShopItemDefinition.base_damage_by_grade` dictionary | `_build_base_damage_by_grade()` | `_build_attack_module_item_row()` | Required int per grade | No |
| `attack_speed_multiplier` | `ShopItemDefinition.attack_speed_multiplier` | `_build_attack_module_item_definition()` | `_build_attack_module_item_row()` | Required float | No |
| `projectile_count`, `spread_angle`, `pierce_count`, `projectile_speed`, `projectile_lifetime`, `projectile_max_distance`, `projectile_visual_size_x/y`, `is_hitscan`, `projectile_homing` | `ShopItemDefinition` projectile fields | `_build_attack_module_item_definition()` -> `apply_dictionary()` | `_build_attack_module_item_row()` | Optional typed reads except required world scene path | No |
| `mechanic_drone_count`, `mechanic_targeting`, `world_visual_scene_path` | `ShopItemDefinition` mechanic/visual fields | `_build_attack_module_item_definition()` | `_build_attack_module_item_row()` | `world_visual_scene_path` required | No |
| `block_materials.tsv` all 16 columns | `BlockMaterialData` fields | `BlockDataImporter.import_from_directory()` material loop | `_build_block_material_rows()` | `validate_block_catalog()` | No |
| `max_allowed_area`, `max_allowed_width`, `max_allowed_height` | `BlockMaterialData.max_allowed_*` | Imported and exported | Exported | Required ints | No; live v1 still uses these gates |
| `block_sizes.tsv` all 13 columns | `BlockSizeData` fields | `BlockDataImporter` size loop | `_build_block_size_rows()` | `validate_block_catalog()` | No |
| Explicit size taxonomy/pressure columns | None in current `block_sizes.tsv` / `BlockSizeData` | Not imported | Not exported from `block_sizes.tsv` | Not validated | Yes by design; v2 derives taxonomy in simulator/export defaults |
| `block_types.tsv` all 10 columns | `BlockTypeDefinition` fields | `BlockDataImporter` type loop | `_build_block_type_rows()` | `validate_block_catalog()` | No |
| `block_size_spawn_rules.tsv` all 16 columns | `BlockSizeSpawnRuleData` fields | `BlockDataImporter` size rule loop and `_assign_spawn_rule_multipliers()` | `_serialize_size_spawn_rule()` | `validate_block_catalog()`, `validate_spawn_v2_rules()` | No |
| `block_material_size_weight_rules.tsv` all 21 columns | `BlockMaterialSizeWeightRuleData` fields | `BlockDataImporter` material-size rule loop and `_assign_spawn_rule_multipliers()` | `_serialize_material_size_weight_rule()` | `validate_block_catalog()`, `validate_spawn_v2_rules()` | No |
| `stage_days.tsv` all 10 columns | `StageDayDefinition` fields | `_convert_stage_table()` | `_build_stage_day_rows()` | `validate_stage_table()` | No |

## D. TSV vs Current TRES Diff Summary

Method: exported current `.tres` files to `_tmp_tsv_export` using `export_tsv`, then compared requested TSVs.

| Area | Match? | Difference count | Meaningful difference | Ignorable difference | Action |
| --- | --- | ---: | --- | --- | --- |
| Attack modules | Yes | 0 | None | None | None |
| Block materials | Yes | 0 | None | None | None |
| Block sizes | Yes | 0 | None | None | None |
| Block types | Yes | 0 | None | None | None |
| Stage days | Yes | 0 | None | None | None |
| v2 size spawn rules | No | 8 data rows differ from export | Current `BlockCatalog.tres` has no persisted v2 rule array, so export service derives default rows; TSV contains tuned simulation rows for `size_1x3`, `size_1x4`, `size_4x1` and custom notes | Note text differences are secondary | Convert and commit `BlockCatalog.tres` before treating `.tres` as v2 rule source |
| v2 material-size weight rules | No | 88 note rows differ from export; multiplier values match observed default policy | Current `BlockCatalog.tres` has no persisted v2 rule array, so export service derives rows | Most differences are note wording | Same as above |

Current runtime implication:

- v1 live spawn does not use the v2 rule arrays, so the missing v2 arrays in current `BlockCatalog.tres` do not affect live v1.
- `BlockSpawnV2Simulator.gd` calls `load_rules_from_directory()` and reads the two v2 TSVs directly, so current v2 snapshots use TSV rule data even though `BlockCatalog.tres` lacks those arrays.
- If the future plan is to make `.tres` the canonical v2 rule runtime source, `BlockCatalog.tres` must be regenerated from TSV and committed.

## E. Conversion Execution Result

Safe execution procedure:

1. Backed up current runtime files to `_tmp_tres_backup/`.
2. Ran:
   `Godot_v4.6.1-stable_win64.exe --headless --log-file godot_tsv_convert_audit.log --path . --script scripts/tools/data_pipeline/DataPipelineCli.gd -- convert_tsv --input_dir=res://data_tsv`
3. Verified generated output.
4. Ran headless load and snapshot scripts against the converted files.
5. Restored the original `.tres` files from backup.

| Command / check | Success | Generated or modified during temporary conversion | Main diff | Error / warning |
| --- | --- | --- | --- | --- |
| `convert_tsv --input_dir=res://data_tsv` | Yes | `data/blocks/BlockCatalog.tres`, `data/stages/StageTable.tres`, `data/items/ShopItemCatalog.tres` | `ShopItemCatalog.tres` unchanged vs backup; `StageTable.tres` unchanged vs backup; `BlockCatalog.tres` gains 8 `BlockSizeSpawnRuleData` and 88 `BlockMaterialSizeWeightRuleData` subresources | Godot local warnings: root certificate store, `user://profile.save` write |
| Converted `.tres` load | Yes | None beyond temporary conversion | Loaded successfully | Same local warnings |
| Restore from backup | Yes | Restored original three `.tres` files exactly | Hash matched backup after restore | None |

Important: the temporary conversion was not left in the workspace. The original `.tres` files were restored byte-for-byte from the audit backup.

## F. Snapshot Verification Result

| Check | Result | Notes |
| --- | --- | --- |
| `scripts/tests/attack_module_dps_snapshot.gd` | Exit 0 | Regenerated `docs/reports/attack_module_dps_snapshot.md`; DPS matrix still uses `base_damage_by_grade` and no grade damage multiplier |
| `scripts/tests/balance_snapshot.gd` | Exit 0 | Completed under converted `.tres` state; no live resolver switch occurred |
| `scripts/tests/spawn_distribution_snapshot.gd` | Exit 0 | Regenerated `docs/reports/spawn_distribution_snapshot.md`; report explicitly marks v2 as simulation-only |
| Godot headless project load | Exit 0 | Project loaded with converted `.tres`; same local warnings |
| `git diff --check` | Exit 0 | No whitespace errors |

The Godot warnings observed in each run were local environment warnings already seen elsewhere:

- `Failed to read the root certificate store.`
- `Failed to open save file for writing: user://profile.save`

They did not cause nonzero exit codes.

## G. Findings and Priority

| Priority | Finding | Impact | Recommended action |
| --- | --- | --- | --- |
| P0 | None | No import failure or runtime load break found | None |
| P1 | Current `BlockCatalog.tres` does not persist v2 rule arrays, while TSV and importer support them | If future runtime expects v2 rules from `.tres`, the current `.tres` is incomplete | When ready, run `convert_tsv` and commit regenerated `BlockCatalog.tres`; do not switch live resolver yet |
| P1 | v2 simulator reads `block_size_spawn_rules.tsv` and `block_material_size_weight_rules.tsv` directly | TSV is currently the simulation source of truth, not `.tres` | Keep documented until v2 runtime source is finalized |
| P2 | `block_sizes.tsv` does not carry explicit `sand_multiplier`, `horizontal_pressure_score`, `vertical_pressure_score`, `width_group`, `height_group`, `area_group`, `size_group` | Current v2 taxonomy is derived in `BlockSpawnV2Simulator`/export defaults, not editable in `block_sizes.tsv` | Add explicit columns only when size taxonomy becomes production data |
| P3 | `block_materials.tsv` still includes `max_allowed_area/width/height` | Expected legacy state for v1 live spawn; conflicts with long-term Spawn Pool design | Keep until v2 live migration; mark deprecated in future schema/docs |
| P4 | Header validation does not reject extra columns or order mismatch | Current headers are fine, but future accidental extra columns may pass validation | Consider stricter validation mode after pipeline stabilizes |
| P4 | `TsvIo.write_rows()` trims trailing empty cells in data rows | Read path pads missing cells, so this is mostly cosmetic | No urgent action |

## Final Judgment

The current TSV to TRES pipeline is valid for live v1 data and can successfully import the new v2 rule files. The pipeline is not yet fully source-of-truth consistent for v2 because current `BlockCatalog.tres` has no persisted v2 rule arrays after restoring the audit conversion. This is acceptable while v2 remains simulation-only and the simulator reads TSV directly, but it must be resolved before using `.tres` as the v2 runtime rule source.

Live v1 spawning is unchanged:

- `GameData.resolve_random_block_definition()` still calls `BlockSpawnResolver.resolve_random_block()`.
- `BlockSpawnResolver.resolve_random_block()` still samples `BlockCatalog.get_spawn_candidates()`.
- `BlockCatalog.get_spawn_candidates()` still applies current material/size v1 gating, including `max_allowed_*`.

v2 remains simulation-only:

- `BlockSpawnV2Simulator.gd` is only referenced by `scripts/tests/spawn_distribution_snapshot.gd`.
- v2 ignores material `max_allowed_*` in its simulation size filtering, as designed.
- No live resolver path was switched during this audit.
