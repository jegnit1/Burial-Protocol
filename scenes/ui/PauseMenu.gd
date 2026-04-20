extends CanvasLayer
class_name PauseMenu

signal closed()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	set_process_input(true)
	set_process_shortcut_input(true)
	_build_layout()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_menu", false, false):
		_resume_game()
		get_viewport().set_input_as_handled()


func _shortcut_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_menu", false, false):
		_resume_game()
		get_viewport().set_input_as_handled()


func _build_layout() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.74)
	add_child(dim)

	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 120)
	root.add_theme_constant_override("margin_top", 100)
	root.add_theme_constant_override("margin_right", 120)
	root.add_theme_constant_override("margin_bottom", 100)
	add_child(root)

	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 36)
	root.add_child(split)

	var left_panel := PanelContainer.new()
	left_panel.custom_minimum_size = Vector2(420, 0)
	left_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.09, 0.12, 0.16, 0.96)))
	split.add_child(left_panel)

	var left_margin := MarginContainer.new()
	left_margin.add_theme_constant_override("margin_left", 28)
	left_margin.add_theme_constant_override("margin_top", 28)
	left_margin.add_theme_constant_override("margin_right", 28)
	left_margin.add_theme_constant_override("margin_bottom", 28)
	left_panel.add_child(left_margin)

	var left_vbox := VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 18)
	left_margin.add_child(left_vbox)

	var title := Label.new()
	title.text = "일시정지"
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color("f1d98b"))
	left_vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "ESC로 돌아가기"
	subtitle.add_theme_font_size_override("font_size", 22)
	subtitle.add_theme_color_override("font_color", Color("9ca8b4"))
	left_vbox.add_child(subtitle)

	var button_gap := Control.new()
	button_gap.custom_minimum_size = Vector2(0, 10)
	left_vbox.add_child(button_gap)

	left_vbox.add_child(_create_menu_button("계속하기", _resume_game))
	left_vbox.add_child(_create_menu_button("메인 허브로", _go_to_main_hub))
	left_vbox.add_child(_create_menu_button("게임 종료", _quit_game))
	left_vbox.add_child(_create_disabled_button("설정", "준비 중"))

	var right_panel := PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.08, 0.10, 0.14, 0.96)))
	split.add_child(right_panel)

	var right_margin := MarginContainer.new()
	right_margin.add_theme_constant_override("margin_left", 28)
	right_margin.add_theme_constant_override("margin_top", 24)
	right_margin.add_theme_constant_override("margin_right", 28)
	right_margin.add_theme_constant_override("margin_bottom", 24)
	right_panel.add_child(right_margin)

	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 16)
	right_margin.add_child(right_vbox)

	var stats_title := Label.new()
	stats_title.text = "현재 스탯"
	stats_title.add_theme_font_size_override("font_size", 34)
	stats_title.add_theme_color_override("font_color", Color("dce7f0"))
	right_vbox.add_child(stats_title)

	var stats_hint := Label.new()
	stats_hint.text = "최종 적용값 기준"
	stats_hint.add_theme_font_size_override("font_size", 18)
	stats_hint.add_theme_color_override("font_color", Color("8d9aa8"))
	right_vbox.add_child(stats_hint)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_vbox.add_child(scroll)

	var stats_list := VBoxContainer.new()
	stats_list.add_theme_constant_override("separation", 10)
	scroll.add_child(stats_list)

	for stat_entry in GameState.get_stat_panel_entries():
		stats_list.add_child(_create_stat_row(
			String(stat_entry.get("label", "")),
			String(stat_entry.get("value", ""))
		))

	var luck_note := Label.new()
	luck_note.text = "행운은 아직 기능화되지 않았으며, 추후 아이템/보물상자 시스템에 연결될 예정입니다."
	luck_note.autowrap_mode = TextServer.AUTOWRAP_WORD
	luck_note.add_theme_font_size_override("font_size", 18)
	luck_note.add_theme_color_override("font_color", Color("93a0ad"))
	right_vbox.add_child(luck_note)


func _create_menu_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 58)
	button.add_theme_font_size_override("font_size", 24)
	button.pressed.connect(callback)
	return button


func _create_disabled_button(text: String, suffix: String) -> Button:
	var button := Button.new()
	button.text = "%s (%s)" % [text, suffix]
	button.custom_minimum_size = Vector2(0, 58)
	button.disabled = true
	button.add_theme_font_size_override("font_size", 24)
	return button


func _create_stat_row(label_text: String, value_text: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(220, 0)
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color("9fb2c6"))
	row.add_child(label)

	var value := Label.new()
	value.text = value_text
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.add_theme_font_size_override("font_size", 22)
	value.add_theme_color_override("font_color", Color("f3f6f8"))
	row.add_child(value)

	return row


func _make_panel_style(background_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color("33414f")
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_right = 14
	style.corner_radius_bottom_left = 14
	return style


func _resume_game() -> void:
	get_tree().paused = false
	closed.emit()
	queue_free()


func _go_to_main_hub() -> void:
	get_tree().paused = false
	closed.emit()
	get_tree().change_scene_to_file("res://scenes/ui/MainHub.tscn")


func _quit_game() -> void:
	get_tree().paused = false
	closed.emit()
	get_tree().quit()
