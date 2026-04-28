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
	_check_catalog_loads_new_and_legacy_items()
	_check_attack_module_style_fields()
	_check_melee_style_shape_growth()
	_check_ranged_attack_module_style_fields()
	_check_ranged_range_growth_only()
	_check_apply_dictionary_style_resolver_defaults()
	_check_sand_xp_accumulator()
	_check_existing_stat_bonus_purchase()
	_check_melee_purity_core_condition()
	_check_module_focus_circuit_condition()
	_check_attack_module_add_and_synthesis_smoke()
	_check_shop_item_price_deduction()
	_check_shop_reroll_cost_progression()
	_check_shop_reroll_gold_failure_and_reset()
	_check_shop_reroll_roll_count_and_prices()


func _reset_with_gold(amount: int = 5000) -> void:
	_game_state.call("reset_run")
	_game_state.call("add_gold", amount)


func _check_catalog_loads_new_and_legacy_items() -> void:
	var legacy_item: Dictionary = _game_data.call("get_shop_item_definition", &"small_gear")
	var melee_item: Dictionary = _game_data.call("get_shop_item_definition", &"melee_purity_core")
	var focus_item: Dictionary = _game_data.call("get_shop_item_definition", &"module_focus_circuit")
	_record("legacy_has_conditions", legacy_item.has("conditions"))
	_record("legacy_effect_type", String(legacy_item.get("effect_type", "")))
	_record("melee_apply_timing", String(melee_item.get("apply_timing", "")))
	_record("focus_condition_type", String((focus_item.get("conditions", []) as Array)[0].get("type", "")))
	_expect(not legacy_item.is_empty(), "small_gear should load")
	_expect(legacy_item.has("conditions"), "legacy item should receive default conditions")
	_expect((legacy_item.get("conditions", []) as Array).is_empty(), "legacy item default conditions should be empty")
	_expect((legacy_item.get("effects", []) as Array).size() == 1, "legacy stat_bonus should normalize one effect entry")
	_expect(String(melee_item.get("effect_type", "")) == "conditional_stat_bonus", "melee_purity_core should load as conditional_stat_bonus")
	_expect(String(focus_item.get("effect_type", "")) == "conditional_stat_bonus", "module_focus_circuit should load as conditional_stat_bonus")


func _check_attack_module_style_fields() -> void:
	var expected := {
		"sword_module": {"attack_style": "slash", "effect_style": "slash_arc", "base": Vector2(1.0, 1.0), "growth": Vector2(1.0, 0.1)},
		"dagger_module": {"attack_style": "stab", "effect_style": "short_stab", "base": Vector2(0.5, 0.5), "growth": Vector2(1.0, 0.0)},
		"lance_module": {"attack_style": "pierce", "effect_style": "long_pierce", "base": Vector2(2.5, 0.5), "growth": Vector2(1.0, 0.0)},
		"axe_module": {"attack_style": "smash", "effect_style": "blunt_smash", "base": Vector2(1.0, 1.0), "growth": Vector2(1.0, 0.1)},
		"greatsword_module": {"attack_style": "cleave", "effect_style": "big_cleave", "base": Vector2(1.5, 1.0), "growth": Vector2(1.0, 0.2)},
	}
	var loaded := {}
	for module_id in expected.keys():
		var definition = _game_data.call("get_attack_module_definition", StringName(module_id))
		var expected_entry: Dictionary = expected[module_id]
		_expect(definition != null, "%s should load as attack module definition" % module_id)
		if definition == null:
			continue
		loaded[module_id] = {
			"attack_style": String(definition.attack_style),
			"effect_style": String(definition.effect_style),
			"base_shape_units": {"x": definition.base_shape_units.x, "y": definition.base_shape_units.y},
			"range_growth": {"width": definition.range_growth_width_scale, "height": definition.range_growth_height_scale},
		}
		_expect(String(definition.module_type) == "melee", "%s should remain melee" % module_id)
		_expect(String(definition.attack_style) == String(expected_entry["attack_style"]), "%s attack_style should match" % module_id)
		_expect(String(definition.effect_style) == String(expected_entry["effect_style"]), "%s effect_style should match" % module_id)
		_expect(_is_vector_near(definition.base_shape_units, expected_entry["base"]), "%s base_shape_units should match" % module_id)
		_expect(is_equal_approx(definition.range_growth_width_scale, (expected_entry["growth"] as Vector2).x), "%s width growth should match" % module_id)
		_expect(is_equal_approx(definition.range_growth_height_scale, (expected_entry["growth"] as Vector2).y), "%s height growth should match" % module_id)
	_record("attack_module_style_fields", loaded)


func _check_melee_style_shape_growth() -> void:
	_reset_with_gold()
	var module_ids := ["sword_module", "dagger_module", "lance_module", "axe_module", "greatsword_module"]
	for module_id in module_ids:
		if module_id != "sword_module":
			_game_state.call("purchase_shop_item", StringName(module_id))
	var before := {}
	var after := {}
	for entry in _get_equipped_attack_module_entries():
		var module_id := String(entry.get("module_id", ""))
		var style_snapshot: Dictionary = _game_state.call("get_attack_module_style_snapshot", entry, 1.5)
		before[module_id] = style_snapshot.get("current_shape_units", {})
		after[module_id] = style_snapshot.get("bonus_shape_units", {})
		var current_shape: Dictionary = style_snapshot.get("current_shape_units", {})
		var bonus_shape: Dictionary = style_snapshot.get("bonus_shape_units", {})
		var growth_height := float(style_snapshot.get("range_growth_height_scale", 0.0))
		_expect(float(bonus_shape.get("x", 0.0)) > float(current_shape.get("x", 0.0)), "%s width should grow with attack range" % module_id)
		if growth_height <= 0.0:
			_expect(is_equal_approx(float(bonus_shape.get("y", 0.0)), float(current_shape.get("y", 0.0))), "%s height should not grow" % module_id)
		else:
			_expect(float(bonus_shape.get("y", 0.0)) > float(current_shape.get("y", 0.0)), "%s height should grow by style scale" % module_id)
	var bow_definition = _game_data.call("get_attack_module_definition", &"bow_module")
	var drone_definition = _game_data.call("get_attack_module_definition", &"drone_attack_module")
	_expect(bow_definition != null and bow_definition.module_type == &"ranged", "bow_module should remain ranged")
	_expect(drone_definition != null and drone_definition.module_type == &"mechanic", "drone_attack_module should remain mechanic")
	_record("melee_shape_before_range_bonus", before)
	_record("melee_shape_after_50pct_range_bonus", after)


func _check_ranged_attack_module_style_fields() -> void:
	var expected := {
		"bow_module": {"attack_style": "rifle", "effect_style": "rifle_projectile", "projectile_count": 1, "spread_angle": 0.0, "pierce_count": 0, "is_hitscan": false},
		"scatter_module": {"attack_style": "shotgun", "effect_style": "shotgun_spread", "projectile_count": 3, "spread_angle": 26.0, "pierce_count": 0, "is_hitscan": false},
		"pierce_module": {"attack_style": "sniper", "effect_style": "sniper_projectile", "projectile_count": 1, "spread_angle": 0.0, "pierce_count": 2, "is_hitscan": false},
		"laser_module": {"attack_style": "laser", "effect_style": "laser_beam", "projectile_count": 0, "spread_angle": 0.0, "pierce_count": 0, "is_hitscan": true},
	}
	var loaded := {}
	for module_id in expected.keys():
		var definition = _game_data.call("get_attack_module_definition", StringName(module_id))
		var expected_entry: Dictionary = expected[module_id]
		_expect(definition != null, "%s should load as ranged attack module definition" % module_id)
		if definition == null:
			continue
		loaded[module_id] = {
			"attack_style": String(definition.attack_style),
			"effect_style": String(definition.effect_style),
			"range_units": definition.range_units,
			"projectile_count": definition.projectile_count,
			"spread_angle": definition.spread_angle,
			"pierce_count": definition.pierce_count,
			"is_hitscan": definition.is_hitscan,
			"projectile_visual_size": {"x": definition.projectile_visual_size.x, "y": definition.projectile_visual_size.y},
		}
		_expect(String(definition.module_type) == "ranged", "%s should remain ranged" % module_id)
		_expect(String(definition.attack_style) == String(expected_entry["attack_style"]), "%s attack_style should match" % module_id)
		_expect(String(definition.effect_style) == String(expected_entry["effect_style"]), "%s effect_style should match" % module_id)
		_expect(definition.projectile_count == int(expected_entry["projectile_count"]), "%s projectile_count should match" % module_id)
		_expect(is_equal_approx(definition.spread_angle, float(expected_entry["spread_angle"])), "%s spread_angle should match" % module_id)
		_expect(definition.pierce_count == int(expected_entry["pierce_count"]), "%s pierce_count should match" % module_id)
		_expect(definition.is_hitscan == bool(expected_entry["is_hitscan"]), "%s is_hitscan should match" % module_id)
		_expect(definition.range_units > 0.0, "%s range_units should be positive" % module_id)
		_expect(definition.projectile_visual_size.x > 0.0 and definition.projectile_visual_size.y > 0.0, "%s projectile_visual_size should be positive" % module_id)
	var drone_definition = _game_data.call("get_attack_module_definition", &"drone_attack_module")
	_expect(drone_definition != null and drone_definition.module_type == &"mechanic", "drone_attack_module should remain mechanic")
	_record("ranged_attack_module_style_fields", loaded)


func _check_ranged_range_growth_only() -> void:
	_reset_with_gold()
	_game_state.call("purchase_shop_item", &"bow_module")
	_game_state.call("purchase_shop_item", &"scatter_module")
	_game_state.call("purchase_shop_item", &"pierce_module")
	_game_state.call("purchase_shop_item", &"laser_module")
	var snapshots := {}
	for entry in _get_equipped_attack_module_entries():
		var module_id := String(entry.get("module_id", ""))
		if module_id == "sword_module":
			continue
		var style_snapshot: Dictionary = _game_state.call("get_attack_module_style_snapshot", entry, 1.5)
		var current_shape: Dictionary = style_snapshot.get("current_shape_units", {})
		var bonus_shape: Dictionary = style_snapshot.get("bonus_shape_units", {})
		snapshots[module_id] = {
			"attack_style": style_snapshot.get("attack_style", ""),
			"current_shape_units": current_shape,
			"bonus_shape_units": bonus_shape,
			"projectile_count": style_snapshot.get("projectile_count", 0),
			"spread_angle": style_snapshot.get("spread_angle", 0.0),
			"pierce_count": style_snapshot.get("pierce_count", 0),
			"is_hitscan": style_snapshot.get("is_hitscan", false),
			"projectile_visual_size": style_snapshot.get("projectile_visual_size", {}),
		}
		_expect(float(bonus_shape.get("x", 0.0)) > float(current_shape.get("x", 0.0)), "%s range length should grow with attack range" % module_id)
		_expect(is_equal_approx(float(bonus_shape.get("y", 0.0)), float(current_shape.get("y", 0.0))), "%s projectile/hitscan thickness should not grow with attack range" % module_id)
	_expect(int(snapshots.get("scatter_module", {}).get("projectile_count", 0)) == 3, "shotgun projectile_count should stay style-defined")
	_expect(is_equal_approx(float(snapshots.get("scatter_module", {}).get("spread_angle", 0.0)), 26.0), "shotgun spread_angle should stay style-defined")
	_expect(int(snapshots.get("pierce_module", {}).get("pierce_count", 0)) == 2, "sniper pierce_count should stay style-defined")
	_expect(bool(snapshots.get("laser_module", {}).get("is_hitscan", false)), "laser should stay hitscan")
	_record("ranged_range_growth_only", snapshots)


func _check_apply_dictionary_style_resolver_defaults() -> void:
	var melee := ShopItemDefinition.new()
	melee.apply_dictionary({
		"item_id": "imported_stab",
		"item_category": "attack_module",
		"module_type": "melee",
		"attack_style": "stab",
	})
	_expect(String(melee.attack_style) == "stab", "apply_dictionary melee attack_style should stay explicit")
	_expect(String(melee.effect_style) == "short_stab", "apply_dictionary melee effect_style should use resolver default")
	_expect(_is_vector_near(melee.base_shape_units, Vector2(0.5, 0.5)), "apply_dictionary melee base_shape_units should use resolver default")
	_expect(is_equal_approx(melee.range_growth_width_scale, 1.0), "apply_dictionary melee width growth should use resolver default")
	_expect(is_equal_approx(melee.range_growth_height_scale, 0.0), "apply_dictionary melee height growth should use resolver default")

	var ranged := ShopItemDefinition.new()
	ranged.apply_dictionary({
		"item_id": "imported_spread",
		"item_category": "attack_module",
		"module_type": "ranged",
		"attack_style": "spread",
		"range_width_u": 4.0,
		"range_height_u": 0.7,
	})
	_expect(String(ranged.attack_style) == "shotgun", "apply_dictionary ranged alias should normalize through resolver")
	_expect(String(ranged.effect_style) == "shotgun_spread", "apply_dictionary ranged effect_style should use resolver default")
	_expect(is_equal_approx(ranged.range_units, 4.0), "apply_dictionary ranged range_units should fall back from range_width_u")
	_expect(ranged.projectile_count == 3, "apply_dictionary shotgun projectile_count should use resolver default")
	_expect(is_equal_approx(ranged.spread_angle, 26.0), "apply_dictionary shotgun spread_angle should use resolver default")
	_expect(ranged.pierce_count == 0, "apply_dictionary shotgun pierce_count should use resolver default")
	_expect(not ranged.is_hitscan, "apply_dictionary shotgun should not become hitscan")
	_expect(_is_vector_near(ranged.projectile_visual_size, Vector2(14.0, 5.0)), "apply_dictionary shotgun visual size should use resolver default")

	var explicit := ShopItemDefinition.new()
	explicit.apply_dictionary({
		"item_id": "imported_explicit",
		"item_category": "attack_module",
		"module_type": "ranged",
		"attack_style": "rifle",
		"effect_style": "custom_projectile",
		"range_units": 9.0,
		"projectile_count": 5,
		"spread_angle": 33.0,
		"pierce_count": 4,
		"is_hitscan": true,
		"projectile_visual_size_x": 22.0,
		"projectile_visual_size_y": 9.0,
	})
	_expect(String(explicit.effect_style) == "custom_projectile", "apply_dictionary explicit effect_style should win over resolver")
	_expect(is_equal_approx(explicit.range_units, 9.0), "apply_dictionary explicit range_units should win over resolver")
	_expect(explicit.projectile_count == 5, "apply_dictionary explicit projectile_count should win over resolver")
	_expect(is_equal_approx(explicit.spread_angle, 33.0), "apply_dictionary explicit spread_angle should win over resolver")
	_expect(explicit.pierce_count == 4, "apply_dictionary explicit pierce_count should win over resolver")
	_expect(explicit.is_hitscan, "apply_dictionary explicit is_hitscan should win over resolver")
	_expect(_is_vector_near(explicit.projectile_visual_size, Vector2(22.0, 9.0)), "apply_dictionary explicit projectile_visual_size should win over resolver")
	_record("apply_dictionary_style_resolver_defaults", {
		"melee": {
			"attack_style": String(melee.attack_style),
			"effect_style": String(melee.effect_style),
			"base_shape_units": {"x": melee.base_shape_units.x, "y": melee.base_shape_units.y},
			"range_growth": {"width": melee.range_growth_width_scale, "height": melee.range_growth_height_scale},
		},
		"ranged": {
			"attack_style": String(ranged.attack_style),
			"effect_style": String(ranged.effect_style),
			"range_units": ranged.range_units,
			"projectile_count": ranged.projectile_count,
			"spread_angle": ranged.spread_angle,
			"pierce_count": ranged.pierce_count,
			"is_hitscan": ranged.is_hitscan,
			"projectile_visual_size": {"x": ranged.projectile_visual_size.x, "y": ranged.projectile_visual_size.y},
		},
		"explicit": {
			"effect_style": String(explicit.effect_style),
			"range_units": explicit.range_units,
			"projectile_count": explicit.projectile_count,
			"spread_angle": explicit.spread_angle,
			"pierce_count": explicit.pierce_count,
			"is_hitscan": explicit.is_hitscan,
			"projectile_visual_size": {"x": explicit.projectile_visual_size.x, "y": explicit.projectile_visual_size.y},
		},
	})


func _check_sand_xp_accumulator() -> void:
	_reset_with_gold()
	_game_state.call("add_sand_removed_xp", 3)
	var before_payout := int(_game_state.get("player_current_xp"))
	_game_state.call("add_sand_removed_xp", 1)
	var after_first_payout := int(_game_state.get("player_current_xp"))
	_game_state.call("add_sand_removed_xp", 4)
	var after_second_payout := int(_game_state.get("player_current_xp"))
	_record("sand_xp_accumulator", {
		"cells_per_xp": GameConstants.SAND_REMOVED_CELLS_PER_XP,
		"after_3_cells": before_payout,
		"after_4_cells": after_first_payout,
		"after_8_cells": after_second_payout,
	})
	_expect(before_payout == 0, "sand XP should wait until enough cells are removed")
	_expect(after_first_payout == 1, "sand XP should pay 1 XP after 4 removed cells")
	_expect(after_second_payout == 2, "sand XP should continue accumulating across mining actions")


func _check_existing_stat_bonus_purchase() -> void:
	_reset_with_gold()
	var before: int = _game_state.call("get_attack_damage")
	var result: Dictionary = _game_state.call("purchase_shop_item", &"small_gear")
	var after: int = _game_state.call("get_attack_damage")
	_record("stat_bonus_before", before)
	_record("stat_bonus_after", after)
	_record("stat_bonus_purchase", result)
	_expect(bool(result.get("ok", false)), "small_gear purchase should succeed")
	_expect(before == 10, "base attack should start at 10")
	_expect(after == 11, "small_gear should still apply +1 attack immediately")


func _check_melee_purity_core_condition() -> void:
	_reset_with_gold()
	var melee_before: int = _game_state.call("get_attack_damage")
	var melee_result: Dictionary = _game_state.call("purchase_shop_item", &"melee_purity_core")
	var melee_after: int = _game_state.call("get_attack_damage")
	_record("melee_core_satisfied_before", melee_before)
	_record("melee_core_satisfied_after", melee_after)
	_record("melee_core_purchase", melee_result)
	_expect(bool(melee_result.get("ok", false)), "melee_purity_core purchase should succeed")
	_expect(melee_before == 10, "melee-only baseline should be 10")
	_expect(melee_after == 12, "melee_purity_core should make 10 attack become 12 when all modules are melee")

	_reset_with_gold()
	var bow_result: Dictionary = _game_state.call("purchase_shop_item", &"bow_module")
	var mixed_before: int = _game_state.call("get_attack_damage")
	var mixed_result: Dictionary = _game_state.call("purchase_shop_item", &"melee_purity_core")
	var mixed_after: int = _game_state.call("get_attack_damage")
	_record("melee_core_unsatisfied_bow_purchase", bow_result)
	_record("melee_core_unsatisfied_before", mixed_before)
	_record("melee_core_unsatisfied_after", mixed_after)
	_record("melee_core_unsatisfied_purchase", mixed_result)
	_expect(bool(bow_result.get("ok", false)), "bow_module purchase should succeed")
	_expect(bool(mixed_result.get("ok", false)), "melee_purity_core mixed purchase should succeed")
	_expect(mixed_after == mixed_before, "melee_purity_core should not increase attack when any equipped module is non-melee")


func _check_module_focus_circuit_condition() -> void:
	_reset_with_gold()
	var one_module_before: int = _game_state.call("get_attack_damage")
	var one_module_result: Dictionary = _game_state.call("purchase_shop_item", &"module_focus_circuit")
	var one_module_after: int = _game_state.call("get_attack_damage")
	_record("focus_unsatisfied_before", one_module_before)
	_record("focus_unsatisfied_after", one_module_after)
	_record("focus_unsatisfied_purchase", one_module_result)
	_expect(bool(one_module_result.get("ok", false)), "module_focus_circuit one-module purchase should succeed")
	_expect(one_module_after == one_module_before, "module_focus_circuit should not increase attack with fewer than 3 modules")

	_reset_with_gold()
	_game_state.call("purchase_shop_item", &"dagger_module")
	_game_state.call("purchase_shop_item", &"lance_module")
	var three_module_before: int = _game_state.call("get_attack_damage")
	var three_module_result: Dictionary = _game_state.call("purchase_shop_item", &"module_focus_circuit")
	var three_module_after: int = _game_state.call("get_attack_damage")
	_record("focus_satisfied_before", three_module_before)
	_record("focus_satisfied_after", three_module_after)
	_record("focus_satisfied_purchase", three_module_result)
	_expect(bool(three_module_result.get("ok", false)), "module_focus_circuit three-module purchase should succeed")
	_expect(three_module_before == 10, "three-module baseline should remain 10 before focus circuit")
	_expect(three_module_after == 12, "module_focus_circuit should add +2 attack with 3 equipped modules")


func _check_attack_module_add_and_synthesis_smoke() -> void:
	_reset_with_gold()
	var add_result: Dictionary = _game_state.call("purchase_shop_item", &"dagger_module")
	_record("attack_module_add_result", add_result)
	_record("attack_module_count_after_add", _get_equipped_attack_module_entries().size())
	_expect(bool(add_result.get("ok", false)), "dagger_module add purchase should succeed")
	_expect(String(add_result.get("reason", "")) == "add", "dagger_module first purchase should add")

	_game_state.call("purchase_shop_item", &"lance_module")
	_game_state.call("purchase_shop_item", &"axe_module")
	_game_state.call("purchase_shop_item", &"greatsword_module")
	var synth_result: Dictionary = _game_state.call("purchase_shop_item", &"dagger_module")
	var dagger_grade := ""
	for entry in _get_equipped_attack_module_entries():
		if String(entry.get("module_id", "")) == "dagger_module":
			dagger_grade = String(entry.get("grade", ""))
			break
	_record("attack_module_synth_result", synth_result)
	_record("attack_module_count_after_synth", _get_equipped_attack_module_entries().size())
	_record("attack_module_dagger_grade_after_synth", dagger_grade)
	_expect(bool(synth_result.get("ok", false)), "dagger_module synth purchase should succeed when slots are full")
	_expect(String(synth_result.get("reason", "")) == "synthesize", "dagger_module duplicate should synthesize at full slots")
	_expect(_get_equipped_attack_module_entries().size() == 5, "synthesis should keep equipped module count capped")
	_expect(dagger_grade == "B", "C dagger duplicate should synthesize to B")


func _check_shop_item_price_deduction() -> void:
	# D rank fallback: small_gear = 15G
	_reset_with_gold(1000)
	var gold_before_d := int(_game_state.get("gold"))
	_game_state.call("purchase_shop_item", &"small_gear")
	var d_deducted := gold_before_d - int(_game_state.get("gold"))
	_record("price_deduction_d_rank", d_deducted)
	_expect(d_deducted == 15, "D rank fallback price should be 15G, got %d" % d_deducted)

	# C rank fallback: dagger_module = 30G
	_reset_with_gold(1000)
	var gold_before_c := int(_game_state.get("gold"))
	_game_state.call("purchase_shop_item", &"dagger_module")
	var c_deducted := gold_before_c - int(_game_state.get("gold"))
	_record("price_deduction_c_rank", c_deducted)
	_expect(c_deducted == 30, "C rank fallback price should be 30G, got %d" % c_deducted)

	# B rank fallback: lance_module = 60G
	_reset_with_gold(1000)
	var gold_before_b := int(_game_state.get("gold"))
	_game_state.call("purchase_shop_item", &"lance_module")
	var b_deducted := gold_before_b - int(_game_state.get("gold"))
	_record("price_deduction_b_rank", b_deducted)
	_expect(b_deducted == 60, "B rank fallback price should be 60G, got %d" % b_deducted)

	# A rank fallback: axe_module = 120G
	_reset_with_gold(1000)
	var gold_before_a := int(_game_state.get("gold"))
	_game_state.call("purchase_shop_item", &"axe_module")
	var a_deducted := gold_before_a - int(_game_state.get("gold"))
	_record("price_deduction_a_rank", a_deducted)
	_expect(a_deducted == 120, "A rank fallback price should be 120G, got %d" % a_deducted)

	# S rank fallback: greatsword_module = 240G
	_reset_with_gold(1000)
	var gold_before_s := int(_game_state.get("gold"))
	_game_state.call("purchase_shop_item", &"greatsword_module")
	var s_deducted := gold_before_s - int(_game_state.get("gold"))
	_record("price_deduction_s_rank", s_deducted)
	_expect(s_deducted == 240, "S rank fallback price should be 240G, got %d" % s_deducted)

	# Explicit price override: melee_purity_core has price_gold = 320 (A rank but costs more)
	_reset_with_gold(1000)
	var gold_before_exp := int(_game_state.get("gold"))
	_game_state.call("purchase_shop_item", &"melee_purity_core")
	var exp_deducted := gold_before_exp - int(_game_state.get("gold"))
	_record("price_deduction_explicit_price", exp_deducted)
	_expect(exp_deducted == 320, "melee_purity_core explicit price should be 320G, got %d" % exp_deducted)

	# Explicit price override: module_focus_circuit has price_gold = 240 (B rank but costs more)
	_reset_with_gold(1000)
	var gold_before_foc := int(_game_state.get("gold"))
	_game_state.call("purchase_shop_item", &"module_focus_circuit")
	var foc_deducted := gold_before_foc - int(_game_state.get("gold"))
	_record("price_deduction_focus_explicit_price", foc_deducted)
	_expect(foc_deducted == 240, "module_focus_circuit explicit price should be 240G, got %d" % foc_deducted)

	# Display price equals purchase price: snapshot price_gold matches what was actually deducted
	_reset_with_gold(1000)
	var snapshot: Dictionary = _game_state.call("get_day_shop_snapshot", PackedStringArray(["axe_module"]))
	var entries: Array = snapshot.get("item_entries", [])
	var display_price := 0
	if not entries.is_empty():
		display_price = int((entries[0] as Dictionary).get("price_gold", 0))
	_record("price_display_equals_deduction_a_rank", display_price)
	_expect(display_price == 120, "A rank display price in snapshot should be 120G, got %d" % display_price)


func _check_shop_reroll_cost_progression() -> void:
	_reset_with_gold(1000)
	_record("shop_reroll_initial_cost", _game_state.call("get_current_shop_reroll_cost"))
	_expect(int(_game_state.call("get_current_shop_reroll_cost")) == 50, "reroll count 0 should cost 50G")

	var first_result: Dictionary = _game_state.call("try_purchase_shop_reroll")
	_record("shop_reroll_first_result", first_result)
	_record("shop_reroll_cost_after_one", _game_state.call("get_current_shop_reroll_cost"))
	_expect(bool(first_result.get("ok", false)), "first reroll purchase should succeed")
	_expect(int(first_result.get("cost", 0)) == 50, "first reroll should spend 50G")
	_expect(int(_game_state.get("current_shop_reroll_count")) == 1, "reroll count should be 1 after one reroll")
	_expect(int(_game_state.call("get_current_shop_reroll_cost")) == 75, "next reroll after one should cost 75G")

	var second_result: Dictionary = _game_state.call("try_purchase_shop_reroll")
	_record("shop_reroll_second_result", second_result)
	_record("shop_reroll_cost_after_two", _game_state.call("get_current_shop_reroll_cost"))
	_expect(bool(second_result.get("ok", false)), "second reroll purchase should succeed")
	_expect(int(second_result.get("cost", 0)) == 75, "second reroll should spend 75G")
	_expect(int(_game_state.get("current_shop_reroll_count")) == 2, "reroll count should be 2 after two rerolls")
	_expect(int(_game_state.call("get_current_shop_reroll_cost")) == 100, "next reroll after two should cost 100G")


func _check_shop_reroll_gold_failure_and_reset() -> void:
	_reset_with_gold(49)
	var gold_before := int(_game_state.get("gold"))
	var fail_result: Dictionary = _game_state.call("try_purchase_shop_reroll")
	_record("shop_reroll_insufficient_gold_result", fail_result)
	_expect(not bool(fail_result.get("ok", false)), "reroll should fail with 49G")
	_expect(String(fail_result.get("reason", "")) == "insufficient_gold", "reroll failure reason should be insufficient_gold")
	_expect(int(_game_state.get("gold")) == gold_before, "failed reroll should not spend gold")
	_expect(int(_game_state.get("current_shop_reroll_count")) == 0, "failed reroll should not increase reroll count")

	_reset_with_gold(1000)
	var success_result: Dictionary = _game_state.call("try_purchase_shop_reroll")
	_record("shop_reroll_gold_after_success", int(_game_state.get("gold")))
	_expect(bool(success_result.get("ok", false)), "reroll should succeed with enough gold")
	_expect(int(_game_state.get("gold")) == 950, "successful first reroll should deduct 50G")
	_game_state.call("reset_shop_reroll_count")
	_record("shop_reroll_cost_after_reset", _game_state.call("get_current_shop_reroll_cost"))
	_expect(int(_game_state.get("current_shop_reroll_count")) == 0, "new shop generation should reset reroll count to 0")
	_expect(int(_game_state.call("get_current_shop_reroll_cost")) == 50, "reroll cost after reset should return to 50G")


func _check_shop_reroll_roll_count_and_prices() -> void:
	_reset_with_gold(1000)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var reroll_result: Dictionary = _game_state.call("try_purchase_shop_reroll")
	var rerolled_ids: PackedStringArray = _game_data.call(
		"roll_shop_item_ids",
		rng,
		GameConstants.DAY_SHOP_ITEM_COUNT,
		_game_state.call("get_shop_roll_context")
	)
	var snapshot: Dictionary = _game_state.call("get_day_shop_snapshot", rerolled_ids)
	var entries: Array = snapshot.get("item_entries", [])
	var price_mismatches: Array[String] = []
	for raw_entry in entries:
		var entry: Dictionary = raw_entry
		var item_id := StringName(String(entry.get("item_id", "")))
		var definition: Dictionary = _game_data.call("get_shop_item_definition", item_id)
		var expected_price := int(_game_state.call("get_effective_shop_item_price", definition))
		if int(entry.get("price_gold", 0)) != expected_price:
			price_mismatches.append(String(item_id))
	_record("shop_reroll_generated_item_count", rerolled_ids.size())
	_record("shop_reroll_snapshot_price_mismatches", price_mismatches)
	_expect(bool(reroll_result.get("ok", false)), "reroll purchase should succeed before rolling new items")
	_expect(rerolled_ids.size() == GameConstants.DAY_SHOP_ITEM_COUNT, "reroll should generate DAY_SHOP_ITEM_COUNT items")
	_expect(price_mismatches.is_empty(), "reroll snapshot prices should match get_effective_shop_item_price")


func _get_equipped_attack_module_entries() -> Array:
	return _game_state.call("get_equipped_attack_module_entries")


func _record(key: String, value: Variant) -> void:
	_results[key] = value


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _is_vector_near(actual: Vector2, expected: Vector2) -> bool:
	return is_equal_approx(actual.x, expected.x) and is_equal_approx(actual.y, expected.y)
