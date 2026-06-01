extends SceneTree

const GC := preload("res://scripts/autoload/GameConstants.gd")

var _ran := false


func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true

	var player_scene := load("res://scenes/player/Player.tscn") as PackedScene
	var player = player_scene.instantiate()
	get_root().add_child(player)
	player.position = Vector2.ZERO

	var right_shape: Dictionary = player.get_mining_shape_data(Vector2.RIGHT)
	var up_shape: Dictionary = player.get_mining_shape_data(Vector2.UP)
	var checks := {
		"height_is_half_unit_right": is_equal_approx(float(right_shape["size"].y), float(GC.CELL_SIZE) * 0.5),
		"height_is_half_unit_up": is_equal_approx(float(up_shape["size"].y), float(GC.CELL_SIZE) * 0.5),
		"base_distance_kept": is_equal_approx(float(right_shape["size"].x), GC.PLAYER_MINING_RANGE_DISTANCE),
	}
	var snapshot := {
		"ok": _all_checks_pass(checks),
		"checks": checks,
		"right_shape": _shape_to_snapshot(right_shape),
		"up_shape": _shape_to_snapshot(up_shape),
	}
	print(JSON.stringify(snapshot, "\t"))
	player.queue_free()
	quit(0 if bool(snapshot["ok"]) else 1)
	return true


func _shape_to_snapshot(shape: Dictionary) -> Dictionary:
	var size: Vector2 = shape["size"]
	return {
		"size": {
			"x": size.x,
			"y": size.y,
		},
		"rotation": float(shape["rotation"]),
	}


func _all_checks_pass(checks: Dictionary) -> bool:
	for value in checks.values():
		if not bool(value):
			return false
	return true
