extends Node

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const SAND_CELL_DATA_SCRIPT := preload("res://scripts/data_models/SandCellData.gd")

var _failures: Array[String] = []
var _results: Dictionary = {}
var _main: Node2D


func _ready() -> void:
	_main = MAIN_SCENE.instantiate() as Node2D
	add_child(_main)
	_check_cleaner_protocol()
	_check_aura_protocol()
	_print_and_quit()


func _check_cleaner_protocol() -> void:
	var sand_field = _main.get_node("SandField")
	for offset in range(3):
		var cell := Vector2i(
			GameConstants.SAND_CELLS_PER_UNIT * (GameConstants.WALL_COLUMNS + 1) + offset,
			GameConstants.SAND_CELLS_PER_UNIT * 10
		)
		var sand_data = SAND_CELL_DATA_SCRIPT.new()
		sand_data.hp = 1
		sand_field.sand_cells[cell] = sand_data
	var before := int(sand_field.get_sand_count())
	var cleaner := GameData.get_shop_item_definition(&"cleaner_bot_c")
	_main.call("_handle_sand_cleaner_protocol", cleaner)
	var after := int(sand_field.get_sand_count())
	_results["cleaner"] = {
		"before": before,
		"after": after,
		"removed": before - after,
	}
	_expect(before - after == 2, "cleaner_bot_c should remove two nearest sand cells")


func _check_aura_protocol() -> void:
	var projectiles_root := _main.get_node("Projectiles")
	var before := projectiles_root.get_child_count()
	var aura := GameData.get_shop_item_definition(&"spark_field_d")
	_main.call("_handle_drone_aura_protocol", {"item_id": "spark_field_d"}, aura)
	var after := projectiles_root.get_child_count()
	_results["aura"] = {
		"before": before,
		"after": after,
		"pulse_spawned": after > before,
	}
	_expect(after > before, "spark field should spawn an aura pulse visual")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _print_and_quit() -> void:
	print(JSON.stringify({
		"ok": _failures.is_empty(),
		"failures": _failures,
		"results": _results,
	}, "\t"))
	get_tree().quit(0 if _failures.is_empty() else 1)
