extends RefCounted
class_name TreasureChestMarkerData

const DEFAULT_WIDTH_SUBCELLS := 2
const DEFAULT_HEIGHT_SUBCELLS := 2

var marker_id := ""
var chest_rarity := "bronze"
var wall_side := "left"
var origin_subcell_x := 0
var origin_subcell_y := 0
var width_subcells := DEFAULT_WIDTH_SUBCELLS
var height_subcells := DEFAULT_HEIGHT_SUBCELLS
var revealed_cells := {}
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
	p_origin_subcell_x: int,
	p_origin_subcell_y: int,
	p_reward_seed: int
) -> void:
	marker_id = p_marker_id
	chest_rarity = p_chest_rarity
	wall_side = p_wall_side
	origin_subcell_x = p_origin_subcell_x
	origin_subcell_y = p_origin_subcell_y
	reward_seed = p_reward_seed
	revealed_cells = _create_hidden_revealed_cells()


func get_occupied_subcell_keys() -> Array[String]:
	var keys: Array[String] = []
	for local_y in range(height_subcells):
		for local_x in range(width_subcells):
			keys.append("%d,%d" % [origin_subcell_x + local_x, origin_subcell_y + local_y])
	return keys


func contains_global_subcell(subcell_x: int, subcell_y: int) -> bool:
	return (
		subcell_x >= origin_subcell_x
		and subcell_x < origin_subcell_x + width_subcells
		and subcell_y >= origin_subcell_y
		and subcell_y < origin_subcell_y + height_subcells
	)


func reveal_global_subcell(subcell_x: int, subcell_y: int) -> bool:
	if not contains_global_subcell(subcell_x, subcell_y):
		return false
	var local_key := "%d,%d" % [subcell_x - origin_subcell_x, subcell_y - origin_subcell_y]
	if bool(revealed_cells.get(local_key, false)):
		return false
	revealed_cells[local_key] = true
	is_fully_revealed = get_revealed_count() == width_subcells * height_subcells
	return true


func get_revealed_count() -> int:
	var count := 0
	for value in revealed_cells.values():
		if bool(value):
			count += 1
	return count


func is_interaction_available() -> bool:
	return is_fully_revealed and not consumed


func get_revealed_global_subcells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for local_y in range(height_subcells):
		for local_x in range(width_subcells):
			if not bool(revealed_cells.get("%d,%d" % [local_x, local_y], false)):
				continue
			cells.append(Vector2i(origin_subcell_x + local_x, origin_subcell_y + local_y))
	return cells


func to_snapshot() -> Dictionary:
	return {
		"marker_id": marker_id,
		"chest_rarity": chest_rarity,
		"wall_side": wall_side,
		"origin_subcell_x": origin_subcell_x,
		"origin_subcell_y": origin_subcell_y,
		"width_subcells": width_subcells,
		"height_subcells": height_subcells,
		"revealed_cells": revealed_cells.duplicate(true),
		"revealed_count": get_revealed_count(),
		"is_fully_revealed": is_fully_revealed,
		"is_interaction_available": is_interaction_available(),
		"reward_item_id": reward_item_id,
		"reward_rank": reward_rank,
		"reward_roll_rank": reward_roll_rank,
		"reward_seed": reward_seed,
		"consumed": consumed,
	}


func _create_hidden_revealed_cells() -> Dictionary:
	var cells := {}
	for local_y in range(height_subcells):
		for local_x in range(width_subcells):
			cells["%d,%d" % [local_x, local_y]] = false
	return cells
