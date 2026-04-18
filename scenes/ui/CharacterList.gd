extends "res://scenes/ui/MenuScreenScaffold.gd"

var current_selection_label: Label


func _ready() -> void:
	add_fullscreen_background()

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var main_panel := make_panel(root, Vector2.ZERO)
	main_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_panel.offset_left = 56
	main_panel.offset_top = 48
	main_panel.offset_right = -56
	main_panel.offset_bottom = -48

	var margin := make_margin(main_panel, 28)
	var layout := VBoxContainer.new()
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 18)
	margin.add_child(layout)

	var title := add_label(layout, Locale.ltr("charlist_title"), 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.custom_minimum_size = Vector2.ZERO

	var subtitle := add_label(layout, Locale.ltr("charlist_subtitle"), 20)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	subtitle.custom_minimum_size = Vector2.ZERO

	current_selection_label = add_label(
		layout,
		Locale.ltr("charlist_current_selection") % GameState.selected_character_name,
		24
	)
	current_selection_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	current_selection_label.custom_minimum_size = Vector2.ZERO

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	layout.add_child(grid)

	for slot_data in GameState.get_character_slots():
		_add_character_slot(grid, slot_data)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	layout.add_child(footer)

	var helper := add_label(footer, Locale.ltr("charlist_footer_hint"), 18)
	helper.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	helper.custom_minimum_size = Vector2.ZERO
	helper.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	add_button(footer, Locale.ltr("btn_back"), _on_back)


func _on_back() -> void:
	change_scene("res://scenes/ui/MainHub.tscn")


func _add_character_slot(parent: Control, slot_data: Dictionary) -> void:
	var is_unlocked := bool(slot_data["unlocked"])
	var is_selected := bool(slot_data["selected"])
	var panel_color := PANEL_COLOR if is_unlocked else PANEL_ALT_COLOR
	var slot_panel := make_panel(parent, Vector2(0, 210), panel_color)
	slot_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not is_unlocked:
		slot_panel.tooltip_text = String(slot_data["unlock_text"])
		slot_panel.mouse_default_cursor_shape = Control.CURSOR_HELP

	var margin := make_margin(slot_panel, 18)
	var layout := VBoxContainer.new()
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)

	var name_label := add_label(layout, String(slot_data["display_name"]), 28)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.custom_minimum_size = Vector2.ZERO

	var state_text := Locale.ltr("char_status_available") if is_unlocked else Locale.ltr("char_status_locked")
	var state_label := add_label(layout, state_text, 20)
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	state_label.custom_minimum_size = Vector2.ZERO

	var record_label := add_label(layout, Locale.ltr("char_best_record") % String(slot_data["best_record"]), 20)
	record_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	record_label.custom_minimum_size = Vector2.ZERO

	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(filler)

	if is_unlocked:
		var button_text := Locale.ltr("btn_select") if not is_selected else Locale.ltr("btn_selected")
		add_button(layout, button_text, func() -> void: _on_select_character(String(slot_data["id"])))
		return

	var hint_label := add_label(layout, Locale.ltr("char_hover_unlock_hint"), 18)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hint_label.custom_minimum_size = Vector2.ZERO


func _on_select_character(character_id: String) -> void:
	if not GameState.select_character(character_id):
		return
	current_selection_label.text = Locale.ltr("charlist_current_selection") % GameState.selected_character_name
	change_scene("res://scenes/ui/MainHub.tscn")
