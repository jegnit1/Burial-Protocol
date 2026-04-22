extends Resource
class_name BlockMaterialData

# 블록 재질 전용 데이터. 사이즈는 여기서 소유하지 않는다.
@export var material_id: StringName
@export var display_name := ""
@export var hp_multiplier := 1.0
@export var reward_multiplier := 1.0
@export var base_spawn_weight := 1.0
@export var special_result_type: StringName = &"none"
@export var color_key: StringName = &"amber"
@export var block_color := Color.WHITE
@export var min_difficulty: StringName = &"normal"
@export var min_stage := 1
@export var max_stage := 0
@export var max_allowed_area := 0
@export var max_allowed_width := 0
@export var max_allowed_height := 0
@export var is_enabled := true
@export_multiline var notes := ""
