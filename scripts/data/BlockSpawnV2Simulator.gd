extends RefCounted
class_name BlockSpawnV2Simulator

const GC = preload("res://scripts/autoload/GameConstants.gd")
const TSV_SCHEMA = preload("res://scripts/tools/data_pipeline/TsvSchema.gd")
const TSV_IO_SCRIPT = preload("res://scripts/tools/data_pipeline/TsvIo.gd")
const TSV_VALIDATION_SERVICE_SCRIPT = preload("res://scripts/tools/data_pipeline/TsvValidationService.gd")
const BLOCK_RESOLVED_DEFINITION_SCRIPT = preload("res://scripts/data/BlockResolvedDefinition.gd")
const BLOCK_SIZE_SPAWN_RULE_DATA_SCRIPT = preload("res://scripts/data/BlockSizeSpawnRuleData.gd")
const BLOCK_MATERIAL_SIZE_WEIGHT_RULE_DATA_SCRIPT = preload("res://scripts/data/BlockMaterialSizeWeightRuleData.gd")

const DIFFICULTY_ORDER := ["normal", "hard", "extreme", "hell", "nightmare"]
const GENERAL_SPAWN_MAX_HEIGHT_U := 3

var size_spawn_rules_by_size_id: Dictionary = {}
var material_size_weight_rules: Array[Resource] = []
var load_errors: Array[String] = []

var _io = TSV_IO_SCRIPT.new()
var _validation = TSV_VALIDATION_SERVICE_SCRIPT.new()


func load_rules_from_directory(input_dir: String = TSV_SCHEMA.DEFAULT_TSV_DIR) -> Dictionary:
	load_errors.clear()
	size_spawn_rules_by_size_id.clear()
	material_size_weight_rules.clear()

	var size_rule_result := _io.read_rows(_join_path(input_dir, TSV_SCHEMA.BLOCK_SIZE_SPAWN_RULES_FILE))
	var material_size_rule_result := _io.read_rows(_join_path(input_dir, TSV_SCHEMA.BLOCK_MATERIAL_SIZE_WEIGHT_RULES_FILE))
	for result in [size_rule_result, material_size_rule_result]:
		if bool(result.get("ok", false)):
			continue
		for error_text in result.get("errors", []):
			load_errors.append(str(error_text))
	if not load_errors.is_empty():
		return {"ok": false, "errors": load_errors}

	var validation_result := _validation.validate_spawn_v2_rules(
		size_rule_result["headers"],
		size_rule_result["rows"],
		material_size_rule_result["headers"],
		material_size_rule_result["rows"]
	)
	if not bool(validation_result.get("ok", false)):
		for error_text in validation_result.get("errors", []):
			load_errors.append(str(error_text))
		return {"ok": false, "errors": load_errors}

	for row in size_rule_result["rows"]:
		var rule := BLOCK_SIZE_SPAWN_RULE_DATA_SCRIPT.new()
		rule.size_id = StringName(_get_string(row, "size_id"))
		rule.size_group = _get_string(row, "size_group")
		rule.base_spawn_weight = _get_float(row, "base_spawn_weight", 1.0)
		_assign_common_rule_fields(rule, row)
		size_spawn_rules_by_size_id[str(rule.size_id)] = rule

	for row in material_size_rule_result["rows"]:
		var rule := BLOCK_MATERIAL_SIZE_WEIGHT_RULE_DATA_SCRIPT.new()
		rule.rule_id = StringName(_get_string(row, "rule_id"))
		rule.material_id = StringName(_get_string(row, "material_id"))
		rule.size_id = StringName(_get_string(row, "size_id"))
		rule.size_group = _get_string(row, "size_group")
		rule.area_group = _get_string(row, "area_group")
		rule.width_group = _get_string(row, "width_group")
		rule.height_group = _get_string(row, "height_group")
		rule.weight_multiplier = _get_float(row, "weight_multiplier", 1.0)
		_assign_common_rule_fields(rule, row)
		material_size_weight_rules.append(rule)

	return {"ok": true, "errors": []}


func resolve_random_block_v2_simulation(
	catalog,
	stage_table,
	day_number: int,
	difficulty_id: StringName,
	rng: RandomNumberGenerator
):
	var material_candidates := get_spawn_v2_material_candidates(catalog, day_number, difficulty_id)
	var material_definition = roll_spawn_v2_material(material_candidates, rng)
	if material_definition == null:
		return null
	var size_candidates := get_spawn_v2_size_candidates(catalog, day_number, difficulty_id)
	var weighted_size_candidates: Array[Dictionary] = []
	for size_definition in size_candidates:
		var weight := calculate_spawn_v2_size_weight(size_definition, material_definition, day_number, difficulty_id)
		if weight <= 0.0:
			continue
		weighted_size_candidates.append({
			"size": size_definition,
			"weight": weight,
		})
	var size_definition = _roll_weighted_resource(weighted_size_candidates, "size", rng)
	if size_definition == null:
		return null
	var type_definition = catalog.pick_block_type_definition_or_none(rng)
	var difficulty_definition := _get_difficulty_definition(str(difficulty_id))
	var day_hp_multiplier := 1.0
	if stage_table != null:
		day_hp_multiplier = float(stage_table.get_block_hp_multiplier(day_number))
	return _build_resolved_definition_v2(
		material_definition,
		size_definition,
		type_definition,
		difficulty_definition,
		day_hp_multiplier,
		calculate_spawn_v2_material_weight(material_definition, day_number, difficulty_id),
		calculate_spawn_v2_size_weight(size_definition, material_definition, day_number, difficulty_id)
	)


func simulate_spawn_distribution_v2(
	catalog,
	stage_table,
	day_number: int,
	difficulty_id: StringName,
	iterations: int,
	rng_seed: int
) -> Array:
	var results: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	for _index in range(iterations):
		var resolved = resolve_random_block_v2_simulation(catalog, stage_table, day_number, difficulty_id, rng)
		if resolved != null:
			results.append(resolved)
	return results


func get_spawn_v2_material_candidates(catalog, day_number: int, difficulty_id: StringName) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	for raw_material in catalog.block_materials:
		var material_definition = raw_material
		if material_definition == null:
			continue
		if not _is_material_available_v2(material_definition, day_number, difficulty_id):
			continue
		var weight := calculate_spawn_v2_material_weight(material_definition, day_number, difficulty_id)
		if weight <= 0.0:
			continue
		candidates.append({
			"material": material_definition,
			"weight": weight,
		})
	return candidates


func calculate_spawn_v2_material_weight(material_definition, _day_number: int, _difficulty_id: StringName) -> float:
	if material_definition == null:
		return 0.0
	return maxf(float(material_definition.base_spawn_weight), 0.0)


func roll_spawn_v2_material(candidates: Array[Dictionary], rng: RandomNumberGenerator):
	return _roll_weighted_resource(candidates, "material", rng)


func get_spawn_v2_size_candidates(catalog, _day_number: int, _difficulty_id: StringName) -> Array:
	var candidates: Array = []
	for raw_size in catalog.block_sizes:
		var size_definition = raw_size
		if size_definition == null:
			continue
		if not _is_size_available_v2(size_definition):
			continue
		candidates.append(size_definition)
	return candidates


func calculate_spawn_v2_size_weight(size_definition, material_definition, day_number: int, difficulty_id: StringName) -> float:
	if size_definition == null:
		return 0.0
	var size_rule = size_spawn_rules_by_size_id.get(str(size_definition.size_id))
	var base_weight := maxf(float(size_definition.base_spawn_weight), 0.0)
	var size_rule_multiplier := 1.0
	if size_rule != null:
		base_weight = maxf(float(size_rule.base_spawn_weight), 0.0)
		size_rule_multiplier *= maxf(float(size_rule.get_difficulty_multiplier(difficulty_id)), 0.0)
		size_rule_multiplier *= maxf(float(size_rule.get_day_multiplier(day_number)), 0.0)
	var material_size_multiplier := apply_material_size_weight_rule(material_definition, size_definition, day_number, difficulty_id)
	return maxf(base_weight * size_rule_multiplier * material_size_multiplier, 0.0)


func apply_size_spawn_rule_weight(size_definition, day_number: int, difficulty_id: StringName) -> float:
	if size_definition == null:
		return 0.0
	var size_rule = size_spawn_rules_by_size_id.get(str(size_definition.size_id))
	if size_rule == null:
		return maxf(float(size_definition.base_spawn_weight), 0.0)
	return maxf(float(size_rule.base_spawn_weight), 0.0) \
		* maxf(float(size_rule.get_difficulty_multiplier(difficulty_id)), 0.0) \
		* maxf(float(size_rule.get_day_multiplier(day_number)), 0.0)


func apply_material_size_weight_rule(material_definition, size_definition, day_number: int, difficulty_id: StringName) -> float:
	if material_definition == null or size_definition == null:
		return 1.0
	var taxonomy := get_size_taxonomy(size_definition)
	var material_id := str(material_definition.material_id)
	var size_id := str(size_definition.size_id)
	var best_rule = null
	var best_score := -1
	for raw_rule in material_size_weight_rules:
		var rule = raw_rule
		if rule == null:
			continue
		var material_score := _get_material_rule_score(rule, material_id)
		if material_score < 0:
			continue
		var selector_score := _get_size_rule_score(rule, size_id, taxonomy)
		if selector_score <= 0:
			continue
		var score := material_score + selector_score
		if score > best_score:
			best_score = score
			best_rule = rule
	if best_rule == null:
		return 1.0
	return maxf(float(best_rule.weight_multiplier), 0.0) \
		* maxf(float(best_rule.get_difficulty_multiplier(difficulty_id)), 0.0) \
		* maxf(float(best_rule.get_day_multiplier(day_number)), 0.0)


func get_size_taxonomy(size_definition) -> Dictionary:
	var width := maxi(int(size_definition.width_u), 1)
	var height := maxi(int(size_definition.height_u), 1)
	var area := int(size_definition.area)
	if area <= 0:
		area = width * height
	return get_size_taxonomy_from_values(width, height, area)


func get_size_taxonomy_from_values(width: int, height: int, area: int) -> Dictionary:
	return {
		"width_u": width,
		"height_u": height,
		"area": area,
		"width_group": _get_width_group(width),
		"height_group": _get_height_group(height),
		"area_group": _get_area_group(area),
		"size_group": _get_size_group(width, height, area),
		"horizontal_pressure_score": max(width - 1, 0),
		"vertical_pressure_score": max(height - 1, 0),
	}


func _build_resolved_definition_v2(
	material_definition,
	size_definition,
	type_definition,
	difficulty_definition: Dictionary,
	day_hp_multiplier: float,
	material_spawn_weight: float,
	size_spawn_weight: float
):
	var resolved := BLOCK_RESOLVED_DEFINITION_SCRIPT.new()
	var type_hp_multiplier := 1.0
	var type_reward_multiplier := 1.0
	var type_sand_units_multiplier := 1.0
	var full_display_name := str(material_definition.display_name)
	var special_result_type: StringName = material_definition.special_result_type
	if type_definition != null:
		type_hp_multiplier = float(type_definition.hp_multiplier)
		type_reward_multiplier = float(type_definition.reward_multiplier)
		type_sand_units_multiplier = float(type_definition.sand_units_multiplier)
		if str(type_definition.name_prefix).strip_edges() != "":
			full_display_name = "%s %s" % [str(type_definition.name_prefix), full_display_name]
		if str(type_definition.name_suffix).strip_edges() != "":
			full_display_name = "%s %s" % [full_display_name, str(type_definition.name_suffix)]
		if type_definition.special_result_override != StringName() and type_definition.special_result_override != &"none":
			special_result_type = type_definition.special_result_override
	var size_hp_multiplier := maxf(float(size_definition.hp_multiplier), 1.0)
	var size_reward_multiplier := maxf(float(size_definition.reward_multiplier), 1.0)
	var material_hp_multiplier := maxf(float(material_definition.hp_multiplier), 0.01)
	var material_reward_multiplier := maxf(float(material_definition.reward_multiplier), 0.0)
	var difficulty_hp_multiplier := float(difficulty_definition.get("block_hp_multiplier", 1.0))
	var safe_day_hp_multiplier := day_hp_multiplier
	if safe_day_hp_multiplier <= 0.0:
		safe_day_hp_multiplier = 1.0
	var final_hp := GC.BLOCK_HP_PER_UNIT * size_hp_multiplier * material_hp_multiplier * difficulty_hp_multiplier * type_hp_multiplier * safe_day_hp_multiplier
	var final_reward := GC.BLOCK_REWARD_PER_UNIT * size_reward_multiplier * material_reward_multiplier * type_reward_multiplier
	var final_sand_units := GC.BLOCK_SAND_UNITS_PER_UNIT * size_reward_multiplier * type_sand_units_multiplier
	resolved.material_id = material_definition.material_id
	resolved.size_id = size_definition.size_id
	resolved.type_id = StringName() if type_definition == null else type_definition.id
	resolved.display_name = full_display_name
	resolved.size_cells = size_definition.get_size_cells()
	resolved.final_hp = maxi(int(ceil(final_hp)), 1)
	resolved.final_reward = maxi(int(round(final_reward)), 0)
	resolved.final_sand_units = maxi(int(round(final_sand_units)), 1)
	resolved.color_key = material_definition.color_key
	resolved.block_color = material_definition.block_color
	resolved.special_result_type = special_result_type
	resolved.base_unit_hp = GC.BLOCK_HP_PER_UNIT
	resolved.base_unit_reward = GC.BLOCK_REWARD_PER_UNIT
	resolved.size_hp_multiplier = size_hp_multiplier
	resolved.size_reward_multiplier = size_reward_multiplier
	resolved.material_hp_multiplier = material_hp_multiplier
	resolved.material_reward_multiplier = material_reward_multiplier
	resolved.difficulty_hp_multiplier = difficulty_hp_multiplier
	resolved.day_hp_multiplier = safe_day_hp_multiplier
	resolved.material_spawn_weight = material_spawn_weight
	resolved.size_spawn_weight = size_spawn_weight
	resolved.final_spawn_weight = material_spawn_weight * size_spawn_weight
	resolved.material_definition = material_definition
	resolved.size_definition = size_definition
	resolved.type_definition = type_definition
	return resolved


func _is_material_available_v2(material_definition, day_number: int, difficulty_id: StringName) -> bool:
	if material_definition == null:
		return false
	if not bool(material_definition.is_enabled):
		return false
	if not _matches_difficulty_limit(material_definition.min_difficulty, difficulty_id):
		return false
	if int(material_definition.min_stage) > 0 and day_number < int(material_definition.min_stage):
		return false
	if int(material_definition.max_stage) > 0 and day_number > int(material_definition.max_stage):
		return false
	return true


func _is_size_available_v2(size_definition) -> bool:
	if size_definition == null:
		return false
	if not bool(size_definition.is_enabled):
		return false
	var width := int(size_definition.width_u)
	var height := int(size_definition.height_u)
	if width <= 0 or height <= 0:
		return false
	if width > GC.CENTER_COLUMNS:
		return false
	if height > GENERAL_SPAWN_MAX_HEIGHT_U:
		return false
	return true


func _roll_weighted_resource(candidates: Array[Dictionary], resource_key: String, rng: RandomNumberGenerator):
	if candidates.is_empty():
		return null
	var total_weight := 0.0
	for raw_candidate in candidates:
		var candidate: Dictionary = raw_candidate
		total_weight += maxf(float(candidate.get("weight", 0.0)), 0.0)
	if total_weight <= 0.0:
		return candidates[0].get(resource_key)
	var roll := rng.randf_range(0.0, total_weight)
	for raw_candidate in candidates:
		var candidate: Dictionary = raw_candidate
		roll -= maxf(float(candidate.get("weight", 0.0)), 0.0)
		if roll <= 0.0:
			return candidate.get(resource_key)
	return candidates[candidates.size() - 1].get(resource_key)


func _matches_difficulty_limit(min_difficulty: StringName, difficulty_id: StringName) -> bool:
	if min_difficulty == StringName() or min_difficulty == &"any":
		return true
	return _get_difficulty_rank(str(difficulty_id)) >= _get_difficulty_rank(str(min_difficulty))


func _get_difficulty_rank(difficulty_id: String) -> int:
	var normalized_id := difficulty_id.strip_edges()
	for index in range(DIFFICULTY_ORDER.size()):
		if DIFFICULTY_ORDER[index] == normalized_id:
			return index
	return 0


func _get_difficulty_definition(difficulty_id: String) -> Dictionary:
	for raw_option in GC.DIFFICULTY_OPTIONS:
		var option: Dictionary = raw_option
		if str(option.get("id", "")) == difficulty_id:
			return option
	return GC.DIFFICULTY_OPTIONS[0]


func _get_material_rule_score(rule, material_id: String) -> int:
	var rule_material_id := str(rule.material_id).strip_edges()
	if rule_material_id == material_id:
		return 1000
	if rule_material_id == "*" or rule_material_id.is_empty():
		return 0
	return -1


func _get_size_rule_score(rule, size_id: String, taxonomy: Dictionary) -> int:
	var rule_size_id := str(rule.size_id).strip_edges()
	if not rule_size_id.is_empty():
		return 500 if rule_size_id == size_id else -1
	var rule_size_group := str(rule.size_group).strip_edges()
	if not rule_size_group.is_empty():
		return 400 if rule_size_group == str(taxonomy.get("size_group", "")) else -1
	var rule_area_group := str(rule.area_group).strip_edges()
	if not rule_area_group.is_empty():
		return 300 if rule_area_group == str(taxonomy.get("area_group", "")) else -1
	var rule_width_group := str(rule.width_group).strip_edges()
	if not rule_width_group.is_empty():
		return 200 if rule_width_group == str(taxonomy.get("width_group", "")) else -1
	var rule_height_group := str(rule.height_group).strip_edges()
	if not rule_height_group.is_empty():
		return 100 if rule_height_group == str(taxonomy.get("height_group", "")) else -1
	return -1


func _get_width_group(width: int) -> String:
	if width <= 1:
		return "w1"
	if width == 2:
		return "w2"
	if width <= 4:
		return "w3_4"
	if width <= 6:
		return "w5_6"
	if width <= 8:
		return "w7_8"
	if width <= 10:
		return "w9_10"
	return "overflow"


func _get_height_group(height: int) -> String:
	if height <= 1:
		return "h1"
	if height == 2:
		return "h2"
	if height == 3:
		return "h3"
	return "h4_plus"


func _get_area_group(area: int) -> String:
	if area <= 1:
		return "a1"
	if area <= 3:
		return "a2_3"
	if area <= 6:
		return "a4_6"
	if area <= 10:
		return "a7_10"
	if area <= 15:
		return "a11_15"
	if area <= 20:
		return "a16_20"
	return "a21_30"


func _get_size_group(width: int, height: int, area: int) -> String:
	if width == 1 and height == 1:
		return "tiny"
	if height > GENERAL_SPAWN_MAX_HEIGHT_U or width >= 9 or area >= 21:
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


func _assign_common_rule_fields(rule, row: Dictionary) -> void:
	rule.normal_multiplier = _get_float(row, "normal_multiplier", 1.0)
	rule.hard_multiplier = _get_float(row, "hard_multiplier", 1.0)
	rule.extreme_multiplier = _get_float(row, "extreme_multiplier", 1.0)
	rule.hell_multiplier = _get_float(row, "hell_multiplier", 1.0)
	rule.nightmare_multiplier = _get_float(row, "nightmare_multiplier", 1.0)
	rule.day_1_5_multiplier = _get_float(row, "day_1_5_multiplier", 1.0)
	rule.day_6_10_multiplier = _get_float(row, "day_6_10_multiplier", 1.0)
	rule.day_11_15_multiplier = _get_float(row, "day_11_15_multiplier", 1.0)
	rule.day_16_20_multiplier = _get_float(row, "day_16_20_multiplier", 1.0)
	rule.day_21_25_multiplier = _get_float(row, "day_21_25_multiplier", 1.0)
	rule.day_26_30_multiplier = _get_float(row, "day_26_30_multiplier", 1.0)
	rule.min_day_hint = _get_int(row, "min_day_hint", 1)
	rule.notes = _get_string(row, "notes")


func _get_string(row: Dictionary, column: String) -> String:
	return str(row.get(column, "")).strip_edges()


func _get_float(row: Dictionary, column: String, default_value: float) -> float:
	var value := str(row.get(column, "")).strip_edges()
	if value.is_empty():
		return default_value
	if value.is_valid_float() or value.is_valid_int():
		return float(value)
	return default_value


func _get_int(row: Dictionary, column: String, default_value: int) -> int:
	var value := str(row.get(column, "")).strip_edges()
	if value.is_empty():
		return default_value
	if value.is_valid_int():
		return int(value)
	return default_value


func _join_path(base_dir: String, file_name: String) -> String:
	if base_dir.ends_with("/") or base_dir.ends_with("\\"):
		return "%s%s" % [base_dir, file_name]
	if "\\" in base_dir:
		return "%s\\%s" % [base_dir, file_name]
	return "%s/%s" % [base_dir, file_name]
