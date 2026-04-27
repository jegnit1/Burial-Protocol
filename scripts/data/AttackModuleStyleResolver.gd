extends RefCounted
class_name AttackModuleStyleResolver


static func normalize_item_dictionary(item: Dictionary) -> void:
	if String(item.get("item_category", "")) != "attack_module":
		return
	var module_type := String(item.get("module_type", ""))
	var attack_style := get_attack_style_for_values(module_type, String(item.get("attack_style", "")))
	item["attack_style"] = attack_style
	var style_defaults := get_style_defaults(module_type, attack_style)
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
		_normalize_ranged_item_dictionary(item, style_defaults)


static func get_attack_style(module_definition) -> StringName:
	if module_definition == null:
		return &""
	return StringName(get_attack_style_for_values(module_definition.module_type, module_definition.attack_style))


static func get_attack_style_for_values(module_type_value: Variant, attack_style_value: Variant) -> String:
	var module_type := String(module_type_value)
	var attack_style := String(attack_style_value)
	if module_type == "melee":
		return "slash" if attack_style.is_empty() else attack_style
	if module_type == "ranged":
		return normalize_ranged_attack_style_alias(attack_style)
	return attack_style


static func get_effect_style(module_definition) -> StringName:
	if module_definition == null:
		return &""
	if module_definition.effect_style != StringName():
		return module_definition.effect_style
	var style_defaults := get_style_defaults(module_definition.module_type, get_attack_style(module_definition))
	return StringName(String(style_defaults.get("effect_style", "")))


static func get_style_defaults(module_type_value: Variant, attack_style_value: Variant) -> Dictionary:
	var module_type := String(module_type_value)
	var attack_style := get_attack_style_for_values(module_type, attack_style_value)
	match module_type:
		"melee":
			return get_melee_attack_style_defaults(attack_style)
		"ranged":
			return get_ranged_attack_style_defaults(attack_style)
	return {}


static func get_melee_attack_style_defaults(attack_style: String) -> Dictionary:
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


static func normalize_ranged_attack_style_alias(attack_style: String) -> String:
	match attack_style:
		"", "single":
			return "rifle"
		"spread":
			return "shotgun"
		"pierce":
			return "sniper"
		_:
			return attack_style


static func get_ranged_attack_style_defaults(attack_style: String) -> Dictionary:
	match normalize_ranged_attack_style_alias(attack_style):
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


static func get_base_shape_units(module_definition) -> Vector2:
	if module_definition == null:
		return Vector2.ONE
	if module_definition.base_shape_units.x > 0.0 and module_definition.base_shape_units.y > 0.0:
		return module_definition.base_shape_units
	if module_definition.module_type == &"melee":
		var defaults := get_melee_attack_style_defaults(String(get_attack_style(module_definition)))
		return Vector2(
			float(defaults.get("base_shape_units_x", 1.0)),
			float(defaults.get("base_shape_units_y", 1.0))
		)
	if module_definition.module_type == &"ranged":
		return Vector2(get_ranged_range_units(module_definition), module_definition.range_height_u)
	return Vector2(module_definition.range_width_u, module_definition.range_height_u)


static func get_ranged_range_units(module_definition) -> float:
	if module_definition == null:
		return 0.0
	if module_definition.range_units > 0.0:
		return module_definition.range_units
	return module_definition.range_width_u


static func get_ranged_projectile_count(module_definition, attack_style: String = "") -> int:
	if is_ranged_hitscan(module_definition, attack_style):
		return 0
	if module_definition == null:
		return 1
	return max(module_definition.projectile_count, 1)


static func get_ranged_spread_angle(module_definition) -> float:
	if module_definition == null:
		return 0.0
	if module_definition.spread_angle > 0.0:
		return module_definition.spread_angle
	return module_definition.projectile_spread_degrees


static func get_ranged_pierce_count(module_definition) -> int:
	if module_definition == null:
		return 0
	return max(module_definition.pierce_count, module_definition.projectile_pierce_count)


static func is_ranged_hitscan(module_definition, attack_style: String = "") -> bool:
	if module_definition == null:
		return false
	var resolved_style := attack_style
	if resolved_style.is_empty():
		resolved_style = String(get_attack_style(module_definition))
	return resolved_style == "laser" or module_definition.is_hitscan or module_definition.projectile_hit_scan


static func get_ranged_projectile_visual_size(module_definition) -> Vector2:
	if module_definition == null:
		return Vector2(18.0, 6.0)
	if module_definition.projectile_visual_size.x > 0.0 and module_definition.projectile_visual_size.y > 0.0:
		return module_definition.projectile_visual_size
	return module_definition.projectile_size


static func _normalize_ranged_item_dictionary(item: Dictionary, style_defaults: Dictionary) -> void:
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
