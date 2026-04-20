extends CanvasLayer
class_name DayShopUI

signal next_day_requested
signal closed


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.0, 0.0, 0.0, 0.72)
	add_child(bg)

	var center_container := CenterContainer.new()
	center_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center_container)

	var panel := PanelContainer.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("18202a")
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color("5e7f95")
	panel_style.corner_radius_top_left = 14
	panel_style.corner_radius_top_right = 14
	panel_style.corner_radius_bottom_right = 14
	panel_style.corner_radius_bottom_left = 14
	panel.add_theme_stylebox_override("panel", panel_style)
	center_container.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(420.0, 0.0)
	vbox.add_theme_constant_override("separation", 18)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "INTERMISSION SHOP"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color("f0d984"))
	vbox.add_child(title)

	var desc := Label.new()
	desc.text = "현재 빌드에서는 상점 단계 진입과 Next Day 전환만 연결되어 있습니다."
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.add_theme_font_size_override("font_size", 18)
	desc.add_theme_color_override("font_color", Color("d9e2eb"))
	vbox.add_child(desc)

	var hint := Label.new()
	hint.text = "구매 없이도 다음 Day로 이동할 수 있습니다."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 17)
	hint.add_theme_color_override("font_color", Color("91b0c9"))
	vbox.add_child(hint)

	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 12)
	vbox.add_child(button_row)

	var close_button := Button.new()
	close_button.text = "Close"
	close_button.custom_minimum_size = Vector2(140.0, 48.0)
	close_button.pressed.connect(_on_close_pressed)
	button_row.add_child(close_button)

	var next_day_button := Button.new()
	next_day_button.text = "Next Day"
	next_day_button.custom_minimum_size = Vector2(180.0, 48.0)
	next_day_button.pressed.connect(_on_next_day_pressed)
	button_row.add_child(next_day_button)


func _on_close_pressed() -> void:
	closed.emit()
	queue_free()


func _on_next_day_pressed() -> void:
	next_day_requested.emit()
