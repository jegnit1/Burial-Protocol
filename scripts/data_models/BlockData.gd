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


static func from_definition(definition: Dictionary) -> BlockData:
	var data := BlockData.new()
	data.id = StringName(definition["id"])
	data.size_cells = definition["size_cells"]
	data.health = definition["health"]
	data.sand_units = definition["sand_units"]
	data.reward = definition["reward"]
	data.color_key = StringName(definition["color_key"])
	data.block_color = GameConstants.get_block_color(data.color_key)
	data.sand_weight = GameConstants.get_sand_weight(data.color_key)
	return data


func get_size_pixels() -> Vector2:
	return Vector2(size_cells * GameConstants.CELL_SIZE)
