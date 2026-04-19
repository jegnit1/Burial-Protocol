extends Resource
class_name StageTable

# 전체 런의 Day 테이블을 한 파일로 묶는다.
@export var total_days := 30
@export var default_day_duration := 40.0
@export var days: Array[Resource] = []

var _day_by_number: Dictionary = {}


func get_total_days() -> int:
	if total_days > 0:
		return total_days
	return days.size()


func get_day_definition(day_number: int):
	_ensure_cache()
	if _day_by_number.has(day_number):
		return _day_by_number[day_number]
	return null


func get_day_type(day_number: int) -> StringName:
	var definition = get_day_definition(day_number)
	if definition == null:
		return &"normal"
	return definition.day_type


func get_day_duration(day_number: int) -> float:
	var definition = get_day_definition(day_number)
	if definition == null or definition.duration <= 0.0:
		return default_day_duration
	return definition.duration


func get_block_hp_multiplier(day_number: int) -> float:
	var definition = get_day_definition(day_number)
	if definition == null or definition.block_hp_multiplier <= 0.0:
		return 1.0
	return definition.block_hp_multiplier


func get_spawn_interval_multiplier(day_number: int) -> float:
	var definition = get_day_definition(day_number)
	if definition == null or definition.spawn_interval_multiplier <= 0.0:
		return 1.0
	return definition.spawn_interval_multiplier


func get_boss_block_base_id(day_number: int) -> StringName:
	var definition = get_day_definition(day_number)
	if definition == null:
		return StringName()
	return definition.boss_block_base_id


func get_boss_block_type_id(day_number: int) -> StringName:
	var definition = get_day_definition(day_number)
	if definition == null:
		return StringName()
	return definition.boss_block_type_id


func is_boss_day(day_number: int) -> bool:
	return get_day_type(day_number) == &"boss"


func get_next_boss_day(from_day: int) -> int:
	for definition in days:
		if definition == null:
			continue
		if definition.day_type == &"boss" and definition.day_number >= from_day:
			return definition.day_number
	return -1


func _ensure_cache() -> void:
	if _day_by_number.size() == days.size():
		return
	_day_by_number.clear()
	for definition in days:
		if definition == null:
			continue
		_day_by_number[definition.day_number] = definition
