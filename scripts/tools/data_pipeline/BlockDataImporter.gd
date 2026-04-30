extends RefCounted
class_name BlockDataImporter

const TSV_SCHEMA = preload("res://scripts/tools/data_pipeline/TsvSchema.gd")
const TSV_IO_SCRIPT = preload("res://scripts/tools/data_pipeline/TsvIo.gd")
const TSV_VALIDATION_SERVICE_SCRIPT = preload("res://scripts/tools/data_pipeline/TsvValidationService.gd")
const BLOCK_CATALOG_SCRIPT = preload("res://scripts/data/BlockCatalog.gd")
const BLOCK_MATERIAL_DATA_SCRIPT = preload("res://scripts/data/BlockMaterialData.gd")
const BLOCK_SIZE_DATA_SCRIPT = preload("res://scripts/data/BlockSizeData.gd")
const BLOCK_TYPE_DEFINITION_SCRIPT = preload("res://scripts/data/BlockTypeDefinition.gd")
const BLOCK_SIZE_SPAWN_RULE_DATA_SCRIPT = preload("res://scripts/data/BlockSizeSpawnRuleData.gd")
const BLOCK_MATERIAL_SIZE_WEIGHT_RULE_DATA_SCRIPT = preload("res://scripts/data/BlockMaterialSizeWeightRuleData.gd")

var _io = TSV_IO_SCRIPT.new()
var _validation = TSV_VALIDATION_SERVICE_SCRIPT.new()


func import_from_directory(input_dir: String) -> Dictionary:
	var meta_result := _io.read_rows(_join_path(input_dir, TSV_SCHEMA.BLOCK_CATALOG_META_FILE))
	var material_result := _io.read_rows(_join_path(input_dir, TSV_SCHEMA.BLOCK_MATERIALS_FILE))
	var size_result := _io.read_rows(_join_path(input_dir, TSV_SCHEMA.BLOCK_SIZES_FILE))
	var type_result := _io.read_rows(_join_path(input_dir, TSV_SCHEMA.BLOCK_TYPES_FILE))
	var size_rule_result := _io.read_rows(_join_path(input_dir, TSV_SCHEMA.BLOCK_SIZE_SPAWN_RULES_FILE))
	var material_size_rule_result := _io.read_rows(_join_path(input_dir, TSV_SCHEMA.BLOCK_MATERIAL_SIZE_WEIGHT_RULES_FILE))
	var errors: Array[String] = []
	for result in [meta_result, material_result, size_result, type_result, size_rule_result, material_size_rule_result]:
		if bool(result.get("ok", false)):
			continue
		for error_text in result.get("errors", []):
			errors.append(str(error_text))
	if not errors.is_empty():
		return {"ok": false, "errors": errors}

	var validation := _validation.validate_block_catalog(
		meta_result["headers"],
		meta_result["rows"],
		material_result["headers"],
		material_result["rows"],
		size_result["headers"],
		size_result["rows"],
		type_result["headers"],
		type_result["rows"],
		size_rule_result["headers"],
		size_rule_result["rows"],
		material_size_rule_result["headers"],
		material_size_rule_result["rows"]
	)
	if not bool(validation.get("ok", false)):
		return {"ok": false, "errors": validation["errors"]}

	var catalog = BLOCK_CATALOG_SCRIPT.new()
	var meta_row: Dictionary = meta_result["rows"][0]
	catalog.default_block_base_id = StringName(_validation.get_required_string(meta_row, "default_material_id", TSV_SCHEMA.BLOCK_CATALOG_META_FILE, errors))
	catalog.default_block_size_id = StringName(_validation.get_required_string(meta_row, "default_size_id", TSV_SCHEMA.BLOCK_CATALOG_META_FILE, errors))
	catalog.random_type_chance = _validation.get_required_float(meta_row, "random_type_chance", TSV_SCHEMA.BLOCK_CATALOG_META_FILE, errors)

	for row in material_result["rows"]:
		var material = BLOCK_MATERIAL_DATA_SCRIPT.new()
		material.material_id = StringName(_validation.get_required_string(row, "material_id", TSV_SCHEMA.BLOCK_MATERIALS_FILE, errors))
		material.display_name = _validation.get_required_string(row, "display_name", TSV_SCHEMA.BLOCK_MATERIALS_FILE, errors)
		material.hp_multiplier = _validation.get_required_float(row, "hp_multiplier", TSV_SCHEMA.BLOCK_MATERIALS_FILE, errors)
		material.reward_multiplier = _validation.get_required_float(row, "reward_multiplier", TSV_SCHEMA.BLOCK_MATERIALS_FILE, errors)
		material.base_spawn_weight = _validation.get_required_float(row, "base_spawn_weight", TSV_SCHEMA.BLOCK_MATERIALS_FILE, errors)
		material.special_result_type = StringName(_validation.get_required_string(row, "special_result_type", TSV_SCHEMA.BLOCK_MATERIALS_FILE, errors))
		material.color_key = StringName(_validation.get_required_string(row, "color_key", TSV_SCHEMA.BLOCK_MATERIALS_FILE, errors))
		material.block_color = _validation.get_required_color(row, "block_color", TSV_SCHEMA.BLOCK_MATERIALS_FILE, errors)
		material.min_difficulty = StringName(_validation.get_optional_string(row, "min_difficulty"))
		material.min_stage = _validation.get_required_int(row, "min_stage", TSV_SCHEMA.BLOCK_MATERIALS_FILE, errors)
		material.max_stage = _validation.get_required_int(row, "max_stage", TSV_SCHEMA.BLOCK_MATERIALS_FILE, errors)
		material.max_allowed_area = _validation.get_required_int(row, "max_allowed_area", TSV_SCHEMA.BLOCK_MATERIALS_FILE, errors)
		material.max_allowed_width = _validation.get_required_int(row, "max_allowed_width", TSV_SCHEMA.BLOCK_MATERIALS_FILE, errors)
		material.max_allowed_height = _validation.get_required_int(row, "max_allowed_height", TSV_SCHEMA.BLOCK_MATERIALS_FILE, errors)
		material.is_enabled = _validation.get_required_bool(row, "is_enabled", TSV_SCHEMA.BLOCK_MATERIALS_FILE, errors)
		material.notes = _validation.get_optional_string(row, "notes")
		catalog.block_materials.append(material)

	for row in size_result["rows"]:
		var size_data = BLOCK_SIZE_DATA_SCRIPT.new()
		size_data.size_id = StringName(_validation.get_required_string(row, "size_id", TSV_SCHEMA.BLOCK_SIZES_FILE, errors))
		size_data.width_u = _validation.get_required_int(row, "width_u", TSV_SCHEMA.BLOCK_SIZES_FILE, errors)
		size_data.height_u = _validation.get_required_int(row, "height_u", TSV_SCHEMA.BLOCK_SIZES_FILE, errors)
		size_data.area = _validation.get_required_int(row, "area", TSV_SCHEMA.BLOCK_SIZES_FILE, errors)
		size_data.hp_multiplier = _validation.get_required_float(row, "hp_multiplier", TSV_SCHEMA.BLOCK_SIZES_FILE, errors)
		size_data.reward_multiplier = _validation.get_required_float(row, "reward_multiplier", TSV_SCHEMA.BLOCK_SIZES_FILE, errors)
		size_data.base_spawn_weight = _validation.get_required_float(row, "base_spawn_weight", TSV_SCHEMA.BLOCK_SIZES_FILE, errors)
		size_data.min_difficulty = StringName(_validation.get_optional_string(row, "min_difficulty"))
		size_data.min_stage = _validation.get_required_int(row, "min_stage", TSV_SCHEMA.BLOCK_SIZES_FILE, errors)
		size_data.max_stage = _validation.get_required_int(row, "max_stage", TSV_SCHEMA.BLOCK_SIZES_FILE, errors)
		size_data.is_enabled = _validation.get_required_bool(row, "is_enabled", TSV_SCHEMA.BLOCK_SIZES_FILE, errors)
		size_data.tags = _validation.get_string_list(row, "tags")
		size_data.notes = _validation.get_optional_string(row, "notes")
		catalog.block_sizes.append(size_data)

	for row in type_result["rows"]:
		var block_type = BLOCK_TYPE_DEFINITION_SCRIPT.new()
		block_type.id = StringName(_validation.get_required_string(row, "id", TSV_SCHEMA.BLOCK_TYPES_FILE, errors))
		block_type.display_name = _validation.get_required_string(row, "display_name", TSV_SCHEMA.BLOCK_TYPES_FILE, errors)
		block_type.name_prefix = _validation.get_optional_string(row, "name_prefix")
		block_type.name_suffix = _validation.get_optional_string(row, "name_suffix")
		block_type.can_spawn_randomly = _validation.get_required_bool(row, "can_spawn_randomly", TSV_SCHEMA.BLOCK_TYPES_FILE, errors)
		block_type.spawn_weight_multiplier = _validation.get_required_float(row, "spawn_weight_multiplier", TSV_SCHEMA.BLOCK_TYPES_FILE, errors)
		block_type.hp_multiplier = _validation.get_required_float(row, "hp_multiplier", TSV_SCHEMA.BLOCK_TYPES_FILE, errors)
		block_type.reward_multiplier = _validation.get_required_float(row, "reward_multiplier", TSV_SCHEMA.BLOCK_TYPES_FILE, errors)
		block_type.sand_units_multiplier = _validation.get_required_float(row, "sand_units_multiplier", TSV_SCHEMA.BLOCK_TYPES_FILE, errors)
		block_type.special_result_override = StringName(_validation.get_required_string(row, "special_result_override", TSV_SCHEMA.BLOCK_TYPES_FILE, errors))
		catalog.block_types.append(block_type)

	for row in size_rule_result["rows"]:
		var rule = BLOCK_SIZE_SPAWN_RULE_DATA_SCRIPT.new()
		rule.size_id = StringName(_validation.get_required_string(row, "size_id", TSV_SCHEMA.BLOCK_SIZE_SPAWN_RULES_FILE, errors))
		rule.size_group = _validation.get_required_string(row, "size_group", TSV_SCHEMA.BLOCK_SIZE_SPAWN_RULES_FILE, errors)
		rule.base_spawn_weight = _validation.get_required_float(row, "base_spawn_weight", TSV_SCHEMA.BLOCK_SIZE_SPAWN_RULES_FILE, errors)
		_assign_spawn_rule_multipliers(rule, row, TSV_SCHEMA.BLOCK_SIZE_SPAWN_RULES_FILE, errors)
		catalog.block_size_spawn_rules.append(rule)

	for row in material_size_rule_result["rows"]:
		var rule = BLOCK_MATERIAL_SIZE_WEIGHT_RULE_DATA_SCRIPT.new()
		rule.rule_id = StringName(_validation.get_required_string(row, "rule_id", TSV_SCHEMA.BLOCK_MATERIAL_SIZE_WEIGHT_RULES_FILE, errors))
		rule.material_id = StringName(_validation.get_optional_string(row, "material_id"))
		rule.size_id = StringName(_validation.get_optional_string(row, "size_id"))
		rule.size_group = _validation.get_optional_string(row, "size_group")
		rule.area_group = _validation.get_optional_string(row, "area_group")
		rule.width_group = _validation.get_optional_string(row, "width_group")
		rule.height_group = _validation.get_optional_string(row, "height_group")
		rule.weight_multiplier = _validation.get_required_float(row, "weight_multiplier", TSV_SCHEMA.BLOCK_MATERIAL_SIZE_WEIGHT_RULES_FILE, errors)
		_assign_spawn_rule_multipliers(rule, row, TSV_SCHEMA.BLOCK_MATERIAL_SIZE_WEIGHT_RULES_FILE, errors)
		catalog.block_material_size_weight_rules.append(rule)

	if not errors.is_empty():
		return {"ok": false, "errors": errors}
	return {
		"ok": true,
		"errors": [],
		"catalog": catalog,
	}


func _assign_spawn_rule_multipliers(rule, row: Dictionary, file_label: String, errors: Array[String]) -> void:
	rule.normal_multiplier = _validation.get_required_float(row, "normal_multiplier", file_label, errors)
	rule.hard_multiplier = _validation.get_required_float(row, "hard_multiplier", file_label, errors)
	rule.extreme_multiplier = _validation.get_required_float(row, "extreme_multiplier", file_label, errors)
	rule.hell_multiplier = _validation.get_required_float(row, "hell_multiplier", file_label, errors)
	rule.nightmare_multiplier = _validation.get_required_float(row, "nightmare_multiplier", file_label, errors)
	rule.day_1_5_multiplier = _validation.get_required_float(row, "day_1_5_multiplier", file_label, errors)
	rule.day_6_10_multiplier = _validation.get_required_float(row, "day_6_10_multiplier", file_label, errors)
	rule.day_11_15_multiplier = _validation.get_required_float(row, "day_11_15_multiplier", file_label, errors)
	rule.day_16_20_multiplier = _validation.get_required_float(row, "day_16_20_multiplier", file_label, errors)
	rule.day_21_25_multiplier = _validation.get_required_float(row, "day_21_25_multiplier", file_label, errors)
	rule.day_26_30_multiplier = _validation.get_required_float(row, "day_26_30_multiplier", file_label, errors)
	rule.min_day_hint = _validation.get_required_int(row, "min_day_hint", file_label, errors)
	rule.notes = _validation.get_optional_string(row, "notes")


func _join_path(base_dir: String, file_name: String) -> String:
	if base_dir.ends_with("/") or base_dir.ends_with("\\"):
		return "%s%s" % [base_dir, file_name]
	if "\\" in base_dir:
		return "%s\\%s" % [base_dir, file_name]
	return "%s/%s" % [base_dir, file_name]
