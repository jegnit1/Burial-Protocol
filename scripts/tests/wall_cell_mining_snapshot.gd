extends SceneTree

const WORLD_GRID_SCRIPT := preload("res://scenes/world/WorldGrid.gd")
const GC := preload("res://scripts/autoload/GameConstants.gd")

var _ran := false


func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true

	var grid = WORLD_GRID_SCRIPT.new()
	get_root().add_child(grid)

	var single_hit_validation := _validate_single_cell_progression(grid)
	var damage_two_validation := _validate_damage_two_progression(grid)
	var restore_validation := _validate_restore(grid)
	var snapshot := {
		"ok": (
			bool(single_hit_validation["ok"])
			and bool(damage_two_validation["ok"])
			and bool(restore_validation["ok"])
		),
		"wall_cell_max_hp": GC.WALL_CELL_MAX_HP,
		"single_hit_validation": single_hit_validation,
		"damage_two_validation": damage_two_validation,
		"restore_validation": restore_validation,
	}
	print(JSON.stringify(snapshot, "\t"))
	grid.queue_free()
	quit(0 if bool(snapshot["ok"]) else 1)
	return true


func _validate_single_cell_progression(grid) -> Dictionary:
	var cell := Vector2i(0, 8)
	var shape := _make_cell_center_shape(grid, cell)
	var initial_active_count := grid.get_active_wall_count()
	var collision_before := grid.rect_collides_static(grid.get_cell_rect(cell).grow(-1.0))
	var hits: Array[Dictionary] = []
	for _index in range(GC.WALL_CELL_MAX_HP):
		var result: Dictionary = grid.try_mine_in_shape(shape, 1)
		hits.append({
			"hit_count": int(result.get("hit_count", 0)),
			"removed_count": int(result.get("removed_count", 0)),
			"hp": int(grid.wall_cells.get(cell, 0)),
			"tile_index": grid.call("_get_wall_tile_index_for_ratio", grid.call("_get_wall_cell_remaining_ratio", cell)),
		})
	var collision_after := grid.rect_collides_static(grid.get_cell_rect(cell).grow(-1.0))
	var active_count_after := grid.get_active_wall_count()
	var checks := {
		"initial_collision_is_solid": collision_before,
		"hit_1_keeps_tile_0": int(hits[0]["hp"]) == GC.WALL_CELL_MAX_HP - 1 and int(hits[0]["tile_index"]) == 0,
		"half_hp_switches_tile_1": int(hits[3]["hp"]) == int(GC.WALL_CELL_MAX_HP / 2) and int(hits[3]["tile_index"]) == 1,
		"quarter_hp_switches_tile_2": int(hits[5]["hp"]) == int(GC.WALL_CELL_MAX_HP / 4) and int(hits[5]["tile_index"]) == 2,
		"final_hit_removes_cell": int(hits[GC.WALL_CELL_MAX_HP - 1]["hp"]) == 0 and int(hits[GC.WALL_CELL_MAX_HP - 1]["removed_count"]) == 1,
		"removed_cell_no_longer_collides": not collision_after,
		"active_count_decrements_by_one": active_count_after == initial_active_count - 1,
	}
	return {
		"ok": _all_checks_pass(checks),
		"checks": checks,
		"hits": hits,
	}


func _validate_damage_two_progression(grid) -> Dictionary:
	var cell := Vector2i(1, 8)
	var result: Dictionary = grid.try_mine_in_shape(_make_cell_center_shape(grid, cell), 2)
	var hp := int(grid.wall_cells.get(cell, 0))
	var tile_index := int(grid.call("_get_wall_tile_index_for_ratio", grid.call("_get_wall_cell_remaining_ratio", cell)))
	var checks := {
		"one_swing_hits_one_cell": int(result.get("hit_count", 0)) == 1,
		"damage_two_reduces_two_hp": hp == GC.WALL_CELL_MAX_HP - 2,
		"damage_two_still_uses_tile_0": tile_index == 0,
		"cell_still_collides": grid.rect_collides_static(grid.get_cell_rect(cell).grow(-1.0)),
	}
	return {
		"ok": _all_checks_pass(checks),
		"checks": checks,
		"hp": hp,
		"tile_index": tile_index,
	}


func _validate_restore(grid) -> Dictionary:
	grid.restore_mining_walls()
	var cell := Vector2i(0, 8)
	var expected_count := GC.WALL_COLUMNS * 2 * GC.FLOOR_ROW
	var checks := {
		"active_count_restored": grid.get_active_wall_count() == expected_count,
		"cell_hp_restored": int(grid.wall_cells.get(cell, 0)) == GC.WALL_CELL_MAX_HP,
		"restored_cell_collides": grid.rect_collides_static(grid.get_cell_rect(cell).grow(-1.0)),
	}
	return {
		"ok": _all_checks_pass(checks),
		"checks": checks,
	}


func _make_cell_center_shape(grid, cell: Vector2i) -> Dictionary:
	return {
		"center": grid.get_cell_rect(cell).get_center(),
		"size": Vector2.ONE * float(GC.CELL_SIZE) * 0.5,
		"rotation": 0.0,
	}


func _all_checks_pass(checks: Dictionary) -> bool:
	for value in checks.values():
		if not bool(value):
			return false
	return true
