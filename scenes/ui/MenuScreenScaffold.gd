extends Control

const BACKGROUND_COLOR := Color("11161d")
const PANEL_COLOR := Color("202733")
const PANEL_ALT_COLOR := Color("18212b")
const PANEL_BORDER_COLOR := Color("637186")
const BUTTON_MIN_SIZE := Vector2(360, 64)


func build_screen(title: String, subtitle: String = "") -> VBoxContainer:
	add_fullscreen_background()

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 96)
	margin.add_theme_constant_override("margin_top", 48)
	margin.add_theme_constant_override("margin_right", 96)
	margin.add_theme_constant_override("margin_bottom", 48)
	center.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	margin.add_child(content)

	add_label(content, title, 64)
	if not subtitle.is_empty():
		add_label(content, subtitle, 24)

	return content


func add_fullscreen_background() -> ColorRect:
	var background := ColorRect.new()
	background.color = BACKGROUND_COLOR
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	return background


func make_panel(parent: Control, min_size: Vector2 = Vector2.ZERO, bg_color: Color = PANEL_COLOR) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = min_size
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = PANEL_BORDER_COLOR
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return panel


func make_margin(parent: Control, padding: int = 24) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", padding)
	margin.add_theme_constant_override("margin_top", padding)
	margin.add_theme_constant_override("margin_right", padding)
	margin.add_theme_constant_override("margin_bottom", padding)
	parent.add_child(margin)
	return margin


func add_label(parent: Control, text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(720, 0)
	parent.add_child(label)
	return label


func add_button(parent: Control, text: String, callback: Callable, disabled: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.disabled = disabled
	button.add_theme_font_size_override("font_size", 32)
	button.custom_minimum_size = BUTTON_MIN_SIZE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(button)
	if not disabled and callback.is_valid():
		button.pressed.connect(callback)
	return button


func add_spacer(parent: Control, height: int) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	parent.add_child(spacer)


func change_scene(scene_path: String) -> void:
	var error := get_tree().change_scene_to_file(scene_path)
	if error != OK:
		push_error("Failed to change scene to %s (error %d)." % [scene_path, error])
