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
@export var attack_style: StringName = &"slash"
@export var range_width_u := 0.0
@export var range_height_u := 0.0
@export var damage_multiplier := 1.0
@export var attack_speed_multiplier := 1.0
@export var projectile_count := 1
@export var projectile_spread_degrees := 0.0
@export var projectile_pierce_count := 0
@export var projectile_speed := 900.0
@export var projectile_lifetime := 1.2
@export var projectile_max_distance := 900.0
@export var projectile_size := Vector2(18.0, 6.0)
@export var projectile_hit_scan := false
@export var projectile_homing := false
@export var mechanic_drone_count := 1
@export var mechanic_targeting: StringName = &"nearest"
@export_file("*.png", "*.svg", "*.webp") var icon_path := ""
@export_file("*.tscn") var world_visual_scene_path := ""
@export var effect_type: StringName = &"none"
@export var effect_values: Dictionary = {}
@export var conditions: Array[Dictionary] = []
@export var effects: Array[Dictionary] = []
@export var apply_timing: StringName = &"on_purchase"
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
		"attack_style": String(attack_style),
		"range_width_u": range_width_u,
		"range_height_u": range_height_u,
		"damage_multiplier": damage_multiplier,
		"attack_speed_multiplier": attack_speed_multiplier,
		"projectile_count": projectile_count,
		"projectile_spread_degrees": projectile_spread_degrees,
		"projectile_pierce_count": projectile_pierce_count,
		"projectile_speed": projectile_speed,
		"projectile_lifetime": projectile_lifetime,
		"projectile_max_distance": projectile_max_distance,
		"projectile_size_x": projectile_size.x,
		"projectile_size_y": projectile_size.y,
		"projectile_hit_scan": projectile_hit_scan,
		"projectile_homing": projectile_homing,
		"mechanic_drone_count": mechanic_drone_count,
		"mechanic_targeting": String(mechanic_targeting),
		"icon_path": icon_path,
		"world_visual_scene_path": world_visual_scene_path,
		"effect_type": String(effect_type),
		"effect_values": effect_values.duplicate(true),
		"conditions": conditions.duplicate(true),
		"effects": effects.duplicate(true),
		"apply_timing": String(apply_timing),
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
	attack_style = StringName(String(data.get("attack_style", "slash")))
	range_width_u = float(data.get("range_width_u", 0.0))
	range_height_u = float(data.get("range_height_u", 0.0))
	damage_multiplier = float(data.get("damage_multiplier", 1.0))
	attack_speed_multiplier = float(data.get("attack_speed_multiplier", 1.0))
	projectile_count = int(data.get("projectile_count", 1))
	projectile_spread_degrees = float(data.get("projectile_spread_degrees", 0.0))
	projectile_pierce_count = int(data.get("projectile_pierce_count", 0))
	projectile_speed = float(data.get("projectile_speed", 900.0))
	projectile_lifetime = float(data.get("projectile_lifetime", 1.2))
	projectile_max_distance = float(data.get("projectile_max_distance", 900.0))
	projectile_size = Vector2(
		float(data.get("projectile_size_x", 18.0)),
		float(data.get("projectile_size_y", 6.0))
	)
	projectile_hit_scan = bool(data.get("projectile_hit_scan", false))
	projectile_homing = bool(data.get("projectile_homing", false))
	mechanic_drone_count = int(data.get("mechanic_drone_count", 1))
	mechanic_targeting = StringName(String(data.get("mechanic_targeting", "nearest")))
	icon_path = String(data.get("icon_path", ""))
	world_visual_scene_path = String(data.get("world_visual_scene_path", ""))
	effect_type = StringName(String(data.get("effect_type", "none")))
	effect_values = (data.get("effect_values", {}) as Dictionary).duplicate(true)
	conditions = _to_dictionary_array(data.get("conditions", []))
	effects = _to_dictionary_array(data.get("effects", []))
	apply_timing = StringName(String(data.get("apply_timing", "on_purchase")))
	tags = PackedStringArray(Array(data.get("tags", [])))
	short_desc = String(data.get("short_desc", ""))
	desc = String(data.get("desc", ""))


func _to_dictionary_array(raw_value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not raw_value is Array:
		return result
	for raw_entry in raw_value:
		if not raw_entry is Dictionary:
			continue
		var entry: Dictionary = raw_entry
		result.append(entry.duplicate(true))
	return result
