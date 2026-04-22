extends Node2D
class_name AttackModuleVisual

@export var module_id: StringName
@export var shape_style: StringName = &"sword"
@export var fill_color := Color.WHITE
@export var accent_color := Color(0.1, 0.12, 0.14, 1.0)
@export var visual_scale := 1.0


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	match shape_style:
		&"dagger":
			_draw_dagger()
		&"lance":
			_draw_lance()
		&"axe":
			_draw_axe()
		&"greatsword":
			_draw_greatsword()
		_:
			_draw_sword()


func _draw_sword() -> void:
	var hilt: Rect2 = _scaled_rect(Rect2(Vector2(-10.0, -3.0), Vector2(10.0, 6.0)))
	var blade: Rect2 = _scaled_rect(Rect2(Vector2(-1.0, -3.0), Vector2(26.0, 6.0)))
	draw_rect(hilt, accent_color)
	draw_rect(blade, fill_color)
	draw_line(_scaled_vector(Vector2(6.0, -6.0)), _scaled_vector(Vector2(6.0, 6.0)), accent_color, 2.0 * visual_scale)


func _draw_dagger() -> void:
	var hilt: Rect2 = _scaled_rect(Rect2(Vector2(-8.0, -2.5), Vector2(8.0, 5.0)))
	var blade_points: PackedVector2Array = _scaled_points([
		Vector2(-1.0, -4.0),
		Vector2(14.0, -2.0),
		Vector2(18.0, 0.0),
		Vector2(14.0, 2.0),
		Vector2(-1.0, 4.0),
	])
	draw_rect(hilt, accent_color)
	draw_colored_polygon(blade_points, fill_color)


func _draw_lance() -> void:
	var shaft: Rect2 = _scaled_rect(Rect2(Vector2(-14.0, -2.0), Vector2(28.0, 4.0)))
	var tip_points: PackedVector2Array = _scaled_points([
		Vector2(14.0, -5.0),
		Vector2(28.0, 0.0),
		Vector2(14.0, 5.0),
	])
	draw_rect(shaft, accent_color)
	draw_colored_polygon(tip_points, fill_color)


func _draw_axe() -> void:
	var handle: Rect2 = _scaled_rect(Rect2(Vector2(-12.0, -2.0), Vector2(18.0, 4.0)))
	var head_points: PackedVector2Array = _scaled_points([
		Vector2(4.0, -11.0),
		Vector2(16.0, -7.0),
		Vector2(18.0, 0.0),
		Vector2(16.0, 7.0),
		Vector2(4.0, 11.0),
		Vector2(8.0, 0.0),
	])
	draw_rect(handle, accent_color)
	draw_colored_polygon(head_points, fill_color)


func _draw_greatsword() -> void:
	var hilt: Rect2 = _scaled_rect(Rect2(Vector2(-12.0, -3.0), Vector2(12.0, 6.0)))
	var blade_points: PackedVector2Array = _scaled_points([
		Vector2(-1.0, -5.0),
		Vector2(20.0, -5.0),
		Vector2(27.0, 0.0),
		Vector2(20.0, 5.0),
		Vector2(-1.0, 5.0),
	])
	draw_rect(hilt, accent_color)
	draw_colored_polygon(blade_points, fill_color)
	draw_line(_scaled_vector(Vector2(5.0, -7.0)), _scaled_vector(Vector2(5.0, 7.0)), accent_color, 2.0 * visual_scale)


func _scaled_rect(value: Rect2) -> Rect2:
	return Rect2(
		_scaled_vector(value.position),
		_scaled_vector(value.size)
	)


func _scaled_vector(value: Vector2) -> Vector2:
	return value * visual_scale


func _scaled_points(points: Array[Vector2]) -> PackedVector2Array:
	var scaled_points := PackedVector2Array()
	for point in points:
		scaled_points.append(_scaled_vector(point))
	return scaled_points
