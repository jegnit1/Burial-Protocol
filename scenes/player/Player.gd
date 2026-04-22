extends Node2D
class_name Player

const IDLE_ANIMATION: StringName = &"idle"
const RUN_ANIMATION: StringName = &"run"
const HORIZONTAL_SAND_PUSH_ATTEMPTS := 2
const DASH_HORIZONTAL_SAND_PUSH_ATTEMPTS := 2
const SAND_SLOPE_STEP_HEIGHT := 10
const SAND_SLOPE_STEP_SAMPLES := 3
const DASH_DOWNWARD_SAND_SIDE_MARGIN := 6.0
const DASH_FEEDBACK_DURATION := 0.14
const DASH_TRAIL_ALPHA := 0.32
const DASH_OUTLINE_WIDTH := 3.0
const ATTACK_MODULE_ORBIT_RADIUS := 36.0
const ATTACK_MODULE_ORBIT_SPEED := 1.35
const ATTACK_MODULE_BOB_AMPLITUDE := 4.0
const ATTACK_MODULE_BOB_SPEED := 2.6
const ATTACK_MODULE_STRIKE_DISTANCE := 22.0
const ATTACK_MODULE_STRIKE_DURATION := 0.12
const DAMAGE_POPUP_SCRIPT := preload("res://scenes/ui/DamagePopup.gd")
# 스프라이트 시각 영역에 맞게 충돌 박스를 줄이는 inset (픽셀).
# x: 좌우 각각 줄임. y는 반드시 0 — y를 바꾸면 바닥/블록 감지가 깨짐.
const COLLISION_INSET := Vector2(28.0, 0.0)

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
var attack_visual_time := 0.0
var mining_cooldown := 0.0
var mining_buffer_remaining := 0.0
var pending_mine_direction := Vector2.ZERO
var mining_visual_direction := Vector2.RIGHT
var mining_visual_time := 0.0
var is_dashing := false
var dash_requested := false
var dash_direction := Vector2.ZERO
var pending_dash_direction := Vector2.ZERO
var dash_time_remaining := 0.0
var dash_cooldown_remaining := 0.0
var dash_distance_remaining := 0.0
var dash_motion_remainder := 0.0
var last_left_tap_time := -1.0
var last_right_tap_time := -1.0
var last_down_tap_time := -1.0
var dash_debug_last_event := ""
var dash_feedback_time := 0.0
var dash_feedback_state: StringName = &""
var damage_cooldown := 0.0
var hurt_flash_remaining := 0.0
var jump_started_this_frame := false
var _had_active_visuals := false
var is_on_floor := false
var is_on_sand := false
var is_on_left_wall := false
var is_on_right_wall := false
var current_battery := GameConstants.PLAYER_BATTERY_MAX
var is_wall_climbing := false
var animated_sprite_base_scale := Vector2.ONE
var attack_module_visual: Node2D
var attack_module_visual_scene_path := ""
var attack_module_orbit_angle := 0.0
var attack_module_bob_time := 0.0
var attack_module_strike_time_remaining := 0.0
var attack_module_strike_direction := Vector2.RIGHT

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	position = GameConstants.PLAYER_SPAWN_POSITION
	current_battery = GameConstants.PLAYER_BATTERY_MAX
	is_wall_climbing = false
	_cache_sprite_base_scale()
	_update_sprite_visuals(0.0)
	queue_redraw()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		jump_buffer_remaining = GameConstants.PLAYER_JUMP_BUFFER_TIME
	if event.is_action_pressed("attack_action"):
		attack_buffer_remaining = GameConstants.PLAYER_ATTACK_BUFFER_TIME
		pending_attack_direction = _resolve_attack_direction()
	if event.is_action_pressed("mine_action"):
		mining_buffer_remaining = GameConstants.PLAYER_MINING_BUFFER_TIME
		pending_mine_direction = _resolve_attack_direction()
	if event.is_action_pressed("move_left", false, false):
		last_left_tap_time = _register_dash_tap(Vector2.LEFT, last_left_tap_time)
	if event.is_action_pressed("move_right", false, false):
		last_right_tap_time = _register_dash_tap(Vector2.RIGHT, last_right_tap_time)
	if GameConstants.PLAYER_DASH_DOWN_ENABLED and event.is_action_pressed("move_down", false, false):
		last_down_tap_time = _register_dash_tap(Vector2.DOWN, last_down_tap_time)
	if event.is_action_pressed("dash_action", false, false):
		var dash_input_direction := _resolve_dash_action_direction()
		if dash_input_direction != Vector2.ZERO:
			_queue_dash_request(dash_input_direction)


func setup(target_world: WorldGrid, target_sand: SandField, target_blocks: Node2D) -> void:
	world_grid = target_world
	sand_field = target_sand
	blocks_root = target_blocks
	current_battery = GameConstants.PLAYER_BATTERY_MAX
	is_wall_climbing = false
	if not GameState.attack_module_changed.is_connected(_on_attack_module_changed):
		GameState.attack_module_changed.connect(_on_attack_module_changed)
	_sync_attack_module_visual()
	_refresh_contacts()


func _physics_process(delta: float) -> void:
	if world_grid == null or sand_field == null:
		return
	var previous_position := position
	_ride_supporting_block()
	jump_buffer_remaining = max(jump_buffer_remaining - delta, 0.0)
	coyote_time_remaining = max(coyote_time_remaining - delta, 0.0)
	attack_cooldown = max(attack_cooldown - delta, 0.0)
	attack_buffer_remaining = max(attack_buffer_remaining - delta, 0.0)
	
	if Input.is_action_pressed("attack_action"):
		attack_buffer_remaining = GameConstants.PLAYER_ATTACK_BUFFER_TIME
		pending_attack_direction = _resolve_attack_direction()
	if Input.is_action_pressed("mine_action"):
		mining_buffer_remaining = GameConstants.PLAYER_MINING_BUFFER_TIME
		pending_mine_direction = _resolve_attack_direction()
	mining_cooldown = max(mining_cooldown - delta, 0.0)
	mining_buffer_remaining = max(mining_buffer_remaining - delta, 0.0)
	dash_cooldown_remaining = max(dash_cooldown_remaining - delta, 0.0)
	dash_time_remaining = max(dash_time_remaining - delta, 0.0)
	dash_feedback_time = max(dash_feedback_time - delta, 0.0)
	damage_cooldown = max(damage_cooldown - delta, 0.0)
	hurt_flash_remaining = max(hurt_flash_remaining - delta, 0.0)
	attack_visual_time = max(attack_visual_time - delta, 0.0)
	mining_visual_time = max(mining_visual_time - delta, 0.0)
	attack_module_strike_time_remaining = max(attack_module_strike_time_remaining - delta, 0.0)
	_process_pending_dash_request()
	_update_dash_state()
	jump_started_this_frame = false
	_refresh_contacts()
	_update_wall_climb_state(delta)
	if is_dashing:
		_apply_dash_movement(delta)
	else:
		_apply_jump_input()
		_apply_gravity(delta)
		_apply_horizontal_input()
		_move_with_collisions(delta)
	_snap_to_supporting_block()
	_refresh_contacts()
	_update_sprite_visuals(position.x - previous_position.x)
	_update_attack_module_visual(delta)
	var _has_active_visuals := (
		is_dashing
		or dash_feedback_time > 0.0
		or attack_visual_time > 0.0
		or (mining_visual_time > 0.0 and mining_visual_direction != Vector2.ZERO)
		or damage_cooldown > 0.0
		or hurt_flash_remaining > 0.0
	)
	if _has_active_visuals or _had_active_visuals:
		queue_redraw()
	_had_active_visuals = _has_active_visuals


func get_body_rect() -> Rect2:
	var body := _get_body_local_rect()
	return Rect2(position + body.position, body.size)


func consume_primary_action_direction() -> Vector2:
	return consume_attack_direction()


func consume_dash_request() -> Vector2:
	var request_direction := pending_dash_direction
	pending_dash_direction = Vector2.ZERO
	dash_requested = false
	return request_direction


func can_dash() -> bool:
	return dash_cooldown_remaining <= 0.0 and not is_dashing


func get_current_battery() -> float:
	return current_battery


func get_max_battery() -> float:
	return GameConstants.PLAYER_BATTERY_MAX


func get_dash_cooldown_remaining() -> float:
	return dash_cooldown_remaining


func get_dash_cooldown_duration() -> float:
	return GameConstants.PLAYER_DASH_COOLDOWN


func get_dash_debug_text() -> String:
	var pending_text := "yes" if pending_dash_direction != Vector2.ZERO or dash_requested else "no"
	return "Dash %s | Dir %s | CD %.2f | Pending %s | Battery %.0f | WallClimb %s | Event %s" % [
		"ON" if is_dashing else "off",
		_vector_to_debug_text(dash_direction),
		dash_cooldown_remaining,
		pending_text,
		current_battery,
		"ON" if is_wall_climbing else "off",
		String(dash_debug_last_event),
	]


func consume_attack_direction() -> Vector2:
	if is_dashing:
		return Vector2.ZERO
	if attack_cooldown > 0.0:
		return Vector2.ZERO
	if attack_buffer_remaining <= 0.0:
		return Vector2.ZERO
	attack_buffer_remaining = 0.0
	attack_cooldown = GameState.get_attack_cooldown_duration()
	var direction := pending_attack_direction
	if direction == Vector2.ZERO:
		direction = _resolve_attack_direction()
	attack_visual_direction = direction
	attack_visual_time = GameConstants.PLAYER_ATTACK_VISUAL_DURATION
	_play_attack_module_strike(direction)
	queue_redraw()
	return direction


func consume_mining_direction() -> Vector2:
	if is_dashing:
		return Vector2.ZERO
	if mining_cooldown > 0.0:
		return Vector2.ZERO
	if mining_buffer_remaining <= 0.0:
		return Vector2.ZERO
	mining_buffer_remaining = 0.0
	mining_cooldown = GameState.get_mining_cooldown_duration()
	var direction := pending_mine_direction
	if direction == Vector2.ZERO:
		direction = _resolve_attack_direction()
	direction = get_mining_direction(direction)
	mining_visual_direction = direction
	mining_visual_time = GameConstants.PLAYER_ATTACK_VISUAL_DURATION
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


func get_mining_direction(attack_direction: Vector2) -> Vector2:
	if attack_direction == Vector2.ZERO:
		return Vector2.ZERO
	return attack_direction.normalized()


func get_mining_shape_data(direction: Vector2) -> Dictionary:
	var local_data := _get_mining_local_shape_data(direction)
	return {
		"center": position + local_data["center"],
		"size": local_data["size"],
		"rotation": local_data["rotation"],
		"direction": local_data["direction"],
		"origin": position + local_data["origin"],
	}


func receive_crush_hit(amount: int) -> bool:
	if damage_cooldown > 0.0:
		return false
	damage_cooldown = GameConstants.PLAYER_DAMAGE_INVULNERABILITY
	hurt_flash_remaining = GameConstants.PLAYER_HURT_FLASH_DURATION
	var applied_damage := GameState.damage_player(amount)
	_spawn_player_damage_popup(applied_damage)
	_update_sprite_visuals(0.0)
	return true


func _register_dash_tap(direction: Vector2, previous_tap_time: float) -> float:
	var current_time := _get_input_time_seconds()
	if previous_tap_time >= 0.0 and current_time - previous_tap_time <= GameConstants.PLAYER_DASH_DOUBLE_TAP_WINDOW:
		_queue_dash_request(direction)
		return -1.0
	return current_time


func _queue_dash_request(direction: Vector2) -> void:
	if not _is_dash_direction_enabled(direction):
		dash_debug_last_event = "dash_direction_disabled"
		_set_dash_feedback(&"blocked")
		return
	if not can_dash():
		dash_debug_last_event = "dash_on_cooldown"
		_set_dash_feedback(&"cooldown")
		GameState.set_status_text("Dash is on cooldown.")
		return
	pending_dash_direction = direction.normalized()
	dash_requested = true
	dash_debug_last_event = "dash_requested"
	_set_dash_feedback(&"queued")


func _process_pending_dash_request() -> void:
	if not dash_requested or pending_dash_direction == Vector2.ZERO:
		return
	if not can_dash():
		return
	is_dashing = true
	dash_direction = pending_dash_direction
	dash_time_remaining = GameConstants.PLAYER_DASH_DURATION
	dash_cooldown_remaining = GameConstants.PLAYER_DASH_COOLDOWN
	dash_distance_remaining = GameConstants.PLAYER_DASH_DISTANCE
	dash_motion_remainder = 0.0
	motion_remainder = Vector2.ZERO
	if dash_direction.x != 0.0:
		facing = Vector2i(_sign_to_int(dash_direction.x), 0)
	dash_requested = false
	pending_dash_direction = Vector2.ZERO
	dash_debug_last_event = "dash_armed"
	_set_dash_feedback(&"armed")


func _update_dash_state() -> void:
	if not is_dashing:
		return
	if dash_time_remaining > 0.0 and dash_distance_remaining > 0.0:
		return
	_finish_dash("dash_finished")


func _is_dash_direction_enabled(direction: Vector2) -> bool:
	if direction == Vector2.ZERO:
		return false
	if direction.y < 0.0:
		return GameConstants.PLAYER_DASH_UP_ENABLED
	if direction.y > 0.0:
		return GameConstants.PLAYER_DASH_DOWN_ENABLED
	return true


func _get_input_time_seconds() -> float:
	return Time.get_ticks_msec() * 0.001


func _resolve_dash_action_direction() -> Vector2:
	var left_pressed := Input.is_action_pressed("move_left")
	var right_pressed := Input.is_action_pressed("move_right")
	var down_pressed := GameConstants.PLAYER_DASH_DOWN_ENABLED and Input.is_action_pressed("move_down")
	if left_pressed != right_pressed:
		return Vector2.LEFT if left_pressed else Vector2.RIGHT
	if down_pressed:
		return Vector2.DOWN
	return Vector2.ZERO


func _update_sprite_visuals(horizontal_motion: float) -> void:
	if animated_sprite == null:
		return
	var animation_name := IDLE_ANIMATION
	if absf(horizontal_motion) > 0.25:
		animation_name = RUN_ANIMATION
	if animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation(animation_name):
		animated_sprite.play(animation_name)
	animated_sprite.flip_h = facing.x < 0
	var sprite_modulate := Color.WHITE
	if hurt_flash_remaining > 0.0:
		sprite_modulate = GameConstants.PLAYER_HURT_FLASH_COLOR
	elif damage_cooldown > 0.0 and _is_invulnerability_flash_visible():
		sprite_modulate = GameConstants.PLAYER_INVULN_FLASH_COLOR
	elif damage_cooldown > 0.0:
		sprite_modulate = sprite_modulate.lerp(GameConstants.PLAYER_HURT_COLOR, 0.25)
	elif is_dashing:
		sprite_modulate = sprite_modulate.lerp(_get_dash_visual_color(), 0.35)
	animated_sprite.modulate = sprite_modulate
	if is_dashing:
		if dash_direction.y > 0.0:
			animated_sprite.scale = animated_sprite_base_scale * Vector2(0.92, 1.08)
		else:
			animated_sprite.scale = animated_sprite_base_scale * Vector2(1.08, 0.92)
	else:
		animated_sprite.scale = animated_sprite_base_scale


func _is_invulnerability_flash_visible() -> bool:
	if damage_cooldown <= 0.0:
		return false
	var elapsed := GameConstants.PLAYER_DAMAGE_INVULNERABILITY - damage_cooldown
	return int(floor(elapsed / GameConstants.PLAYER_INVULN_FLASH_INTERVAL)) % 2 == 0


func _spawn_player_damage_popup(amount: int) -> void:
	if amount <= 0:
		return
	var popup_parent := get_parent()
	if popup_parent == null:
		return
	var popup := DAMAGE_POPUP_SCRIPT.new() as Node2D
	popup_parent.add_child(popup)
	popup.global_position = global_position + Vector2(0.0, -GameConstants.PLAYER_SIZE.y * 0.7)
	popup.setup(
		amount,
		GameConstants.PLAYER_DAMAGE_POPUP_TEXT_COLOR,
		GameConstants.PLAYER_DAMAGE_POPUP_SHADOW_COLOR,
		"-"
	)


func _cache_sprite_base_scale() -> void:
	if animated_sprite == null:
		return
	var editor_scale := animated_sprite.scale
	if not editor_scale.is_equal_approx(Vector2.ONE):
		animated_sprite_base_scale = editor_scale
		return
	var fit_scale := _get_sprite_fit_scale()
	animated_sprite_base_scale = fit_scale


func _get_sprite_fit_scale() -> Vector2:
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return Vector2.ONE
	if not animated_sprite.sprite_frames.has_animation(IDLE_ANIMATION):
		return Vector2.ONE
	var frame_texture := animated_sprite.sprite_frames.get_frame_texture(IDLE_ANIMATION, 0)
	if frame_texture == null:
		return Vector2.ONE
	var frame_size := frame_texture.get_size()
	if frame_size.x <= 0.0 or frame_size.y <= 0.0:
		return Vector2.ONE
	return Vector2(
		GameConstants.PLAYER_SIZE.x / frame_size.x,
		GameConstants.PLAYER_SIZE.y / frame_size.y
	)


func _apply_dash_movement(delta: float) -> void:
	if not is_dashing or dash_direction == Vector2.ZERO:
		return
	var dash_speed := GameConstants.PLAYER_DASH_DISTANCE / GameConstants.PLAYER_DASH_DURATION
	var target_distance := minf(dash_speed * delta, dash_distance_remaining)
	if target_distance <= 0.0:
		_finish_dash("dash_finished")
		return
	dash_motion_remainder += target_distance
	var step_count := int(floor(dash_motion_remainder))
	if step_count <= 0:
		return
	dash_motion_remainder -= step_count
	var requested_steps := step_count * _dash_axis_sign()
	var moved_steps := 0
	if dash_direction.x != 0.0:
		moved_steps = _move_axis(requested_steps, true)
	else:
		moved_steps = _move_axis(requested_steps, false)
	dash_distance_remaining = maxf(dash_distance_remaining - absf(float(moved_steps)), 0.0)
	if moved_steps != requested_steps:
		_finish_dash("dash_blocked")


func _finish_dash(debug_event: String) -> void:
	is_dashing = false
	dash_requested = false
	dash_direction = Vector2.ZERO
	pending_dash_direction = Vector2.ZERO
	dash_time_remaining = 0.0
	dash_distance_remaining = 0.0
	dash_motion_remainder = 0.0
	dash_debug_last_event = debug_event
	if debug_event == "dash_blocked":
		_set_dash_feedback(&"blocked")


func _dash_axis_sign() -> int:
	if dash_direction.x != 0.0:
		return _sign_to_int(dash_direction.x)
	return _sign_to_int(dash_direction.y)


func _set_dash_feedback(state: StringName) -> void:
	dash_feedback_state = state
	dash_feedback_time = DASH_FEEDBACK_DURATION
	queue_redraw()


func _apply_horizontal_input() -> void:
	var input_strength := Input.get_axis("move_left", "move_right")
	if input_strength != 0.0:
		facing = Vector2i(_sign_to_int(input_strength), 0)
	var move_speed := GameState.get_move_speed() if is_on_floor else GameState.get_air_move_speed()
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
		velocity.y = GameState.get_jump_speed()
		jump_started_this_frame = true
		return
	if is_wall_climbing:
		jump_buffer_remaining = 0.0
		var wall_direction := 1 if is_on_left_wall else -1
		velocity.x = wall_direction * GameConstants.PLAYER_WALL_JUMP_SPEED_X
		velocity.y = GameState.get_jump_speed()
		coyote_time_remaining = 0.0
		is_wall_climbing = false
		jump_started_this_frame = true
		return
	if extra_jumps_left > 0:
		jump_buffer_remaining = 0.0
		extra_jumps_left -= 1
		velocity.y = GameState.get_jump_speed()
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
	if is_wall_climbing and velocity.y > GameConstants.PLAYER_WALL_CLIMB_FALL_SPEED:
		velocity.y = GameConstants.PLAYER_WALL_CLIMB_FALL_SPEED


# 고정 벽 접촉 + 벽 방향 입력 + 배터리 보유 상태일 때만 벽타기를 유지한다.
# 배터리 회복량은 캐릭터 기본 스탯 상수(GameConstants)에서 가져온다.
func _update_wall_climb_state(delta: float) -> void:
	var climb_direction := _get_wall_climb_input_direction()
	var can_wall_climb := not is_dashing and current_battery > 0.0 and (
		(climb_direction < 0.0 and is_on_left_wall)
		or (climb_direction > 0.0 and is_on_right_wall)
	)
	is_wall_climbing = can_wall_climb
	if is_wall_climbing:
		current_battery = maxf(
			current_battery - GameConstants.PLAYER_WALL_CLIMB_DRAIN_PER_SEC * delta,
			0.0
		)
		if current_battery <= 0.0:
			is_wall_climbing = false
		return
	current_battery = minf(
		current_battery + GameState.get_battery_recovery_per_second() * delta,
		GameConstants.PLAYER_BATTERY_MAX
	)


# 좌우 입력이 실제로 접촉 중인 벽 방향인지 판정한다.
func _get_wall_climb_input_direction() -> float:
	var horizontal_input := Input.get_axis("move_left", "move_right")
	if absf(horizontal_input) < GameConstants.PLAYER_WALL_CLIMB_INPUT_DEADZONE:
		return 0.0
	return horizontal_input


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


func _move_axis(steps: int, horizontal: bool) -> int:
	if steps == 0:
		return 0
	var direction := 1 if steps > 0 else -1
	var moved_steps := 0
	for _index in range(abs(steps)):
		var next_position := position
		if horizontal:
			next_position.x += direction
		else:
			next_position.y += direction
		var body_local := _get_body_local_rect()
		var next_rect := Rect2(next_position + body_local.position, body_local.size)
		if _movement_collides(next_rect, horizontal, direction):
			var hit_sand := horizontal and sand_field.rect_collides(_get_lower_sand_rect(next_rect))
			if hit_sand and _try_step_up_on_sand(direction):
				moved_steps += direction
				continue
			if horizontal:
				velocity.x = 0.0
			else:
				velocity.y = 0.0
			break
		position = next_position
		moved_steps += direction
	return moved_steps


func _movement_collides(rect: Rect2, horizontal: bool, direction: int) -> bool:
	if world_grid.rect_collides_static(rect) or is_rect_blocked_by_falling_block(rect):
		return true
	var sand_rect := rect
	if horizontal:
		sand_rect = _get_lower_sand_rect(rect)
	elif direction < 0:
		sand_rect = _get_upward_sand_rect(rect)
	elif is_dashing and direction > 0:
		sand_rect = _get_dash_downward_sand_rect(rect)
	if sand_field.rect_collides(sand_rect):
		if not horizontal and direction < 0 and sand_field.try_clear_jump_space(rect, facing.x):
			return sand_field.rect_collides(sand_rect)
		if horizontal and _try_resolve_horizontal_sand_collision(rect, sand_rect, direction):
			return false
		return true
	return false


func _try_resolve_horizontal_sand_collision(rect: Rect2, sand_rect: Rect2, direction: int) -> bool:
	var push_attempts := HORIZONTAL_SAND_PUSH_ATTEMPTS
	if is_dashing:
		push_attempts = DASH_HORIZONTAL_SAND_PUSH_ATTEMPTS
	for _attempt in range(push_attempts):
		if not sand_field.try_push_for_body(rect, direction):
			return false
		if is_dashing:
			if not sand_field.rect_collides(sand_rect):
				return true
			continue
		if not sand_field.rect_collides(rect):
			return true
	return false


func _try_step_up_on_sand(direction: int) -> bool:
	if is_dashing or direction == 0:
		return false
	var body_local := _get_body_local_rect()
	for sample_index in range(1, SAND_SLOPE_STEP_SAMPLES + 1):
		var step_height := int(ceil(float(SAND_SLOPE_STEP_HEIGHT * sample_index) / float(SAND_SLOPE_STEP_SAMPLES)))
		var candidate_position := position + Vector2(direction, -step_height)
		var candidate_rect := Rect2(candidate_position + body_local.position, body_local.size)
		if world_grid.rect_collides_static(candidate_rect) or is_rect_blocked_by_falling_block(candidate_rect):
			continue
		var candidate_sand_rect := _get_lower_sand_rect(candidate_rect)
		if sand_field.rect_collides(candidate_sand_rect):
			if not sand_field.try_push_for_body(candidate_rect, direction):
				continue
			if sand_field.rect_collides(candidate_sand_rect):
				continue
		position = candidate_position
		motion_remainder.y = 0.0
		if velocity.y > 0.0:
			velocity.y = 0.0
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
	var target_center_y := block_rect.position.y - _get_body_local_rect().size.y * 0.5
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
	var attack_size := GameState.get_attack_shape_size_pixels()
	var support_distance := _get_body_support_distance(attack_direction)
	var center_offset := attack_direction * (support_distance + attack_size.x * 0.5)
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
	return _get_preview_polygon(shape_data)


func _get_mining_preview_polygon(direction: Vector2) -> PackedVector2Array:
	var shape_data := _get_mining_local_shape_data(direction)
	return _get_preview_polygon(shape_data)


func _get_mining_local_shape_data(direction: Vector2) -> Dictionary:
	var mining_direction := direction.normalized()
	if mining_direction == Vector2.ZERO:
		mining_direction = Vector2(facing)
	var mining_size := Vector2(
		GameConstants.PLAYER_MINING_RANGE_DISTANCE,
		GameConstants.PLAYER_MINING_RANGE_HEIGHT
	)
	mining_size *= GameState.get_mining_range_multiplier()
	var support_distance := _get_body_support_distance(mining_direction)
	var center_offset := mining_direction * (support_distance + mining_size.x * 0.5)
	return {
		"center": center_offset,
		"size": mining_size,
		"rotation": mining_direction.angle(),
		"direction": mining_direction,
		"origin": Vector2.ZERO,
	}


func _get_preview_polygon(shape_data: Dictionary) -> PackedVector2Array:
	var center: Vector2 = shape_data["center"]
	var size: Vector2 = shape_data["size"]
	var forward := Vector2.RIGHT.rotated(shape_data["rotation"])
	var half_forward := forward * (size.x * 0.5)
	var half_side := forward.orthogonal() * (size.y * 0.5)
	return PackedVector2Array([
		center - half_forward - half_side,
		center + half_forward - half_side,
		center + half_forward + half_side,
		center - half_forward + half_side,
	])


func _get_body_support_distance(direction: Vector2) -> float:
	var normalized_direction := direction.normalized()
	if normalized_direction == Vector2.ZERO:
		normalized_direction = Vector2(facing)
	var body_half_size := _get_body_local_rect().size * 0.5
	var tx := INF if absf(normalized_direction.x) < 0.0001 else body_half_size.x / absf(normalized_direction.x)
	var ty := INF if absf(normalized_direction.y) < 0.0001 else body_half_size.y / absf(normalized_direction.y)
	return minf(tx, ty)


func _get_body_local_rect() -> Rect2:
	var collision_size := GameConstants.PLAYER_SIZE - COLLISION_INSET * 2.0
	return Rect2(-collision_size * 0.5, collision_size)


func _get_lower_sand_rect(rect: Rect2) -> Rect2:
	var top := rect.position.y + rect.size.y * 0.42
	return Rect2(Vector2(rect.position.x, top), Vector2(rect.size.x, rect.end.y - top))


func _get_upward_sand_rect(rect: Rect2) -> Rect2:
	var side_margin := float(GameConstants.SAND_CELL_SIZE)
	var width: float = maxf(rect.size.x - side_margin * 2.0, side_margin * 2.0)
	return Rect2(
		Vector2(rect.position.x + (rect.size.x - width) * 0.5, rect.position.y),
		Vector2(width, GameConstants.PLAYER_UPWARD_SAND_CHECK_HEIGHT)
	)


func _get_dash_downward_sand_rect(rect: Rect2) -> Rect2:
	var width := maxf(rect.size.x - DASH_DOWNWARD_SAND_SIDE_MARGIN * 2.0, rect.size.x * 0.5)
	return Rect2(
		Vector2(rect.position.x + (rect.size.x - width) * 0.5, rect.position.y + rect.size.y * 0.18),
		Vector2(width, rect.size.y * 0.82)
	)


func _sign_to_int(value: float) -> int:
	if value > 0.0:
		return 1
	if value < 0.0:
		return -1
	return 0


func _vector_to_debug_text(value: Vector2) -> String:
	if value == Vector2.ZERO:
		return "(0,0)"
	return "(%d,%d)" % [_sign_to_int(value.x), _sign_to_int(value.y)]


func _on_attack_module_changed(_module_id: StringName) -> void:
	_sync_attack_module_visual()


func _sync_attack_module_visual() -> void:
	var module_definition = GameState.get_equipped_attack_module_definition()
	var scene_path := ""
	if module_definition != null:
		scene_path = module_definition.visual_scene_path
	if attack_module_visual != null and is_instance_valid(attack_module_visual) and scene_path == attack_module_visual_scene_path:
		return
	if attack_module_visual != null and is_instance_valid(attack_module_visual):
		attack_module_visual.queue_free()
	attack_module_visual = null
	attack_module_visual_scene_path = scene_path
	if scene_path.is_empty():
		return
	var visual_scene = load(scene_path)
	if visual_scene == null or not (visual_scene is PackedScene):
		push_warning("Attack module visual scene load failed: %s" % scene_path)
		return
	attack_module_visual = (visual_scene as PackedScene).instantiate() as Node2D
	if attack_module_visual == null:
		return
	add_child(attack_module_visual)
	attack_module_visual.z_index = 20
	attack_module_visual.position = Vector2.RIGHT * ATTACK_MODULE_ORBIT_RADIUS


func _update_attack_module_visual(delta: float) -> void:
	if attack_module_visual == null or not is_instance_valid(attack_module_visual):
		return
	attack_module_orbit_angle = wrapf(
		attack_module_orbit_angle + delta * ATTACK_MODULE_ORBIT_SPEED,
		0.0,
		TAU
	)
	attack_module_bob_time += delta * ATTACK_MODULE_BOB_SPEED
	var orbit_offset := Vector2.RIGHT.rotated(attack_module_orbit_angle) * ATTACK_MODULE_ORBIT_RADIUS
	orbit_offset.y += sin(attack_module_bob_time) * ATTACK_MODULE_BOB_AMPLITUDE
	var strike_ratio := 0.0
	if attack_module_strike_time_remaining > 0.0:
		strike_ratio = attack_module_strike_time_remaining / ATTACK_MODULE_STRIKE_DURATION
	var strike_offset := attack_module_strike_direction.normalized() * ATTACK_MODULE_STRIKE_DISTANCE * strike_ratio
	attack_module_visual.position = orbit_offset + strike_offset
	if attack_module_strike_time_remaining > 0.0:
		attack_module_visual.rotation = attack_module_strike_direction.angle()
	else:
		attack_module_visual.rotation = orbit_offset.angle()


func _play_attack_module_strike(direction: Vector2) -> void:
	if direction == Vector2.ZERO:
		direction = Vector2(facing)
	attack_module_strike_direction = direction.normalized()
	attack_module_strike_time_remaining = ATTACK_MODULE_STRIKE_DURATION


func _get_dash_visual_color() -> Color:
	if is_dashing:
		return Color("7fe7d6")
	if dash_feedback_time <= 0.0:
		return Color.TRANSPARENT
	match String(dash_feedback_state):
		"queued":
			return Color(0.92, 0.88, 0.42, 0.85)
		"armed":
			return Color(0.55, 0.92, 0.82, 0.9)
		"cooldown":
			return Color(0.95, 0.56, 0.36, 0.88)
		"blocked":
			return Color(0.86, 0.34, 0.34, 0.88)
	return Color(0.78, 0.84, 0.92, 0.75)


func _draw() -> void:
	var body := _get_body_local_rect()
	draw_rect(body, Color(1.0, 1.0, 1.0, 0.18), false, 1.0)
	var dash_visual_color := _get_dash_visual_color()
	if is_dashing and dash_direction != Vector2.ZERO:
		var trail_rect := body
		var trail_offset := dash_direction * -12.0
		if dash_direction.x != 0.0:
			trail_rect.size.x += 14.0
			if dash_direction.x < 0.0:
				trail_rect.position.x -= 14.0
		elif dash_direction.y > 0.0:
			trail_rect.size.y += 16.0
		var trail_color := dash_visual_color
		trail_color.a = DASH_TRAIL_ALPHA
		draw_rect(Rect2(trail_rect.position + trail_offset, trail_rect.size), trail_color)
		draw_rect(body.grow(2.0), Color(dash_visual_color, 0.95), false, DASH_OUTLINE_WIDTH)
	elif dash_feedback_time > 0.0 and dash_visual_color.a > 0.0:
		draw_rect(body.grow(1.5), dash_visual_color, false, 2.0)
	if attack_visual_time > 0.0:
		var preview_polygon := _get_attack_preview_polygon(attack_visual_direction)
		draw_colored_polygon(preview_polygon, GameConstants.ATTACK_PREVIEW_COLOR)
		for index in range(preview_polygon.size()):
			var next_index := (index + 1) % preview_polygon.size()
			draw_line(preview_polygon[index], preview_polygon[next_index], Color(0.95, 0.45, 0.33, 0.95), 2.0)
	if mining_visual_time > 0.0 and mining_visual_direction != Vector2.ZERO:
		var mining_polygon := _get_mining_preview_polygon(mining_visual_direction)
		draw_colored_polygon(mining_polygon, GameConstants.MINING_PREVIEW_COLOR)
		for index in range(mining_polygon.size()):
			var next_index := (index + 1) % mining_polygon.size()
			draw_line(mining_polygon[index], mining_polygon[next_index], Color(0.93, 0.84, 0.43, 0.95), 2.0)
