extends RefCounted
class_name TsvValidationService

const TSV_SCHEMA = preload("res://scripts/tools/data_pipeline/TsvSchema.gd")

const VALID_DAY_TYPES := {
	"normal": true,
	"rush": true,
	"boss": true,
}

const VALID_DIFFICULTY_IDS := {
	"": true,
	"any": true,
	"normal": true,
	"hard": true,
	"extreme": true,
	"hell": true,
	"nightmare": true,
}

const VALID_ITEM_CATEGORIES := {
	"attack_module": true,
	"function_module": true,
	"enhance_module": true,
}

const VALID_ITEM_RANKS := {
	"D": true,
	"C": true,
	"B": true,
	"A": true,
	"S": true,
}

const VALID_FUNCTION_EFFECT_TYPES := {
	"combat_drone": true,
	"sand_cleaner": true,
	"aura_damage": true,
}

const VALID_ENHANCE_EFFECT_TYPES := {
	"stat_bonus": true,
	"conditional_stat_bonus": true,
}

const VALID_APPLY_TIMINGS := {
	"": true,
	"on_purchase": true,
	"stat_query": true,
}


func validate_block_catalog(
	meta_headers: Array,
	meta_rows: Array,
	material_headers: Array,
	material_rows: Array,
	size_headers: Array,
	size_rows: Array,
	type_headers: Array,
	type_rows: Array,
	size_rule_headers: Array = [],
	size_rule_rows: Array = [],
	material_size_rule_headers: Array = [],
	material_size_rule_rows: Array = []
) -> Dictionary:
	var errors: Array[String] = []
	_validate_headers("block_catalog_meta.tsv", meta_headers, TSV_SCHEMA.BLOCK_CATALOG_META_HEADERS, errors)
	_validate_headers("block_materials.tsv", material_headers, TSV_SCHEMA.BLOCK_MATERIAL_HEADERS, errors)
	_validate_headers("block_sizes.tsv", size_headers, TSV_SCHEMA.BLOCK_SIZE_HEADERS, errors)
	_validate_headers("block_types.tsv", type_headers, TSV_SCHEMA.BLOCK_TYPE_HEADERS, errors)
	_validate_headers("block_size_spawn_rules.tsv", size_rule_headers, TSV_SCHEMA.BLOCK_SIZE_SPAWN_RULE_HEADERS, errors)
	_validate_headers("block_material_size_weight_rules.tsv", material_size_rule_headers, TSV_SCHEMA.BLOCK_MATERIAL_SIZE_WEIGHT_RULE_HEADERS, errors)
	_require_single_meta_row("block_catalog_meta.tsv", meta_rows, errors)
	_validate_unique_ids("block_materials.tsv", material_rows, "material_id", errors)
	_validate_unique_ids("block_sizes.tsv", size_rows, "size_id", errors)
	_validate_unique_ids("block_types.tsv", type_rows, "id", errors)
	_validate_unique_ids("block_size_spawn_rules.tsv", size_rule_rows, "size_id", errors)
	_validate_unique_ids("block_material_size_weight_rules.tsv", material_size_rule_rows, "rule_id", errors)

	if not meta_rows.is_empty():
		var meta_row: Dictionary = meta_rows[0]
		get_required_string(meta_row, "default_material_id", "block_catalog_meta.tsv", errors)
		get_required_string(meta_row, "default_size_id", "block_catalog_meta.tsv", errors)
		get_required_float(meta_row, "random_type_chance", "block_catalog_meta.tsv", errors)

	for row in material_rows:
		get_required_string(row, "material_id", "block_materials.tsv", errors)
		get_required_string(row, "display_name", "block_materials.tsv", errors)
		get_required_float(row, "hp_multiplier", "block_materials.tsv", errors)
		get_required_float(row, "reward_multiplier", "block_materials.tsv", errors)
		get_required_float(row, "base_spawn_weight", "block_materials.tsv", errors)
		get_required_string(row, "special_result_type", "block_materials.tsv", errors)
		get_required_string(row, "color_key", "block_materials.tsv", errors)
		get_required_color(row, "block_color", "block_materials.tsv", errors)
		var min_difficulty := get_optional_string(row, "min_difficulty")
		if not VALID_DIFFICULTY_IDS.has(min_difficulty):
			errors.append(_location("block_materials.tsv", row, "min_difficulty") + "must be blank/any/normal/hard/extreme/hell/nightmare.")
		get_required_int(row, "min_stage", "block_materials.tsv", errors)
		get_required_int(row, "max_stage", "block_materials.tsv", errors)
		get_required_int(row, "max_allowed_area", "block_materials.tsv", errors)
		get_required_int(row, "max_allowed_width", "block_materials.tsv", errors)
		get_required_int(row, "max_allowed_height", "block_materials.tsv", errors)
		get_required_bool(row, "is_enabled", "block_materials.tsv", errors)

	for row in size_rows:
		get_required_string(row, "size_id", "block_sizes.tsv", errors)
		var width_u := get_required_int(row, "width_u", "block_sizes.tsv", errors)
		var height_u := get_required_int(row, "height_u", "block_sizes.tsv", errors)
		var area := get_required_int(row, "area", "block_sizes.tsv", errors)
		if width_u > 0 and height_u > 0 and area != width_u * height_u:
			errors.append(_location("block_sizes.tsv", row, "area") + "must equal width_u * height_u.")
		get_required_float(row, "hp_multiplier", "block_sizes.tsv", errors)
		get_required_float(row, "reward_multiplier", "block_sizes.tsv", errors)
		get_required_float(row, "base_spawn_weight", "block_sizes.tsv", errors)
		var size_min_difficulty := get_optional_string(row, "min_difficulty")
		if not VALID_DIFFICULTY_IDS.has(size_min_difficulty):
			errors.append(_location("block_sizes.tsv", row, "min_difficulty") + "must be blank/any/normal/hard/extreme/hell/nightmare.")
		get_required_int(row, "min_stage", "block_sizes.tsv", errors)
		get_required_int(row, "max_stage", "block_sizes.tsv", errors)
		get_required_bool(row, "is_enabled", "block_sizes.tsv", errors)

	for row in type_rows:
		get_required_string(row, "id", "block_types.tsv", errors)
		get_required_string(row, "display_name", "block_types.tsv", errors)
		get_required_bool(row, "can_spawn_randomly", "block_types.tsv", errors)
		get_required_float(row, "spawn_weight_multiplier", "block_types.tsv", errors)
		get_required_float(row, "hp_multiplier", "block_types.tsv", errors)
		get_required_float(row, "reward_multiplier", "block_types.tsv", errors)
		get_required_float(row, "sand_units_multiplier", "block_types.tsv", errors)
		get_required_string(row, "special_result_override", "block_types.tsv", errors)

	for row in size_rule_rows:
		get_required_string(row, "size_id", "block_size_spawn_rules.tsv", errors)
		get_required_string(row, "size_group", "block_size_spawn_rules.tsv", errors)
		_validate_positive_required_float(row, "base_spawn_weight", "block_size_spawn_rules.tsv", errors)
		_validate_positive_required_float(row, "normal_multiplier", "block_size_spawn_rules.tsv", errors)
		_validate_positive_required_float(row, "hard_multiplier", "block_size_spawn_rules.tsv", errors)
		_validate_positive_required_float(row, "extreme_multiplier", "block_size_spawn_rules.tsv", errors)
		_validate_positive_required_float(row, "hell_multiplier", "block_size_spawn_rules.tsv", errors)
		_validate_positive_required_float(row, "nightmare_multiplier", "block_size_spawn_rules.tsv", errors)
		_validate_positive_required_float(row, "day_1_5_multiplier", "block_size_spawn_rules.tsv", errors)
		_validate_positive_required_float(row, "day_6_10_multiplier", "block_size_spawn_rules.tsv", errors)
		_validate_positive_required_float(row, "day_11_15_multiplier", "block_size_spawn_rules.tsv", errors)
		_validate_positive_required_float(row, "day_16_20_multiplier", "block_size_spawn_rules.tsv", errors)
		_validate_positive_required_float(row, "day_21_25_multiplier", "block_size_spawn_rules.tsv", errors)
		_validate_positive_required_float(row, "day_26_30_multiplier", "block_size_spawn_rules.tsv", errors)
		get_required_int(row, "min_day_hint", "block_size_spawn_rules.tsv", errors)

	for row in material_size_rule_rows:
		get_required_string(row, "rule_id", "block_material_size_weight_rules.tsv", errors)
		var selector_count := 0
		for selector_column in ["size_id", "size_group", "area_group", "width_group", "height_group"]:
			if not get_optional_string(row, selector_column).is_empty():
				selector_count += 1
		if selector_count <= 0:
			errors.append(_location("block_material_size_weight_rules.tsv", row, "size_group") + "must define at least one size selector.")
		_validate_positive_required_float(row, "weight_multiplier", "block_material_size_weight_rules.tsv", errors)
		_validate_positive_required_float(row, "normal_multiplier", "block_material_size_weight_rules.tsv", errors)
		_validate_positive_required_float(row, "hard_multiplier", "block_material_size_weight_rules.tsv", errors)
		_validate_positive_required_float(row, "extreme_multiplier", "block_material_size_weight_rules.tsv", errors)
		_validate_positive_required_float(row, "hell_multiplier", "block_material_size_weight_rules.tsv", errors)
		_validate_positive_required_float(row, "nightmare_multiplier", "block_material_size_weight_rules.tsv", errors)
		_validate_positive_required_float(row, "day_1_5_multiplier", "block_material_size_weight_rules.tsv", errors)
		_validate_positive_required_float(row, "day_6_10_multiplier", "block_material_size_weight_rules.tsv", errors)
		_validate_positive_required_float(row, "day_11_15_multiplier", "block_material_size_weight_rules.tsv", errors)
		_validate_positive_required_float(row, "day_16_20_multiplier", "block_material_size_weight_rules.tsv", errors)
		_validate_positive_required_float(row, "day_21_25_multiplier", "block_material_size_weight_rules.tsv", errors)
		_validate_positive_required_float(row, "day_26_30_multiplier", "block_material_size_weight_rules.tsv", errors)
		get_required_int(row, "min_day_hint", "block_material_size_weight_rules.tsv", errors)

	return _build_result(errors)


func validate_spawn_v2_rules(
	size_rule_headers: Array,
	size_rule_rows: Array,
	material_size_rule_headers: Array,
	material_size_rule_rows: Array
) -> Dictionary:
	var errors: Array[String] = []
	_validate_headers("block_size_spawn_rules.tsv", size_rule_headers, TSV_SCHEMA.BLOCK_SIZE_SPAWN_RULE_HEADERS, errors)
	_validate_headers("block_material_size_weight_rules.tsv", material_size_rule_headers, TSV_SCHEMA.BLOCK_MATERIAL_SIZE_WEIGHT_RULE_HEADERS, errors)
	_validate_unique_ids("block_size_spawn_rules.tsv", size_rule_rows, "size_id", errors)
	_validate_unique_ids("block_material_size_weight_rules.tsv", material_size_rule_rows, "rule_id", errors)
	for row in size_rule_rows:
		get_required_string(row, "size_id", "block_size_spawn_rules.tsv", errors)
		get_required_string(row, "size_group", "block_size_spawn_rules.tsv", errors)
		_validate_positive_required_float(row, "base_spawn_weight", "block_size_spawn_rules.tsv", errors)
		_validate_positive_required_float(row, "normal_multiplier", "block_size_spawn_rules.tsv", errors)
		_validate_positive_required_float(row, "hard_multiplier", "block_size_spawn_rules.tsv", errors)
		_validate_positive_required_float(row, "extreme_multiplier", "block_size_spawn_rules.tsv", errors)
		_validate_positive_required_float(row, "hell_multiplier", "block_size_spawn_rules.tsv", errors)
		_validate_positive_required_float(row, "nightmare_multiplier", "block_size_spawn_rules.tsv", errors)
		_validate_positive_required_float(row, "day_1_5_multiplier", "block_size_spawn_rules.tsv", errors)
		_validate_positive_required_float(row, "day_6_10_multiplier", "block_size_spawn_rules.tsv", errors)
		_validate_positive_required_float(row, "day_11_15_multiplier", "block_size_spawn_rules.tsv", errors)
		_validate_positive_required_float(row, "day_16_20_multiplier", "block_size_spawn_rules.tsv", errors)
		_validate_positive_required_float(row, "day_21_25_multiplier", "block_size_spawn_rules.tsv", errors)
		_validate_positive_required_float(row, "day_26_30_multiplier", "block_size_spawn_rules.tsv", errors)
		get_required_int(row, "min_day_hint", "block_size_spawn_rules.tsv", errors)
	for row in material_size_rule_rows:
		get_required_string(row, "rule_id", "block_material_size_weight_rules.tsv", errors)
		var selector_count := 0
		for selector_column in ["size_id", "size_group", "area_group", "width_group", "height_group"]:
			if not get_optional_string(row, selector_column).is_empty():
				selector_count += 1
		if selector_count <= 0:
			errors.append(_location("block_material_size_weight_rules.tsv", row, "size_group") + "must define at least one size selector.")
		_validate_positive_required_float(row, "weight_multiplier", "block_material_size_weight_rules.tsv", errors)
		_validate_positive_required_float(row, "normal_multiplier", "block_material_size_weight_rules.tsv", errors)
		_validate_positive_required_float(row, "hard_multiplier", "block_material_size_weight_rules.tsv", errors)
		_validate_positive_required_float(row, "extreme_multiplier", "block_material_size_weight_rules.tsv", errors)
		_validate_positive_required_float(row, "hell_multiplier", "block_material_size_weight_rules.tsv", errors)
		_validate_positive_required_float(row, "nightmare_multiplier", "block_material_size_weight_rules.tsv", errors)
		_validate_positive_required_float(row, "day_1_5_multiplier", "block_material_size_weight_rules.tsv", errors)
		_validate_positive_required_float(row, "day_6_10_multiplier", "block_material_size_weight_rules.tsv", errors)
		_validate_positive_required_float(row, "day_11_15_multiplier", "block_material_size_weight_rules.tsv", errors)
		_validate_positive_required_float(row, "day_16_20_multiplier", "block_material_size_weight_rules.tsv", errors)
		_validate_positive_required_float(row, "day_21_25_multiplier", "block_material_size_weight_rules.tsv", errors)
		_validate_positive_required_float(row, "day_26_30_multiplier", "block_material_size_weight_rules.tsv", errors)
		get_required_int(row, "min_day_hint", "block_material_size_weight_rules.tsv", errors)
	return _build_result(errors)


func validate_stage_table(day_headers: Array, day_rows: Array) -> Dictionary:
	var errors: Array[String] = []
	_validate_headers("stage_days.tsv", day_headers, TSV_SCHEMA.STAGE_DAY_HEADERS, errors)
	_validate_unique_ids("stage_days.tsv", day_rows, "day_number", errors)
	for row in day_rows:
		get_required_int(row, "day_number", "stage_days.tsv", errors)
		var day_type := get_required_string(row, "day_type", "stage_days.tsv", errors)
		if not day_type.is_empty() and not VALID_DAY_TYPES.has(day_type):
			errors.append(_location("stage_days.tsv", row, "day_type") + "must be one of normal/rush/boss.")
		get_required_float(row, "duration", "stage_days.tsv", errors)
		get_required_float(row, "block_hp_multiplier", "stage_days.tsv", errors)
		get_required_float(row, "spawn_interval_multiplier", "stage_days.tsv", errors)
		get_required_float(row, "reward_multiplier", "stage_days.tsv", errors)
	return _build_result(errors)


func validate_shop_item_catalog(
	attack_headers: Array,
	attack_rows: Array,
	function_headers: Array,
	function_rows: Array,
	enhance_headers: Array,
	enhance_rows: Array
) -> Dictionary:
	var errors: Array[String] = []
	_validate_headers("attack_module_items.tsv", attack_headers, TSV_SCHEMA.get_attack_module_item_headers(), errors)
	_validate_headers("function_module_items.tsv", function_headers, TSV_SCHEMA.get_function_module_item_headers(), errors)
	_validate_headers("enhance_module_items.tsv", enhance_headers, TSV_SCHEMA.get_enhance_module_item_headers(), errors)
	var all_item_ids: Dictionary = {}
	_validate_item_rows("attack_module_items.tsv", attack_rows, &"attack_module", all_item_ids, errors)
	_validate_item_rows("function_module_items.tsv", function_rows, &"function_module", all_item_ids, errors)
	_validate_item_rows("enhance_module_items.tsv", enhance_rows, &"enhance_module", all_item_ids, errors)
	return _build_result(errors)


func get_required_string(row: Dictionary, column: String, file_label: String, errors: Array[String]) -> String:
	var value := str(row.get(column, "")).strip_edges()
	if value.is_empty():
		errors.append(_location(file_label, row, column) + "is required.")
	return value


func get_optional_string(row: Dictionary, column: String) -> String:
	return str(row.get(column, "")).strip_edges()


func get_required_int(row: Dictionary, column: String, file_label: String, errors: Array[String]) -> int:
	var value := str(row.get(column, "")).strip_edges()
	if value.is_empty():
		errors.append(_location(file_label, row, column) + "is required.")
		return 0
	if not value.is_valid_int():
		errors.append(_location(file_label, row, column) + "must be an integer.")
		return 0
	return int(value)


func get_optional_int(row: Dictionary, column: String, default_value := 0) -> int:
	var value := str(row.get(column, "")).strip_edges()
	if value.is_empty():
		return default_value
	if value.is_valid_int():
		return int(value)
	return default_value


func get_required_float(row: Dictionary, column: String, file_label: String, errors: Array[String]) -> float:
	var value := str(row.get(column, "")).strip_edges()
	if value.is_empty():
		errors.append(_location(file_label, row, column) + "is required.")
		return 0.0
	if not value.is_valid_float() and not value.is_valid_int():
		errors.append(_location(file_label, row, column) + "must be a number.")
		return 0.0
	return float(value)


func get_optional_float(row: Dictionary, column: String, default_value := 0.0) -> float:
	var value := str(row.get(column, "")).strip_edges()
	if value.is_empty():
		return default_value
	if value.is_valid_float() or value.is_valid_int():
		return float(value)
	return default_value


func get_required_bool(row: Dictionary, column: String, file_label: String, errors: Array[String]) -> bool:
	var value := str(row.get(column, "")).strip_edges().to_lower()
	if value.is_empty():
		errors.append(_location(file_label, row, column) + "is required.")
		return false
	match value:
		"true", "1", "yes":
			return true
		"false", "0", "no":
			return false
		_:
			errors.append(_location(file_label, row, column) + "must be true/false.")
			return false


func get_optional_bool(row: Dictionary, column: String, default_value := false) -> bool:
	var value := str(row.get(column, "")).strip_edges().to_lower()
	if value.is_empty():
		return default_value
	match value:
		"true", "1", "yes":
			return true
		"false", "0", "no":
			return false
		_:
			return default_value


func get_required_color(row: Dictionary, column: String, file_label: String, errors: Array[String]) -> Color:
	var value := get_required_string(row, column, file_label, errors)
	if value.is_empty():
		return Color.WHITE
	var parsed := Color.from_string(value, Color(999.0, 999.0, 999.0, 999.0))
	if parsed.r > 100.0:
		errors.append(_location(file_label, row, column) + "must be a valid color string.")
		return Color.WHITE
	return parsed


func get_string_list(row: Dictionary, column: String) -> PackedStringArray:
	return TSV_SCHEMA.split_list(str(row.get(column, "")))


func get_effect_values(row: Dictionary) -> Dictionary:
	var effect_values: Dictionary = {}
	for column in TSV_SCHEMA.EFFECT_HEADERS:
		var value := str(row.get(column, "")).strip_edges()
		if value.is_empty():
			continue
		var effect_key := str(TSV_SCHEMA.EFFECT_COLUMN_TO_KEY[column])
		if value.is_valid_int():
			effect_values[effect_key] = int(value)
		elif value.is_valid_float():
			effect_values[effect_key] = float(value)
		else:
			effect_values[effect_key] = value
	return effect_values


func get_dictionary_array_json(row: Dictionary, column: String, file_label: String, errors: Array[String]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var value := str(row.get(column, "")).strip_edges()
	if value.is_empty():
		return result
	var json := JSON.new()
	var parse_error := json.parse(value)
	if parse_error != OK:
		errors.append(_location(file_label, row, column) + "must be a valid JSON array. %s" % json.get_error_message())
		return result
	var parsed = json.data
	if not parsed is Array:
		errors.append(_location(file_label, row, column) + "must be a JSON array.")
		return result
	var parsed_array: Array = parsed
	for index in range(parsed_array.size()):
		var raw_entry = parsed_array[index]
		if not raw_entry is Dictionary:
			errors.append(_location(file_label, row, column) + "entry %d must be a JSON object." % [index + 1])
			continue
		var entry: Dictionary = _normalize_json_value(raw_entry)
		result.append(entry.duplicate(true))
	return result


func _normalize_json_value(value: Variant) -> Variant:
	if value is Dictionary:
		var normalized_dictionary: Dictionary = {}
		var source_dictionary: Dictionary = value
		for key in source_dictionary.keys():
			normalized_dictionary[key] = _normalize_json_value(source_dictionary[key])
		return normalized_dictionary
	if value is Array:
		var normalized_array: Array = []
		for entry in value:
			normalized_array.append(_normalize_json_value(entry))
		return normalized_array
	if value is float:
		var float_value := float(value)
		var int_value := int(float_value)
		if is_equal_approx(float_value, float(int_value)):
			return int_value
	return value


func _validate_item_rows(file_label: String, rows: Array, expected_category: StringName, all_item_ids: Dictionary, errors: Array[String]) -> void:
	for row in rows:
		var item_id := get_required_string(row, "item_id", file_label, errors)
		if not item_id.is_empty():
			if all_item_ids.has(item_id):
				errors.append(_location(file_label, row, "item_id") + "duplicates item_id '%s'." % item_id)
			else:
				all_item_ids[item_id] = true
		get_required_string(row, "name", file_label, errors)
		var item_category := get_required_string(row, "item_category", file_label, errors)
		if not item_category.is_empty() and item_category != str(expected_category):
			errors.append(_location(file_label, row, "item_category") + "must be %s." % str(expected_category))
		if not item_category.is_empty() and not VALID_ITEM_CATEGORIES.has(item_category):
			errors.append(_location(file_label, row, "item_category") + "must be attack_module/function_module/enhance_module.")
		var rank := get_required_string(row, "rank", file_label, errors)
		if not rank.is_empty() and not VALID_ITEM_RANKS.has(rank):
			errors.append(_location(file_label, row, "rank") + "must be one of D/C/B/A/S.")
		get_required_int(row, "price_gold", file_label, errors)
		get_required_bool(row, "shop_enabled", file_label, errors)
		get_required_float(row, "shop_spawn_weight", file_label, errors)
		get_required_bool(row, "stackable", file_label, errors)
		get_required_int(row, "max_stack", file_label, errors)
		get_required_bool(row, "is_equippable", file_label, errors)
		get_required_string(row, "short_desc", file_label, errors)
		get_required_string(row, "desc", file_label, errors)
		if str(expected_category) == "function_module" or str(expected_category) == "enhance_module":
			get_dictionary_array_json(row, "conditions_json", file_label, errors)
			get_dictionary_array_json(row, "effects_json", file_label, errors)
			var apply_timing := get_optional_string(row, "apply_timing")
			if not VALID_APPLY_TIMINGS.has(apply_timing):
				errors.append(_location(file_label, row, "apply_timing") + "must be blank/on_purchase/stat_query.")
		match str(expected_category):
			"attack_module":
				get_required_bool(row, "default_start_module", file_label, errors)
				get_required_string(row, "module_type", file_label, errors)
				get_required_float(row, "base_shape_units_x", file_label, errors)
				get_required_float(row, "base_shape_units_y", file_label, errors)
				get_required_float(row, "range_growth_width_scale", file_label, errors)
				get_required_float(row, "range_growth_height_scale", file_label, errors)
				get_required_string(row, "hit_shape", file_label, errors)
				get_required_float(row, "range_units", file_label, errors)
				get_required_float(row, "range_growth_scale", file_label, errors)
				get_required_float(row, "range_width_u", file_label, errors)
				get_required_float(row, "range_height_u", file_label, errors)
				get_required_int(row, "module_base_damage", file_label, errors)
				for grade in TSV_SCHEMA.ATTACK_MODULE_BASE_DAMAGE_GRADES:
					get_required_int(row, "base_damage_%s" % grade, file_label, errors)
				get_required_float(row, "attack_speed_multiplier", file_label, errors)
				get_required_string(row, "world_visual_scene_path", file_label, errors)
			"function_module":
				var effect_type := get_required_string(row, "effect_type", file_label, errors)
				if not effect_type.is_empty() and not VALID_FUNCTION_EFFECT_TYPES.has(effect_type):
					errors.append(_location(file_label, row, "effect_type") + "must be combat_drone/sand_cleaner/aura_damage.")
			"enhance_module":
				var enhance_effect_type := get_required_string(row, "effect_type", file_label, errors)
				if not enhance_effect_type.is_empty() and not VALID_ENHANCE_EFFECT_TYPES.has(enhance_effect_type):
					errors.append(_location(file_label, row, "effect_type") + "must be stat_bonus/conditional_stat_bonus.")


func _validate_positive_required_float(row: Dictionary, column: String, file_label: String, errors: Array[String]) -> void:
	var value := get_required_float(row, column, file_label, errors)
	if value <= 0.0:
		errors.append(_location(file_label, row, column) + "must be greater than 0. Use an epsilon multiplier instead of 0.")


func _validate_headers(file_label: String, headers: Array, required_headers: Array, errors: Array[String]) -> void:
	var seen_headers: Dictionary = {}
	for header in headers:
		var header_text := str(header)
		if seen_headers.has(header_text):
			errors.append("%s has a duplicated header '%s'." % [file_label, header_text])
		seen_headers[header_text] = true
	for required_header in required_headers:
		if not headers.has(required_header):
			errors.append("%s is missing required header '%s'." % [file_label, required_header])


func _require_single_meta_row(file_label: String, rows: Array, errors: Array[String]) -> void:
	if rows.size() != 1:
		errors.append("%s must contain exactly one data row." % file_label)


func _validate_unique_ids(file_label: String, rows: Array, id_column: String, errors: Array[String]) -> void:
	var seen_ids: Dictionary = {}
	for row in rows:
		var id_text := str(row.get(id_column, "")).strip_edges()
		if id_text.is_empty():
			continue
		if seen_ids.has(id_text):
			errors.append(_location(file_label, row, id_column) + "duplicates id '%s'." % id_text)
		else:
			seen_ids[id_text] = true


func _location(file_label: String, row: Dictionary, column: String) -> String:
	return "%s row %d column %s " % [file_label, int(row.get("__row_number", 0)), column]


func _build_result(errors: Array[String]) -> Dictionary:
	return {
		"ok": errors.is_empty(),
		"errors": errors,
	}
