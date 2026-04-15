extends Node2D
class_name Player

var world_grid: WorldGrid
var sand_field: SandField
var blocks_root: Node2D
var velocity := Vector2.ZERO
var motion_remainder := Vector2.ZERO
var facing := Vector2i.RIGHT
var extra_jumps_left := GameConstants.PLAYER_EXTRA_JUMPS
var jump_buffer_remaining := 0.0
var coyote_time_remaining := 0.0
var attack_cooldown := 0.0
var attack_buffer_remaining := 0.0
var pending_attack_direction := Vector2.ZERO
var attack_visual_direction := Vector2.RIGHT
var damage_cooldown := 0.0
var attack_visual_time := 0.0
var jump_started_this_frame := false
var is_on_floor := false
var is_on_sand := false
var is_on_left_wall := false
var is_on_right_wall := false


func _ready() -> void:
	position = GameConstants.PLAYER_SPAWN_POSITION
	queue_redraw()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		jump_buffer_remaining = GameConstants.PLAYER_JUMP_BUFFER_TIME
	if event.is_action_pressed("primary_action"):
		attack_buffer_remaining = GameConstants.PLAYER_ATTACK_BUFFER_TIME
		pending_attack_direction = _resolve_attack_direction()
		attack_visual_direction = pending_attack_direction
		attack_visual_time = GameConstants.PLAYER_ATTACK_VISUAL_DURATION
		queue_redraw()


func setup(target_world: WorldGrid, target_sand: SandField, target_blocks: Node2D) -> void:
	world_grid = target_world
	sand_field = target_sand
	blocks_root = target_blocks
	_refresh_contacts()


func _physics_process(delta: float) -> void:
	if world_grid == null or sand_field == null:
		return
	_ride_supporting_block()
	jump_buffer_remaining = max(jump_buffer_remaining - delta, 0.0)
	coyote_time_remaining = max(coyote_time_remaining - delta, 0.0)
	attack_cooldown = max(attack_cooldown - delta, 0.0)
	attack_buffer_remaining = max(attack_buffer_remaining - delta, 0.0)
	damage_cooldown = max(damage_cooldown - delta, 0.0)
	attack_visual_time = max(attack_visual_time - delta, 0.0)
	jump_started_this_frame = false
	_refresh_contacts()
	_apply_jump_input()
	_apply_gravity(delta)
	_apply_horizontal_input()
	_move_with_collisions(delta)
	_snap_to_supporting_block()
	_refresh_contacts()
	queue_redraw()


func get_body_rect() -> Rect2:
	var body := _get_body_local_rect()
	return Rect2(position + body.position, body.size)


func consume_primary_action_direction() -> Vector2:
	if attack_cooldown > 0.0:
		return Vector2.ZERO
	if attack_buffer_remaining <= 0.0:
		return Vector2.ZERO
	attack_buffer_remaining = 0.0
	attack_cooldown = GameConstants.PLAYER_ATTACK_COOLDOWN
	var direction := pending_attack_direction
	if direction == Vector2.ZERO:
		direction = _resolve_attack_direction()
	attack_visual_direction = direction
	attack_visual_time = GameConstants.PLAYER_ATTACK_VISUAL_DURATION
	queue_redraw()
	return direction


func get_attack_shape_data(direction: Vector2) -> Dictionary:
	var local_data := _get_attack_local_shape_data(direction)
	return {
		"center": position + local_data["center"],
		"size": local_data["size"],
		"rotation": local_data["rotation"],
	}


func is_rect_blocked_by_falling_block(target_rect: Rect2) -> bool:
	if blocks_root == null:
		return false
	for child in blocks_root.get_children():
		var block: FallingBlock = child as FallingBlock
		if block != null and block.is_blocking_rect(target_rect):
			return true
	return false


func is_crushable_under(block_rect: Rect2) -> bool:
	if not block_rect.intersects(get_body_rect()):
		return false
	var body := get_body_rect()
	var support_probe := Rect2(Vector2(body.position.x + 6.0, body.end.y), Vector2(body.size.x - 12.0, 2.0))
	return world_grid.rect_collides_static(support_probe) or sand_field.rect_collides(support_probe) or is_rect_blocked_by_falling_block(support_probe)


func get_head_y() -> float:
	return get_body_rect().position.y


func get_attack_direction() -> Vector2:
	return _resolve_attack_direction()


func get_mining_direction(attack_direction: Vector2) -> Vector2i:
	if attack_direction == Vector2.ZERO:
		return Vector2i.ZERO
	if absf(attack_direction.x) < absf(attack_direction.y):
		return Vector2i.ZERO
	return Vector2i.RIGHT if attack_direction.x >= 0.0 else Vector2i.LEFT


func get_mining_rect(direction: Vector2i) -> Rect2:
	var attack_local := _get_axis_attack_local_rect(direction)
	return Rect2(position + attack_local.position, attack_local.size)


func receive_crush_hit() -> bool:
	if damage_cooldown > 0.0:
		return false
	damage_cooldown = GameConstants.PLAYER_DAMAGE_INVULNERABILITY
	GameState.damage_player(GameConstants.PLAYER_CRUSH_DAMAGE)
	return true


func _apply_horizontal_input() -> void:
	var input_strength := Input.get_axis("move_left", "move_right")
	if input_strength != 0.0:
		facing = Vector2i(_sign_to_int(input_strength), 0)
	var move_speed := GameConstants.PLAYER_MOVE_SPEED if is_on_floor else GameConstants.PLAYER_AIR_SPEED
	if is_on_sand:
		move_speed *= GameConstants.PLAYER_SAND_SPEED_MULTIPLIER
	velocity.x = input_strength * move_speed


func _apply_jump_input() -> void:
	if is_on_floor:
		extra_jumps_left = GameConstants.PLAYER_EXTRA_JUMPS
		coyote_time_remaining = GameConstants.PLAYER_COYOTE_TIME
	if jump_buffer_remaining <= 0.0:
		return
	if is_on_floor or coyote_time_remaining > 0.0:
		jump_buffer_remaining = 0.0
		coyote_time_remaining = 0.0
		sand_field.try_clear_jump_space(get_body_rect(), facing.x)
		velocity.y = GameConstants.PLAYER_JUMP_SPEED
		jump_started_this_frame = true
		return
	if is_on_left_wall or is_on_right_wall:
		jump_buffer_remaining = 0.0
		var wall_direction := 1 if is_on_left_wall else -1
		sand_field.try_clear_jump_space(get_body_rect(), wall_direction)
		velocity.x = wall_direction * GameConstants.PLAYER_WALL_JUMP_SPEED_X
		velocity.y = GameConstants.PLAYER_JUMP_SPEED
		extra_jumps_left = GameConstants.PLAYER_EXTRA_JUMPS
		coyote_time_remaining = 0.0
		jump_started_this_frame = true
		return
	if extra_jumps_left > 0:
		jump_buffer_remaining = 0.0
		extra_jumps_left -= 1
		sand_field.try_clear_jump_space(get_body_rect(), facing.x)
		velocity.y = GameConstants.PLAYER_JUMP_SPEED
		jump_started_this_frame = true


func _apply_gravity(delta: float) -> void:
	if is_on_floor and velocity.y > 0.0:
		velocity.y = 0.0
		return
	velocity.y += GameConstants.PLAYER_GRAVITY * delta
	if Input.is_action_pressed("move_down") and not is_on_floor:
		velocity.y = min(
			velocity.y + GameConstants.PLAYER_FAST_FALL_ACCELERATION * delta,
			GameConstants.PLAYER_FAST_FALL_SPEED
		)
	if (is_on_left_wall or is_on_right_wall) and velocity.y > GameConstants.PLAYER_WALL_SLIDE_SPEED:
		velocity.y = GameConstants.PLAYER_WALL_SLIDE_SPEED


func _move_with_collisions(delta: float) -> void:
	motion_remainder.x += velocity.x * delta
	motion_remainder.y += velocity.y * delta
	var step_x := int(signf(motion_remainder.x) * floor(absf(motion_remainder.x)))
	var step_y := int(signf(motion_remainder.y) * floor(absf(motion_remainder.y)))
	motion_remainder.x -= step_x
	motion_remainder.y -= step_y
	var move_vertical_first := jump_started_this_frame or velocity.y < 0.0
	if move_vertical_first:
		_move_axis(step_y, false)
		_move_axis(step_x, true)
		return
	_move_axis(step_x, true)
	_move_axis(step_y, false)


func _move_axis(steps: int, horizontal: bool) -> void:
	if steps == 0:
		return
	var direction := 1 if steps > 0 else -1
	for _index in range(abs(steps)):
		var next_position := position
		if horizontal:
			next_position.x += direction
		else:
			next_position.y += direction
		var next_rect := Rect2(next_position + _get_body_local_rect().position, GameConstants.PLAYER_SIZE)
		if _movement_collides(next_rect, horizontal, direction):
			if horizontal:
				velocity.x = 0.0
			else:
				velocity.y = 0.0
			break
		position = next_position


func _movement_collides(rect: Rect2, horizontal: bool, direction: int) -> bool:
	if world_grid.rect_collides_static(rect) or is_rect_blocked_by_falling_block(rect):
		return true
	var sand_rect := rect
	if horizontal:
		sand_rect = _get_lower_sand_rect(rect)
	elif direction < 0:
		sand_rect = _get_upward_sand_rect(rect)
	if sand_field.rect_collides(sand_rect):
		if not horizontal and direction < 0 and sand_field.try_clear_jump_space(rect, facing.x):
			return sand_field.rect_collides(sand_rect)
		if horizontal and sand_field.try_push_for_body(rect, direction):
			return sand_field.rect_collides(rect)
		return true
	return false


func _rect_collides(rect: Rect2) -> bool:
	return world_grid.rect_collides_static(rect) or sand_field.rect_collides(rect) or is_rect_blocked_by_falling_block(rect)


func _refresh_contacts() -> void:
	var body := get_body_rect()
	var floor_probe := Rect2(Vector2(body.position.x + 6.0, body.end.y), Vector2(body.size.x - 12.0, 2.0))
	is_on_floor = _rect_collides(floor_probe)
	var left_probe := Rect2(Vector2(body.position.x - 2.0, body.position.y + 4.0), Vector2(4.0, body.size.y - 8.0))
	var right_probe := Rect2(Vector2(body.end.x - 2.0, body.position.y + 4.0), Vector2(4.0, body.size.y - 8.0))
	is_on_left_wall = world_grid.rect_collides_static(left_probe)
	is_on_right_wall = world_grid.rect_collides_static(right_probe)
	var sand_probe := Rect2(Vector2(body.position.x + 6.0, body.end.y), Vector2(body.size.x - 12.0, 2.0))
	is_on_sand = sand_field.rect_collides(sand_probe)


func _ride_supporting_block() -> void:
	var support_block := _get_supporting_block()
	if support_block == null:
		return
	var support_motion := support_block.get_frame_motion()
	if support_motion == Vector2.ZERO:
		return
	var moved_rect := get_body_rect()
	moved_rect.position += support_motion
	if _rect_collides_excluding_block(moved_rect, support_block):
		return
	position += support_motion
	if velocity.y > 0.0:
		velocity.y = 0.0
	motion_remainder.y = 0.0


func _get_supporting_block() -> FallingBlock:
	if blocks_root == null:
		return null
	var body := get_body_rect()
	var body_left := body.position.x + 6.0
	var body_right := body.end.x - 6.0
	var best_block: FallingBlock = null
	var best_top := INF
	for child in blocks_root.get_children():
		var block := child as FallingBlock
		if block == null or not block.active:
			continue
		var block_rect := block.get_block_rect()
		if absf(body.end.y - block_rect.position.y) > 3.0:
			continue
		var overlap_left := maxf(body_left, block_rect.position.x)
		var overlap_right := minf(body_right, block_rect.end.x)
		if overlap_right <= overlap_left:
			continue
		if block_rect.position.y < best_top:
			best_top = block_rect.position.y
			best_block = block
	return best_block


func _rect_collides_excluding_block(rect: Rect2, excluded_block: FallingBlock) -> bool:
	if world_grid.rect_collides_static(rect) or sand_field.rect_collides(rect):
		return true
	if blocks_root == null:
		return false
	for child in blocks_root.get_children():
		var block := child as FallingBlock
		if block == null or block == excluded_block:
			continue
		if block.is_blocking_rect(rect):
			return true
	return false


func _snap_to_supporting_block() -> void:
	if velocity.y < 0.0:
		return
	var support_block := _get_supporting_block()
	if support_block == null:
		return
	var block_rect := support_block.get_block_rect()
	var target_center_y := block_rect.position.y - GameConstants.PLAYER_SIZE.y * 0.5
	if position.y <= target_center_y + 3.0:
		position.y = target_center_y
		velocity.y = 0.0
		motion_remainder.y = 0.0


func _resolve_attack_direction() -> Vector2:
	var to_mouse := get_global_mouse_position() - get_body_rect().get_center()
	if to_mouse.length() <= GameConstants.PLAYER_ATTACK_DIRECTION_DEADZONE:
		return Vector2(facing)
	if to_mouse.x > 0.0:
		facing = Vector2i.RIGHT
	elif to_mouse.x < 0.0:
		facing = Vector2i.LEFT
	return to_mouse.normalized()


func _get_attack_local_shape_data(direction: Vector2) -> Dictionary:
	var attack_direction := direction.normalized()
	if attack_direction == Vector2.ZERO:
		attack_direction = Vector2(facing)
	var attack_size := Vector2(GameConstants.PLAYER_ATTACK_RANGE, GameConstants.PLAYER_ATTACK_THICKNESS)
	var center_offset := attack_direction * ((GameConstants.PLAYER_SIZE.x + attack_size.x) * 0.5)
	return {
		"center": center_offset,
		"size": attack_size,
		"rotation": attack_direction.angle(),
	}


func _get_axis_attack_local_rect(direction: Vector2i) -> Rect2:
	var body := _get_body_local_rect()
	var attack_size := Vector2.ONE * GameConstants.CELL_SIZE
	if direction.x > 0:
		return Rect2(
			Vector2(body.end.x, -attack_size.y * 0.5),
			attack_size
		)
	if direction.x < 0:
		return Rect2(
			Vector2(body.position.x - attack_size.x, -attack_size.y * 0.5),
			attack_size
		)
	if direction.y < 0:
		return Rect2(
			Vector2(-attack_size.x * 0.5, body.position.y - attack_size.y),
			attack_size
		)
	return Rect2(
		Vector2(-attack_size.x * 0.5, body.end.y),
		attack_size
	)


func _get_attack_preview_polygon(direction: Vector2) -> PackedVector2Array:
	var shape_data := _get_attack_local_shape_data(direction)
	var center: Vector2 = shape_data["center"]
	var size: Vector2 = shape_data["size"]
	var attack_direction := Vector2.RIGHT.rotated(shape_data["rotation"])
	var half_forward := attack_direction * (size.x * 0.5)
	var half_side := attack_direction.orthogonal() * (size.y * 0.5)
	return PackedVector2Array([
		center - half_forward - half_side,
		center + half_forward - half_side,
		center + half_forward + half_side,
		center - half_forward + half_side,
	])


func _get_body_local_rect() -> Rect2:
	return Rect2(-GameConstants.PLAYER_SIZE * 0.5, GameConstants.PLAYER_SIZE)


func _get_lower_sand_rect(rect: Rect2) -> Rect2:
	var top := rect.position.y + rect.size.y * 0.42
	return Rect2(Vector2(rect.position.x, top), Vector2(rect.size.x, rect.end.y - top))


func _get_upward_sand_rect(rect: Rect2) -> Rect2:
	var side_margin := float(GameConstants.SAND_CELL_SIZE)
	var width: float = maxf(rect.size.x - side_margin * 2.0, side_margin * 2.0)
	var head_height: float = maxf(float(GameConstants.SAND_CELL_SIZE) * 2.0, rect.size.y * 0.55)
	return Rect2(
		Vector2(rect.position.x + (rect.size.x - width) * 0.5, rect.position.y),
		Vector2(width, head_height)
	)


func _sign_to_int(value: float) -> int:
	if value > 0.0:
		return 1
	if value < 0.0:
		return -1
	return 0


func _draw() -> void:
	var body := _get_body_local_rect()
	var fill_color := GameConstants.PLAYER_HURT_COLOR if damage_cooldown > 0.0 else GameConstants.PLAYER_COLOR
	draw_rect(body, fill_color)
	if attack_visual_time > 0.0:
		var preview_polygon := _get_attack_preview_polygon(attack_visual_direction)
		draw_colored_polygon(preview_polygon, GameConstants.ATTACK_PREVIEW_COLOR)
		for index in range(preview_polygon.size()):
			var next_index := (index + 1) % preview_polygon.size()
			draw_line(preview_polygon[index], preview_polygon[next_index], Color(0.95, 0.45, 0.33, 0.95), 2.0)
