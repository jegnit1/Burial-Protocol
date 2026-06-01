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
	_game_state.call("add_gold", 10000)
	_check_weapon_purchase_slots()
	_check_drone_protocol_purchase_slots()
	_check_passive_module_purchase_slots()
	_check_shop_ui_equipment_rows()


func _check_weapon_purchase_slots() -> void:
	var right_result: Dictionary = _game_state.call("purchase_shop_item", &"pistol_module@D")
	var blocked_gold := int(_game_state.get("gold"))
	var blocked_result: Dictionary = _game_state.call("purchase_shop_item", &"axe_module@D")
	var replace_result: Dictionary = _game_state.call("purchase_shop_item", &"axe_module@D", {"weapon_slot": "left"})
	var left: Dictionary = _game_state.call("get_equipped_weapon_left")
	var right: Dictionary = _game_state.call("get_equipped_weapon_right")
	_results["weapons"] = {
		"right_result": right_result,
		"blocked_result": blocked_result,
		"replace_result": replace_result,
		"left": left,
		"right": right,
	}
	_expect(bool(right_result.get("ok", false)) and String(right_result.get("slot", "")) == "right", "first bought weapon should fill the empty right slot")
	_expect(not bool(blocked_result.get("ok", false)) and String(blocked_result.get("reason", "")) == "weapon_slot_required", "full weapon slots should require an explicit replacement target")
	_expect(int(_game_state.get("gold")) < blocked_gold, "explicit weapon replacement should spend gold")
	_expect(String(left.get("module_id", "")) == "axe_module", "selected left weapon slot should be replaced")
	_expect(String(right.get("module_id", "")) == "pistol_module", "right weapon slot should remain equipped")


func _check_drone_protocol_purchase_slots() -> void:
	var purchase_results: Array[Dictionary] = []
	for _index in range(GameConstants.DRONE_PROTOCOL_MAX_EQUIPPED):
		purchase_results.append(_game_state.call("purchase_shop_item", &"combat_drone_d"))
	var blocked_result: Dictionary = _game_state.call("purchase_shop_item", &"combat_drone_d")
	var replace_result: Dictionary = _game_state.call(
		"purchase_shop_item",
		&"cleaner_bot_d",
		{"drone_protocol_slot": 2}
	)
	var entries: Array = _game_state.call("get_equipped_drone_protocol_entries")
	_results["drone_protocols"] = {
		"purchase_results": purchase_results,
		"blocked_result": blocked_result,
		"replace_result": replace_result,
		"entries": entries,
	}
	_expect(entries.size() == GameConstants.DRONE_PROTOCOL_MAX_EQUIPPED, "protocol purchases should fill exactly five slots")
	_expect(not bool(blocked_result.get("ok", false)) and String(blocked_result.get("reason", "")) == "drone_protocol_slot_required", "full protocol slots should require an explicit replacement target")
	_expect(String((entries[2] as Dictionary).get("item_id", "")) == "cleaner_bot_d", "selected protocol slot should be replaced")


func _check_passive_module_purchase_slots() -> void:
	var purchase_results: Array[Dictionary] = []
	for _index in range(GameConstants.PASSIVE_MODULE_MAX_EQUIPPED):
		purchase_results.append(_game_state.call("purchase_shop_item", &"small_gear"))
	var damage_percent_before_replace := float(_game_state.call("get_damage_percent"))
	var blocked_result: Dictionary = _game_state.call("purchase_shop_item", &"small_gear")
	var replace_result: Dictionary = _game_state.call(
		"purchase_shop_item",
		&"reinforced_bolt",
		{"passive_module_slot": 1}
	)
	var damage_percent_after_replace := float(_game_state.call("get_damage_percent"))
	var entries: Array = _game_state.call("get_equipped_passive_module_entries")
	_results["passives"] = {
		"purchase_results": purchase_results,
		"blocked_result": blocked_result,
		"replace_result": replace_result,
		"damage_percent_before_replace": damage_percent_before_replace,
		"damage_percent_after_replace": damage_percent_after_replace,
		"entries": entries,
	}
	_expect(entries.size() == GameConstants.PASSIVE_MODULE_MAX_EQUIPPED, "passive purchases should fill exactly five slots")
	_expect(not bool(blocked_result.get("ok", false)) and String(blocked_result.get("reason", "")) == "passive_module_slot_required", "sixth passive purchase should require a replacement target")
	_expect(String((entries[1] as Dictionary).get("item_id", "")) == "reinforced_bolt", "selected passive slot should be replaced")
	_expect(is_equal_approx(damage_percent_before_replace, 0.05), "five small gears should add 5% damage")
	_expect(is_equal_approx(damage_percent_after_replace, 0.06), "replacing one small gear with reinforced bolt should recalculate damage to 6%")


func _check_shop_ui_equipment_rows() -> void:
	var shop_ui_script := load("res://scenes/ui/DayShopUI.gd")
	var shop_ui = shop_ui_script.new()
	get_root().add_child(shop_ui)
	var snapshot: Dictionary = _game_state.call(
		"get_day_shop_snapshot",
		PackedStringArray(["pistol_module@D", "combat_drone_d", "small_gear"])
	)
	var categories: Array[String] = []
	for raw_entry in snapshot.get("item_entries", []):
		categories.append(String((raw_entry as Dictionary).get("item_category", "")))
	var slots_vbox = shop_ui.get("_equipment_slots_vbox")
	shop_ui.set("_selected_drone_protocol_slot", 2)
	shop_ui.call("_clear_equipment_target_for_category", "drone_protocol")
	shop_ui.set("_selected_passive_module_slot", 3)
	shop_ui.call("_clear_equipment_target_for_category", "passive_module")
	_results["shop_ui"] = {
		"categories": categories,
		"equipment_row_count": slots_vbox.get_child_count(),
		"protocol_label": shop_ui.call("_category_label", "drone_protocol"),
		"passive_label": shop_ui.call("_category_label", "passive_module"),
		"protocol_target_after_purchase": shop_ui.get("_selected_drone_protocol_slot"),
		"passive_target_after_purchase": shop_ui.get("_selected_passive_module_slot"),
	}
	_expect(categories == ["weapon", "drone_protocol", "passive_module"], "shop snapshot should expose new equipment categories")
	_expect(slots_vbox.get_child_count() == 4, "shop UI should render weapon, drone, protocol, and passive rows")
	_expect(int(shop_ui.get("_selected_drone_protocol_slot")) == -1, "successful protocol purchase should clear the replacement target")
	_expect(int(shop_ui.get("_selected_passive_module_slot")) == -1, "successful passive purchase should clear the replacement target")
	shop_ui.queue_free()


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
