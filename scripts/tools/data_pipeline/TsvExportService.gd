extends RefCounted
class_name TsvExportService

const TSV_SCHEMA = preload("res://scripts/tools/data_pipeline/TsvSchema.gd")
const TSV_IO_SCRIPT = preload("res://scripts/tools/data_pipeline/TsvIo.gd")
const BLOCK_CATALOG_PATH := TSV_SCHEMA.BLOCK_CATALOG_TRES_PATH
const STAGE_TABLE_PATH := TSV_SCHEMA.STAGE_TABLE_TRES_PATH
const SHOP_ITEM_CATALOG_SCRIPT = preload("res://scripts/data/ShopItemCatalog.gd")

var _io = TSV_IO_SCRIPT.new()


func export_all_catalogs(output_dir: String = TSV_SCHEMA.DEFAULT_TSV_DIR) -> Dictionary:
	var errors: Array[String] = []
	var written_files: Array[String] = []

	_write_table(output_dir, TSV_SCHEMA.BLOCK_CATALOG_META_FILE, TSV_SCHEMA.BLOCK_CATALOG_META_HEADERS, [_build_block_catalog_meta_row()], written_files, errors)
	_write_table(output_dir, TSV_SCHEMA.BLOCK_MATERIALS_FILE, TSV_SCHEMA.BLOCK_MATERIAL_HEADERS, _build_block_material_rows(), written_files, errors)
	_write_table(output_dir, TSV_SCHEMA.BLOCK_SIZES_FILE, TSV_SCHEMA.BLOCK_SIZE_HEADERS, _build_block_size_rows(), written_files, errors)
	_write_table(output_dir, TSV_SCHEMA.BLOCK_TYPES_FILE, TSV_SCHEMA.BLOCK_TYPE_HEADERS, _build_block_type_rows(), written_files, errors)
	_write_table(output_dir, TSV_SCHEMA.BLOCK_SIZE_SPAWN_RULES_FILE, TSV_SCHEMA.BLOCK_SIZE_SPAWN_RULE_HEADERS, _build_block_size_spawn_rule_rows(), written_files, errors)
	_write_table(output_dir, TSV_SCHEMA.BLOCK_MATERIAL_SIZE_WEIGHT_RULES_FILE, TSV_SCHEMA.BLOCK_MATERIAL_SIZE_WEIGHT_RULE_HEADERS, _build_block_material_size_weight_rule_rows(), written_files, errors)
	_write_table(output_dir, TSV_SCHEMA.STAGE_DAYS_FILE, TSV_SCHEMA.STAGE_DAY_HEADERS, _build_stage_day_rows(), written_files, errors)

	var split_items := _build_shop_item_rows_by_category()
	_write_table(output_dir, TSV_SCHEMA.ATTACK_MODULE_ITEMS_FILE, TSV_SCHEMA.get_attack_module_item_headers(), split_items["attack_module"], written_files, errors)
	_write_table(output_dir, TSV_SCHEMA.FUNCTION_MODULE_ITEMS_FILE, TSV_SCHEMA.get_function_module_item_headers(), split_items["function_module"], written_files, errors)
	_write_table(output_dir, TSV_SCHEMA.ENHANCE_MODULE_ITEMS_FILE, TSV_SCHEMA.get_enhance_module_item_headers(), split_items["enhance_module"], written_files, errors)

	return {
		"ok": errors.is_empty(),
		"errors": errors,
		"written_files": written_files,
	}


func _build_block_catalog_meta_row() -> Dictionary:
	var catalog = load(BLOCK_CATALOG_PATH)
	return {
		"default_material_id": str(catalog.default_block_base_id),
		"default_size_id": str(catalog.default_block_size_id),
		"random_type_chance": float(catalog.random_type_chance),
	}


func _build_block_material_rows() -> Array[Dictionary]:
	var catalog = load(BLOCK_CATALOG_PATH)
	var rows: Array[Dictionary] = []
	for raw_definition in catalog.block_materials:
		var definition = raw_definition
		if definition == null:
			continue
		rows.append({
			"material_id": str(definition.material_id),
			"display_name": str(definition.display_name),
			"hp_multiplier": float(definition.hp_multiplier),
			"reward_multiplier": float(definition.reward_multiplier),
			"base_spawn_weight": float(definition.base_spawn_weight),
			"special_result_type": str(definition.special_result_type),
			"color_key": str(definition.color_key),
			"block_color": "#%s" % definition.block_color.to_html(true),
			"min_difficulty": str(definition.min_difficulty),
			"min_stage": int(definition.min_stage),
			"max_stage": int(definition.max_stage),
			"max_allowed_area": int(definition.max_allowed_area),
			"max_allowed_width": int(definition.max_allowed_width),
			"max_allowed_height": int(definition.max_allowed_height),
			"is_enabled": bool(definition.is_enabled),
			"notes": str(definition.notes),
		})
	return rows


func _build_block_size_rows() -> Array[Dictionary]:
	var catalog = load(BLOCK_CATALOG_PATH)
	var rows: Array[Dictionary] = []
	for raw_definition in catalog.block_sizes:
		var definition = raw_definition
		if definition == null:
			continue
		rows.append({
			"size_id": str(definition.size_id),
			"width_u": int(definition.width_u),
			"height_u": int(definition.height_u),
			"area": int(definition.area),
			"hp_multiplier": float(definition.hp_multiplier),
			"reward_multiplier": float(definition.reward_multiplier),
			"base_spawn_weight": float(definition.base_spawn_weight),
			"min_difficulty": str(definition.min_difficulty),
			"min_stage": int(definition.min_stage),
			"max_stage": int(definition.max_stage),
			"is_enabled": bool(definition.is_enabled),
			"tags": TSV_SCHEMA.join_list(Array(definition.tags)),
			"notes": str(definition.notes),
		})
	return rows


func _build_block_type_rows() -> Array[Dictionary]:
	var catalog = load(BLOCK_CATALOG_PATH)
	var rows: Array[Dictionary] = []
	for raw_definition in catalog.block_types:
		var definition = raw_definition
		if definition == null:
			continue
		rows.append({
			"id": str(definition.id),
			"display_name": str(definition.display_name),
			"name_prefix": str(definition.name_prefix),
			"name_suffix": str(definition.name_suffix),
			"can_spawn_randomly": bool(definition.can_spawn_randomly),
			"spawn_weight_multiplier": float(definition.spawn_weight_multiplier),
			"hp_multiplier": float(definition.hp_multiplier),
			"reward_multiplier": float(definition.reward_multiplier),
			"sand_units_multiplier": float(definition.sand_units_multiplier),
			"special_result_override": str(definition.special_result_override),
		})
	return rows


func _build_block_size_spawn_rule_rows() -> Array[Dictionary]:
	var catalog = load(BLOCK_CATALOG_PATH)
	var rows: Array[Dictionary] = []
	if not catalog.block_size_spawn_rules.is_empty():
		for raw_rule in catalog.block_size_spawn_rules:
			var rule = raw_rule
			if rule == null:
				continue
			rows.append(_serialize_size_spawn_rule(rule))
		return rows
	for raw_definition in catalog.block_sizes:
		var definition = raw_definition
		if definition == null:
			continue
		rows.append(_build_default_size_spawn_rule_row(definition))
	return rows


func _build_block_material_size_weight_rule_rows() -> Array[Dictionary]:
	var catalog = load(BLOCK_CATALOG_PATH)
	var rows: Array[Dictionary] = []
	if not catalog.block_material_size_weight_rules.is_empty():
		for raw_rule in catalog.block_material_size_weight_rules:
			var rule = raw_rule
			if rule == null:
				continue
			rows.append(_serialize_material_size_weight_rule(rule))
		return rows
	for raw_material in catalog.block_materials:
		var material = raw_material
		if material == null:
			continue
		var material_id := str(material.material_id)
		var policy := _get_default_material_group_policy(material_id)
		for size_group in _get_size_policy_groups():
			rows.append(_build_default_material_size_weight_rule_row(material_id, size_group, float(policy.get(size_group, 1.0))))
	return rows


func _serialize_size_spawn_rule(rule) -> Dictionary:
	return {
		"size_id": str(rule.size_id),
		"size_group": str(rule.size_group),
		"base_spawn_weight": float(rule.base_spawn_weight),
		"normal_multiplier": float(rule.normal_multiplier),
		"hard_multiplier": float(rule.hard_multiplier),
		"extreme_multiplier": float(rule.extreme_multiplier),
		"hell_multiplier": float(rule.hell_multiplier),
		"nightmare_multiplier": float(rule.nightmare_multiplier),
		"day_1_5_multiplier": float(rule.day_1_5_multiplier),
		"day_6_10_multiplier": float(rule.day_6_10_multiplier),
		"day_11_15_multiplier": float(rule.day_11_15_multiplier),
		"day_16_20_multiplier": float(rule.day_16_20_multiplier),
		"day_21_25_multiplier": float(rule.day_21_25_multiplier),
		"day_26_30_multiplier": float(rule.day_26_30_multiplier),
		"min_day_hint": int(rule.min_day_hint),
		"notes": str(rule.notes),
	}


func _serialize_material_size_weight_rule(rule) -> Dictionary:
	return {
		"rule_id": str(rule.rule_id),
		"material_id": str(rule.material_id),
		"size_id": str(rule.size_id),
		"size_group": str(rule.size_group),
		"area_group": str(rule.area_group),
		"width_group": str(rule.width_group),
		"height_group": str(rule.height_group),
		"weight_multiplier": float(rule.weight_multiplier),
		"normal_multiplier": float(rule.normal_multiplier),
		"hard_multiplier": float(rule.hard_multiplier),
		"extreme_multiplier": float(rule.extreme_multiplier),
		"hell_multiplier": float(rule.hell_multiplier),
		"nightmare_multiplier": float(rule.nightmare_multiplier),
		"day_1_5_multiplier": float(rule.day_1_5_multiplier),
		"day_6_10_multiplier": float(rule.day_6_10_multiplier),
		"day_11_15_multiplier": float(rule.day_11_15_multiplier),
		"day_16_20_multiplier": float(rule.day_16_20_multiplier),
		"day_21_25_multiplier": float(rule.day_21_25_multiplier),
		"day_26_30_multiplier": float(rule.day_26_30_multiplier),
		"min_day_hint": int(rule.min_day_hint),
		"notes": str(rule.notes),
	}


func _build_default_size_spawn_rule_row(definition) -> Dictionary:
	var width := int(definition.width_u)
	var height := int(definition.height_u)
	var area := width * height
	var size_group := _derive_size_group(width, height, area)
	var day_multipliers := _get_default_size_day_multipliers(size_group, width, height)
	var difficulty_multipliers := _get_default_size_difficulty_multipliers(size_group)
	return {
		"size_id": str(definition.size_id),
		"size_group": size_group,
		"base_spawn_weight": float(definition.base_spawn_weight),
		"normal_multiplier": float(difficulty_multipliers["normal"]),
		"hard_multiplier": float(difficulty_multipliers["hard"]),
		"extreme_multiplier": float(difficulty_multipliers["extreme"]),
		"hell_multiplier": float(difficulty_multipliers["hell"]),
		"nightmare_multiplier": float(difficulty_multipliers["nightmare"]),
		"day_1_5_multiplier": float(day_multipliers[0]),
		"day_6_10_multiplier": float(day_multipliers[1]),
		"day_11_15_multiplier": float(day_multipliers[2]),
		"day_16_20_multiplier": float(day_multipliers[3]),
		"day_21_25_multiplier": float(day_multipliers[4]),
		"day_26_30_multiplier": float(day_multipliers[5]),
		"min_day_hint": _get_default_size_min_day_hint(size_group, width, height),
		"notes": "v2 simulation rule; size min_stage/min_difficulty are not hard gates here.",
	}


func _build_default_material_size_weight_rule_row(material_id: String, size_group: String, multiplier: float) -> Dictionary:
	return {
		"rule_id": "%s_%s" % [material_id, size_group],
		"material_id": material_id,
		"size_id": "",
		"size_group": size_group,
		"area_group": "",
		"width_group": "",
		"height_group": "",
		"weight_multiplier": multiplier,
		"normal_multiplier": 1.0,
		"hard_multiplier": 1.0,
		"extreme_multiplier": 1.0,
		"hell_multiplier": 1.0,
		"nightmare_multiplier": 1.0,
		"day_1_5_multiplier": 1.0,
		"day_6_10_multiplier": 1.0,
		"day_11_15_multiplier": 1.0,
		"day_16_20_multiplier": 1.0,
		"day_21_25_multiplier": 1.0,
		"day_26_30_multiplier": 1.0,
		"min_day_hint": 1,
		"notes": "v2 simulation affinity multiplier; never hard-blocks a size.",
	}


func _derive_size_group(width: int, height: int, area: int) -> String:
	if width == 1 and height == 1:
		return "tiny"
	if height > 3 or width >= 9 or area >= 21:
		return "event_like"
	if area >= 13:
		return "huge"
	if width >= 7:
		return "wide_large"
	if height == 3 and width <= 1:
		return "tall_small"
	if height == 3 and width <= 3:
		return "tall_medium"
	if width >= 5 and height == 1:
		return "wide_medium"
	if width >= 5:
		return "large"
	if width >= 3 and height == 1:
		return "wide_small"
	if height >= 2 and width == 1:
		return "tall_small"
	if area <= 2:
		return "small"
	if area <= 6:
		return "medium"
	if area <= 12:
		return "large"
	return "huge"


func _get_default_size_day_multipliers(size_group: String, width: int, height: int) -> Array[float]:
	if height > 3:
		return [0.001, 0.001, 0.001, 0.003, 0.005, 0.005]
	match size_group:
		"tiny", "small", "tall_small":
			return [1.0, 1.0, 0.95, 0.9, 0.85, 0.8]
		"medium", "tall_medium":
			return [0.15, 0.4, 0.75, 1.0, 1.0, 1.0]
		"wide_small":
			return [0.03, 0.12, 0.35, 0.65, 0.85, 1.0]
		"wide_medium":
			return [0.005, 0.02, 0.08, 0.18, 0.35, 0.5]
		"wide_large":
			return [0.001, 0.003, 0.008, 0.02, 0.05, 0.08]
		"large":
			return [0.001, 0.008, 0.03, 0.08, 0.18, 0.3]
		"huge":
			return [0.001, 0.001, 0.003, 0.008, 0.02, 0.04]
		"event_like":
			return [0.001, 0.001, 0.001, 0.003, 0.005, 0.008]
		_:
			return [1.0, 1.0, 1.0, 1.0, 1.0, 1.0]


func _get_default_size_difficulty_multipliers(size_group: String) -> Dictionary:
	match size_group:
		"tiny", "small", "tall_small":
			return {"normal": 1.0, "hard": 0.95, "extreme": 0.9, "hell": 0.85, "nightmare": 0.8}
		"medium", "tall_medium":
			return {"normal": 1.0, "hard": 1.2, "extreme": 1.35, "hell": 1.5, "nightmare": 1.7}
		"wide_small":
			return {"normal": 1.0, "hard": 1.35, "extreme": 1.65, "hell": 1.9, "nightmare": 2.2}
		"wide_medium", "wide_large":
			return {"normal": 1.0, "hard": 1.6, "extreme": 2.0, "hell": 2.4, "nightmare": 2.8}
		"large", "huge", "event_like":
			return {"normal": 1.0, "hard": 1.8, "extreme": 2.4, "hell": 3.0, "nightmare": 3.6}
		_:
			return {"normal": 1.0, "hard": 1.0, "extreme": 1.0, "hell": 1.0, "nightmare": 1.0}


func _get_default_size_min_day_hint(size_group: String, width: int, height: int) -> int:
	if height > 3:
		return 0
	match size_group:
		"tiny", "small", "tall_small":
			return 1
		"medium", "tall_medium":
			return 6
		"wide_small":
			return 11
		"wide_medium":
			return 16
		"wide_large", "large":
			return 21
		"huge", "event_like":
			return 26
		_:
			return 1


func _get_size_policy_groups() -> Array[String]:
	return [
		"tiny",
		"small",
		"medium",
		"wide_small",
		"wide_medium",
		"wide_large",
		"tall_small",
		"tall_medium",
		"large",
		"huge",
		"event_like",
	]


func _get_default_material_group_policy(material_id: String) -> Dictionary:
	var default_policy := {
		"tiny": 1.0,
		"small": 1.0,
		"medium": 1.0,
		"wide_small": 1.0,
		"wide_medium": 1.0,
		"wide_large": 0.2,
		"tall_small": 1.0,
		"tall_medium": 0.75,
		"large": 0.45,
		"huge": 0.1,
		"event_like": 0.02,
	}
	var policies := {
		"wood": {"tiny": 1.0, "small": 1.0, "medium": 1.0, "wide_small": 1.0, "wide_medium": 1.0, "wide_large": 0.35, "tall_small": 0.9, "tall_medium": 0.75, "large": 0.45, "huge": 0.12, "event_like": 0.02},
		"rock": {"tiny": 1.0, "small": 1.0, "medium": 0.95, "wide_small": 0.75, "wide_medium": 0.55, "wide_large": 0.25, "tall_small": 0.9, "tall_medium": 0.7, "large": 0.55, "huge": 0.18, "event_like": 0.03},
		"marble": {"tiny": 1.0, "small": 1.0, "medium": 1.05, "wide_small": 0.65, "wide_medium": 0.4, "wide_large": 0.18, "tall_small": 0.75, "tall_medium": 0.55, "large": 0.35, "huge": 0.1, "event_like": 0.02},
		"cement": {"tiny": 0.9, "small": 0.9, "medium": 1.0, "wide_small": 1.1, "wide_medium": 1.1, "wide_large": 0.45, "tall_small": 0.9, "tall_medium": 0.75, "large": 0.75, "huge": 0.25, "event_like": 0.05},
		"steel": {"tiny": 0.8, "small": 0.8, "medium": 1.0, "wide_small": 1.3, "wide_medium": 1.3, "wide_large": 0.75, "tall_small": 0.65, "tall_medium": 0.5, "large": 0.9, "huge": 0.35, "event_like": 0.08},
		"bomb": {"tiny": 0.8, "small": 0.8, "medium": 0.15, "wide_small": 0.08, "wide_medium": 0.04, "wide_large": 0.02, "tall_small": 0.1, "tall_medium": 0.06, "large": 0.03, "huge": 0.005, "event_like": 0.001},
		"glass": {"tiny": 1.0, "small": 1.0, "medium": 0.8, "wide_small": 0.45, "wide_medium": 0.25, "wide_large": 0.08, "tall_small": 0.45, "tall_medium": 0.3, "large": 0.15, "huge": 0.02, "event_like": 0.005},
		"gold": {"tiny": 1.0, "small": 1.0, "medium": 0.45, "wide_small": 0.12, "wide_medium": 0.08, "wide_large": 0.03, "tall_small": 0.18, "tall_medium": 0.1, "large": 0.05, "huge": 0.005, "event_like": 0.001},
	}
	return policies.get(material_id, default_policy)


func _build_stage_day_rows() -> Array[Dictionary]:
	var stage_table = load(STAGE_TABLE_PATH)
	var rows: Array[Dictionary] = []
	for raw_definition in stage_table.days:
		var definition = raw_definition
		if definition == null:
			continue
		rows.append({
			"day_number": int(definition.day_number),
			"day_type": str(definition.day_type),
			"duration": float(definition.duration),
			"block_hp_multiplier": float(definition.block_hp_multiplier),
			"boss_block_base_id": str(definition.boss_block_base_id),
			"boss_block_size_id": str(definition.boss_block_size_id),
			"boss_block_type_id": str(definition.boss_block_type_id),
			"spawn_interval_multiplier": float(definition.spawn_interval_multiplier),
			"reward_multiplier": float(definition.reward_multiplier),
			"special_rules": TSV_SCHEMA.join_list(Array(definition.special_rules)),
		})
	return rows


func _build_shop_item_rows_by_category() -> Dictionary:
	var catalog = SHOP_ITEM_CATALOG_SCRIPT.new()
	var rows_by_category := {
		"attack_module": [],
		"function_module": [],
		"enhance_module": [],
	}
	for raw_definition in catalog.get_all_items():
		var definition: Dictionary = raw_definition
		var category := str(definition.get("item_category", ""))
		if not rows_by_category.has(category):
			continue
		match category:
			"attack_module":
				rows_by_category[category].append(_build_attack_module_item_row(definition))
			"function_module", "enhance_module":
				rows_by_category[category].append(_build_effect_item_row(definition))
	return rows_by_category


func _build_attack_module_item_row(definition: Dictionary) -> Dictionary:
	var row := _build_common_item_row(definition)
	row["default_start_module"] = bool(definition.get("default_start_module", false))
	row["module_type"] = str(definition.get("module_type", ""))
	row["attack_style"] = str(definition.get("attack_style", "slash"))
	row["effect_style"] = str(definition.get("effect_style", ""))
	row["base_shape_units_x"] = float(definition.get("base_shape_units_x", definition.get("range_width_u", 0.0)))
	row["base_shape_units_y"] = float(definition.get("base_shape_units_y", definition.get("range_height_u", 0.0)))
	row["range_growth_width_scale"] = float(definition.get("range_growth_width_scale", 1.0))
	row["range_growth_height_scale"] = float(definition.get("range_growth_height_scale", 0.1))
	row["hit_shape"] = str(definition.get("hit_shape", "rectangle"))
	row["range_units"] = float(definition.get("range_units", definition.get("range_width_u", 0.0)))
	row["range_growth_scale"] = float(definition.get("range_growth_scale", 1.0))
	row["range_width_u"] = float(definition.get("range_width_u", 0.0))
	row["range_height_u"] = float(definition.get("range_height_u", 0.0))
	row["module_base_damage"] = int(definition.get("module_base_damage", 0))
	var base_damage_by_grade: Dictionary = definition.get("base_damage_by_grade", {})
	for grade in TSV_SCHEMA.ATTACK_MODULE_BASE_DAMAGE_GRADES:
		row["base_damage_%s" % grade] = int(base_damage_by_grade.get(grade, 0))
	row["attack_speed_multiplier"] = float(definition.get("attack_speed_multiplier", 1.0))
	row["projectile_count"] = int(definition.get("projectile_count", 1))
	row["spread_angle"] = float(definition.get("spread_angle", 0.0))
	row["pierce_count"] = int(definition.get("pierce_count", 0))
	row["projectile_speed"] = float(definition.get("projectile_speed", 900.0))
	row["projectile_lifetime"] = float(definition.get("projectile_lifetime", 1.2))
	row["projectile_max_distance"] = float(definition.get("projectile_max_distance", 900.0))
	row["projectile_visual_size_x"] = float(definition.get("projectile_visual_size_x", 18.0))
	row["projectile_visual_size_y"] = float(definition.get("projectile_visual_size_y", 6.0))
	row["is_hitscan"] = bool(definition.get("is_hitscan", false))
	row["projectile_homing"] = bool(definition.get("projectile_homing", false))
	row["mechanic_drone_count"] = int(definition.get("mechanic_drone_count", 1))
	row["mechanic_targeting"] = str(definition.get("mechanic_targeting", "nearest"))
	row["world_visual_scene_path"] = str(definition.get("world_visual_scene_path", ""))
	return row


func _build_effect_item_row(definition: Dictionary) -> Dictionary:
	var row := _build_common_item_row(definition)
	var effect_type := str(definition.get("effect_type", ""))
	row["effect_type"] = effect_type
	var conditions: Array = definition.get("conditions", [])
	var effects: Array = definition.get("effects", [])
	if effect_type == "conditional_stat_bonus" or not conditions.is_empty():
		row["conditions_json"] = _stringify_json(conditions)
		row["effects_json"] = _stringify_json(effects)
		row["apply_timing"] = str(definition.get("apply_timing", ""))
	var effect_values: Dictionary = definition.get("effect_values", {})
	for effect_column in TSV_SCHEMA.EFFECT_HEADERS:
		var effect_key := str(TSV_SCHEMA.EFFECT_COLUMN_TO_KEY[effect_column])
		if effect_values.has(effect_key):
			row[effect_column] = effect_values[effect_key]
	return row


func _stringify_json(value: Variant) -> String:
	if value is Array:
		var array_value: Array = value
		if array_value.is_empty():
			return ""
	return JSON.stringify(value)


func _build_common_item_row(definition: Dictionary) -> Dictionary:
	return {
		"item_id": str(definition.get("item_id", "")),
		"name": str(definition.get("name", "")),
		"item_category": str(definition.get("item_category", "")),
		"rank": str(definition.get("rank", "D")),
		"price_gold": int(definition.get("price_gold", 100)),
		"shop_enabled": bool(definition.get("shop_enabled", true)),
		"shop_spawn_weight": float(definition.get("shop_spawn_weight", -1.0)),
		"stackable": bool(definition.get("stackable", false)),
		"max_stack": int(definition.get("max_stack", 1)),
		"equip_slot": str(definition.get("equip_slot", "")),
		"is_equippable": bool(definition.get("is_equippable", false)),
		"icon_path": str(definition.get("icon_path", "")),
		"short_desc": str(definition.get("short_desc", "")),
		"desc": str(definition.get("desc", "")),
		"tags": TSV_SCHEMA.join_list(Array(definition.get("tags", []))),
	}


func _write_table(output_dir: String, file_name: String, headers: Array, rows: Array, written_files: Array[String], errors: Array[String]) -> void:
	var file_path := _join_path(output_dir, file_name)
	var result := _io.write_rows(file_path, headers, rows)
	if not bool(result.get("ok", false)):
		for error_text in result.get("errors", []):
			errors.append(str(error_text))
		return
	written_files.append(str(result.get("path", file_path)))


func _join_path(base_dir: String, file_name: String) -> String:
	if base_dir.ends_with("/") or base_dir.ends_with("\\"):
		return "%s%s" % [base_dir, file_name]
	if "\\" in base_dir:
		return "%s\\%s" % [base_dir, file_name]
	return "%s/%s" % [base_dir, file_name]
