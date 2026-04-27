extends RefCounted
class_name ShopItemCatalog

const RESOURCE_CATALOG_PATH := "res://data/items/ShopItemCatalog.tres"
const DRAFT_PATH := "res://scripts/data/ShopItemCatalogDraft.gd"
const CATEGORY_ATTACK_MODULE: StringName = &"attack_module"
const CATEGORY_FUNCTION_MODULE: StringName = &"function_module"
const CATEGORY_ENHANCE_MODULE: StringName = &"enhance_module"

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
	return {}


func get_items_by_category(category: StringName) -> Array[Dictionary]:
	_rebuild_cache()
	if not _items_by_category.has(category):
		return []
	var items: Array[Dictionary] = []
	for raw_item in _items_by_category[category]:
		var item: Dictionary = raw_item
		items.append(normalize_item_definition(item))
	return items


func has_item(item_id: StringName) -> bool:
	_rebuild_cache()
	return _items_by_id.has(item_id)


func normalize_item_definition(item: Dictionary) -> Dictionary:
	var normalized := item.duplicate(true)
	_normalize_attack_module_style_fields(normalized)
	var effect_type := String(normalized.get("effect_type", "none"))
	var effect_values: Dictionary = {}
	if normalized.get("effect_values", {}) is Dictionary:
		effect_values = (normalized.get("effect_values", {}) as Dictionary).duplicate(true)
	normalized["effect_type"] = effect_type
	normalized["effect_values"] = effect_values
	normalized["conditions"] = _normalize_dictionary_array(normalized.get("conditions", []))
	var effects := _normalize_dictionary_array(normalized.get("effects", []))
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
	return normalized


func _normalize_attack_module_style_fields(item: Dictionary) -> void:
	if String(item.get("item_category", "")) != "attack_module":
		return
	var module_type := String(item.get("module_type", ""))
	var attack_style := String(item.get("attack_style", ""))
	if attack_style.is_empty():
		attack_style = "slash" if module_type == "melee" else ""
	if module_type == "ranged":
		attack_style = _normalize_ranged_attack_style_alias(attack_style)
	item["attack_style"] = attack_style
	var style_defaults := _get_attack_style_defaults(module_type, attack_style)
	item["effect_style"] = String(item.get("effect_style", style_defaults.get("effect_style", "")))
	item["hit_shape"] = String(item.get("hit_shape", style_defaults.get("hit_shape", "rectangle")))
	item["base_shape_units_x"] = float(item.get(
		"base_shape_units_x",
		style_defaults.get("base_shape_units_x", item.get("range_width_u", 0.0))
	))
	item["base_shape_units_y"] = float(item.get(
		"base_shape_units_y",
		style_defaults.get("base_shape_units_y", item.get("range_height_u", 0.0))
	))
	item["range_growth_width_scale"] = float(item.get(
		"range_growth_width_scale",
		style_defaults.get("range_growth_width_scale", 1.0)
	))
	item["range_growth_height_scale"] = float(item.get(
		"range_growth_height_scale",
		style_defaults.get("range_growth_height_scale", 0.0)
	))
	if module_type == "ranged":
		_normalize_ranged_attack_module_fields(item, style_defaults)


func _get_attack_style_defaults(module_type: String, attack_style: String) -> Dictionary:
	if module_type == "ranged":
		return _get_ranged_attack_style_defaults(attack_style)
	if module_type != "melee":
		return {}
	match attack_style:
		"stab":
			return {
				"effect_style": "short_stab",
				"base_shape_units_x": 0.5,
				"base_shape_units_y": 0.5,
				"range_growth_width_scale": 1.0,
				"range_growth_height_scale": 0.0,
				"hit_shape": "rectangle",
			}
		"pierce":
			return {
				"effect_style": "long_pierce",
				"base_shape_units_x": 2.5,
				"base_shape_units_y": 0.5,
				"range_growth_width_scale": 1.0,
				"range_growth_height_scale": 0.0,
				"hit_shape": "rectangle",
			}
		"cleave":
			return {
				"effect_style": "big_cleave",
				"base_shape_units_x": 1.5,
				"base_shape_units_y": 1.0,
				"range_growth_width_scale": 1.0,
				"range_growth_height_scale": 0.2,
				"hit_shape": "rectangle",
			}
		"smash":
			return {
				"effect_style": "blunt_smash",
				"base_shape_units_x": 1.0,
				"base_shape_units_y": 1.0,
				"range_growth_width_scale": 1.0,
				"range_growth_height_scale": 0.1,
				"hit_shape": "rectangle",
			}
		_:
			return {
				"effect_style": "slash_arc",
				"base_shape_units_x": 1.0,
				"base_shape_units_y": 1.0,
				"range_growth_width_scale": 1.0,
				"range_growth_height_scale": 0.1,
				"hit_shape": "rectangle",
			}


func _normalize_ranged_attack_style_alias(attack_style: String) -> String:
	match attack_style:
		"", "single":
			return "rifle"
		"spread":
			return "shotgun"
		"pierce":
			return "sniper"
		_:
			return attack_style


func _normalize_ranged_attack_module_fields(item: Dictionary, style_defaults: Dictionary) -> void:
	item["range_units"] = float(item.get("range_units", item.get("range_width_u", 0.0)))
	item["range_growth_scale"] = float(item.get("range_growth_scale", style_defaults.get("range_growth_scale", 1.0)))
	item["projectile_count"] = int(item.get("projectile_count", style_defaults.get("projectile_count", 1)))
	item["spread_angle"] = float(item.get("spread_angle", item.get("projectile_spread_degrees", style_defaults.get("spread_angle", 0.0))))
	item["pierce_count"] = int(item.get("pierce_count", item.get("projectile_pierce_count", style_defaults.get("pierce_count", 0))))
	item["is_hitscan"] = bool(item.get("is_hitscan", item.get("projectile_hit_scan", style_defaults.get("is_hitscan", false))))
	item["projectile_visual_size_x"] = float(item.get("projectile_visual_size_x", item.get("projectile_size_x", style_defaults.get("projectile_visual_size_x", 18.0))))
	item["projectile_visual_size_y"] = float(item.get("projectile_visual_size_y", item.get("projectile_size_y", style_defaults.get("projectile_visual_size_y", 6.0))))
	item["range_width_u"] = float(item.get("range_width_u", item["range_units"]))
	item["projectile_spread_degrees"] = float(item.get("projectile_spread_degrees", item["spread_angle"]))
	item["projectile_pierce_count"] = int(item.get("projectile_pierce_count", item["pierce_count"]))
	item["projectile_hit_scan"] = bool(item.get("projectile_hit_scan", item["is_hitscan"]))
	item["projectile_size_x"] = float(item.get("projectile_size_x", item["projectile_visual_size_x"]))
	item["projectile_size_y"] = float(item.get("projectile_size_y", item["projectile_visual_size_y"]))


func _get_ranged_attack_style_defaults(attack_style: String) -> Dictionary:
	match _normalize_ranged_attack_style_alias(attack_style):
		"revolver":
			return {
				"effect_style": "revolver_projectile",
				"range_growth_scale": 1.0,
				"projectile_count": 1,
				"spread_angle": 0.0,
				"pierce_count": 0,
				"is_hitscan": false,
				"projectile_visual_size_x": 16.0,
				"projectile_visual_size_y": 6.0,
			}
		"shotgun":
			return {
				"effect_style": "shotgun_spread",
				"range_growth_scale": 1.0,
				"projectile_count": 3,
				"spread_angle": 26.0,
				"pierce_count": 0,
				"is_hitscan": false,
				"projectile_visual_size_x": 14.0,
				"projectile_visual_size_y": 5.0,
			}
		"sniper":
			return {
				"effect_style": "sniper_projectile",
				"range_growth_scale": 1.0,
				"projectile_count": 1,
				"spread_angle": 0.0,
				"pierce_count": 1,
				"is_hitscan": false,
				"projectile_visual_size_x": 20.0,
				"projectile_visual_size_y": 5.0,
			}
		"laser":
			return {
				"effect_style": "laser_beam",
				"range_growth_scale": 1.0,
				"projectile_count": 0,
				"spread_angle": 0.0,
				"pierce_count": 0,
				"is_hitscan": true,
				"projectile_visual_size_x": 8.0,
				"projectile_visual_size_y": 4.0,
			}
		_:
			return {
				"effect_style": "rifle_projectile",
				"range_growth_scale": 1.0,
				"projectile_count": 1,
				"spread_angle": 0.0,
				"pierce_count": 0,
				"is_hitscan": false,
				"projectile_visual_size_x": 18.0,
				"projectile_visual_size_y": 6.0,
			}


func roll_shop_item_ids(
	rng: RandomNumberGenerator,
	desired_count: int,
	context: Dictionary = {}
) -> PackedStringArray:
	_rebuild_cache()
	var pool: Array[Dictionary] = []
	for raw_item in get_all_items():
		var item: Dictionary = raw_item
		if not bool(item.get("shop_enabled", true)):
			continue
		if _should_skip_item_for_roll(item, context):
			continue
		pool.append(item)
	var rolled_ids := PackedStringArray()
	var used_ids: Dictionary = {}
	while rolled_ids.size() < desired_count and not pool.is_empty():
		var picked_index := _pick_weighted_index(rng, pool, context)
		if picked_index < 0:
			break
		var picked_item: Dictionary = pool[picked_index]
		var item_id := StringName(String(picked_item.get("item_id", "")))
		if item_id != StringName() and not used_ids.has(item_id):
			rolled_ids.append(String(item_id))
			used_ids[item_id] = true
		pool.remove_at(picked_index)
	return rolled_ids


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
