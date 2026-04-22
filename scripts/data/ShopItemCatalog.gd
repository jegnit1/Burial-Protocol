extends RefCounted
class_name ShopItemCatalog

const RESOURCE_CATALOG_PATH := "res://data/items/ShopItemCatalog.tres"
const DRAFT_PATH := "res://docs/shop_item_catalog_draft.gd"
const CATEGORY_ATTACK_MODULE: StringName = &"attack_module"
const CATEGORY_FUNCTION_MODULE: StringName = &"function_module"
const CATEGORY_ENHANCE_MODULE: StringName = &"enhance_module"

# 랭크 확률 수치는 아직 확정 전이라 임시 가중치만 둔다.
# TODO: luck 시스템이 붙으면 여기서 랭크 가중치를 조정한다.
const DEFAULT_RANK_WEIGHTS := {
	"D": 40.0,
	"C": 28.0,
	"B": 18.0,
	"A": 10.0,
	"S": 4.0,
}

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


func _should_skip_item_for_roll(item: Dictionary, context: Dictionary) -> bool:
	var item_id := StringName(String(item.get("item_id", "")))
	var category := StringName(String(item.get("item_category", "")))
	if category == CATEGORY_ATTACK_MODULE:
		var owned_attack_ids: PackedStringArray = context.get("owned_attack_module_ids", PackedStringArray())
		if owned_attack_ids.has(String(item_id)):
			return true
	if category == CATEGORY_FUNCTION_MODULE:
		var owned_function_ids: PackedStringArray = context.get("owned_function_module_ids", PackedStringArray())
		if owned_function_ids.has(String(item_id)):
			return true
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


func _get_shop_weight(item: Dictionary, _context: Dictionary) -> float:
	var explicit_weight := float(item.get("shop_spawn_weight", -1.0))
	if explicit_weight > 0.0:
		return explicit_weight
	var rank := String(item.get("rank", "D"))
	return float(DEFAULT_RANK_WEIGHTS.get(rank, 1.0))


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
