extends Node2D

# 블록 파괴 시 파괴 위치 근처에 떠오르는 골드 획득 팝업.
# 현재는 텍스트 기반 아이콘을 사용하며, 추후 스프라이트로 교체 가능한 구조를 유지한다.

var _amount := 0
var _elapsed := 0.0


func setup(amount: int) -> void:
	_amount = amount
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed += delta
	position.y -= GameConstants.GOLD_POPUP_RISE_SPEED * delta
	modulate.a = 1.0 - clampf(_elapsed / GameConstants.GOLD_POPUP_LIFETIME, 0.0, 1.0)
	if _elapsed >= GameConstants.GOLD_POPUP_LIFETIME:
		queue_free()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return
	var font_size := GameConstants.GOLD_POPUP_FONT_SIZE
	var baseline := font.get_ascent(font_size) * 0.5

	# 아이콘 영역: 현재 텍스트 임시 표기.
	# 추후 교체: _draw_icon() 대신 TextureRect 자식 노드를 setup()에서 생성하는 방식으로 전환.
	_draw_icon(font, font_size, baseline)
	_draw_amount(font, font_size, baseline)


func _draw_icon(font: Font, font_size: int, baseline: float) -> void:
	# 추후 스프라이트 아이콘으로 교체할 때 이 메서드만 교체하면 된다.
	var icon_text := GameConstants.GOLD_POPUP_ICON_TEXT
	var icon_width := font.get_string_size(icon_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var amount_text := "+%d" % _amount
	var amount_width := font.get_string_size(amount_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var total_width := icon_width + 8.0 + amount_width
	var x := -total_width * 0.5
	draw_string(font, Vector2(x + 1.0, baseline + 1.0), icon_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, GameConstants.GOLD_POPUP_SHADOW_COLOR)
	draw_string(font, Vector2(x, baseline), icon_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, GameConstants.GOLD_POPUP_TEXT_COLOR)


func _draw_amount(font: Font, font_size: int, baseline: float) -> void:
	var icon_text := GameConstants.GOLD_POPUP_ICON_TEXT
	var icon_width := font.get_string_size(icon_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var amount_text := "+%d" % _amount
	var amount_width := font.get_string_size(amount_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var total_width := icon_width + 8.0 + amount_width
	var x := -total_width * 0.5 + icon_width + 8.0
	draw_string(font, Vector2(x + 1.0, baseline + 1.0), amount_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, GameConstants.GOLD_POPUP_SHADOW_COLOR)
	draw_string(font, Vector2(x, baseline), amount_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, GameConstants.GOLD_POPUP_TEXT_COLOR)
