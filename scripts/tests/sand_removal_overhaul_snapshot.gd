extends Node

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const FALLING_BLOCK_SCENE := preload("res://scenes/blocks/FallingBlock.tscn")
const PROJECTILE_SCRIPT := preload("res://scenes/projectiles/AttackModuleProjectile.gd")
const SAND_CELL_DATA_SCRIPT := preload("res://scripts/data_models/SandCellData.gd")
const BLOCK_DATA_SCRIPT := preload("res://scripts/data_models/BlockData.gd")

var _failures: Array[String] = []
var _results: Dictionary = {}
var _main: Node2D
var _sand_field: SandField
var _game_state: Node


func _ready() -> void:
	_game_state = get_node("/root/GameState")
	_main = MAIN_SCENE.instantiate() as Node2D
	add_child(_main)
	_sand_field = _main.get_node("SandField") as SandField
	_check_right_click_mining_blocked()
	_check_weapon_ratio_and_area_damage()
	_check_exact_damage_ratio()
	_check_main_melee_weapon_path()
	_check_laser_collision_rules()
	_check_damage_source_guard()
	_check_spawn_hp_formula()
	_check_non_piercing_projectile_collision()
	_check_piercing_projectile_collision()
	_check_projectile_shared_pierce_with_block()
	_check_explosion_projectile_collision()
	_check_cleaner_special_removal()
	_check_sand_xp_without_gold_or_popup()
	_check_block_reward_unchanged()
	_check_natural_fall()
	_check_diagonal_spread()
	_check_player_push()
	_check_weight_overload()
	_print_and_quit()


func _check_right_click_mining_blocked() -> void:
	_reset_sand()
	var cell := _center_cell(10)
	_place_sand(cell, 3.0)
	var shape := _shape_for_cell(cell)
	var result: Dictionary = _sand_field.try_mine_in_shape(shape, 999)
	_results["right_click_mining"] = {
		"mineable": _sand_field.has_mineable_in_shape(shape),
		"removed": int(result.get("removed_count", 0)),
		"hp": _sand_hp(cell),
	}
	_expect(not _sand_field.has_mineable_in_shape(shape), "sand should not be a right-click mining target")
	_expect(int(result.get("removed_count", 0)) == 0, "right-click mining should not remove sand")
	_expect(is_equal_approx(_sand_hp(cell), 3.0), "right-click mining should not damage sand")


func _check_weapon_ratio_and_area_damage() -> void:
	_reset_sand()
	var first := _center_cell(10)
	var second := first + Vector2i.RIGHT
	_place_sand(first, 3.0)
	_place_sand(second, 3.0)
	var bounds := _sand_field.get_sand_cell_rect(first).merge(_sand_field.get_sand_cell_rect(second))
	var shape := {
		"center": bounds.get_center(),
		"size": bounds.size,
		"rotation": 0.0,
	}
	var first_hit: Dictionary = _sand_field.apply_weapon_damage_in_shape(shape, 20.0, &"weapon")
	var first_hp := [_sand_hp(first), _sand_hp(second)]
	var second_hit: Dictionary = _sand_field.apply_weapon_damage_in_shape(shape, 20.0, &"weapon")
	_results["weapon_area_damage"] = {
		"damage_per_cell": float(first_hit.get("damage_per_cell", 0.0)),
		"first_hit_count": int(first_hit.get("hit_count", 0)),
		"hp_after_first_hit": first_hp,
		"removed_after_second_hit": int(second_hit.get("removed_count", 0)),
	}
	_expect(is_equal_approx(float(first_hit.get("damage_per_cell", 0.0)), 2.0), "sand damage should be 10 percent of weapon damage")
	_expect(int(first_hit.get("hit_count", 0)) == 2, "area weapon damage should hit each sand cell")
	_expect(is_equal_approx(float(first_hp[0]), 1.0) and is_equal_approx(float(first_hp[1]), 1.0), "each sand cell should track its own float HP")
	_expect(int(second_hit.get("removed_count", 0)) == 2, "only sand cells reduced to zero HP should be removed")


func _check_damage_source_guard() -> void:
	_reset_sand()
	var cell := _center_cell(10)
	_place_sand(cell, 3.0)
	var blocked: Dictionary = _sand_field.apply_weapon_damage_in_shape(_shape_for_cell(cell), 100.0, &"drone_protocol")
	_results["source_guard"] = {
		"hit_count": int(blocked.get("hit_count", 0)),
		"hp": _sand_hp(cell),
	}
	_expect(int(blocked.get("hit_count", 0)) == 0, "drone protocol source should not damage sand")
	_expect(is_equal_approx(_sand_hp(cell), 3.0), "blocked protocol damage should leave sand HP unchanged")


func _check_exact_damage_ratio() -> void:
	_reset_sand()
	var damaged_cell := _center_cell(10)
	var removed_cell := damaged_cell + Vector2i.RIGHT
	_place_sand(damaged_cell, 10.0)
	_place_sand(removed_cell, 10.0)
	_sand_field.apply_weapon_damage_to_sand_cell(damaged_cell, 20.0, &"weapon")
	var damaged_hp := _sand_hp(damaged_cell)
	var removed := _sand_field.apply_weapon_damage_to_sand_cell(removed_cell, 100.0, &"weapon")
	_results["exact_damage_ratio"] = {
		"hp_after_20_damage": damaged_hp,
		"removed_after_100_damage": removed,
	}
	_expect(is_equal_approx(damaged_hp, 8.0), "20 weapon damage should reduce a 10 HP sand cell to 8 HP")
	_expect(removed and not _sand_field.sand_cells.has(removed_cell), "100 weapon damage should remove a 10 HP sand cell")


func _check_main_melee_weapon_path() -> void:
	_reset_sand()
	_game_state.call("reset_run")
	_expect(_game_state.call("grant_weapon", &"sword_module", true), "sword weapon should be available for melee sand regression")
	var entry: Dictionary = _game_state.call("get_equipped_weapon_entries")[0]
	var shape: Dictionary = _main.get_node("Player").get_attack_shape_data_for_module(Vector2.RIGHT, entry)
	var cell := _sand_field.world_to_sand_cell(shape["center"])
	_place_sand(cell, 5.0)
	var weapon_damage := float(_game_state.call("get_attack_module_damage", entry))
	_main.call("_handle_attack_module_action", {
		"module_entry": entry,
		"direction": Vector2.RIGHT,
	})
	_results["main_melee_weapon"] = {
		"weapon_damage": weapon_damage,
		"sand_hp": _sand_hp(cell),
	}
	_expect(
		is_equal_approx(_sand_hp(cell), 5.0 - weapon_damage * GameConstants.SAND_WEAPON_DAMAGE_RATIO),
		"Main melee weapon path should apply sand damage"
	)


func _check_spawn_hp_formula() -> void:
	_reset_sand()
	var block_data = BLOCK_DATA_SCRIPT.new()
	block_data.health = 100
	block_data.sand_units = 4
	block_data.color_key = &"amber"
	block_data.sand_weight = 1.0
	var rect := Rect2(_sand_field.sand_cell_to_world(_center_cell(10)), Vector2.ONE * GameConstants.SAND_CELL_SIZE)
	_sand_field.spawn_from_block(rect, block_data)
	var hp_values: Array[float] = []
	for raw_cell in _sand_field.sand_cells.values():
		var sand_cell = raw_cell
		hp_values.append(float(sand_cell.hp))
	_results["spawn_hp_formula"] = {
		"spawned": hp_values.size(),
		"hp_values": hp_values,
	}
	_expect(hp_values.size() == 4, "block decomposition should create the requested sand cell count when space is open")
	for hp in hp_values:
		_expect(is_equal_approx(hp, 25.0), "spawned sand HP should equal final block HP divided by generated cell count")


func _check_laser_collision_rules() -> void:
	_reset_sand()
	_game_state.call("reset_run")
	_expect(_game_state.call("grant_weapon", &"laser_module", true), "laser weapon should be available for hitscan sand regression")
	var entry: Dictionary = _game_state.call("get_equipped_weapon_entries")[0]
	var definition = _game_state.call("get_attack_module_definition_from_entry", entry)
	var weapon_damage := float(_game_state.call("get_attack_module_damage", entry))
	var first := _sand_field.world_to_sand_cell(_main.get_node("Player").global_position + Vector2.RIGHT * 24.0)
	var cells: Array[Vector2i] = []
	for offset in range(4):
		var cell := first + Vector2i.RIGHT * offset
		_place_sand(cell, 10.0)
		cells.append(cell)
	var original_pierce_count: int = definition.pierce_count
	definition.pierce_count = 0
	_main.call("_fire_laser_placeholder", entry, definition, Vector2.RIGHT, Vector2.ZERO)
	var non_piercing_hp := _sand_hp_values(cells)
	_reset_sand()
	for cell in cells:
		_place_sand(cell, 10.0)
	definition.pierce_count = 2
	_main.call("_fire_laser_placeholder", entry, definition, Vector2.RIGHT, Vector2.ZERO)
	var piercing_hp := _sand_hp_values(cells)
	definition.pierce_count = original_pierce_count
	_results["laser_collision"] = {
		"weapon_damage": weapon_damage,
		"non_piercing_hp": non_piercing_hp,
		"piercing_hp": piercing_hp,
	}
	_expect(is_equal_approx(float(non_piercing_hp[0]), 10.0 - weapon_damage * GameConstants.SAND_WEAPON_DAMAGE_RATIO), "non-piercing laser should damage the front sand cell")
	_expect(is_equal_approx(float(non_piercing_hp[1]), 10.0), "non-piercing laser should stop after the front sand cell")
	_expect(is_equal_approx(float(piercing_hp[0]), 10.0 - weapon_damage * GameConstants.SAND_WEAPON_DAMAGE_RATIO), "piercing laser should damage its first sand cell")
	_expect(is_equal_approx(float(piercing_hp[2]), 10.0 - weapon_damage * GameConstants.SAND_WEAPON_DAMAGE_RATIO), "piercing laser should consume its configured additional pierces")
	_expect(is_equal_approx(float(piercing_hp[3]), 10.0), "piercing laser should stop after its configured additional pierces")


func _check_non_piercing_projectile_collision() -> void:
	_reset_sand()
	var first := _center_cell(10)
	var cells: Array[Vector2i] = []
	for offset in range(3):
		var cell := first + Vector2i.RIGHT * offset
		_place_sand(cell, 10.0)
		cells.append(cell)
	var projectile = PROJECTILE_SCRIPT.new()
	add_child(projectile)
	projectile.setup({
		"position": _sand_field.get_sand_cell_rect(first).get_center() - Vector2(12.0, 0.0),
		"direction": Vector2.RIGHT,
		"damage": 20,
		"weapon_damage_for_sand": 20.0,
		"pierce_count": 0,
		"sand_field": _sand_field,
	})
	projectile.call(
		"_check_hits",
		_sand_field.get_sand_cell_rect(first).position - Vector2(4.0, 0.0),
		_sand_field.get_sand_cell_rect(cells[2]).end + Vector2(4.0, 0.0)
	)
	var hp_values := _sand_hp_values(cells)
	_results["non_piercing_projectile"] = {
		"hp_values": hp_values,
		"queued_for_deletion": projectile.is_queued_for_deletion(),
	}
	_expect(is_equal_approx(float(hp_values[0]), 8.0), "non-piercing projectile should damage the front sand cell by 10 percent")
	_expect(is_equal_approx(float(hp_values[1]), 10.0) and is_equal_approx(float(hp_values[2]), 10.0), "non-piercing projectile should not damage rear sand cells")
	_expect(projectile.is_queued_for_deletion(), "non-piercing projectile should stop at the front sand cell")
	projectile.queue_free()


func _check_piercing_projectile_collision() -> void:
	_reset_sand()
	var first := _center_cell(10)
	var cells: Array[Vector2i] = []
	for offset in range(4):
		var cell := first + Vector2i.RIGHT * offset
		_place_sand(cell, 10.0)
		cells.append(cell)
	var projectile = PROJECTILE_SCRIPT.new()
	add_child(projectile)
	projectile.setup({
		"position": _sand_field.get_sand_cell_rect(first).get_center() - Vector2(12.0, 0.0),
		"direction": Vector2.RIGHT,
		"damage": 20,
		"weapon_damage_for_sand": 20.0,
		"pierce_count": 2,
		"sand_field": _sand_field,
	})
	projectile.call(
		"_check_hits",
		_sand_field.get_sand_cell_rect(first).position - Vector2(4.0, 0.0),
		_sand_field.get_sand_cell_rect(cells[3]).end + Vector2(4.0, 0.0)
	)
	var hp_values := _sand_hp_values(cells)
	_results["piercing_projectile"] = {
		"hp_values": hp_values,
		"queued_for_deletion": projectile.is_queued_for_deletion(),
	}
	_expect(is_equal_approx(float(hp_values[0]), 8.0) and is_equal_approx(float(hp_values[2]), 8.0), "piercing projectile should damage the front cell and two additional pierced cells")
	_expect(is_equal_approx(float(hp_values[3]), 10.0), "piercing projectile should stop before exceeding its pierce count")
	_expect(projectile.is_queued_for_deletion(), "piercing projectile should stop when its pierce count is exhausted")
	projectile.queue_free()


func _check_explosion_projectile_collision() -> void:
	_reset_sand()
	var front := _center_cell(10)
	var nearby := front + Vector2i.DOWN
	var rear := front + Vector2i.RIGHT * 4
	_place_sand(front, 10.0)
	_place_sand(nearby, 10.0)
	_place_sand(rear, 10.0)
	var projectile = PROJECTILE_SCRIPT.new()
	add_child(projectile)
	projectile.setup({
		"position": _sand_field.get_sand_cell_rect(front).get_center() - Vector2(12.0, 0.0),
		"direction": Vector2.RIGHT,
		"damage": 20,
		"weapon_damage_for_sand": 20.0,
		"pierce_count": 0,
		"explosion_radius": GameConstants.SAND_CELL_SIZE * 1.6,
		"sand_field": _sand_field,
	})
	projectile.call(
		"_check_hits",
		_sand_field.get_sand_cell_rect(front).position - Vector2(4.0, 0.0),
		_sand_field.get_sand_cell_rect(rear).end + Vector2(4.0, 0.0)
	)
	_results["explosion_projectile"] = {
		"front_hp": _sand_hp(front),
		"nearby_hp": _sand_hp(nearby),
		"rear_hp": _sand_hp(rear),
		"queued_for_deletion": projectile.is_queued_for_deletion(),
	}
	_expect(is_equal_approx(_sand_hp(front), 8.0) and is_equal_approx(_sand_hp(nearby), 8.0), "explosion should apply 10 percent weapon damage to each sand cell in range")
	_expect(is_equal_approx(_sand_hp(rear), 10.0), "explosion projectile should detonate at the front collision instead of travelling through the pile")
	_expect(projectile.is_queued_for_deletion(), "explosion projectile should stop after detonating")
	projectile.queue_free()


func _check_projectile_shared_pierce_with_block() -> void:
	_reset_sand()
	var front := _center_cell(10)
	_place_sand(front, 10.0)
	var block_data = BLOCK_DATA_SCRIPT.new()
	block_data.health = 50
	block_data.size_cells = Vector2i.ONE
	var block = FALLING_BLOCK_SCENE.instantiate()
	_main.get_node("Blocks").add_child(block)
	var block_position := _sand_field.get_sand_cell_rect(front).get_center() + Vector2.RIGHT * 80.0
	block.setup(
		block_data,
		block_position,
		_main.get_node("WorldGrid"),
		_sand_field,
		_main.get_node("Player")
	)
	var rear := _sand_field.world_to_sand_cell(block_position + Vector2.RIGHT * 48.0)
	_place_sand(rear, 10.0)
	var projectile = PROJECTILE_SCRIPT.new()
	add_child(projectile)
	projectile.setup({
		"position": _sand_field.get_sand_cell_rect(front).get_center() - Vector2(12.0, 0.0),
		"direction": Vector2.RIGHT,
		"damage": 20,
		"weapon_damage_for_sand": 20.0,
		"pierce_count": 1,
		"blocks_root": _main.get_node("Blocks"),
		"sand_field": _sand_field,
	})
	projectile.call(
		"_check_hits",
		_sand_field.get_sand_cell_rect(front).position - Vector2(4.0, 0.0),
		_sand_field.get_sand_cell_rect(rear).end + Vector2(4.0, 0.0)
	)
	_results["shared_projectile_pierce"] = {
		"front_hp": _sand_hp(front),
		"block_hp": block.current_health,
		"rear_hp": _sand_hp(rear),
		"queued_for_deletion": projectile.is_queued_for_deletion(),
	}
	_expect(is_equal_approx(_sand_hp(front), 8.0), "front sand cell should consume the projectile's first collision")
	_expect(block.current_health == 30, "block should consume the remaining shared projectile pierce")
	_expect(is_equal_approx(_sand_hp(rear), 10.0), "projectile should stop before rear sand after block consumes the remaining pierce")
	_expect(projectile.is_queued_for_deletion(), "shared block and sand pierce should stop after the configured additional pierce")
	projectile.queue_free()
	block.queue_free()


func _check_cleaner_special_removal() -> void:
	_reset_sand()
	for offset in range(3):
		_place_sand(_center_cell(10) + Vector2i(offset, 0), 3.0)
	var cleaner := GameData.get_shop_item_definition(&"cleaner_bot_c")
	_main.call("_handle_sand_cleaner_protocol", cleaner)
	_results["cleaner_special_removal"] = {
		"remaining": _sand_field.get_sand_count(),
	}
	_expect(_sand_field.get_sand_count() == 1, "cleaner protocol should remain a special removal effect")


func _check_sand_xp_without_gold_or_popup() -> void:
	_reset_sand()
	_game_state.call("reset_run")
	var gold_before := int(_game_state.get("gold"))
	var xp_before := int(_game_state.get("player_current_xp"))
	var popup_count_before := _main.get_node("Blocks").get_child_count()
	var cells: Array[Vector2i] = []
	for offset in range(GameConstants.SAND_REMOVED_CELLS_PER_XP):
		var cell := _center_cell(10) + Vector2i(offset, 0)
		_place_sand(cell, 1.0)
		cells.append(cell)
	var bounds := _sand_field.get_sand_cell_rect(cells[0]).merge(_sand_field.get_sand_cell_rect(cells[cells.size() - 1]))
	_sand_field.apply_weapon_damage_in_shape({
		"center": bounds.get_center(),
		"size": bounds.size,
		"rotation": 0.0,
	}, 10.0, &"weapon")
	var gold_after := int(_game_state.get("gold"))
	var xp_after := int(_game_state.get("player_current_xp"))
	var popup_count_after := _main.get_node("Blocks").get_child_count()
	_results["sand_reward"] = {
		"gold_delta": gold_after - gold_before,
		"xp_delta": xp_after - xp_before,
		"popup_delta": popup_count_after - popup_count_before,
	}
	_expect(gold_after == gold_before, "sand removal should not grant gold")
	_expect(popup_count_after == popup_count_before, "sand removal should not spawn gold popups")
	_expect(xp_after - xp_before == 1, "existing sand removal XP policy should remain isolated and active")


func _check_block_reward_unchanged() -> void:
	_game_state.call("reset_run")
	var block_data = BLOCK_DATA_SCRIPT.new()
	block_data.reward = 7
	block_data.size_cells = Vector2i.ONE
	var fake_block = FALLING_BLOCK_SCENE.instantiate()
	fake_block.block_data = block_data
	_main.get_node("Blocks").add_child(fake_block)
	var gold_before := int(_game_state.get("gold"))
	var xp_before := int(_game_state.get("player_current_xp"))
	_main.call("_on_block_destroyed", fake_block)
	_results["block_reward"] = {
		"gold_delta": int(_game_state.get("gold")) - gold_before,
		"xp_delta": int(_game_state.get("player_current_xp")) - xp_before,
	}
	_expect(int(_game_state.get("gold")) - gold_before == 7, "block destruction gold reward should remain unchanged")
	_expect(int(_game_state.get("player_current_xp")) - xp_before == GameConstants.get_block_xp(1, 1), "block destruction XP should remain unchanged")
	fake_block.queue_free()


func _check_natural_fall() -> void:
	_reset_sand()
	var from_cell := _center_cell(8)
	var to_cell := from_cell + Vector2i.DOWN
	_place_sand(from_cell, 3.0)
	_sand_field.call("_mark_active_cell", from_cell)
	_sand_field.step_simulation(_sand_field.get_sand_cell_rect(from_cell))
	_results["natural_fall"] = {
		"moved_down": _sand_field.sand_cells.has(to_cell),
	}
	_expect(_sand_field.sand_cells.has(to_cell), "sand natural falling should remain active")


func _check_diagonal_spread() -> void:
	_reset_sand()
	var from_cell := _center_cell(8)
	var blocking_cell := from_cell + Vector2i.DOWN
	_place_sand(from_cell, 3.0)
	_place_sand(blocking_cell, 3.0)
	var moved := bool(_sand_field.call("_try_move_cell", from_cell))
	var moved_diagonally := (
		_sand_field.sand_cells.has(from_cell + Vector2i(-1, 1))
		or _sand_field.sand_cells.has(from_cell + Vector2i(1, 1))
	)
	_results["diagonal_spread"] = {
		"moved": moved,
		"moved_diagonally": moved_diagonally,
	}
	_expect(moved and moved_diagonally, "sand diagonal spreading should remain active when downward movement is blocked")


func _check_player_push() -> void:
	_reset_sand()
	var player_rect: Rect2 = _main.get_node("Player").get_body_rect()
	var push_rect: Rect2 = _sand_field.call("_get_push_rect", player_rect, 1)
	var from_cell := _sand_field.world_to_sand_cell(push_rect.get_center())
	var to_cell := from_cell + Vector2i.RIGHT
	_place_sand(from_cell, 3.0)
	var moved := _sand_field.try_push_for_body(player_rect, 1)
	_results["player_push"] = {
		"moved": moved,
		"moved_forward": _sand_field.sand_cells.has(to_cell),
	}
	_expect(moved and _sand_field.sand_cells.has(to_cell), "player body push should keep moving sand cells")


func _check_weight_overload() -> void:
	_reset_sand()
	var weight_limit := int(_game_state.call("get_weight_limit_sand_cells"))
	for index in range(weight_limit):
		_place_sand(Vector2i(index, 0), 1.0)
	var would_fail := _sand_field.get_sand_count() >= weight_limit
	_results["weight_overload"] = {
		"limit": weight_limit,
		"sand_count": _sand_field.get_sand_count(),
		"would_fail": would_fail,
	}
	_expect(would_fail, "weight overload threshold should remain active")


func _reset_sand() -> void:
	_sand_field.sand_cells.clear()
	_sand_field.active_cells.clear()
	_sand_field.mining_triggered_cells.clear()
	_sand_field.blocked_push_signature = ""
	_sand_field.blocked_jump_signature = ""


func _center_cell(row: int) -> Vector2i:
	return Vector2i(
		GameConstants.SAND_CELLS_PER_UNIT * (GameConstants.WALL_COLUMNS + 1),
		GameConstants.SAND_CELLS_PER_UNIT * row
	)


func _place_sand(cell: Vector2i, hp: float) -> void:
	var sand_data = SAND_CELL_DATA_SCRIPT.new()
	sand_data.max_hp = hp
	sand_data.hp = hp
	_sand_field.sand_cells[cell] = sand_data


func _shape_for_cell(cell: Vector2i) -> Dictionary:
	var rect := _sand_field.get_sand_cell_rect(cell)
	return {
		"center": rect.get_center(),
		"size": rect.size,
		"rotation": 0.0,
	}


func _sand_hp(cell: Vector2i) -> float:
	if not _sand_field.sand_cells.has(cell):
		return 0.0
	return float(_sand_field.sand_cells[cell].hp)


func _sand_hp_values(cells: Array[Vector2i]) -> Array[float]:
	var values: Array[float] = []
	for cell in cells:
		values.append(_sand_hp(cell))
	return values


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
