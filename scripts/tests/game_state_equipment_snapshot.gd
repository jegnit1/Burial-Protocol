extends SceneTree

var _failures: Array[String] = []
var _results: Dictionary = {}
var _ran := false
var _game_state: Node = null


func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	_game_state = get_root().get_node_or_null("GameState")
	if _game_state == null:
		_failures.append("GameState autoload should be available")
		_print_and_quit()
		return true
	_run_checks()
	_print_and_quit()
	return true


func _run_checks() -> void:
	_game_state.call("reset_run")
	_check_weapon_slots()
	_check_drone_protocol_slots()
	_check_passive_module_slots()
	_check_level_up_cards_and_stats()
	_check_stat_panel()


func _check_weapon_slots() -> void:
	var left: Dictionary = _game_state.call("get_equipped_weapon_left")
	var right: Dictionary = _game_state.call("get_equipped_weapon_right")
	_expect(not left.is_empty(), "new run should equip a default left weapon")
	_expect(right.is_empty(), "new run should keep the right weapon slot empty")
	_expect((_game_state.call("get_input_attack_module_entries") as Array).size() == 1, "new run should expose the default left weapon to Player")
	_expect(_game_state.call("grant_weapon", &"pistol_module"), "pistol should be grantable as a weapon")
	_expect(_game_state.call("equip_weapon", &"pistol_module", "right"), "pistol should equip to the right weapon slot")
	var weapons: Array = _game_state.call("get_equipped_weapon_entries")
	_results["weapons"] = {
		"left": _game_state.call("get_equipped_weapon_left"),
		"right": _game_state.call("get_equipped_weapon_right"),
		"equipped_count": weapons.size(),
		"player_weapon_count": (_game_state.call("get_input_attack_module_entries") as Array).size(),
	}
	_expect(weapons.size() == GameConstants.WEAPON_SLOT_COUNT, "two weapon slots should be available")
	_expect((_game_state.call("get_input_attack_module_entries") as Array).size() == GameConstants.WEAPON_SLOT_COUNT, "Phase 4 Player adapter should expose both weapon slots")


func _check_drone_protocol_slots() -> void:
	var equip_results: Array[bool] = []
	for _index in range(GameConstants.DRONE_PROTOCOL_MAX_EQUIPPED):
		equip_results.append(bool(_game_state.call("equip_drone_protocol", &"spark_field_d")))
	var overflow := bool(_game_state.call("equip_drone_protocol", &"spark_field_d"))
	var entries: Array = _game_state.call("get_equipped_drone_protocol_entries")
	_results["drone_protocols"] = {
		"drone_id": String(_game_state.call("get_equipped_drone_id")),
		"equip_results": equip_results,
		"overflow": overflow,
		"equipped_count": entries.size(),
		"cooldown": _game_state.call("get_drone_protocol_cooldown_duration", entries[0]),
	}
	_expect(String(_game_state.call("get_equipped_drone_id")) == String(GameConstants.DEFAULT_DRONE_ID), "new run should use the basic drone")
	_expect(not equip_results.has(false), "the same protocol should equip five times")
	_expect(entries.size() == GameConstants.DRONE_PROTOCOL_MAX_EQUIPPED, "protocol slots should cap at five")
	_expect(not overflow, "sixth protocol should be rejected")


func _check_passive_module_slots() -> void:
	var equip_results: Array[bool] = []
	for _index in range(GameConstants.PASSIVE_MODULE_MAX_EQUIPPED):
		equip_results.append(bool(_game_state.call("equip_passive_module", &"small_gear")))
	var overflow := bool(_game_state.call("equip_passive_module", &"small_gear"))
	var entries: Array = _game_state.call("get_equipped_passive_module_entries")
	_results["passive_modules"] = {
		"equip_results": equip_results,
		"overflow": overflow,
		"equipped_count": entries.size(),
	}
	_expect(not equip_results.has(false), "passive module slots should accept five entries")
	_expect(entries.size() == GameConstants.PASSIVE_MODULE_MAX_EQUIPPED, "passive module slots should cap at five")
	_expect(not overflow, "sixth passive module should be rejected")


func _check_level_up_cards_and_stats() -> void:
	var card_ids: Array[String] = []
	for definition in _game_state.call("get_level_up_card_pool"):
		card_ids.append(String((definition as Dictionary).get("id", "")))
	_expect(card_ids.has("weapon_attack_up"), "level-up pool should include weapon attack")
	_expect(card_ids.has("drone_attack_up"), "level-up pool should include drone attack")
	_expect(card_ids.has("attack_speed_up"), "level-up pool should include weapon attack speed")
	_expect(not card_ids.has("melee_atk_up"), "level-up pool should remove melee attack")
	_expect(not card_ids.has("ranged_atk_up"), "level-up pool should remove ranged attack")
	_expect(not card_ids.has("drone_cooldown_reduction_up"), "level-up pool should exclude rare drone cooldown reduction")
	var weapon_before := int(_game_state.call("get_weapon_attack_damage_flat"))
	var drone_before := int(_game_state.call("get_drone_attack_damage_flat"))
	_game_state.call("apply_level_up_card", "weapon_attack_up")
	_game_state.call("apply_level_up_card", "drone_attack_up")
	_results["level_up"] = {
		"card_ids": card_ids,
		"weapon_before": weapon_before,
		"weapon_after": _game_state.call("get_weapon_attack_damage_flat"),
		"drone_before": drone_before,
		"drone_after": _game_state.call("get_drone_attack_damage_flat"),
	}
	_expect(int(_game_state.call("get_weapon_attack_damage_flat")) == weapon_before + 1, "weapon attack card should add one weapon attack")
	_expect(int(_game_state.call("get_drone_attack_damage_flat")) == drone_before + 1, "drone attack card should add one drone attack")


func _check_stat_panel() -> void:
	var labels: Array[String] = []
	for raw_entry in _game_state.call("get_stat_panel_entries"):
		labels.append(String((raw_entry as Dictionary).get("label", "")))
	_results["stat_panel_labels"] = labels
	_expect(labels.has("좌측 무기"), "stat panel should show left weapon")
	_expect(labels.has("우측 무기"), "stat panel should show right weapon")
	_expect(labels.has("드론 공격력"), "stat panel should show drone attack")
	_expect(labels.has("드론 쿨타임 감소"), "stat panel should show drone cooldown reduction")
	_expect(not labels.has("근거리 공격력"), "stat panel should remove melee attack")
	_expect(not labels.has("원거리 공격력"), "stat panel should remove ranged attack")


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
