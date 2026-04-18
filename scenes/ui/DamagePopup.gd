extends Node2D

var amount := 0
var elapsed := 0.0
var horizontal_speed := 0.0


func setup(value: int) -> void:
	amount = value
	horizontal_speed = randf_range(
		-GameConstants.DAMAGE_POPUP_HORIZONTAL_JITTER,
		GameConstants.DAMAGE_POPUP_HORIZONTAL_JITTER
	)
	queue_redraw()


func _process(delta: float) -> void:
	elapsed += delta
	position.x += horizontal_speed * delta
	position.y -= GameConstants.DAMAGE_POPUP_RISE_SPEED * delta
	modulate.a = 1.0 - clampf(elapsed / GameConstants.DAMAGE_POPUP_LIFETIME, 0.0, 1.0)
	if elapsed >= GameConstants.DAMAGE_POPUP_LIFETIME:
		queue_free()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return
	var text := str(amount)
	var font_size := GameConstants.DAMAGE_POPUP_FONT_SIZE
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var baseline := font.get_ascent(font_size) * 0.5
	var text_position := Vector2(-text_size.x * 0.5, baseline)
	draw_string(
		font,
		text_position + Vector2(2.0, 2.0),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		GameConstants.DAMAGE_POPUP_SHADOW_COLOR
	)
	draw_string(
		font,
		text_position,
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		GameConstants.DAMAGE_POPUP_TEXT_COLOR
	)
