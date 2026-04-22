extends RefCounted
class_name BlockResolvedDefinition

# 스폰 후보를 해석한 뒤 실제 생성 직전에 사용하는 최종 블록 정의.
var material_id: StringName
var size_id: StringName
var type_id: StringName
var display_name := ""
var size_cells := Vector2i.ONE
var final_hp := 1
var final_reward := 0
var final_sand_units := 1
var color_key: StringName = &"amber"
var block_color := Color.WHITE
var special_result_type: StringName = &"none"
var base_unit_hp := 0.0
var base_unit_reward := 0.0
var size_hp_multiplier := 1.0
var size_reward_multiplier := 1.0
var material_hp_multiplier := 1.0
var material_reward_multiplier := 1.0
var difficulty_hp_multiplier := 1.0
var material_spawn_weight := 1.0
var size_spawn_weight := 1.0
var final_spawn_weight := 1.0
var material_definition: Resource
var size_definition: Resource
var type_definition: Resource
