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


func _run_checks() -> void:
	_check_catalog_schema()
	_check_passive_purchase_and_replacement()
	_check_all_equipped_weapons_type_condition()
	_check_equipped_weapon_count_condition()
	_check_generic_equipment_conditions()
	_check_rank_fallback_prices()
	_check_shop_reroll_progression()


func _reset_with_gold(amount: int = 5000) -> void:
	_game_state.call("reset_run")
	_game_state.call("add_gold", amount)


func _check_catalog_schema() -> void:
	var small_gear: Dictionary = _game_data.call("get_shop_item_definition", &"small_gear")
	var purity: Dictionary = _game_data.call("get_shop_item_definition", &"melee_purity_core")
	var focus: Dictionary = _game_data.call("get_shop_item_definition", &"module_focus_circuit")
	var purity_condition: Dictionary = (purity.get("conditions", []) as Array)[0]
	var focus_condition: Dictionary = (focus.get("conditions", []) as Array)[0]
	_results["catalog_schema"] = {
		"small_gear_category": small_gear.get("item_category", ""),
		"small_gear_damage_percent": (small_gear.get("effect_values", {}) as Dictionary).get("damage_percent", 0.0),
		"purity_condition": purity_condition,
		"focus_condition": focus_condition,
	}
	_expect(String(small_gear.get("item_category", "")) == "passive_module", "enhance rows should normalize to passive_module")
	_expect(is_equal_approx(float((small_gear.get("effect_values", {}) as Dictionary).get("damage_percent", 0.0)), 0.01), "small_gear should load a 1% damage effect")
	_expect(String(purity_condition.get("type", "")) == "all_equipped_weapons_type", "purity core should use the new all-equipped-weapons condition")
	_expect(String(focus_condition.get("type", "")) == "equipped_weapon_count_at_least", "focus circuit should use the new weapon-count condition")


func _check_passive_purchase_and_replacement() -> void:
	_reset_with_gold()
	for _index in range(GameConstants.PASSIVE_MODULE_MAX_EQUIPPED):
		_expect(bool((_game_state.call("purchase_shop_item", &"small_gear") as Dictionary).get("ok", false)), "small_gear should fill passive slots")
	var before_replace := float(_game_state.call("get_damage_percent"))
	var blocked: Dictionary = _game_state.call("purchase_shop_item", &"reinforced_bolt")
	var replaced: Dictionary = _game_state.call("purchase_shop_item", &"reinforced_bolt", {"passive_module_slot": 0})
	var after_replace := float(_game_state.call("get_damage_percent"))
	_results["passive_replacement"] = {
		"before_replace": before_replace,
		"blocked": blocked,
		"replaced": replaced,
		"after_replace": after_replace,
	}
	_expect(is_equal_approx(before_replace, 0.05), "five small gears should add 5% damage")
	_expect(String(blocked.get("reason", "")) == "passive_module_slot_required", "full passive slots should require a replacement target")
	_expect(bool(replaced.get("ok", false)) and int(replaced.get("slot", -1)) == 0, "selected passive slot should be replaceable")
	_expect(is_equal_approx(after_replace, 0.06), "replacement should remove the old 1% effect and apply the new 2% effect")


func _check_all_equipped_weapons_type_condition() -> void:
	_reset_with_gold()
	_game_state.call("grant_weapon", &"sword_module")
	_game_state.call("equip_weapon", &"sword_module", "left")
	var purchase: Dictionary = _game_state.call("purchase_shop_item", &"melee_purity_core")
	var area_only := float(_game_state.call("get_damage_percent"))
	var pistol: Dictionary = _game_state.call("purchase_shop_item", &"pistol_module@D")
	var mixed_types := float(_game_state.call("get_damage_percent"))
	_results["all_equipped_weapons_type"] = {
		"purchase": purchase,
		"area_only": area_only,
		"pistol": pistol,
		"mixed_types": mixed_types,
	}
	_expect(bool(purchase.get("ok", false)), "purity core should purchase as a passive")
	_expect(is_equal_approx(area_only, 0.20), "purity core should apply while all equipped weapons are area type")
	_expect(bool(pistol.get("ok", false)), "pistol should fill the right weapon slot")
	_expect(is_equal_approx(mixed_types, 0.0), "purity core should stop applying when projectile and area weapons are mixed")


func _check_equipped_weapon_count_condition() -> void:
	_reset_with_gold()
	var purchase: Dictionary = _game_state.call("purchase_shop_item", &"module_focus_circuit")
	var one_weapon := float(_game_state.call("get_damage_percent"))
	_game_state.call("purchase_shop_item", &"pistol_module@D")
	var two_weapons := float(_game_state.call("get_damage_percent"))
	_results["equipped_weapon_count"] = {
		"purchase": purchase,
		"one_weapon": one_weapon,
		"two_weapons": two_weapons,
	}
	_expect(bool(purchase.get("ok", false)), "focus circuit should purchase as a passive")
	_expect(is_equal_approx(one_weapon, 0.0), "focus circuit should stay inactive with one weapon")
	_expect(is_equal_approx(two_weapons, 0.02), "focus circuit should activate with two equipped weapons")


func _check_generic_equipment_conditions() -> void:
	_reset_with_gold()
	_game_state.call("purchase_shop_item", &"pistol_module@D")
	_game_state.call("purchase_shop_item", &"spark_field_d")
	var checks := {
		"has_projectile_weapon": _game_state.call("_is_item_condition_met", {"type": "weapon_slot_has_type", "slot": "right", "attack_type": "projectile"}),
		"has_electric_protocol": _game_state.call("_is_item_condition_met", {"type": "protocol_attribute_is", "attribute": "electric"}),
		"has_area_protocol": _game_state.call("_is_item_condition_met", {"type": "protocol_type_is", "attack_type": "area"}),
		"two_projectile_equipment": _game_state.call("_is_item_condition_met", {"type": "equipped_type_count_at_least", "attack_type": "projectile", "value": 2}),
	}
	_results["generic_conditions"] = checks
	for key in checks.keys():
		_expect(bool(checks[key]), "%s should be true" % key)


func _check_rank_fallback_prices() -> void:
	var expected_prices := {
		"small_gear": 15,
		"reinforced_bolt": 30,
		"aux_gear": 60,
		"output_amp_motor": 120,
		"reinforced_servo_arm": 240,
	}
	var actual_prices := {}
	for item_id in expected_prices.keys():
		var definition: Dictionary = _game_data.call("get_shop_item_definition", StringName(item_id))
		actual_prices[item_id] = _game_state.call("get_effective_shop_item_price", definition)
		_expect(int(actual_prices[item_id]) == int(expected_prices[item_id]), "%s fallback price should match rank" % item_id)
	_results["rank_fallback_prices"] = actual_prices


func _check_shop_reroll_progression() -> void:
	_reset_with_gold(1000)
	var first: Dictionary = _game_state.call("try_purchase_shop_reroll")
	var second: Dictionary = _game_state.call("try_purchase_shop_reroll")
	_results["shop_reroll"] = {
		"first": first,
		"second": second,
		"gold": _game_state.get("gold"),
	}
	_expect(int(first.get("cost", 0)) == 50, "first reroll should cost 50G")
	_expect(int(second.get("cost", 0)) == 75, "second reroll should cost 75G")
	_expect(int(_game_state.get("gold")) == 875, "two rerolls should deduct 125G")


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
