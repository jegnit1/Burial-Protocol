extends RefCounted
class_name TsvToTresConverter

const TSV_SCHEMA = preload("res://scripts/tools/data_pipeline/TsvSchema.gd")
const TSV_IO_SCRIPT = preload("res://scripts/tools/data_pipeline/TsvIo.gd")
const TSV_VALIDATION_SERVICE_SCRIPT = preload("res://scripts/tools/data_pipeline/TsvValidationService.gd")
const BLOCK_DATA_IMPORTER_SCRIPT = preload("res://scripts/tools/data_pipeline/BlockDataImporter.gd")
const STAGE_TABLE_SCRIPT = preload("res://scripts/data/StageTable.gd")
const STAGE_DAY_DEFINITION_SCRIPT = preload("res://scripts/data/StageDayDefinition.gd")
const SHOP_ITEM_RESOURCE_CATALOG_SCRIPT = preload("res://scripts/data/ShopItemResourceCatalog.gd")
const SHOP_ITEM_DEFINITION_SCRIPT = preload("res://scripts/data/ShopItemDefinition.gd")

var _io = TSV_IO_SCRIPT.new()
var _validation = TSV_VALIDATION_SERVICE_SCRIPT.new()
var _block_importer = BLOCK_DATA_IMPORTER_SCRIPT.new()


func convert_all_from_directory(input_dir: String = TSV_SCHEMA.DEFAULT_TSV_DIR) -> Dictionary:
	var errors: Array[String] = []
	var written_paths: Array[String] = []

	_collect_result(convert_catalog_from_directory(input_dir, "block_catalog"), written_paths, errors)
	_collect_result(convert_catalog_from_directory(input_dir, "stage_table"), written_paths, errors)
	_collect_result(convert_catalog_from_directory(input_dir, "shop_item_catalog"), written_paths, errors)

	return {
		"ok": errors.is_empty(),
		"errors": errors,
		"written_paths": written_paths,
	}


func convert_catalog_from_directory(input_dir: String, catalog_name: String) -> Dictionary:
	match catalog_name:
		"block_catalog":
			return _convert_block_catalog(input_dir)
		"stage_table":
			return _convert_stage_table(input_dir)
		"shop_item_catalog", "item_catalog":
			return _convert_shop_item_catalog(input_dir)
		_:
			return {
				"ok": false,
				"errors": ["Unsupported TSV catalog: %s" % catalog_name],
				"written_paths": [],
			}


func _convert_block_catalog(input_dir: String) -> Dictionary:
	var import_result := _block_importer.import_from_directory(input_dir)
	if not bool(import_result.get("ok", false)):
		return {"ok": false, "errors": import_result.get("errors", []), "written_paths": []}
	return _save_resource(import_result["catalog"], TSV_SCHEMA.BLOCK_CATALOG_TRES_PATH)


func _convert_stage_table(input_dir: String) -> Dictionary:
	var day_result := _read_table(input_dir, TSV_SCHEMA.STAGE_DAYS_FILE)
	var errors := _merge_read_errors([day_result])
	if not errors.is_empty():
		return {"ok": false, "errors": errors, "written_paths": []}
	var validation := _validation.validate_stage_table(day_result["headers"], day_result["rows"])
	if not bool(validation.get("ok", false)):
		return {"ok": false, "errors": validation["errors"], "written_paths": []}

	var table = STAGE_TABLE_SCRIPT.new()
	var max_day_number := 0
	var default_day_duration := 0.0

	for row in day_result["rows"]:
		var definition = STAGE_DAY_DEFINITION_SCRIPT.new()
		definition.day_number = _validation.get_required_int(row, "day_number", TSV_SCHEMA.STAGE_DAYS_FILE, errors)
		definition.day_type = StringName(_validation.get_required_string(row, "day_type", TSV_SCHEMA.STAGE_DAYS_FILE, errors))
		definition.duration = _validation.get_required_float(row, "duration", TSV_SCHEMA.STAGE_DAYS_FILE, errors)
		definition.block_hp_multiplier = _validation.get_required_float(row, "block_hp_multiplier", TSV_SCHEMA.STAGE_DAYS_FILE, errors)
		definition.boss_block_base_id = StringName(_validation.get_optional_string(row, "boss_block_base_id"))
		definition.boss_block_size_id = StringName(_validation.get_optional_string(row, "boss_block_size_id"))
		definition.boss_block_type_id = StringName(_validation.get_optional_string(row, "boss_block_type_id"))
		definition.spawn_interval_multiplier = _validation.get_required_float(row, "spawn_interval_multiplier", TSV_SCHEMA.STAGE_DAYS_FILE, errors)
		definition.reward_multiplier = _validation.get_required_float(row, "reward_multiplier", TSV_SCHEMA.STAGE_DAYS_FILE, errors)
		definition.special_rules = _validation.get_string_list(row, "special_rules")
		table.days.append(definition)
		max_day_number = maxi(max_day_number, definition.day_number)
		if default_day_duration <= 0.0 and definition.duration > 0.0:
			default_day_duration = definition.duration

	table.total_days = max_day_number
	table.default_day_duration = default_day_duration if default_day_duration > 0.0 else 40.0

	if not errors.is_empty():
		return {"ok": false, "errors": errors, "written_paths": []}
	return _save_resource(table, TSV_SCHEMA.STAGE_TABLE_TRES_PATH)


func _convert_shop_item_catalog(input_dir: String) -> Dictionary:
	var attack_result := _read_table(input_dir, TSV_SCHEMA.ATTACK_MODULE_ITEMS_FILE)
	var function_result := _read_table(input_dir, TSV_SCHEMA.FUNCTION_MODULE_ITEMS_FILE)
	var enhance_result := _read_table(input_dir, TSV_SCHEMA.ENHANCE_MODULE_ITEMS_FILE)
	var errors := _merge_read_errors([attack_result, function_result, enhance_result])
	if not errors.is_empty():
		return {"ok": false, "errors": errors, "written_paths": []}
	var validation := _validation.validate_shop_item_catalog(
		attack_result["headers"],
		attack_result["rows"],
		function_result["headers"],
		function_result["rows"],
		enhance_result["headers"],
		enhance_result["rows"]
	)
	if not bool(validation.get("ok", false)):
		return {"ok": false, "errors": validation["errors"], "written_paths": []}

	var catalog = SHOP_ITEM_RESOURCE_CATALOG_SCRIPT.new()
	catalog.catalog_type = &"item_catalog"
	catalog.version = 1

	for row in attack_result["rows"]:
		catalog.items.append(_build_attack_module_item_definition(row, errors))
	for row in function_result["rows"]:
		catalog.items.append(_build_effect_item_definition(row, errors))
	for row in enhance_result["rows"]:
		catalog.items.append(_build_effect_item_definition(row, errors))

	if not errors.is_empty():
		return {"ok": false, "errors": errors, "written_paths": []}
	return _save_resource(catalog, TSV_SCHEMA.SHOP_ITEM_CATALOG_TRES_PATH)


func _build_attack_module_item_definition(row: Dictionary, errors: Array[String]):
	var definition = SHOP_ITEM_DEFINITION_SCRIPT.new()
	definition.apply_dictionary({
		"item_id": _validation.get_required_string(row, "item_id", TSV_SCHEMA.ATTACK_MODULE_ITEMS_FILE, errors),
		"name": _validation.get_required_string(row, "name", TSV_SCHEMA.ATTACK_MODULE_ITEMS_FILE, errors),
		"item_category": _validation.get_required_string(row, "item_category", TSV_SCHEMA.ATTACK_MODULE_ITEMS_FILE, errors),
		"rank": _validation.get_required_string(row, "rank", TSV_SCHEMA.ATTACK_MODULE_ITEMS_FILE, errors),
		"price_gold": _validation.get_required_int(row, "price_gold", TSV_SCHEMA.ATTACK_MODULE_ITEMS_FILE, errors),
		"shop_enabled": _validation.get_required_bool(row, "shop_enabled", TSV_SCHEMA.ATTACK_MODULE_ITEMS_FILE, errors),
		"shop_spawn_weight": _validation.get_required_float(row, "shop_spawn_weight", TSV_SCHEMA.ATTACK_MODULE_ITEMS_FILE, errors),
		"stackable": _validation.get_required_bool(row, "stackable", TSV_SCHEMA.ATTACK_MODULE_ITEMS_FILE, errors),
		"max_stack": _validation.get_required_int(row, "max_stack", TSV_SCHEMA.ATTACK_MODULE_ITEMS_FILE, errors),
		"equip_slot": _validation.get_optional_string(row, "equip_slot"),
		"is_equippable": _validation.get_required_bool(row, "is_equippable", TSV_SCHEMA.ATTACK_MODULE_ITEMS_FILE, errors),
		"default_start_module": _validation.get_required_bool(row, "default_start_module", TSV_SCHEMA.ATTACK_MODULE_ITEMS_FILE, errors),
		"icon_path": _validation.get_optional_string(row, "icon_path"),
		"short_desc": _validation.get_required_string(row, "short_desc", TSV_SCHEMA.ATTACK_MODULE_ITEMS_FILE, errors),
		"desc": _validation.get_required_string(row, "desc", TSV_SCHEMA.ATTACK_MODULE_ITEMS_FILE, errors),
		"tags": Array(_validation.get_string_list(row, "tags")),
		"module_type": _validation.get_required_string(row, "module_type", TSV_SCHEMA.ATTACK_MODULE_ITEMS_FILE, errors),
		"attack_style": _validation.get_optional_string(row, "attack_style"),
		"range_width_u": _validation.get_required_float(row, "range_width_u", TSV_SCHEMA.ATTACK_MODULE_ITEMS_FILE, errors),
		"range_height_u": _validation.get_required_float(row, "range_height_u", TSV_SCHEMA.ATTACK_MODULE_ITEMS_FILE, errors),
		"damage_multiplier": _validation.get_required_float(row, "damage_multiplier", TSV_SCHEMA.ATTACK_MODULE_ITEMS_FILE, errors),
		"attack_speed_multiplier": _validation.get_required_float(row, "attack_speed_multiplier", TSV_SCHEMA.ATTACK_MODULE_ITEMS_FILE, errors),
		"projectile_count": _validation.get_optional_int(row, "projectile_count", 1),
		"projectile_spread_degrees": _validation.get_optional_float(row, "projectile_spread_degrees", 0.0),
		"projectile_pierce_count": _validation.get_optional_int(row, "projectile_pierce_count", 0),
		"projectile_speed": _validation.get_optional_float(row, "projectile_speed", 900.0),
		"projectile_lifetime": _validation.get_optional_float(row, "projectile_lifetime", 1.2),
		"projectile_max_distance": _validation.get_optional_float(row, "projectile_max_distance", 900.0),
		"projectile_size_x": _validation.get_optional_float(row, "projectile_size_x", 18.0),
		"projectile_size_y": _validation.get_optional_float(row, "projectile_size_y", 6.0),
		"projectile_hit_scan": _validation.get_optional_bool(row, "projectile_hit_scan", false),
		"projectile_homing": _validation.get_optional_bool(row, "projectile_homing", false),
		"mechanic_drone_count": _validation.get_optional_int(row, "mechanic_drone_count", 1),
		"mechanic_targeting": _validation.get_optional_string(row, "mechanic_targeting"),
		"world_visual_scene_path": _validation.get_required_string(row, "world_visual_scene_path", TSV_SCHEMA.ATTACK_MODULE_ITEMS_FILE, errors),
	})
	return definition


func _build_effect_item_definition(row: Dictionary, errors: Array[String]):
	var file_label := TSV_SCHEMA.FUNCTION_MODULE_ITEMS_FILE
	var item_category := _validation.get_required_string(row, "item_category", file_label, errors)
	if item_category == "enhance_module":
		file_label = TSV_SCHEMA.ENHANCE_MODULE_ITEMS_FILE
	var definition = SHOP_ITEM_DEFINITION_SCRIPT.new()
	definition.apply_dictionary({
		"item_id": _validation.get_required_string(row, "item_id", file_label, errors),
		"name": _validation.get_required_string(row, "name", file_label, errors),
		"item_category": item_category,
		"rank": _validation.get_required_string(row, "rank", file_label, errors),
		"price_gold": _validation.get_required_int(row, "price_gold", file_label, errors),
		"shop_enabled": _validation.get_required_bool(row, "shop_enabled", file_label, errors),
		"shop_spawn_weight": _validation.get_required_float(row, "shop_spawn_weight", file_label, errors),
		"stackable": _validation.get_required_bool(row, "stackable", file_label, errors),
		"max_stack": _validation.get_required_int(row, "max_stack", file_label, errors),
		"equip_slot": _validation.get_optional_string(row, "equip_slot"),
		"is_equippable": _validation.get_required_bool(row, "is_equippable", file_label, errors),
		"icon_path": _validation.get_optional_string(row, "icon_path"),
		"short_desc": _validation.get_required_string(row, "short_desc", file_label, errors),
		"desc": _validation.get_required_string(row, "desc", file_label, errors),
		"tags": Array(_validation.get_string_list(row, "tags")),
		"effect_type": _validation.get_required_string(row, "effect_type", file_label, errors),
		"effect_values": _validation.get_effect_values(row),
	})
	return definition


func _save_resource(resource: Resource, output_path: String) -> Dictionary:
	var global_dir := ProjectSettings.globalize_path(output_path.get_base_dir())
	DirAccess.make_dir_recursive_absolute(global_dir)
	var save_error := ResourceSaver.save(resource, output_path)
	if save_error != OK:
		return {
			"ok": false,
			"errors": ["Failed to save resource: %s (code %d)" % [output_path, save_error]],
			"written_paths": [],
		}
	return {
		"ok": true,
		"errors": [],
		"written_paths": [output_path],
	}


func _read_table(input_dir: String, file_name: String) -> Dictionary:
	return _io.read_rows(_join_path(input_dir, file_name))


func _merge_read_errors(results: Array) -> Array[String]:
	var errors: Array[String] = []
	for raw_result in results:
		var result: Dictionary = raw_result
		if bool(result.get("ok", false)):
			continue
		for error_text in result.get("errors", []):
			errors.append(str(error_text))
	return errors


func _collect_result(result: Dictionary, written_paths: Array[String], errors: Array[String]) -> void:
	if bool(result.get("ok", false)):
		for path in result.get("written_paths", []):
			written_paths.append(str(path))
		return
	for error_text in result.get("errors", []):
		errors.append(str(error_text))


func _join_path(base_dir: String, file_name: String) -> String:
	if base_dir.ends_with("/") or base_dir.ends_with("\\"):
		return "%s%s" % [base_dir, file_name]
	if "\\" in base_dir:
		return "%s\\%s" % [base_dir, file_name]
	return "%s/%s" % [base_dir, file_name]
