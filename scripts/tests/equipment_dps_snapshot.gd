extends SceneTree

const REPORT_PATH := "res://docs/reports/equipment_dps_snapshot.md"

var _failures: Array[String] = []
var _ran := false
var _game_data: Node = null
var _game_state: Node = null


func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	_game_data = get_root().get_node_or_null("GameData")
	_game_state = get_root().get_node_or_null("GameState")
	if _game_data == null or _game_state == null:
		_failures.append("GameData/GameState autoloads should be available")
		_print_and_quit({})
		return true
	_game_state.call("reset_run")
	var snapshot := _build_snapshot()
	_write_report(_build_report(snapshot))
	_print_and_quit(snapshot)
	return true


func _build_snapshot() -> Dictionary:
	var weapons := _build_weapon_rows()
	var protocols := _build_protocol_rows()
	_expect(weapons.size() >= 9, "weapon DPS snapshot should include migrated weapons")
	_expect(protocols.size() >= 15, "protocol DPS snapshot should include migrated protocols")
	return {
		"weapon_rows": weapons,
		"protocol_rows": protocols,
		"weapon_count": weapons.size(),
		"protocol_count": protocols.size(),
		"report_path": REPORT_PATH,
	}


func _build_weapon_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for definition in _game_data.call("get_weapon_definitions"):
		if definition == null:
			continue
		for raw_grade in GameConstants.ATTACK_MODULE_GRADE_ORDER:
			var grade := String(raw_grade)
			var entry := {
				"module_id": String(definition.item_id),
				"grade": grade,
			}
			var damage := int(_game_state.call("get_attack_module_damage", entry))
			var cooldown := float(_game_state.call("get_attack_module_cooldown_duration", entry))
			var hit_count := maxi(int(definition.projectile_count), 1) if String(definition.attack_style) == "shotgun" else 1
			_expect(damage > 0, "%s %s weapon damage should be positive" % [definition.item_id, grade])
			_expect(cooldown > 0.0, "%s %s weapon cooldown should be positive" % [definition.item_id, grade])
			rows.append({
				"item_id": String(definition.item_id),
				"grade": grade,
				"attribute": String(definition.attribute),
				"attack_type": String(definition.attack_type),
				"damage": damage,
				"cooldown": cooldown,
				"hits": hit_count,
				"full_hit_dps": float(damage * hit_count) / cooldown,
			})
	return rows


func _build_protocol_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for definition in _game_data.call("get_drone_protocol_definitions"):
		if definition == null:
			continue
		var entry := {"item_id": String(definition.item_id)}
		var behavior := String(definition.protocol_behavior)
		var cooldown := float(_game_state.call("get_drone_protocol_cooldown_duration", entry))
		var damage := 0
		if behavior in ["auto_attack", "combat_drone", "aura_damage"]:
			damage = int(_game_state.call("get_drone_protocol_damage", entry))
			_expect(damage > 0, "%s protocol damage should be positive" % definition.item_id)
		_expect(cooldown > 0.0, "%s protocol cooldown should be positive" % definition.item_id)
		var effect_values: Dictionary = definition.effect_values
		rows.append({
			"item_id": String(definition.item_id),
			"rank": String(definition.rank),
			"attribute": String(definition.attribute),
			"attack_type": String(definition.attack_type),
			"behavior": behavior,
			"damage": damage,
			"cooldown": cooldown,
			"dps": float(damage) / cooldown if damage > 0 else 0.0,
			"sand_remove_count": int(effect_values.get("sand_remove_count", 0)),
		})
	return rows


func _build_report(snapshot: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("# Equipment DPS Snapshot Report")
	lines.append("")
	lines.append("Date: 2026-05-30")
	lines.append("")
	lines.append("This report uses the Phase 6 weapon and drone protocol runtime getters with no passive or level-up bonuses.")
	lines.append("")
	lines.append("## Weapons")
	lines.append("")
	lines.append("| weapon | grade | attribute | type | damage | cooldown | hits | full-hit DPS |")
	lines.append("|---|---|---|---|---:|---:|---:|---:|")
	for row in snapshot.get("weapon_rows", []):
		lines.append("| %s | %s | %s | %s | %d | %.3f | %d | %.2f |" % [
			row["item_id"],
			row["grade"],
			row["attribute"],
			row["attack_type"],
			row["damage"],
			row["cooldown"],
			row["hits"],
			row["full_hit_dps"],
		])
	lines.append("")
	lines.append("## Drone Protocols")
	lines.append("")
	lines.append("| protocol | rank | attribute | type | behavior | damage | cooldown | DPS | sand removed |")
	lines.append("|---|---|---|---|---|---:|---:|---:|---:|")
	for row in snapshot.get("protocol_rows", []):
		lines.append("| %s | %s | %s | %s | %s | %d | %.3f | %.2f | %d |" % [
			row["item_id"],
			row["rank"],
			row["attribute"],
			row["attack_type"],
			row["behavior"],
			row["damage"],
			row["cooldown"],
			row["dps"],
			row["sand_remove_count"],
		])
	lines.append("")
	lines.append("Support protocols show zero DPS and retain their behavior-specific output.")
	lines.append("")
	return "\n".join(lines)


func _write_report(report: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/reports"))
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file == null:
		_failures.append("Could not write report: %s" % REPORT_PATH)
		return
	file.store_string(report)
	file.close()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _print_and_quit(snapshot: Dictionary) -> void:
	print(JSON.stringify({
		"ok": _failures.is_empty(),
		"failures": _failures,
		"weapon_count": snapshot.get("weapon_count", 0),
		"protocol_count": snapshot.get("protocol_count", 0),
		"report_path": snapshot.get("report_path", REPORT_PATH),
	}, "\t"))
	quit(0 if _failures.is_empty() else 1)
