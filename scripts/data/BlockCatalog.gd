extends Resource
class_name BlockCatalog

# 에디터에서 다루는 블록 본체/affix 묶음 데이터다.
@export var default_block_base_id: StringName
@export var random_type_chance := 0.0
@export var block_bases: Array[Resource] = []
@export var block_types: Array[Resource] = []

var _block_base_by_id: Dictionary = {}
var _block_type_by_id: Dictionary = {}


func get_block_base_definition(base_id: StringName):
	_ensure_cache()
	var resolved_base_id := base_id
	if resolved_base_id == StringName():
		resolved_base_id = default_block_base_id
	if _block_base_by_id.has(resolved_base_id):
		return _block_base_by_id[resolved_base_id]
	if _block_base_by_id.has(default_block_base_id):
		return _block_base_by_id[default_block_base_id]
	return null


func get_block_type_definition(type_id: StringName):
	_ensure_cache()
	if _block_type_by_id.has(type_id):
		return _block_type_by_id[type_id]
	return null


func get_block_base_spawn_weight(definition) -> float:
	if definition == null:
		return 0.0
	return maxf(definition.spawn_weight, 0.0)


func get_block_type_spawn_weight(definition) -> float:
	if definition == null:
		return 0.0
	if not definition.can_spawn_randomly:
		return 0.0
	return maxf(definition.spawn_weight_multiplier, 0.0)


func pick_block_base_definition(rng: RandomNumberGenerator):
	if block_bases.is_empty():
		return null
	var total_weight := 0.0
	for definition in block_bases:
		total_weight += get_block_base_spawn_weight(definition)
	if total_weight <= 0.0:
		return block_bases[0]
	var remaining_weight := rng.randf_range(0.0, total_weight)
	for definition in block_bases:
		remaining_weight -= get_block_base_spawn_weight(definition)
		if remaining_weight <= 0.0:
			return definition
	return block_bases[block_bases.size() - 1]


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


func _ensure_cache() -> void:
	if _block_base_by_id.size() != block_bases.size():
		_block_base_by_id.clear()
		for definition in block_bases:
			if definition == null:
				continue
			_block_base_by_id[definition.id] = definition
	if _block_type_by_id.size() != block_types.size():
		_block_type_by_id.clear()
		for definition in block_types:
			if definition == null:
				continue
			_block_type_by_id[definition.id] = definition
