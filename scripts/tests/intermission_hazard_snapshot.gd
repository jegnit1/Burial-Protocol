extends Node

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const MAIN_SCRIPT := preload("res://scenes/main/Main.gd")
const SAND_CELL_DATA_SCRIPT := preload("res://scripts/data_models/SandCellData.gd")

var _failures: Array[String] = []
var _results: Dictionary = {}
var _main: Node2D
var _game_state: Node


func _ready() -> void:
	_game_state = get_node_or_null("/root/GameState")
	if _game_state == null:
		_failures.append("GameState autoload should be available")
		_print_and_quit()
		return
	_main = MAIN_SCENE.instantiate() as Node2D
	add_child(_main)
	if not _main.has_method("_enter_intermission"):
		_failures.append("Main.gd should compile and expose intermission methods")
		_print_and_quit()
		return
	await _run_checks()
	_print_and_quit()


func _run_checks() -> void:
	_check_intermission_entry_and_kiosk()
	_check_pause_guards()
	_check_hazard_damage_and_recovery_block()
	await _check_next_day_reset()


func _check_intermission_entry_and_kiosk() -> void:
	_main.call("_enter_intermission")
	_expect(_get_state() == MAIN_SCRIPT.IntermissionHazardState.NONE, "intermission should not start hazard countdown before kiosk deployment")
	_expect(not _main.get_node("HUD").intermission_hazard_panel.visible, "hazard HUD should stay hidden before kiosk deployment")
	_main.get_node("Player").set_mining_enabled(false)
	_main.call("_physics_process", 0.0)
	_expect(_main.get_node("Player").mining_enabled, "intermission should not lock mining")
	var sand_field = _main.get_node("SandField")
	var sand_cell := Vector2i(
		GameConstants.SAND_CELLS_PER_UNIT * (GameConstants.WALL_COLUMNS + 1),
		GameConstants.SAND_CELLS_PER_UNIT * 10
	)
	var sand_data = SAND_CELL_DATA_SCRIPT.new()
	sand_data.max_hp = 1.0
	sand_data.hp = 1.0
	sand_field.sand_cells[sand_cell] = sand_data
	var sand_rect: Rect2 = sand_field.get_sand_cell_rect(sand_cell)
	var sand_shape := {
		"center": sand_rect.get_center(),
		"size": sand_rect.size,
		"rotation": 0.0,
	}
	var mining_result: Dictionary = sand_field.try_mine_in_shape(sand_shape, 999)
	_expect(int(mining_result.get("removed_count", 0)) == 0, "right-click mining should not remove sand during intermission")
	var weapon_result: Dictionary = sand_field.apply_weapon_damage_in_shape(sand_shape, 10.0, &"weapon")
	_expect(int(weapon_result.get("removed_count", 0)) == 1, "weapon sand removal should remain available during intermission")
	var initial_health := int(_game_state.get("player_health"))
	_main.call("_update_day_kiosk_deployment", 0.0)
	_main.call("_update_day_kiosk_deployment", GameConstants.DAY_KIOSK_DEPLOY_DELAY)
	var kiosk = _main.get("_day_kiosk")
	_expect(kiosk != null and is_instance_valid(kiosk), "kiosk should deploy after the existing delay once active blocks are clear")
	_expect(_get_state() == MAIN_SCRIPT.IntermissionHazardState.COUNTDOWN, "kiosk deployment should start hazard countdown")
	_expect(_main.get_node("HUD").intermission_hazard_panel.visible, "hazard HUD should become visible after kiosk deployment")
	var initial_hud_text := String(_main.get_node("HUD").intermission_hazard_label.text)
	_expect(initial_hud_text == "10", "hazard HUD should initially show 10 after kiosk deployment")
	_main.call("_update_intermission_hazard", 9.5)
	_expect(int(_game_state.get("player_health")) == initial_health, "countdown should not deal damage")
	_results["intermission_entry"] = {
		"state": _get_state(),
		"initial_hud_text": initial_hud_text,
		"hud_text_after_9_5_seconds": _main.get_node("HUD").intermission_hazard_label.text,
		"mining_enabled": _main.get_node("Player").mining_enabled,
		"kiosk_spawned": kiosk != null and is_instance_valid(kiosk),
		"countdown_health": int(_game_state.get("player_health")),
		"mining_sand_removed": int(mining_result.get("removed_count", 0)),
		"weapon_sand_removed": int(weapon_result.get("removed_count", 0)),
	}


func _check_pause_guards() -> void:
	_main.call("_start_intermission_hazard")
	var before_pause := float(_main.get("_intermission_hazard_time_remaining"))
	_main.call("_open_pause_menu")
	_expect(get_tree().paused, "pause menu should pause the tree")
	_main.call("_update_intermission_hazard", 4.0)
	_main.call("_close_pause_menu")
	var after_pause := float(_main.get("_intermission_hazard_time_remaining"))
	_expect(is_equal_approx(before_pause, after_pause), "tree pause should freeze hazard time")
	_main.call("_open_day_shop")
	_expect(bool(_main.get("_shop_ui_open")), "day shop should set its open guard")
	_main.call("_update_intermission_hazard", 4.0)
	_main.call("_close_day_shop")
	var after_shop := float(_main.get("_intermission_hazard_time_remaining"))
	_expect(is_equal_approx(before_pause, after_shop), "shop UI should freeze hazard time")
	_results["pause_guards"] = {
		"before": before_pause,
		"after_tree_pause": after_pause,
		"after_shop_ui": after_shop,
	}


func _check_hazard_damage_and_recovery_block() -> void:
	_game_state.call("reset_run")
	_game_state.set("run_bonus_defense", 999)
	_main.call("_start_intermission_hazard")
	_main.call("_update_intermission_hazard", GameConstants.INTERMISSION_HAZARD_COUNTDOWN_SECONDS)
	_expect(_get_state() == MAIN_SCRIPT.IntermissionHazardState.WARNING, "countdown should advance to warning")
	_expect(_main.get_node("HUD").intermission_hazard_label.text == "유해물질 경고", "warning HUD should show its label")
	_expect(int(_game_state.get("player_health")) == 100, "countdown transition should not deal damage")
	_main.call("_update_intermission_hazard", 1.0)
	_expect(int(_game_state.get("player_health")) == 98, "warning should deal 2 fixed damage per second")
	_main.call("_update_player_regen", 20.0)
	_expect(int(_game_state.get("player_health")) == 98, "warning should stop the Main HP regen loop")
	_game_state.call("heal_player", 10)
	_expect(int(_game_state.get("player_health")) == 98, "warning should block healing")
	_main.call("_update_intermission_hazard", 9.0)
	_expect(_get_state() == MAIN_SCRIPT.IntermissionHazardState.DANGER, "warning should advance to danger after 10 seconds")
	_expect(_main.get_node("HUD").intermission_hazard_label.text == "유해물질 위험", "danger HUD should show its label")
	_expect(int(_game_state.get("player_health")) == 80, "warning should deal 20 total damage despite defense")
	_main.call("_update_intermission_hazard", 10.0)
	_expect(_get_state() == MAIN_SCRIPT.IntermissionHazardState.CRITICAL, "danger should advance to critical after 10 seconds")
	_expect(int(_game_state.get("player_health")) == 30, "danger should deal 50 total damage")
	_main.call("_update_intermission_hazard", 1.0)
	_expect(int(_game_state.get("player_health")) == 20, "critical should deal 10 fixed damage per second")
	var glitch_text := String(_main.get_node("HUD").intermission_hazard_label.text)
	_expect(MAIN_SCRIPT.INTERMISSION_HAZARD_GLITCH_TEXTS.has(glitch_text), "critical HUD should show a glitch string")
	_results["hazard_damage"] = {
		"state": _get_state(),
		"health_after_critical_tick": int(_game_state.get("player_health")),
		"glitch_text": glitch_text,
		"recovery_blocked": bool(_game_state.call("is_health_recovery_blocked")),
	}


func _check_next_day_reset() -> void:
	_main.call("_start_next_day_transition")
	_expect(_get_state() == MAIN_SCRIPT.IntermissionHazardState.NONE, "Next Day transition should clear hazard state immediately")
	_expect(not _main.get_node("HUD").intermission_hazard_panel.visible, "Next Day transition should hide hazard HUD")
	_expect(not bool(_game_state.call("is_health_recovery_blocked")), "Next Day transition should allow healing again")
	_expect(is_zero_approx(float(_main.get("_intermission_hazard_damage_accumulator"))), "Next Day transition should clear hazard damage accumulator")
	await get_tree().create_timer(GameConstants.DAY_TRANSITION_FADE_DURATION * 2.0 + 0.1).timeout
	_expect(not bool(_main.get("_is_next_day_transitioning")), "Next Day transition should finish after both fades")
	_results["next_day_reset"] = {
		"state": _get_state(),
		"hud_visible": _main.get_node("HUD").intermission_hazard_panel.visible,
		"recovery_blocked": bool(_game_state.call("is_health_recovery_blocked")),
		"damage_accumulator": float(_main.get("_intermission_hazard_damage_accumulator")),
		"transition_finished": not bool(_main.get("_is_next_day_transitioning")),
	}


func _get_state() -> int:
	return int(_main.get("_intermission_hazard_state"))


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _print_and_quit() -> void:
	print(JSON.stringify({
		"ok": _failures.is_empty(),
		"failures": _failures,
		"results": _results,
	}, "\t"))
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
	get_tree().process_frame.connect(_quit_after_cleanup, CONNECT_ONE_SHOT)


func _quit_after_cleanup() -> void:
	get_tree().quit(0 if _failures.is_empty() else 1)
