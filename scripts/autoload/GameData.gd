extends Node

const BLOCK_CATALOG = preload("res://data/blocks/BlockCatalog.tres")
const STAGE_TABLE = preload("res://data/stages/StageTable.tres")
const SHOP_ITEM_RESOURCE_CATALOG = preload("res://data/items/ShopItemCatalog.tres")
const SHOP_ITEM_CATALOG_SCRIPT = preload("res://scripts/data/ShopItemCatalog.gd")
const BLOCK_SPAWN_RESOLVER_SCRIPT = preload("res://scripts/data/BlockSpawnResolver.gd")

var _shop_item_catalog = SHOP_ITEM_CATALOG_SCRIPT.new()
var _block_spawn_resolver = BLOCK_SPAWN_RESOLVER_SCRIPT.new()


func get_block_catalog():
	return BLOCK_CATALOG


func get_stage_table():
	return STAGE_TABLE


func get_block_material_definition(material_id: StringName):
	return BLOCK_CATALOG.get_block_material_definition(material_id)


func get_block_base_definition(base_id: StringName):
	return get_block_material_definition(base_id)


func get_block_size_definition(size_id: StringName):
	return BLOCK_CATALOG.get_block_size_definition(size_id)


func get_block_type_definition(type_id: StringName):
	return BLOCK_CATALOG.get_block_type_definition(type_id)


func get_block_material_spawn_weight(definition) -> float:
	return BLOCK_CATALOG.get_block_material_spawn_weight(definition)


func get_block_base_spawn_weight(definition) -> float:
	return get_block_material_spawn_weight(definition)


func get_block_type_spawn_weight(definition) -> float:
	return BLOCK_CATALOG.get_block_type_spawn_weight(definition)


func pick_block_base_definition(rng: RandomNumberGenerator):
	return BLOCK_CATALOG.pick_block_base_definition(rng)


func pick_block_type_definition_or_none(rng: RandomNumberGenerator):
	return BLOCK_CATALOG.pick_block_type_definition_or_none(rng)


func resolve_random_block_definition(
	rng: RandomNumberGenerator,
	difficulty_id: StringName,
	stage_number: int,
	type_definition = null
):
	var difficulty_definition := GameConstants.get_difficulty_definition(str(difficulty_id))
	var day_hp_multiplier := get_block_hp_multiplier(stage_number)
	return _block_spawn_resolver.resolve_random_block(
		BLOCK_CATALOG,
		rng,
		difficulty_id,
		stage_number,
		difficulty_definition,
		type_definition,
		day_hp_multiplier
	)


func resolve_specific_block_definition(
	material_id: StringName,
	size_id: StringName,
	difficulty_id: StringName,
	stage_number: int,
	type_definition = null
):
	var difficulty_definition := GameConstants.get_difficulty_definition(str(difficulty_id))
	var day_hp_multiplier := get_block_hp_multiplier(stage_number)
	return _block_spawn_resolver.resolve_specific_block(
		BLOCK_CATALOG,
		material_id,
		size_id,
		difficulty_id,
		stage_number,
		difficulty_definition,
		type_definition,
		day_hp_multiplier
	)


func get_total_days() -> int:
	return STAGE_TABLE.get_total_days()


func get_day_definition(day_number: int):
	return STAGE_TABLE.get_day_definition(day_number)


func get_day_type(day_number: int) -> StringName:
	return STAGE_TABLE.get_day_type(day_number)


func get_day_duration(day_number: int) -> float:
	return STAGE_TABLE.get_day_duration(day_number)


func get_block_hp_multiplier(day_number: int) -> float:
	return STAGE_TABLE.get_block_hp_multiplier(day_number)


func get_spawn_interval_multiplier(day_number: int) -> float:
	return STAGE_TABLE.get_spawn_interval_multiplier(day_number)


func is_boss_day(day_number: int) -> bool:
	return STAGE_TABLE.is_boss_day(day_number)


func get_next_boss_day(from_day: int) -> int:
	return STAGE_TABLE.get_next_boss_day(from_day)


func get_boss_block_base_definition(day_number: int):
	var block_base_id = STAGE_TABLE.get_boss_block_base_id(day_number)
	if block_base_id == StringName():
		return null
	return get_block_base_definition(block_base_id)


func get_boss_block_size_definition(day_number: int):
	var block_size_id = STAGE_TABLE.get_boss_block_size_id(day_number)
	if block_size_id == StringName():
		return null
	return get_block_size_definition(block_size_id)


func get_boss_block_type_definition(day_number: int):
	var block_type_id = STAGE_TABLE.get_boss_block_type_id(day_number)
	if block_type_id == StringName():
		return null
	return get_block_type_definition(block_type_id)


func get_attack_module_definitions() -> Array[Resource]:
	return SHOP_ITEM_RESOURCE_CATALOG.get_attack_module_definitions()


func get_attack_module_definition(module_id: StringName):
	return SHOP_ITEM_RESOURCE_CATALOG.get_attack_module_definition(module_id)


func get_default_attack_module_id() -> StringName:
	return SHOP_ITEM_RESOURCE_CATALOG.get_default_attack_module_id()


func get_default_attack_module_definition():
	return SHOP_ITEM_RESOURCE_CATALOG.get_default_attack_module_definition()


func get_shop_item_catalog():
	return _shop_item_catalog


func get_all_shop_items() -> Array[Dictionary]:
	return _shop_item_catalog.get_all_items()


func get_shop_item_definition(item_id: StringName) -> Dictionary:
	return _shop_item_catalog.get_item_definition(item_id)


func get_shop_items_by_category(category: StringName) -> Array[Dictionary]:
	return _shop_item_catalog.get_items_by_category(category)


func roll_shop_item_ids(
	rng: RandomNumberGenerator,
	desired_count: int,
	context: Dictionary = {}
) -> PackedStringArray:
	return _shop_item_catalog.roll_shop_item_ids(rng, desired_count, context)
