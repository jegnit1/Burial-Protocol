extends SceneTree

const GC = preload("res://scripts/autoload/GameConstants.gd")
const BOSS_DPS_SAMPLES := [40, 60, 100, 150, 200]
const SHOP_RANK_POWERS := {
	"D": 1.0,
	"C": 1.8,
	"B": 3.2,
	"A": 5.5,
	"S": 9.0,
}
const SHOP_STAT_BASE_TARGETS := {
	"attack_damage_flat": {"label": "attack_damage", "base_value": 1.0, "unit": "flat", "level_card_id": "atk_up"},
	"attack_speed_percent": {"label": "attack_speed", "base_value": 0.03, "unit": "percent", "level_card_id": "atk_spd_up"},
	"attack_range_percent": {"label": "attack_range", "base_value": 0.05, "unit": "percent", "level_card_id": "atk_range_up"},
	"max_hp_flat": {"label": "max_health", "base_value": 5.0, "unit": "flat", "level_card_id": "hp_up"},
	"defense_flat": {"label": "defense", "base_value": 1.0, "unit": "flat", "level_card_id": "def_up"},
	"hp_regen_flat": {"label": "hp_regen", "base_value": 1.0, "unit": "flat", "level_card_id": "hp_regen_up"},
	"move_speed_percent": {"label": "move_speed", "base_value": 0.03, "unit": "percent", "level_card_id": "spd_up"},
	"jump_power_percent": {"label": "jump_power", "base_value": 0.03, "unit": "percent", "level_card_id": "jump_up"},
	"mining_damage_flat": {"label": "mining_damage", "base_value": 1.0, "unit": "flat", "level_card_id": "mine_dmg_up"},
	"mining_speed_percent": {"label": "mining_speed", "base_value": 0.04, "unit": "percent", "level_card_id": "mine_spd_up"},
	"mining_range_percent": {"label": "mining_range", "base_value": 0.05, "unit": "percent", "level_card_id": "mine_range_up"},
	"crit_chance_flat": {"label": "crit_chance", "base_value": 0.01, "unit": "percentage_point", "level_card_id": "crit_chance_up"},
	"luck_flat": {"label": "luck", "base_value": 1.0, "unit": "flat", "level_card_id": "luck_up"},
	"interest_rate_percent": {"label": "interest_rate", "base_value": 0.01, "unit": "percentage_point", "level_card_id": "interest_up"},
	"battery_recovery_flat": {"label": "battery_recovery", "base_value": 0.5, "unit": "flat_per_second", "level_card_id": "battery_recovery_up"},
}
const LEVEL_UP_NORMAL_TARGETS := {
	"atk_up": {"stat": "attack_damage", "value": 1.0, "unit": "flat"},
	"atk_spd_up": {"stat": "attack_speed", "value": 0.03, "unit": "percent"},
	"atk_range_up": {"stat": "attack_range", "value": 0.05, "unit": "percent"},
	"crit_chance_up": {"stat": "crit_chance", "value": 0.02, "unit": "percentage_point"},
	"hp_up": {"stat": "max_health", "value": 5.0, "unit": "flat"},
	"def_up": {"stat": "defense", "value": 1.0, "unit": "flat"},
	"hp_regen_up": {"stat": "hp_regen", "value": 1.0, "unit": "flat"},
	"spd_up": {"stat": "move_speed", "value": 0.03, "unit": "percent"},
	"jump_up": {"stat": "jump_power", "value": 0.03, "unit": "percent"},
	"battery_recovery_up": {"stat": "battery_recovery", "value": 1.0, "unit": "flat_per_second"},
	"mine_dmg_up": {"stat": "mining_damage", "value": 1.0, "unit": "flat"},
	"mine_spd_up": {"stat": "mining_speed", "value": 0.04, "unit": "percent"},
	"mine_range_up": {"stat": "mining_range", "value": 0.05, "unit": "percent"},
	"luck_up": {"stat": "luck", "value": 1.0, "unit": "flat"},
	"interest_up": {"stat": "interest_rate", "value": 0.02, "unit": "percentage_point"},
}

var _game_data: Node = null
var _game_state: Node = null
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
	print(JSON.stringify(_build_snapshot(), "\t"))
	quit(0)
	return true


func _build_snapshot() -> Dictionary:
	return {
		"ok": true,
		"player_stats": _get_player_stats(),
		"difficulty_multipliers": _get_difficulty_multipliers(),
		"attack_module_grade_multipliers": {
			"damage": GC.ATTACK_MODULE_GRADE_DAMAGE_MULTIPLIERS,
			"speed": GC.ATTACK_MODULE_GRADE_SPEED_MULTIPLIERS,
			"range": GC.ATTACK_MODULE_GRADE_RANGE_MULTIPLIERS,
		},
		"stage_days": _get_stage_days(),
		"day_hp_comparison": _get_day_hp_comparison(),
		"boss_days": _get_boss_days(),
		"missing_day_fallback": _get_missing_day_fallback(),
		"block_catalog": _get_block_catalog_snapshot(),
		"shop_stat_bonus_by_rank": _get_shop_stat_bonus_by_rank(),
		"shop_stat_bonus_rank_comparison": _get_shop_stat_bonus_rank_comparison(),
		"level_up_cards": _get_level_up_card_snapshot(),
		"level_up_rarity_chances_by_luck": _get_level_up_rarity_chances_by_luck(),
		"level_up_card_rarity_effect_values": _get_level_up_card_rarity_effect_values(),
		"level_up_choice_sample": _get_level_up_choice_sample(),
	}


func _get_player_stats() -> Dictionary:
	return {
		"attack_damage": GC.PLAYER_ATTACK_DAMAGE,
		"attack_cooldown": GC.PLAYER_ATTACK_COOLDOWN,
		"base_dps": float(GC.PLAYER_ATTACK_DAMAGE) / GC.PLAYER_ATTACK_COOLDOWN,
		"max_health": GC.PLAYER_MAX_HEALTH,
		"defense": GC.PLAYER_BASE_DEFENSE,
		"crit_chance": GC.PLAYER_BASE_CRIT_CHANCE,
		"crit_damage_multiplier": GC.PLAYER_CRIT_DAMAGE_MULTIPLIER,
		"mining_damage": GC.PLAYER_MINING_DAMAGE,
		"mining_cooldown": GC.PLAYER_MINING_COOLDOWN,
		"mining_per_second": 1.0 / GC.PLAYER_MINING_COOLDOWN,
		"move_speed": GC.PLAYER_MOVE_SPEED,
		"air_speed": GC.PLAYER_AIR_SPEED,
		"jump_power": absf(GC.PLAYER_JUMP_SPEED),
		"weight_limit_sand_cells": GC.WEIGHT_LIMIT_SAND_CELLS,
		"battery_recovery": GC.PLAYER_BATTERY_RECOVERY_PER_SEC,
		"block_hp_per_unit": GC.BLOCK_HP_PER_UNIT,
		"block_reward_per_unit": GC.BLOCK_REWARD_PER_UNIT,
		"block_sand_units_per_unit": GC.BLOCK_SAND_UNITS_PER_UNIT,
	}


func _get_difficulty_multipliers() -> Dictionary:
	var result := {}
	for raw_option in GC.DIFFICULTY_OPTIONS:
		var option: Dictionary = raw_option
		result[String(option.get("id", ""))] = float(option.get("block_hp_multiplier", 1.0))
	return result


func _get_stage_days() -> Array[Dictionary]:
	var days: Array[Dictionary] = []
	for day in [1, 5, 10, 15, 20, 25, 30]:
		days.append({
			"day": day,
			"type": String(_game_data.call("get_day_type", day)),
			"actual_hp_multiplier": float(_game_data.call("get_block_hp_multiplier", day)),
			"doc_formula_hp_multiplier": _doc_day_hp_multiplier(day),
			"spawn_interval_multiplier": float(_game_data.call("get_spawn_interval_multiplier", day)),
		})
	return days


func _get_day_hp_comparison() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for day in [1, 10, 20, 30]:
		var stage_multiplier := float(_game_data.call("get_block_hp_multiplier", day))
		var doc_multiplier := _doc_day_hp_multiplier(day)
		var default_block_hp := _get_specific_block_hp(&"wood", &"size_1x1", StringName(), day)
		rows.append({
			"day": day,
			"base_dps": float(GC.PLAYER_ATTACK_DAMAGE) / GC.PLAYER_ATTACK_COOLDOWN,
			"default_block_hp_actual_runtime": default_block_hp,
			"default_block_hp_stage_table_expected": ceili(GC.BLOCK_HP_PER_UNIT * stage_multiplier),
			"default_block_hp_doc_formula": ceili(GC.BLOCK_HP_PER_UNIT * doc_multiplier),
			"stage_boss_hp_actual_runtime": _get_stage_boss_hp(day),
		})
	return rows


func _get_specific_block_hp(material_id: StringName, size_id: StringName, type_id: StringName, day: int) -> int:
	var type_definition = null
	if type_id != StringName():
		type_definition = _game_data.call("get_block_type_definition", type_id)
	var resolved = _game_data.call("resolve_specific_block_definition", material_id, size_id, &"normal", day, type_definition)
	if resolved == null:
		return 0
	return int(resolved.final_hp)


func _get_stage_boss_hp(day: int) -> int:
	var day_definition = _game_data.call("get_day_definition", day)
	if day_definition == null:
		return 0
	var material_id: StringName = day_definition.boss_block_base_id
	var size_id: StringName = day_definition.boss_block_size_id
	var type_id: StringName = day_definition.boss_block_type_id
	if material_id == StringName() or size_id == StringName():
		return 0
	return _get_specific_block_hp(material_id, size_id, type_id, day)


func _get_boss_days() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var previous_hp := 0
	for day in range(1, int(_game_data.call("get_total_days")) + 1):
		if not bool(_game_data.call("is_boss_day", day)):
			continue
		var day_definition = _game_data.call("get_day_definition", day)
		var material_id: StringName = day_definition.boss_block_base_id
		var size_id: StringName = day_definition.boss_block_size_id
		var type_id: StringName = day_definition.boss_block_type_id
		var material_definition = _game_data.call("get_block_material_definition", material_id)
		var size_definition = _game_data.call("get_block_size_definition", size_id)
		var type_definition = null
		if type_id != StringName():
			type_definition = _game_data.call("get_block_type_definition", type_id)
		var resolved = _game_data.call("resolve_specific_block_definition", material_id, size_id, &"normal", day, type_definition)
		var final_hp := 0 if resolved == null else int(resolved.final_hp)
		var default_block_hp := _get_specific_block_hp(&"wood", &"size_1x1", StringName(), day)
		var hp_growth_from_previous := 0.0
		if previous_hp > 0:
			hp_growth_from_previous = float(final_hp) / float(previous_hp)
		if final_hp > 0:
			previous_hp = final_hp
		rows.append({
			"day": day,
			"material": String(material_id),
			"size": String(size_id),
			"type": String(type_id),
			"material_hp_multiplier": _get_resource_float(material_definition, "hp_multiplier"),
			"size_hp_multiplier": _get_resource_float(size_definition, "hp_multiplier"),
			"type_hp_multiplier": 1.0 if type_definition == null else float(type_definition.hp_multiplier),
			"material_min_stage": _get_resource_int(material_definition, "min_stage"),
			"material_max_stage": _get_resource_int(material_definition, "max_stage"),
			"size_min_stage": _get_resource_int(size_definition, "min_stage"),
			"size_max_stage": _get_resource_int(size_definition, "max_stage"),
			"resolved_ok": resolved != null,
			"final_hp": final_hp,
			"final_reward": 0 if resolved == null else int(resolved.final_reward),
			"final_sand_units": 0 if resolved == null else int(resolved.final_sand_units),
			"day_hp_multiplier": float(_game_data.call("get_block_hp_multiplier", day)),
			"default_block_hp": default_block_hp,
			"hp_to_default_block_ratio": 0.0 if default_block_hp <= 0 else _round_to(float(final_hp) / float(default_block_hp), 2),
			"hp_growth_from_previous_boss": _round_to(hp_growth_from_previous, 2),
			"kill_time_seconds_by_dps": _get_kill_time_seconds_by_dps(final_hp),
		})
	return rows


func _get_resource_int(resource, property_name: String) -> int:
	if resource == null:
		return 0
	return int(resource.get(property_name))


func _get_resource_float(resource, property_name: String) -> float:
	if resource == null:
		return 0.0
	return float(resource.get(property_name))


func _get_kill_time_seconds_by_dps(hp: int) -> Dictionary:
	var result := {}
	for dps in BOSS_DPS_SAMPLES:
		var key := "%d_dps" % int(dps)
		if hp <= 0 or float(dps) <= 0.0:
			result[key] = 0.0
			continue
		result[key] = _round_to(float(hp) / float(dps), 2)
	return result


func _round_to(value: float, digits: int) -> float:
	var scale := pow(10.0, float(digits))
	return round(value * scale) / scale


func _get_missing_day_fallback() -> Dictionary:
	var missing_day := 999
	return {
		"day": missing_day,
		"stage_multiplier": float(_game_data.call("get_block_hp_multiplier", missing_day)),
		"default_block_hp_actual_runtime": _get_specific_block_hp(&"wood", &"size_1x1", StringName(), missing_day),
	}


func _doc_day_hp_multiplier(day: int) -> float:
	return 1.0 + float(day - 1) * 0.06 + float(floori((day - 1) / 5)) * 0.12


func _get_block_catalog_snapshot() -> Dictionary:
	var catalog = _game_data.call("get_block_catalog")
	var materials: Array[Dictionary] = []
	for material in catalog.block_materials:
		materials.append({
			"id": String(material.material_id),
			"hp": float(material.hp_multiplier),
			"reward": float(material.reward_multiplier),
			"spawn_weight": float(material.base_spawn_weight),
			"min_stage": int(material.min_stage),
			"min_difficulty": String(material.min_difficulty),
			"special": String(material.special_result_type),
		})
	var sizes: Array[Dictionary] = []
	for size in catalog.block_sizes:
		sizes.append({
			"id": String(size.size_id),
			"width": int(size.width_u),
			"height": int(size.height_u),
			"area": int(size.area),
			"hp": float(size.hp_multiplier),
			"reward": float(size.reward_multiplier),
			"spawn_weight": float(size.base_spawn_weight),
			"min_stage": int(size.min_stage),
			"min_difficulty": String(size.min_difficulty),
		})
	var types: Array[Dictionary] = []
	for block_type in catalog.block_types:
		types.append({
			"id": String(block_type.id),
			"hp": float(block_type.hp_multiplier),
			"reward": float(block_type.reward_multiplier),
			"sand_units": float(block_type.sand_units_multiplier),
			"random": bool(block_type.can_spawn_randomly),
			"spawn_weight": float(block_type.spawn_weight_multiplier),
		})
	return {
		"materials": materials,
		"sizes": sizes,
		"types": types,
	}


func _get_shop_stat_bonus_by_rank() -> Dictionary:
	var result := {}
	for raw_item in _game_data.call("get_all_shop_items"):
		var item: Dictionary = raw_item
		if String(item.get("item_category", "")) != "enhance_module":
			continue
		var effect_type := String(item.get("effect_type", ""))
		if effect_type != "stat_bonus" and effect_type != "conditional_stat_bonus":
			continue
		var rank := String(item.get("rank", "D"))
		var effects: Array = item.get("effects", [])
		for raw_effect in effects:
			var effect: Dictionary = raw_effect
			var effect_key := String(effect.get("type", ""))
			if effect_key.is_empty():
				continue
			if not result.has(effect_key):
				result[effect_key] = {}
			if not result[effect_key].has(rank):
				result[effect_key][rank] = []
			result[effect_key][rank].append({
				"item_id": String(item.get("item_id", "")),
				"value": effect.get("value", null),
				"effect_type": effect_type,
			})
	return result


func _get_shop_stat_bonus_rank_comparison() -> Dictionary:
	var rows: Array[Dictionary] = []
	var by_effect := {}
	var outliers: Array[Dictionary] = []
	var missing_doc_targets: Array[Dictionary] = []
	for raw_item in _game_data.call("get_all_shop_items"):
		var item: Dictionary = raw_item
		if String(item.get("item_category", "")) != "enhance_module":
			continue
		var effect_type := String(item.get("effect_type", ""))
		if effect_type != "stat_bonus" and effect_type != "conditional_stat_bonus":
			continue
		var rank := String(item.get("rank", "D"))
		var effects: Array = item.get("effects", [])
		for raw_effect in effects:
			var effect: Dictionary = raw_effect
			var effect_key := String(effect.get("type", ""))
			if effect_key.is_empty():
				continue
			var actual_value := float(effect.get("value", 0.0))
			var target: Dictionary = SHOP_STAT_BASE_TARGETS.get(effect_key, {})
			var expected_value = null
			var delta = null
			var ratio = null
			var status := "no_doc_target"
			var level_platinum_value = null
			var level_relation = null
			if not target.is_empty():
				expected_value = _get_shop_expected_value(effect_key, rank)
				delta = _round_to(actual_value - float(expected_value), 4)
				if absf(float(expected_value)) > 0.0001:
					ratio = _round_to(actual_value / float(expected_value), 2)
				status = _classify_value_delta(actual_value, float(expected_value), String(target.get("unit", "")))
				level_platinum_value = _get_level_platinum_target_value(target)
				if level_platinum_value != null and absf(float(level_platinum_value)) > 0.0001:
					level_relation = _round_to(actual_value / float(level_platinum_value), 2)
			var row := {
				"item_id": String(item.get("item_id", "")),
				"name": String(item.get("name", "")),
				"rank": rank,
				"effect_type": effect_type,
				"effect_key": effect_key,
				"actual_value": actual_value,
				"doc_expected_value": expected_value,
				"delta_from_doc": delta,
				"actual_to_expected_ratio": ratio,
				"level_platinum_value": level_platinum_value,
				"actual_to_level_platinum_ratio": level_relation,
				"status": status,
			}
			rows.append(row)
			if not by_effect.has(effect_key):
				by_effect[effect_key] = []
			by_effect[effect_key].append(row)
			if target.is_empty():
				missing_doc_targets.append(row)
			elif status == "high" or status == "low":
				outliers.append(row)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var effect_cmp := String(a.get("effect_key", "")).naturalnocasecmp_to(String(b.get("effect_key", "")))
		if effect_cmp != 0:
			return effect_cmp < 0
		return _rank_sort_value(String(a.get("rank", "D"))) < _rank_sort_value(String(b.get("rank", "D")))
	)
	return {
		"rank_powers": SHOP_RANK_POWERS,
		"doc_base_targets": SHOP_STAT_BASE_TARGETS,
		"items": rows,
		"by_effect": by_effect,
		"outliers": outliers,
		"missing_doc_targets": missing_doc_targets,
		"summary": _summarize_shop_comparison(rows),
	}


func _get_shop_expected_value(effect_key: String, rank: String):
	var target: Dictionary = SHOP_STAT_BASE_TARGETS.get(effect_key, {})
	if target.is_empty():
		return null
	var raw_value := float(target.get("base_value", 0.0)) * float(SHOP_RANK_POWERS.get(rank, 1.0))
	return _round_shop_value(raw_value, String(target.get("unit", "")))


func _round_shop_value(value: float, unit: String):
	match unit:
		"flat":
			return int(round(value))
		"percent", "percentage_point":
			return _round_to(value, 2)
		"flat_per_second":
			return _round_to(value, 2)
	return _round_to(value, 2)


func _get_level_platinum_target_value(target: Dictionary):
	var base_value := float(target.get("base_value", 0.0))
	var level_card_id := String(target.get("level_card_id", ""))
	if level_card_id.is_empty():
		return null
	var level_target: Dictionary = LEVEL_UP_NORMAL_TARGETS.get(level_card_id, {})
	var level_base := float(level_target.get("value", base_value))
	return _round_level_value(level_base * 4.0, String(level_target.get("unit", target.get("unit", ""))))


func _round_level_value(value: float, unit: String):
	match unit:
		"flat":
			return int(round(value))
		"percent", "percentage_point":
			return _round_to(value, 2)
		"flat_per_second":
			return _round_to(value, 2)
	return _round_to(value, 2)


func _classify_value_delta(actual_value: float, expected_value: float, unit: String) -> String:
	var tolerance := 0.0001
	if unit == "flat":
		tolerance = 0.51
	elif unit == "percent" or unit == "percentage_point":
		tolerance = 0.0051
	elif unit == "flat_per_second":
		tolerance = 0.051
	if actual_value > expected_value + tolerance:
		return "high"
	if actual_value < expected_value - tolerance:
		return "low"
	return "near_doc"


func _rank_sort_value(rank: String) -> int:
	match rank:
		"D":
			return 0
		"C":
			return 1
		"B":
			return 2
		"A":
			return 3
		"S":
			return 4
	return 99


func _summarize_shop_comparison(rows: Array[Dictionary]) -> Dictionary:
	var total := rows.size()
	var near_doc := 0
	var high := 0
	var low := 0
	var missing := 0
	var by_status := {}
	for row in rows:
		var status := String(row.get("status", ""))
		by_status[status] = int(by_status.get(status, 0)) + 1
		match status:
			"near_doc":
				near_doc += 1
			"high":
				high += 1
			"low":
				low += 1
			"no_doc_target":
				missing += 1
	return {
		"total_rows": total,
		"near_doc": near_doc,
		"high": high,
		"low": low,
		"no_doc_target": missing,
		"by_status": by_status,
	}


func _get_level_up_card_snapshot() -> Dictionary:
	var card_ids: Array[String] = []
	for raw_key in GC.LEVEL_UP_CARDS.keys():
		card_ids.append(String(raw_key))
	for raw_card in GC.EXTRA_LEVEL_UP_CARDS:
		var card: Dictionary = raw_card
		card_ids.append(String(card.get("id", "")))
	card_ids.sort()
	var cards := {}
	for card_id in card_ids:
		cards[card_id] = _measure_level_card_delta(card_id)
	return cards


func _get_level_up_rarity_chances_by_luck() -> Dictionary:
	var result := {}
	for luck in [0, 10, 20, 30]:
		var chances: Dictionary = _game_state.call("get_level_up_rarity_chances", luck)
		result[str(luck)] = chances
	return result


func _get_level_up_card_rarity_effect_values() -> Dictionary:
	var result := {}
	var card_ids: Array[String] = []
	for raw_key in GC.LEVEL_UP_CARDS.keys():
		card_ids.append(String(raw_key))
	for raw_card in GC.EXTRA_LEVEL_UP_CARDS:
		var card: Dictionary = raw_card
		card_ids.append(String(card.get("id", "")))
	card_ids.sort()
	for card_id in card_ids:
		result[card_id] = {}
		for raw_rarity in GC.LEVEL_UP_CARD_RARITIES:
			var rarity: Dictionary = raw_rarity
			var rarity_id := String(rarity.get("id", "normal"))
			var measurement := _measure_level_card_delta(card_id, rarity_id, false)
			result[card_id][rarity_id] = {
				"multiplier": float(rarity.get("multiplier", 1.0)),
				"effect_description": String(_game_state.call("get_level_up_card_effect_description", card_id, rarity_id)),
				"delta": measurement.get("delta", {}),
			}
	return result


func _get_level_up_choice_sample() -> Dictionary:
	_game_state.call("reset_run")
	var choices: Array = _game_state.call("generate_level_up_card_choices", 3)
	var seen := {}
	var has_duplicate_exact := false
	var rows: Array[Dictionary] = []
	for raw_choice in choices:
		var choice: Dictionary = raw_choice
		var card_id := String(choice.get("id", ""))
		var rarity_id := String(choice.get("rarity_id", "normal"))
		var key := "%s:%s" % [card_id, rarity_id]
		if seen.has(key):
			has_duplicate_exact = true
		seen[key] = true
		rows.append({
			"card_id": card_id,
			"rarity_id": rarity_id,
			"title": String(choice.get("title", "")),
			"desc": String(choice.get("desc", "")),
		})
	return {
		"choices": rows,
		"has_duplicate_card_and_rarity": has_duplicate_exact,
	}


func _measure_level_card_delta(card_id: String, rarity_id: String = "normal", include_full_stats: bool = true) -> Dictionary:
	_game_state.call("reset_run")
	_game_state.set("player_current_xp", 1000)
	var before := _read_level_stats()
	_game_state.call("apply_level_up_card", card_id, rarity_id)
	var after := _read_level_stats()
	var result := {
		"delta": _diff_stats(before, after),
		"doc_normal_target": LEVEL_UP_NORMAL_TARGETS.get(card_id, {}),
		"rarity_id": rarity_id,
	}
	if include_full_stats:
		result["before"] = before
		result["after"] = after
	return result


func _read_level_stats() -> Dictionary:
	return {
		"attack_damage": int(_game_state.call("get_attack_damage")),
		"attack_cooldown": float(_game_state.call("get_attack_cooldown_duration")),
		"attacks_per_second": float(_game_state.call("get_attacks_per_second")),
		"attack_range": float(_game_state.call("get_attack_range_multiplier")),
		"max_health": int(_game_state.call("get_player_max_health")),
		"defense": int(_game_state.call("get_defense")),
		"hp_regen": float(_game_state.call("get_hp_regen_stat")),
		"move_speed": float(_game_state.call("get_move_speed")),
		"jump_power": float(_game_state.call("get_jump_power")),
		"mining_damage": int(_game_state.call("get_mining_damage")),
		"mining_cooldown": float(_game_state.call("get_mining_cooldown_duration")),
		"mines_per_second": float(_game_state.call("get_mines_per_second")),
		"mining_range": float(_game_state.call("get_mining_range_multiplier")),
		"crit_chance": float(_game_state.call("get_critical_chance_ratio")),
		"battery_recovery": float(_game_state.call("get_battery_recovery_per_second")),
		"luck": float(_game_state.call("get_luck")),
		"interest_rate": float(_game_state.call("get_interest_rate")),
	}


func _diff_stats(before: Dictionary, after: Dictionary) -> Dictionary:
	var delta := {}
	for key in before.keys():
		var diff := float(after[key]) - float(before[key])
		if absf(diff) > 0.0001:
			delta[key] = diff
	return delta
