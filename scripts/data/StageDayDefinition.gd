extends Resource
class_name StageDayDefinition

# 하루 단위 콘텐츠 데이터만 가진다.
@export var day_number := 1
@export var day_type: StringName = &"normal"
@export var duration := 40.0
@export var block_hp_multiplier := 1.0
@export var boss_block_base_id: StringName
@export var boss_block_size_id: StringName
@export var boss_block_type_id: StringName
@export var spawn_interval_multiplier := 1.0
@export var reward_multiplier := 1.0
@export var special_rules: PackedStringArray = PackedStringArray()
