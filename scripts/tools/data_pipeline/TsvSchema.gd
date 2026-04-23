extends RefCounted
class_name TsvSchema

const DEFAULT_TSV_DIR := "res://data_tsv"

const BLOCK_CATALOG_TRES_PATH := "res://data/blocks/BlockCatalog.tres"
const STAGE_TABLE_TRES_PATH := "res://data/stages/StageTable.tres"
const SHOP_ITEM_CATALOG_TRES_PATH := "res://data/items/ShopItemCatalog.tres"

const BLOCK_CATALOG_META_FILE := "block_catalog_meta.tsv"
const BLOCK_MATERIALS_FILE := "block_materials.tsv"
const BLOCK_SIZES_FILE := "block_sizes.tsv"
const BLOCK_TYPES_FILE := "block_types.tsv"
const STAGE_DAYS_FILE := "stage_days.tsv"
const ATTACK_MODULE_ITEMS_FILE := "attack_module_items.tsv"
const FUNCTION_MODULE_ITEMS_FILE := "function_module_items.tsv"
const ENHANCE_MODULE_ITEMS_FILE := "enhance_module_items.tsv"

const BLOCK_CATALOG_META_HEADERS := [
	"default_material_id",
	"default_size_id",
	"random_type_chance",
]

const BLOCK_MATERIAL_HEADERS := [
	"material_id",
	"display_name",
	"hp_multiplier",
	"reward_multiplier",
	"base_spawn_weight",
	"special_result_type",
	"color_key",
	"block_color",
	"min_difficulty",
	"min_stage",
	"max_stage",
	"max_allowed_area",
	"max_allowed_width",
	"max_allowed_height",
	"is_enabled",
	"notes",
]

const BLOCK_SIZE_HEADERS := [
	"size_id",
	"width_u",
	"height_u",
	"area",
	"hp_multiplier",
	"reward_multiplier",
	"base_spawn_weight",
	"min_difficulty",
	"min_stage",
	"max_stage",
	"is_enabled",
	"tags",
	"notes",
]

const BLOCK_TYPE_HEADERS := [
	"id",
	"display_name",
	"name_prefix",
	"name_suffix",
	"can_spawn_randomly",
	"spawn_weight_multiplier",
	"hp_multiplier",
	"reward_multiplier",
	"sand_units_multiplier",
	"special_result_override",
]

const STAGE_DAY_HEADERS := [
	"day_number",
	"day_type",
	"duration",
	"block_hp_multiplier",
	"boss_block_base_id",
	"boss_block_size_id",
	"boss_block_type_id",
	"spawn_interval_multiplier",
	"reward_multiplier",
	"special_rules",
]

const ITEM_COMMON_HEADERS := [
	"item_id",
	"name",
	"item_category",
	"rank",
	"price_gold",
	"shop_enabled",
	"shop_spawn_weight",
	"stackable",
	"max_stack",
	"equip_slot",
	"is_equippable",
	"icon_path",
	"short_desc",
	"desc",
	"tags",
]

const EFFECT_HEADERS := [
	"effect_damage_multiplier",
	"effect_sand_remove_interval_sec",
	"effect_sand_remove_count",
	"effect_tick_interval_sec",
	"effect_radius_u",
	"effect_attack_damage_flat",
	"effect_attack_speed_percent",
	"effect_attack_range_percent",
	"effect_max_hp_flat",
	"effect_defense_flat",
	"effect_hp_regen_flat",
	"effect_max_weight_flat",
	"effect_mining_damage_flat",
	"effect_mining_speed_percent",
	"effect_mining_range_percent",
	"effect_move_speed_percent",
	"effect_move_speed_flat",
	"effect_jump_power_percent",
	"effect_jump_power_flat",
	"effect_crit_chance_flat",
	"effect_luck_flat",
	"effect_interest_rate_percent",
	"effect_battery_recovery_flat",
]

const EFFECT_COLUMN_TO_KEY := {
	"effect_damage_multiplier": "damage_multiplier",
	"effect_sand_remove_interval_sec": "sand_remove_interval_sec",
	"effect_sand_remove_count": "sand_remove_count",
	"effect_tick_interval_sec": "tick_interval_sec",
	"effect_radius_u": "radius_u",
	"effect_attack_damage_flat": "attack_damage_flat",
	"effect_attack_speed_percent": "attack_speed_percent",
	"effect_attack_range_percent": "attack_range_percent",
	"effect_max_hp_flat": "max_hp_flat",
	"effect_defense_flat": "defense_flat",
	"effect_hp_regen_flat": "hp_regen_flat",
	"effect_max_weight_flat": "max_weight_flat",
	"effect_mining_damage_flat": "mining_damage_flat",
	"effect_mining_speed_percent": "mining_speed_percent",
	"effect_mining_range_percent": "mining_range_percent",
	"effect_move_speed_percent": "move_speed_percent",
	"effect_move_speed_flat": "move_speed_flat",
	"effect_jump_power_percent": "jump_power_percent",
	"effect_jump_power_flat": "jump_power_flat",
	"effect_crit_chance_flat": "crit_chance_flat",
	"effect_luck_flat": "luck_flat",
	"effect_interest_rate_percent": "interest_rate_percent",
	"effect_battery_recovery_flat": "battery_recovery_flat",
}


static func get_attack_module_item_headers() -> Array:
	var headers := ITEM_COMMON_HEADERS.duplicate()
	headers.append_array([
		"default_start_module",
		"module_type",
		"attack_style",
		"range_width_u",
		"range_height_u",
		"damage_multiplier",
		"attack_speed_multiplier",
		"projectile_count",
		"projectile_spread_degrees",
		"projectile_pierce_count",
		"projectile_speed",
		"projectile_lifetime",
		"projectile_max_distance",
		"projectile_size_x",
		"projectile_size_y",
		"projectile_hit_scan",
		"projectile_homing",
		"mechanic_drone_count",
		"mechanic_targeting",
		"world_visual_scene_path",
	])
	return headers


static func get_function_module_item_headers() -> Array:
	var headers := ITEM_COMMON_HEADERS.duplicate()
	headers.append("effect_type")
	headers.append_array(EFFECT_HEADERS)
	return headers


static func get_enhance_module_item_headers() -> Array:
	return get_function_module_item_headers()


static func get_all_tsv_files() -> Array[String]:
	return [
		BLOCK_CATALOG_META_FILE,
		BLOCK_MATERIALS_FILE,
		BLOCK_SIZES_FILE,
		BLOCK_TYPES_FILE,
		STAGE_DAYS_FILE,
		ATTACK_MODULE_ITEMS_FILE,
		FUNCTION_MODULE_ITEMS_FILE,
		ENHANCE_MODULE_ITEMS_FILE,
	]


static func join_list(values: Array) -> String:
	var text_values: Array[String] = []
	for value in values:
		var text := str(value)
		if text.is_empty():
			continue
		text_values.append(text)
	return "|".join(text_values)


static func split_list(value: String) -> PackedStringArray:
	if value.is_empty():
		return PackedStringArray()
	return PackedStringArray(value.split("|", false))
