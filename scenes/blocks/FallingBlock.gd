extends Area2D
class_name FallingBlock

signal destroyed(block: FallingBlock)
signal decomposed(block: FallingBlock, reason: StringName)

var block_data: BlockData
var world_grid: WorldGrid
var sand_field: SandField
var player: Player
var current_health := 1
var fall_remainder := 0.0
var active := false

@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	_ensure_collision_shape()


func setup(data: BlockData, spawn_position: Vector2, target_world: WorldGrid, target_sand: SandField, target_player: Player) -> void:
	block_data = data
	position = spawn_position
	world_grid = target_world
	sand_field = target_sand
	player = target_player
	current_health = block_data.health
	active = true
	collision_layer = 1
	collision_mask = 0
	_ensure_collision_shape()
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not active or block_data == null:
		return
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


func get_block_rect() -> Rect2:
	var size_pixels := block_data.get_size_pixels()
	return Rect2(position - size_pixels * 0.5, size_pixels)


func overlaps_rect(target_rect: Rect2) -> bool:
	return get_block_rect().intersects(target_rect)


func is_blocking_rect(target_rect: Rect2) -> bool:
	return active and get_block_rect().intersects(target_rect)


func apply_damage(amount: int) -> void:
	if not active:
		return
	current_health -= amount
	if current_health <= 0:
		active = false
		destroyed.emit(self)
		queue_free()
	else:
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
	draw_rect(rect, block_data.block_color)
	draw_rect(rect, Color(0.05, 0.05, 0.05, 1.0), false, 2.0)


func _ensure_collision_shape() -> void:
	if collision_shape == null or block_data == null:
		return
	if collision_shape.shape == null:
		collision_shape.shape = RectangleShape2D.new()
	(collision_shape.shape as RectangleShape2D).size = block_data.get_size_pixels()
