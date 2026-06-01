extends Node2D
class_name AttackModuleProjectile

const DEFAULT_COLOR := Color(0.58, 0.9, 1.0, 0.95)
const DEFAULT_TRAIL_COLOR := Color(0.58, 0.9, 1.0, 0.28)

var direction := Vector2.RIGHT
var speed := 900.0
var lifetime := 1.2
var max_distance := 900.0
var projectile_size := Vector2(18.0, 6.0)
var visual_offset := Vector2.ZERO
var damage := 1
var weapon_damage_for_sand := 1.0
var stagger_power := 0.0
var is_critical := false
var pierce_count := 0
var explosion_radius := 0.0
var homing := false
var effect_style: StringName = &"revolver_projectile"
var blocks_root: Node2D
var sand_field: SandField

var _elapsed := 0.0
var _travelled := 0.0
var _logical_position := Vector2.ZERO
var _hit_block_ids: Dictionary = {}
var _hit_sand_cells: Dictionary = {}


func setup(config: Dictionary) -> void:
	var start_position: Vector2 = config.get("position", global_position)
	var start_direction: Vector2 = config.get("direction", Vector2.RIGHT)
	var configured_size: Vector2 = config.get("size", projectile_size)
	var configured_visual_offset: Vector2 = config.get("visual_offset", Vector2.ZERO)
	var configured_blocks_root := config.get("blocks_root", null) as Node2D
	var configured_sand_field := config.get("sand_field", null) as SandField
	_logical_position = start_position
	visual_offset = configured_visual_offset
	global_position = _logical_position + visual_offset
	direction = start_direction.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	speed = float(config.get("speed", speed))
	lifetime = float(config.get("lifetime", lifetime))
	max_distance = float(config.get("max_distance", max_distance))
	projectile_size = configured_size
	damage = int(config.get("damage", damage))
	weapon_damage_for_sand = float(config.get("weapon_damage_for_sand", damage))
	stagger_power = maxf(float(config.get("stagger_power", stagger_power)), 0.0)
	is_critical = bool(config.get("is_critical", false))
	pierce_count = int(config.get("pierce_count", pierce_count))
	explosion_radius = maxf(float(config.get("explosion_radius", explosion_radius)), 0.0)
	homing = bool(config.get("homing", false))
	effect_style = StringName(String(config.get("effect_style", effect_style)))
	blocks_root = configured_blocks_root
	sand_field = configured_sand_field
	rotation = direction.angle()
	queue_redraw()


func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= lifetime or _travelled >= max_distance:
		queue_free()
		return
	if homing:
		_update_homing_direction(delta)
	var previous_position := _logical_position
	var motion := direction * speed * delta
	_logical_position += motion
	global_position = _logical_position + visual_offset
	rotation = direction.angle()
	_travelled += motion.length()
	_check_hits(previous_position, _logical_position)


func _check_hits(previous_position: Vector2, current_position: Vector2) -> void:
	var collisions := _collect_collision_candidates(previous_position, current_position)
	for collision in collisions:
		if _apply_collision(collision):
			return


func _collect_collision_candidates(previous_position: Vector2, current_position: Vector2) -> Array[Dictionary]:
	var collisions: Array[Dictionary] = []
	var sweep_rect := _build_sweep_rect(previous_position, current_position)
	var travel_direction := (current_position - previous_position).normalized()
	if travel_direction == Vector2.ZERO:
		travel_direction = direction
	if sand_field != null:
		for cell in sand_field.get_sand_cells_in_rect(sweep_rect):
			if _hit_sand_cells.has(cell):
				continue
			var cell_rect := sand_field.get_sand_cell_rect(cell)
			collisions.append(_make_collision_candidate(&"sand", cell, cell_rect, previous_position, travel_direction))
	if blocks_root != null:
		for child in blocks_root.get_children():
			var block := child as FallingBlock
			if block == null or not block.active:
				continue
			var block_id := block.get_instance_id()
			if _hit_block_ids.has(block_id):
				continue
			var block_rect := block.get_block_rect()
			if block_rect.intersects(sweep_rect):
				collisions.append(_make_collision_candidate(&"block", block, block_rect, previous_position, travel_direction))
	collisions.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var distance_a := float(a["distance"])
		var distance_b := float(b["distance"])
		if is_equal_approx(distance_a, distance_b):
			return String(a["type"]) < String(b["type"])
		return distance_a < distance_b
	)
	return collisions


func _make_collision_candidate(
	target_type: StringName,
	target,
	target_rect: Rect2,
	start_position: Vector2,
	travel_direction: Vector2
) -> Dictionary:
	var distance := _get_forward_collision_distance(target_rect, start_position, travel_direction)
	return {
		"type": target_type,
		"target": target,
		"position": start_position + travel_direction * maxf(distance, 0.0),
		"distance": distance,
	}


func _get_forward_collision_distance(target_rect: Rect2, start_position: Vector2, travel_direction: Vector2) -> float:
	var projected_half_extent := (
		absf(travel_direction.x) * target_rect.size.x
		+ absf(travel_direction.y) * target_rect.size.y
	) * 0.5
	return (target_rect.get_center() - start_position).dot(travel_direction) - projected_half_extent


func _apply_collision(collision: Dictionary) -> bool:
	var collision_position: Vector2 = collision["position"]
	if explosion_radius > 0.0:
		_explode_at(collision_position)
		queue_free()
		return true
	match StringName(collision["type"]):
		&"sand":
			var cell: Vector2i = collision["target"]
			if _hit_sand_cells.has(cell):
				return false
			_hit_sand_cells[cell] = true
			sand_field.apply_weapon_damage_to_sand_cell(cell, weapon_damage_for_sand, &"weapon")
		&"block":
			var block := collision["target"] as FallingBlock
			if block == null or not block.active:
				return false
			var block_id := block.get_instance_id()
			if _hit_block_ids.has(block_id):
				return false
			_hit_block_ids[block_id] = true
			block.apply_damage(damage, is_critical, stagger_power)
	return _consume_pierce_or_stop()


func _consume_pierce_or_stop() -> bool:
	if pierce_count <= 0:
		queue_free()
		return true
	pierce_count -= 1
	return false


func _explode_at(world_position: Vector2) -> void:
	if sand_field != null:
		sand_field.apply_weapon_damage_in_radius(
			world_position,
			explosion_radius,
			weapon_damage_for_sand,
			&"weapon"
		)
	if blocks_root == null:
		return
	for child in blocks_root.get_children():
		var block := child as FallingBlock
		if block == null or not block.active:
			continue
		if block.get_block_rect().grow(explosion_radius).has_point(world_position):
			block.apply_damage(damage, is_critical, stagger_power)


func _build_sweep_rect(previous_position: Vector2, current_position: Vector2) -> Rect2:
	var min_x := minf(previous_position.x, current_position.x) - projectile_size.x * 0.5
	var min_y := minf(previous_position.y, current_position.y) - projectile_size.y * 0.5
	var max_x := maxf(previous_position.x, current_position.x) + projectile_size.x * 0.5
	var max_y := maxf(previous_position.y, current_position.y) + projectile_size.y * 0.5
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))


func _update_homing_direction(delta: float) -> void:
	var target := _find_nearest_block()
	if target == null:
		return
	var desired_direction := (target.global_position - _logical_position).normalized()
	if desired_direction == Vector2.ZERO:
		return
	direction = direction.slerp(desired_direction, clampf(delta * 3.0, 0.0, 1.0)).normalized()


func _find_nearest_block() -> FallingBlock:
	if blocks_root == null:
		return null
	var best_block: FallingBlock = null
	var best_distance := INF
	for child in blocks_root.get_children():
		var block := child as FallingBlock
		if block == null or not block.active:
			continue
		var distance := _logical_position.distance_to(block.global_position)
		if distance >= best_distance:
			continue
		best_distance = distance
		best_block = block
	return best_block


func _draw() -> void:
	var half := projectile_size * 0.5
	var color := _get_effect_color()
	var trail_color := Color(color.r, color.g, color.b, maxf(color.a * 0.3, 0.2))
	draw_rect(Rect2(Vector2(-half.x, -half.y), projectile_size), color)
	draw_rect(Rect2(Vector2(-half.x - 18.0, -half.y * 0.55), Vector2(18.0, projectile_size.y * 0.55)), trail_color)


func _get_effect_color() -> Color:
	match String(effect_style):
		"revolver_projectile":
			return Color(1.0, 0.78, 0.42, 0.95)
		"shotgun_spread":
			return Color(1.0, 0.58, 0.34, 0.92)
		"sniper_projectile":
			return Color(0.72, 1.0, 0.84, 0.96)
		_:
			return DEFAULT_COLOR
