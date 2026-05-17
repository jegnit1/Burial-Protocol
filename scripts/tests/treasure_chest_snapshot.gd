extends SceneTree

const WALL_TREASURE_MANAGER_SCRIPT := preload("res://scripts/data/WallTreasureManager.gd")
const TREASURE_REWARD_POPUP_SCENE := preload("res://scenes/ui/TreasureRewardPopup.tscn")
const EXPECTED_MARKER_COUNT := 6
const SNAPSHOT_SEED := 5102026
const INTERACTION_RANGE := 128.0

var _ran := false


func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true

	var rng := RandomNumberGenerator.new()
	rng.seed = SNAPSHOT_SEED
	var manager = WALL_TREASURE_MANAGER_SCRIPT.new()
	manager.setup()
	manager.generate_markers_for_wall_reset(rng, EXPECTED_MARKER_COUNT)

	var marker_validation: Dictionary = manager.validate_markers()
	var rarity_validation: Dictionary = manager.validate_rarity_roll_table()
	var preview_validation := _validate_preview_visuals(manager)
	var reveal_validation := _validate_reveal_flow(manager)
	var reward_validation := _validate_reward_flow(manager)
	var popup_validation := _validate_popup_scene(reveal_validation.get("final_marker", {}), reward_validation.get("reward_snapshot", {}))
	var snapshot := {
		"ok": (
			bool(marker_validation["ok"])
			and bool(rarity_validation["ok"])
			and bool(preview_validation["ok"])
			and bool(reveal_validation["ok"])
			and bool(reward_validation["ok"])
			and bool(popup_validation["ok"])
			and manager.markers.size() == EXPECTED_MARKER_COUNT
		),
		"seed": SNAPSHOT_SEED,
		"expected_marker_count": EXPECTED_MARKER_COUNT,
		"actual_marker_count": manager.markers.size(),
		"marker_validation": marker_validation,
		"rarity_validation": rarity_validation,
		"preview_validation": preview_validation,
		"reveal_validation": reveal_validation,
		"reward_validation": reward_validation,
		"popup_validation": popup_validation,
		"rarity_roll_table": manager.get_rarity_roll_table(),
		"reward_rank_roll_tables": manager.get_reward_rank_roll_tables(),
		"markers": manager.get_marker_snapshots(),
		"visual_debug_snapshot": manager.get_visual_debug_snapshot(),
		"side_counts": _get_side_counts(manager.markers),
		"rarity_counts": _get_rarity_counts(manager.markers),
	}
	print(JSON.stringify(snapshot, "\t"))
	manager.free()
	quit(0 if bool(snapshot["ok"]) else 1)
	return true


func _validate_preview_visuals(manager) -> Dictionary:
	var visual_snapshot: Dictionary = manager.get_visual_debug_snapshot()
	var previews: Array = visual_snapshot.get("previews", [])
	var palette: Dictionary = visual_snapshot.get("rarity_preview_palette", {})
	var distinct_color_keys := {}
	for rarity in ["bronze", "silver", "gold", "platinum"]:
		var color: Dictionary = palette.get(rarity, {})
		distinct_color_keys["%.3f,%.3f,%.3f,%.3f" % [
			float(color.get("r", -1.0)),
			float(color.get("g", -1.0)),
			float(color.get("b", -1.0)),
			float(color.get("a", -1.0)),
		]] = true
	var all_previews_visible := true
	for preview in previews:
		if not bool((preview as Dictionary).get("visible_before_mining", false)):
			all_previews_visible = false
	var checks := {
		"preview_count_matches_markers": previews.size() == manager.markers.size(),
		"all_previews_visible_before_mining": all_previews_visible,
		"rarity_palette_has_four_entries": palette.size() == 4,
		"rarity_palette_colors_are_distinct": distinct_color_keys.size() == 4,
		"debug_outline_enabled": bool(visual_snapshot.get("debug_draw_marker_outlines", false)),
		"no_revealed_quadrants_before_mining": int(visual_snapshot.get("revealed_quadrant_count", -1)) == 0,
	}
	var ok := true
	for value in checks.values():
		if not bool(value):
			ok = false
	return {
		"ok": ok,
		"checks": checks,
		"visual_snapshot": visual_snapshot,
	}


func _validate_reveal_flow(manager) -> Dictionary:
	if manager.markers.is_empty():
		return {"ok": false, "error": "no markers generated"}
	var marker = manager.markers[0]
	var origin_x := int(marker.origin_subcell_x)
	var origin_y := int(marker.origin_subcell_y)
	var interaction_available_before_reveal := bool(marker.is_interaction_available())
	var nearest_before_reveal = manager.get_nearest_interactable_marker(manager.get_marker_world_center(marker), INTERACTION_RANGE)
	manager.update_interaction_prompt(manager.get_marker_world_center(marker), INTERACTION_RANGE)
	var prompt_before_reveal: Dictionary = manager.get_interaction_debug_snapshot()
	var step_1: Dictionary = manager.handle_mined_wall_subcells([_make_removed_subcell(origin_x, origin_y)])
	var visual_after_step_1: Dictionary = manager.get_visual_debug_snapshot()
	var interaction_available_after_partial := bool(marker.is_interaction_available())
	var nearest_after_partial = manager.get_nearest_interactable_marker(manager.get_marker_world_center(marker), INTERACTION_RANGE)
	var duplicate_step: Dictionary = manager.handle_mined_wall_subcells([_make_removed_subcell(origin_x, origin_y)])
	var step_3: Dictionary = manager.handle_mined_wall_subcells([
		_make_removed_subcell(origin_x + 1, origin_y),
		_make_removed_subcell(origin_x, origin_y + 1),
	])
	var step_4: Dictionary = manager.handle_mined_wall_subcells([_make_removed_subcell(origin_x + 1, origin_y + 1)])
	var visual_after_step_4: Dictionary = manager.get_visual_debug_snapshot()
	var nearest_after_full_outside = manager.get_nearest_interactable_marker(Vector2(-10000.0, -10000.0), INTERACTION_RANGE)
	var nearest_after_full_inside = manager.get_nearest_interactable_marker(manager.get_marker_world_center(marker), INTERACTION_RANGE)
	manager.update_interaction_prompt(Vector2(-10000.0, -10000.0), INTERACTION_RANGE)
	var prompt_after_full_outside: Dictionary = manager.get_interaction_debug_snapshot()
	manager.update_interaction_prompt(manager.get_marker_world_center(marker), INTERACTION_RANGE)
	var prompt_after_full_inside: Dictionary = manager.get_interaction_debug_snapshot()
	var unrelated_step: Dictionary = manager.handle_mined_wall_subcells([_make_removed_subcell(-1, -1)])
	var checks := {
		"step_1_revealed": marker.get_revealed_count() >= 1,
		"step_1_new_count": int(step_1["newly_revealed_count"]) == 1,
		"step_1_visual_has_one_revealed_quadrant": int(visual_after_step_1.get("revealed_quadrant_count", -1)) == 1,
		"duplicate_ignored": int(duplicate_step["newly_revealed_count"]) == 0,
		"step_3_new_count": int(step_3["newly_revealed_count"]) == 2,
		"step_4_new_count": int(step_4["newly_revealed_count"]) == 1,
		"step_4_visual_has_four_revealed_quadrants": int(visual_after_step_4.get("revealed_quadrant_count", -1)) == 4,
		"unrelated_ignored": int(unrelated_step["newly_revealed_count"]) == 0,
		"revealed_count_4": marker.get_revealed_count() == 4,
		"fully_revealed": bool(marker.is_fully_revealed),
		"interaction_unavailable_before_reveal": not interaction_available_before_reveal,
		"interaction_unavailable_after_partial": not interaction_available_after_partial,
		"interaction_available_after_full_reveal": bool(marker.is_interaction_available()),
		"nearest_unavailable_before_reveal": nearest_before_reveal == null,
		"nearest_unavailable_after_partial": nearest_after_partial == null,
		"nearest_unavailable_outside_range": nearest_after_full_outside == null,
		"nearest_available_inside_range": nearest_after_full_inside != null,
		"prompt_hidden_before_reveal": not bool(prompt_before_reveal.get("prompt_visible", true)),
		"prompt_hidden_outside_range": not bool(prompt_after_full_outside.get("prompt_visible", true)),
		"prompt_visible_inside_range": bool(prompt_after_full_inside.get("prompt_visible", false)),
		"prompt_targets_marker": String(prompt_after_full_inside.get("prompt_marker_id", "")) == marker.marker_id,
		"fully_revealed_id_reported": Array(step_4["newly_fully_revealed_marker_ids"]).has(marker.marker_id),
	}
	var ok := true
	for value in checks.values():
		if not bool(value):
			ok = false
	return {
		"ok": ok,
		"marker_id": marker.marker_id,
		"checks": checks,
		"step_1": step_1,
		"visual_after_step_1": visual_after_step_1,
		"duplicate_step": duplicate_step,
		"step_3": step_3,
		"step_4": step_4,
		"visual_after_step_4": visual_after_step_4,
		"prompt_before_reveal": prompt_before_reveal,
		"prompt_after_full_outside": prompt_after_full_outside,
		"prompt_after_full_inside": prompt_after_full_inside,
		"unrelated_step": unrelated_step,
		"final_marker": marker.to_snapshot(),
	}


func _make_removed_subcell(subcell_x: int, subcell_y: int) -> Dictionary:
	return {
		"subcell_x": subcell_x,
		"subcell_y": subcell_y,
	}


func _validate_reward_flow(manager) -> Dictionary:
	if manager.markers.is_empty():
		return {"ok": false, "error": "no markers generated"}
	var marker = manager.markers[0]
	var rank_table_validation: Dictionary = manager.validate_reward_rank_roll_tables()
	var reward_snapshot: Dictionary = manager.prepare_reward_for_marker(marker)
	var cached_reward_snapshot: Dictionary = manager.prepare_reward_for_marker(marker)
	var game_data = get_root().get_node("/root/GameData")
	var game_state = get_root().get_node("/root/GameState")
	var definition: Dictionary = game_data.call("get_shop_item_definition", StringName(reward_snapshot.get("item_id", "")))
	var buy_price := int(game_state.call("get_effective_shop_item_price", definition)) if not definition.is_empty() else 0
	var expected_sell_price := int(floor(float(buy_price) * 0.6))
	game_state.call("reset_run")
	var gold_before_grant := int(game_state.get("gold"))
	var grant_result: Dictionary = game_state.call("grant_shop_item_reward", StringName(reward_snapshot.get("item_id", "")), "treasure_chest_snapshot")
	var gold_after_grant := int(game_state.get("gold"))
	game_state.call("reset_run")
	var gold_before_sell := int(game_state.get("gold"))
	game_state.call("add_gold", int(reward_snapshot.get("sell_price", 0)))
	var gold_after_sell := int(game_state.get("gold"))
	var consumed := bool(manager.consume_marker(marker.marker_id))
	var nearest_after_consume = manager.get_nearest_interactable_marker(manager.get_marker_world_center(marker), INTERACTION_RANGE)
	manager.update_interaction_prompt(manager.get_marker_world_center(marker), INTERACTION_RANGE)
	var prompt_after_consume: Dictionary = manager.get_interaction_debug_snapshot()
	var visual_after_consume: Dictionary = manager.get_visual_debug_snapshot()
	var checks := {
		"reward_rank_tables_valid": bool(rank_table_validation.get("ok", false)),
		"reward_roll_ok": bool(reward_snapshot.get("ok", false)),
		"reward_cached_same_item": String(reward_snapshot.get("item_id", "")) == String(cached_reward_snapshot.get("item_id", "")),
		"reward_definition_exists": not definition.is_empty(),
		"sell_price_matches_floor_60_percent": int(reward_snapshot.get("sell_price", -1)) == expected_sell_price,
		"grant_helper_ok": bool(grant_result.get("ok", false)),
		"grant_helper_spent_no_gold": gold_before_grant == gold_after_grant,
		"sell_adds_gold_without_item_grant_path": gold_after_sell - gold_before_sell == int(reward_snapshot.get("sell_price", 0)),
		"consume_marker_ok": consumed,
		"consumed_interaction_unavailable": not bool(marker.is_interaction_available()),
		"consumed_nearest_unavailable": nearest_after_consume == null,
		"consumed_prompt_hidden": not bool(prompt_after_consume.get("prompt_visible", true)),
		"consumed_visual_removed": int(visual_after_consume.get("preview_count", -1)) == manager.markers.size() - 1,
	}
	var ok := true
	for value in checks.values():
		if not bool(value):
			ok = false
	return {
		"ok": ok,
		"checks": checks,
		"rank_table_validation": rank_table_validation,
		"reward_snapshot": reward_snapshot,
		"cached_reward_snapshot": cached_reward_snapshot,
		"grant_result": grant_result,
		"prompt_after_consume": prompt_after_consume,
		"visual_after_consume": visual_after_consume,
	}


func _validate_popup_scene(marker_snapshot: Dictionary, reward_snapshot: Dictionary) -> Dictionary:
	var popup = TREASURE_REWARD_POPUP_SCENE.instantiate()
	get_root().add_child(popup)
	if popup.has_method("setup"):
		popup.call("setup", marker_snapshot, reward_snapshot)
	var popup_debug: Dictionary = {}
	if popup.has_method("get_debug_snapshot"):
		popup_debug = popup.call("get_debug_snapshot")
	var checks := {
		"instantiated": popup != null,
		"has_closed_signal": popup.has_signal("closed"),
		"has_claim_signal": popup.has_signal("claim_requested"),
		"has_sell_signal": popup.has_signal("sell_requested"),
		"processes_when_paused": popup.process_mode == Node.PROCESS_MODE_WHEN_PAUSED,
		"claim_button_enabled": bool(popup_debug.get("claim_enabled", false)),
		"sell_button_enabled": bool(popup_debug.get("sell_enabled", false)),
	}
	var ok := true
	for value in checks.values():
		if not bool(value):
			ok = false
	popup.queue_free()
	return {
		"ok": ok,
		"checks": checks,
		"popup_debug": popup_debug,
	}


func _get_side_counts(markers: Array) -> Dictionary:
	var counts := {}
	for marker in markers:
		counts[marker.wall_side] = int(counts.get(marker.wall_side, 0)) + 1
	return counts


func _get_rarity_counts(markers: Array) -> Dictionary:
	var counts := {}
	for marker in markers:
		counts[marker.chest_rarity] = int(counts.get(marker.chest_rarity, 0)) + 1
	return counts
