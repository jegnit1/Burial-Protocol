extends SceneTree

const SIMULATOR_PATH := "res://scripts/data/BlockSpawnV2Simulator.gd"
const REPORT_PATH := "res://docs/reports/spawn_distribution_snapshot.md"
const ITERATIONS := 10000
const TEST_DAYS := [1, 5, 10, 15, 20, 25, 30]
const TEST_DIFFICULTIES := ["normal", "hard"]
const TOP_PAIR_LIMIT := 8
const RECENT_WINDOW_SIZE := 10

var _game_data = null
var _simulator = null
var _ran := false


func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	_game_data = get_root().get_node_or_null("GameData")
	if _game_data == null:
		print(JSON.stringify({"ok": false, "error": "GameData autoload not available"}, "\t"))
		quit(1)
		return true

	var simulator_script = load(SIMULATOR_PATH)
	_simulator = simulator_script.new()
	var load_result = _simulator.load_rules_from_directory("res://data_tsv")
	if not bool(load_result.get("ok", false)):
		print(JSON.stringify({"ok": false, "errors": load_result.get("errors", [])}, "\t"))
		quit(1)
		return true

	var snapshot = _build_snapshot()
	var report_result = _write_report(snapshot)
	if not bool(report_result.get("ok", false)):
		snapshot["ok"] = false
		snapshot["report_error"] = str(report_result.get("error", "failed to write report"))
		print(JSON.stringify(snapshot, "\t"))
		quit(1)
		return true

	snapshot["report_path"] = REPORT_PATH
	print(JSON.stringify(_build_console_summary(snapshot), "\t"))
	quit(0)
	return true


func _build_snapshot() -> Dictionary:
	var catalog = _game_data.call("get_block_catalog")
	var stage_table = _game_data.call("get_stage_table")
	var conditions = []
	for difficulty_id in TEST_DIFFICULTIES:
		for day_number in TEST_DAYS:
			var v1_summary = _simulate_v1(day_number, StringName(difficulty_id), _seed_for(difficulty_id, day_number, 1))
			var v2_summary = _simulate_v2(catalog, stage_table, day_number, StringName(difficulty_id), _seed_for(difficulty_id, day_number, 2))
			conditions.append({
				"difficulty": difficulty_id,
				"day": day_number,
				"v1": v1_summary,
				"v2": v2_summary,
				"comparison": _compare_summaries(v1_summary, v2_summary),
			})
	return {
		"ok": true,
		"iterations": ITERATIONS,
		"conditions": conditions,
		"notes": [
			"v1 uses current live BlockCatalog.get_spawn_candidates and BlockSpawnResolver.resolve_random_block.",
			"v2 is simulation-only and is not connected to live game spawning.",
			"v2 ignores material max_allowed_area/max_allowed_width/max_allowed_height for regular random size filtering.",
			"v2 hard-filters only global size rules: enabled, width <= center play width, height <= 3U.",
		],
	}


func _simulate_v1(day_number: int, difficulty_id: StringName, seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var summary = _make_empty_summary()
	for _index in range(ITERATIONS):
		var type_definition = _game_data.call("pick_block_type_definition_or_none", rng)
		var resolved = _game_data.call("resolve_random_block_definition", rng, difficulty_id, day_number, type_definition)
		if resolved != null:
			_record_resolved_spawn(summary, resolved)
	return _finalize_summary(summary)


func _simulate_v2(catalog, stage_table, day_number: int, difficulty_id: StringName, seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var summary = _make_empty_summary()
	for _index in range(ITERATIONS):
		var resolved = _simulator.resolve_random_block_v2_simulation(catalog, stage_table, day_number, difficulty_id, rng)
		if resolved != null:
			_record_resolved_spawn(summary, resolved)
	return _finalize_summary(summary)


func _make_empty_summary() -> Dictionary:
	return {
		"iterations": ITERATIONS,
		"resolved_count": 0,
		"material_counts": {},
		"size_counts": {},
		"pair_counts": {},
		"width_group_counts": {},
		"area_group_counts": {},
		"size_group_counts": {},
		"risk_counts": {
			"gold_huge": 0,
			"bomb_huge": 0,
			"glass_wide_large": 0,
			"width_9_10": 0,
			"event_like": 0,
		},
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
		"wide_large_streak_current": 0,
		"wide_large_streak_max": 0,
		"recent_wide_window": [],
		"recent_wide_ratio_max": 0.0,
		"width_pressure_window": [],
		"width_pressure_window_max": 0.0,
		"area_pressure_window": [],
		"area_pressure_window_max": 0.0,
	}


func _record_resolved_spawn(summary: Dictionary, resolved) -> void:
	var material_id = str(resolved.material_id)
	var size_id = str(resolved.size_id)
	var taxonomy = _simulator.get_size_taxonomy(resolved.size_definition)
	var size_group = str(taxonomy.get("size_group", ""))
	var width_group = str(taxonomy.get("width_group", ""))
	var area_group = str(taxonomy.get("area_group", ""))
	var horizontal_pressure = float(taxonomy.get("horizontal_pressure_score", 0.0))
	var vertical_pressure = float(taxonomy.get("vertical_pressure_score", 0.0))
	var area = int(taxonomy.get("area", 1))
	var pair_id = "%s+%s" % [material_id, size_id]

	summary["resolved_count"] = int(summary["resolved_count"]) + 1
	_increment_counter(summary["material_counts"], material_id)
	_increment_counter(summary["size_counts"], size_id)
	_increment_counter(summary["pair_counts"], pair_id)
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

	_record_risks(summary, material_id, size_group, width_group)
	_record_pressure_windows(summary, size_group, horizontal_pressure, area)


func _record_risks(summary: Dictionary, material_id: String, size_group: String, width_group: String) -> void:
	var risk_counts = summary["risk_counts"]
	if material_id == "gold" and (size_group == "huge" or size_group == "event_like"):
		_increment_counter(risk_counts, "gold_huge")
	if material_id == "bomb" and (size_group == "large" or size_group == "huge" or size_group == "event_like"):
		_increment_counter(risk_counts, "bomb_huge")
	if material_id == "glass" and (size_group == "wide_large" or size_group == "huge" or size_group == "event_like"):
		_increment_counter(risk_counts, "glass_wide_large")
	if width_group == "w9_10":
		_increment_counter(risk_counts, "width_9_10")
	if size_group == "event_like":
		_increment_counter(risk_counts, "event_like")


func _record_pressure_windows(summary: Dictionary, size_group: String, horizontal_pressure: float, area: int) -> void:
	var wide_or_larger = _is_wide_or_larger(size_group)
	if wide_or_larger:
		summary["wide_large_streak_current"] = int(summary["wide_large_streak_current"]) + 1
	else:
		summary["wide_large_streak_current"] = 0
	summary["wide_large_streak_max"] = maxi(int(summary["wide_large_streak_max"]), int(summary["wide_large_streak_current"]))

	var recent_wide_window = summary["recent_wide_window"]
	if wide_or_larger:
		recent_wide_window.append(1)
	else:
		recent_wide_window.append(0)
	while recent_wide_window.size() > RECENT_WINDOW_SIZE:
		recent_wide_window.remove_at(0)
	summary["recent_wide_ratio_max"] = maxf(float(summary["recent_wide_ratio_max"]), _sum_array(recent_wide_window) / float(recent_wide_window.size()))

	var width_pressure_window = summary["width_pressure_window"]
	width_pressure_window.append(horizontal_pressure)
	while width_pressure_window.size() > RECENT_WINDOW_SIZE:
		width_pressure_window.remove_at(0)
	summary["width_pressure_window_max"] = maxf(float(summary["width_pressure_window_max"]), _sum_array(width_pressure_window))

	var area_pressure_window = summary["area_pressure_window"]
	area_pressure_window.append(area)
	while area_pressure_window.size() > RECENT_WINDOW_SIZE:
		area_pressure_window.remove_at(0)
	summary["area_pressure_window_max"] = maxf(float(summary["area_pressure_window_max"]), _sum_array(area_pressure_window))


func _finalize_summary(summary: Dictionary) -> Dictionary:
	var resolved_count = maxi(int(summary["resolved_count"]), 1)
	return {
		"iterations": int(summary["iterations"]),
		"resolved_count": int(summary["resolved_count"]),
		"material_counts": summary["material_counts"],
		"size_counts": summary["size_counts"],
		"pair_counts": summary["pair_counts"],
		"width_group_counts": summary["width_group_counts"],
		"area_group_counts": summary["area_group_counts"],
		"size_group_counts": summary["size_group_counts"],
		"risk_counts": summary["risk_counts"],
		"horizontal_pressure_avg": _round_to(float(summary["horizontal_pressure_sum"]) / float(resolved_count), 3),
		"horizontal_pressure_max": _round_to(float(summary["horizontal_pressure_max"]), 3),
		"vertical_pressure_avg": _round_to(float(summary["vertical_pressure_sum"]) / float(resolved_count), 3),
		"vertical_pressure_max": _round_to(float(summary["vertical_pressure_max"]), 3),
		"hp_avg": _round_to(float(summary["hp_sum"]) / float(resolved_count), 2),
		"hp_max": int(summary["hp_max"]),
		"reward_avg": _round_to(float(summary["reward_sum"]) / float(resolved_count), 2),
		"reward_max": int(summary["reward_max"]),
		"sand_avg": _round_to(float(summary["sand_sum"]) / float(resolved_count), 2),
		"sand_max": int(summary["sand_max"]),
		"wide_large_streak_max": int(summary["wide_large_streak_max"]),
		"recent_wide_ratio_max": _round_to(float(summary["recent_wide_ratio_max"]), 3),
		"width_pressure_window_max": _round_to(float(summary["width_pressure_window_max"]), 3),
		"area_pressure_window_max": _round_to(float(summary["area_pressure_window_max"]), 3),
	}


func _compare_summaries(v1: Dictionary, v2: Dictionary) -> Dictionary:
	return {
		"material_l1_delta_pct": _round_to(_distribution_l1_delta(v1["material_counts"], v2["material_counts"], int(v1["resolved_count"]), int(v2["resolved_count"])), 2),
		"size_l1_delta_pct": _round_to(_distribution_l1_delta(v1["size_counts"], v2["size_counts"], int(v1["resolved_count"]), int(v2["resolved_count"])), 2),
		"pair_l1_delta_pct": _round_to(_distribution_l1_delta(v1["pair_counts"], v2["pair_counts"], int(v1["resolved_count"]), int(v2["resolved_count"])), 2),
		"hp_avg_delta": _round_to(float(v2["hp_avg"]) - float(v1["hp_avg"]), 2),
		"reward_avg_delta": _round_to(float(v2["reward_avg"]) - float(v1["reward_avg"]), 2),
		"sand_avg_delta": _round_to(float(v2["sand_avg"]) - float(v1["sand_avg"]), 2),
		"horizontal_pressure_avg_delta": _round_to(float(v2["horizontal_pressure_avg"]) - float(v1["horizontal_pressure_avg"]), 3),
	}


func _write_report(snapshot: Dictionary) -> Dictionary:
	var global_dir = ProjectSettings.globalize_path(REPORT_PATH.get_base_dir())
	DirAccess.make_dir_recursive_absolute(global_dir)
	var file = FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "Failed to open %s" % REPORT_PATH}
	file.store_string(_build_report(snapshot))
	return {"ok": true}


func _build_report(snapshot: Dictionary) -> String:
	var lines = []
	lines.append("# Spawn Distribution Snapshot")
	lines.append("")
	lines.append("Generated by `scripts/tests/spawn_distribution_snapshot.gd`.")
	lines.append("")
	lines.append("- Iterations per condition: `%d`" % int(snapshot["iterations"]))
	lines.append("- Difficulties: `%s`" % _join_strings(TEST_DIFFICULTIES, ", "))
	lines.append("- Days: `%s`" % _join_strings(TEST_DAYS, ", "))
	lines.append("- v1 path: current live `BlockCatalog.get_spawn_candidates()` + `BlockSpawnResolver.resolve_random_block()`.")
	lines.append("- v2 path: simulation-only Spawn Pool + Weight Modifier.")
	lines.append("- v2 ignores material `max_allowed_area`, `max_allowed_width`, and `max_allowed_height` for regular random size filtering.")
	lines.append("- v2 hard-filters only global size rules: `is_enabled`, `width <= GameConstants.CENTER_COLUMNS`, `height <= 3U`.")
	lines.append("")
	lines.append("## V1 vs V2 Change Summary")
	lines.append("")
	lines.append("| Difficulty | Day | Material L1 pct | Size L1 pct | Pair L1 pct | HP avg delta | Reward avg delta | Sand avg delta | H pressure avg delta |")
	lines.append("| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |")
	for condition in snapshot["conditions"]:
		var comparison = condition["comparison"]
		lines.append("| %s | %d | %.2f | %.2f | %.2f | %.2f | %.2f | %.2f | %.3f |" % [
			str(condition["difficulty"]),
			int(condition["day"]),
			float(comparison["material_l1_delta_pct"]),
			float(comparison["size_l1_delta_pct"]),
			float(comparison["pair_l1_delta_pct"]),
			float(comparison["hp_avg_delta"]),
			float(comparison["reward_avg_delta"]),
			float(comparison["sand_avg_delta"]),
			float(comparison["horizontal_pressure_avg_delta"]),
		])
	lines.append("")
	lines.append("## Condition Details")
	for condition in snapshot["conditions"]:
		lines.append("")
		lines.append("### %s Day %d" % [str(condition["difficulty"]), int(condition["day"])])
		lines.append("")
		lines.append(_build_metric_table(condition["v1"], condition["v2"]))
		lines.append("")
		lines.append("#### Material Distribution")
		lines.append("")
		lines.append(_build_distribution_table(condition["v1"]["material_counts"], condition["v2"]["material_counts"], int(condition["v1"]["resolved_count"]), int(condition["v2"]["resolved_count"]), "Material"))
		lines.append("")
		lines.append("#### Size Distribution")
		lines.append("")
		lines.append(_build_distribution_table(condition["v1"]["size_counts"], condition["v2"]["size_counts"], int(condition["v1"]["resolved_count"]), int(condition["v2"]["resolved_count"]), "Size"))
		lines.append("")
		lines.append("#### Material-Size Pair Top %d" % TOP_PAIR_LIMIT)
		lines.append("")
		lines.append(_build_top_pair_table(condition["v1"]["pair_counts"], condition["v2"]["pair_counts"], int(condition["v1"]["resolved_count"]), int(condition["v2"]["resolved_count"])))
		lines.append("")
		lines.append("#### Width Group Distribution")
		lines.append("")
		lines.append(_build_distribution_table(condition["v1"]["width_group_counts"], condition["v2"]["width_group_counts"], int(condition["v1"]["resolved_count"]), int(condition["v2"]["resolved_count"]), "Width group"))
		lines.append("")
		lines.append("#### Area Group Distribution")
		lines.append("")
		lines.append(_build_distribution_table(condition["v1"]["area_group_counts"], condition["v2"]["area_group_counts"], int(condition["v1"]["resolved_count"]), int(condition["v2"]["resolved_count"]), "Area group"))
		lines.append("")
		lines.append("#### Risk Combination Rate")
		lines.append("")
		lines.append(_build_distribution_table(condition["v1"]["risk_counts"], condition["v2"]["risk_counts"], int(condition["v1"]["resolved_count"]), int(condition["v2"]["resolved_count"]), "Risk"))
	lines.append("")
	lines.append("## Implementation Warnings")
	lines.append("")
	lines.append("- This script does not change live spawning. It only samples v1 and v2 side by side.")
	lines.append("- Current v2 candidate filtering deliberately ignores material `max_allowed_*`; this is the expected experimental behavior.")
	lines.append("- Current data only contains existing live sizes, so width 9~10 and huge future-size risks remain structural checks until larger non-live fixture sizes are added.")
	lines.append("- `size_1x4` is classified as `event_like` but excluded from v2 regular candidates by the global `height <= 3U` rule.")
	lines.append("- Before switching live resolver behavior, add future width 1~10 / height 1~3 non-live fixture data and re-run this report.")
	lines.append("")
	return _join_strings(lines, "\n")


func _build_metric_table(v1: Dictionary, v2: Dictionary) -> String:
	var lines = []
	lines.append("| Metric | v1 | v2 | Delta |")
	lines.append("| --- | ---: | ---: | ---: |")
	for metric in [
		"resolved_count",
		"horizontal_pressure_avg",
		"horizontal_pressure_max",
		"vertical_pressure_avg",
		"vertical_pressure_max",
		"hp_avg",
		"hp_max",
		"reward_avg",
		"reward_max",
		"sand_avg",
		"sand_max",
		"wide_large_streak_max",
		"recent_wide_ratio_max",
		"width_pressure_window_max",
		"area_pressure_window_max",
	]:
		var v1_value = float(v1[metric])
		var v2_value = float(v2[metric])
		lines.append("| %s | %.3f | %.3f | %.3f |" % [metric, v1_value, v2_value, v2_value - v1_value])
	return _join_strings(lines, "\n")


func _build_distribution_table(v1_counts: Dictionary, v2_counts: Dictionary, v1_total: int, v2_total: int, label: String) -> String:
	var lines = []
	lines.append("| %s | v1 count | v1 pct | v2 count | v2 pct | Delta pct |" % label)
	lines.append("| --- | ---: | ---: | ---: | ---: | ---: |")
	for key in _merged_sorted_keys(v1_counts, v2_counts):
		var v1_count = int(v1_counts.get(key, 0))
		var v2_count = int(v2_counts.get(key, 0))
		var v1_pct = _pct(v1_count, v1_total)
		var v2_pct = _pct(v2_count, v2_total)
		lines.append("| %s | %d | %.2f | %d | %.2f | %.2f |" % [str(key), v1_count, v1_pct, v2_count, v2_pct, v2_pct - v1_pct])
	return _join_strings(lines, "\n")


func _build_top_pair_table(v1_counts: Dictionary, v2_counts: Dictionary, v1_total: int, v2_total: int) -> String:
	var v1_top = _get_top_counts(v1_counts, v1_total, TOP_PAIR_LIMIT)
	var v2_top = _get_top_counts(v2_counts, v2_total, TOP_PAIR_LIMIT)
	var lines = []
	lines.append("| Rank | v1 pair | v1 pct | v2 pair | v2 pct |")
	lines.append("| ---: | --- | ---: | --- | ---: |")
	for index in range(TOP_PAIR_LIMIT):
		var v1_id = ""
		var v1_pct = 0.0
		var v2_id = ""
		var v2_pct = 0.0
		if index < v1_top.size():
			v1_id = str(v1_top[index]["id"])
			v1_pct = float(v1_top[index]["pct"])
		if index < v2_top.size():
			v2_id = str(v2_top[index]["id"])
			v2_pct = float(v2_top[index]["pct"])
		lines.append("| %d | %s | %.2f | %s | %.2f |" % [index + 1, v1_id, v1_pct, v2_id, v2_pct])
	return _join_strings(lines, "\n")


func _build_console_summary(snapshot: Dictionary) -> Dictionary:
	var condition_summaries = []
	for condition in snapshot["conditions"]:
		var v2 = condition["v2"]
		var comparison = condition["comparison"]
		condition_summaries.append({
			"difficulty": condition["difficulty"],
			"day": condition["day"],
			"material_l1_delta_pct": comparison["material_l1_delta_pct"],
			"size_l1_delta_pct": comparison["size_l1_delta_pct"],
			"v2_hp_avg": v2["hp_avg"],
			"v2_reward_avg": v2["reward_avg"],
			"v2_sand_avg": v2["sand_avg"],
			"v2_risk_counts": v2["risk_counts"],
		})
	return {
		"ok": bool(snapshot.get("ok", false)),
		"iterations": int(snapshot["iterations"]),
		"report_path": snapshot["report_path"],
		"conditions": condition_summaries,
	}


func _get_top_counts(counts: Dictionary, total: int, limit: int) -> Array:
	var source = []
	for key in counts.keys():
		source.append({
			"id": str(key),
			"count": int(counts[key]),
			"pct": _pct(int(counts[key]), total),
		})
	var result = []
	while not source.is_empty() and result.size() < limit:
		var best_index = 0
		var best_count = int(source[0]["count"])
		for index in range(1, source.size()):
			var count = int(source[index]["count"])
			if count > best_count:
				best_count = count
				best_index = index
		result.append(source[best_index])
		source.remove_at(best_index)
	return result


func _merged_sorted_keys(a: Dictionary, b: Dictionary) -> Array:
	var seen = {}
	for key in a.keys():
		seen[key] = true
	for key in b.keys():
		seen[key] = true
	var keys = seen.keys()
	keys.sort()
	return keys


func _distribution_l1_delta(a: Dictionary, b: Dictionary, a_total: int, b_total: int) -> float:
	var total = 0.0
	for key in _merged_sorted_keys(a, b):
		total += absf(_pct(int(a.get(key, 0)), a_total) - _pct(int(b.get(key, 0)), b_total))
	return total


func _increment_counter(counts: Dictionary, key: String, amount := 1) -> void:
	counts[key] = int(counts.get(key, 0)) + amount


func _pct(count: int, total: int) -> float:
	if total <= 0:
		return 0.0
	return _round_to(float(count) * 100.0 / float(total), 2)


func _round_to(value: float, decimals: int) -> float:
	var factor = pow(10.0, decimals)
	return round(value * factor) / factor


func _sum_array(values: Array) -> float:
	var total = 0.0
	for value in values:
		total += float(value)
	return total


func _is_wide_or_larger(size_group: String) -> bool:
	return size_group == "wide_large" or size_group == "huge" or size_group == "event_like"


func _seed_for(difficulty_id: String, day_number: int, version: int) -> int:
	var difficulty_index = TEST_DIFFICULTIES.find(difficulty_id)
	return 17391 + day_number * 97 + max(difficulty_index, 0) * 1009 + version * 100003


func _join_strings(values: Array, separator: String) -> String:
	var text_values = []
	for value in values:
		text_values.append(str(value))
	return separator.join(text_values)
