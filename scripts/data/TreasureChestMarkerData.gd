extends RefCounted
class_name TreasureChestMarkerData

const DEFAULT_WIDTH_CELLS := 1
const DEFAULT_HEIGHT_CELLS := 1

var marker_id := ""
var chest_rarity := "bronze"
var wall_side := "left"
var origin_cell_x := 0
var origin_cell_y := 0
var width_cells := DEFAULT_WIDTH_CELLS
var height_cells := DEFAULT_HEIGHT_CELLS
var is_fully_revealed := false
var reward_item_id := ""
var reward_rank := ""
var reward_roll_rank := ""
var reward_seed := 0
var consumed := false


func setup(
	p_marker_id: String,
	p_chest_rarity: String,
	p_wall_side: String,
	p_origin_cell_x: int,
	p_origin_cell_y: int,
	p_reward_seed: int
) -> void:
	marker_id = p_marker_id
	chest_rarity = p_chest_rarity
	wall_side = p_wall_side
	origin_cell_x = p_origin_cell_x
	origin_cell_y = p_origin_cell_y
	reward_seed = p_reward_seed
	is_fully_revealed = false


func get_occupied_cell_keys() -> Array[String]:
	var keys: Array[String] = []
	for local_y in range(height_cells):
		for local_x in range(width_cells):
			keys.append("%d,%d" % [origin_cell_x + local_x, origin_cell_y + local_y])
	return keys


func contains_global_cell(cell_x: int, cell_y: int) -> bool:
	return (
		cell_x >= origin_cell_x
		and cell_x < origin_cell_x + width_cells
		and cell_y >= origin_cell_y
		and cell_y < origin_cell_y + height_cells
	)


func reveal_global_cell(cell_x: int, cell_y: int) -> bool:
	if not contains_global_cell(cell_x, cell_y):
		return false
	if is_fully_revealed:
		return false
	is_fully_revealed = true
	return true


func get_revealed_count() -> int:
	return 1 if is_fully_revealed else 0


func is_interaction_available() -> bool:
	return is_fully_revealed and not consumed


func get_revealed_global_cells() -> Array[Vector2i]:
	if not is_fully_revealed:
		return []
	return [Vector2i(origin_cell_x, origin_cell_y)]


func to_snapshot() -> Dictionary:
	return {
		"marker_id": marker_id,
		"chest_rarity": chest_rarity,
		"wall_side": wall_side,
		"origin_cell_x": origin_cell_x,
		"origin_cell_y": origin_cell_y,
		"width_cells": width_cells,
		"height_cells": height_cells,
		"revealed_count": get_revealed_count(),
		"is_fully_revealed": is_fully_revealed,
		"is_interaction_available": is_interaction_available(),
		"reward_item_id": reward_item_id,
		"reward_rank": reward_rank,
		"reward_roll_rank": reward_roll_rank,
		"reward_seed": reward_seed,
		"consumed": consumed,
	}
