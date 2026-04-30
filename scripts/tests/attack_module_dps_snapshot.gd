extends SceneTree

const GC = preload("res://scripts/autoload/GameConstants.gd")
const SHOP_ITEM_CATALOG = preload("res://data/items/ShopItemCatalog.tres")
const REPORT_PATH := "res://docs/reports/attack_module_dps_snapshot.md"
const DPS_MODULE_IDS := [
	"sword_module",
	"dagger_module",
	"lance_module",
	"axe_module",
	"greatsword_module",
	"bow_module",
	"scatter_module",
	"pierce_module",
	"laser_module",
]

var _ran := false


func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	var report := _build_report()
	print(report)
	_write_report(report)
	quit(0)
	return true


func _build_report() -> String:
	var modules := _get_attack_modules()
	var lines: Array[String] = []
	lines.append("# Attack Module DPS Snapshot Report")
	lines.append("")
	lines.append("Date: 2026-04-30")
	lines.append("")
	lines.append("This snapshot compares each attack module at each virtual grade, not only the catalog row rank. `base_damage_by_grade` values are treated as fixed data values and are never multiplied by `grade_damage_mult`.")
	lines.append("")
	lines.append("Damage lookup priority:")
	lines.append("")
	lines.append("1. `base_damage_by_grade[current_grade]`")
	lines.append("2. `module_base_damage`")
	lines.append("3. Fallback to `1` with a warning when neither data value exists")
	lines.append("")
	lines.append("`drone_attack_module` is included in the base damage matrix so the structure is represented, but mechanic/drone DPS is excluded from the grade comparison tables.")
	lines.append("")
	_append_damage_matrix(lines, modules)
	for raw_grade in GC.ATTACK_MODULE_GRADE_ORDER:
		_append_grade_dps_table(lines, modules, String(raw_grade))
	_append_growth_table(lines, modules)
	_append_notes(lines, modules)
	return "\n".join(lines)


func _get_attack_modules() -> Array:
	var modules := []
	for raw_definition in SHOP_ITEM_CATALOG.get_attack_module_definitions():
		var definition = raw_definition
		if definition == null:
			continue
		modules.append(definition)
	return modules


func _append_damage_matrix(lines: Array[String], modules: Array) -> void:
	lines.append("## Base Damage By Grade Matrix")
	lines.append("")
	lines.append("| module_id | type | D | C | B | A | S |")
	lines.append("|---|---:|---:|---:|---:|---:|---:|")
	for definition in modules:
		lines.append("| %s | %s | %d | %d | %d | %d | %d |" % [
			String(definition.item_id),
			String(definition.module_type),
			_get_base_damage_for_grade(definition, "D"),
			_get_base_damage_for_grade(definition, "C"),
			_get_base_damage_for_grade(definition, "B"),
			_get_base_damage_for_grade(definition, "A"),
			_get_base_damage_for_grade(definition, "S"),
		])
	lines.append("")


func _append_grade_dps_table(lines: Array[String], modules: Array, grade: String) -> void:
	lines.append("## %s Grade DPS Comparison" % grade)
	lines.append("")
	lines.append("| module | type | base_damage | APS | single_projectile_DPS | full_hit_DPS |")
	lines.append("|---|---:|---:|---:|---:|---:|")
	for definition in modules:
		if not DPS_MODULE_IDS.has(String(definition.item_id)):
			continue
		var base_damage := _get_base_damage_for_grade(definition, grade)
		var aps := _get_aps(definition, grade)
		var projectile_count := _get_projectile_count(definition)
		var single_dps := aps * float(base_damage)
		var full_hit_dps := single_dps * float(projectile_count)
		lines.append("| %s %s | %s | %d | %.3f | %.2f | %.2f |" % [
			_get_short_module_label(definition),
			grade,
			String(definition.module_type),
			base_damage,
			aps,
			single_dps,
			full_hit_dps,
		])
	lines.append("")


func _append_growth_table(lines: Array[String], modules: Array) -> void:
	lines.append("## Grade Growth Table")
	lines.append("")
	lines.append("| module_id | D->C | C->B | B->A | A->S |")
	lines.append("|---|---:|---:|---:|---:|")
	for definition in modules:
		lines.append("| %s | %s | %s | %s | %s |" % [
			String(definition.item_id),
			_get_growth_text(definition, "D", "C"),
			_get_growth_text(definition, "C", "B"),
			_get_growth_text(definition, "B", "A"),
			_get_growth_text(definition, "A", "S"),
		])
	lines.append("")


func _append_notes(lines: Array[String], modules: Array) -> void:
	var melee_dps := []
	var ranged_dps := []
	for definition in modules:
		if not DPS_MODULE_IDS.has(String(definition.item_id)):
			continue
		var dps := _get_aps(definition, "D") * float(_get_base_damage_for_grade(definition, "D")) * float(_get_projectile_count(definition))
		if definition.module_type == &"melee":
			melee_dps.append(dps)
		elif definition.module_type == &"ranged":
			ranged_dps.append(dps)
	lines.append("## Readout")
	lines.append("")
	lines.append("- The previous row-rank comparison was invalid because it compared different module shapes at different grades instead of comparing all module shapes at the same grade.")
	lines.append("- Same-grade comparison is now available for D/C/B/A/S across sword, dagger, lance, axe, greatsword, bow, scatter, pierce, and laser.")
	lines.append("- Scatter reports both `single_projectile_DPS` and `full_hit_DPS`; the full-hit column assumes all projectiles connect.")
	lines.append("- D-grade melee average full-hit DPS: %.2f." % _average(melee_dps))
	lines.append("- D-grade ranged average full-hit DPS: %.2f." % _average(ranged_dps))
	lines.append("")


func _get_base_damage_for_grade(definition, grade: String) -> int:
	var grade_key := grade.strip_edges().to_upper()
	var grade_map: Dictionary = definition.base_damage_by_grade
	if grade_map.has(grade_key):
		var grade_damage := int(grade_map[grade_key])
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


func _get_projectile_count(definition) -> int:
	if String(definition.item_id) == "scatter_module":
		return maxi(int(definition.projectile_count), 1)
	return 1


func _get_short_module_label(definition) -> String:
	return String(definition.item_id).replace("_attack_module", "").replace("_module", "")


func _get_growth_text(definition, from_grade: String, to_grade: String) -> String:
	var from_damage := _get_base_damage_for_grade(definition, from_grade)
	var to_damage := _get_base_damage_for_grade(definition, to_grade)
	if from_damage <= 0:
		return "n/a"
	var ratio := (float(to_damage) / float(from_damage) - 1.0) * 100.0
	return "%+.1f%%" % ratio


func _average(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value in values:
		total += float(value)
	return total / float(values.size())


func _write_report(report: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/reports"))
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write report: %s" % REPORT_PATH)
		return
	file.store_string(report)
	file.close()
