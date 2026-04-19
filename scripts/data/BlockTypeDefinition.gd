extends Resource
class_name BlockTypeDefinition

# 블록 타입은 본체에 선택적으로 붙는 affix/modifier다.
@export var id: StringName
@export var display_name := ""
@export var name_prefix := ""
@export var name_suffix := ""
@export var can_spawn_randomly := true
@export var spawn_weight_multiplier := 1.0
@export var hp_multiplier := 1.0
@export var reward_multiplier := 1.0
@export var sand_units_multiplier := 1.0
@export var special_result_override: StringName = &"none"
