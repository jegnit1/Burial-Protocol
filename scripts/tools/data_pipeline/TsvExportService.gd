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
	row["range_width_u"] = float(definition.get("range_width_u", 0.0))
	row["range_height_u"] = float(definition.get("range_height_u", 0.0))
	row["damage_multiplier"] = float(definition.get("damage_multiplier", 1.0))
	row["attack_speed_multiplier"] = float(definition.get("attack_speed_multiplier", 1.0))
	row["projectile_count"] = int(definition.get("projectile_count", 1))
	row["projectile_spread_degrees"] = float(definition.get("projectile_spread_degrees", 0.0))
	row["projectile_pierce_count"] = int(definition.get("projectile_pierce_count", 0))
	row["projectile_speed"] = float(definition.get("projectile_speed", 900.0))
	row["projectile_lifetime"] = float(definition.get("projectile_lifetime", 1.2))
	row["projectile_max_distance"] = float(definition.get("projectile_max_distance", 900.0))
	row["projectile_size_x"] = float(definition.get("projectile_size_x", 18.0))
	row["projectile_size_y"] = float(definition.get("projectile_size_y", 6.0))
	row["projectile_hit_scan"] = bool(definition.get("projectile_hit_scan", false))
	row["projectile_homing"] = bool(definition.get("projectile_homing", false))
	row["mechanic_drone_count"] = int(definition.get("mechanic_drone_count", 1))
	row["mechanic_targeting"] = str(definition.get("mechanic_targeting", "nearest"))
	row["world_visual_scene_path"] = str(definition.get("world_visual_scene_path", ""))
	return row


func _build_effect_item_row(definition: Dictionary) -> Dictionary:
	var row := _build_common_item_row(definition)
	row["effect_type"] = str(definition.get("effect_type", ""))
	var effect_values: Dictionary = definition.get("effect_values", {})
	for effect_column in TSV_SCHEMA.EFFECT_HEADERS:
		var effect_key := str(TSV_SCHEMA.EFFECT_COLUMN_TO_KEY[effect_column])
		if effect_values.has(effect_key):
			row[effect_column] = effect_values[effect_key]
	return row


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
