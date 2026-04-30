extends SceneTree

const GC = preload("res://scripts/autoload/GameConstants.gd")
const SIMULATOR_PATH := "res://scripts/data/BlockSpawnV2Simulator.gd"
const REPORT_PATH := "res://docs/reports/day_pressure_snapshot.md"
const ITERATIONS := 10000
const TEST_DIFFICULTIES := ["normal", "hard"]
const KEY_DAYS := [1, 5, 10, 15, 20, 25, 30]
const TOP_LIMIT := 8
const RECENT_WINDOW_SIZE := 10
const RNG_SEED_BASE := 829451

var _game_data = null
var _game_state = null
var _simulator = null
var _ran := false


func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	_game_data = get_root().get_node_or_null("GameData")
	_game_state = get_root().get_node_or_null("GameState")
	if _game_data == null or _game_state == null:
		print(JSON.stringify({"ok": false, "error": "GameData/GameState autoloads not available"}, "\t"))
		quit(1)
		return true

	var simulator_script = load(SIMULATOR_PATH)
	_simulator = simulator_script.new()
	var load_result = _simulator.load_rules_from_directory("res://data_tsv")
	if not bool(load_result.get("ok", false)):
		print(JSON.stringify({"ok": false, "errors": load_result.get("errors", [])}, "\t"))
		quit(1)
		return true

	var snapshot := _build_snapshot()
	var write_result := _write_report(snapshot)
	if not bool(write_result.get("ok", false)):
		snapshot["ok"] = false
		snapshot["report_error"] = str(write_result.get("error", "failed to write report"))
		print(JSON.stringify(snapshot, "\t"))
		quit(1)
		return true

	snapshot["report_path"] = REPORT_PATH
	print(JSON.stringify(_build_console_summary(snapshot), "\t"))
	quit(0)
	return true


func _build_snapshot() -> Dictionary:
	var catalog = _game_data.call("get_block_catalog")
	var total_days := int(_game_data.call("get_total_days"))
	var days: Array[int] = []
	for day in range(1, total_days + 1):
		days.append(day)

	var stage_rows: Array[Dictionary] = []
	for day in days:
		stage_rows.append(_build_stage_day_row(day))

	var v1_conditions: Array[Dictionary] = []
	var v1_by_key := {}
	for difficulty_id in TEST_DIFFICULTIES:
		for day in days:
			var summary := _simulate_v1(catalog, day, StringName(difficulty_id), _seed_for(difficulty_id, day, 1))
			var pressure := _build_pressure_estimate(day, StringName(difficulty_id), summary)
			var gating := _build_gating_snapshot(catalog, day, StringName(difficulty_id))
			var condition := {
				"difficulty": difficulty_id,
				"day": day,
				"summary": summary,
				"pressure": pressure,
				"gating": gating,
			}
			v1_conditions.append(condition)
			v1_by_key["%s:%d" % [difficulty_id, day]] = condition

	var v2_comparisons: Array[Dictionary] = []
	for difficulty_id in TEST_DIFFICULTIES:
		for day in KEY_DAYS:
			var v1_condition: Dictionary = v1_by_key.get("%s:%d" % [difficulty_id, day], {})
			var v2_summary := _simulate_v2(catalog, day, StringName(difficulty_id), _seed_for(difficulty_id, day, 2))
			v2_comparisons.append({
				"difficulty": difficulty_id,
				"day": day,
				"v1": v1_condition.get("summary", {}),
				"v2": v2_summary,
				"comparison": _compare_summaries(v1_condition.get("summary", {}), v2_summary),
			})

	return {
		"ok": true,
		"iterations": ITERATIONS,
		"rng_seed_base": RNG_SEED_BASE,
		"stage_rows": stage_rows,
		"v1_conditions": v1_conditions,
		"v2_comparisons": v2_comparisons,
		"attack_baseline": _build_attack_baseline(),
		"sand_limit": {
			"weight_limit_sand_cells": GC.WEIGHT_LIMIT_SAND_CELLS,
			"display_weight_per_sand_cell": GC.DISPLAY_WEIGHT_PER_SAND_CELL,
			"display_weight_limit": _round_to(_sand_cells_to_display_weight(GC.WEIGHT_LIMIT_SAND_CELLS), 1),
			"display_unit": GC.DISPLAY_WEIGHT_UNIT,
		},
		"diagnosis": _build_pressure_curve_diagnosis(v1_conditions),
		"risks": _build_risk_rows(v1_conditions, v2_comparisons),
		"notes": [
			"v1 pressure uses current live BlockCatalog.get_spawn_candidates() plus BlockSpawnResolver-compatible resolved values.",
			"v1 candidate weights are sampled with Monte Carlo, but live resolver code and data are not modified.",
			"v2 is simulation-only and is included only as a reference comparison.",
			"Expected spawn count uses the active Timer pattern in Main.gd: floor(day_duration / (BLOCK_SPAWN_INTERVAL * spawn_interval_multiplier)).",
		],
	}


func _build_stage_day_row(day: int) -> Dictionary:
	var definition = _game_data.call("get_day_definition", day)
	var day_type := String(_game_data.call("get_day_type", day))
	var duration := float(_game_data.call("get_day_duration", day))
	var spawn_multiplier := float(_game_data.call("get_spawn_interval_multiplier", day))
	var effective_interval := _get_effective_spawn_interval(day)
	var expected_spawn_count := _get_expected_spawn_count(day)
	var boss_material := ""
	var boss_size := ""
	var boss_type := ""
	var special_rules := ""
	if definition != null:
		boss_material = String(definition.boss_block_base_id)
		boss_size = String(definition.boss_block_size_id)
		boss_type = String(definition.boss_block_type_id)
		special_rules = _join_strings(Array(definition.special_rules), "|")
	return {
		"day": day,
		"day_type": day_type,
		"duration": _round_to(duration, 2),
		"block_hp_multiplier": _round_to(float(_game_data.call("get_block_hp_multiplier", day)), 3),
		"spawn_interval_multiplier": _round_to(spawn_multiplier, 3),
		"effective_spawn_interval": _round_to(effective_interval, 3),
		"spawns_per_min": _round_to(60.0 / effective_interval, 2) if effective_interval > 0.0 else 0.0,
		"expected_spawn_count": expected_spawn_count,
		"is_rush": day_type == "rush",
		"is_boss": bool(_game_data.call("is_boss_day", day)),
		"boss_material_id": boss_material,
		"boss_size_id": boss_size,
		"boss_type_id": boss_type,
		"special_rules": special_rules,
	}


func _simulate_v1(catalog, day: int, difficulty_id: StringName, seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var weighted_candidates := _build_v1_weighted_candidates(catalog, day, difficulty_id)
	var summary := _make_empty_summary()
	summary["candidate_count"] = weighted_candidates.size()
	if weighted_candidates.is_empty():
		return _finalize_summary(summary)

	var total_weight := 0.0
	for candidate in weighted_candidates:
		total_weight += float(candidate.get("weight", 0.0))
	for _index in range(ITERATIONS):
		var candidate := _roll_weighted_candidate(weighted_candidates, total_weight, rng)
		if candidate.is_empty():
			continue
		var resolved = candidate.get("resolved")
		var type_definition = _game_data.call("pick_block_type_definition_or_none", rng)
		if type_definition != null:
			resolved = _game_data.call(
				"resolve_specific_block_definition",
				resolved.material_id,
				resolved.size_id,
				difficulty_id,
				day,
				type_definition
			)
		if resolved != null:
			_record_resolved_spawn(summary, resolved)
	return _finalize_summary(summary)


func _build_v1_weighted_candidates(catalog, day: int, difficulty_id: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for raw_candidate in catalog.get_spawn_candidates(difficulty_id, day):
		var candidate: Dictionary = raw_candidate
		var material = candidate.get("material")
		var size = candidate.get("size")
		if material == null or size == null:
			continue
		var weight := float(candidate.get("weight", 0.0))
		if weight <= 0.0:
			continue
		var resolved = _game_data.call(
			"resolve_specific_block_definition",
			material.material_id,
			size.size_id,
			difficulty_id,
			day,
			null
		)
		if resolved == null:
			continue
		result.append({
			"resolved": resolved,
			"weight": weight,
		})
	return result


func _simulate_v2(catalog, day: int, difficulty_id: StringName, seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var summary := _make_empty_summary()
	for _index in range(ITERATIONS):
		var resolved = _simulator.resolve_random_block_v2_simulation(catalog, _game_data.call("get_stage_table"), day, difficulty_id, rng)
		if resolved != null:
			_record_resolved_spawn(summary, resolved)
	return _finalize_summary(summary)


func _make_empty_summary() -> Dictionary:
	return {
		"iterations": ITERATIONS,
		"candidate_count": 0,
		"resolved_count": 0,
		"material_counts": {},
		"size_counts": {},
		"pair_counts": {},
		"type_counts": {},
		"width_group_counts": {},
		"area_group_counts": {},
		"size_group_counts": {},
		"horizontal_pressure_sum": 0.0,
		"horizontal_pressure_max": 0.0,
		"vertical_pressure_sum": 0.0,
		"vertical_pressure_max": 0.0,
		"hp_sum": 0.0,
		"hp_max": 0.0,
		"reward_sum": 0.0,
		"reward_max": 0.0,
		"sand_sum": 0.0,
		"sand_max": 0.0,
		"area_sum": 0.0,
		"recent_wide_window": [],
		"recent_wide_ratio_max": 0.0,
		"width_pressure_window": [],
		"width_pressure_window_max": 0.0,
		"area_pressure_window": [],
		"area_pressure_window_max": 0.0,
	}


func _record_resolved_spawn(summary: Dictionary, resolved) -> void:
	var material_id := str(resolved.material_id)
	var size_id := str(resolved.size_id)
	var type_id := "none" if resolved.type_id == StringName() else str(resolved.type_id)
	var taxonomy: Dictionary = _simulator.get_size_taxonomy(resolved.size_definition)
	var size_group := str(taxonomy.get("size_group", ""))
	var width_group := str(taxonomy.get("width_group", ""))
	var area_group := str(taxonomy.get("area_group", ""))
	var horizontal_pressure := float(taxonomy.get("horizontal_pressure_score", 0.0))
	var vertical_pressure := float(taxonomy.get("vertical_pressure_score", 0.0))
	var area := int(taxonomy.get("area", 1))
	var pair_id := "%s+%s" % [material_id, size_id]

	summary["resolved_count"] = int(summary["resolved_count"]) + 1
	_increment_counter(summary["material_counts"], material_id)
	_increment_counter(summary["size_counts"], size_id)
	_increment_counter(summary["pair_counts"], pair_id)
	_increment_counter(summary["type_counts"], type_id)
	_increment_counter(summary["width_group_counts"], width_group)
	_increment_counter(summary["area_group_counts"], area_group)
	_increment_counter(summary["size_group_counts"], size_group)

	summary["horizontal_pressure_sum"] = float(summary["horizontal_pressure_sum"]) + horizontal_pressure
	summary["horizontal_pressure_max"] = maxf(float(summary["horizontal_pressure_max"]), horizontal_pressure)
	summary["vertical_pressure_sum"] = float(summary["vertical_pressure_sum"]) + vertical_pressure
	summary["vertical_pressure_max"] = maxf(float(summary["vertical_pressure_max"]), vertical_pressure)
	summary["hp_sum"] = float(summary["hp_sum"]) + float(resolved.final_hp)
	summary["hp_max"] = maxf(float(summary["hp_max"]), float(resolved.final_hp))
	summary["reward_sum"] = float(summary["reward_sum"]) + float(resolved.final_reward)
	summary["reward_max"] = maxf(float(summary["reward_max"]), float(resolved.final_reward))
	summary["sand_sum"] = float(summary["sand_sum"]) + float(resolved.final_sand_units)
	summary["sand_max"] = maxf(float(summary["sand_max"]), float(resolved.final_sand_units))
	summary["area_sum"] = float(summary["area_sum"]) + float(area)

	_record_pressure_windows(summary, size_group, horizontal_pressure, area)


func _record_pressure_windows(summary: Dictionary, size_group: String, horizontal_pressure: float, area: int) -> void:
	var wide_or_larger := _is_wide_or_larger(size_group)
	var recent_wide_window: Array = summary["recent_wide_window"]
	recent_wide_window.append(1 if wide_or_larger else 0)
	while recent_wide_window.size() > RECENT_WINDOW_SIZE:
		recent_wide_window.remove_at(0)
	summary["recent_wide_ratio_max"] = maxf(float(summary["recent_wide_ratio_max"]), _sum_array(recent_wide_window) / float(recent_wide_window.size()))

	var width_pressure_window: Array = summary["width_pressure_window"]
	width_pressure_window.append(horizontal_pressure)
	while width_pressure_window.size() > RECENT_WINDOW_SIZE:
		width_pressure_window.remove_at(0)
	summary["width_pressure_window_max"] = maxf(float(summary["width_pressure_window_max"]), _sum_array(width_pressure_window))

	var area_pressure_window: Array = summary["area_pressure_window"]
	area_pressure_window.append(float(area))
	while area_pressure_window.size() > RECENT_WINDOW_SIZE:
		area_pressure_window.remove_at(0)
	summary["area_pressure_window_max"] = maxf(float(summary["area_pressure_window_max"]), _sum_array(area_pressure_window))


func _finalize_summary(summary: Dictionary) -> Dictionary:
	var resolved_count := maxi(int(summary["resolved_count"]), 1)
	return {
		"iterations": int(summary["iterations"]),
		"candidate_count": int(summary["candidate_count"]),
		"resolved_count": int(summary["resolved_count"]),
		"material_counts": summary["material_counts"],
		"size_counts": summary["size_counts"],
		"pair_counts": summary["pair_counts"],
		"type_counts": summary["type_counts"],
		"width_group_counts": summary["width_group_counts"],
		"area_group_counts": summary["area_group_counts"],
		"size_group_counts": summary["size_group_counts"],
		"horizontal_pressure_avg": _round_to(float(summary["horizontal_pressure_sum"]) / float(resolved_count), 3),
		"horizontal_pressure_max": _round_to(float(summary["horizontal_pressure_max"]), 3),
		"vertical_pressure_avg": _round_to(float(summary["vertical_pressure_sum"]) / float(resolved_count), 3),
		"vertical_pressure_max": _round_to(float(summary["vertical_pressure_max"]), 3),
		"area_avg": _round_to(float(summary["area_sum"]) / float(resolved_count), 3),
		"hp_avg": _round_to(float(summary["hp_sum"]) / float(resolved_count), 2),
		"hp_max": int(summary["hp_max"]),
		"reward_avg": _round_to(float(summary["reward_sum"]) / float(resolved_count), 2),
		"reward_max": int(summary["reward_max"]),
		"sand_avg": _round_to(float(summary["sand_sum"]) / float(resolved_count), 2),
		"sand_max": int(summary["sand_max"]),
		"recent_wide_ratio_max": _round_to(float(summary["recent_wide_ratio_max"]), 3),
		"width_pressure_window_max": _round_to(float(summary["width_pressure_window_max"]), 3),
		"area_pressure_window_max": _round_to(float(summary["area_pressure_window_max"]), 3),
	}


func _build_pressure_estimate(day: int, difficulty_id: StringName, summary: Dictionary) -> Dictionary:
	var duration := float(_game_data.call("get_day_duration", day))
	var expected_spawn_count := _get_expected_spawn_count(day)
	var minutes := duration / 60.0
	var boss_hp := 0
	var boss_reward := 0
	var boss_sand := 0
	var boss_resolved = _resolve_boss_block(day, difficulty_id)
	if boss_resolved != null:
		boss_hp = int(boss_resolved.final_hp)
		boss_reward = int(boss_resolved.final_reward)
		boss_sand = int(boss_resolved.final_sand_units)
	var regular_hp := float(expected_spawn_count) * float(summary.get("hp_avg", 0.0))
	var regular_reward := float(expected_spawn_count) * float(summary.get("reward_avg", 0.0))
	var regular_sand := float(expected_spawn_count) * float(summary.get("sand_avg", 0.0))
	var total_hp := regular_hp + float(boss_hp)
	var total_reward := regular_reward + float(boss_reward)
	var total_sand := regular_sand + float(boss_sand)
	var total_horizontal := float(expected_spawn_count) * float(summary.get("horizontal_pressure_avg", 0.0))
	var total_vertical := float(expected_spawn_count) * float(summary.get("vertical_pressure_avg", 0.0))
	var safe_minutes := maxf(minutes, 0.001)
	return {
		"effective_spawn_interval": _round_to(_get_effective_spawn_interval(day), 3),
		"expected_spawn_count": expected_spawn_count,
		"boss_hp": boss_hp,
		"boss_reward": boss_reward,
		"boss_sand": boss_sand,
		"regular_total_hp": _round_to(regular_hp, 2),
		"regular_total_reward": _round_to(regular_reward, 2),
		"regular_total_sand": _round_to(regular_sand, 2),
		"expected_total_hp": _round_to(total_hp, 2),
		"expected_total_reward": _round_to(total_reward, 2),
		"expected_total_sand": _round_to(total_sand, 2),
		"expected_total_horizontal_pressure": _round_to(total_horizontal, 3),
		"expected_total_vertical_pressure": _round_to(total_vertical, 3),
		"hp_per_min": _round_to(total_hp / safe_minutes, 2),
		"sand_per_min": _round_to(total_sand / safe_minutes, 2),
		"reward_per_min": _round_to(total_reward / safe_minutes, 2),
		"hp_per_sec": _round_to(total_hp / maxf(duration, 0.001), 3),
		"sand_limit_ratio": _round_to(total_sand / float(GC.WEIGHT_LIMIT_SAND_CELLS), 3),
		"display_weight": _round_to(_sand_cells_to_display_weight(int(round(total_sand))), 1),
	}


func _resolve_boss_block(day: int, difficulty_id: StringName):
	if not bool(_game_data.call("is_boss_day", day)):
		return null
	var day_definition = _game_data.call("get_day_definition", day)
	if day_definition == null:
		return null
	var boss_type = null
	if day_definition.boss_block_type_id != StringName():
		boss_type = _game_data.call("get_block_type_definition", day_definition.boss_block_type_id)
	return _game_data.call(
		"resolve_specific_block_definition",
		day_definition.boss_block_base_id,
		day_definition.boss_block_size_id,
		difficulty_id,
		day,
		boss_type
	)


func _build_gating_snapshot(catalog, day: int, difficulty_id: StringName) -> Dictionary:
	var live_size_ids := {}
	for raw_candidate in catalog.get_spawn_candidates(difficulty_id, day):
		var candidate: Dictionary = raw_candidate
		var size = candidate.get("size")
		if size != null:
			live_size_ids[str(size.size_id)] = true
	var individually_available_sizes: Array[String] = []
	var max_gate_blocked_pairs := 0
	var max_gate_blocked_size_ids := {}
	var max_gate_blocked_examples: Array[String] = []
	for raw_size in catalog.block_sizes:
		var size = raw_size
		if size == null:
			continue
		if _is_size_individually_available(size, day, difficulty_id):
			individually_available_sizes.append(str(size.size_id))
	for raw_material in catalog.block_materials:
		var material = raw_material
		if material == null or not _is_material_individually_available(material, day, difficulty_id):
			continue
		for raw_size in catalog.block_sizes:
			var size = raw_size
			if size == null or not _is_size_individually_available(size, day, difficulty_id):
				continue
			var gate_reason := _get_material_size_gate_reason(material, size)
			if gate_reason.is_empty():
				continue
			max_gate_blocked_pairs += 1
			max_gate_blocked_size_ids[str(size.size_id)] = true
			if max_gate_blocked_examples.size() < 6:
				max_gate_blocked_examples.append("%s+%s:%s" % [str(material.material_id), str(size.size_id), gate_reason])
	var live_sizes := live_size_ids.keys()
	live_sizes.sort()
	individually_available_sizes.sort()
	var blocked_sizes := max_gate_blocked_size_ids.keys()
	blocked_sizes.sort()
	return {
		"live_size_ids": live_sizes,
		"individually_available_size_ids": individually_available_sizes,
		"max_gate_blocked_pairs": max_gate_blocked_pairs,
		"max_gate_blocked_size_ids": blocked_sizes,
		"max_gate_blocked_examples": max_gate_blocked_examples,
	}


func _is_material_individually_available(material, day: int, difficulty_id: StringName) -> bool:
	if material == null or not bool(material.is_enabled):
		return false
	if not _matches_difficulty_limit(material.min_difficulty, difficulty_id):
		return false
	if int(material.min_stage) > 0 and day < int(material.min_stage):
		return false
	if int(material.max_stage) > 0 and day > int(material.max_stage):
		return false
	return true


func _is_size_individually_available(size, day: int, difficulty_id: StringName) -> bool:
	if size == null or not bool(size.is_enabled):
		return false
	if not _matches_difficulty_limit(size.min_difficulty, difficulty_id):
		return false
	if int(size.min_stage) > 0 and day < int(size.min_stage):
		return false
	if int(size.max_stage) > 0 and day > int(size.max_stage):
		return false
	return true


func _matches_difficulty_limit(min_difficulty: StringName, difficulty_id: StringName) -> bool:
	if min_difficulty == StringName() or min_difficulty == &"any":
		return true
	return _get_difficulty_rank(str(difficulty_id)) >= _get_difficulty_rank(str(min_difficulty))


func _get_material_size_gate_reason(material, size) -> String:
	var size_area := int(size.area)
	if size_area <= 0:
		size_area = maxi(int(size.width_u) * int(size.height_u), 1)
	if int(material.max_allowed_area) > 0 and size_area > int(material.max_allowed_area):
		return "area"
	if int(material.max_allowed_width) > 0 and int(size.width_u) > int(material.max_allowed_width):
		return "width"
	if int(material.max_allowed_height) > 0 and int(size.height_u) > int(material.max_allowed_height):
		return "height"
	return ""


func _build_attack_baseline() -> Dictionary:
	var module_rows: Array[Dictionary] = []
	var melee_dps: Array[float] = []
	var ranged_dps: Array[float] = []
	for raw_definition in _game_data.call("get_attack_module_definitions"):
		var definition = raw_definition
		if definition == null:
			continue
		var module_type := String(definition.module_type)
		if module_type == "mechanic":
			continue
		var grade := "D"
		var base_damage := _get_base_damage_for_grade(definition, grade)
		var aps := _get_aps(definition, grade)
		var full_hit_multiplier := 1
		if String(definition.item_id) == "scatter_module":
			full_hit_multiplier = maxi(int(definition.projectile_count), 1)
		var full_hit_dps := aps * float(base_damage) * float(full_hit_multiplier)
		var row := {
			"module_id": String(definition.item_id),
			"type": module_type,
			"grade": grade,
			"base_damage": base_damage,
			"aps": _round_to(aps, 3),
			"full_hit_dps": _round_to(full_hit_dps, 2),
		}
		module_rows.append(row)
		if module_type == "melee":
			melee_dps.append(full_hit_dps)
		elif module_type == "ranged":
			ranged_dps.append(full_hit_dps)
	return {
		"default_sword_d_dps": _round_to(float(GC.PLAYER_ATTACK_DAMAGE) / float(GC.PLAYER_ATTACK_COOLDOWN), 2),
		"d_melee_average_full_hit_dps": _round_to(_average(melee_dps), 2),
		"d_ranged_average_full_hit_dps": _round_to(_average(ranged_dps), 2),
		"module_rows": module_rows,
	}


func _get_base_damage_for_grade(definition, grade: String) -> int:
	var grade_map: Dictionary = definition.base_damage_by_grade
	if grade_map.has(grade):
		var grade_damage := int(grade_map[grade])
		if grade_damage > 0:
			return grade_damage
	var explicit_base_damage := int(definition.module_base_damage)
	if explicit_base_damage > 0:
		return explicit_base_damage
	return 1


func _get_aps(definition, grade: String) -> float:
	var module_speed := maxf(float(definition.attack_speed_multiplier), 0.01)
	module_speed *= float(GC.ATTACK_MODULE_GRADE_SPEED_MULTIPLIERS.get(grade, 1.0))
	return module_speed / float(GC.PLAYER_ATTACK_COOLDOWN)


func _compare_summaries(v1: Dictionary, v2: Dictionary) -> Dictionary:
	if v1.is_empty() or v2.is_empty():
		return {}
	return {
		"material_l1_delta_pct": _round_to(_distribution_l1_delta(v1["material_counts"], v2["material_counts"], int(v1["resolved_count"]), int(v2["resolved_count"])), 2),
		"size_l1_delta_pct": _round_to(_distribution_l1_delta(v1["size_counts"], v2["size_counts"], int(v1["resolved_count"]), int(v2["resolved_count"])), 2),
		"pair_l1_delta_pct": _round_to(_distribution_l1_delta(v1["pair_counts"], v2["pair_counts"], int(v1["resolved_count"]), int(v2["resolved_count"])), 2),
		"hp_avg_delta": _round_to(float(v2["hp_avg"]) - float(v1["hp_avg"]), 2),
		"reward_avg_delta": _round_to(float(v2["reward_avg"]) - float(v1["reward_avg"]), 2),
		"sand_avg_delta": _round_to(float(v2["sand_avg"]) - float(v1["sand_avg"]), 2),
		"horizontal_pressure_avg_delta": _round_to(float(v2["horizontal_pressure_avg"]) - float(v1["horizontal_pressure_avg"]), 3),
		"area_avg_delta": _round_to(float(v2["area_avg"]) - float(v1["area_avg"]), 3),
	}


func _build_pressure_curve_diagnosis(v1_conditions: Array[Dictionary]) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for difficulty_id in TEST_DIFFICULTIES:
		rows.append(_make_diagnosis_row(difficulty_id, "Day 1-4 intro", [1, 2, 3, 4], v1_conditions))
		rows.append(_make_diagnosis_row(difficulty_id, "Day 5 rush", [5], v1_conditions))
		rows.append(_make_diagnosis_row(difficulty_id, "Day 6-9 post-rush", [6, 7, 8, 9], v1_conditions))
		rows.append(_make_diagnosis_row(difficulty_id, "Day 10 boss", [10], v1_conditions))
		rows.append(_make_diagnosis_row(difficulty_id, "Day 11-14 mid", [11, 12, 13, 14], v1_conditions))
		rows.append(_make_diagnosis_row(difficulty_id, "Day 15 rush", [15], v1_conditions))
		rows.append(_make_diagnosis_row(difficulty_id, "Day 16-20 late entry", [16, 17, 18, 19, 20], v1_conditions))
		rows.append(_make_diagnosis_row(difficulty_id, "Day 21-29 late run", [21, 22, 23, 24, 25, 26, 27, 28, 29], v1_conditions))
		rows.append(_make_diagnosis_row(difficulty_id, "Day 30 final", [30], v1_conditions))
	return rows


func _make_diagnosis_row(difficulty_id: String, days: String, day_numbers: Array, conditions: Array[Dictionary]) -> Dictionary:
	var first_condition := _find_condition(conditions, difficulty_id, int(day_numbers.front()))
	var last_condition := _find_condition(conditions, difficulty_id, int(day_numbers.back()))
	var first_pressure: Dictionary = first_condition.get("pressure", {})
	var last_pressure: Dictionary = last_condition.get("pressure", {})
	var hp_change := _ratio_or_zero(float(last_pressure.get("hp_per_min", 0.0)), float(first_pressure.get("hp_per_min", 0.0)), 2)
	var sand_change := _ratio_or_zero(float(last_pressure.get("sand_per_min", 0.0)), float(first_pressure.get("sand_per_min", 0.0)), 2)
	var spawn_start := int(first_pressure.get("expected_spawn_count", 0))
	var spawn_end := int(last_pressure.get("expected_spawn_count", 0))
	var readout := "steady"
	if days.find("rush") >= 0:
		readout = "tempo spike"
	elif days.find("boss") >= 0 or days.find("final") >= 0:
		readout = "boss pressure"
	elif hp_change >= 1.25 or sand_change >= 1.25 or spawn_end > spawn_start:
		readout = "ramping"
	return {
		"difficulty": difficulty_id,
		"segment": days,
		"first_day": int(day_numbers.front()),
		"last_day": int(day_numbers.back()),
		"spawn_count_start": spawn_start,
		"spawn_count_end": spawn_end,
		"hp_per_min_start": float(first_pressure.get("hp_per_min", 0.0)),
		"hp_per_min_end": float(last_pressure.get("hp_per_min", 0.0)),
		"sand_per_min_start": float(first_pressure.get("sand_per_min", 0.0)),
		"sand_per_min_end": float(last_pressure.get("sand_per_min", 0.0)),
		"hp_change_ratio": hp_change,
		"sand_change_ratio": sand_change,
		"readout": readout,
	}


func _build_risk_rows(v1_conditions: Array[Dictionary], v2_comparisons: Array[Dictionary]) -> Array[Dictionary]:
	var normal_day1 := _find_condition(v1_conditions, "normal", 1)
	var normal_day5 := _find_condition(v1_conditions, "normal", 5)
	var normal_day30 := _find_condition(v1_conditions, "normal", 30)
	var hard_day30 := _find_condition(v1_conditions, "hard", 30)
	return [
		{
			"priority": "P1",
			"risk": "Early v1 size variety is extremely narrow",
			"evidence": "normal Day 1 live sizes: %s" % _join_strings(normal_day1.get("gating", {}).get("live_size_ids", []), ", "),
			"action": "Do not tune blindly; use size spawn rule design before widening live pool.",
		},
		{
			"priority": "P1",
			"risk": "Rush days are real tempo spikes",
			"evidence": "normal Day 5 expected spawns=%d, hp/min=%.2f, sand/min=%.2f" % [
				int(normal_day5.get("pressure", {}).get("expected_spawn_count", 0)),
				float(normal_day5.get("pressure", {}).get("hp_per_min", 0.0)),
				float(normal_day5.get("pressure", {}).get("sand_per_min", 0.0)),
			],
			"action": "Playtest rush readability before changing weights.",
		},
		{
			"priority": "P2",
			"risk": "Day 30 final regular tempo is slower than Day 29; final pressure depends heavily on boss block.",
			"evidence": "normal Day 30 expected spawns=%d, boss_hp=%d, total hp/min=%.2f" % [
				int(normal_day30.get("pressure", {}).get("expected_spawn_count", 0)),
				int(normal_day30.get("pressure", {}).get("boss_hp", 0)),
				float(normal_day30.get("pressure", {}).get("hp_per_min", 0.0)),
			],
			"action": "If final day feels flat after boss, tune StageTable later, not in this audit.",
		},
		{
			"priority": "P2",
			"risk": "Hard late-run HP pressure can exceed unscaled D-module throughput by a large margin.",
			"evidence": "hard Day 30 hp/sec=%.3f vs sword D DPS=%.2f" % [
				float(hard_day30.get("pressure", {}).get("hp_per_sec", 0.0)),
				float(_build_attack_baseline().get("default_sword_d_dps", 0.0)),
			],
			"action": "This likely requires shop/level growth; validate with real builds.",
		},
		{
			"priority": "P3",
			"risk": "v2 reference distribution is materially different from v1.",
			"evidence": "Key-day v2 comparisons show size/pair L1 deltas; see v1/v2 table.",
			"action": "Do not switch live resolver without a dedicated tuning pass.",
		},
	]


func _find_condition(conditions: Array[Dictionary], difficulty_id: String, day: int) -> Dictionary:
	for condition in conditions:
		if String(condition.get("difficulty", "")) == difficulty_id and int(condition.get("day", 0)) == day:
			return condition
	return {}


func _write_report(snapshot: Dictionary) -> Dictionary:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT_PATH.get_base_dir()))
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "Failed to open %s" % REPORT_PATH}
	file.store_string(_build_report(snapshot))
	file.close()
	return {"ok": true}


func _build_report(snapshot: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("# Day Pressure Snapshot")
	lines.append("")
	lines.append("Generated by `scripts/tests/day_pressure_snapshot.gd`.")
	lines.append("")
	lines.append("- Scope: current v1 live spawn pressure measurement. No balance data, `.tres`, TSV, or resolver path is changed.")
	lines.append("- Iterations per Day/difficulty condition: `%d`." % int(snapshot["iterations"]))
	lines.append("- Difficulties: `%s`." % _join_strings(TEST_DIFFICULTIES, ", "))
	lines.append("- Days measured for v1: `1-30`; key Day tables highlight `%s`." % _join_strings(KEY_DAYS, ", "))
	lines.append("- RNG seed base: `%d`." % int(snapshot["rng_seed_base"]))
	lines.append("- v1 path: current live `BlockCatalog.get_spawn_candidates()` compatible weighted candidates.")
	lines.append("- v2 path: reference only, simulation-only `BlockSpawnV2Simulator`; not connected to live spawning.")
	lines.append("- Expected spawn count follows `floor(day_duration / (BLOCK_SPAWN_INTERVAL * spawn_interval_multiplier))` based on `Main.gd` Timer usage.")
	lines.append("")
	_append_stage_table(lines, snapshot["stage_rows"])
	_append_v1_average_table(lines, snapshot["v1_conditions"], true)
	_append_v1_pressure_table(lines, snapshot["v1_conditions"], true)
	_append_distribution_summary(lines, snapshot["v1_conditions"], "material_counts", "Material Distribution Summary")
	_append_distribution_summary(lines, snapshot["v1_conditions"], "size_counts", "Size Distribution Summary")
	_append_top_pair_summary(lines, snapshot["v1_conditions"])
	_append_sand_risk_table(lines, snapshot["v1_conditions"])
	_append_player_throughput_table(lines, snapshot["v1_conditions"], snapshot["attack_baseline"])
	_append_v2_comparison_table(lines, snapshot["v2_comparisons"])
	_append_gating_table(lines, snapshot["v1_conditions"])
	_append_diagnosis_table(lines, snapshot["diagnosis"])
	_append_risk_table(lines, snapshot["risks"])
	_append_full_day_tables(lines, snapshot["v1_conditions"])
	_append_notes(lines, snapshot)
	return "\n".join(lines)


func _append_stage_table(lines: Array[String], rows: Array) -> void:
	lines.append("## A. StageTable Day Settings")
	lines.append("")
	lines.append("| Day | Type | Duration | Spawn mult | Effective interval | HP mult | Rush | Boss | Boss material | Boss size | Boss type | Expected spawns |")
	lines.append("| ---: | --- | ---: | ---: | ---: | ---: | --- | --- | --- | --- | --- | ---: |")
	for row in rows:
		lines.append("| %d | %s | %.1f | %.3f | %.3f | %.3f | %s | %s | %s | %s | %s | %d |" % [
			int(row["day"]),
			str(row["day_type"]),
			float(row["duration"]),
			float(row["spawn_interval_multiplier"]),
			float(row["effective_spawn_interval"]),
			float(row["block_hp_multiplier"]),
			"yes" if bool(row["is_rush"]) else "no",
			"yes" if bool(row["is_boss"]) else "no",
			_empty_dash(row["boss_material_id"]),
			_empty_dash(row["boss_size_id"]),
			_empty_dash(row["boss_type_id"]),
			int(row["expected_spawn_count"]),
		])
	lines.append("")


func _append_v1_average_table(lines: Array[String], conditions: Array, key_only: bool) -> void:
	lines.append("## B. Day v1 Average Block Metrics")
	lines.append("")
	lines.append("| Difficulty | Day | Candidates | Avg HP | Max HP | Avg reward | Max reward | Avg sand | Max sand | Avg H pressure | Avg V pressure | Avg area |")
	lines.append("| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |")
	for condition in conditions:
		var day := int(condition["day"])
		if key_only and not KEY_DAYS.has(day):
			continue
		var summary: Dictionary = condition["summary"]
		lines.append("| %s | %d | %d | %.2f | %d | %.2f | %d | %.2f | %d | %.3f | %.3f | %.3f |" % [
			str(condition["difficulty"]),
			day,
			int(summary["candidate_count"]),
			float(summary["hp_avg"]),
			int(summary["hp_max"]),
			float(summary["reward_avg"]),
			int(summary["reward_max"]),
			float(summary["sand_avg"]),
			int(summary["sand_max"]),
			float(summary["horizontal_pressure_avg"]),
			float(summary["vertical_pressure_avg"]),
			float(summary["area_avg"]),
		])
	lines.append("")


func _append_v1_pressure_table(lines: Array[String], conditions: Array, key_only: bool) -> void:
	lines.append("## C. Day Total Pressure Estimate")
	lines.append("")
	lines.append("| Difficulty | Day | Expected spawns | Boss HP | Expected total HP | Expected total sand | HP/min | Sand/min | Reward/min | Sand limit ratio |")
	lines.append("| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |")
	for condition in conditions:
		var day := int(condition["day"])
		if key_only and not KEY_DAYS.has(day):
			continue
		var pressure: Dictionary = condition["pressure"]
		lines.append("| %s | %d | %d | %d | %.2f | %.2f | %.2f | %.2f | %.2f | %.3f |" % [
			str(condition["difficulty"]),
			day,
			int(pressure["expected_spawn_count"]),
			int(pressure["boss_hp"]),
			float(pressure["expected_total_hp"]),
			float(pressure["expected_total_sand"]),
			float(pressure["hp_per_min"]),
			float(pressure["sand_per_min"]),
			float(pressure["reward_per_min"]),
			float(pressure["sand_limit_ratio"]),
		])
	lines.append("")


func _append_distribution_summary(lines: Array[String], conditions: Array, count_key: String, title: String) -> void:
	lines.append("## %s" % title)
	lines.append("")
	lines.append("| Difficulty | Day | Top distribution |")
	lines.append("| --- | ---: | --- |")
	for condition in conditions:
		var day := int(condition["day"])
		if not KEY_DAYS.has(day):
			continue
		var summary: Dictionary = condition["summary"]
		lines.append("| %s | %d | %s |" % [
			str(condition["difficulty"]),
			day,
			_format_top_counts(summary[count_key], int(summary["resolved_count"]), TOP_LIMIT),
		])
	lines.append("")


func _append_top_pair_summary(lines: Array[String], conditions: Array) -> void:
	lines.append("## F. Top Material-Size Pairs")
	lines.append("")
	lines.append("| Difficulty | Day | Top pairs |")
	lines.append("| --- | ---: | --- |")
	for condition in conditions:
		var day := int(condition["day"])
		if not KEY_DAYS.has(day):
			continue
		var summary: Dictionary = condition["summary"]
		lines.append("| %s | %d | %s |" % [
			str(condition["difficulty"]),
			day,
			_format_top_counts(summary["pair_counts"], int(summary["resolved_count"]), TOP_LIMIT),
		])
	lines.append("")


func _append_sand_risk_table(lines: Array[String], conditions: Array) -> void:
	lines.append("## G. Sand Weight Risk")
	lines.append("")
	lines.append("| Difficulty | Day | Avg sand/spawn | Expected total sand | Display weight | Weight limit pct | Spawns to limit if unmined |")
	lines.append("| --- | ---: | ---: | ---: | ---: | ---: | ---: |")
	for condition in conditions:
		var day := int(condition["day"])
		if not KEY_DAYS.has(day):
			continue
		var summary: Dictionary = condition["summary"]
		var pressure: Dictionary = condition["pressure"]
		var avg_sand := float(summary["sand_avg"])
		var spawns_to_limit := _ratio_or_zero(float(GC.WEIGHT_LIMIT_SAND_CELLS), avg_sand, 1)
		lines.append("| %s | %d | %.2f | %.2f | %.1f %s | %.1f%% | %.1f |" % [
			str(condition["difficulty"]),
			day,
			avg_sand,
			float(pressure["expected_total_sand"]),
			float(pressure["display_weight"]),
			GC.DISPLAY_WEIGHT_UNIT,
			float(pressure["sand_limit_ratio"]) * 100.0,
			spawns_to_limit,
		])
	lines.append("")


func _append_player_throughput_table(lines: Array[String], conditions: Array, attack_baseline: Dictionary) -> void:
	lines.append("## Player Throughput Reference")
	lines.append("")
	lines.append("- Sword D baseline DPS: `%.2f`." % float(attack_baseline["default_sword_d_dps"]))
	lines.append("- D-grade melee average full-hit DPS: `%.2f`." % float(attack_baseline["d_melee_average_full_hit_dps"]))
	lines.append("- D-grade ranged average full-hit DPS: `%.2f`." % float(attack_baseline["d_ranged_average_full_hit_dps"]))
	lines.append("")
	lines.append("| Difficulty | Day | HP/sec pressure | Sword D DPS ratio | D melee avg ratio | Readout |")
	lines.append("| --- | ---: | ---: | ---: | ---: | --- |")
	for condition in conditions:
		var day := int(condition["day"])
		if not KEY_DAYS.has(day):
			continue
		var pressure: Dictionary = condition["pressure"]
		var hp_per_sec := float(pressure["hp_per_sec"])
		var sword_ratio := _ratio_or_zero(hp_per_sec, float(attack_baseline["default_sword_d_dps"]), 3)
		var melee_ratio := _ratio_or_zero(hp_per_sec, float(attack_baseline["d_melee_average_full_hit_dps"]), 3)
		var readout := "growth optional"
		if sword_ratio > 0.75:
			readout = "growth required"
		elif sword_ratio > 0.45:
			readout = "growth expected"
		lines.append("| %s | %d | %.3f | %.3f | %.3f | %s |" % [
			str(condition["difficulty"]),
			day,
			hp_per_sec,
			sword_ratio,
			melee_ratio,
			readout,
		])
	lines.append("")


func _append_v2_comparison_table(lines: Array[String], comparisons: Array) -> void:
	lines.append("## H. v1/v2 Reference Comparison")
	lines.append("")
	lines.append("v2 remains simulation-only. This table is a tuning reference, not a live resolver recommendation.")
	lines.append("")
	lines.append("| Difficulty | Day | v1 avg HP | v2 avg HP | v1 avg reward | v2 avg reward | v1 avg sand | v2 avg sand | Size L1 pct | Pair L1 pct | H pressure delta | Area delta |")
	lines.append("| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |")
	for comparison_row in comparisons:
		var v1: Dictionary = comparison_row["v1"]
		var v2: Dictionary = comparison_row["v2"]
		var comparison: Dictionary = comparison_row["comparison"]
		lines.append("| %s | %d | %.2f | %.2f | %.2f | %.2f | %.2f | %.2f | %.2f | %.2f | %.3f | %.3f |" % [
			str(comparison_row["difficulty"]),
			int(comparison_row["day"]),
			float(v1["hp_avg"]),
			float(v2["hp_avg"]),
			float(v1["reward_avg"]),
			float(v2["reward_avg"]),
			float(v1["sand_avg"]),
			float(v2["sand_avg"]),
			float(comparison["size_l1_delta_pct"]),
			float(comparison["pair_l1_delta_pct"]),
			float(comparison["horizontal_pressure_avg_delta"]),
			float(comparison["area_avg_delta"]),
		])
	lines.append("")


func _append_gating_table(lines: Array[String], conditions: Array) -> void:
	lines.append("## Current v1 Size Gating Snapshot")
	lines.append("")
	lines.append("| Difficulty | Day | Live sizes | Max-gate blocked pairs | Max-gate blocked sizes | Examples |")
	lines.append("| --- | ---: | --- | ---: | --- | --- |")
	for condition in conditions:
		var day := int(condition["day"])
		if not KEY_DAYS.has(day):
			continue
		var gating: Dictionary = condition["gating"]
		lines.append("| %s | %d | %s | %d | %s | %s |" % [
			str(condition["difficulty"]),
			day,
			_join_or_dash(gating.get("live_size_ids", []), ", "),
			int(gating.get("max_gate_blocked_pairs", 0)),
			_join_or_dash(gating.get("max_gate_blocked_size_ids", []), ", "),
			_join_or_dash(gating.get("max_gate_blocked_examples", []), "; "),
		])
	lines.append("")


func _append_diagnosis_table(lines: Array[String], rows: Array) -> void:
	lines.append("## I. Pressure Curve Diagnosis")
	lines.append("")
	lines.append("| Difficulty | Segment | Spawn count | HP/min | Sand/min | HP change | Sand change | Readout |")
	lines.append("| --- | --- | --- | --- | --- | ---: | ---: | --- |")
	for row in rows:
		lines.append("| %s | %s | %d -> %d | %.2f -> %.2f | %.2f -> %.2f | %.2fx | %.2fx | %s |" % [
			str(row["difficulty"]),
			str(row["segment"]),
			int(row["spawn_count_start"]),
			int(row["spawn_count_end"]),
			float(row["hp_per_min_start"]),
			float(row["hp_per_min_end"]),
			float(row["sand_per_min_start"]),
			float(row["sand_per_min_end"]),
			float(row["hp_change_ratio"]),
			float(row["sand_change_ratio"]),
			str(row["readout"]),
		])
	lines.append("")


func _append_risk_table(lines: Array[String], risks: Array) -> void:
	lines.append("## J. Risk Candidates")
	lines.append("")
	lines.append("| Priority | Risk | Evidence | Suggested next step |")
	lines.append("| --- | --- | --- | --- |")
	for risk in risks:
		lines.append("| %s | %s | %s | %s |" % [
			str(risk["priority"]),
			str(risk["risk"]),
			str(risk["evidence"]),
			str(risk["action"]),
		])
	lines.append("")


func _append_full_day_tables(lines: Array[String], conditions: Array) -> void:
	lines.append("## Full Day 1-30 Pressure Table")
	lines.append("")
	lines.append("This full table is included for trend inspection. Key distribution tables above remain focused on Days 1/5/10/15/20/25/30.")
	lines.append("")
	_append_v1_average_table(lines, conditions, false)
	_append_v1_pressure_table(lines, conditions, false)


func _append_notes(lines: Array[String], snapshot: Dictionary) -> void:
	lines.append("## Notes")
	lines.append("")
	for note in snapshot["notes"]:
		lines.append("- %s" % str(note))
	lines.append("- `block_types.tsv` currently has only `boss` with `can_spawn_randomly=false`; random live type distribution is therefore `none` in the measured v1 random spawns.")
	lines.append("- Boss block pressure is added separately to total Day pressure estimates on boss Days. Regular random-spawn averages remain separate.")
	lines.append("- Sand pressure is an upper-bound style estimate: it assumes decomposed sand remains unless the player mines, moves, or otherwise clears it.")
	lines.append("- No live balance values were changed by this measurement.")
	lines.append("")


func _build_console_summary(snapshot: Dictionary) -> Dictionary:
	var key_rows: Array[Dictionary] = []
	for condition in snapshot["v1_conditions"]:
		if not KEY_DAYS.has(int(condition["day"])):
			continue
		var pressure: Dictionary = condition["pressure"]
		key_rows.append({
			"difficulty": condition["difficulty"],
			"day": condition["day"],
			"expected_spawns": pressure["expected_spawn_count"],
			"hp_per_min": pressure["hp_per_min"],
			"sand_per_min": pressure["sand_per_min"],
			"sand_limit_ratio": pressure["sand_limit_ratio"],
		})
	return {
		"ok": bool(snapshot.get("ok", false)),
		"iterations": int(snapshot["iterations"]),
		"rng_seed_base": int(snapshot["rng_seed_base"]),
		"report_path": snapshot.get("report_path", REPORT_PATH),
		"key_rows": key_rows,
	}


func _roll_weighted_candidate(candidates: Array[Dictionary], total_weight: float, rng: RandomNumberGenerator) -> Dictionary:
	if candidates.is_empty():
		return {}
	if total_weight <= 0.0:
		return candidates[0]
	var roll := rng.randf_range(0.0, total_weight)
	for candidate in candidates:
		roll -= float(candidate.get("weight", 0.0))
		if roll <= 0.0:
			return candidate
	return candidates[candidates.size() - 1]


func _get_effective_spawn_interval(day: int) -> float:
	return maxf(GC.BLOCK_SPAWN_INTERVAL * float(_game_data.call("get_spawn_interval_multiplier", day)), 0.001)


func _get_expected_spawn_count(day: int) -> int:
	return int(floor(float(_game_data.call("get_day_duration", day)) / _get_effective_spawn_interval(day)))


func _sand_cells_to_display_weight(sand_cells: int) -> float:
	return float(sand_cells) * GC.DISPLAY_WEIGHT_PER_SAND_CELL


func _get_difficulty_rank(difficulty_id: String) -> int:
	for index in range(GC.DIFFICULTY_OPTIONS.size()):
		var option: Dictionary = GC.DIFFICULTY_OPTIONS[index]
		if String(option.get("id", "")) == difficulty_id:
			return index
	return 0


func _seed_for(difficulty_id: String, day: int, version: int) -> int:
	var difficulty_index := TEST_DIFFICULTIES.find(difficulty_id)
	return RNG_SEED_BASE + day * 997 + max(difficulty_index, 0) * 10007 + version * 1000003


func _distribution_l1_delta(a: Dictionary, b: Dictionary, a_total: int, b_total: int) -> float:
	var total := 0.0
	for key in _merged_sorted_keys(a, b):
		total += absf(_pct_raw(int(a.get(key, 0)), a_total) - _pct_raw(int(b.get(key, 0)), b_total))
	return total


func _format_top_counts(counts: Dictionary, total: int, limit: int) -> String:
	var top := _get_top_counts(counts, total, limit)
	if top.is_empty():
		return "-"
	var parts: Array[String] = []
	for row in top:
		parts.append("%s %.2f%%" % [str(row["id"]), float(row["pct"])])
	return ", ".join(parts)


func _get_top_counts(counts: Dictionary, total: int, limit: int) -> Array[Dictionary]:
	var source: Array[Dictionary] = []
	for key in counts.keys():
		source.append({
			"id": str(key),
			"count": int(counts[key]),
			"pct": _round_to(_pct_raw(int(counts[key]), total), 2),
		})
	var result: Array[Dictionary] = []
	while not source.is_empty() and result.size() < limit:
		var best_index := 0
		var best_count := int(source[0]["count"])
		for index in range(1, source.size()):
			var count := int(source[index]["count"])
			if count > best_count:
				best_count = count
				best_index = index
		result.append(source[best_index])
		source.remove_at(best_index)
	return result


func _merged_sorted_keys(a: Dictionary, b: Dictionary) -> Array:
	var seen := {}
	for key in a.keys():
		seen[key] = true
	for key in b.keys():
		seen[key] = true
	var keys := seen.keys()
	keys.sort()
	return keys


func _increment_counter(counts: Dictionary, key: String, amount := 1) -> void:
	counts[key] = int(counts.get(key, 0)) + amount


func _pct_raw(count: int, total: int) -> float:
	if total <= 0:
		return 0.0
	return float(count) * 100.0 / float(total)


func _round_to(value: float, decimals: int) -> float:
	var factor := pow(10.0, decimals)
	return round(value * factor) / factor


func _ratio_or_zero(numerator: float, denominator: float, decimals: int) -> float:
	if absf(denominator) <= 0.000001:
		return 0.0
	return _round_to(numerator / denominator, decimals)


func _average(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value in values:
		total += float(value)
	return total / float(values.size())


func _sum_array(values: Array) -> float:
	var total := 0.0
	for value in values:
		total += float(value)
	return total


func _is_wide_or_larger(size_group: String) -> bool:
	return size_group == "wide_large" or size_group == "huge" or size_group == "event_like"


func _empty_dash(value) -> String:
	var text := str(value).strip_edges()
	return "-" if text.is_empty() else text


func _join_or_dash(values: Array, separator: String) -> String:
	if values.is_empty():
		return "-"
	return _join_strings(values, separator)


func _join_strings(values: Array, separator: String) -> String:
	var text_values: Array[String] = []
	for value in values:
		text_values.append(str(value))
	return separator.join(text_values)
