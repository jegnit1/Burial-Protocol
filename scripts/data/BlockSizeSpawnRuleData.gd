extends Resource
class_name BlockSizeSpawnRuleData

@export var size_id: StringName
@export var size_group := ""
@export var base_spawn_weight := 1.0
@export var normal_multiplier := 1.0
@export var hard_multiplier := 1.0
@export var extreme_multiplier := 1.0
@export var hell_multiplier := 1.0
@export var nightmare_multiplier := 1.0
@export var day_1_5_multiplier := 1.0
@export var day_6_10_multiplier := 1.0
@export var day_11_15_multiplier := 1.0
@export var day_16_20_multiplier := 1.0
@export var day_21_25_multiplier := 1.0
@export var day_26_30_multiplier := 1.0
@export var min_day_hint := 1
@export_multiline var notes := ""


func get_difficulty_multiplier(difficulty_id: StringName) -> float:
	match str(difficulty_id):
		"hard":
			return hard_multiplier
		"extreme":
			return extreme_multiplier
		"hell":
			return hell_multiplier
		"nightmare":
			return nightmare_multiplier
		_:
			return normal_multiplier


func get_day_multiplier(day_number: int) -> float:
	if day_number <= 5:
		return day_1_5_multiplier
	if day_number <= 10:
		return day_6_10_multiplier
	if day_number <= 15:
		return day_11_15_multiplier
	if day_number <= 20:
		return day_16_20_multiplier
	if day_number <= 25:
		return day_21_25_multiplier
	return day_26_30_multiplier
