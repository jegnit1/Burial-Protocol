extends Resource
class_name BlockBaseDefinition

# 블록 베이스는 실제 스폰되는 블록 본체다.
@export var id: StringName
@export var display_name := ""
@export var size_cells := Vector2i.ONE
@export var hp_multiplier := 1.0
@export var reward := 0
@export var sand_units := 1
@export var color_key: StringName = &"amber"
@export var block_color := Color.WHITE
@export var spawn_weight := 1.0
@export var special_result_type: StringName = &"none"
