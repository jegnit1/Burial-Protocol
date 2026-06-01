extends RefCounted
class_name SandCellData

var color_key: StringName
var color := Color.WHITE
var weight := 1.0
var stable := false
var max_hp := GameConstants.SAND_FALLBACK_CELL_HP
var hp := GameConstants.SAND_FALLBACK_CELL_HP


static func from_block(block_data: BlockData, generated_sand_cell_count: int = 0) -> SandCellData:
	var cell := SandCellData.new()
	cell.color_key = block_data.color_key
	cell.color = GameConstants.get_sand_color(block_data.color_key)
	cell.weight = block_data.sand_weight
	var safe_cell_count := maxi(generated_sand_cell_count, 1)
	cell.max_hp = float(block_data.get_effective_health()) / float(safe_cell_count)
	if cell.max_hp <= 0.0:
		cell.max_hp = GameConstants.SAND_FALLBACK_CELL_HP
	cell.hp = cell.max_hp
	return cell


func clone() -> SandCellData:
	var copy := SandCellData.new()
	copy.color_key = color_key
	copy.color = color
	copy.weight = weight
	copy.stable = stable
	copy.max_hp = max_hp
	copy.hp = hp
	return copy
