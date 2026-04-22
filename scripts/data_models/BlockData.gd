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

var block_material: StringName
var block_material_definition: Resource
var block_material_display_name := ""
var block_material_reward_multiplier := 1.0

var block_size: StringName
var block_size_definition: Resource
var block_size_display_name := ""
var block_size_spawn_weight := 1.0
var block_size_hp_multiplier := 1.0
var block_size_reward_multiplier := 1.0

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


static func from_resolved_definition(resolved_definition) -> BlockData:
	var data := BlockData.new()
	if resolved_definition == null:
		push_error("BlockData.from_resolved_definition requires a resolved block definition.")
		return data

	var material_definition = resolved_definition.material_definition
	var size_definition = resolved_definition.size_definition
	var type_definition = resolved_definition.type_definition
	var material_id: StringName = resolved_definition.material_id
	var size_id: StringName = resolved_definition.size_id
	var type_id: StringName = resolved_definition.type_id

	data.id = StringName("%s__%s" % [String(material_id), String(size_id)])
	if type_id != StringName():
		data.id = StringName("%s__%s" % [String(data.id), String(type_id)])
	data.display_name = resolved_definition.display_name
	data.size_cells = resolved_definition.size_cells
	data.health = maxi(int(resolved_definition.final_hp), 1)
	data.sand_units = maxi(int(resolved_definition.final_sand_units), 1)
	data.reward = maxi(int(resolved_definition.final_reward), 0)
	data.color_key = resolved_definition.color_key
	data.block_color = resolved_definition.block_color
	data.sand_weight = GameConstants.get_sand_weight(data.color_key)

	data.block_base = material_id
	data.block_base_definition = material_definition
	data.block_base_display_name = str(material_definition.display_name)
	data.block_base_color = resolved_definition.block_color
	data.block_base_spawn_weight = float(resolved_definition.material_spawn_weight)
	data.block_base_hp_multiplier = float(resolved_definition.material_hp_multiplier)

	data.block_material = material_id
	data.block_material_definition = material_definition
	data.block_material_display_name = str(material_definition.display_name)
	data.block_material_reward_multiplier = float(resolved_definition.material_reward_multiplier)

	data.block_size = size_id
	data.block_size_definition = size_definition
	data.block_size_display_name = _format_size_label(size_definition)
	data.block_size_spawn_weight = float(resolved_definition.size_spawn_weight)
	data.block_size_hp_multiplier = float(resolved_definition.size_hp_multiplier)
	data.block_size_reward_multiplier = float(resolved_definition.size_reward_multiplier)

	data.block_type = type_id
	data.block_type_definition = type_definition
	data.block_type_display_name = ""
	data.block_type_spawn_weight_multiplier = 1.0
	data.block_type_hp_multiplier = 1.0
	data.block_type_reward_multiplier = 1.0
	data.block_type_sand_units_multiplier = 1.0
	if type_definition != null:
		data.block_type_display_name = str(type_definition.display_name)
		data.block_type_spawn_weight_multiplier = float(type_definition.spawn_weight_multiplier)
		data.block_type_hp_multiplier = float(type_definition.hp_multiplier)
		data.block_type_reward_multiplier = float(type_definition.reward_multiplier)
		data.block_type_sand_units_multiplier = float(type_definition.sand_units_multiplier)

	data.unit_hp = float(resolved_definition.base_unit_hp)
	data.area_units = maxi(int(data.size_cells.x * data.size_cells.y), 1)
	data.day_hp_multiplier = 1.0
	data.difficulty_hp_multiplier = float(resolved_definition.difficulty_hp_multiplier)
	data.spawn_weight = float(resolved_definition.final_spawn_weight)
	data.special_result_type = resolved_definition.special_result_type
	return data


static func _format_size_label(size_definition) -> String:
	if size_definition == null:
		return "1x1"
	return "%dx%d" % [int(size_definition.width_u), int(size_definition.height_u)]


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
	return "%s | HP %d | 1U %.2f | Size %s (%dU) | Material x%.3f | Type(%s) x%.3f | Diff x%.3f" % [
		display_name,
		health,
		unit_hp,
		block_size_display_name,
		area_units,
		block_base_hp_multiplier,
		type_label,
		block_type_hp_multiplier,
		difficulty_hp_multiplier,
	]
