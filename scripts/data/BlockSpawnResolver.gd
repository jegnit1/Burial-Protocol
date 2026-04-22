extends RefCounted
class_name BlockSpawnResolver

const BLOCK_RESOLVED_DEFINITION_SCRIPT = preload("res://scripts/data/BlockResolvedDefinition.gd")


func resolve_random_block(
	catalog,
	rng: RandomNumberGenerator,
	difficulty_id: StringName,
	stage_number: int,
	difficulty_definition: Dictionary,
	type_definition = null
):
	var candidates = catalog.get_spawn_candidates(difficulty_id, stage_number)
	if candidates.is_empty():
		push_warning("BlockSpawnResolver could not find a spawn candidate for difficulty=%s stage=%d." % [str(difficulty_id), stage_number])
		return null
	var total_weight := 0.0
	for raw_candidate in candidates:
		var candidate: Dictionary = raw_candidate
		total_weight += float(candidate.get("weight", 0.0))
	if total_weight <= 0.0:
		return _build_resolved_definition(candidates[0], difficulty_definition, type_definition)
	var roll := rng.randf_range(0.0, total_weight)
	for raw_candidate in candidates:
		var candidate: Dictionary = raw_candidate
		roll -= float(candidate.get("weight", 0.0))
		if roll <= 0.0:
			return _build_resolved_definition(candidate, difficulty_definition, type_definition)
	return _build_resolved_definition(candidates[candidates.size() - 1], difficulty_definition, type_definition)


func resolve_specific_block(
	catalog,
	material_id: StringName,
	size_id: StringName,
	difficulty_id: StringName,
	stage_number: int,
	difficulty_definition: Dictionary,
	type_definition = null
):
	var material_definition = catalog.get_block_material_definition(material_id)
	var size_definition = catalog.get_block_size_definition(size_id)
	if material_definition == null or size_definition == null:
		push_warning("BlockSpawnResolver could not resolve specific block material=%s size=%s." % [str(material_id), str(size_id)])
		return null
	if not catalog.is_material_size_allowed(material_definition, size_definition, difficulty_id, stage_number):
		push_warning("BlockSpawnResolver rejected material=%s size=%s for difficulty=%s stage=%d." % [
			str(material_id),
			str(size_id),
			str(difficulty_id),
			stage_number,
		])
		return null
	var candidate := {
		"material": material_definition,
		"size": size_definition,
		"weight": catalog.get_spawn_weight_for_candidate(material_definition, size_definition, difficulty_id, stage_number),
	}
	return _build_resolved_definition(candidate, difficulty_definition, type_definition)


func _build_resolved_definition(candidate: Dictionary, difficulty_definition: Dictionary, type_definition):
	var material_definition = candidate.get("material")
	var size_definition = candidate.get("size")
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
	var difficulty_hp_multiplier := 1.0
	if difficulty_definition != null:
		difficulty_hp_multiplier = float(difficulty_definition.get("block_hp_multiplier", 1.0))
	var final_hp := GameConstants.BLOCK_HP_PER_UNIT * size_hp_multiplier * material_hp_multiplier * difficulty_hp_multiplier * type_hp_multiplier
	var final_reward := GameConstants.BLOCK_REWARD_PER_UNIT * size_reward_multiplier * material_reward_multiplier * type_reward_multiplier
	var final_sand_units := GameConstants.BLOCK_SAND_UNITS_PER_UNIT * size_reward_multiplier * type_sand_units_multiplier
	resolved.material_id = material_definition.material_id
	resolved.size_id = size_definition.size_id
	resolved.type_id = StringName()
	resolved.display_name = full_display_name
	resolved.size_cells = size_definition.get_size_cells()
	resolved.final_hp = maxi(int(ceil(final_hp)), 1)
	resolved.final_reward = maxi(int(round(final_reward)), 0)
	resolved.final_sand_units = maxi(int(round(final_sand_units)), 1)
	resolved.color_key = material_definition.color_key
	resolved.block_color = material_definition.block_color
	resolved.special_result_type = special_result_type
	resolved.base_unit_hp = GameConstants.BLOCK_HP_PER_UNIT
	resolved.base_unit_reward = GameConstants.BLOCK_REWARD_PER_UNIT
	resolved.size_hp_multiplier = size_hp_multiplier
	resolved.size_reward_multiplier = size_reward_multiplier
	resolved.material_hp_multiplier = material_hp_multiplier
	resolved.material_reward_multiplier = material_reward_multiplier
	resolved.difficulty_hp_multiplier = difficulty_hp_multiplier
	resolved.material_spawn_weight = float(material_definition.base_spawn_weight)
	resolved.size_spawn_weight = float(size_definition.base_spawn_weight)
	resolved.final_spawn_weight = float(candidate.get("weight", 1.0))
	resolved.material_definition = material_definition
	resolved.size_definition = size_definition
	resolved.type_definition = type_definition
	if type_definition != null:
		resolved.type_id = type_definition.id
	return resolved
