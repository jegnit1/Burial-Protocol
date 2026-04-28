extends Node2D

const FALLING_BLOCK_SCENE := preload("res://scenes/blocks/FallingBlock.tscn")
const GOLD_POPUP_SCRIPT := preload("res://scenes/ui/GoldPopup.gd")
const DAY_KIOSK_SCRIPT := preload("res://scenes/world/DayKiosk.gd")
const DAY_SHOP_UI_SCRIPT := preload("res://scenes/ui/DayShopUI.gd")
const PAUSE_MENU_SCRIPT := preload("res://scenes/ui/PauseMenu.gd")
const ATTACK_MODULE_PROJECTILE_SCRIPT := preload("res://scenes/projectiles/AttackModuleProjectile.gd")
const ATTACK_MODULE_STYLE_RESOLVER := preload("res://scripts/data/AttackModuleStyleResolver.gd")
const CAMERA_PLAYER_Y_OFFSET := 110.0
const RANGED_PROJECTILE_LANE_GAP_UNITS := 0.26

@onready var world_grid: WorldGrid = $WorldGrid
@onready var sand_field: SandField = $SandField
@onready var player: Player = $Player
@onready var blocks_root: Node2D = $Blocks
@onready var hud: HUD = $HUD
@onready var world_camera: Camera2D = $WorldCamera
@onready var spawn_timer: Timer = $SpawnTimer

var rng := RandomNumberGenerator.new()
var last_spawned_block_debug := "Spawn Base -"
var last_spawned_column := -1
var run_finished := false

# Day 진행과 상점 전환 상태를 최소 범위로 분리한다.
var _is_day_active := true
var _is_intermission := false
var _is_intermission_locked := false
var _is_next_day_transitioning := false
var _shop_ui_open := false
var _intermission_elapsed := 0.0
var _day_kiosk: Node2D
var _day_shop_ui
var _fade_overlay: ColorRect
var _last_transition_sand_report := ""
var _waiting_for_day_kiosk := false
var _kiosk_spawn_delay_remaining := -1.0
var _pending_wall_reset_for_next_day := false
var _pause_menu: CanvasLayer
var _projectiles_root: Node2D
var _player_regen_accumulator := 0.0
var _current_shop_item_ids := PackedStringArray()
var _has_shop_inventory_for_intermission := false
var _last_mining_idle_status_text := ""
var _last_mining_idle_status_time := -INF

var _current_day := 1
var _day_time_remaining := 0.0
var _day30_boss_alive := false


func _ready() -> void:
	GameConstants.ensure_input_actions()
	GameState.reset_run()
	rng.randomize()
	_configure_camera()
	sand_field.setup(world_grid)
	player.setup(world_grid, sand_field, blocks_root)
	_ensure_projectiles_root()
	_ensure_fade_overlay()
	_current_day = 1
	_day_time_remaining = GameData.get_day_duration(_current_day)
	GameState.current_day = _current_day
	GameState.level_up_ready.connect(_show_level_up_ui)
	_apply_day_spawn_interval()
	spawn_timer.start()
	if GameData.is_boss_day(_current_day):
		_spawn_boss_block()
	_refresh_debug()
	GameState.grant_attack_module(&"laser_module", true)


func _physics_process(delta: float) -> void:
	if run_finished:
		return
	if Input.is_action_just_pressed("restart"):
		_finish_temporary_run("run_end", Locale.ltr("run_end_label"))
		return
	if Input.is_action_just_pressed("ui_toggle_status"):
		hud.toggle_debug_panel()

	if _is_intermission:
		_update_intermission(delta)

	if not _shop_ui_open and not _is_next_day_transitioning:
		var attack_triggers := player.consume_attack_module_triggers()
		_assign_ranged_attack_lanes(attack_triggers)
		for attack_trigger in attack_triggers:
			_handle_attack_module_action(attack_trigger)
		for mechanic_trigger in player.consume_mechanic_attack_module_triggers():
			_handle_attack_module_action(mechanic_trigger, true)

	if run_finished:
		return

	if not _shop_ui_open and not _is_next_day_transitioning and not _is_intermission_locked:
		var mine_direction := player.consume_mining_direction()
		if mine_direction != Vector2.ZERO:
			_handle_mining_action(mine_direction)
	elif player.consume_mining_direction() != Vector2.ZERO and _is_intermission_locked:
		GameState.set_status_text("상점 단계에서는 채굴이 정지됩니다.")

	if _is_day_active:
		_day_time_remaining -= delta
	_update_player_regen(delta)
	GameState.day_time_remaining = _day_time_remaining
	if _is_day_active and _day_time_remaining <= 0.0:
		_on_day_timer_expired()
		if run_finished:
			return

	if not _is_next_day_transitioning:
		sand_field.step_simulation(player.get_body_rect())

	if _is_intermission and not _shop_ui_open and not _is_next_day_transitioning:
		_update_day_kiosk_prompt()
		if Input.is_action_just_pressed("interact_action") and _is_player_near_day_kiosk():
			_open_day_shop()

	_check_run_end_conditions()
	if run_finished:
		return

	_update_camera_y()
	_refresh_debug()


func _on_spawn_timer_timeout() -> void:
	if run_finished or not _is_day_active or _is_intermission or _is_next_day_transitioning:
		return
	var type_definition = GameData.pick_block_type_definition_or_none(rng)
	var resolved_definition = GameData.resolve_random_block_definition(
		rng,
		StringName(GameState.current_run_difficulty_id),
		_current_day,
		type_definition
	)
	if resolved_definition == null:
		return
	var block_data := BlockData.from_resolved_definition(resolved_definition)
	var camera_top_y := world_camera.position.y - float(GameConstants.VIEWPORT_SIZE.y) * 0.5
	var spawn_result := _pick_fair_spawn_position(block_data.size_cells, camera_top_y)
	if not bool(spawn_result.get("ok", false)):
		last_spawned_block_debug = "Spawn skipped: no safe airspace"
		return
	var spawn_position: Vector2 = spawn_result["position"]
	last_spawned_column = int((spawn_position.x - float(GameConstants.WORLD_ORIGIN.x)) / float(GameConstants.CELL_SIZE))
	var block := FALLING_BLOCK_SCENE.instantiate() as FallingBlock
	blocks_root.add_child(block)
	block.setup(block_data, spawn_position, world_grid, sand_field, player)
	block.destroyed.connect(_on_block_destroyed)
	block.decomposed.connect(_on_block_decomposed)
	last_spawned_block_debug = "Spawn %s | %s" % [block_data.display_name, block_data.get_block_base_debug_text()]


func _assign_ranged_attack_lanes(attack_triggers: Array[Dictionary]) -> void:
	var ranged_trigger_indices: Array[int] = []
	for index in range(attack_triggers.size()):
		var trigger: Dictionary = attack_triggers[index]
		var module_entry: Dictionary = trigger.get("module_entry", {})
		var module_definition = GameState.get_attack_module_definition_from_entry(module_entry)
		if module_definition == null or module_definition.module_type != &"ranged":
			continue
		ranged_trigger_indices.append(index)
	var lane_count := ranged_trigger_indices.size()
	if lane_count <= 0:
		return
	for lane_index in range(lane_count):
		var trigger_index := ranged_trigger_indices[lane_index]
		var trigger: Dictionary = attack_triggers[trigger_index]
		trigger["ranged_lane_index"] = lane_index
		trigger["ranged_lane_count"] = lane_count
		attack_triggers[trigger_index] = trigger


func _handle_attack_module_action(trigger: Dictionary, is_mechanic := false) -> void:
	var module_entry: Dictionary = trigger.get("module_entry", {})
	if module_entry.is_empty():
		return
	var direction: Vector2 = trigger.get("direction", Vector2.ZERO)
	if is_mechanic:
		_handle_mechanic_attack_module_action(module_entry)
		return
	var module_definition = GameState.get_attack_module_definition_from_entry(module_entry)
	if module_definition != null and module_definition.module_type == &"ranged":
		_handle_ranged_attack_module_action(
			module_entry,
			module_definition,
			direction,
			int(trigger.get("ranged_lane_index", 0)),
			int(trigger.get("ranged_lane_count", 1))
		)
		return
	var attack_shape_data := player.get_attack_shape_data_for_module(direction, module_entry)
	if module_definition != null:
		_spawn_melee_attack_effect(module_definition, attack_shape_data)
	var attack_shape := RectangleShape2D.new()
	attack_shape.size = attack_shape_data["size"]
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = attack_shape
	query.transform = Transform2D(attack_shape_data["rotation"], attack_shape_data["center"])
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = 1
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var results: Array[Dictionary] = space_state.intersect_shape(query, 32)
	var hit_count := 0
	var crit_count := 0
	var hit_once: Dictionary = {}
	var module_damage := GameState.get_attack_module_damage(module_entry)
	for result in results:
		var block := result["collider"] as FallingBlock
		if block != null and not hit_once.has(block):
			hit_once[block] = true
			var is_critical := rng.randf() < GameState.get_critical_chance_ratio()
			var damage := module_damage
			if is_critical:
				damage = int(round(float(damage) * GameState.get_critical_damage_multiplier()))
				crit_count += 1
			block.apply_damage(damage, is_critical)
			hit_count += 1
	if hit_count > 0:
		var status_text := "%s: %s" % [GameState.get_attack_module_entry_label(module_entry), Locale.ltr("status_attack_hit") % hit_count]
		if crit_count > 0:
			status_text += " CRIT x%d" % crit_count
		GameState.set_status_text(status_text)
	else:
		GameState.set_status_text(Locale.ltr("status_attack_miss"))


func _get_ranged_lane_offset(fire_direction: Vector2, lane_index: int, lane_count: int) -> Vector2:
	if lane_count <= 1:
		return Vector2.ZERO
	var normalized_direction := fire_direction.normalized()
	if normalized_direction == Vector2.ZERO:
		normalized_direction = Vector2.RIGHT
	var perpendicular := Vector2(-normalized_direction.y, normalized_direction.x)
	var centered_index := float(lane_index) - (float(lane_count) - 1.0) * 0.5
	var lane_gap := float(GameConstants.CELL_SIZE) * RANGED_PROJECTILE_LANE_GAP_UNITS
	return perpendicular * centered_index * lane_gap


func _get_ranged_attack_distance(module_entry: Dictionary) -> float:
	return maxf(GameState.get_attack_module_shape_size_pixels(module_entry).x, 1.0)


func _handle_ranged_attack_module_action(
	module_entry: Dictionary,
	module_definition,
	direction: Vector2,
	lane_index: int,
	lane_count: int
) -> void:
	var fire_direction := direction.normalized()
	if fire_direction == Vector2.ZERO:
		fire_direction = player.get_attack_direction()
	if fire_direction == Vector2.ZERO:
		fire_direction = Vector2.RIGHT
	var lane_offset := _get_ranged_lane_offset(fire_direction, lane_index, lane_count)
	var attack_style := String(ATTACK_MODULE_STYLE_RESOLVER.get_attack_style(module_definition))
	if ATTACK_MODULE_STYLE_RESOLVER.is_ranged_hitscan(module_definition, attack_style):
		_fire_laser_placeholder(module_entry, module_definition, fire_direction, lane_offset)
		return
	_fire_projectile_burst(module_entry, module_definition, fire_direction, lane_offset, attack_style)


func _fire_projectile_burst(module_entry: Dictionary, module_definition, fire_direction: Vector2, lane_offset: Vector2, attack_style: String) -> void:
	_ensure_projectiles_root()
	var projectile_count := ATTACK_MODULE_STYLE_RESOLVER.get_ranged_projectile_count(module_definition, attack_style)
	var spread_degrees := ATTACK_MODULE_STYLE_RESOLVER.get_ranged_spread_angle(module_definition)
	var range_distance := _get_ranged_attack_distance(module_entry)
	var projectile_speed: float = maxf(module_definition.projectile_speed, 1.0)
	var projectile_lifetime: float = maxf(module_definition.projectile_lifetime, range_distance / projectile_speed + 0.05)
	var effect_style := String(ATTACK_MODULE_STYLE_RESOLVER.get_effect_style(module_definition))
	var projectile_visual_size := ATTACK_MODULE_STYLE_RESOLVER.get_ranged_projectile_visual_size(module_definition)
	var pierce_count := ATTACK_MODULE_STYLE_RESOLVER.get_ranged_pierce_count(module_definition)
	var start_angle := -spread_degrees * 0.5
	var angle_step := 0.0
	if projectile_count > 1:
		angle_step = spread_degrees / float(projectile_count - 1)
	for index in range(projectile_count):
		var angle_degrees := start_angle + angle_step * float(index)
		var shot_direction := fire_direction.rotated(deg_to_rad(angle_degrees)).normalized()
		var projectile := ATTACK_MODULE_PROJECTILE_SCRIPT.new() as Node2D
		_projectiles_root.add_child(projectile)
		var is_critical := rng.randf() < GameState.get_critical_chance_ratio()
		var damage := GameState.get_attack_module_damage(module_entry)
		if is_critical:
			damage = int(round(float(damage) * GameState.get_critical_damage_multiplier()))
		projectile.call("setup", {
			"position": player.global_position,
			"direction": shot_direction,
			"visual_offset": lane_offset,
			"speed": projectile_speed,
			"lifetime": projectile_lifetime,
			"max_distance": range_distance,
			"size": projectile_visual_size,
			"effect_style": effect_style,
			"damage": damage,
			"is_critical": is_critical,
			"pierce_count": pierce_count,
			"homing": module_definition.projectile_homing,
			"blocks_root": blocks_root,
		})
	GameState.set_status_text("%s fired x%d." % [GameState.get_attack_module_entry_label(module_entry), projectile_count])


func _fire_laser_placeholder(module_entry: Dictionary, module_definition, fire_direction: Vector2, lane_offset: Vector2) -> void:
	var range_distance := _get_ranged_attack_distance(module_entry)
	var shape_size := GameState.get_attack_module_shape_size_pixels(module_entry)
	var attack_shape_data := {
		"center": player.global_position + fire_direction * (range_distance * 0.5),
		"size": Vector2(range_distance, shape_size.y),
		"rotation": fire_direction.angle(),
	}
	var attack_shape := RectangleShape2D.new()
	attack_shape.size = attack_shape_data["size"]
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = attack_shape
	query.transform = Transform2D(attack_shape_data["rotation"], attack_shape_data["center"])
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = 1
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var results: Array[Dictionary] = space_state.intersect_shape(query, 32)
	var hit_count := 0
	var hit_once: Dictionary = {}
	for result in results:
		var block := result["collider"] as FallingBlock
		if block == null or hit_once.has(block):
			continue
		hit_once[block] = true
		var is_critical := rng.randf() < GameState.get_critical_chance_ratio()
		var damage := GameState.get_attack_module_damage(module_entry)
		if is_critical:
			damage = int(round(float(damage) * GameState.get_critical_damage_multiplier()))
		block.apply_damage(damage, is_critical)
		hit_count += 1
	_spawn_laser_line(
		player.global_position + lane_offset,
		player.global_position + fire_direction * range_distance + lane_offset,
		String(ATTACK_MODULE_STYLE_RESOLVER.get_effect_style(module_definition))
	)
	GameState.set_status_text("%s laser hit %d." % [GameState.get_attack_module_entry_label(module_entry), hit_count])


func _spawn_laser_line(from_position: Vector2, to_position: Vector2, effect_style: String = "laser_beam") -> void:
	_ensure_projectiles_root()
	var line := Line2D.new()
	line.width = 5.0 if effect_style == "laser_beam" else 3.0
	line.default_color = Color(0.55, 0.92, 1.0, 0.8)
	line.points = PackedVector2Array([from_position, to_position])
	_projectiles_root.add_child(line)
	var tween := create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.12)
	tween.finished.connect(line.queue_free)


func _spawn_melee_attack_effect(module_definition, attack_shape_data: Dictionary) -> void:
	if module_definition == null or module_definition.module_type != &"melee":
		return
	_ensure_projectiles_root()
	var effect_style := String(ATTACK_MODULE_STYLE_RESOLVER.get_effect_style(module_definition))
	var center: Vector2 = attack_shape_data["center"]
	var size: Vector2 = attack_shape_data["size"]
	var rotation := float(attack_shape_data["rotation"])
	match effect_style:
		"short_stab":
			_spawn_melee_line_effect(center, size, rotation, Color(0.9, 1.0, 0.82, 0.88), 3.0, 0.08)
		"long_pierce":
			_spawn_melee_line_effect(center, size, rotation, Color(0.62, 0.9, 1.0, 0.86), 4.0, 0.1)
		"big_cleave":
			_spawn_melee_polygon_effect(center, size, rotation, Color(1.0, 0.58, 0.24, 0.26), Color(1.0, 0.75, 0.42, 0.9), 0.14)
		"blunt_smash":
			_spawn_melee_polygon_effect(center, size, rotation, Color(0.95, 0.9, 0.64, 0.24), Color(1.0, 0.93, 0.56, 0.88), 0.12)
		_:
			_spawn_melee_arc_effect(center, size, rotation, Color(1.0, 0.48, 0.34, 0.88), 0.12)


func _spawn_melee_line_effect(center: Vector2, size: Vector2, rotation: float, color: Color, width: float, duration: float) -> void:
	var forward := Vector2.RIGHT.rotated(rotation)
	var line := Line2D.new()
	line.width = width
	line.default_color = color
	line.points = PackedVector2Array([
		center - forward * size.x * 0.5,
		center + forward * size.x * 0.5,
	])
	line.z_index = 38
	_projectiles_root.add_child(line)
	_fade_and_free(line, duration)


func _spawn_melee_arc_effect(center: Vector2, size: Vector2, rotation: float, color: Color, duration: float) -> void:
	var forward := Vector2.RIGHT.rotated(rotation)
	var side := forward.orthogonal()
	var line := Line2D.new()
	line.width = 4.0
	line.default_color = color
	line.points = PackedVector2Array([
		center - forward * size.x * 0.46 - side * size.y * 0.32,
		center - forward * size.x * 0.1 + side * size.y * 0.38,
		center + forward * size.x * 0.46 + side * size.y * 0.18,
	])
	line.z_index = 38
	_projectiles_root.add_child(line)
	_fade_and_free(line, duration)


func _spawn_melee_polygon_effect(center: Vector2, size: Vector2, rotation: float, fill_color: Color, outline_color: Color, duration: float) -> void:
	var polygon := Polygon2D.new()
	polygon.color = fill_color
	polygon.polygon = _get_rotated_box_points(center, size, rotation)
	polygon.z_index = 37
	_projectiles_root.add_child(polygon)
	var outline := Line2D.new()
	outline.width = 3.0
	outline.default_color = outline_color
	var outline_points := _get_rotated_box_points(center, size, rotation)
	outline_points.append(outline_points[0])
	outline.points = outline_points
	outline.z_index = 38
	_projectiles_root.add_child(outline)
	_fade_and_free(polygon, duration)
	_fade_and_free(outline, duration)


func _get_rotated_box_points(center: Vector2, size: Vector2, rotation: float) -> PackedVector2Array:
	var forward := Vector2.RIGHT.rotated(rotation)
	var side := forward.orthogonal()
	var half_forward := forward * size.x * 0.5
	var half_side := side * size.y * 0.5
	return PackedVector2Array([
		center - half_forward - half_side,
		center + half_forward - half_side,
		center + half_forward + half_side,
		center - half_forward + half_side,
	])


func _fade_and_free(node: CanvasItem, duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(node, "modulate:a", 0.0, duration)
	tween.finished.connect(node.queue_free)


func _handle_mechanic_attack_module_action(module_entry: Dictionary) -> void:
	var target := _find_nearest_attackable_block(GameState.get_attack_module_shape_size_pixels(module_entry).x)
	if target == null:
		return
	var damage := GameState.get_mechanic_attack_module_damage(module_entry)
	target.apply_damage(damage, false)
	GameState.set_status_text("%s auto hit." % GameState.get_attack_module_entry_label(module_entry))


func _find_nearest_attackable_block(max_distance: float) -> FallingBlock:
	var best_block: FallingBlock = null
	var best_distance := INF
	var origin := player.global_position
	for child in blocks_root.get_children():
		var block := child as FallingBlock
		if block == null or not block.active:
			continue
		var distance := origin.distance_to(block.global_position)
		if distance > max_distance or distance >= best_distance:
			continue
		best_distance = distance
		best_block = block
	return best_block


func _handle_mining_action(direction: Vector2) -> void:
	var mining_direction := player.get_mining_direction(direction)
	if mining_direction == Vector2.ZERO:
		_set_mining_idle_status(Locale.ltr("status_mine_blocked"))
		return
	var mining_shape_data := player.get_mining_shape_data(mining_direction)
	var final_mining_damage := GameState.get_mining_damage()
	var sand_result: Dictionary = sand_field.try_mine_in_shape(mining_shape_data, final_mining_damage)
	var sand_hits := int(sand_result["hit_count"])
	var sand_removed := int(sand_result["removed_count"])
	if sand_hits > 0:
		if sand_removed > 0:
			GameState.add_sand_removed_xp(sand_removed)
		GameState.set_status_text(Locale.ltr("status_mine_sand") % [sand_hits, sand_removed])
		return
	var wall_result: Dictionary = world_grid.try_mine_in_shape(mining_shape_data, final_mining_damage)
	var wall_hits := int(wall_result["hit_count"])
	var wall_removed := int(wall_result["removed_count"])
	if wall_hits > 0:
		GameState.set_status_text(Locale.ltr("status_mine_wall") % [wall_hits, wall_removed])
		return
	_set_mining_idle_status(Locale.ltr("status_mine_nothing"))


func _on_block_destroyed(block: FallingBlock) -> void:
	var reward := block.block_data.reward
	var spawn_pos := block.global_position
	var xp_amount := GameConstants.get_block_xp(int(block.block_data.size_cells.x), int(block.block_data.size_cells.y))
	GameState.add_xp(xp_amount)
	GameState.add_gold(reward)
	GameState.set_status_text(Locale.ltr("status_block_destroyed") % reward)
	_spawn_gold_popup(spawn_pos, reward)


func _spawn_gold_popup(spawn_pos: Vector2, amount: int) -> void:
	var popup := GOLD_POPUP_SCRIPT.new() as Node2D
	blocks_root.add_child(popup)
	popup.global_position = spawn_pos
	popup.call("setup", amount)


func _on_block_decomposed(block: FallingBlock, reason: StringName) -> void:
	sand_field.spawn_from_block(block.get_block_rect(), block.block_data)
	if reason == "player_crush":
		GameState.set_status_text(Locale.ltr("status_player_crushed"))
	else:
		GameState.set_status_text(Locale.ltr("status_block_decomposed"))


func _on_day_timer_expired() -> void:
	if _current_day >= GameData.get_total_days():
		if not GameState.run_cleared:
			_finish_temporary_run("time_limit", Locale.ltr("run_time_limit"))
		return
	_enter_intermission()


func _advance_to_next_day() -> void:
	_current_day += 1
	_day_time_remaining = GameData.get_day_duration(_current_day)
	GameState.current_day = _current_day
	GameState.current_run_stage_reached = _current_day
	_apply_day_spawn_interval()
	if GameData.is_boss_day(_current_day):
		_spawn_boss_block()
	GameState.set_status_text(Locale.ltr("run_day_start") % _current_day)


func _apply_day_spawn_interval() -> void:
	spawn_timer.wait_time = GameConstants.BLOCK_SPAWN_INTERVAL * GameData.get_spawn_interval_multiplier(_current_day)


func _spawn_boss_block() -> void:
	var boss_material_definition = GameData.get_boss_block_base_definition(_current_day)
	var boss_size_definition = GameData.get_boss_block_size_definition(_current_day)
	if boss_material_definition == null or boss_size_definition == null:
		return
	var boss_type_definition = GameData.get_boss_block_type_definition(_current_day)
	var resolved_definition = GameData.resolve_specific_block_definition(
		boss_material_definition.material_id,
		boss_size_definition.size_id,
		StringName(GameState.current_run_difficulty_id),
		_current_day,
		boss_type_definition,
	)
	if resolved_definition == null:
		push_warning("Boss block could not be resolved for day %d." % _current_day)
		return
	var block_data := BlockData.from_resolved_definition(resolved_definition)
	var camera_top_y := world_camera.position.y - float(GameConstants.VIEWPORT_SIZE.y) * 0.5
	var spawn_result := _pick_fair_spawn_position(block_data.size_cells, camera_top_y)
	if not bool(spawn_result.get("ok", false)):
		last_spawned_block_debug = "Boss spawn skipped: no safe airspace"
		return
	var spawn_position: Vector2 = spawn_result["position"]
	var block := FALLING_BLOCK_SCENE.instantiate() as FallingBlock
	blocks_root.add_child(block)
	block.setup(block_data, spawn_position, world_grid, sand_field, player)
	block.destroyed.connect(_on_block_destroyed)
	block.decomposed.connect(_on_block_decomposed)
	if _current_day == GameData.get_total_days():
		_day30_boss_alive = true
		block.destroyed.connect(_on_day30_boss_destroyed)
		block.decomposed.connect(_on_day30_boss_decomposed)
	last_spawned_block_debug = "Boss Spawn | %s" % block_data.get_block_base_debug_text()


func _on_day30_boss_destroyed(_block: FallingBlock) -> void:
	if run_finished:
		return
	_day30_boss_alive = false
	GameState.run_cleared = true
	GameState.current_run_stage_reached = _current_day
	_finish_temporary_run("cleared", Locale.ltr("run_day30_clear"))


func _on_day30_boss_decomposed(_block: FallingBlock, _reason: StringName) -> void:
	if run_finished:
		return
	_day30_boss_alive = false
	var surviving := GameState.player_health > 0 and sand_field.get_sand_count() < GameState.get_weight_limit_sand_cells()
	if surviving:
		GameState.run_cleared = true
		GameState.current_run_stage_reached = _current_day
		_finish_temporary_run("cleared", Locale.ltr("run_day30_clear"))


func _enter_intermission() -> void:
	if _is_intermission or _is_next_day_transitioning:
		return
	_is_day_active = false
	_is_intermission = true
	_is_intermission_locked = false
	_intermission_elapsed = 0.0
	_shop_ui_open = false
	_waiting_for_day_kiosk = true
	_kiosk_spawn_delay_remaining = -1.0
	_current_shop_item_ids = PackedStringArray()
	_has_shop_inventory_for_intermission = false
	GameState.reset_shop_reroll_count()
	GameState.reset_shop_locks()
	_day_time_remaining = 0.0
	GameState.day_time_remaining = 0.0
	spawn_timer.stop()
	GameState.set_status_text("Day 종료. 키오스크와 상호작용해 다음 날로 이동하세요.")


func _update_intermission(delta: float) -> void:
	_update_day_kiosk_deployment(delta)
	if _is_intermission_locked:
		return
	_intermission_elapsed += delta
	if _intermission_elapsed >= GameConstants.DAY_INTERMISSION_GRACE_DURATION:
		_is_intermission_locked = true
		GameState.set_status_text("유예 시간이 끝났습니다. 채굴만 정지되고 모래 반응은 유지됩니다.")


func _spawn_day_kiosk() -> void:
	if _day_kiosk != null and is_instance_valid(_day_kiosk):
		return
	_waiting_for_day_kiosk = false
	_kiosk_spawn_delay_remaining = -1.0
	_day_kiosk = DAY_KIOSK_SCRIPT.new() as Node2D
	add_child(_day_kiosk)
	var center_rect := GameConstants.get_center_rect()
	var camera_top_y := world_camera.position.y - float(GameConstants.VIEWPORT_SIZE.y) * 0.5
	var spawn_position := Vector2(
		center_rect.position.x + center_rect.size.x * 0.5,
		camera_top_y - 96.0
	)
	if _day_kiosk.has_method("setup"):
		_day_kiosk.call("setup", world_grid, sand_field, blocks_root, spawn_position)
	else:
		_day_kiosk.global_position = spawn_position
	_update_day_kiosk_prompt()


func _update_day_kiosk_prompt() -> void:
	if _day_kiosk == null or not is_instance_valid(_day_kiosk):
		return
	var kiosk_ready := true
	if _day_kiosk.has_method("is_interactable"):
		kiosk_ready = bool(_day_kiosk.call("is_interactable"))
	var can_interact := kiosk_ready and _is_player_near_day_kiosk() and not _shop_ui_open and not _is_next_day_transitioning
	if _day_kiosk.has_method("set_interaction_available"):
		_day_kiosk.call("set_interaction_available", can_interact)


func _despawn_day_kiosk() -> void:
	_waiting_for_day_kiosk = false
	_kiosk_spawn_delay_remaining = -1.0
	if _day_kiosk == null or not is_instance_valid(_day_kiosk):
		return
	_day_kiosk.queue_free()
	_day_kiosk = null


func _is_player_near_day_kiosk() -> bool:
	if _day_kiosk == null or not is_instance_valid(_day_kiosk):
		return false
	if _day_kiosk.has_method("is_interactable") and not bool(_day_kiosk.call("is_interactable")):
		return false
	return player.global_position.distance_to(_day_kiosk.global_position) <= GameConstants.DAY_KIOSK_INTERACTION_RANGE


func _open_day_shop() -> void:
	if _shop_ui_open or _is_next_day_transitioning:
		return
	if not _has_shop_inventory_for_intermission:
		GameState.reset_shop_reroll_count()
		GameState.reset_shop_locks()
		_current_shop_item_ids = GameData.roll_shop_item_ids(
			rng,
			GameConstants.DAY_SHOP_ITEM_COUNT,
			GameState.get_shop_roll_context()
		)
		_has_shop_inventory_for_intermission = true
	_day_shop_ui = DAY_SHOP_UI_SCRIPT.new()
	add_child(_day_shop_ui)
	if _day_shop_ui.has_method("set_shop_item_ids"):
		_day_shop_ui.call("set_shop_item_ids", _current_shop_item_ids)
	_day_shop_ui.next_day_requested.connect(_request_next_day_transition)
	_day_shop_ui.closed.connect(_on_day_shop_closed)
	if _day_shop_ui.has_signal("item_purchased"):
		_day_shop_ui.item_purchased.connect(_on_day_shop_item_purchased)
	if _day_shop_ui.has_signal("reroll_requested"):
		_day_shop_ui.reroll_requested.connect(_on_day_shop_reroll_requested)
	_shop_ui_open = true
	_update_day_kiosk_prompt()
	GameState.set_status_text("상점 화면이 열렸습니다. Next Day 버튼으로 다음 날을 시작할 수 있습니다.")


func _close_day_shop() -> void:
	if _day_shop_ui == null or not is_instance_valid(_day_shop_ui):
		_day_shop_ui = null
		_shop_ui_open = false
		return
	_day_shop_ui.queue_free()
	_day_shop_ui = null
	_shop_ui_open = false
	_update_day_kiosk_prompt()


func _on_day_shop_closed() -> void:
	_day_shop_ui = null
	_shop_ui_open = false
	_update_day_kiosk_prompt()
	GameState.set_status_text("상점을 닫았습니다. 키오스크에서 다시 열 수 있습니다.")


func _set_mining_idle_status(text: String) -> void:
	var now := Time.get_ticks_msec() * 0.001
	if text == _last_mining_idle_status_text:
		if now - _last_mining_idle_status_time < GameConstants.PLAYER_MINING_STATUS_MESSAGE_INTERVAL:
			return
	_last_mining_idle_status_text = text
	_last_mining_idle_status_time = now
	GameState.set_status_text(text)


func _on_day_shop_item_purchased(item_id: StringName) -> void:
	# 같은 상점 단계에서는 구매한 상품을 메인 보관 목록에서도 제거해 재등장을 막는다.
	var item_key := String(item_id)
	if not _current_shop_item_ids.has(item_key):
		return
	var remaining_ids := PackedStringArray()
	for raw_item_id in _current_shop_item_ids:
		if raw_item_id == item_key:
			continue
		remaining_ids.append(raw_item_id)
	_current_shop_item_ids = remaining_ids


func _on_day_shop_reroll_requested() -> void:
	if not _is_intermission or not _shop_ui_open or _is_next_day_transitioning:
		return
	var result := GameState.try_purchase_shop_reroll()
	if not bool(result.get("ok", false)):
		var reason := String(result.get("reason", "failed"))
		if reason == "insufficient_gold":
			GameState.set_status_text("Not enough gold to reroll.")
		else:
			GameState.set_status_text("Failed to reroll shop.")
		if _day_shop_ui != null and is_instance_valid(_day_shop_ui) and _day_shop_ui.has_method("set_shop_item_ids"):
			_day_shop_ui.call("set_shop_item_ids", _current_shop_item_ids)
		return
	_current_shop_item_ids = _reroll_shop_item_ids_preserving_locks()
	_has_shop_inventory_for_intermission = true
	if _day_shop_ui != null and is_instance_valid(_day_shop_ui) and _day_shop_ui.has_method("set_shop_item_ids"):
		_day_shop_ui.call("set_shop_item_ids", _current_shop_item_ids)
	GameState.set_status_text("Shop rerolled for %dG." % int(result.get("cost", 0)))


func _reroll_shop_item_ids_preserving_locks() -> PackedStringArray:
	var previous_ids := _current_shop_item_ids.duplicate()
	var locked_slots := GameState.get_current_shop_locked_slots()
	var used_ids: Dictionary = {}
	var result_ids := PackedStringArray()
	var replacement_count := 0
	for slot_index in range(GameConstants.DAY_SHOP_ITEM_COUNT):
		var keep_locked := bool(locked_slots.get(slot_index, false)) and slot_index < previous_ids.size()
		if keep_locked:
			var locked_item_id := String(previous_ids[slot_index])
			result_ids.append(locked_item_id)
			used_ids[locked_item_id] = true
		else:
			result_ids.append("")
			replacement_count += 1
	var replacements := _roll_shop_item_replacements(replacement_count, used_ids)
	var replacement_index := 0
	for slot_index in range(result_ids.size()):
		if not String(result_ids[slot_index]).is_empty():
			continue
		if replacement_index >= replacements.size():
			break
		result_ids[slot_index] = replacements[replacement_index]
		replacement_index += 1
	var compact_ids := PackedStringArray()
	for raw_item_id in result_ids:
		var item_id := String(raw_item_id)
		if item_id.is_empty():
			continue
		compact_ids.append(item_id)
	return compact_ids


func _roll_shop_item_replacements(count: int, used_ids: Dictionary) -> PackedStringArray:
	var replacements := PackedStringArray()
	if count <= 0:
		return replacements
	var attempts := 0
	while replacements.size() < count and attempts < 10:
		attempts += 1
		var rolled_ids := GameData.roll_shop_item_ids(
			rng,
			GameConstants.DAY_SHOP_ITEM_COUNT,
			GameState.get_shop_roll_context()
		)
		for raw_item_id in rolled_ids:
			var item_id := String(raw_item_id)
			if used_ids.has(item_id):
				continue
			replacements.append(item_id)
			used_ids[item_id] = true
			if replacements.size() >= count:
				break
	return replacements


func _request_next_day_transition() -> void:
	if _is_next_day_transitioning:
		return
	_start_next_day_transition()


func _start_next_day_transition() -> void:
	_is_next_day_transitioning = true
	_close_day_shop()
	GameState.reset_shop_locks()
	_despawn_day_kiosk()
	await _play_fade(1.0, GameConstants.DAY_TRANSITION_FADE_DURATION)
	_apply_next_day_interest()
	_apply_pending_wall_reset_for_next_day()
	_is_intermission = false
	_is_intermission_locked = false
	_intermission_elapsed = 0.0
	_is_day_active = true
	_advance_to_next_day()
	spawn_timer.start()
	await _play_fade(0.0, GameConstants.DAY_TRANSITION_FADE_DURATION)
	_is_next_day_transitioning = false


func queue_wall_reset_for_next_day() -> void:
	# TODO: 특정 상점 구매가 확정되면 이 훅을 호출해 다음 Day 전환에서만 벽을 복구한다.
	_pending_wall_reset_for_next_day = true


func _apply_pending_wall_reset_for_next_day() -> void:
	if not _pending_wall_reset_for_next_day:
		_last_transition_sand_report = "skipped(reset=false)"
		return
	_pending_wall_reset_for_next_day = false
	_restore_side_walls_preserving_sand()


func _restore_side_walls_preserving_sand() -> void:
	var sand_before := sand_field.get_sand_count()
	var wall_rects = world_grid.get_wall_restore_rects()
	var extracted_cells = sand_field.extract_sand_cells_in_rects(wall_rects)
	var collected_count := extracted_cells.size()
	var sand_after_extract := sand_field.get_sand_count()
	world_grid.restore_mining_walls()
	var blocked_rects := _collect_transition_blocking_rects()
	var placed_count := sand_field.redistribute_sand_cells_to_center(extracted_cells, blocked_rects)
	if placed_count < extracted_cells.size():
		var remaining_cells: Array = []
		for index in range(placed_count, extracted_cells.size()):
			remaining_cells.append(extracted_cells[index])
		placed_count += sand_field.redistribute_sand_cells_to_center(remaining_cells)
	var sand_after := sand_field.get_sand_count()
	var expected_after_extract := sand_before - collected_count
	var expected_after := expected_after_extract + placed_count
	_last_transition_sand_report = "before=%d collected=%d after_extract=%d reapplied=%d after=%d" % [
		sand_before,
		collected_count,
		sand_after_extract,
		placed_count,
		sand_after,
	]
	print("DayTransitionSandReport ", _last_transition_sand_report)
	if sand_after_extract != expected_after_extract:
		push_error("Day transition sand extraction mismatch: expected=%s actual=%s | %s" % [
			expected_after_extract,
			sand_after_extract,
			_last_transition_sand_report,
		])
	if sand_after != expected_after:
		push_error("Day transition sand reapply mismatch: expected=%s actual=%s | %s" % [
			expected_after,
			sand_after,
			_last_transition_sand_report,
		])
	if sand_before != sand_after or placed_count != collected_count:
		push_error("Day transition sand preservation mismatch | %s" % _last_transition_sand_report)


func _update_day_kiosk_deployment(delta: float) -> void:
	if not _waiting_for_day_kiosk or _is_next_day_transitioning:
		return
	if _day_kiosk != null and is_instance_valid(_day_kiosk):
		_waiting_for_day_kiosk = false
		return
	if _get_active_block_count() > 0:
		return
	if _kiosk_spawn_delay_remaining < 0.0:
		_kiosk_spawn_delay_remaining = GameConstants.DAY_KIOSK_DEPLOY_DELAY
		GameState.set_status_text("마지막 블록 정리 완료. 키오스크 투하를 준비합니다.")
		return
	_kiosk_spawn_delay_remaining = max(_kiosk_spawn_delay_remaining - delta, 0.0)
	if _kiosk_spawn_delay_remaining > 0.0:
		return
	_spawn_day_kiosk()
	GameState.set_status_text("키오스크가 투하되었습니다. 안착 후 상호작용할 수 있습니다.")


func _get_active_block_count() -> int:
	var active_count := 0
	for child in blocks_root.get_children():
		var block := child as FallingBlock
		if block != null and block.active:
			active_count += 1
	return active_count


func _collect_transition_blocking_rects() -> Array[Rect2]:
	var blocked_rects: Array[Rect2] = [player.get_body_rect()]
	for child in blocks_root.get_children():
		var block := child as FallingBlock
		if block != null and block.active:
			blocked_rects.append(block.get_block_rect())
	return blocked_rects


func _ensure_fade_overlay() -> void:
	if _fade_overlay != null:
		return
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 100
	add_child(fade_layer)
	_fade_overlay = ColorRect.new()
	_fade_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	fade_layer.add_child(_fade_overlay)


func _ensure_projectiles_root() -> void:
	if _projectiles_root != null and is_instance_valid(_projectiles_root):
		return
	_projectiles_root = Node2D.new()
	_projectiles_root.name = "Projectiles"
	_projectiles_root.z_index = 35
	add_child(_projectiles_root)


func _unhandled_input(event: InputEvent) -> void:
	if run_finished:
		return
	if event.is_action_pressed("pause_menu"):
		_toggle_pause_menu()
		get_viewport().set_input_as_handled()


func _toggle_pause_menu() -> void:
	if _shop_ui_open:
		_close_day_shop()
		GameState.set_status_text("?곸젏???レ븯?듬땲?? ?ㅼ삤?ㅽ겕?먯꽌 ?ㅼ떆 ?????덉뒿?덈떎.")
		return
	if _is_next_day_transitioning or run_finished:
		return
	if _pause_menu != null and is_instance_valid(_pause_menu):
		_close_pause_menu()
		return
	_open_pause_menu()


func _open_pause_menu() -> void:
	if _pause_menu != null and is_instance_valid(_pause_menu):
		return
	_pause_menu = PAUSE_MENU_SCRIPT.new()
	add_child(_pause_menu)
	if _pause_menu.has_signal("closed"):
		_pause_menu.closed.connect(_on_pause_menu_closed)
	get_tree().paused = true


func _close_pause_menu() -> void:
	if _pause_menu == null or not is_instance_valid(_pause_menu):
		_pause_menu = null
		get_tree().paused = false
		return
	get_tree().paused = false
	_pause_menu.queue_free()
	_pause_menu = null


func _on_pause_menu_closed() -> void:
	_pause_menu = null


func _update_player_regen(delta: float) -> void:
	if _shop_ui_open or _is_next_day_transitioning:
		return
	if GameState.player_health <= 0 or GameState.player_health >= GameState.get_player_max_health():
		return
	var regen_interval := GameState.get_hp_regen_interval()
	if not is_finite(regen_interval) or regen_interval <= 0.0:
		return
	_player_regen_accumulator += delta
	while _player_regen_accumulator >= regen_interval:
		_player_regen_accumulator -= regen_interval
		if GameState.player_health >= GameState.get_player_max_health():
			break
		GameState.heal_player(1)


func _apply_next_day_interest() -> void:
	var interest_amount := GameState.calculate_interest_payout()
	if interest_amount <= 0:
		return
	GameState.add_gold(interest_amount)


func _play_fade(target_alpha: float, duration: float) -> void:
	if _fade_overlay == null:
		return
	var tween := create_tween()
	tween.tween_property(_fade_overlay, "color:a", target_alpha, duration)
	await tween.finished


func _refresh_debug() -> void:
	hud.set_day_info(
		_current_day,
		GameData.get_total_days(),
		_day_time_remaining,
		GameData.get_day_type(_current_day),
		GameState.current_run_difficulty_name
	)
	if hud.has_method("update_sensors"):
		hud.update_sensors(player, blocks_root, sand_field, world_camera, GameState.get_weight_limit_sand_cells())
	if not hud.is_debug_visible():
		return
	hud.set_runtime_debug(
		blocks_root.get_child_count(),
		sand_field.get_sand_count(),
		world_grid.get_active_wall_count(),
		PackedStringArray([
			player.get_dash_debug_text(),
			last_spawned_block_debug,
		])
	)


func _configure_camera() -> void:
	world_camera.zoom = Vector2.ONE
	world_camera.position_smoothing_enabled = false
	world_camera.limit_left = GameConstants.WORLD_ORIGIN.x
	world_camera.limit_right = GameConstants.WORLD_ORIGIN.x + GameConstants.WORLD_PIXEL_WIDTH
	world_camera.limit_top = int(GameConstants.WORLD_PLAYABLE_TOP_Y)
	world_camera.limit_bottom = GameConstants.WORLD_ORIGIN.y + GameConstants.WORLD_PIXEL_HEIGHT
	world_camera.position = Vector2(
		float(GameConstants.WORLD_ORIGIN.x) + float(GameConstants.WORLD_PIXEL_WIDTH) * 0.5,
		_get_clamped_camera_y(player.position.y - CAMERA_PLAYER_Y_OFFSET)
	)


func _update_camera_y() -> void:
	world_camera.position.y = _get_clamped_camera_y(player.position.y - CAMERA_PLAYER_Y_OFFSET)


func _pick_fair_spawn_position(size_cells: Vector2i, camera_top_y: float) -> Dictionary:
	var min_col := GameConstants.WALL_COLUMNS
	var max_col := GameConstants.WORLD_COLUMNS - GameConstants.WALL_COLUMNS - size_cells.x
	camera_top_y = maxf(camera_top_y, GameConstants.BLOCK_SPAWN_MIN_CAMERA_TOP_Y)
	var half_size := Vector2(size_cells) * float(GameConstants.CELL_SIZE) * 0.5
	var band_near := float(GameConstants.CELL_SIZE) * GameConstants.BLOCK_SPAWN_BAND_NEAR_UNITS
	var band_far := float(GameConstants.CELL_SIZE) * GameConstants.BLOCK_SPAWN_BAND_FAR_UNITS
	var highest_active_top := _get_highest_active_block_top_y()
	for attempt in range(GameConstants.BLOCK_SPAWN_POSITION_ATTEMPTS):
		var col := _pick_spawn_column(min_col, max_col, attempt)
		var spawn_x := float(GameConstants.WORLD_ORIGIN.x) + (float(col) + float(size_cells.x) * 0.5) * float(GameConstants.CELL_SIZE)
		var spawn_y := camera_top_y - rng.randf_range(band_near, band_far) - half_size.y
		if is_finite(highest_active_top):
			spawn_y = minf(spawn_y, highest_active_top - band_near - half_size.y)
		var spawn_pos := Vector2(spawn_x, spawn_y)
		var spawn_rect := Rect2(spawn_pos - half_size, half_size * 2.0)
		if not _is_spawn_rect_safe(spawn_rect):
			continue
		return {
			"ok": true,
			"position": spawn_pos,
		}
	return {"ok": false}


func _get_clamped_camera_y(target_y: float) -> float:
	return clampf(
		target_y,
		GameConstants.WORLD_PLAYABLE_TOP_Y + float(GameConstants.VIEWPORT_SIZE.y) * 0.5,
		float(GameConstants.WORLD_ORIGIN.y + GameConstants.WORLD_PIXEL_HEIGHT) - float(GameConstants.VIEWPORT_SIZE.y) * 0.5
	)


func _pick_spawn_column(min_col: int, max_col: int, attempt: int) -> int:
	var col := rng.randi_range(min_col, max_col)
	if attempt == 0 and last_spawned_column >= 0 and max_col > min_col:
		var tries := 0
		while col == last_spawned_column and tries < 4:
			col = rng.randi_range(min_col, max_col)
			tries += 1
	return col


func _is_spawn_rect_safe(rect: Rect2) -> bool:
	if player != null and rect.intersects(player.get_body_rect()):
		return false
	return not _spawn_rect_overlaps_active_block(rect)


func _spawn_rect_overlaps_active_block(rect: Rect2) -> bool:
	var clearance := float(GameConstants.CELL_SIZE) * GameConstants.BLOCK_SPAWN_ACTIVE_BLOCK_CLEARANCE_UNITS
	var test_rect := rect.grow(clearance)
	for child in blocks_root.get_children():
		var block := child as FallingBlock
		if block != null and block.active and block.get_block_rect().intersects(test_rect):
			return true
	return false


func _get_highest_active_block_top_y() -> float:
	var highest := INF
	for child in blocks_root.get_children():
		var block := child as FallingBlock
		if block == null or not block.active:
			continue
		highest = minf(highest, block.get_block_rect().position.y)
	return highest


func _check_run_end_conditions() -> void:
	if GameState.player_health <= 0:
		_finish_temporary_run("health_depletion", Locale.ltr("run_health_depleted"))
		return
	if sand_field.get_sand_count() >= GameState.get_weight_limit_sand_cells():
		_finish_temporary_run("weight_overload", Locale.ltr("run_weight_overload"))


func _finish_temporary_run(reason_id: String = "run_end", reason_label: String = "Run Ended") -> void:
	if run_finished:
		return
	run_finished = true
	spawn_timer.stop()
	GameState.finish_temporary_run(reason_id, reason_label)
	get_tree().change_scene_to_file("res://scenes/ui/Result.tscn")


func _show_level_up_ui() -> void:
	if get_tree().paused:
		return
	get_tree().paused = true
	var level_up_ui_script = load("res://scenes/ui/LevelUpUI.gd")
	if level_up_ui_script:
		var level_ui = level_up_ui_script.new()
		add_child(level_ui)
