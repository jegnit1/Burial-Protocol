extends Resource
class_name BlockCatalog

# 블록 카탈로그는 재질, 사이즈, 옵션 타입만 소유한다.
# 스폰은 material × size 조합을 런타임에 해석해서 결정한다.
const DIFFICULTY_ORDER := ["normal", "hard", "extreme", "hell", "nightmare"]

@export var default_block_base_id: StringName
@export var default_block_size_id: StringName
@export var random_type_chance := 0.0
@export var block_materials: Array[Resource] = []
@export var block_sizes: Array[Resource] = []
@export var block_types: Array[Resource] = []

var _block_material_by_id: Dictionary = {}
var _block_size_by_id: Dictionary = {}
var _block_type_by_id: Dictionary = {}


func get_block_material_definition(material_id: StringName):
	_ensure_cache()
	var resolved_material_id := material_id
	if resolved_material_id == StringName():
		resolved_material_id = default_block_base_id
	if _block_material_by_id.has(resolved_material_id):
		return _block_material_by_id[resolved_material_id]
	if _block_material_by_id.has(default_block_base_id):
		return _block_material_by_id[default_block_base_id]
	return null


func get_block_base_definition(base_id: StringName):
	return get_block_material_definition(base_id)


func get_block_size_definition(size_id: StringName):
	_ensure_cache()
	var resolved_size_id := size_id
	if resolved_size_id == StringName():
		resolved_size_id = default_block_size_id
	if _block_size_by_id.has(resolved_size_id):
		return _block_size_by_id[resolved_size_id]
	if _block_size_by_id.has(default_block_size_id):
		return _block_size_by_id[default_block_size_id]
	return null


func get_block_type_definition(type_id: StringName):
	_ensure_cache()
	if _block_type_by_id.has(type_id):
		return _block_type_by_id[type_id]
	return null


func get_block_material_spawn_weight(definition) -> float:
	if definition == null:
		return 0.0
	return maxf(float(definition.base_spawn_weight), 0.0)


func get_block_base_spawn_weight(definition) -> float:
	return get_block_material_spawn_weight(definition)


func get_block_size_spawn_weight(definition) -> float:
	if definition == null:
		return 0.0
	return maxf(float(definition.base_spawn_weight), 0.0)


func get_block_type_spawn_weight(definition) -> float:
	if definition == null:
		return 0.0
	if not definition.can_spawn_randomly:
		return 0.0
	return maxf(definition.spawn_weight_multiplier, 0.0)


func pick_block_base_definition(rng: RandomNumberGenerator):
	if block_materials.is_empty():
		return null
	var total_weight := 0.0
	for definition in block_materials:
		total_weight += get_block_material_spawn_weight(definition)
	if total_weight <= 0.0:
		return block_materials[0]
	var remaining_weight := rng.randf_range(0.0, total_weight)
	for definition in block_materials:
		remaining_weight -= get_block_material_spawn_weight(definition)
		if remaining_weight <= 0.0:
			return definition
	return block_materials[block_materials.size() - 1]


func pick_block_size_definition(rng: RandomNumberGenerator):
	if block_sizes.is_empty():
		return null
	var total_weight := 0.0
	for definition in block_sizes:
		total_weight += get_block_size_spawn_weight(definition)
	if total_weight <= 0.0:
		return block_sizes[0]
	var remaining_weight := rng.randf_range(0.0, total_weight)
	for definition in block_sizes:
		remaining_weight -= get_block_size_spawn_weight(definition)
		if remaining_weight <= 0.0:
			return definition
	return block_sizes[block_sizes.size() - 1]


func pick_block_type_definition_or_none(rng: RandomNumberGenerator):
	if block_types.is_empty():
		return null
	if random_type_chance <= 0.0:
		return null
	if rng.randf() > random_type_chance:
		return null
	var total_weight := 0.0
	for definition in block_types:
		total_weight += get_block_type_spawn_weight(definition)
	if total_weight <= 0.0:
		return null
	var remaining_weight := rng.randf_range(0.0, total_weight)
	for definition in block_types:
		remaining_weight -= get_block_type_spawn_weight(definition)
		if remaining_weight <= 0.0:
			return definition
	return null


func get_spawn_candidates(difficulty_id: StringName, stage_number: int) -> Array[Dictionary]:
	_ensure_cache()
	var candidates: Array[Dictionary] = []
	for raw_material in block_materials:
		var material_definition = raw_material
		if material_definition == null:
			continue
		for raw_size in block_sizes:
			var size_definition = raw_size
			if size_definition == null:
				continue
			if not is_material_size_allowed(material_definition, size_definition, difficulty_id, stage_number):
				continue
			var weight := get_spawn_weight_for_candidate(
				material_definition,
				size_definition,
				difficulty_id,
				stage_number
			)
			if weight <= 0.0:
				continue
			candidates.append({
				"material": material_definition,
				"size": size_definition,
				"weight": weight,
			})
	return candidates


func is_material_size_allowed(material_definition, size_definition, difficulty_id: StringName, stage_number: int) -> bool:
	if material_definition == null or size_definition == null:
		return false
	if not bool(material_definition.is_enabled) or not bool(size_definition.is_enabled):
		return false
	if not _matches_material_limits(material_definition, difficulty_id, stage_number):
		return false
	if not _matches_size_limits(size_definition, difficulty_id, stage_number):
		return false
	var size_area := _get_size_area(size_definition)
	var size_width := int(size_definition.width_u)
	var size_height := int(size_definition.height_u)
	if int(material_definition.max_allowed_area) > 0 and size_area > int(material_definition.max_allowed_area):
		return false
	if int(material_definition.max_allowed_width) > 0 and size_width > int(material_definition.max_allowed_width):
		return false
	if int(material_definition.max_allowed_height) > 0 and size_height > int(material_definition.max_allowed_height):
		return false
	return true


func get_spawn_weight_for_candidate(
	material_definition,
	size_definition,
	difficulty_id: StringName = StringName(),
	stage_number: int = 1
) -> float:
	if material_definition == null or size_definition == null:
		return 0.0
	var weight := get_block_material_spawn_weight(material_definition)
	weight *= get_block_size_spawn_weight(size_definition)
	weight *= _get_progression_weight_multiplier(material_definition, size_definition, difficulty_id, stage_number)
	return maxf(weight, 0.0)


func _ensure_cache() -> void:
	if _block_material_by_id.size() != block_materials.size():
		_block_material_by_id.clear()
		for definition in block_materials:
			if definition == null:
				continue
			_block_material_by_id[definition.material_id] = definition
	if _block_size_by_id.size() != block_sizes.size():
		_block_size_by_id.clear()
		for definition in block_sizes:
			if definition == null:
				continue
			_block_size_by_id[definition.size_id] = definition
	if _block_type_by_id.size() != block_types.size():
		_block_type_by_id.clear()
		for definition in block_types:
			if definition == null:
				continue
			_block_type_by_id[definition.id] = definition


func _matches_material_limits(material_definition, difficulty_id: StringName, stage_number: int) -> bool:
	if material_definition == null:
		return false
	if not _matches_difficulty_limit(material_definition.min_difficulty, difficulty_id):
		return false
	if int(material_definition.min_stage) > 0 and stage_number < int(material_definition.min_stage):
		return false
	if int(material_definition.max_stage) > 0 and stage_number > int(material_definition.max_stage):
		return false
	return true


func _matches_size_limits(size_definition, difficulty_id: StringName, stage_number: int) -> bool:
	if size_definition == null:
		return false
	if not _matches_difficulty_limit(size_definition.min_difficulty, difficulty_id):
		return false
	if int(size_definition.min_stage) > 0 and stage_number < int(size_definition.min_stage):
		return false
	if int(size_definition.max_stage) > 0 and stage_number > int(size_definition.max_stage):
		return false
	return true


func _matches_difficulty_limit(min_difficulty: StringName, difficulty_id: StringName) -> bool:
	if min_difficulty == StringName():
		return true
	if min_difficulty == &"any":
		return true
	return _get_difficulty_rank(str(difficulty_id)) >= _get_difficulty_rank(str(min_difficulty))


func _get_size_area(size_definition) -> int:
	if size_definition == null:
		return 0
	if int(size_definition.area) > 0:
		return int(size_definition.area)
	return max(int(size_definition.width_u) * int(size_definition.height_u), 1)


func _get_difficulty_rank(difficulty_id: String) -> int:
	var normalized_id := difficulty_id.strip_edges()
	for index in range(DIFFICULTY_ORDER.size()):
		if DIFFICULTY_ORDER[index] == normalized_id:
			return index
	return 0


func _get_progression_weight_multiplier(material_definition, size_definition, difficulty_id: StringName, stage_number: int) -> float:
	var progression := _get_progression_ratio(difficulty_id, stage_number)
	var material_unlock_score := _get_unlock_score(material_definition.min_difficulty, int(material_definition.min_stage))
	var size_unlock_score := _get_unlock_score(size_definition.min_difficulty, int(size_definition.min_stage))
	var size_area := float(_get_size_area(size_definition))
	var wide_pressure := maxf(float(int(size_definition.width_u) - 1), 0.0)
	var progression_bonus := 1.0
	progression_bonus += progression * material_unlock_score * 0.35
	progression_bonus += progression * size_unlock_score * 0.55
	progression_bonus += progression * maxf(size_area - 1.0, 0.0) * 0.08
	progression_bonus += progression * wide_pressure * 0.06
	return maxf(progression_bonus, 0.1)


func _get_progression_ratio(difficulty_id: StringName, stage_number: int) -> float:
	var max_unlock_stage := _get_max_unlock_stage()
	var stage_progress := 1.0
	if max_unlock_stage > 1:
		stage_progress = clampf(float(max(stage_number - 1, 0)) / float(max_unlock_stage - 1), 0.0, 1.0)
	var difficulty_progress := 0.0
	if DIFFICULTY_ORDER.size() > 1:
		difficulty_progress = clampf(
			float(_get_difficulty_rank(str(difficulty_id))) / float(DIFFICULTY_ORDER.size() - 1),
			0.0,
			1.0
		)
	return clampf((stage_progress + difficulty_progress) * 0.5, 0.0, 1.0)


func _get_unlock_score(min_difficulty: StringName, min_stage: int) -> float:
	var difficulty_score := 0.0
	if DIFFICULTY_ORDER.size() > 1:
		difficulty_score = clampf(
			float(_get_difficulty_rank(str(min_difficulty))) / float(DIFFICULTY_ORDER.size() - 1),
			0.0,
			1.0
		)
	var stage_score := 0.0
	var max_unlock_stage := _get_max_unlock_stage()
	if max_unlock_stage > 1:
		stage_score = clampf(float(max(min_stage - 1, 0)) / float(max_unlock_stage - 1), 0.0, 1.0)
	return clampf((difficulty_score + stage_score) * 0.5, 0.0, 1.0)


func _get_max_unlock_stage() -> int:
	var max_unlock_stage := 1
	for raw_material in block_materials:
		var material_definition = raw_material
		if material_definition == null:
			continue
		max_unlock_stage = maxi(max_unlock_stage, int(material_definition.min_stage))
	for raw_size in block_sizes:
		var size_definition = raw_size
		if size_definition == null:
			continue
		max_unlock_stage = maxi(max_unlock_stage, int(size_definition.min_stage))
	return max_unlock_stage
