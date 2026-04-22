extends Resource
class_name BlockSizeData

# 블록 크기 전용 데이터. 재질과 독립적으로 관리한다.
@export var size_id: StringName
@export var width_u := 1
@export var height_u := 1
@export var area := 1
@export var hp_multiplier := 1.0
@export var reward_multiplier := 1.0
@export var base_spawn_weight := 1.0
@export var min_difficulty: StringName = &"normal"
@export var min_stage := 1
@export var max_stage := 0
@export var is_enabled := true
@export var tags: PackedStringArray = PackedStringArray()
@export_multiline var notes := ""


func get_size_cells() -> Vector2i:
	return Vector2i(maxi(width_u, 1), maxi(height_u, 1))
