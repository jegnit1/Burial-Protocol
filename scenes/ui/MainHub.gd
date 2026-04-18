extends "res://scenes/ui/MenuScreenScaffold.gd"

var difficulty_overlay: Control
var selected_character_value_label: Label
var best_record_value_label: Label
var last_difficulty_label: Label


func _ready() -> void:
	add_fullscreen_background()

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	_build_currency_area(root)
	_build_menu_area(root)
	_build_character_area(root)
	_build_difficulty_overlay(root)


func _on_game_start() -> void:
	difficulty_overlay.visible = true


func _on_character_list() -> void:
	change_scene("res://scenes/ui/CharacterList.tscn")


func _on_achievement() -> void:
	change_scene("res://scenes/ui/Achievement.tscn")


func _on_growth() -> void:
	change_scene("res://scenes/ui/Growth.tscn")


func _on_item_list() -> void:
	change_scene("res://scenes/ui/ItemList.tscn")


func _on_cancel_difficulty_popup() -> void:
	difficulty_overlay.visible = false


func _build_currency_area(parent: Control) -> void:
	var panel := make_panel(parent, Vector2.ZERO)
	panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	panel.offset_left = 48
	panel.offset_top = 36
	panel.offset_right = -48
	panel.offset_bottom = 148

	var margin := make_margin(panel, 20)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)

	var heading := add_label(layout, Locale.ltr("hub_title"), 40)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	heading.custom_minimum_size = Vector2.ZERO

	var currencies := HBoxContainer.new()
	currencies.add_theme_constant_override("separation", 12)
	layout.add_child(currencies)

	var currency_keys := ["hub_currency_gear", "hub_currency_plywood", "hub_currency_lubricant", "hub_currency_iron_ore", "hub_currency_power"]
	for key in currency_keys:
		var slot := make_panel(currencies, Vector2(0, 52), PANEL_ALT_COLOR)
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var slot_margin := make_margin(slot, 12)
		var value := add_label(slot_margin, "%s  -" % Locale.ltr(key), 20)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		value.custom_minimum_size = Vector2.ZERO


func _build_menu_area(parent: Control) -> void:
	var panel := make_panel(parent, Vector2.ZERO)
	panel.anchor_left = 0.0
	panel.anchor_right = 0.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 48
	panel.offset_top = 188
	panel.offset_right = 360
	panel.offset_bottom = -48

	var margin := make_margin(panel, 24)
	var layout := VBoxContainer.new()
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 14)
	margin.add_child(layout)

	var heading := add_label(layout, Locale.ltr("hub_actions_title"), 32)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	heading.custom_minimum_size = Vector2.ZERO

	add_button(layout, Locale.ltr("btn_start_game"), _on_game_start)
	add_button(layout, Locale.ltr("btn_achievements"), _on_achievement)
	add_button(layout, Locale.ltr("btn_character_select"), _on_character_list)
	add_button(layout, Locale.ltr("btn_growth"), _on_growth)
	add_button(layout, Locale.ltr("btn_item_list"), _on_item_list)

	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(filler)

	last_difficulty_label = add_label(
		layout,
		Locale.ltr("hub_last_difficulty") % GameState.last_selected_difficulty_name,
		18
	)
	last_difficulty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	last_difficulty_label.custom_minimum_size = Vector2.ZERO


func _build_character_area(parent: Control) -> void:
	var display_panel := make_panel(parent, Vector2.ZERO, PANEL_ALT_COLOR)
	display_panel.anchor_left = 0.39
	display_panel.anchor_right = 0.81
	display_panel.anchor_top = 0.24
	display_panel.anchor_bottom = 0.72

	var display_margin := make_margin(display_panel, 24)
	var display_layout := VBoxContainer.new()
	display_layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	display_layout.add_theme_constant_override("separation", 12)
	display_margin.add_child(display_layout)

	add_label(display_layout, Locale.ltr("hub_selected_character_title"), 34)

	var filler_top := Control.new()
	filler_top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	display_layout.add_child(filler_top)

	add_label(display_layout, Locale.ltr("hub_character_display_placeholder"), 32)
	selected_character_value_label = add_label(display_layout, GameState.selected_character_name, 24)

	var filler_bottom := Control.new()
	filler_bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	display_layout.add_child(filler_bottom)

	var record_panel := make_panel(parent, Vector2.ZERO)
	record_panel.anchor_left = 0.39
	record_panel.anchor_right = 0.81
	record_panel.anchor_top = 0.76
	record_panel.anchor_bottom = 0.88

	var record_margin := make_margin(record_panel, 20)
	var record_layout := VBoxContainer.new()
	record_layout.add_theme_constant_override("separation", 8)
	record_margin.add_child(record_layout)

	add_label(record_layout, Locale.ltr("hub_best_record_title"), 24)
	best_record_value_label = add_label(record_layout, GameState.best_record_summary, 22)


func _build_difficulty_overlay(parent: Control) -> void:
	difficulty_overlay = Control.new()
	difficulty_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	difficulty_overlay.visible = false
	parent.add_child(difficulty_overlay)

	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	difficulty_overlay.add_child(shade)

	var popup_panel := make_panel(difficulty_overlay, Vector2(540, 0))
	popup_panel.anchor_left = 0.5
	popup_panel.anchor_right = 0.5
	popup_panel.anchor_top = 0.5
	popup_panel.anchor_bottom = 0.5
	popup_panel.offset_left = -270
	popup_panel.offset_top = -250
	popup_panel.offset_right = 270
	popup_panel.offset_bottom = 250

	var margin := make_margin(popup_panel, 24)
	var layout := VBoxContainer.new()
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)

	add_label(layout, Locale.ltr("hub_difficulty_popup_title"), 34)
	add_label(layout, Locale.ltr("hub_difficulty_popup_char") % GameState.selected_character_name, 20)
	add_label(layout, Locale.ltr("hub_difficulty_popup_hint"), 18)
	add_spacer(layout, 8)

	for option_data in GameState.get_difficulty_options():
		var option_id := String(option_data["id"])
		var is_unlocked := bool(option_data.get("unlocked", true))
		var button_text := String(option_data["display_name"])
		if not is_unlocked:
			button_text += Locale.ltr("hub_difficulty_locked_suffix")
		elif bool(option_data["selected"]):
			button_text += Locale.ltr("hub_difficulty_selected_suffix")
		add_button(layout, button_text, func() -> void: _on_pick_difficulty(option_id), not is_unlocked)

	add_spacer(layout, 8)
	add_button(layout, Locale.ltr("btn_cancel"), _on_cancel_difficulty_popup)


func _on_pick_difficulty(difficulty_id: String) -> void:
	if not GameState.begin_run(difficulty_id):
		return
	change_scene("res://scenes/main/Main.tscn")
