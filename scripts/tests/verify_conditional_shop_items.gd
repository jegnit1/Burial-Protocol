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
	_check_existing_stat_bonus_purchase()
	_check_melee_purity_core_condition()
	_check_module_focus_circuit_condition()
	_check_attack_module_add_and_synthesis_smoke()


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


func _get_equipped_attack_module_entries() -> Array:
	return _game_state.call("get_equipped_attack_module_entries")


func _record(key: String, value: Variant) -> void:
	_results[key] = value


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _is_vector_near(actual: Vector2, expected: Vector2) -> bool:
	return is_equal_approx(actual.x, expected.x) and is_equal_approx(actual.y, expected.y)
