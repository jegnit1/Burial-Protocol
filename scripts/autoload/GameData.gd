extends Node

const BLOCK_CATALOG = preload("res://data/blocks/BlockCatalog.tres")
const STAGE_TABLE = preload("res://data/stages/StageTable.tres")


func get_block_catalog():
	return BLOCK_CATALOG


func get_stage_table():
	return STAGE_TABLE


func get_block_base_definition(base_id: StringName):
	return BLOCK_CATALOG.get_block_base_definition(base_id)


func get_block_type_definition(type_id: StringName):
	return BLOCK_CATALOG.get_block_type_definition(type_id)


func get_block_base_spawn_weight(definition) -> float:
	return BLOCK_CATALOG.get_block_base_spawn_weight(definition)


func get_block_type_spawn_weight(definition) -> float:
	return BLOCK_CATALOG.get_block_type_spawn_weight(definition)


func pick_block_base_definition(rng: RandomNumberGenerator):
	return BLOCK_CATALOG.pick_block_base_definition(rng)


func pick_block_type_definition_or_none(rng: RandomNumberGenerator):
	return BLOCK_CATALOG.pick_block_type_definition_or_none(rng)


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


func get_boss_block_type_definition(day_number: int):
	var block_type_id = STAGE_TABLE.get_boss_block_type_id(day_number)
	if block_type_id == StringName():
		return null
	return get_block_type_definition(block_type_id)
