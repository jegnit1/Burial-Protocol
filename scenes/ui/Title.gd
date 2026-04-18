extends "res://scenes/ui/MenuScreenScaffold.gd"


func _ready() -> void:
	add_fullscreen_background()

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	_build_background_placeholder(root)
	_build_title_header(root)
	_build_button_stack(root)


func _on_start() -> void:
	change_scene("res://scenes/ui/MainHub.tscn")


func _on_quit() -> void:
	get_tree().quit()


func _build_background_placeholder(parent: Control) -> void:
	var background_panel := make_panel(parent, Vector2.ZERO, PANEL_ALT_COLOR)
	background_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	background_panel.offset_left = 72
	background_panel.offset_top = 132
	background_panel.offset_right = -72
	background_panel.offset_bottom = -72

	var background_margin := make_margin(background_panel, 28)
	var background_box := VBoxContainer.new()
	background_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	background_margin.add_child(background_box)

	var top_spacer := Control.new()
	top_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	background_box.add_child(top_spacer)

	add_label(background_box, Locale.ltr("title_bg_placeholder"), 28)
	add_label(background_box, Locale.ltr("title_scene_desc"), 20)

	var bottom_spacer := Control.new()
	bottom_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	background_box.add_child(bottom_spacer)


func _build_title_header(parent: Control) -> void:
	var title_box := VBoxContainer.new()
	title_box.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title_box.offset_left = 120
	title_box.offset_top = 52
	title_box.offset_right = -120
	title_box.offset_bottom = 0
	title_box.add_theme_constant_override("separation", 8)
	title_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(title_box)

	add_label(title_box, Locale.ltr("title_game_title"), 68)
	add_label(title_box, Locale.ltr("title_subtitle"), 24)


func _build_button_stack(parent: Control) -> void:
	var button_panel := make_panel(parent, Vector2(440, 0))
	button_panel.anchor_left = 0.5
	button_panel.anchor_right = 0.5
	button_panel.anchor_top = 0.58
	button_panel.anchor_bottom = 0.58
	button_panel.offset_left = -220
	button_panel.offset_top = 0
	button_panel.offset_right = 220
	button_panel.offset_bottom = 360

	var button_margin := make_margin(button_panel, 24)
	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	button_margin.add_child(buttons)

	add_button(buttons, Locale.ltr("btn_start_game"), _on_start)
	add_button(buttons, Locale.ltr("btn_settings"), Callable(), true)
	add_button(buttons, Locale.ltr("btn_profile"), Callable(), true)
	add_button(buttons, Locale.ltr("btn_quit"), _on_quit)
	add_button(buttons, Locale.ltr("btn_ranking"), Callable(), true)
