extends SceneTree

var _failures: Array[String] = []
var _results: Dictionary = {}
var _ran := false
var _game_state: Node = null
var _game_data: Node = null
var _player: Node2D = null


func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	_game_state = get_root().get_node_or_null("GameState")
	_game_data = get_root().get_node_or_null("GameData")
	if _game_state == null or _game_data == null:
		_failures.append("GameState/GameData autoloads should be available")
		_print_and_quit()
		return true
	var player_scene := load("res://scenes/player/Player.tscn") as PackedScene
	_player = player_scene.instantiate() as Node2D
	get_root().add_child(_player)
	_run_checks()
	_print_and_quit()
	return true


func _run_checks() -> void:
	_game_state.call("reset_run")
	_expect(_game_state.call("grant_weapon", &"pistol_module"), "pistol should be grantable")
	_expect(_game_state.call("equip_weapon", &"pistol_module", "right"), "pistol should equip to the right slot")
	_player.call("_sync_attack_module_visual")
	_check_weapon_triggers()
	_check_protocol_triggers()
	_check_visuals()


func _check_weapon_triggers() -> void:
	_player.set("attack_buffer_remaining", GameConstants.PLAYER_ATTACK_BUFFER_TIME)
	_player.set("pending_attack_direction", Vector2.RIGHT)
	var initial: Array = _player.call("consume_attack_module_triggers")
	var immediate_retry: Array = _player.call("consume_attack_module_triggers")
	var cooldowns: Dictionary = (_player.get("attack_module_cooldowns") as Dictionary).duplicate(true)
	_results["weapon_triggers"] = {
		"initial_count": initial.size(),
		"immediate_retry_count": immediate_retry.size(),
		"cooldowns": cooldowns,
	}
	_expect(initial.size() == GameConstants.WEAPON_SLOT_COUNT, "one left click buffer should trigger both equipped weapons")
	_expect(immediate_retry.is_empty(), "weapons should not retrigger while their cooldowns are active")
	var weapon_entries: Array = _game_state.call("get_equipped_weapon_entries")
	_expect(weapon_entries.size() == GameConstants.WEAPON_SLOT_COUNT, "snapshot requires two equipped weapons")
	if weapon_entries.size() < GameConstants.WEAPON_SLOT_COUNT:
		return
	var left_id := String((weapon_entries[0] as Dictionary).get("instance_id", ""))
	var right_id := String((weapon_entries[1] as Dictionary).get("instance_id", ""))
	var independent_cooldowns: Dictionary = _player.get("attack_module_cooldowns")
	independent_cooldowns[left_id] = 0.0
	independent_cooldowns[right_id] = 99.0
	_player.set("attack_buffer_remaining", GameConstants.PLAYER_ATTACK_BUFFER_TIME)
	var left_only: Array = _player.call("consume_attack_module_triggers")
	_results["weapon_triggers"]["left_only_count"] = left_only.size()
	_expect(left_only.size() == 1, "weapon cooldowns should advance independently")


func _check_protocol_triggers() -> void:
	_expect(_game_state.call("equip_drone_protocol", &"combat_drone_d"), "combat protocol should equip")
	_expect(_game_state.call("equip_drone_protocol", &"cleaner_bot_d"), "cleaner protocol should equip")
	_expect(_game_state.call("equip_drone_protocol", &"spark_field_d"), "aura protocol should equip")
	var initial: Array = _player.call("consume_drone_protocol_triggers")
	var immediate_retry: Array = _player.call("consume_drone_protocol_triggers")
	var cooldowns: Dictionary = (_player.get("drone_protocol_cooldowns") as Dictionary).duplicate(true)
	var behaviors: Array[String] = []
	for raw_trigger in initial:
		var trigger: Dictionary = raw_trigger
		var entry: Dictionary = trigger.get("protocol_entry", {})
		var definition: Dictionary = _game_data.call("get_shop_item_definition", StringName(String(entry.get("item_id", ""))))
		behaviors.append(String(definition.get("protocol_behavior", "")))
	_results["protocol_triggers"] = {
		"initial_count": initial.size(),
		"immediate_retry_count": immediate_retry.size(),
		"behaviors": behaviors,
		"cooldowns": cooldowns,
	}
	_expect(initial.size() == 3, "each equipped protocol should trigger independently")
	_expect(immediate_retry.is_empty(), "protocols should wait for their independent cooldowns")
	_expect(behaviors.has("combat_drone"), "combat protocol behavior should be available")
	_expect(behaviors.has("sand_cleaner"), "cleaner protocol behavior should be available")
	_expect(behaviors.has("aura_damage"), "aura protocol behavior should be available")


func _check_visuals() -> void:
	var snapshot: Dictionary = _player.call("get_equipment_trigger_debug_snapshot")
	_results["visuals"] = snapshot
	_expect(bool(snapshot.get("has_left_weapon_visual", false)), "left weapon visual should exist")
	_expect(bool(snapshot.get("has_right_weapon_visual", false)), "right weapon visual should exist")
	_expect(bool(snapshot.get("has_drone_visual", false)), "basic drone visual should exist")
	var drone_position: Vector2 = snapshot.get("drone_position", Vector2.ZERO)
	_expect(drone_position.y < _player.global_position.y, "basic drone visual should float above the player")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _print_and_quit() -> void:
	print(JSON.stringify({
		"ok": _failures.is_empty(),
		"failures": _failures,
		"results": _results,
	}, "\t"))
	quit(0 if _failures.is_empty() else 1)
