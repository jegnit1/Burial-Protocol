extends Node2D

const GRAVITY := 980.0

var _texture: Texture2D
var _source_rect := Rect2()
var _draw_size := Vector2.ONE
var _velocity := Vector2.ZERO
var _lifetime := 0.4
var _age := 0.0


func setup(
	texture: Texture2D,
	source_rect: Rect2,
	draw_size: Vector2,
	velocity: Vector2,
	lifetime: float
) -> void:
	_texture = texture
	_source_rect = source_rect
	_draw_size = draw_size
	_velocity = velocity
	_lifetime = maxf(lifetime, 0.01)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_age += delta
	if _age >= _lifetime:
		queue_free()
		return
	_velocity.y += GRAVITY * delta
	position += _velocity * delta
	modulate.a = 1.0 - clampf(_age / _lifetime, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	if _texture == null:
		return
	var draw_rect := Rect2(-_draw_size * 0.5, _draw_size)
	draw_texture_rect_region(
		_texture,
		draw_rect,
		_source_rect
	)
