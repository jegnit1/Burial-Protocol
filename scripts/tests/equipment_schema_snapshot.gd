extends SceneTree

var _failures: Array[String] = []
var _results: Dictionary = {}
var _ran := false
var _game_data: Node = null


func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	_game_data = get_root().get_node_or_null("GameData")
	if _game_data == null:
		_failures.append("GameData autoload should be available")
		_print_and_quit()
		return true
	_run_checks()
	_print_and_quit()
	return true


func _run_checks() -> void:
	var sword: Dictionary = _game_data.call("get_shop_item_definition", &"sword_module")
	var laser: Dictionary = _game_data.call("get_shop_item_definition", &"laser_module")
	var mechanic_drone: Dictionary = _game_data.call("get_shop_item_definition", &"drone_attack_module")
	var combat_drone: Dictionary = _game_data.call("get_shop_item_definition", &"combat_drone_d")
	var spark_field: Dictionary = _game_data.call("get_shop_item_definition", &"spark_field_d")
	var passive: Dictionary = _game_data.call("get_shop_item_definition", &"small_gear")
	var weapon_resources: Array = _game_data.call("get_weapon_definitions")
	var protocol_resources: Array = _game_data.call("get_drone_protocol_definitions")
	var passive_resources: Array = _game_data.call("get_passive_module_definitions")
	_results = {
		"sword": _metadata_snapshot(sword),
		"laser": _metadata_snapshot(laser),
		"mechanic_drone": _metadata_snapshot(mechanic_drone),
		"combat_drone": _metadata_snapshot(combat_drone),
		"spark_field": _metadata_snapshot(spark_field),
		"passive": _metadata_snapshot(passive),
		"resource_counts": {
			"weapons": weapon_resources.size(),
			"protocols": protocol_resources.size(),
			"passives": passive_resources.size(),
		},
	}
	_expect(String(sword.get("equipment_category", "")) == "weapon", "sword should migrate to weapon metadata")
	_expect(String(sword.get("attribute", "")) == "physical", "sword should migrate to physical metadata")
	_expect(String(sword.get("attack_type", "")) == "area", "sword should migrate to area metadata")
	_expect(is_equal_approx(float(sword.get("weapon_base_cooldown", 0.0)), 0.3), "sword should expose legacy-compatible weapon base cooldown")
	_expect(String(laser.get("attribute", "")) == "energy", "laser should migrate to energy metadata")
	_expect(String(laser.get("attack_type", "")) == "beam", "laser should migrate to beam metadata")
	_expect(String(mechanic_drone.get("equipment_category", "")) == "drone_protocol", "mechanic attack module should migrate to drone protocol metadata")
	_expect(int(mechanic_drone.get("protocol_base_damage", 0)) == 6, "mechanic attack module should expose protocol base damage")
	_expect(float(mechanic_drone.get("protocol_base_cooldown", 0.0)) > 0.0, "mechanic attack module should expose protocol base cooldown")
	_expect(String(combat_drone.get("equipment_category", "")) == "drone_protocol", "combat drone should migrate to drone protocol metadata")
	_expect(String(combat_drone.get("attack_type", "")) == "projectile", "combat drone should migrate to projectile metadata")
	_expect(String(spark_field.get("attribute", "")) == "electric", "spark field should migrate to electric metadata")
	_expect(String(spark_field.get("attack_type", "")) == "area", "spark field should migrate to area metadata")
	_expect(String(passive.get("equipment_category", "")) == "passive_module", "enhance item should migrate to passive module metadata")
	_expect(weapon_resources.size() >= 1, "resource catalog should expose weapon metadata")
	_expect(protocol_resources.size() >= 1, "resource catalog should expose drone protocol metadata")
	_expect(passive_resources.size() >= 1, "resource catalog should expose passive module metadata")


func _metadata_snapshot(definition: Dictionary) -> Dictionary:
	return {
		"equipment_category": String(definition.get("equipment_category", "")),
		"attribute": String(definition.get("attribute", "")),
		"attack_type": String(definition.get("attack_type", "")),
		"weapon_base_cooldown": float(definition.get("weapon_base_cooldown", 0.0)),
		"protocol_base_damage": int(definition.get("protocol_base_damage", 0)),
		"protocol_base_cooldown": float(definition.get("protocol_base_cooldown", 0.0)),
		"protocol_behavior": String(definition.get("protocol_behavior", "")),
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _print_and_quit() -> void:
	print(JSON.stringify({
		"ok": _failures.is_empty(),
		"failures": _failures,
		"results": _results,
	}, "\t"))
	quit(0 if _failures.is_empty() else 1)
