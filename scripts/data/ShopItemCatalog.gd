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
		items.append(item.duplicate(true))
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
		items.append(item.duplicate(true))
	return items


func has_item(item_id: StringName) -> bool:
	_rebuild_cache()
	return _items_by_id.has(item_id)


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
		var normalized_item := item.duplicate(true)
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
