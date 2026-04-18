extends Area2D
class_name FallingBlock

const DAMAGE_POPUP_SCRIPT := preload("res://scenes/ui/DamagePopup.gd")

signal destroyed(block: FallingBlock)
signal decomposed(block: FallingBlock, reason: StringName)

var block_data: BlockData
var world_grid: WorldGrid
var sand_field: SandField
var player: Player
var current_health := 1
var fall_remainder := 0.0
var active := false
var frame_motion := Vector2.ZERO
# HP 오버레이 상태. 피격 시 타이머를 설정해 잠깐 표시한다.
var _hp_overlay_timer := 0.0
var _max_health_cache := 0  # setup() 시점에 캐시. 추후 체력바 비율 계산에도 사용 가능.

@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	_ensure_collision_shape()


func setup(data: BlockData, spawn_position: Vector2, target_world: WorldGrid, target_sand: SandField, target_player: Player) -> void:
	block_data = data
	position = spawn_position
	world_grid = target_world
	sand_field = target_sand
	player = target_player
	current_health = block_data.get_effective_health()
	_max_health_cache = current_health
	_hp_overlay_timer = 0.0
	active = true
	frame_motion = Vector2.ZERO
	collision_layer = 1
	collision_mask = 0
	_ensure_collision_shape()
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not active or block_data == null:
		return
	if _hp_overlay_timer > 0.0:
		_hp_overlay_timer -= delta
		if _hp_overlay_timer <= 0.0:
			_hp_overlay_timer = 0.0
			queue_redraw()  # 오버레이 숨김을 위한 1회 갱신
	frame_motion = Vector2.ZERO
	fall_remainder += GameConstants.BLOCK_FALL_SPEED * delta
	var step_pixels := int(floor(fall_remainder))
	fall_remainder -= step_pixels
	for _index in range(step_pixels):
		var next_rect := get_block_rect()
		next_rect.position.y += 1.0
		if player != null and player.is_crushable_under(next_rect):
			if player.receive_crush_hit():
				_emit_decompose("player_crush")
				return
		if player != null and next_rect.intersects(player.get_body_rect()):
			position.y = player.get_head_y() - get_block_rect().size.y * 0.5
			fall_remainder = 0.0
			queue_redraw()
			return
		if world_grid.rect_collides_static(next_rect) or sand_field.rect_collides(next_rect):
			_emit_decompose("settled")
			return
		position.y += 1.0
		frame_motion.y += 1.0


func get_block_rect() -> Rect2:
	var size_pixels := block_data.get_size_pixels()
	return Rect2(position - size_pixels * 0.5, size_pixels)


func overlaps_rect(target_rect: Rect2) -> bool:
	return get_block_rect().intersects(target_rect)


func is_blocking_rect(target_rect: Rect2) -> bool:
	return active and get_block_rect().intersects(target_rect)


func get_frame_motion() -> Vector2:
	return frame_motion


func get_block_base_id() -> StringName:
	if block_data == null:
		return StringName()
	return block_data.block_base


func get_block_base_debug_text() -> String:
	if block_data == null:
		return ""
	return block_data.get_block_base_debug_text()


func apply_damage(amount: int) -> void:
	if not active:
		return
	_spawn_damage_popup(amount)
	current_health -= amount
	if current_health <= 0:
		active = false
		destroyed.emit(self)
		queue_free()
	else:
		_hp_overlay_timer = GameConstants.BLOCK_HP_OVERLAY_DURATION
		queue_redraw()


func _emit_decompose(reason: StringName) -> void:
	if not active:
		return
	active = false
	decomposed.emit(self, reason)
	queue_free()


func _draw() -> void:
	if block_data == null:
		return
	var rect := Rect2(-block_data.get_size_pixels() * 0.5, block_data.get_size_pixels())
	draw_rect(rect, block_data.block_base_color)
	draw_rect(rect, Color(0.05, 0.05, 0.05, 1.0), false, 2.0)
	if _hp_overlay_timer > 0.0:
		_draw_hp_overlay()


func _draw_hp_overlay() -> void:
	if _max_health_cache <= 0:
		return
	var ratio := clampf(float(current_health) / float(_max_health_cache), 0.0, 1.0)
	var bar_w := block_data.get_size_pixels().x
	var bar_h := GameConstants.BLOCK_HP_BAR_HEIGHT
	var top_y := -block_data.get_size_pixels().y * 0.5
	var bar_x := -bar_w * 0.5
	var bar_y := top_y - GameConstants.BLOCK_HP_OVERLAY_TOP_MARGIN - bar_h
	var bg_rect := Rect2(bar_x, bar_y, bar_w, bar_h)
	# 배경
	draw_rect(bg_rect, GameConstants.BLOCK_HP_BAR_BG_COLOR)
	# 채움: 비율에 따라 저체력(빨강) → 고체력(초록) 보간
	if ratio > 0.0:
		var fill_color := GameConstants.BLOCK_HP_BAR_LOW_COLOR.lerp(
			GameConstants.BLOCK_HP_BAR_HIGH_COLOR, ratio)
		draw_rect(Rect2(bar_x, bar_y, bar_w * ratio, bar_h), fill_color)
	# 테두리
	draw_rect(bg_rect, GameConstants.BLOCK_HP_BAR_BORDER_COLOR, false, 1.0)


func _ensure_collision_shape() -> void:
	if collision_shape == null or block_data == null:
		return
	if collision_shape.shape == null:
		collision_shape.shape = RectangleShape2D.new()
	(collision_shape.shape as RectangleShape2D).size = block_data.get_size_pixels()


func _spawn_damage_popup(amount: int) -> void:
	if amount <= 0 or block_data == null:
		return
	var popup_parent := get_parent()
	if popup_parent == null:
		return
	var popup := DAMAGE_POPUP_SCRIPT.new() as Node2D
	popup_parent.add_child(popup)
	popup.global_position = global_position + Vector2(0.0, -block_data.get_size_pixels().y * 0.5)
	popup.call("setup", amount)
