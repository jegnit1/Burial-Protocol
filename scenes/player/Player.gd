extends Node2D
class_name Player

signal mining_execute_requested(direction: Vector2)

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
const DASH_AFTERIMAGE_COUNT := 4
const DASH_AFTERIMAGE_LIFETIME := 0.16
const WEAPON_ANIMATION_TYPE_ONE_HAND_GUN: StringName = &"one_hand_gun"
const WEAPON_ANIMATION_TYPE_TWO_HAND_GUN: StringName = &"two_hand_gun"
const WEAPON_ANIMATION_TYPE_SWING: StringName = &"swing"
const WEAPON_ANIMATION_TYPE_STAB: StringName = &"stab"
const WEAPON_IDLE_BOB_AMPLITUDE := 2.0
const WEAPON_IDLE_BOB_SPEED := 2.4
const WEAPON_IDLE_MELEE_Y_OFFSET_U := -0.5
const WEAPON_IDLE_MELEE_X_INSET_U := 0.25
const WEAPON_IDLE_TWO_HAND_Y_OFFSET_U := -0.55
const WEAPON_IDLE_TWO_HAND_X_INSET_U := 0.10
const WEAPON_IDLE_MELEE_RIGHT_ROTATION := -PI * 0.25
const WEAPON_IDLE_MELEE_LEFT_ROTATION := -PI * 0.75
const WEAPON_IDLE_GUN_RIGHT_ROTATION := 0.0
const WEAPON_IDLE_GUN_LEFT_ROTATION := PI
const WEAPON_ATTACK_VISUAL_DURATION := 0.14
const WEAPON_ATTACK_GUN_RECOIL_DISTANCE := 14.0
const WEAPON_ATTACK_STAB_DISTANCE := 20.0
const WEAPON_ATTACK_SWING_ROTATION := PI * 0.35
const WEAPON_ATTACK_SCALE_PUNCH := 0.08
const DAMAGE_POPUP_SCRIPT := preload("res://scenes/ui/DamagePopup.gd")
const BASIC_DRONE_VISUAL_SCRIPT := preload("res://scenes/player/modules/BasicDroneVisual.gd")
const DRILL_TEXTURE := preload("res://assets/characters/drill.png")
const DRILL_FRAME_SIZE := Vector2(17.0, 15.0)
const DRILL_FRAME_COUNT := 4
const DRILL_FRAME_RATE := 28.0
const DRILL_TARGET_WORLD_SIZE_U := 0.75
const DRILL_EDGE_OVERLAP := 2.0
const DIG_CHARACTER_RECOIL_PIXELS := 4.0
# 스프라이트 시각 영역에 맞게 충돌 박스를 줄이는 inset (픽셀).
# x: 좌우 각각 줄임. y는 반드시 0 — y를 바꾸면 바닥/블록 감지가 깨짐.
const COLLISION_INSET := Vector2.ZERO

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
var attack_module_cooldowns: Dictionary = {}
var drone_protocol_cooldowns: Dictionary = {}
var attack_visual_direction := Vector2.RIGHT
var attack_visual_time := 0.0
var mining_cooldown := 0.0
var mining_visual_direction := Vector2.RIGHT
var mining_visual_time := 0.0
var mining_visual_active := false
var mining_input_held := false
var drill_animation_time := 0.0
var mining_enabled := true
var is_dashing := false
var dash_requested := false
var dash_direction := Vector2.ZERO
var pending_dash_direction := Vector2.ZERO
var dash_time_remaining := 0.0
var dash_cooldown_remaining := 0.0
var dash_distance_remaining := 0.0
var dash_input_grace_timer := 0.0
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
var animated_sprite_base_scale := Vector2.ONE
var weapon_visual_root: Node2D
var weapon_visual: Node2D
var weapon_visual_instance_id := ""
var weapon_animation_type: StringName = WEAPON_ANIMATION_TYPE_SWING
var weapon_bob_time := 0.0
var weapon_attack_direction := Vector2.RIGHT
var weapon_attack_visual_time := 0.0
var right_weapon_visual_root: Node2D
var right_weapon_visual: Node2D
var right_weapon_visual_instance_id := ""
var right_weapon_animation_type: StringName = WEAPON_ANIMATION_TYPE_SWING
var right_weapon_attack_visual_time := 0.0
var drone_visual: Node2D
var drone_bob_time := 0.0
var drill_visual: Sprite2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	position = GameConstants.PLAYER_SPAWN_POSITION
	current_battery = GameConstants.PLAYER_BATTERY_MAX
	_cache_sprite_base_scale()
	_ensure_drill_visual()
	_ensure_drone_visual()
	_update_sprite_visuals(0.0)
	_update_drill_visual()
	queue_redraw()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		jump_buffer_remaining = GameConstants.PLAYER_JUMP_BUFFER_TIME
	if event.is_action_pressed("attack_action"):
		attack_buffer_remaining = GameConstants.PLAYER_ATTACK_BUFFER_TIME
		pending_attack_direction = _resolve_attack_direction()
	if event.is_action_pressed("mine_action", false, false):
		mining_input_held = true
		_try_execute_mining_event()
	if event.is_action_released("mine_action"):
		mining_input_held = Input.is_action_pressed("mine_action")
	if event.is_action_pressed("dash_action", false, false):
		var dash_input_direction := _resolve_mouse_dash_direction()
		if dash_input_direction != Vector2.ZERO:
			_queue_dash_request(dash_input_direction)


func setup(target_world: WorldGrid, target_sand: SandField, target_blocks: Node2D) -> void:
	world_grid = target_world
	sand_field = target_sand
	blocks_root = target_blocks
	current_battery = GameConstants.PLAYER_BATTERY_MAX
	if not GameState.attack_module_changed.is_connected(_on_attack_module_changed):
		GameState.attack_module_changed.connect(_on_attack_module_changed)
	if not GameState.weapons_changed.is_connected(_on_weapons_changed):
		GameState.weapons_changed.connect(_on_weapons_changed)
	_sync_attack_module_visual()
	_ensure_drone_visual()
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
	_update_attack_module_cooldowns(delta)
	_update_drone_protocol_cooldowns(delta)
	
	if Input.is_action_pressed("attack_action"):
		attack_buffer_remaining = GameConstants.PLAYER_ATTACK_BUFFER_TIME
		pending_attack_direction = _resolve_attack_direction()
	mining_cooldown = max(mining_cooldown - delta, 0.0)
	dash_cooldown_remaining = max(dash_cooldown_remaining - delta, 0.0)
	dash_time_remaining = max(dash_time_remaining - delta, 0.0)
	dash_input_grace_timer = max(dash_input_grace_timer - delta, 0.0)
	dash_feedback_time = max(dash_feedback_time - delta, 0.0)
	damage_cooldown = max(damage_cooldown - delta, 0.0)
	hurt_flash_remaining = max(hurt_flash_remaining - delta, 0.0)
	attack_visual_time = max(attack_visual_time - delta, 0.0)
	mining_visual_time = max(mining_visual_time - delta, 0.0)
	if mining_visual_time <= 0.0:
		mining_visual_active = false
	if mining_visual_active:
		drill_animation_time += delta
	_process_pending_dash_request()
	_update_dash_state()
	jump_started_this_frame = false
	_refresh_contacts()
	_refresh_ground_jump_state()
	_update_battery_recovery(delta)
	_process_mining_input()
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
	_update_drill_visual()
	_update_weapon_visual(delta)
	_update_drone_visual(delta)
	var _has_active_visuals := (
		is_dashing
		or dash_feedback_time > 0.0
		or attack_visual_time > 0.0
		or mining_visual_active
		or mining_visual_time > 0.0
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
	return dash_cooldown_remaining <= 0.0 and not is_dashing and current_battery >= GameConstants.PLAYER_DASH_BATTERY_COST


func get_current_battery() -> float:
	return current_battery


func get_max_battery() -> float:
	return GameConstants.PLAYER_BATTERY_MAX


func get_dash_cooldown_remaining() -> float:
	return dash_cooldown_remaining


func get_dash_cooldown_duration() -> float:
	return GameConstants.PLAYER_DASH_COOLDOWN


func set_mining_enabled(enabled: bool) -> void:
	mining_enabled = enabled
	if not mining_enabled:
		stop_mining_visual()


func can_spend_mining_battery() -> bool:
	return current_battery >= GameConstants.PLAYER_MINING_BATTERY_COST


func try_spend_mining_battery() -> bool:
	if not can_spend_mining_battery():
		return false
	current_battery = maxf(current_battery - GameConstants.PLAYER_MINING_BATTERY_COST, 0.0)
	return true


func get_dash_debug_text() -> String:
	var pending_text := "yes" if pending_dash_direction != Vector2.ZERO or dash_requested else "no"
	return "Dash %s | Dir %s | CD %.2f | Pending %s | Battery %.0f | Event %s" % [
		"ON" if is_dashing else "off",
		_vector_to_debug_text(dash_direction),
		dash_cooldown_remaining,
		pending_text,
		current_battery,
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
	_play_weapon_attack_visual(direction)
	queue_redraw()
	return direction


func consume_attack_module_triggers() -> Array[Dictionary]:
	var triggers: Array[Dictionary] = []
	if is_dashing or attack_buffer_remaining <= 0.0:
		return triggers
	var direction := pending_attack_direction
	if direction == Vector2.ZERO:
		direction = _resolve_attack_direction()
	for module_entry in GameState.get_input_attack_module_entries():
		var instance_id := String(module_entry.get("instance_id", ""))
		if instance_id.is_empty():
			continue
		if float(attack_module_cooldowns.get(instance_id, 0.0)) > 0.0:
			continue
		attack_module_cooldowns[instance_id] = GameState.get_attack_module_cooldown_duration(module_entry)
		triggers.append({
			"module_entry": module_entry,
			"direction": direction,
		})
	if triggers.is_empty():
		return triggers
	attack_buffer_remaining = 0.0
	attack_visual_direction = direction
	attack_visual_time = GameConstants.PLAYER_ATTACK_VISUAL_DURATION
	_play_weapon_attack_visual(direction)
	queue_redraw()
	return triggers


func consume_mechanic_attack_module_triggers() -> Array[Dictionary]:
	return []


func consume_drone_protocol_triggers() -> Array[Dictionary]:
	var triggers: Array[Dictionary] = []
	if is_dashing:
		return triggers
	for protocol_entry in GameState.get_equipped_drone_protocol_entries():
		var instance_id := String(protocol_entry.get("instance_id", ""))
		if instance_id.is_empty():
			continue
		if float(drone_protocol_cooldowns.get(instance_id, 0.0)) > 0.0:
			continue
		drone_protocol_cooldowns[instance_id] = GameState.get_drone_protocol_cooldown_duration(protocol_entry)
		triggers.append({
			"protocol_entry": protocol_entry,
			"drone_position": get_drone_global_position(),
		})
	return triggers


func consume_mining_direction() -> Vector2:
	return Vector2.ZERO


func start_or_update_mining_visual(direction: Vector2) -> void:
	var resolved_direction := get_mining_direction(direction)
	if resolved_direction == Vector2.ZERO:
		stop_mining_visual()
		return
	mining_visual_direction = resolved_direction
	mining_visual_active = true
	_update_drill_visual()


func stop_mining_visual() -> void:
	mining_visual_active = false
	mining_visual_time = 0.0
	_update_drill_visual()


func get_attack_shape_data(direction: Vector2) -> Dictionary:
	var local_data := _get_attack_local_shape_data(direction)
	return {
		"center": position + local_data["center"],
		"size": local_data["size"],
		"rotation": local_data["rotation"],
	}


func get_attack_shape_data_for_module(direction: Vector2, module_entry: Dictionary) -> Dictionary:
	var local_data := _get_attack_local_shape_data_for_module(direction, module_entry)
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


func try_push_down_by_falling_block(pushing_block: FallingBlock) -> bool:
	var moved_rect := get_body_rect()
	moved_rect.position.y += 1.0
	if _rect_collides_excluding_block(moved_rect, pushing_block):
		return false
	position.y += 1.0
	if velocity.y < GameConstants.BLOCK_FALL_SPEED:
		velocity.y = GameConstants.BLOCK_FALL_SPEED
	if motion_remainder.y < 0.0:
		motion_remainder.y = 0.0
	coyote_time_remaining = 0.0
	is_on_floor = false
	is_on_sand = false
	return true


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


func _queue_dash_request(direction: Vector2) -> void:
	var normalized_direction := direction.normalized()
	if normalized_direction == Vector2.ZERO:
		dash_debug_last_event = "dash_direction_disabled"
		_set_dash_feedback(&"blocked")
		return
	if not can_dash():
		if current_battery < GameConstants.PLAYER_DASH_BATTERY_COST:
			dash_debug_last_event = "dash_battery_low"
			_set_dash_feedback(&"blocked")
			GameState.set_status_text("Not enough battery for dash.")
		else:
			dash_debug_last_event = "dash_on_cooldown"
			_set_dash_feedback(&"cooldown")
			GameState.set_status_text("Dash is on cooldown.")
		return
	pending_dash_direction = normalized_direction
	dash_requested = true
	dash_debug_last_event = "dash_requested"
	_set_dash_feedback(&"queued")


func _process_pending_dash_request() -> void:
	if not dash_requested or pending_dash_direction == Vector2.ZERO:
		return
	if not can_dash():
		return
	stop_mining_visual()
	current_battery = maxf(current_battery - GameConstants.PLAYER_DASH_BATTERY_COST, 0.0)
	is_dashing = true
	dash_direction = pending_dash_direction
	dash_time_remaining = GameConstants.PLAYER_DASH_DURATION
	dash_cooldown_remaining = GameConstants.PLAYER_DASH_COOLDOWN
	dash_distance_remaining = GameConstants.PLAYER_DASH_DISTANCE
	motion_remainder = Vector2.ZERO
	if dash_direction.x != 0.0:
		facing = Vector2i(_sign_to_int(dash_direction.x), 0)
	dash_requested = false
	pending_dash_direction = Vector2.ZERO
	dash_debug_last_event = "dash_armed"
	_set_dash_feedback(&"armed")
	_spawn_dash_afterimages()


func _update_attack_module_cooldowns(delta: float) -> void:
	for raw_key in attack_module_cooldowns.keys():
		var key := String(raw_key)
		attack_module_cooldowns[key] = maxf(float(attack_module_cooldowns[key]) - delta, 0.0)


func _update_drone_protocol_cooldowns(delta: float) -> void:
	for raw_key in drone_protocol_cooldowns.keys():
		var key := String(raw_key)
		drone_protocol_cooldowns[key] = maxf(float(drone_protocol_cooldowns[key]) - delta, 0.0)


func _update_dash_state() -> void:
	if not is_dashing:
		return
	if dash_time_remaining > 0.0 and dash_distance_remaining > 0.0:
		return
	_finish_dash("dash_finished")


func _resolve_mouse_dash_direction() -> Vector2:
	var to_mouse := get_global_mouse_position() - get_body_rect().get_center()
	if to_mouse.length() <= GameConstants.PLAYER_ATTACK_DIRECTION_DEADZONE:
		return Vector2.ZERO
	return to_mouse.normalized()


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
	_align_sprite_to_body_bottom()
	if mining_visual_time > 0.0 and mining_visual_direction != Vector2.ZERO:
		var feedback_ratio := mining_visual_time / GameConstants.DIG_EFFECT_FEEDBACK_DURATION
		var recoil_direction := mining_visual_direction.normalized()
		animated_sprite.position += -recoil_direction * DIG_CHARACTER_RECOIL_PIXELS * sin(clampf(feedback_ratio, 0.0, 1.0) * PI)


func _align_sprite_to_body_bottom() -> void:
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return
	var frame_texture := animated_sprite.sprite_frames.get_frame_texture(animated_sprite.animation, animated_sprite.frame)
	if frame_texture == null:
		return
	var visual_height := frame_texture.get_size().y * absf(animated_sprite.scale.y)
	var body := _get_body_local_rect()
	animated_sprite.position = Vector2(0.0, body.end.y - visual_height * 0.5)


func _ensure_drill_visual() -> void:
	if drill_visual != null:
		return
	drill_visual = Sprite2D.new()
	drill_visual.texture = DRILL_TEXTURE
	drill_visual.region_enabled = true
	drill_visual.region_rect = Rect2(Vector2.ZERO, DRILL_FRAME_SIZE)
	drill_visual.centered = true
	drill_visual.scale = _get_drill_visual_scale()
	drill_visual.z_index = 30
	drill_visual.visible = false
	drill_visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(drill_visual)


func _update_drill_visual() -> void:
	_ensure_drill_visual()
	if drill_visual == null:
		return
	if not mining_visual_active or mining_visual_direction == Vector2.ZERO:
		drill_visual.visible = false
		return
	var direction := mining_visual_direction.normalized()
	if direction == Vector2.ZERO:
		drill_visual.visible = false
		return
	var frame_index := int(floor(drill_animation_time * DRILL_FRAME_RATE)) % DRILL_FRAME_COUNT
	drill_visual.region_rect = Rect2(Vector2(float(frame_index) * DRILL_FRAME_SIZE.x, 0.0), DRILL_FRAME_SIZE)
	drill_visual.rotation = direction.angle()
	var drill_scale := _get_drill_visual_scale()
	drill_visual.scale = drill_scale
	var support_distance := _get_body_support_distance(direction)
	var drill_half_width := DRILL_FRAME_SIZE.x * drill_scale.x * 0.5
	var feedback_ratio := 0.0
	if GameConstants.DIG_EFFECT_FEEDBACK_DURATION > 0.0:
		feedback_ratio = mining_visual_time / GameConstants.DIG_EFFECT_FEEDBACK_DURATION
	var feedback_offset := -direction * 3.0 * sin(clampf(feedback_ratio, 0.0, 1.0) * PI)
	drill_visual.position = direction * (support_distance + drill_half_width - DRILL_EDGE_OVERLAP) + feedback_offset
	drill_visual.visible = true


func _get_drill_visual_scale() -> Vector2:
	var target_size := float(GameConstants.CELL_SIZE) * DRILL_TARGET_WORLD_SIZE_U
	var source_size := maxf(DRILL_FRAME_SIZE.x, DRILL_FRAME_SIZE.y)
	if source_size <= 0.0:
		return Vector2.ONE
	return Vector2.ONE * (target_size / source_size)


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


func _process_mining_input() -> void:
	mining_input_held = Input.is_action_pressed("mine_action")
	if not mining_input_held:
		return
	_try_execute_mining_event()


func _try_execute_mining_event() -> void:
	if not mining_enabled or is_dashing or mining_cooldown > 0.0:
		return
	var mining_direction := _resolve_mining_direction()
	if mining_direction == Vector2.ZERO:
		return
	var mining_shape_data := get_mining_shape_data(mining_direction)
	var has_wall_target := world_grid != null and world_grid.has_mineable_in_shape(mining_shape_data)
	if not has_wall_target:
		return
	if not try_spend_mining_battery():
		return
	mining_cooldown = _get_mining_interval()
	_play_mining_feedback(mining_direction)
	mining_execute_requested.emit(mining_direction)


func _resolve_mining_direction() -> Vector2:
	var to_mouse := get_global_mouse_position() - get_body_rect().get_center()
	if to_mouse.length() <= GameConstants.PLAYER_ATTACK_DIRECTION_DEADZONE:
		return Vector2.ZERO
	if to_mouse.x > 0.0:
		facing = Vector2i.RIGHT
	elif to_mouse.x < 0.0:
		facing = Vector2i.LEFT
	return to_mouse.normalized()


func _play_mining_feedback(direction: Vector2) -> void:
	var resolved_direction := direction.normalized()
	if resolved_direction == Vector2.ZERO:
		return
	mining_visual_direction = resolved_direction
	mining_visual_active = true
	mining_visual_time = GameConstants.DIG_EFFECT_FEEDBACK_DURATION
	if world_grid != null:
		world_grid.shake_mineable_in_shape(get_mining_shape_data(resolved_direction))
	_update_drill_visual()
	queue_redraw()


func _get_mining_interval() -> float:
	var mining_speed_bonus_percent := GameState.get_mining_speed_bonus_percent()
	return maxf(
		GameConstants.MIN_MINING_INTERVAL,
		GameConstants.BASE_MINING_INTERVAL / (1.0 + mining_speed_bonus_percent / 100.0)
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
		GameConstants.PLAYER_VISUAL_SIZE.x / frame_size.x,
		GameConstants.PLAYER_VISUAL_SIZE.y / frame_size.y
	)


func _apply_dash_movement(delta: float) -> void:
	if not is_dashing or dash_direction == Vector2.ZERO:
		return
	var dash_speed := GameConstants.PLAYER_DASH_DISTANCE / GameConstants.PLAYER_DASH_DURATION
	var target_distance := minf(dash_speed * delta, dash_distance_remaining)
	if target_distance <= 0.0:
		_finish_dash("dash_finished")
		return
	var requested_motion := dash_direction * target_distance
	var moved_motion := _move_dash_vector(requested_motion)
	dash_distance_remaining = maxf(dash_distance_remaining - moved_motion.length(), 0.0)
	if moved_motion.length() + 0.01 < requested_motion.length():
		_finish_dash("dash_blocked")


func _finish_dash(debug_event: String) -> void:
	is_dashing = false
	dash_requested = false
	dash_direction = Vector2.ZERO
	pending_dash_direction = Vector2.ZERO
	dash_time_remaining = 0.0
	dash_distance_remaining = 0.0
	dash_input_grace_timer = GameConstants.PLAYER_DASH_INPUT_GRACE_TIME
	dash_debug_last_event = debug_event
	if debug_event == "dash_blocked":
		_set_dash_feedback(&"blocked")


func _move_dash_vector(requested_motion: Vector2) -> Vector2:
	if requested_motion == Vector2.ZERO:
		return Vector2.ZERO
	var step_count := maxi(int(ceil(requested_motion.length())), 1)
	var step_motion := requested_motion / float(step_count)
	var moved_motion := Vector2.ZERO
	for _index in range(step_count):
		var moved_step := _try_move_dash_step(step_motion)
		moved_motion += moved_step
		if moved_step.length() + 0.001 < step_motion.length():
			break
	return moved_motion


func _try_move_dash_step(step_motion: Vector2) -> Vector2:
	var moved_step := Vector2.ZERO
	if not is_zero_approx(step_motion.x):
		var x_direction := _sign_to_int(step_motion.x)
		var x_position := position + Vector2(step_motion.x, 0.0)
		var x_rect := Rect2(x_position + _get_body_local_rect().position, _get_body_local_rect().size)
		if not _movement_collides(x_rect, true, x_direction):
			position.x = x_position.x
			moved_step.x = step_motion.x
	if not is_zero_approx(step_motion.y):
		var y_direction := _sign_to_int(step_motion.y)
		var y_position := position + Vector2(0.0, step_motion.y)
		if y_direction < 0 and _would_cross_playable_top(y_position):
			position.y = _get_min_player_center_y()
			velocity.y = 0.0
			motion_remainder.y = 0.0
			return moved_step
		var y_rect := Rect2(y_position + _get_body_local_rect().position, _get_body_local_rect().size)
		if not _movement_collides(y_rect, false, y_direction):
			position.y = y_position.y
			moved_step.y = step_motion.y
	return moved_step


func _set_dash_feedback(state: StringName) -> void:
	dash_feedback_state = state
	dash_feedback_time = DASH_FEEDBACK_DURATION
	queue_redraw()


func _spawn_dash_afterimages() -> void:
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return
	var frame_texture := animated_sprite.sprite_frames.get_frame_texture(animated_sprite.animation, animated_sprite.frame)
	if frame_texture == null:
		return
	var afterimage_parent := get_parent()
	if afterimage_parent == null:
		return
	var spacing := GameConstants.PLAYER_DASH_DISTANCE / float(DASH_AFTERIMAGE_COUNT + 1)
	for index in range(DASH_AFTERIMAGE_COUNT):
		var ghost := Sprite2D.new()
		ghost.texture = frame_texture
		ghost.centered = true
		ghost.flip_h = animated_sprite.flip_h
		ghost.scale = animated_sprite.global_scale
		ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ghost.z_index = animated_sprite.z_index - 1
		var offset := dash_direction * spacing * float(index + 1)
		ghost.global_position = animated_sprite.global_position + offset
		var alpha := lerpf(0.30, 0.08, float(index) / float(maxi(DASH_AFTERIMAGE_COUNT - 1, 1)))
		ghost.modulate = Color(0.55, 0.92, 0.82, alpha)
		afterimage_parent.add_child(ghost)
		var tween := create_tween()
		tween.tween_property(ghost, "modulate:a", 0.0, DASH_AFTERIMAGE_LIFETIME)
		tween.finished.connect(ghost.queue_free)


func _apply_horizontal_input() -> void:
	var input_strength := Input.get_axis("move_left", "move_right")
	if input_strength != 0.0:
		facing = Vector2i(_sign_to_int(input_strength), 0)
	var move_speed := GameState.get_move_speed() if is_on_floor else GameState.get_air_move_speed()
	if is_on_sand:
		move_speed *= GameConstants.PLAYER_SAND_SPEED_MULTIPLIER
	if dash_input_grace_timer > 0.0:
		move_speed *= GameConstants.PLAYER_DASH_RECOVERY_MOVE_MULT
	velocity.x = input_strength * move_speed


func _apply_jump_input() -> void:
	if jump_buffer_remaining <= 0.0:
		return
	if is_on_floor or coyote_time_remaining > 0.0:
		jump_buffer_remaining = 0.0
		coyote_time_remaining = 0.0
		velocity.y = GameState.get_jump_speed()
		jump_started_this_frame = true
		return
	if extra_jumps_left > 0:
		jump_buffer_remaining = 0.0
		extra_jumps_left -= 1
		velocity.y = GameState.get_jump_speed()
		jump_started_this_frame = true


func _refresh_ground_jump_state() -> void:
	if not is_on_floor:
		return
	extra_jumps_left = GameConstants.PLAYER_EXTRA_JUMPS
	coyote_time_remaining = GameConstants.PLAYER_COYOTE_TIME


func _apply_gravity(delta: float) -> void:
	if is_on_floor and velocity.y > 0.0:
		velocity.y = 0.0
		return
	velocity.y += GameConstants.PLAYER_GRAVITY * delta
	if dash_input_grace_timer <= 0.0 and Input.is_action_pressed("move_down") and not is_on_floor:
		velocity.y = min(
			velocity.y + GameConstants.PLAYER_FAST_FALL_ACCELERATION * delta,
			GameConstants.PLAYER_FAST_FALL_SPEED
		)


# 고정 벽 접촉 + 벽 방향 입력 + 배터리 보유 상태일 때만 벽타기를 유지한다.
# 배터리 회복량은 캐릭터 기본 스탯 상수(GameConstants)에서 가져온다.
func _update_battery_recovery(delta: float) -> void:
	if is_dashing:
		return
	current_battery = minf(
		current_battery + GameState.get_battery_recovery_per_second() * delta,
		GameConstants.PLAYER_BATTERY_MAX
	)


# 좌우 입력이 실제로 접촉 중인 벽 방향인지 판정한다.
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
			if direction < 0 and _would_cross_playable_top(next_position):
				position.y = _get_min_player_center_y()
				velocity.y = 0.0
				motion_remainder.y = 0.0
				break
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


func _would_cross_playable_top(next_position: Vector2) -> bool:
	var body_local := _get_body_local_rect()
	return next_position.y + body_local.position.y < GameConstants.WORLD_PLAYABLE_TOP_Y


func _get_min_player_center_y() -> float:
	return GameConstants.WORLD_PLAYABLE_TOP_Y - _get_body_local_rect().position.y


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


func _get_attack_local_shape_data_for_module(direction: Vector2, module_entry: Dictionary) -> Dictionary:
	var attack_direction := direction.normalized()
	if attack_direction == Vector2.ZERO:
		attack_direction = Vector2(facing)
	var attack_size := GameState.get_attack_module_shape_size_pixels(module_entry)
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
		GameConstants.PLAYER_MINING_RANGE_DISTANCE * GameState.get_mining_range_multiplier(),
		GameConstants.PLAYER_MINING_RANGE_HEIGHT
	)
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
	return "(%.2f,%.2f)" % [value.x, value.y]


func _on_attack_module_changed(_module_id: StringName) -> void:
	_sync_attack_module_visual()


func _on_weapons_changed(_left_weapon: Dictionary, _right_weapon: Dictionary) -> void:
	_sync_attack_module_visual()


func _ensure_weapon_visual_root() -> void:
	if weapon_visual_root != null and is_instance_valid(weapon_visual_root):
		return
	weapon_visual_root = get_node_or_null("WeaponVisualRoot") as Node2D
	if weapon_visual_root == null:
		weapon_visual_root = Node2D.new()
		weapon_visual_root.name = "WeaponVisualRoot"
		add_child(weapon_visual_root)
	weapon_visual_root.position = Vector2.ZERO


func _ensure_right_weapon_visual_root() -> void:
	if right_weapon_visual_root != null and is_instance_valid(right_weapon_visual_root):
		return
	right_weapon_visual_root = get_node_or_null("RightWeaponVisualRoot") as Node2D
	if right_weapon_visual_root == null:
		right_weapon_visual_root = Node2D.new()
		right_weapon_visual_root.name = "RightWeaponVisualRoot"
		add_child(right_weapon_visual_root)
	right_weapon_visual_root.position = Vector2.ZERO


func _sync_attack_module_visual() -> void:
	_ensure_weapon_visual_root()
	_ensure_right_weapon_visual_root()
	var left_entry := GameState.get_equipped_weapon_left()
	if left_entry.is_empty():
		_clear_weapon_visual()
	else:
		_sync_weapon_visual_for_entry(left_entry, false)
	var right_entry := GameState.get_equipped_weapon_right()
	if right_entry.is_empty():
		_clear_right_weapon_visual()
	else:
		_sync_weapon_visual_for_entry(right_entry, true)


func _sync_weapon_visual_for_entry(module_entry: Dictionary, is_right_slot: bool) -> void:
	var instance_id := String(module_entry.get("instance_id", ""))
	if instance_id.is_empty():
		if is_right_slot:
			_clear_right_weapon_visual()
		else:
			_clear_weapon_visual()
		return
	var module_definition = GameState.get_attack_module_definition_from_entry(module_entry)
	var scene_path := ""
	if module_definition != null:
		scene_path = module_definition.visual_scene_path
	if is_right_slot:
		if right_weapon_visual == null or not is_instance_valid(right_weapon_visual) or right_weapon_visual_instance_id != instance_id:
			_clear_right_weapon_visual()
			right_weapon_visual = _instantiate_attack_module_visual(scene_path)
			if right_weapon_visual == null:
				return
			right_weapon_visual_root.add_child(right_weapon_visual)
			right_weapon_visual_instance_id = instance_id
			right_weapon_visual.position = Vector2.ZERO
		_configure_attack_module_visual(right_weapon_visual, module_entry, module_definition)
		right_weapon_animation_type = _get_weapon_animation_type(module_definition)
		if right_weapon_visual.has_method("set_animation_type"):
			right_weapon_visual.call("set_animation_type", right_weapon_animation_type)
		_update_right_weapon_idle_pose()
		return
	if weapon_visual == null or not is_instance_valid(weapon_visual) or weapon_visual_instance_id != instance_id:
		_clear_weapon_visual()
		weapon_visual = _instantiate_attack_module_visual(scene_path)
		if weapon_visual == null:
			return
		weapon_visual_root.add_child(weapon_visual)
		weapon_visual_instance_id = instance_id
		weapon_visual.position = Vector2.ZERO
	_configure_attack_module_visual(weapon_visual, module_entry, module_definition)
	weapon_animation_type = _get_weapon_animation_type(module_definition)
	if weapon_visual.has_method("set_animation_type"):
		weapon_visual.call("set_animation_type", weapon_animation_type)
	_update_weapon_idle_pose()


func _update_weapon_visual(delta: float) -> void:
	weapon_bob_time += delta * WEAPON_IDLE_BOB_SPEED
	weapon_attack_visual_time = maxf(weapon_attack_visual_time - delta, 0.0)
	right_weapon_attack_visual_time = maxf(right_weapon_attack_visual_time - delta, 0.0)
	if weapon_visual != null and is_instance_valid(weapon_visual):
		_update_weapon_idle_pose()
	if right_weapon_visual != null and is_instance_valid(right_weapon_visual):
		_update_right_weapon_idle_pose()


func _instantiate_attack_module_visual(scene_path: String) -> Node2D:
	if scene_path.is_empty():
		return null
	var visual_scene = load(scene_path)
	if visual_scene == null or not (visual_scene is PackedScene):
		push_warning("Attack module visual scene load failed: %s" % scene_path)
		return null
	return (visual_scene as PackedScene).instantiate() as Node2D


func _configure_attack_module_visual(visual: Node2D, module_entry: Dictionary, module_definition) -> void:
	if visual == null or not is_instance_valid(visual):
		return
	if visual.has_method("configure"):
		visual.call("configure", module_entry, module_definition)


func _play_weapon_attack_visual(direction: Vector2) -> void:
	if direction == Vector2.ZERO:
		direction = Vector2(facing)
	weapon_attack_direction = direction.normalized()
	if weapon_attack_direction == Vector2.ZERO:
		weapon_attack_direction = Vector2.RIGHT
	weapon_attack_visual_time = WEAPON_ATTACK_VISUAL_DURATION
	right_weapon_attack_visual_time = WEAPON_ATTACK_VISUAL_DURATION
	_update_weapon_idle_pose()
	_update_right_weapon_idle_pose()


func _clear_weapon_visual() -> void:
	if weapon_visual != null and is_instance_valid(weapon_visual):
		weapon_visual.queue_free()
	weapon_visual = null
	weapon_visual_instance_id = ""
	weapon_attack_visual_time = 0.0


func _clear_right_weapon_visual() -> void:
	if right_weapon_visual != null and is_instance_valid(right_weapon_visual):
		right_weapon_visual.queue_free()
	right_weapon_visual = null
	right_weapon_visual_instance_id = ""
	right_weapon_attack_visual_time = 0.0


func _set_weapon_visual_depth(is_combat_depth: bool) -> void:
	if weapon_visual_root == null or not is_instance_valid(weapon_visual_root):
		return
	var body_z := animated_sprite.z_index if animated_sprite != null else 0
	weapon_visual_root.z_index = body_z + 1 if is_combat_depth else body_z - 1


func _update_weapon_idle_pose() -> void:
	if weapon_visual_root == null or not is_instance_valid(weapon_visual_root):
		return
	if weapon_visual == null or not is_instance_valid(weapon_visual):
		return
	var pose := _get_weapon_idle_pose(false)
	var bob_offset := Vector2(0.0, sin(weapon_bob_time) * WEAPON_IDLE_BOB_AMPLITUDE)
	var pose_position: Vector2 = pose.get("position", Vector2.ZERO)
	var pose_rotation := float(pose.get("rotation", 0.0))
	var attack_transform := _get_weapon_attack_visual_transform(pose_rotation)
	var attack_offset: Vector2 = attack_transform.get("offset", Vector2.ZERO)
	var attack_rotation := float(attack_transform.get("rotation", 0.0))
	var attack_scale := float(attack_transform.get("scale", 1.0))
	weapon_visual_root.position = pose_position + bob_offset + attack_offset
	weapon_visual.position = Vector2.ZERO
	weapon_visual.rotation = pose_rotation + attack_rotation
	weapon_visual.scale = Vector2.ONE * attack_scale
	weapon_visual.visible = true
	_set_weapon_visual_depth(false)


func _update_right_weapon_idle_pose() -> void:
	if right_weapon_visual_root == null or not is_instance_valid(right_weapon_visual_root):
		return
	if right_weapon_visual == null or not is_instance_valid(right_weapon_visual):
		return
	var pose := _get_weapon_idle_pose(true)
	var bob_offset := Vector2(0.0, sin(weapon_bob_time + PI) * WEAPON_IDLE_BOB_AMPLITUDE)
	var pose_position: Vector2 = pose.get("position", Vector2.ZERO)
	var pose_rotation := float(pose.get("rotation", 0.0))
	var attack_transform := _get_weapon_attack_visual_transform_for(
		pose_rotation,
		right_weapon_attack_visual_time,
		right_weapon_animation_type
	)
	right_weapon_visual_root.position = pose_position + bob_offset + Vector2(0.0, -4.0) + attack_transform.get("offset", Vector2.ZERO)
	right_weapon_visual.position = Vector2.ZERO
	right_weapon_visual.rotation = pose_rotation + float(attack_transform.get("rotation", 0.0))
	right_weapon_visual.scale = Vector2.ONE * float(attack_transform.get("scale", 1.0))
	right_weapon_visual.visible = true
	var body_z := animated_sprite.z_index if animated_sprite != null else 0
	right_weapon_visual_root.z_index = body_z + 1


func _get_weapon_idle_pose(is_right_slot: bool = false) -> Dictionary:
	var body := _get_body_local_rect()
	var unit := float(GameConstants.CELL_SIZE)
	var is_facing_left := facing.x < 0
	var x_inset_u := WEAPON_IDLE_MELEE_X_INSET_U
	var y_offset_u := WEAPON_IDLE_MELEE_Y_OFFSET_U
	var rotation := WEAPON_IDLE_GUN_RIGHT_ROTATION
	match weapon_animation_type:
		WEAPON_ANIMATION_TYPE_SWING, WEAPON_ANIMATION_TYPE_STAB:
			rotation = WEAPON_IDLE_MELEE_LEFT_ROTATION if is_facing_left else WEAPON_IDLE_MELEE_RIGHT_ROTATION
		WEAPON_ANIMATION_TYPE_TWO_HAND_GUN:
			x_inset_u = WEAPON_IDLE_TWO_HAND_X_INSET_U
			y_offset_u = WEAPON_IDLE_TWO_HAND_Y_OFFSET_U
			rotation = WEAPON_IDLE_GUN_LEFT_ROTATION if is_facing_left else WEAPON_IDLE_GUN_RIGHT_ROTATION
		_:
			rotation = WEAPON_IDLE_GUN_LEFT_ROTATION if is_facing_left else WEAPON_IDLE_GUN_RIGHT_ROTATION
	var visual_on_left := is_facing_left != is_right_slot
	var x := body.position.x + x_inset_u * unit if visual_on_left else body.end.x - x_inset_u * unit
	var y := body.end.y + y_offset_u * unit
	return {
		"position": Vector2(x, y),
		"rotation": rotation,
	}


func _get_weapon_attack_visual_transform(base_rotation: float) -> Dictionary:
	return _get_weapon_attack_visual_transform_for(base_rotation, weapon_attack_visual_time, weapon_animation_type)


func _get_weapon_attack_visual_transform_for(base_rotation: float, visual_time: float, animation_type: StringName) -> Dictionary:
	if visual_time <= 0.0 or WEAPON_ATTACK_VISUAL_DURATION <= 0.0:
		return {"offset": Vector2.ZERO, "rotation": 0.0, "scale": 1.0}
	var progress := 1.0 - visual_time / WEAPON_ATTACK_VISUAL_DURATION
	progress = clampf(progress, 0.0, 1.0)
	var impulse := sin(progress * PI)
	var direction := Vector2.RIGHT.rotated(base_rotation)
	var facing_sign := -1.0 if facing.x < 0 else 1.0
	match animation_type:
		WEAPON_ANIMATION_TYPE_ONE_HAND_GUN:
			return {
				"offset": -direction * WEAPON_ATTACK_GUN_RECOIL_DISTANCE * impulse,
				"rotation": -facing_sign * 0.10 * impulse,
				"scale": 1.0,
			}
		WEAPON_ANIMATION_TYPE_TWO_HAND_GUN:
			return {
				"offset": -direction * WEAPON_ATTACK_GUN_RECOIL_DISTANCE * 1.25 * impulse,
				"rotation": -facing_sign * 0.07 * impulse,
				"scale": 1.0,
			}
		WEAPON_ANIMATION_TYPE_STAB:
			return {
				"offset": direction * WEAPON_ATTACK_STAB_DISTANCE * impulse,
				"rotation": 0.0,
				"scale": 1.0 + WEAPON_ATTACK_SCALE_PUNCH * impulse,
			}
		_:
			return {
				"offset": Vector2.ZERO,
				"rotation": -facing_sign * WEAPON_ATTACK_SWING_ROTATION * impulse,
				"scale": 1.0,
			}


func _get_weapon_animation_type(module_definition) -> StringName:
	if module_definition == null:
		return WEAPON_ANIMATION_TYPE_SWING
	var module_type := String(module_definition.module_type)
	var attack_style := String(module_definition.attack_style)
	if module_type == "ranged":
		match attack_style:
			"revolver", "pistol", "single":
				return WEAPON_ANIMATION_TYPE_ONE_HAND_GUN
			_:
				return WEAPON_ANIMATION_TYPE_TWO_HAND_GUN
	match attack_style:
		"stab", "pierce":
			return WEAPON_ANIMATION_TYPE_STAB
		_:
			return WEAPON_ANIMATION_TYPE_SWING


func _ensure_drone_visual() -> void:
	if drone_visual != null and is_instance_valid(drone_visual):
		return
	drone_visual = get_node_or_null("BasicDroneVisual") as Node2D
	if drone_visual == null:
		drone_visual = BASIC_DRONE_VISUAL_SCRIPT.new() as Node2D
		drone_visual.name = "BasicDroneVisual"
		add_child(drone_visual)
	drone_visual.z_index = (animated_sprite.z_index if animated_sprite != null else 0) + 2
	_update_drone_visual(0.0)


func _update_drone_visual(delta: float) -> void:
	_ensure_drone_visual()
	drone_bob_time += delta * 2.2
	drone_visual.position = Vector2(30.0, -54.0 + sin(drone_bob_time) * 4.0)


func get_drone_global_position() -> Vector2:
	if drone_visual == null or not is_instance_valid(drone_visual):
		return global_position + Vector2(30.0, -54.0)
	return drone_visual.global_position


func get_equipment_trigger_debug_snapshot() -> Dictionary:
	return {
		"weapon_cooldowns": attack_module_cooldowns.duplicate(true),
		"protocol_cooldowns": drone_protocol_cooldowns.duplicate(true),
		"has_left_weapon_visual": weapon_visual != null and is_instance_valid(weapon_visual),
		"has_right_weapon_visual": right_weapon_visual != null and is_instance_valid(right_weapon_visual),
		"has_drone_visual": drone_visual != null and is_instance_valid(drone_visual),
		"drone_position": get_drone_global_position(),
	}


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
