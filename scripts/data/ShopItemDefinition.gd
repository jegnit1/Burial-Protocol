extends Resource
class_name ShopItemDefinition

# 상점/런 콘텐츠용 공통 아이템 정의 리소스다.
@export var item_id: StringName
@export var name := ""
@export var item_category: StringName = &"attack_module"
@export var rank := "D"
@export var price_gold := 100
@export var shop_enabled := true
@export var shop_spawn_weight := -1.0
@export var stackable := false
@export var max_stack := 1
@export var equip_slot := ""
@export var is_equippable := false
@export var default_start_module := false
@export var module_type: StringName = &""
@export var range_width_u := 0.0
@export var range_height_u := 0.0
@export var damage_multiplier := 1.0
@export var attack_speed_multiplier := 1.0
@export_file("*.png", "*.svg", "*.webp") var icon_path := ""
@export_file("*.tscn") var world_visual_scene_path := ""
@export var effect_type: StringName = &"none"
@export var effect_values: Dictionary = {}
@export var tags: PackedStringArray = PackedStringArray()
@export var short_desc := ""
@export_multiline var desc := ""

var module_id: StringName:
	get:
		return item_id

var display_name: String:
	get:
		return name

var shop_price_gold: int:
	get:
		return price_gold

var visual_scene_path: String:
	get:
		return world_visual_scene_path


func to_dictionary() -> Dictionary:
	return {
		"item_id": String(item_id),
		"name": name,
		"item_category": String(item_category),
		"rank": rank,
		"price_gold": price_gold,
		"shop_enabled": shop_enabled,
		"shop_spawn_weight": shop_spawn_weight,
		"stackable": stackable,
		"max_stack": max_stack,
		"equip_slot": equip_slot,
		"is_equippable": is_equippable,
		"default_start_module": default_start_module,
		"module_type": String(module_type),
		"range_width_u": range_width_u,
		"range_height_u": range_height_u,
		"damage_multiplier": damage_multiplier,
		"attack_speed_multiplier": attack_speed_multiplier,
		"icon_path": icon_path,
		"world_visual_scene_path": world_visual_scene_path,
		"effect_type": String(effect_type),
		"effect_values": effect_values.duplicate(true),
		"tags": Array(tags),
		"short_desc": short_desc,
		"desc": desc,
	}


func apply_dictionary(data: Dictionary) -> void:
	item_id = StringName(String(data.get("item_id", "")))
	name = String(data.get("name", ""))
	item_category = StringName(String(data.get("item_category", "attack_module")))
	rank = String(data.get("rank", "D"))
	price_gold = int(data.get("price_gold", 100))
	shop_enabled = bool(data.get("shop_enabled", true))
	shop_spawn_weight = float(data.get("shop_spawn_weight", -1.0))
	stackable = bool(data.get("stackable", false))
	max_stack = int(data.get("max_stack", 1))
	equip_slot = String(data.get("equip_slot", ""))
	is_equippable = bool(data.get("is_equippable", false))
	default_start_module = bool(data.get("default_start_module", false))
	module_type = StringName(String(data.get("module_type", "")))
	range_width_u = float(data.get("range_width_u", 0.0))
	range_height_u = float(data.get("range_height_u", 0.0))
	damage_multiplier = float(data.get("damage_multiplier", 1.0))
	attack_speed_multiplier = float(data.get("attack_speed_multiplier", 1.0))
	icon_path = String(data.get("icon_path", ""))
	world_visual_scene_path = String(data.get("world_visual_scene_path", ""))
	effect_type = StringName(String(data.get("effect_type", "none")))
	effect_values = (data.get("effect_values", {}) as Dictionary).duplicate(true)
	tags = PackedStringArray(Array(data.get("tags", [])))
	short_desc = String(data.get("short_desc", ""))
	desc = String(data.get("desc", ""))
