extends RefCounted
class_name ShopItemCatalog

const RESOURCE_CATALOG_PATH := "res://data/items/ShopItemCatalog.tres"
const DRAFT_PATH := "res://scripts/data/ShopItemCatalogDraft.gd"
const ATTACK_MODULE_STYLE_RESOLVER := preload("res://scripts/data/AttackModuleStyleResolver.gd")
const CATEGORY_ATTACK_MODULE: StringName = &"attack_module"
const CATEGORY_FUNCTION_MODULE: StringName = &"function_module"
const CATEGORY_ENHANCE_MODULE: StringName = &"enhance_module"
const CATEGORY_WEAPON: StringName = &"weapon"
const CATEGORY_DRONE: StringName = &"drone"
const CATEGORY_DRONE_PROTOCOL: StringName = &"drone_protocol"
const CATEGORY_PASSIVE_MODULE: StringName = &"passive_module"
const CATEGORY_PART: StringName = &"part"
const CATEGORY_ARTIFACT: StringName = &"artifact"
const ATTACK_MODULE_OFFER_SEPARATOR := "@"
const LEGACY_BASE_ATTACK_COOLDOWN_SECONDS := 0.30
const ATTACK_MODULE_SHOP_GRADES := ["D", "C", "B", "A", "S"]
const ATTACK_MODULE_FALLBACK_PRICES := {
	"D": 15,
	"C": 30,
	"B": 60,
	"A": 120,
	"S": 240,
}

# 상점 랭크 분포는 현재 Day/Stage를 먼저 보고, 행운은 그 분포를 살짝 보정만 한다.
const STAGE_RANK_WEIGHT_TABLE := [
	{"from": 1, "to": 3, "weights": {"D": 62.0, "C": 28.0, "B": 10.0, "A": 0.0, "S": 0.0}},
	{"from": 4, "to": 6, "weights": {"D": 56.0, "C": 30.0, "B": 13.0, "A": 1.0, "S": 0.0}},
	{"from": 7, "to": 10, "weights": {"D": 48.0, "C": 32.0, "B": 18.0, "A": 2.0, "S": 0.0}},
	{"from": 11, "to": 15, "weights": {"D": 40.0, "C": 33.0, "B": 23.0, "A": 4.0, "S": 0.0}},
	{"from": 16, "to": 20, "weights": {"D": 32.0, "C": 34.0, "B": 27.0, "A": 6.0, "S": 1.0}},
	{"from": 21, "to": 24, "weights": {"D": 25.0, "C": 35.0, "B": 31.0, "A": 8.0, "S": 1.0}},
	{"from": 25, "to": 29, "weights": {"D": 18.0, "C": 35.0, "B": 35.0, "A": 10.0, "S": 2.0}},
	{"from": 30, "to": 30, "weights": {"D": 12.0, "C": 34.0, "B": 38.0, "A": 13.0, "S": 3.0}},
]

var _items_by_id: Dictionary = {}
var _items_by_category: Dictionary = {}
var _catalog_source = null


func _init() -> void:
	_rebuild_cache()


func get_all_items() -> Array[Dictionary]:
	_rebuild_cache()
	var items: Array[Dictionary] = []
	for raw_item in _get_source_items():
		var item: Dictionary = raw_item
		items.append(normalize_item_definition(item))
	return items


func get_item_definition(item_id: StringName) -> Dictionary:
	_rebuild_cache()
	if _items_by_id.has(item_id):
		return (_items_by_id[item_id] as Dictionary).duplicate(true)
	var offer_data := parse_attack_module_offer_item_id(String(item_id))
	if not offer_data.is_empty():
		var module_id := StringName(String(offer_data.get("module_id", "")))
		var grade := String(offer_data.get("grade", "D"))
		if _items_by_id.has(module_id):
			var base_item: Dictionary = _items_by_id[module_id]
			return _build_attack_module_offer_definition(base_item, grade)
	return {}


func get_items_by_category(category: StringName) -> Array[Dictionary]:
	_rebuild_cache()
	var items: Array[Dictionary] = []
	var categories: Array[StringName] = [category]
	if not _items_by_category.has(category):
		categories = _get_compatible_query_categories(category)
	for query_category in categories:
		if not _items_by_category.has(query_category):
			continue
		for raw_item in _items_by_category[query_category]:
			var item: Dictionary = raw_item
			items.append(normalize_item_definition(item))
	return items


func get_reward_candidate_items_for_rank(rank: String) -> Array[Dictionary]:
	_rebuild_cache()
	var normalized_rank := rank.strip_edges().to_upper()
	var candidates: Array[Dictionary] = []
	for raw_item in get_all_items():
		var item: Dictionary = raw_item
		if not bool(item.get("shop_enabled", true)):
			continue
		var category := String(item.get("item_category", ""))
		if category != String(CATEGORY_WEAPON) and category != String(CATEGORY_PART) and category != String(CATEGORY_ARTIFACT):
			continue
		if category == String(CATEGORY_WEAPON):
			var offer := _build_reward_attack_module_candidate(item, normalized_rank)
			if not offer.is_empty():
				candidates.append(offer)
			continue
		if String(item.get("rank", "D")).strip_edges().to_upper() == normalized_rank:
			candidates.append(item)
	return candidates


func has_item(item_id: StringName) -> bool:
	_rebuild_cache()
	if _items_by_id.has(item_id):
		return true
	var offer_data := parse_attack_module_offer_item_id(String(item_id))
	return not offer_data.is_empty() and _items_by_id.has(StringName(String(offer_data.get("module_id", ""))))


func normalize_item_definition(item: Dictionary) -> Dictionary:
	var normalized := item.duplicate(true)
	normalized["legacy_item_category"] = String(normalized.get("item_category", ""))
	if String(normalized.get("module_type", "")).is_empty() and not String(normalized.get("weapon_type", "")).is_empty():
		normalized["module_type"] = String(normalized.get("weapon_type", ""))
	ATTACK_MODULE_STYLE_RESOLVER.normalize_item_dictionary(normalized)
	_apply_reworked_item_category(normalized)
	_apply_equipment_schema_metadata(normalized)
	if String(normalized.get("item_category", "")) == "weapon":
		if String(normalized.get("weapon_type", "")).is_empty():
			normalized["weapon_type"] = String(normalized.get("module_type", ""))
		normalized["module_base_damage"] = int(normalized.get("module_base_damage", 0))
		normalized["base_damage_by_grade"] = _normalize_base_damage_by_grade(normalized.get("base_damage_by_grade", {}))
		normalized["price_by_grade"] = _normalize_price_by_grade(normalized.get("price_by_grade", {}))
	var effect_type := String(normalized.get("effect_type", "none"))
	var effect_values: Dictionary = {}
	if normalized.get("effect_values", {}) is Dictionary:
		effect_values = (normalized.get("effect_values", {}) as Dictionary).duplicate(true)
	_normalize_damage_effect_values(effect_values)
	normalized["effect_type"] = effect_type
	normalized["effect_values"] = effect_values
	normalized["conditions"] = _normalize_dictionary_array(normalized.get("conditions", []))
	var effects := _normalize_dictionary_array(normalized.get("effects", []))
	_normalize_damage_effect_entries(effects)
	if effects.is_empty() and not effect_values.is_empty():
		for raw_key in effect_values.keys():
			effects.append({
				"type": String(raw_key),
				"value": effect_values[raw_key],
			})
	normalized["effects"] = effects
	normalized["apply_timing"] = _get_default_apply_timing(
		String(normalized.get("apply_timing", "")),
		effect_type
	)
	normalized["tags"] = Array(normalized.get("tags", []))
	_apply_damage_percent_display_text(normalized)
	return normalized


func _apply_equipment_schema_metadata(item: Dictionary) -> void:
	var equipment_category := String(item.get("equipment_category", "")).strip_edges()
	if equipment_category.is_empty():
		equipment_category = _infer_equipment_category(item)
	item["equipment_category"] = equipment_category
	var attribute := String(item.get("attribute", "")).strip_edges()
	var inferred_attribute := _infer_equipment_attribute(item)
	if attribute.is_empty() or (attribute == "none" and inferred_attribute != "none"):
		attribute = inferred_attribute
	item["attribute"] = attribute if not attribute.is_empty() else "none"
	var attack_type := String(item.get("attack_type", "")).strip_edges()
	var inferred_attack_type := _infer_equipment_attack_type(item)
	if attack_type.is_empty() or (attack_type == "support" and inferred_attack_type != "support"):
		attack_type = inferred_attack_type
	item["attack_type"] = attack_type if not attack_type.is_empty() else "support"
	if equipment_category == String(CATEGORY_WEAPON):
		var weapon_base_cooldown := float(item.get("weapon_base_cooldown", 0.0))
		item["weapon_base_cooldown"] = weapon_base_cooldown if weapon_base_cooldown > 0.0 else LEGACY_BASE_ATTACK_COOLDOWN_SECONDS
	if equipment_category == String(CATEGORY_DRONE_PROTOCOL):
		var protocol_base_damage := int(item.get("protocol_base_damage", 0))
		if protocol_base_damage <= 0 and String(item.get("module_type", "")) == "mechanic":
			protocol_base_damage = int(item.get("module_base_damage", 0))
		item["protocol_base_damage"] = maxi(protocol_base_damage, 0)
		var protocol_base_cooldown := float(item.get("protocol_base_cooldown", 0.0))
		if protocol_base_cooldown <= 0.0:
			protocol_base_cooldown = _infer_protocol_base_cooldown(item)
		item["protocol_base_cooldown"] = maxf(protocol_base_cooldown, 0.0)
		if String(item.get("protocol_behavior", "")).is_empty():
			item["protocol_behavior"] = _infer_protocol_behavior(item)
		if String(item.get("targeting", "")).is_empty():
			item["targeting"] = String(item.get("mechanic_targeting", "nearest"))


func _infer_equipment_category(item: Dictionary) -> String:
	var category := String(item.get("item_category", ""))
	var legacy_category := String(item.get("legacy_item_category", category))
	if legacy_category == "function_module":
		return String(CATEGORY_DRONE_PROTOCOL)
	if legacy_category == "enhance_module":
		return String(CATEGORY_PASSIVE_MODULE)
	if category == "weapon" and String(item.get("module_type", "")) == "mechanic":
		return String(CATEGORY_DRONE_PROTOCOL)
	match category:
		"attack_module", "weapon":
			return String(CATEGORY_WEAPON)
		"drone":
			return String(CATEGORY_DRONE)
		"function_module", "drone_protocol":
			return String(CATEGORY_DRONE_PROTOCOL)
		"enhance_module", "part", "artifact", "passive_module":
			return String(CATEGORY_PASSIVE_MODULE)
	return ""


func _infer_equipment_attribute(item: Dictionary) -> String:
	var tags: Array = item.get("tags", [])
	for attribute_id in ["electric", "fire", "physical", "energy", "chemical"]:
		if tags.has(attribute_id):
			return attribute_id
	var attack_style := String(item.get("attack_style", ""))
	if attack_style == "laser":
		return "energy"
	if String(item.get("effect_type", "")) == "combat_drone":
		return "physical"
	if String(item.get("equipment_category", "")) == String(CATEGORY_WEAPON):
		return "physical"
	return "none"


func _infer_equipment_attack_type(item: Dictionary) -> String:
	var attack_style := String(item.get("attack_style", ""))
	var effect_type := String(item.get("effect_type", ""))
	if attack_style == "laser":
		return "beam"
	if attack_style in ["revolver", "shotgun", "sniper", "rifle", "drone"]:
		return "projectile"
	if effect_type == "combat_drone":
		return "projectile"
	if effect_type == "aura_damage":
		return "area"
	if String(item.get("equipment_category", "")) == String(CATEGORY_WEAPON):
		return "area"
	return "support"


func _infer_protocol_behavior(item: Dictionary) -> String:
	var effect_type := String(item.get("effect_type", ""))
	if not effect_type.is_empty() and effect_type != "none":
		return effect_type
	if String(item.get("module_type", "")) == "mechanic":
		return "auto_attack"
	return ""


func _infer_protocol_base_cooldown(item: Dictionary) -> float:
	var effect_values: Dictionary = item.get("effect_values", {}) as Dictionary
	if effect_values.has("sand_remove_interval_sec"):
		return float(effect_values["sand_remove_interval_sec"])
	if effect_values.has("tick_interval_sec"):
		return float(effect_values["tick_interval_sec"])
	if String(item.get("module_type", "")) == "mechanic":
		return LEGACY_BASE_ATTACK_COOLDOWN_SECONDS / maxf(float(item.get("attack_speed_multiplier", 1.0)), 0.01)
	return 0.0


func _apply_reworked_item_category(item: Dictionary) -> void:
	var category := String(item.get("item_category", ""))
	match category:
		"attack_module":
			item["item_category"] = "weapon"
			item["weapon_type"] = String(item.get("module_type", ""))
		"function_module":
			item["item_category"] = "drone_protocol"
		"enhance_module":
			item["item_category"] = "passive_module"


func _get_compatible_query_categories(category: StringName) -> Array[StringName]:
	match String(category):
		"attack_module":
			var weapon_categories: Array[StringName] = [&"weapon"]
			return weapon_categories
		"function_module":
			var protocol_categories: Array[StringName] = [&"drone_protocol"]
			return protocol_categories
		"enhance_module":
			var passive_categories: Array[StringName] = [&"passive_module"]
			return passive_categories
	var categories: Array[StringName] = [category]
	return categories


func _normalize_base_damage_by_grade(raw_value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if not raw_value is Dictionary:
		return result
	var raw_dictionary: Dictionary = raw_value
	for raw_grade in raw_dictionary.keys():
		var grade := String(raw_grade).strip_edges().to_upper()
		if grade.is_empty():
			continue
		var damage := int(raw_dictionary[raw_grade])
		if damage <= 0:
			continue
		result[grade] = damage
	return result


func _normalize_price_by_grade(raw_value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if not raw_value is Dictionary:
		return result
	var raw_dictionary: Dictionary = raw_value
	for raw_grade in raw_dictionary.keys():
		var grade := String(raw_grade).strip_edges().to_upper()
		if grade.is_empty():
			continue
		var price := int(raw_dictionary[raw_grade])
		if price <= 0:
			continue
		result[grade] = price
	return result


func _apply_damage_percent_display_text(item: Dictionary) -> void:
	var damage_percent = null
	var effects: Array = item.get("effects", [])
	for raw_effect in effects:
		var effect: Dictionary = raw_effect
		if String(effect.get("type", "")) != "damage_percent":
			continue
		damage_percent = float(effect.get("value", 0.0))
		break
	if damage_percent == null:
		return
	var percent_text := "%d%%" % int(round(float(damage_percent) * 100.0))
	if String(item.get("effect_type", "")) == "conditional_stat_bonus":
		item["short_desc"] = "Conditional damage +" + percent_text
		item["desc"] = "When this item's condition is met, final damage increases by " + percent_text + "."
	else:
		item["short_desc"] = "Damage +" + percent_text
		item["desc"] = "Increases all final damage by " + percent_text + "."


func _normalize_damage_effect_values(effect_values: Dictionary) -> void:
	if effect_values.has("attack_damage_flat"):
		effect_values["damage_percent"] = float(effect_values.get("damage_percent", 0.0)) + float(effect_values["attack_damage_flat"]) * 0.01
		effect_values.erase("attack_damage_flat")
	if effect_values.has("attack_damage_percent"):
		effect_values["damage_percent"] = float(effect_values.get("damage_percent", 0.0)) + float(effect_values["attack_damage_percent"])
		effect_values.erase("attack_damage_percent")


func _normalize_damage_effect_entries(effects: Array[Dictionary]) -> void:
	for index in range(effects.size()):
		var effect: Dictionary = effects[index]
		match String(effect.get("type", "")):
			"attack_damage_flat":
				effect["type"] = "damage_percent"
				effect["value"] = float(effect.get("value", 0.0)) * 0.01
			"attack_damage_percent":
				effect["type"] = "damage_percent"
		effects[index] = effect


func roll_shop_item_ids(
	rng: RandomNumberGenerator,
	desired_count: int,
	context: Dictionary = {}
) -> PackedStringArray:
	_rebuild_cache()
	var rolled_ids := PackedStringArray()
	var used_ids: Dictionary = {}
	for _slot_index in range(desired_count):
		rolled_ids.append("")
	_apply_locked_shop_slots(rolled_ids, used_ids, desired_count, context)
	var pool: Array[Dictionary] = []
	for raw_item in get_all_items():
		var item: Dictionary = raw_item
		if not bool(item.get("shop_enabled", true)):
			continue
		if _should_skip_item_for_roll(item, context):
			continue
		if String(item.get("item_category", "")) == String(CATEGORY_WEAPON):
			var module_id := String(item.get("item_id", ""))
			if used_ids.has(_get_attack_module_used_key(module_id)):
				continue
			for grade in ATTACK_MODULE_SHOP_GRADES:
				if not _can_offer_attack_module_grade(item, grade):
					continue
				var offer := _build_attack_module_offer_definition(item, grade)
				if not offer.is_empty():
					pool.append(offer)
			continue
		var item_id := String(item.get("item_id", ""))
		if used_ids.has(item_id):
			continue
		pool.append(item)
	while _has_empty_shop_roll_slot(rolled_ids) and not pool.is_empty():
		var picked_index := _pick_weighted_index(rng, pool, context)
		if picked_index < 0:
			break
		var picked_item: Dictionary = pool[picked_index]
		var item_id := String(picked_item.get("item_id", ""))
		var used_key := _get_shop_roll_used_key(item_id)
		if not item_id.is_empty() and not used_ids.has(used_key):
			var empty_slot_index := _find_empty_shop_roll_slot(rolled_ids)
			if empty_slot_index < 0:
				break
			rolled_ids[empty_slot_index] = item_id
			used_ids[used_key] = true
		pool.remove_at(picked_index)
	return _compact_shop_roll_ids(rolled_ids)


func _apply_locked_shop_slots(
	rolled_ids: PackedStringArray,
	used_ids: Dictionary,
	desired_count: int,
	context: Dictionary
) -> void:
	if not context.has("shop_locked_slots") or not (context["shop_locked_slots"] is Dictionary):
		return
	var locked_slots: Dictionary = context["shop_locked_slots"]
	for raw_slot_index in locked_slots.keys():
		var slot_index := int(raw_slot_index)
		if slot_index < 0 or slot_index >= desired_count:
			continue
		var raw_item_id = locked_slots[raw_slot_index]
		if raw_item_id is bool:
			continue
		var item_id := String(raw_item_id)
		var used_key := _get_shop_roll_used_key(item_id)
		if item_id.is_empty() or used_ids.has(used_key):
			continue
		var locked_item := get_item_definition(StringName(item_id))
		if locked_item.is_empty() or not bool(locked_item.get("shop_enabled", true)):
			continue
		rolled_ids[slot_index] = item_id
		used_ids[used_key] = true


func _has_empty_shop_roll_slot(rolled_ids: PackedStringArray) -> bool:
	return _find_empty_shop_roll_slot(rolled_ids) >= 0


func _find_empty_shop_roll_slot(rolled_ids: PackedStringArray) -> int:
	for slot_index in range(rolled_ids.size()):
		if String(rolled_ids[slot_index]).is_empty():
			return slot_index
	return -1


func _compact_shop_roll_ids(rolled_ids: PackedStringArray) -> PackedStringArray:
	var compact_ids := PackedStringArray()
	for raw_item_id in rolled_ids:
		var item_id := String(raw_item_id)
		if item_id.is_empty():
			continue
		compact_ids.append(item_id)
	return compact_ids


func _should_skip_item_for_roll(_item: Dictionary, _context: Dictionary) -> bool:
	# 보유 여부는 구매 가능성 판단에만 쓰고, 상점 출현 풀에서는 제외하지 않는다.
	return false


func _pick_weighted_index(
	rng: RandomNumberGenerator,
	items: Array[Dictionary],
	context: Dictionary
) -> int:
	var total_weight := 0.0
	var weights: Array[float] = []
	for item in items:
		var weight := _get_shop_weight(item, context)
		weights.append(weight)
		total_weight += weight
	if total_weight <= 0.0:
		return -1
	var threshold := rng.randf_range(0.0, total_weight)
	var running_weight := 0.0
	for index in range(items.size()):
		running_weight += weights[index]
		if threshold <= running_weight:
			return index
	return items.size() - 1


func _get_shop_weight(item: Dictionary, context: Dictionary) -> float:
	var rank := String(item.get("rank", "D"))
	var stage_number := int(context.get("stage_number", context.get("current_day", 1)))
	var luck := float(context.get("luck", 0.0))
	var rank_weight := _get_rank_weight(rank, stage_number)
	if rank_weight <= 0.0:
		return 0.0
	return rank_weight * _get_luck_multiplier_for_rank(rank, luck) * _get_item_modifier_weight(item)


static func make_attack_module_offer_item_id(module_id: String, grade: String) -> String:
	return "%s%s%s" % [module_id, ATTACK_MODULE_OFFER_SEPARATOR, grade]


static func parse_attack_module_offer_item_id(item_id: String) -> Dictionary:
	var separator_index := item_id.rfind(ATTACK_MODULE_OFFER_SEPARATOR)
	if separator_index <= 0 or separator_index >= item_id.length() - 1:
		return {}
	var module_id := item_id.substr(0, separator_index)
	var grade := item_id.substr(separator_index + 1).strip_edges().to_upper()
	if not ATTACK_MODULE_SHOP_GRADES.has(grade):
		return {}
	return {
		"module_id": module_id,
		"grade": grade,
	}


func _build_attack_module_offer_definition(base_item: Dictionary, grade: String) -> Dictionary:
	var offer := base_item.duplicate(true)
	var module_id := String(base_item.get("module_id", base_item.get("item_id", "")))
	if module_id.is_empty():
		return {}
	var normalized_grade := grade.strip_edges().to_upper()
	if not ATTACK_MODULE_SHOP_GRADES.has(normalized_grade):
		normalized_grade = "D"
	offer["module_id"] = module_id
	offer["item_id"] = make_attack_module_offer_item_id(module_id, normalized_grade)
	offer["rank"] = normalized_grade
	offer["grade"] = normalized_grade
	offer["price_gold"] = _get_attack_module_price_for_grade(base_item, normalized_grade)
	offer["stackable"] = false
	offer["max_stack"] = 1
	offer["equip_slot"] = "weapon"
	offer["is_equippable"] = true
	return offer


func _can_offer_attack_module_grade(item: Dictionary, grade: String) -> bool:
	var base_damage_by_grade: Dictionary = item.get("base_damage_by_grade", {}) as Dictionary
	if int(base_damage_by_grade.get(grade, 0)) <= 0:
		return false
	return _get_attack_module_price_for_grade(item, grade) > 0


func _build_reward_attack_module_candidate(item: Dictionary, rank: String) -> Dictionary:
	if _can_offer_attack_module_grade(item, rank):
		return _build_attack_module_offer_definition(item, rank)
	if String(item.get("rank", "D")).strip_edges().to_upper() == rank:
		return item.duplicate(true)
	return {}


func _get_attack_module_price_for_grade(item: Dictionary, grade: String) -> int:
	var price_by_grade: Dictionary = item.get("price_by_grade", {}) as Dictionary
	var price := int(price_by_grade.get(grade, 0))
	if price > 0:
		return price
	return int(ATTACK_MODULE_FALLBACK_PRICES.get(grade, 15))


func _get_shop_roll_used_key(item_id: String) -> String:
	var offer_data := parse_attack_module_offer_item_id(item_id)
	if offer_data.is_empty():
		return item_id
	return _get_attack_module_used_key(String(offer_data.get("module_id", "")))


func _get_attack_module_used_key(module_id: String) -> String:
	return "attack_module:%s" % module_id


func _get_rank_weights_for_stage(stage_number: int) -> Dictionary:
	var safe_stage := maxi(stage_number, 1)
	for raw_entry in STAGE_RANK_WEIGHT_TABLE:
		var entry: Dictionary = raw_entry
		if safe_stage < int(entry["from"]) or safe_stage > int(entry["to"]):
			continue
		return (entry["weights"] as Dictionary).duplicate(true)
	return (STAGE_RANK_WEIGHT_TABLE.back()["weights"] as Dictionary).duplicate(true)


func _get_rank_weight(rank: String, stage_number: int) -> float:
	var rank_weights := _get_rank_weights_for_stage(stage_number)
	return float(rank_weights.get(rank, 0.0))


func _get_luck_multiplier_for_rank(rank: String, luck: float) -> float:
	match rank:
		"D":
			return maxf(0.80, 1.0 - 0.0015 * luck)
		"C":
			return maxf(0.90, 1.0 - 0.0005 * luck)
		"B":
			return 1.0 + 0.0015 * luck
		"A":
			return 1.0 + 0.0050 * luck
		"S":
			return 1.0 + 0.0100 * luck
	return 1.0


func _get_item_modifier_weight(item: Dictionary) -> float:
	var modifier := float(item.get("shop_spawn_weight", 1.0))
	if modifier <= 0.0:
		return 1.0
	return modifier


func _rebuild_cache() -> void:
	if not _items_by_id.is_empty():
		return
	_items_by_id.clear()
	_items_by_category.clear()
	for raw_item in _get_source_items():
		var item: Dictionary = raw_item
		var item_id := StringName(String(item.get("item_id", "")))
		if item_id == StringName():
			continue
		var normalized_item := normalize_item_definition(item)
		_items_by_id[item_id] = normalized_item
		var category := StringName(String(normalized_item.get("item_category", "")))
		if not _items_by_category.has(category):
			_items_by_category[category] = []
		(_items_by_category[category] as Array).append(normalized_item)


func _get_source_items() -> Array[Dictionary]:
	var source = _get_catalog_source()
	if source == null:
		return []
	if source is Resource and source.has_method("get_all_item_dictionaries"):
		return source.get_all_item_dictionaries()
	if source.has_method("get_all_shop_items"):
		var items: Array[Dictionary] = []
		for raw_item in source.get_all_shop_items():
			var item: Dictionary = raw_item
			items.append(item.duplicate(true))
		return items
	return []


func _get_catalog_source():
	if _catalog_source != null:
		return _catalog_source
	if ResourceLoader.exists(RESOURCE_CATALOG_PATH):
		_catalog_source = load(RESOURCE_CATALOG_PATH)
		return _catalog_source
	_catalog_source = load(DRAFT_PATH)
	return _catalog_source


func _normalize_dictionary_array(raw_value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not raw_value is Array:
		return result
	for raw_entry in raw_value:
		if not raw_entry is Dictionary:
			continue
		var entry: Dictionary = raw_entry
		result.append(entry.duplicate(true))
	return result


func _get_default_apply_timing(raw_timing: String, effect_type: String) -> String:
	if not raw_timing.is_empty():
		return raw_timing
	if effect_type == "conditional_stat_bonus":
		return "stat_query"
	return "on_purchase"
