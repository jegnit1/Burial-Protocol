extends Node2D
class_name BasicDroneVisual

var pulse_time := 0.0


func _process(delta: float) -> void:
	pulse_time += delta
	queue_redraw()


func _draw() -> void:
	var pulse := 1.0 + sin(pulse_time * 4.0) * 0.08
	draw_line(Vector2(-18.0, 0.0), Vector2(-9.0, 0.0), Color("72d8e8"), 3.0)
	draw_line(Vector2(9.0, 0.0), Vector2(18.0, 0.0), Color("72d8e8"), 3.0)
	draw_circle(Vector2.ZERO, 10.0 * pulse, Color("3e8194"))
	draw_circle(Vector2.ZERO, 5.0 * pulse, Color("b6f4ff"))
	draw_circle(Vector2.ZERO, 2.0 * pulse, Color("ffffff"))
