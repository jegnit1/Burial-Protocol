extends RefCounted
class_name SandCellData

var color_key: StringName
var color := Color.WHITE
var weight := 1.0
var stable := false


static func from_block(block_data: BlockData) -> SandCellData:
	var cell := SandCellData.new()
	cell.color_key = block_data.color_key
	cell.color = GameConstants.get_sand_color(block_data.color_key)
	cell.weight = block_data.sand_weight
	return cell


func clone() -> SandCellData:
	var copy := SandCellData.new()
	copy.color_key = color_key
	copy.color = color
	copy.weight = weight
	copy.stable = stable
	return copy
