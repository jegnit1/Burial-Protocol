extends RefCounted
class_name BlockData

var id: StringName
var display_name := ""
var size_cells := Vector2i.ONE
var health := 1
var sand_units := 1
var reward := 0
var color_key: StringName = &"amber"
var block_color := Color.WHITE
var sand_weight := 1.0

var block_base: StringName
var block_base_definition: Resource
var block_base_display_name := ""
var block_base_color := Color.WHITE
var block_base_spawn_weight := 1.0
var block_base_hp_multiplier := 1.0

var block_type: StringName
var block_type_definition: Resource
var block_type_display_name := ""
var block_type_spawn_weight_multiplier := 1.0
var block_type_hp_multiplier := 1.0
var block_type_reward_multiplier := 1.0
var block_type_sand_units_multiplier := 1.0

var unit_hp := 0.0
var area_units := 1
var day_hp_multiplier := 1.0
var difficulty_hp_multiplier := 1.0
var spawn_weight := 1.0
var special_result_type: StringName = GameConstants.BLOCK_SPECIAL_RESULT_NONE


static func from_spawn_selection(base_definition, type_definition, day_definition, difficulty_definition: Dictionary) -> BlockData:
	var data := BlockData.new()
	if base_definition == null:
		push_error("BlockData.from_spawn_selection requires a block base definition.")
		return data

	var type_hp_multiplier := 1.0
	var type_reward_multiplier := 1.0
	var type_sand_units_multiplier := 1.0
	var type_spawn_weight_multiplier := 1.0
	var type_display_name := ""
	var full_display_name := String(base_definition.display_name)
	var special_result_type: StringName = base_definition.special_result_type

	if type_definition != null:
		type_hp_multiplier = float(type_definition.hp_multiplier)
		type_reward_multiplier = float(type_definition.reward_multiplier)
		type_sand_units_multiplier = float(type_definition.sand_units_multiplier)
		type_spawn_weight_multiplier = float(type_definition.spawn_weight_multiplier)
		type_display_name = String(type_definition.display_name)
		if String(type_definition.name_prefix).strip_edges() != "":
			full_display_name = "%s %s" % [String(type_definition.name_prefix), full_display_name]
		if String(type_definition.name_suffix).strip_edges() != "":
			full_display_name = "%s %s" % [full_display_name, String(type_definition.name_suffix)]
		if type_display_name.strip_edges() != "" and full_display_name == String(base_definition.display_name):
			full_display_name = type_display_name + " " + full_display_name
		if type_definition.special_result_override != StringName() and type_definition.special_result_override != &"none":
			special_result_type = type_definition.special_result_override

	var stage_hp_multiplier := 1.0
	var stage_reward_multiplier := 1.0
	if day_definition != null:
		stage_hp_multiplier = float(day_definition.block_hp_multiplier)
		stage_reward_multiplier = float(day_definition.reward_multiplier)

	var difficulty_hp_multiplier := 1.0
	if difficulty_definition != null:
		difficulty_hp_multiplier = float(difficulty_definition.get("block_hp_multiplier", 1.0))

	var area_units := maxi(base_definition.size_cells.x * base_definition.size_cells.y, 1)
	var raw_health := (
		GameConstants.BLOCK_HP_PER_UNIT
		* float(area_units)
		* float(base_definition.hp_multiplier)
		* type_hp_multiplier
		* stage_hp_multiplier
		* difficulty_hp_multiplier
	)
	var raw_reward := float(base_definition.reward) * type_reward_multiplier * stage_reward_multiplier
	var raw_sand_units := float(base_definition.sand_units) * type_sand_units_multiplier

	data.id = base_definition.id
	data.display_name = full_display_name
	data.size_cells = base_definition.size_cells
	data.health = maxi(int(ceil(raw_health)), 1)
	data.sand_units = maxi(int(round(raw_sand_units)), 1)
	data.reward = maxi(int(round(raw_reward)), 0)
	data.color_key = base_definition.color_key
	data.block_color = base_definition.block_color
	data.sand_weight = GameConstants.get_sand_weight(data.color_key)

	data.block_base = base_definition.id
	data.block_base_definition = base_definition
	data.block_base_display_name = base_definition.display_name
	data.block_base_color = base_definition.block_color
	data.block_base_spawn_weight = float(base_definition.spawn_weight)
	data.block_base_hp_multiplier = float(base_definition.hp_multiplier)

	data.block_type = StringName()
	data.block_type_definition = type_definition
	data.block_type_display_name = type_display_name
	data.block_type_spawn_weight_multiplier = type_spawn_weight_multiplier
	data.block_type_hp_multiplier = type_hp_multiplier
	data.block_type_reward_multiplier = type_reward_multiplier
	data.block_type_sand_units_multiplier = type_sand_units_multiplier
	if type_definition != null:
		data.block_type = type_definition.id
		data.id = StringName("%s__%s" % [String(base_definition.id), String(type_definition.id)])

	data.unit_hp = GameConstants.BLOCK_HP_PER_UNIT
	data.area_units = area_units
	data.day_hp_multiplier = stage_hp_multiplier
	data.difficulty_hp_multiplier = difficulty_hp_multiplier
	data.spawn_weight = float(base_definition.spawn_weight) * type_spawn_weight_multiplier
	data.special_result_type = special_result_type
	return data


func get_size_pixels() -> Vector2:
	return Vector2(size_cells * GameConstants.CELL_SIZE)


func get_effective_health() -> int:
	return health


func has_block_type() -> bool:
	return block_type != StringName()


func get_block_base_debug_text() -> String:
	var type_label := "none"
	if has_block_type():
		type_label = String(block_type)
	return "%s | HP %d | 1U %.2f | Area %dU | Base x%.3f | Type(%s) x%.3f | Day x%.3f | Diff x%.3f" % [
		display_name,
		health,
		unit_hp,
		area_units,
		block_base_hp_multiplier,
		type_label,
		block_type_hp_multiplier,
		day_hp_multiplier,
		difficulty_hp_multiplier,
	]
