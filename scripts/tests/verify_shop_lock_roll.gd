extends SceneTree

var _failures: Array[String] = []
var _results: Dictionary = {}
var _ran := false
var _game_state: Node = null
var _game_data: Node = null


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
	_run_checks()
	_print_and_quit()
	return true


func _print_and_quit() -> void:
	print(JSON.stringify({
		"ok": _failures.is_empty(),
		"failures": _failures,
		"results": _results,
	}, "\t"))
	quit(0 if _failures.is_empty() else 1)


func _run_checks() -> void:
	_check_locked_item_roll_preserves_slot()
	_check_lock_payload_survives_slot_shift()
	_check_reset_run_clears_shop_locks()


func _reset_with_gold(amount: int = 1000) -> void:
	_game_state.call("reset_run")
	_game_state.call("add_gold", amount)


func _check_locked_item_roll_preserves_slot() -> void:
	_reset_with_gold()
	var initial_ids := PackedStringArray([
		"sword_module",
		"dagger_module",
		"lance_module",
		"axe_module",
		"greatsword_module",
	])
	var locked_slot := 2
	var locked_item_id := String(initial_ids[locked_slot])
	_game_state.call("set_shop_slot_locked", locked_slot, true, StringName(locked_item_id))

	var locked_slots: Dictionary = _game_state.call("get_current_shop_locked_slots")
	_record("locked_slot_payload", locked_slots.duplicate(true))
	_expect(String(locked_slots.get(locked_slot, "")) == locked_item_id, "locked slot should store the locked item id")

	var rng := RandomNumberGenerator.new()
	rng.seed = 24680
	var rolled_ids: PackedStringArray = _game_data.call(
		"roll_shop_item_ids",
		rng,
		GameConstants.DAY_SHOP_ITEM_COUNT,
		_game_state.call("get_shop_roll_context")
	)
	var locked_item_count := 0
	for raw_item_id in rolled_ids:
		if String(raw_item_id) == locked_item_id:
			locked_item_count += 1

	var snapshot: Dictionary = _game_state.call("get_day_shop_snapshot", rolled_ids)
	var entries: Array = snapshot.get("item_entries", [])
	var locked_entry_is_locked := false
	var locked_entry_id := ""
	if locked_slot < entries.size():
		var locked_entry: Dictionary = entries[locked_slot]
		locked_entry_is_locked = bool(locked_entry.get("is_locked", false))
		locked_entry_id = String(locked_entry.get("item_id", ""))

	_record("locked_roll_ids", Array(rolled_ids))
	_record("locked_roll_snapshot_slot", {
		"slot": locked_slot,
		"item_id": locked_entry_id,
		"is_locked": locked_entry_is_locked,
	})
	_expect(rolled_ids.size() == GameConstants.DAY_SHOP_ITEM_COUNT, "locked roll should still return exactly DAY_SHOP_ITEM_COUNT items")
	_expect(String(rolled_ids[locked_slot]) == locked_item_id, "locked item should occupy its locked shop slot after roll")
	_expect(locked_item_count == 1, "locked item should occupy a normal slot, not be added as an extra duplicate")
	_expect(locked_entry_id == locked_item_id and locked_entry_is_locked, "locked item snapshot should remain locked in the same slot")


func _check_lock_payload_survives_slot_shift() -> void:
	_game_state.call("reset_shop_locks")
	_game_state.call("set_shop_slot_locked", 3, true, &"axe_module")
	_game_state.call("remove_shop_slot_lock_and_shift", 1)
	var locked_slots: Dictionary = _game_state.call("get_current_shop_locked_slots")
	_record("shifted_lock_payload", locked_slots.duplicate(true))
	_expect(not locked_slots.has(3), "lock above a purchased slot should shift down")
	_expect(String(locked_slots.get(2, "")) == "axe_module", "shifted lock should keep its item id payload")


func _check_reset_run_clears_shop_locks() -> void:
	_game_state.call("set_shop_slot_locked", 0, true, &"sword_module")
	_game_state.call("reset_run")
	var locked_slots: Dictionary = _game_state.call("get_current_shop_locked_slots")
	_record("locks_after_reset_run", locked_slots.duplicate(true))
	_expect(locked_slots.is_empty(), "reset_run should clear shop locks")


func _record(key: String, value: Variant) -> void:
	_results[key] = value


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
