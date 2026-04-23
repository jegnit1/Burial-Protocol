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
var is_critical := false
var pierce_count := 0
var homing := false
var blocks_root: Node2D

var _elapsed := 0.0
var _travelled := 0.0
var _logical_position := Vector2.ZERO
var _hit_block_ids: Dictionary = {}


func setup(config: Dictionary) -> void:
	var start_position: Vector2 = config.get("position", global_position)
	var start_direction: Vector2 = config.get("direction", Vector2.RIGHT)
	var configured_size: Vector2 = config.get("size", projectile_size)
	var configured_visual_offset: Vector2 = config.get("visual_offset", Vector2.ZERO)
	var configured_blocks_root := config.get("blocks_root", null) as Node2D
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
	is_critical = bool(config.get("is_critical", false))
	pierce_count = int(config.get("pierce_count", pierce_count))
	homing = bool(config.get("homing", false))
	blocks_root = configured_blocks_root
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
	_check_block_hits(previous_position, _logical_position)


func _check_block_hits(previous_position: Vector2, current_position: Vector2) -> void:
	if blocks_root == null:
		return
	var sweep_rect := _build_sweep_rect(previous_position, current_position)
	for child in blocks_root.get_children():
		var block := child as FallingBlock
		if block == null or not block.active:
			continue
		var block_id := block.get_instance_id()
		if _hit_block_ids.has(block_id):
			continue
		if not block.get_block_rect().intersects(sweep_rect):
			continue
		_hit_block_ids[block_id] = true
		block.apply_damage(damage, is_critical)
		if pierce_count <= 0:
			queue_free()
			return
		pierce_count -= 1


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
	draw_rect(Rect2(Vector2(-half.x, -half.y), projectile_size), DEFAULT_COLOR)
	draw_rect(Rect2(Vector2(-half.x - 18.0, -half.y * 0.55), Vector2(18.0, projectile_size.y * 0.55)), DEFAULT_TRAIL_COLOR)
