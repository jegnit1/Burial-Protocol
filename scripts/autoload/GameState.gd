extends Node

signal gold_changed(value: int)
signal health_changed(current: int, maximum: int)
signal status_text_changed(text: String)
signal selected_character_changed(character_id: String, character_name: String, best_record: String)
signal xp_changed(current: int, next_level_req: int)
signal level_changed(level: int)
signal level_up_ready()
signal attack_module_changed(module_id: StringName)
signal owned_attack_modules_changed(module_ids: PackedStringArray)
signal run_items_changed()
signal shop_reroll_count_changed(count: int, next_cost: int)
signal shop_locked_slots_changed(locked_slots: Dictionary)

const SAVE_FILE_PATH := "user://profile.save"
const SAVE_VERSION := 1
const ATTACK_MODULE_STYLE_RESOLVER := preload("res://scripts/data/AttackModuleStyleResolver.gd")

const DEFAULT_CURRENCIES := {
	"gear": 0,
	"plywood": 0,
	"lubricant": 0,
	"iron_ore": 0,
	"power": 0,
}

const DEFAULT_SETTINGS := {
	"master_volume": 1.0,
	"fullscreen": false,
}

const DEFAULT_GROWTH := {
	"attack_level": 0,
	"mining_level": 0,
	"defense_level": 0,
	"mobility_level": 0,
}

const CHARACTER_SLOTS := [
	{
		"id": "default_worker",
		"display_name": "기본 일꾼",
		"default_unlocked": true,
		"unlock_text": "처음부터 사용 가능.",
	},
	{
		"id": "locked_slot_01",
		"display_name": "잠긴 슬롯 01",
		"default_unlocked": false,
		"unlock_text": "해금 조건 미정 01",
	},
	{
		"id": "locked_slot_02",
		"display_name": "잠긴 슬롯 02",
		"default_unlocked": false,
		"unlock_text": "해금 조건 미정 02",
	},
	{
		"id": "locked_slot_03",
		"display_name": "잠긴 슬롯 03",
		"default_unlocked": false,
		"unlock_text": "해금 조건 미정 03",
	},
	{
		"id": "locked_slot_04",
		"display_name": "잠긴 슬롯 04",
		"default_unlocked": false,
		"unlock_text": "해금 조건 미정 04",
	},
	{
		"id": "locked_slot_05",
		"display_name": "잠긴 슬롯 05",
		"default_unlocked": false,
		"unlock_text": "해금 조건 미정 05",
	},
	{
		"id": "locked_slot_06",
		"display_name": "잠긴 슬롯 06",
		"default_unlocked": false,
		"unlock_text": "해금 조건 미정 06",
	},
	{
		"id": "locked_slot_07",
		"display_name": "잠긴 슬롯 07",
		"default_unlocked": false,
		"unlock_text": "해금 조건 미정 07",
	},
	{
		"id": "locked_slot_08",
		"display_name": "잠긴 슬롯 08",
		"default_unlocked": false,
		"unlock_text": "해금 조건 미정 08",
	},
	{
		"id": "locked_slot_09",
		"display_name": "잠긴 슬롯 09",
		"default_unlocked": false,
		"unlock_text": "해금 조건 미정 09",
	},
]

var gold := 0
var player_health := GameConstants.PLAYER_MAX_HEALTH
var status_text := "Phase 0 초기화 완료."
var latest_run_record := "아직 런을 진행하지 않았습니다."
var latest_run_reason_id := "none"
var latest_run_reason_label := "결과 없음"
var latest_run_stage_reached := 0
var latest_run_difficulty_name := "일반"
var latest_run_character_name := "기본 일꾼"
var selected_character_id := "default_worker"
var selected_character_name := "기본 일꾼"
var best_record_summary := "기록 없음"
var last_selected_difficulty_id := "normal"
var last_selected_difficulty_name := "일반"
var current_run_character_id := "default_worker"
var current_run_character_name := "기본 일꾼"
var current_run_difficulty_id := "normal"
var current_run_difficulty_name := "일반"
var current_run_stage_reached := 1
var current_day := 1
var day_time_remaining := 0.0
var run_cleared := false
var current_shop_reroll_count := 0
var current_shop_locked_slots: Dictionary = {}

# 경험치 및 레벨업 상태
var player_level := 1
var player_current_xp := 0
var player_next_level_xp := 50
var pending_sand_removed_cells_for_xp := 0

# 런타임 성장 보너스
# Deprecated: kept for old saves/scripts. New combat damage uses run_bonus_damage_percent instead.
var run_bonus_attack_damage := 0
var run_bonus_damage_percent := 0.0
var run_bonus_melee_attack_damage := 0
var run_bonus_ranged_attack_damage := 0
var run_bonus_move_speed := 0.0
var run_bonus_max_hp := 0
var run_attack_speed_mult := 1.0
var run_bonus_mining_damage := 0
var run_mining_speed_mult := 1.0
var run_bonus_crit_chance := 0.0
var run_bonus_hp_regen := 0.0
var run_bonus_defense := 0
var run_bonus_luck := 0.0
var run_bonus_interest_rate := 0.0
var run_attack_range_mult := 1.0
var run_mining_range_mult := 1.0
var run_bonus_jump_power := 0.0
var run_move_speed_mult := 1.0
var run_jump_power_mult := 1.0
var run_bonus_max_weight := 0
var run_bonus_battery_recovery := 0.0
var owned_attack_module_ids: PackedStringArray = PackedStringArray()
var equipped_attack_module_id: StringName = StringName()
var equipped_attack_modules: Array[Dictionary] = []
var attack_module_instance_sequence := 0
var attack_module_runtime_state: Dictionary = {}
var owned_function_module_ids: PackedStringArray = PackedStringArray()
var owned_enhance_module_counts: Dictionary = {}
var current_run_items: PackedStringArray = PackedStringArray()
var current_run_effects: Dictionary = {}

var cleared_difficulty_ids: PackedStringArray = PackedStringArray()
var persistent_currencies: Dictionary = {}
var settings_data: Dictionary = {}
var growth_data: Dictionary = {}
var unlocked_character_ids: PackedStringArray = PackedStringArray()
var unlocked_achievement_ids: PackedStringArray = PackedStringArray()
var best_records_by_character: Dictionary = {}


func _ready() -> void:
	day_time_remaining = GameData.get_day_duration(current_day)
	load_profile()
	_emit_initial_state()


func reset_run() -> void:
	gold = 0
	player_health = GameConstants.PLAYER_MAX_HEALTH
	current_run_stage_reached = 1
	current_day = 1
	day_time_remaining = GameData.get_day_duration(current_day)
	run_cleared = false
	reset_shop_reroll_count()
	
	player_level = 1
	player_current_xp = 0
	player_next_level_xp = 50
	pending_sand_removed_cells_for_xp = 0
	run_bonus_attack_damage = 0
	run_bonus_damage_percent = 0.0
	run_bonus_melee_attack_damage = 0
	run_bonus_ranged_attack_damage = 0
	run_bonus_move_speed = 0.0
	run_bonus_max_hp = 0
	run_attack_speed_mult = 1.0
	run_bonus_mining_damage = 0
	run_mining_speed_mult = 1.0
	run_bonus_crit_chance = 0.0
	run_bonus_hp_regen = 0.0
	run_bonus_defense = 0
	run_bonus_luck = 0.0
	run_bonus_interest_rate = 0.0
	run_attack_range_mult = 1.0
	run_mining_range_mult = 1.0
	run_bonus_jump_power = 0.0
	run_move_speed_mult = 1.0
	run_jump_power_mult = 1.0
	run_bonus_max_weight = 0
	run_bonus_battery_recovery = 0.0
	_reset_run_shop_items()
	_reset_run_attack_modules()
	
	status_text = Locale.ltr("status_run_start") % [
		current_run_character_name,
		current_run_difficulty_name,
	]
	gold_changed.emit(gold)
	xp_changed.emit(player_current_xp, player_next_level_xp)
	level_changed.emit(player_level)
	health_changed.emit(player_health, get_player_max_health())
	status_text_changed.emit(status_text)
	run_items_changed.emit()


func finish_temporary_run(reason_id: String = "run_end", reason_label: String = "Run Ended") -> void:
	latest_run_reason_id = reason_id
	latest_run_reason_label = reason_label
	latest_run_stage_reached = current_run_stage_reached
	latest_run_difficulty_name = current_run_difficulty_name
	latest_run_character_name = current_run_character_name
	if run_cleared:
		mark_difficulty_cleared(current_run_difficulty_id)
	_update_best_record(current_run_character_id, current_run_difficulty_id, current_run_stage_reached)
	latest_run_record = Locale.ltr("status_run_record") % [
		current_run_character_name,
		current_run_difficulty_name,
		current_run_stage_reached,
		gold,
		player_health,
		get_player_max_health(),
	]
	_refresh_selected_character_summary()
	save_profile()


func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)


func can_afford_gold(amount: int) -> bool:
	return gold >= amount


func try_spend_gold(amount: int) -> bool:
	if amount < 0:
		return false
	if not can_afford_gold(amount):
		return false
	gold -= amount
	gold_changed.emit(gold)
	return true


func reset_shop_reroll_count() -> void:
	current_shop_reroll_count = 0
	shop_reroll_count_changed.emit(current_shop_reroll_count, get_current_shop_reroll_cost())


func reset_shop_locks() -> void:
	current_shop_locked_slots = {}
	shop_locked_slots_changed.emit(get_current_shop_locked_slots())


func get_current_shop_locked_slots() -> Dictionary:
	return current_shop_locked_slots.duplicate(true)


func is_shop_slot_locked(slot_index: int) -> bool:
	return current_shop_locked_slots.has(slot_index)


func get_shop_locked_item_id(slot_index: int) -> StringName:
	var raw_value = current_shop_locked_slots.get(slot_index, "")
	if raw_value is bool:
		return StringName()
	var item_key := String(raw_value)
	if item_key.is_empty():
		return StringName()
	return StringName(item_key)


func set_shop_slot_locked(slot_index: int, locked: bool, item_id: StringName = StringName()) -> void:
	if slot_index < 0 or slot_index >= GameConstants.DAY_SHOP_ITEM_COUNT:
		return
	if locked:
		var item_key := String(item_id)
		current_shop_locked_slots[slot_index] = item_key if not item_key.is_empty() else true
	else:
		current_shop_locked_slots.erase(slot_index)
	shop_locked_slots_changed.emit(get_current_shop_locked_slots())


func toggle_shop_slot_locked(slot_index: int, item_id: StringName = StringName()) -> bool:
	var locked := not is_shop_slot_locked(slot_index)
	set_shop_slot_locked(slot_index, locked, item_id)
	return locked


func remove_shop_slot_lock_and_shift(slot_index: int) -> void:
	if slot_index < 0:
		return
	var shifted_locks: Dictionary = {}
	for raw_key in current_shop_locked_slots.keys():
		var locked_index := int(raw_key)
		var locked_value = current_shop_locked_slots[raw_key]
		if locked_index == slot_index:
			continue
		if locked_index > slot_index:
			locked_index -= 1
		if locked_index >= 0 and locked_index < GameConstants.DAY_SHOP_ITEM_COUNT:
			shifted_locks[locked_index] = locked_value
	current_shop_locked_slots = shifted_locks
	shop_locked_slots_changed.emit(get_current_shop_locked_slots())


func get_current_shop_reroll_cost() -> int:
	return GameConstants.get_shop_reroll_cost(current_shop_reroll_count)


func can_afford_shop_reroll() -> bool:
	return can_afford_gold(get_current_shop_reroll_cost())


func try_purchase_shop_reroll() -> Dictionary:
	var cost := get_current_shop_reroll_cost()
	if not try_spend_gold(cost):
		return {
			"ok": false,
			"reason": "insufficient_gold",
			"cost": cost,
			"reroll_count": current_shop_reroll_count,
		}
	current_shop_reroll_count += 1
	shop_reroll_count_changed.emit(current_shop_reroll_count, get_current_shop_reroll_cost())
	return {
		"ok": true,
		"reason": "rerolled",
		"cost": cost,
		"reroll_count": current_shop_reroll_count,
		"next_cost": get_current_shop_reroll_cost(),
	}


func damage_player(amount: int) -> int:
	if amount <= 0:
		return 0
	var applied_damage := maxi(amount - get_defense(), 1)
	player_health = max(player_health - applied_damage, 0)
	health_changed.emit(player_health, get_player_max_health())
	return applied_damage


func heal_player(amount: int) -> void:
	if amount <= 0 or player_health <= 0:
		return
	player_health = min(player_health + amount, get_player_max_health())
	health_changed.emit(player_health, get_player_max_health())


func get_player_max_health() -> int:
	return GameConstants.PLAYER_MAX_HEALTH + run_bonus_max_hp


func get_attack_damage() -> int:
	var entries := get_equipped_attack_module_entries()
	if entries.is_empty():
		return maxi(int(floor(float(get_base_attack_damage()) * get_global_damage_multiplier())), 1)
	return get_attack_module_damage(entries[0])


func get_attack_cooldown_duration() -> float:
	var entries := get_equipped_attack_module_entries()
	if entries.is_empty():
		return GameConstants.PLAYER_ATTACK_COOLDOWN * run_attack_speed_mult
	return get_attack_module_cooldown_duration(entries[0])


func get_attacks_per_second() -> float:
	var cooldown := get_attack_cooldown_duration()
	if cooldown <= 0.0:
		return 0.0
	return 1.0 / cooldown


func get_base_attack_damage() -> int:
	return maxi(GameConstants.PLAYER_ATTACK_DAMAGE + run_bonus_attack_damage, 1)


func get_melee_base_attack_damage() -> int:
	return maxi(GameConstants.PLAYER_ATTACK_DAMAGE + run_bonus_melee_attack_damage, 1)


func get_ranged_base_attack_damage() -> int:
	return maxi(GameConstants.PLAYER_ATTACK_DAMAGE + run_bonus_ranged_attack_damage, 1)


func get_melee_attack_damage_flat() -> int:
	return run_bonus_melee_attack_damage


func get_ranged_attack_damage_flat() -> int:
	return run_bonus_ranged_attack_damage


func get_damage_percent() -> float:
	var legacy_flat_as_percent := get_stat_query_effect_value("attack_damage_flat") * 0.01
	return run_bonus_damage_percent \
		+ get_stat_query_effect_value("damage_percent") \
		+ get_stat_query_effect_value("attack_damage_percent") \
		+ legacy_flat_as_percent


func get_global_damage_multiplier() -> float:
	return maxf(1.0 + get_damage_percent(), 0.0)


func get_damage_percent_display() -> int:
	return int(round(get_damage_percent() * 100.0))


func get_module_base_damage(module_definition) -> int:
	return get_attack_module_base_damage_for_grade(module_definition, "D")


func get_attack_module_base_damage_for_grade(module_definition, grade: String) -> int:
	if module_definition == null:
		return get_base_attack_damage()
	var grade_damage := _get_attack_module_base_damage_from_grade_map(module_definition, grade)
	if grade_damage > 0:
		return grade_damage
	var explicit_base_damage := _get_explicit_module_base_damage(module_definition)
	if explicit_base_damage > 0:
		return explicit_base_damage
	push_warning("Attack module '%s' has no base_damage_by_grade value for grade '%s' and no module_base_damage; falling back to 1." % [
		String(_get_definition_item_id(module_definition)),
		grade,
	])
	return 1


func _get_attack_module_base_damage_from_grade_map(module_definition, grade: String) -> int:
	var grade_map := _get_definition_base_damage_by_grade(module_definition)
	if grade_map.is_empty():
		return 0
	var grade_key := grade.strip_edges().to_upper()
	if grade_key.is_empty():
		grade_key = "D"
	if not grade_map.has(grade_key):
		return 0
	return maxi(int(grade_map[grade_key]), 0)


func _get_definition_base_damage_by_grade(module_definition) -> Dictionary:
	if module_definition == null:
		return {}
	var raw_map = {}
	if module_definition is Dictionary:
		raw_map = module_definition.get("base_damage_by_grade", {})
	else:
		raw_map = module_definition.base_damage_by_grade
	if not raw_map is Dictionary:
		return {}
	var raw_dictionary: Dictionary = raw_map
	var result: Dictionary = {}
	for raw_grade in raw_dictionary.keys():
		var grade := String(raw_grade).strip_edges().to_upper()
		if grade.is_empty():
			continue
		var damage := int(raw_dictionary[raw_grade])
		if damage <= 0:
			continue
		result[grade] = damage
	return result


func _get_explicit_module_base_damage(module_definition) -> int:
	if module_definition == null:
		return 0
	if module_definition is Dictionary:
		return int(module_definition.get("module_base_damage", 0))
	return int(module_definition.module_base_damage)


func _get_definition_item_id(module_definition) -> StringName:
	if module_definition == null:
		return StringName()
	if module_definition is Dictionary:
		return StringName(String(module_definition.get("item_id", "")))
	return module_definition.item_id


func get_attack_base_damage_for_module(module_entry: Dictionary) -> int:
	var module_definition = get_attack_module_definition_from_entry(module_entry)
	if module_definition == null:
		return get_base_attack_damage()
	var grade := String(module_entry.get("grade", module_definition.rank))
	var module_base_damage := get_attack_module_base_damage_for_grade(module_definition, grade)
	match String(module_definition.module_type):
		"melee":
			return maxi(module_base_damage + get_melee_attack_damage_flat(), 1)
		"ranged":
			return maxi(module_base_damage + get_ranged_attack_damage_flat(), 1)
		"mechanic":
			return module_base_damage
		_:
			return module_base_damage


func get_attack_module_damage(module_entry: Dictionary) -> int:
	var module_definition = get_attack_module_definition_from_entry(module_entry)
	if module_definition == null:
		return maxi(int(floor(float(get_base_attack_damage()) * get_global_damage_multiplier())), 1)
	var base_damage := get_attack_base_damage_for_module(module_entry)
	return maxi(int(floor(float(base_damage) * get_global_damage_multiplier())), 1)


func get_mechanic_attack_module_damage(module_entry: Dictionary) -> int:
	var module_definition = get_attack_module_definition_from_entry(module_entry)
	if module_definition == null:
		return maxi(int(floor(float(get_base_attack_damage()) * get_global_damage_multiplier())), 1)
	var grade := String(module_entry.get("grade", module_definition.rank))
	var base_damage := get_attack_module_base_damage_for_grade(module_definition, grade)
	return maxi(int(floor(float(base_damage) * get_global_damage_multiplier())), 1)


func get_attack_module_cooldown_duration(module_entry: Dictionary) -> float:
	var module_definition = get_attack_module_definition_from_entry(module_entry)
	var module_speed := 1.0
	if module_definition != null:
		module_speed = maxf(module_definition.attack_speed_multiplier, 0.01)
		module_speed *= _get_attack_module_grade_multiplier(
			String(module_entry.get("grade", module_definition.rank)),
			GameConstants.ATTACK_MODULE_GRADE_SPEED_MULTIPLIERS
		)
	var module_type := _get_attack_module_type(module_entry)
	if module_type == &"mechanic":
		return GameConstants.PLAYER_ATTACK_COOLDOWN / module_speed
	return (GameConstants.PLAYER_ATTACK_COOLDOWN * run_attack_speed_mult) / module_speed


func get_attack_range_multiplier() -> float:
	return GameConstants.PLAYER_ATTACK_RANGE_MULTIPLIER * run_attack_range_mult


func get_equipped_attack_module_id() -> StringName:
	if not equipped_attack_modules.is_empty():
		return StringName(String(equipped_attack_modules[0].get("module_id", "")))
	if equipped_attack_module_id != StringName():
		return equipped_attack_module_id
	return GameData.get_default_attack_module_id()


func get_owned_attack_module_ids() -> PackedStringArray:
	return owned_attack_module_ids.duplicate()


func is_attack_module_owned(module_id: StringName) -> bool:
	return owned_attack_module_ids.has(String(module_id))


func get_equipped_attack_module_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for raw_entry in equipped_attack_modules:
		entries.append(raw_entry.duplicate(true))
	return entries


func get_input_attack_module_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for raw_entry in equipped_attack_modules:
		var entry := raw_entry.duplicate(true)
		var module_type := _get_attack_module_type(entry)
		if module_type == &"melee" or module_type == &"ranged":
			entries.append(entry)
	return entries


func get_mechanic_attack_module_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for raw_entry in equipped_attack_modules:
		var entry := raw_entry.duplicate(true)
		if _get_attack_module_type(entry) == &"mechanic":
			entries.append(entry)
	return entries


func get_attack_module_definition_from_entry(module_entry: Dictionary):
	return GameData.get_attack_module_definition(StringName(String(module_entry.get("module_id", ""))))


func get_attack_module_entry_label(module_entry: Dictionary) -> String:
	var module_definition = get_attack_module_definition_from_entry(module_entry)
	var module_name := String(module_entry.get("module_id", "unknown"))
	var fallback_grade := "D"
	if module_definition != null:
		module_name = module_definition.display_name
		fallback_grade = String(module_definition.rank)
	return "%s %s" % [module_name, String(module_entry.get("grade", fallback_grade))]


func get_equipped_attack_module_definition():
	return GameData.get_attack_module_definition(get_equipped_attack_module_id())


func get_equipped_attack_module_display_name() -> String:
	var module_definition = get_equipped_attack_module_definition()
	if module_definition == null:
		return "없음"
	return module_definition.display_name


func get_attack_shape_size_units() -> Vector2:
	var entries := get_equipped_attack_module_entries()
	if entries.is_empty():
		return Vector2.ONE * get_attack_range_multiplier()
	return get_attack_module_shape_size_units(entries[0])


func get_attack_module_shape_size_units(module_entry: Dictionary) -> Vector2:
	return _get_attack_module_shape_size_units_with_range_multiplier(module_entry, get_attack_range_multiplier())


func _get_attack_module_shape_size_units_with_range_multiplier(module_entry: Dictionary, stat_range_multiplier: float) -> Vector2:
	var module_definition = get_attack_module_definition_from_entry(module_entry)
	if module_definition == null:
		return Vector2.ONE * stat_range_multiplier
	var grade_multiplier := _get_attack_module_grade_multiplier(
		String(module_entry.get("grade", module_definition.rank)),
		GameConstants.ATTACK_MODULE_GRADE_RANGE_MULTIPLIERS
	)
	var module_type := _get_attack_module_type(module_entry)
	if module_type == &"melee":
		var base_shape_units := ATTACK_MODULE_STYLE_RESOLVER.get_base_shape_units(module_definition)
		var range_bonus := maxf(stat_range_multiplier * grade_multiplier - 1.0, 0.0)
		return Vector2(
			base_shape_units.x + range_bonus * maxf(module_definition.range_growth_width_scale, 0.0),
			base_shape_units.y + range_bonus * maxf(module_definition.range_growth_height_scale, 0.0)
		)
	if module_type == &"ranged":
		var range_bonus := maxf(stat_range_multiplier * grade_multiplier - 1.0, 0.0)
		var range_scale := 1.0 + range_bonus * maxf(module_definition.range_growth_scale, 0.0)
		return Vector2(
			ATTACK_MODULE_STYLE_RESOLVER.get_ranged_range_units(module_definition) * range_scale,
			maxf(module_definition.range_height_u, 0.0)
		)
	var final_range_multiplier := 1.0 if module_type == &"mechanic" else stat_range_multiplier
	return Vector2(module_definition.range_width_u, module_definition.range_height_u) * final_range_multiplier * grade_multiplier


func get_attack_module_style_snapshot(module_entry: Dictionary, bonus_range_multiplier: float = 1.0) -> Dictionary:
	var module_definition = get_attack_module_definition_from_entry(module_entry)
	if module_definition == null:
		return {}
	var current_size := get_attack_module_shape_size_units(module_entry)
	var bonus_stat_range_multiplier := get_attack_range_multiplier() * maxf(bonus_range_multiplier, 0.0)
	var bonus_size := _get_attack_module_shape_size_units_with_range_multiplier(module_entry, bonus_stat_range_multiplier)
	var base_shape_units := ATTACK_MODULE_STYLE_RESOLVER.get_base_shape_units(module_definition)
	var projectile_visual_size := ATTACK_MODULE_STYLE_RESOLVER.get_ranged_projectile_visual_size(module_definition)
	return {
		"module_id": String(module_definition.module_id),
		"module_type": String(module_definition.module_type),
		"attack_style": String(ATTACK_MODULE_STYLE_RESOLVER.get_attack_style(module_definition)),
		"effect_style": String(ATTACK_MODULE_STYLE_RESOLVER.get_effect_style(module_definition)),
		"hit_shape": String(module_definition.hit_shape),
		"base_shape_units": {"x": base_shape_units.x, "y": base_shape_units.y},
		"range_growth_width_scale": module_definition.range_growth_width_scale,
		"range_growth_height_scale": module_definition.range_growth_height_scale,
		"range_units": ATTACK_MODULE_STYLE_RESOLVER.get_ranged_range_units(module_definition),
		"range_growth_scale": module_definition.range_growth_scale,
		"projectile_count": module_definition.projectile_count,
		"spread_angle": module_definition.spread_angle,
		"pierce_count": module_definition.pierce_count,
		"is_hitscan": module_definition.is_hitscan,
		"projectile_visual_size": {
			"x": projectile_visual_size.x,
			"y": projectile_visual_size.y,
		},
		"current_shape_units": {"x": current_size.x, "y": current_size.y},
		"bonus_shape_units": {"x": bonus_size.x, "y": bonus_size.y},
	}


func get_attack_shape_size_pixels() -> Vector2:
	return get_attack_shape_size_units() * float(GameConstants.CELL_SIZE)


func get_attack_module_shape_size_pixels(module_entry: Dictionary) -> Vector2:
	return get_attack_module_shape_size_units(module_entry) * float(GameConstants.CELL_SIZE)


func get_owned_attack_module_definitions() -> Array:
	var definitions: Array = []
	for owned_module in owned_attack_module_ids:
		var module_id: StringName = StringName(owned_module)
		var definition = GameData.get_attack_module_definition(module_id)
		if definition == null:
			continue
		definitions.append(definition)
	return definitions


func get_attack_module_shop_snapshot() -> Dictionary:
	var module_entries: Array[Dictionary] = []
	for raw_definition in GameData.get_attack_module_definitions():
		var definition = raw_definition
		if definition == null:
			continue
		module_entries.append({
			"module_id": String(definition.module_id),
			"display_name": String(definition.display_name),
			"shop_price_gold": int(definition.shop_price_gold),
			"owned": is_attack_module_owned(definition.module_id),
			"equipped": definition.module_id == get_equipped_attack_module_id(),
		})
	return {
		"equipped_module_id": String(get_equipped_attack_module_id()),
		"equipped_module_name": get_equipped_attack_module_display_name(),
		"owned_module_ids": Array(owned_attack_module_ids),
		"module_entries": module_entries,
	}


func get_shop_roll_context() -> Dictionary:
	return {
		"stage_number": current_day,
		"current_day": current_day,
		"owned_attack_module_ids": get_owned_attack_module_ids(),
		"owned_function_module_ids": get_owned_function_module_ids(),
		"luck": get_luck(),
		"shop_locked_slots": get_current_shop_locked_slots(),
	}


func get_owned_function_module_ids() -> PackedStringArray:
	return owned_function_module_ids.duplicate()


func get_owned_enhance_module_counts() -> Dictionary:
	return owned_enhance_module_counts.duplicate(true)


func get_enhance_module_stack_count(item_id: StringName) -> int:
	return int(owned_enhance_module_counts.get(String(item_id), 0))


func is_function_module_owned(item_id: StringName) -> bool:
	return owned_function_module_ids.has(String(item_id))


func get_current_run_effect_entries(effect_type: StringName = StringName()) -> Array[Dictionary]:
	if effect_type == StringName():
		var merged: Array[Dictionary] = []
		for raw_entries in current_run_effects.values():
			for raw_entry in raw_entries:
				var entry: Dictionary = raw_entry
				merged.append(entry.duplicate(true))
		return merged
	if not current_run_effects.has(effect_type):
		return []
	var entries: Array[Dictionary] = []
	for raw_entry in current_run_effects[effect_type]:
		var entry: Dictionary = raw_entry
		entries.append(entry.duplicate(true))
	return entries


func get_stat_query_effect_value(effect_key: String, context: Dictionary = {}) -> float:
	var total := 0.0
	for raw_entry in get_current_run_effect_entries(&"conditional_stat_bonus"):
		var entry: Dictionary = raw_entry
		if String(entry.get("apply_timing", "")) != "stat_query":
			continue
		if not _are_item_conditions_met(_get_condition_entries(entry), context):
			continue
		for effect in _get_effect_entries(entry):
			if String(effect.get("type", "")) != effect_key:
				continue
			total += float(effect.get("value", 0.0))
	return total


func get_effective_shop_item_price(definition: Dictionary) -> int:
	var raw_price := int(definition.get("price_gold", 0))
	if raw_price > 0:
		return raw_price
	var rank := String(definition.get("rank", "D"))
	return int(GameConstants.SHOP_ITEM_RANK_FALLBACK_PRICES.get(rank, 15))


func get_day_shop_snapshot(item_ids: PackedStringArray) -> Dictionary:
	var entries: Array[Dictionary] = []
	for slot_index in range(item_ids.size()):
		var item_id := StringName(item_ids[slot_index])
		var definition := GameData.get_shop_item_definition(item_id)
		if definition.is_empty():
			continue
		entries.append(_build_shop_item_snapshot(definition, slot_index))
	return {
		"gold": gold,
		"equipped_attack_module_id": String(get_equipped_attack_module_id()),
		"equipped_attack_module_name": get_equipped_attack_module_display_name(),
		"owned_attack_module_ids": Array(owned_attack_module_ids),
		"owned_function_module_ids": Array(owned_function_module_ids),
		"owned_enhance_module_counts": owned_enhance_module_counts.duplicate(true),
		"current_run_effects": current_run_effects.duplicate(true),
		"shop_reroll_count": current_shop_reroll_count,
		"shop_reroll_cost": get_current_shop_reroll_cost(),
		"can_afford_shop_reroll": can_afford_shop_reroll(),
		"shop_locked_slots": get_current_shop_locked_slots(),
		"item_entries": entries,
	}


func purchase_shop_item(item_id: StringName) -> Dictionary:
	var definition := GameData.get_shop_item_definition(item_id)
	if definition.is_empty():
		return {"ok": false, "reason": "missing_definition"}
	var category := StringName(String(definition.get("item_category", "")))
	var price_gold := get_effective_shop_item_price(definition)
	if category == &"function_module" and is_function_module_owned(item_id):
		return {"ok": false, "reason": "already_owned"}
	if category != &"attack_module" and category != &"function_module" and category != &"enhance_module":
		return {"ok": false, "reason": "unsupported_category"}
	if category == &"attack_module":
		var equip_result := can_add_or_synthesize_attack_module(item_id)
		if not bool(equip_result.get("ok", false)):
			return equip_result
	if not try_spend_gold(price_gold):
		return {"ok": false, "reason": "insufficient_gold"}
	match String(category):
		"attack_module":
			return _register_owned_attack_module(item_id)
		"function_module":
			_register_function_module_purchase(definition)
		"enhance_module":
			_register_enhance_module_purchase(definition)
	run_items_changed.emit()
	return {"ok": true, "reason": "purchased", "category": String(category)}


func grant_attack_module(module_id: StringName, auto_equip := false) -> bool:
	var module_definition = GameData.get_attack_module_definition(module_id)
	if module_definition == null:
		return false
	owned_attack_module_ids.append(String(module_id))
	owned_attack_modules_changed.emit(get_owned_attack_module_ids())
	if auto_equip:
		var entry := _make_attack_module_entry(module_id, String(module_definition.rank))
		equipped_attack_modules.append(entry)
		_sync_primary_equipped_attack_module_id()
		attack_module_changed.emit(equipped_attack_module_id)
		run_items_changed.emit()
	return true


func equip_attack_module(module_id: StringName) -> bool:
	# 다중 장착 체계에서는 상점 구매가 즉시 장착을 담당한다.
	run_items_changed.emit()
	return is_attack_module_owned(module_id)


func can_add_or_synthesize_attack_module(module_id: StringName) -> Dictionary:
	var module_definition = GameData.get_attack_module_definition(module_id)
	if module_definition == null:
		return {"ok": false, "reason": "missing_definition"}
	var grade := String(module_definition.rank)
	if equipped_attack_modules.size() < GameConstants.ATTACK_MODULE_MAX_EQUIPPED:
		return {"ok": true, "mode": "add"}
	var merge_index := _find_first_synthesis_candidate(module_id, grade)
	if merge_index >= 0:
		var next_grade := _get_next_attack_module_grade(grade)
		if next_grade.is_empty():
			return {"ok": false, "reason": "no_next_grade"}
		return {"ok": true, "mode": "synthesize", "target_index": merge_index, "next_grade": next_grade}
	return {"ok": false, "reason": "attack_module_slots_full"}


func get_critical_chance_ratio() -> float:
	return clampf(GameConstants.PLAYER_BASE_CRIT_CHANCE + run_bonus_crit_chance, 0.0, 1.0)


func get_critical_chance_percent() -> float:
	return get_critical_chance_ratio() * 100.0


func get_critical_damage_multiplier() -> float:
	return GameConstants.PLAYER_CRIT_DAMAGE_MULTIPLIER


func get_critical_damage_percent() -> int:
	return int(round(get_critical_damage_multiplier() * 100.0))


func get_defense() -> int:
	return GameConstants.PLAYER_BASE_DEFENSE + run_bonus_defense


func get_hp_regen_stat() -> float:
	return GameConstants.PLAYER_BASE_HP_REGEN + GameConstants.PLAYER_TEST_HP_REGEN_BONUS + run_bonus_hp_regen


func get_hp_regen_interval() -> float:
	var regen_value := get_hp_regen_stat()
	if regen_value <= 0.0:
		return INF
	return 5.0 / (1.0 + (regen_value - 1.0) / 2.25)


func get_move_speed() -> float:
	return (GameConstants.PLAYER_MOVE_SPEED + run_bonus_move_speed) * run_move_speed_mult


func get_air_move_speed() -> float:
	return (GameConstants.PLAYER_AIR_SPEED + run_bonus_move_speed) * run_move_speed_mult


func get_jump_speed() -> float:
	var jump_power := (absf(GameConstants.PLAYER_JUMP_SPEED) + run_bonus_jump_power) * run_jump_power_mult
	return -jump_power


func get_jump_power() -> float:
	return absf(get_jump_speed())


func get_mining_damage() -> int:
	return GameConstants.PLAYER_MINING_DAMAGE + run_bonus_mining_damage


func get_mining_cooldown_duration() -> float:
	return GameConstants.PLAYER_MINING_COOLDOWN * run_mining_speed_mult


func get_mines_per_second() -> float:
	var cooldown := get_mining_cooldown_duration()
	if cooldown <= 0.0:
		return 0.0
	return 1.0 / cooldown


func get_mining_range_multiplier() -> float:
	return GameConstants.PLAYER_MINING_RANGE_MULTIPLIER * run_mining_range_mult


func get_interest_rate() -> float:
	return maxf(GameConstants.STAGE_INTEREST_RATE + run_bonus_interest_rate, 0.0)


func get_interest_percent() -> int:
	return int(round(get_interest_rate() * 100.0))


func calculate_interest_payout() -> int:
	return int(floor(float(gold) * get_interest_rate()))


func get_luck() -> float:
	return GameConstants.PLAYER_BASE_LUCK + run_bonus_luck


func get_weight_limit_sand_cells() -> int:
	return GameConstants.WEIGHT_LIMIT_SAND_CELLS + run_bonus_max_weight


func get_battery_recovery_per_second() -> float:
	return maxf(GameConstants.PLAYER_BATTERY_RECOVERY_PER_SEC + run_bonus_battery_recovery, 0.0)


func get_stat_panel_entries() -> Array[Dictionary]:
	var attack_shape_units := get_attack_shape_size_units()
	return [
		{"label": "공격 모듈", "value": _get_equipped_attack_module_summary()},
		{"label": "현재 모듈 공격력", "value": str(get_attack_damage())},
		{"label": "근거리 공격력", "value": "+%d" % get_melee_attack_damage_flat()},
		{"label": "원거리 공격력", "value": "+%d" % get_ranged_attack_damage_flat()},
		{"label": "데미지", "value": "+%d%%" % get_damage_percent_display()},
		{"label": "공격속도", "value": "%.2f / sec" % get_attacks_per_second()},
		{"label": "공격범위", "value": "%.2fU x %.2fU" % [attack_shape_units.x, attack_shape_units.y]},
		{"label": "치명타 확률", "value": "%.0f%%" % get_critical_chance_percent()},
		{"label": "치명타 배율", "value": "%d%%" % get_critical_damage_percent()},
		{"label": "현재 체력", "value": "%d / %d" % [player_health, get_player_max_health()]},
		{"label": "방어력", "value": str(get_defense())},
		{"label": "HP 재생", "value": "%.0f" % get_hp_regen_stat()},
		{"label": "이동속도", "value": "%.0f" % get_move_speed()},
		{"label": "점프력", "value": "%.0f" % get_jump_power()},
		{"label": "채굴 데미지", "value": str(get_mining_damage())},
		{"label": "채굴 속도", "value": "%.2f / sec" % get_mines_per_second()},
		{"label": "채굴 범위", "value": "%.2fx" % get_mining_range_multiplier()},
		{"label": "이자율", "value": "%d%%" % get_interest_percent()},
		{"label": "행운", "value": "%.0f (효과 없음)" % get_luck()},
	]


func set_status_text(text: String) -> void:
	status_text = text
	status_text_changed.emit(status_text)


func get_character_slots() -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	for slot_data in CHARACTER_SLOTS:
		var slot: Dictionary = slot_data.duplicate()
		var character_id := String(slot["id"])
		slot["unlocked"] = _is_character_unlocked(character_id)
		slot["best_record"] = _get_character_best_record_summary(character_id)
		slot["selected"] = character_id == selected_character_id
		slots.append(slot)
	return slots


func get_difficulty_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	for option_data in GameConstants.DIFFICULTY_OPTIONS:
		var option: Dictionary = option_data.duplicate()
		option["selected"] = option["id"] == last_selected_difficulty_id
		option["unlocked"] = is_difficulty_unlocked(String(option["id"]))
		options.append(option)
	return options


func select_character(character_id: String) -> bool:
	if not _is_character_unlocked(character_id):
		return false
	var display_name := _get_character_display_name(character_id)
	if display_name.is_empty():
		return false
	selected_character_id = character_id
	selected_character_name = display_name
	_refresh_selected_character_summary()
	selected_character_changed.emit(selected_character_id, selected_character_name, best_record_summary)
	save_profile()
	return true


func begin_run(difficulty_id: String) -> bool:
	for option_data in GameConstants.DIFFICULTY_OPTIONS:
		if option_data["id"] != difficulty_id:
			continue
		if not is_difficulty_unlocked(difficulty_id):
			return false
		last_selected_difficulty_id = String(option_data["id"])
		last_selected_difficulty_name = String(option_data["display_name"])
		current_run_difficulty_id = last_selected_difficulty_id
		current_run_difficulty_name = last_selected_difficulty_name
		current_run_character_id = selected_character_id
		current_run_character_name = selected_character_name
		current_run_stage_reached = 1
		save_profile()
		return true
	return false


func apply_growth_change(changes: Dictionary) -> void:
	for key in changes.keys():
		growth_data[String(key)] = changes[key]
	save_profile()


func apply_setting_change(setting_name: String, value: Variant) -> void:
	settings_data[setting_name] = value
	save_profile()


func register_achievement_unlock(achievement_id: String) -> void:
	if unlocked_achievement_ids.has(achievement_id):
		return
	unlocked_achievement_ids.append(achievement_id)
	save_profile()


func unlock_character(character_id: String) -> void:
	if unlocked_character_ids.has(character_id):
		return
	unlocked_character_ids.append(character_id)
	save_profile()


func is_difficulty_unlocked(difficulty_id: String) -> bool:
	var def := GameConstants.get_difficulty_definition(difficulty_id)
	var required := String(def.get("unlock_required", ""))
	if required.is_empty():
		return true
	return cleared_difficulty_ids.has(required)


func mark_difficulty_cleared(difficulty_id: String) -> void:
	if cleared_difficulty_ids.has(difficulty_id):
		return
	cleared_difficulty_ids.append(difficulty_id)
	save_profile()


func save_profile() -> void:
	var file := FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open save file for writing: %s" % SAVE_FILE_PATH)
		return
	file.store_string(JSON.stringify(_build_save_data(), "\t"))


func load_profile() -> void:
	_apply_save_data(_default_save_data())
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		save_profile()
		return
	var file := FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if file == null:
		push_error("Failed to open save file for reading: %s" % SAVE_FILE_PATH)
		save_profile()
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid save file format. Resetting to defaults.")
		_apply_save_data(_default_save_data())
		save_profile()
		return
	_apply_save_data(parsed)
	save_profile()


func _build_save_data() -> Dictionary:
	return {
		"save_version": SAVE_VERSION,
		"selected_character_id": selected_character_id,
		"last_selected_difficulty_id": last_selected_difficulty_id,
		"persistent_currencies": persistent_currencies.duplicate(true),
		"settings": settings_data.duplicate(true),
		"growth": growth_data.duplicate(true),
		"unlocked_character_ids": Array(unlocked_character_ids),
		"unlocked_achievement_ids": Array(unlocked_achievement_ids),
		"best_records_by_character": best_records_by_character.duplicate(true),
		"cleared_difficulty_ids": Array(cleared_difficulty_ids),
	}


func _default_save_data() -> Dictionary:
	var unlocked_ids: Array[String] = []
	var records: Dictionary = {}
	for slot_data in CHARACTER_SLOTS:
		var character_id := String(slot_data["id"])
		if bool(slot_data["default_unlocked"]):
			unlocked_ids.append(character_id)
		records[character_id] = _default_difficulty_record_map()
	return {
		"save_version": SAVE_VERSION,
		"selected_character_id": "default_worker",
		"last_selected_difficulty_id": "normal",
		"persistent_currencies": DEFAULT_CURRENCIES.duplicate(true),
		"settings": DEFAULT_SETTINGS.duplicate(true),
		"growth": DEFAULT_GROWTH.duplicate(true),
		"unlocked_character_ids": unlocked_ids,
		"unlocked_achievement_ids": [],
		"best_records_by_character": records,
		"cleared_difficulty_ids": [],
	}


func _apply_save_data(data: Dictionary) -> void:
	var default_data := _default_save_data()
	persistent_currencies = _merge_simple_dict(
		default_data["persistent_currencies"],
		data.get("persistent_currencies", {})
	)
	settings_data = _merge_simple_dict(
		default_data["settings"],
		data.get("settings", {})
	)
	growth_data = _merge_simple_dict(
		default_data["growth"],
		data.get("growth", {})
	)
	unlocked_character_ids = PackedStringArray(_normalize_string_array(
		data.get("unlocked_character_ids", default_data["unlocked_character_ids"])
	))
	if unlocked_character_ids.is_empty():
		unlocked_character_ids.append("default_worker")
	unlocked_achievement_ids = PackedStringArray(_normalize_string_array(
		data.get("unlocked_achievement_ids", [])
	))
	cleared_difficulty_ids = PackedStringArray(_normalize_string_array(
		data.get("cleared_difficulty_ids", [])
	))
	best_records_by_character = _normalize_best_records(
		data.get("best_records_by_character", default_data["best_records_by_character"])
	)
	selected_character_id = String(data.get("selected_character_id", "default_worker"))
	if not _is_character_unlocked(selected_character_id):
		selected_character_id = "default_worker"
	last_selected_difficulty_id = String(data.get("last_selected_difficulty_id", "normal"))
	last_selected_difficulty_name = _get_difficulty_display_name(last_selected_difficulty_id)
	selected_character_name = _get_character_display_name(selected_character_id)
	current_run_character_id = selected_character_id
	current_run_character_name = selected_character_name
	current_run_difficulty_id = last_selected_difficulty_id
	current_run_difficulty_name = last_selected_difficulty_name
	_refresh_selected_character_summary()


func _emit_initial_state() -> void:
	gold_changed.emit(gold)
	health_changed.emit(player_health, get_player_max_health())
	status_text_changed.emit(status_text)
	selected_character_changed.emit(selected_character_id, selected_character_name, best_record_summary)
	owned_attack_modules_changed.emit(get_owned_attack_module_ids())
	attack_module_changed.emit(get_equipped_attack_module_id())
	run_items_changed.emit()


func _merge_simple_dict(defaults: Dictionary, overrides: Variant) -> Dictionary:
	var merged := defaults.duplicate(true)
	if typeof(overrides) != TYPE_DICTIONARY:
		return merged
	for key in overrides.keys():
		merged[String(key)] = overrides[key]
	return merged


func _normalize_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for item in value:
		result.append(String(item))
	return result


func _normalize_best_records(value: Variant) -> Dictionary:
	var normalized: Dictionary = {}
	for slot_data in CHARACTER_SLOTS:
		var character_id := String(slot_data["id"])
		normalized[character_id] = _default_difficulty_record_map()
	if typeof(value) != TYPE_DICTIONARY:
		return normalized
	for character_id_variant in value.keys():
		var character_id := String(character_id_variant)
		if not normalized.has(character_id):
			normalized[character_id] = _default_difficulty_record_map()
		var source_records: Dictionary = value[character_id_variant]
		if typeof(source_records) != TYPE_DICTIONARY:
			continue
		for difficulty in GameConstants.DIFFICULTY_OPTIONS:
			var difficulty_id := String(difficulty["id"])
			normalized[character_id][difficulty_id] = int(source_records.get(difficulty_id, 0))
	return normalized


func _default_difficulty_record_map() -> Dictionary:
	var records: Dictionary = {}
	for difficulty in GameConstants.DIFFICULTY_OPTIONS:
		records[String(difficulty["id"])] = 0
	return records


func _is_character_unlocked(character_id: String) -> bool:
	return unlocked_character_ids.has(character_id)


func _get_character_display_name(character_id: String) -> String:
	for slot_data in CHARACTER_SLOTS:
		if String(slot_data["id"]) == character_id:
			return String(slot_data["display_name"])
	return ""


func _get_difficulty_display_name(difficulty_id: String) -> String:
	for option_data in GameConstants.DIFFICULTY_OPTIONS:
		if String(option_data["id"]) == difficulty_id:
			return String(option_data["display_name"])
	return "일반"


func _get_character_best_record_summary(character_id: String) -> String:
	if not best_records_by_character.has(character_id):
		return Locale.ltr("no_record_yet")
	var record_map := best_records_by_character[character_id] as Dictionary
	var best_stage := 0
	var best_difficulty_name := ""
	for option_data in GameConstants.DIFFICULTY_OPTIONS:
		var difficulty_id := String(option_data["id"])
		var stage_value := int(record_map.get(difficulty_id, 0))
		if stage_value > best_stage:
			best_stage = stage_value
			best_difficulty_name = String(option_data["display_name"])
	if best_stage <= 0:
		return Locale.ltr("no_record_yet")
	return Locale.ltr("record_format") % [best_difficulty_name, best_stage]


func _refresh_selected_character_summary() -> void:
	best_record_summary = _get_character_best_record_summary(selected_character_id)


func _update_best_record(character_id: String, difficulty_id: String, stage_reached: int) -> void:
	if not best_records_by_character.has(character_id):
		best_records_by_character[character_id] = _default_difficulty_record_map()
	var record_map := best_records_by_character[character_id] as Dictionary
	record_map[difficulty_id] = maxi(int(record_map.get(difficulty_id, 0)), stage_reached)
	best_records_by_character[character_id] = record_map


func _reset_run_attack_modules() -> void:
	owned_attack_module_ids = PackedStringArray()
	equipped_attack_modules = []
	attack_module_instance_sequence = 0
	attack_module_runtime_state = {}
	var default_module_id := GameData.get_default_attack_module_id()
	if default_module_id != StringName():
		owned_attack_module_ids.append(String(default_module_id))
		var default_definition = GameData.get_attack_module_definition(default_module_id)
		var default_grade := "D"
		if default_definition != null:
			default_grade = String(default_definition.rank)
		equipped_attack_modules.append(_make_attack_module_entry(default_module_id, default_grade))
	equipped_attack_module_id = default_module_id
	owned_attack_modules_changed.emit(get_owned_attack_module_ids())
	attack_module_changed.emit(equipped_attack_module_id)


func _make_attack_module_entry(module_id: StringName, grade: String) -> Dictionary:
	attack_module_instance_sequence += 1
	return {
		"instance_id": "%s_%d" % [String(module_id), attack_module_instance_sequence],
		"module_id": String(module_id),
		"grade": grade,
	}


func _sync_primary_equipped_attack_module_id() -> void:
	if equipped_attack_modules.is_empty():
		equipped_attack_module_id = StringName()
		return
	equipped_attack_module_id = StringName(String(equipped_attack_modules[0].get("module_id", "")))


func _find_first_synthesis_candidate(module_id: StringName, grade: String) -> int:
	for index in range(equipped_attack_modules.size()):
		var entry: Dictionary = equipped_attack_modules[index]
		if String(entry.get("module_id", "")) == String(module_id) and String(entry.get("grade", "")) == grade:
			return index
	return -1


func _get_next_attack_module_grade(grade: String) -> String:
	var order: Array = GameConstants.ATTACK_MODULE_GRADE_ORDER
	var index := order.find(grade)
	if index < 0 or index + 1 >= order.size():
		return ""
	return String(order[index + 1])


func _get_attack_module_grade_multiplier(grade: String, table: Dictionary) -> float:
	return float(table.get(grade, 1.0))


func _get_attack_module_type(module_entry: Dictionary) -> StringName:
	var module_definition = get_attack_module_definition_from_entry(module_entry)
	if module_definition == null:
		return &"melee"
	return module_definition.module_type


func _has_equipped_attack_module(module_id: StringName) -> bool:
	for raw_entry in equipped_attack_modules:
		var entry: Dictionary = raw_entry
		if String(entry.get("module_id", "")) == String(module_id):
			return true
	return false


func _get_equipped_attack_module_summary() -> String:
	if equipped_attack_modules.is_empty():
		return "없음"
	var labels: Array[String] = []
	for raw_entry in equipped_attack_modules:
		var entry: Dictionary = raw_entry
		labels.append(get_attack_module_entry_label(entry))
	return ", ".join(labels)


func _reset_run_shop_items() -> void:
	owned_function_module_ids = PackedStringArray()
	owned_enhance_module_counts = {}
	current_run_items = PackedStringArray()
	current_run_effects = {}
	reset_shop_reroll_count()
	reset_shop_locks()


func _build_shop_item_snapshot(definition: Dictionary, slot_index: int = -1) -> Dictionary:
	var item_id := String(definition.get("item_id", ""))
	var category := String(definition.get("item_category", ""))
	var owned := false
	var equipped := false
	var stack_count := 0
	match category:
		"attack_module":
			owned = is_attack_module_owned(StringName(item_id))
			equipped = _has_equipped_attack_module(StringName(item_id))
		"function_module":
			owned = is_function_module_owned(StringName(item_id))
		"enhance_module":
			stack_count = get_enhance_module_stack_count(StringName(item_id))
			owned = stack_count > 0
	var price_gold := get_effective_shop_item_price(definition)
	var can_afford := can_afford_gold(price_gold)
	var can_buy := can_afford
	var purchase_reason := ""
	if category == "attack_module":
		var attack_purchase_state := can_add_or_synthesize_attack_module(StringName(item_id))
		can_buy = can_afford and bool(attack_purchase_state.get("ok", false))
		purchase_reason = String(attack_purchase_state.get("reason", ""))
	var locked_item_id := get_shop_locked_item_id(slot_index)
	var is_locked := is_shop_slot_locked(slot_index)
	if is_locked and locked_item_id != StringName() and String(locked_item_id) != item_id:
		is_locked = false
	return {
		"slot_index": slot_index,
		"item_id": item_id,
		"item_category": category,
		"name": String(definition.get("name", item_id)),
		"rank": String(definition.get("rank", "D")),
		"price_gold": price_gold,
		"short_desc": String(definition.get("short_desc", "")),
		"desc": String(definition.get("desc", "")),
		"stackable": bool(definition.get("stackable", false)),
		"owned": owned,
		"equipped": equipped,
		"stack_count": stack_count,
		"can_afford": can_afford,
		"can_buy": can_buy,
		"is_locked": is_locked,
		"locked_item_id": String(locked_item_id),
		"can_lock": slot_index >= 0,
		"purchase_reason": purchase_reason,
	}


func _register_owned_attack_module(module_id: StringName) -> Dictionary:
	var module_definition = GameData.get_attack_module_definition(module_id)
	if module_definition == null:
		return {"ok": false, "reason": "missing_definition"}
	var grade := String(module_definition.rank)
	var equip_result := can_add_or_synthesize_attack_module(module_id)
	if not bool(equip_result.get("ok", false)):
		return equip_result
	owned_attack_module_ids.append(String(module_id))
	current_run_items.append(String(module_id))
	var mode := String(equip_result.get("mode", "add"))
	if mode == "synthesize":
		var target_index := int(equip_result.get("target_index", -1))
		if target_index < 0 or target_index >= equipped_attack_modules.size():
			return {"ok": false, "reason": "invalid_synthesis_target"}
		var upgraded_entry := (equipped_attack_modules[target_index] as Dictionary).duplicate(true)
		upgraded_entry["grade"] = String(equip_result.get("next_grade", grade))
		equipped_attack_modules[target_index] = upgraded_entry
	else:
		equipped_attack_modules.append(_make_attack_module_entry(module_id, grade))
	_sync_primary_equipped_attack_module_id()
	owned_attack_modules_changed.emit(get_owned_attack_module_ids())
	attack_module_changed.emit(equipped_attack_module_id)
	run_items_changed.emit()
	return {"ok": true, "reason": mode, "category": "attack_module"}


func _register_function_module_purchase(definition: Dictionary) -> void:
	var item_id := String(definition.get("item_id", ""))
	if not owned_function_module_ids.has(item_id):
		owned_function_module_ids.append(item_id)
	current_run_items.append(item_id)
	_register_runtime_effect_entry(definition)


func _register_enhance_module_purchase(definition: Dictionary) -> void:
	var item_id := String(definition.get("item_id", ""))
	owned_enhance_module_counts[item_id] = get_enhance_module_stack_count(StringName(item_id)) + 1
	current_run_items.append(item_id)
	_register_runtime_effect_entry(definition)
	_apply_shop_effect_values(definition)


func _register_runtime_effect_entry(definition: Dictionary) -> void:
	var effect_type := StringName(String(definition.get("effect_type", "none")))
	if effect_type == StringName():
		return
	if not current_run_effects.has(effect_type):
		current_run_effects[effect_type] = []
	(current_run_effects[effect_type] as Array).append({
		"item_id": String(definition.get("item_id", "")),
		"effect_type": String(effect_type),
		"effect_values": (definition.get("effect_values", {}) as Dictionary).duplicate(true),
		"conditions": _get_condition_entries(definition),
		"effects": _get_effect_entries(definition),
		"apply_timing": _get_item_apply_timing(definition),
	})


func _apply_shop_effect_values(definition: Dictionary) -> void:
	if String(definition.get("effect_type", "")) != "stat_bonus":
		return
	if _get_item_apply_timing(definition) != "on_purchase":
		return
	var effect_values: Dictionary = definition.get("effect_values", {})
	for raw_key in effect_values.keys():
		var effect_key := String(raw_key)
		var effect_value = effect_values[raw_key]
		_apply_stat_bonus_effect(effect_key, effect_value)


func _apply_stat_bonus_effect(effect_key: String, effect_value: Variant) -> void:
	match effect_key:
		"attack_damage_flat":
			run_bonus_damage_percent += float(effect_value) * 0.01
		"attack_damage_percent", "damage_percent":
			run_bonus_damage_percent += float(effect_value)
		"attack_speed_percent":
			run_attack_speed_mult /= maxf(1.0 + float(effect_value), 0.01)
		"attack_range_percent":
			run_attack_range_mult *= 1.0 + float(effect_value)
		"max_hp_flat":
			var previous_max_health := get_player_max_health()
			run_bonus_max_hp += int(effect_value)
			var new_max_health := get_player_max_health()
			player_health = min(player_health + max(new_max_health - previous_max_health, 0), new_max_health)
			health_changed.emit(player_health, new_max_health)
		"defense_flat":
			run_bonus_defense += int(effect_value)
		"hp_regen_flat":
			run_bonus_hp_regen += float(effect_value)
		"max_weight_flat":
			run_bonus_max_weight += int(effect_value)
		"mining_damage_flat":
			run_bonus_mining_damage += int(effect_value)
		"mining_speed_percent":
			run_mining_speed_mult /= maxf(1.0 + float(effect_value), 0.01)
		"mining_range_percent":
			run_mining_range_mult *= 1.0 + float(effect_value)
		"move_speed_percent":
			run_move_speed_mult *= 1.0 + float(effect_value)
		"move_speed_flat":
			run_bonus_move_speed += float(effect_value)
		"jump_power_percent":
			run_jump_power_mult *= 1.0 + float(effect_value)
		"jump_power_flat":
			run_bonus_jump_power += float(effect_value)
		"crit_chance_flat":
			run_bonus_crit_chance += float(effect_value)
		"luck_flat":
			run_bonus_luck += float(effect_value)
		"interest_rate_percent":
			run_bonus_interest_rate += float(effect_value)
		"battery_recovery_flat":
			run_bonus_battery_recovery += float(effect_value)


func _get_item_apply_timing(definition: Dictionary) -> String:
	var raw_timing := String(definition.get("apply_timing", ""))
	if not raw_timing.is_empty():
		return raw_timing
	if String(definition.get("effect_type", "")) == "conditional_stat_bonus":
		return "stat_query"
	return "on_purchase"


func _get_condition_entries(source: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var raw_conditions = source.get("conditions", [])
	if not raw_conditions is Array:
		return result
	for raw_condition in raw_conditions:
		if not raw_condition is Dictionary:
			continue
		var condition: Dictionary = raw_condition
		result.append(condition.duplicate(true))
	return result


func _get_effect_entries(source: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var raw_effects = source.get("effects", [])
	if raw_effects is Array:
		for raw_effect in raw_effects:
			if not raw_effect is Dictionary:
				continue
			var effect: Dictionary = raw_effect
			result.append(effect.duplicate(true))
	if not result.is_empty():
		return result
	var raw_values = source.get("effect_values", {})
	if not raw_values is Dictionary:
		return result
	var effect_values: Dictionary = raw_values
	for raw_key in effect_values.keys():
		result.append({
			"type": String(raw_key),
			"value": effect_values[raw_key],
		})
	return result


func _are_item_conditions_met(conditions: Array[Dictionary], context: Dictionary = {}) -> bool:
	for condition in conditions:
		if not _is_item_condition_met(condition, context):
			return false
	return true


func _is_item_condition_met(condition: Dictionary, context: Dictionary = {}) -> bool:
	match String(condition.get("type", "")):
		"weight_ratio_at_least":
			return _get_condition_weight_ratio(context) >= float(condition.get("value", 0.0))
		"weight_ratio_below":
			return _get_condition_weight_ratio(context) < float(condition.get("value", 0.0))
		"hp_ratio_at_least":
			return _get_hp_ratio() >= float(condition.get("value", 0.0))
		"hp_ratio_below":
			return _get_hp_ratio() < float(condition.get("value", 0.0))
		"gold_at_least":
			return gold >= int(condition.get("value", 0))
		"current_day_at_least":
			return current_day >= int(condition.get("value", 1))
		"all_attack_modules_type":
			return _are_all_equipped_attack_modules_type(StringName(String(condition.get("module_type", ""))))
		"equipped_attack_module_count_at_least":
			return equipped_attack_modules.size() >= int(condition.get("value", 0))
		"has_attack_module_type":
			return _has_equipped_attack_module_type(StringName(String(condition.get("module_type", ""))))
		"attack_module_type_is", "attack_hit_side", "player_is_airborne", "target_block_size_at_least", "is_critical_hit":
			# TODO: attack-timing conditions need on_attack_start/on_attack_hit context.
			return false
		_:
			return false


func _get_condition_weight_ratio(context: Dictionary) -> float:
	if context.has("weight_ratio"):
		return float(context.get("weight_ratio", 0.0))
	if not context.has("current_weight_sand_cells"):
		return 0.0
	var limit := float(context.get("weight_limit_sand_cells", get_weight_limit_sand_cells()))
	if limit <= 0.0:
		return 0.0
	return float(context.get("current_weight_sand_cells", 0.0)) / limit


func _get_hp_ratio() -> float:
	var max_health := get_player_max_health()
	if max_health <= 0:
		return 0.0
	return float(player_health) / float(max_health)


func _are_all_equipped_attack_modules_type(module_type: StringName) -> bool:
	if module_type == StringName() or equipped_attack_modules.is_empty():
		return false
	for entry in equipped_attack_modules:
		if _get_attack_module_type(entry) != module_type:
			return false
	return true


func _has_equipped_attack_module_type(module_type: StringName) -> bool:
	if module_type == StringName():
		return false
	for entry in equipped_attack_modules:
		if _get_attack_module_type(entry) == module_type:
			return true
	return false


# ---- 경험치 및 레벨업 ----

func add_xp(amount: int) -> void:
	if amount <= 0:
		return
	player_current_xp += amount
	xp_changed.emit(player_current_xp, player_next_level_xp)
	if player_current_xp >= player_next_level_xp:
		level_up_ready.emit()


func add_sand_removed_xp(removed_cells: int) -> void:
	if removed_cells <= 0:
		return
	pending_sand_removed_cells_for_xp += removed_cells
	var xp_amount := GameConstants.get_sand_xp(pending_sand_removed_cells_for_xp)
	if xp_amount <= 0:
		return
	pending_sand_removed_cells_for_xp -= xp_amount * GameConstants.SAND_REMOVED_CELLS_PER_XP
	add_xp(xp_amount)

func get_level_up_card_pool() -> Array[Dictionary]:
	var cards: Array[Dictionary] = []
	for raw_key in GameConstants.LEVEL_UP_CARDS.keys():
		var card: Dictionary = GameConstants.LEVEL_UP_CARDS[raw_key]
		cards.append(card.duplicate(true))
	for raw_card in GameConstants.EXTRA_LEVEL_UP_CARDS:
		var card: Dictionary = raw_card
		cards.append(card.duplicate(true))
	return cards


func get_level_up_card_definition(card_id: String) -> Dictionary:
	for card in get_level_up_card_pool():
		if String(card.get("id", "")) == card_id:
			return card
	return {}


func get_level_up_card_rarity_definition(rarity_id: String) -> Dictionary:
	for raw_rarity in GameConstants.LEVEL_UP_CARD_RARITIES:
		var rarity: Dictionary = raw_rarity
		if String(rarity.get("id", "")) == rarity_id:
			return rarity
	return GameConstants.LEVEL_UP_CARD_RARITIES[0]


func get_level_up_card_rarity_multiplier(rarity_id: String) -> float:
	var rarity := get_level_up_card_rarity_definition(rarity_id)
	return float(rarity.get("multiplier", 1.0))


func get_level_up_rarity_chances(luck_value: Variant = null) -> Dictionary:
	var luck_amount := get_luck()
	if luck_value != null:
		luck_amount = float(luck_value)
	var raw_chances: Array[Dictionary] = []
	var total := 0.0
	for raw_rarity in GameConstants.LEVEL_UP_CARD_RARITIES:
		var rarity: Dictionary = raw_rarity
		var chance := float(rarity.get("base_chance", 0.0)) + luck_amount * float(rarity.get("luck_chance_delta", 0.0))
		chance = clampf(chance, float(rarity.get("min_chance", 0.0)), float(rarity.get("max_chance", 1.0)))
		raw_chances.append({
			"id": String(rarity.get("id", "")),
			"chance": chance,
		})
		total += chance
	var normalized := {}
	if total <= 0.0:
		var fallback := 1.0 / maxf(float(raw_chances.size()), 1.0)
		for entry in raw_chances:
			normalized[String(entry.get("id", ""))] = fallback
		return normalized
	for entry in raw_chances:
		normalized[String(entry.get("id", ""))] = float(entry.get("chance", 0.0)) / total
	return normalized


func roll_level_up_card_rarity(luck_value: Variant = null) -> String:
	var chances := get_level_up_rarity_chances(luck_value)
	var roll := randf()
	var cumulative := 0.0
	var fallback := "normal"
	for raw_rarity in GameConstants.LEVEL_UP_CARD_RARITIES:
		var rarity: Dictionary = raw_rarity
		var rarity_id := String(rarity.get("id", "normal"))
		fallback = rarity_id
		cumulative += float(chances.get(rarity_id, 0.0))
		if roll <= cumulative:
			return rarity_id
	return fallback


func generate_level_up_card_choices(count: int = 3) -> Array[Dictionary]:
	var pool := get_level_up_card_pool()
	var choices: Array[Dictionary] = []
	var used := {}
	if pool.is_empty() or count <= 0:
		return choices
	var attempts := 0
	while choices.size() < count and attempts < 200:
		attempts += 1
		var rarity_id := roll_level_up_card_rarity()
		var card: Dictionary = pool[randi() % pool.size()]
		var card_id := String(card.get("id", ""))
		var choice_key := "%s:%s" % [card_id, rarity_id]
		if used.has(choice_key):
			continue
		used[choice_key] = true
		choices.append(_build_level_up_card_choice(card_id, rarity_id))
	if choices.size() >= count:
		return choices
	for raw_rarity in GameConstants.LEVEL_UP_CARD_RARITIES:
		var rarity: Dictionary = raw_rarity
		var rarity_id := String(rarity.get("id", "normal"))
		for card in pool:
			if choices.size() >= count:
				return choices
			var card_id := String(card.get("id", ""))
			var choice_key := "%s:%s" % [card_id, rarity_id]
			if used.has(choice_key):
				continue
			used[choice_key] = true
			choices.append(_build_level_up_card_choice(card_id, rarity_id))
	return choices


func get_level_up_card_effect_description(card_id: String, rarity_id: String = "normal") -> String:
	var multiplier := get_level_up_card_rarity_multiplier(rarity_id)
	match card_id:
		"atk_up", "damage_up":
			return "Damage +%s" % _format_level_up_percent(_scale_level_up_percent(0.01, multiplier))
		"atk_spd_up":
			return "Attack speed +%s" % _format_level_up_percent(_scale_level_up_percent(0.02, multiplier))
		"hp_up":
			var hp_gain := _scale_level_up_int(5, multiplier)
			return "Max HP +%d, heal +%d" % [hp_gain, hp_gain]
		"spd_up":
			return "Move speed +%s" % _format_level_up_percent(_scale_level_up_percent(0.03, multiplier))
		"mine_dmg_up":
			return "Mining damage +%d" % _scale_level_up_int(1, multiplier)
		"mine_spd_up":
			return "Mining speed +%s" % _format_level_up_percent(_scale_level_up_percent(0.04, multiplier))
		"battery_recovery_up":
			return "Battery recovery +%d/sec" % _scale_level_up_int(1, multiplier)
		"luck_up":
			return "Luck +%d" % _scale_level_up_int(1, multiplier)
		"interest_up":
			return "Interest +%sp" % _format_level_up_percent(_scale_level_up_percent(0.02, multiplier))
		"atk_range_up":
			return "Attack range +%s" % _format_level_up_percent(_scale_level_up_percent(0.05, multiplier))
		"crit_chance_up":
			return "Crit chance +%sp" % _format_level_up_percent(_scale_level_up_percent(0.02, multiplier))
		"def_up":
			return "Defense +%d" % _scale_level_up_int(1, multiplier)
		"hp_regen_up":
			return "HP regen +%d" % _scale_level_up_int(1, multiplier)
		"jump_up":
			return "Jump power +%s" % _format_level_up_percent(_scale_level_up_percent(0.03, multiplier))
		"mine_range_up":
			return "Mining range +%s" % _format_level_up_percent(_scale_level_up_percent(0.05, multiplier))
		"melee_atk_up":
			return "Melee attack +%d" % _scale_level_up_int(1, multiplier)
		"ranged_atk_up":
			return "Ranged attack +%d" % _scale_level_up_int(1, multiplier)
		_:
			return ""


func _build_level_up_card_choice(card_id: String, rarity_id: String) -> Dictionary:
	var card := get_level_up_card_definition(card_id)
	var rarity := get_level_up_card_rarity_definition(rarity_id)
	var rarity_title := String(rarity.get("title", "Normal"))
	return {
		"id": card_id,
		"card_id": card_id,
		"rarity_id": String(rarity.get("id", "normal")),
		"rarity_title": rarity_title,
		"rarity_multiplier": float(rarity.get("multiplier", 1.0)),
		"title": "%s [%s]" % [String(card.get("title", card_id)), rarity_title],
		"desc": "%s\n%s" % [rarity_title, get_level_up_card_effect_description(card_id, rarity_id)],
	}


func _scale_level_up_int(base_value: int, multiplier: float) -> int:
	return maxi(roundi(float(base_value) * multiplier), 1)


func _scale_level_up_percent(base_value: float, multiplier: float) -> float:
	return float(roundi(base_value * multiplier * 100.0)) / 100.0


func _format_level_up_percent(value: float) -> String:
	return "%d%%" % int(round(value * 100.0))


func apply_level_up_card(card_id: String, rarity_id: String = "normal") -> void:
	var rarity_multiplier := get_level_up_card_rarity_multiplier(rarity_id)
	match card_id:
		"atk_up", "damage_up":
			run_bonus_damage_percent += _scale_level_up_percent(0.01, rarity_multiplier)
		"atk_spd_up":
			run_attack_speed_mult /= 1.0 + _scale_level_up_percent(0.02, rarity_multiplier)
		"hp_up":
			var hp_gain := _scale_level_up_int(5, rarity_multiplier)
			run_bonus_max_hp += hp_gain
			player_health = mini(player_health + hp_gain, get_player_max_health())
			health_changed.emit(player_health, GameConstants.PLAYER_MAX_HEALTH + run_bonus_max_hp)
		"spd_up":
			run_move_speed_mult *= 1.0 + _scale_level_up_percent(0.03, rarity_multiplier)
		"mine_dmg_up":
			run_bonus_mining_damage += _scale_level_up_int(1, rarity_multiplier)
		"mine_spd_up":
			run_mining_speed_mult /= 1.0 + _scale_level_up_percent(0.04, rarity_multiplier)
		"battery_recovery_up":
			run_bonus_battery_recovery += float(_scale_level_up_int(1, rarity_multiplier))
		"luck_up":
			run_bonus_luck += float(_scale_level_up_int(1, rarity_multiplier))
		"interest_up":
			run_bonus_interest_rate += _scale_level_up_percent(0.02, rarity_multiplier)
		"melee_atk_up":
			run_bonus_melee_attack_damage += _scale_level_up_int(1, rarity_multiplier)
		"ranged_atk_up":
			run_bonus_ranged_attack_damage += _scale_level_up_int(1, rarity_multiplier)

	# 경험치 차감 및 레벨 증가
	match card_id:
		"atk_range_up":
			run_attack_range_mult *= 1.0 + _scale_level_up_percent(0.05, rarity_multiplier)
		"crit_chance_up":
			run_bonus_crit_chance += _scale_level_up_percent(0.02, rarity_multiplier)
		"def_up":
			run_bonus_defense += _scale_level_up_int(1, rarity_multiplier)
		"hp_regen_up":
			run_bonus_hp_regen += float(_scale_level_up_int(1, rarity_multiplier))
		"jump_up":
			run_jump_power_mult *= 1.0 + _scale_level_up_percent(0.03, rarity_multiplier)
		"mine_range_up":
			run_mining_range_mult *= 1.0 + _scale_level_up_percent(0.05, rarity_multiplier)
	player_current_xp -= player_next_level_xp
	if player_current_xp < 0:
		player_current_xp = 0
	player_level += 1
	player_next_level_xp = int(player_level * 20) # 스케일링 비율
	
	level_changed.emit(player_level)
	xp_changed.emit(player_current_xp, player_next_level_xp)
