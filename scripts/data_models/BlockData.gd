extends RefCounted
class_name BlockData

var id: StringName
var size_cells := Vector2i.ONE
var health := 1
var sand_units := 1
var reward := 0
var color_key: StringName
var block_color := Color.WHITE
var sand_weight := 1.0
var block_base: StringName
var block_base_definition: Dictionary = {}
var block_base_display_name := ""
var block_base_color := Color.WHITE
var block_base_spawn_weight := 1.0
var block_base_hp_multiplier := 1.0
var block_base_reward_multiplier := 1.0
var special_result_type: StringName = GameConstants.BLOCK_SPECIAL_RESULT_NONE
var spawn_weight := 1.0
var modifier_ids := PackedStringArray()
var attribute_tags := PackedStringArray()


static func from_definition(definition: Dictionary) -> BlockData:
	var data := BlockData.new()
	var base_id := StringName(definition.get("block_base", GameConstants.DEFAULT_BLOCK_BASE))
	var base_definition := GameConstants.get_block_base_definition(base_id)
	data.id = StringName(definition["id"])
	data.size_cells = definition["size_cells"]
	data.health = definition["health"]
	data.sand_units = definition["sand_units"]
	data.reward = definition["reward"]
	data.color_key = StringName(definition["color_key"])
	data.sand_weight = GameConstants.get_sand_weight(data.color_key)
	data.block_base_definition = base_definition.duplicate(true)
	data.block_base = StringName(base_definition["id"])
	data.block_base_display_name = String(base_definition["display_name"])
	data.block_base_color = base_definition["color"]
	data.block_color = data.block_base_color
	data.block_base_spawn_weight = float(base_definition.get("spawn_weight", 1.0))
	data.block_base_hp_multiplier = float(base_definition["hp_multiplier"])
	data.block_base_reward_multiplier = float(base_definition["reward_multiplier"])
	data.special_result_type = StringName(base_definition["special_result_type"])
	data.spawn_weight = GameConstants.get_block_type_spawn_weight(definition)
	if definition.has("modifier_ids"):
		data.modifier_ids = PackedStringArray(definition["modifier_ids"])
	if definition.has("attribute_tags"):
		data.attribute_tags = PackedStringArray(definition["attribute_tags"])
	return data


func get_size_pixels() -> Vector2:
	return Vector2(size_cells * GameConstants.CELL_SIZE)


func get_effective_health() -> int:
	return maxi(int(round(float(health) * block_base_hp_multiplier)), 1)


func get_block_base_debug_text() -> String:
	return "%s | SpawnW %.2f | HP %d | HPx%.2f | Rewardx%.2f | Result %s" % [
		block_base_display_name,
		spawn_weight,
		get_effective_health(),
		block_base_hp_multiplier,
		block_base_reward_multiplier,
		String(special_result_type),
	]
