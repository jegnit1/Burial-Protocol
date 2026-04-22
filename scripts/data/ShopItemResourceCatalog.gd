extends Resource
class_name ShopItemResourceCatalog

# 상점/아이템 카탈로그를 묶음형 리소스로 관리한다.
@export var catalog_type: StringName = &"item_catalog"
@export var version := 1
@export var items: Array[Resource] = []

var _items_by_id: Dictionary = {}
var _items_by_category: Dictionary = {}


func get_item_definition(item_id: StringName):
	_ensure_cache()
	if _items_by_id.has(item_id):
		return _items_by_id[item_id]
	return null


func get_items_by_category(category: StringName) -> Array[Resource]:
	_ensure_cache()
	if not _items_by_category.has(category):
		return Array([], TYPE_OBJECT, "Resource", null)
	var result: Array[Resource] = []
	for raw_item in (_items_by_category[category] as Array):
		result.append(raw_item)
	return result


func get_items() -> Array[Resource]:
	var result: Array[Resource] = []
	for raw_item in items:
		result.append(raw_item)
	return result


func get_attack_module_definitions() -> Array[Resource]:
	return get_items_by_category(&"attack_module")


func get_attack_module_definition(module_id: StringName):
	var item = get_item_definition(module_id)
	if item == null:
		return null
	if item.item_category != &"attack_module":
		return null
	return item


func get_default_attack_module_id() -> StringName:
	for raw_item in get_attack_module_definitions():
		var item = raw_item
		if item == null:
			continue
		if bool(item.default_start_module):
			return item.item_id
	var attack_modules = get_attack_module_definitions()
	if attack_modules.is_empty():
		return StringName()
	var first_item = attack_modules[0]
	if first_item == null:
		return StringName()
	return first_item.item_id


func get_default_attack_module_definition():
	return get_attack_module_definition(get_default_attack_module_id())


func get_all_item_dictionaries() -> Array[Dictionary]:
	var dictionaries: Array[Dictionary] = []
	for raw_item in items:
		var item = raw_item
		if item == null:
			continue
		dictionaries.append(item.to_dictionary())
	return dictionaries


func _ensure_cache() -> void:
	if _items_by_id.size() == items.size():
		return
	_items_by_id.clear()
	_items_by_category.clear()
	for raw_item in items:
		var item = raw_item
		if item == null:
			continue
		_items_by_id[item.item_id] = item
		if not _items_by_category.has(item.item_category):
			_items_by_category[item.item_category] = []
		(_items_by_category[item.item_category] as Array).append(item)
