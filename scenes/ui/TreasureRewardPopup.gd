extends CanvasLayer
class_name TreasureRewardPopup

signal closed
signal claim_requested(reward_snapshot: Dictionary)
signal sell_requested(reward_snapshot: Dictionary)

var _marker_snapshot := {}
var _reward_snapshot := {}
var _rarity_label: Label
var _reward_name_label: Label
var _reward_rank_label: Label
var _category_label: Label
var _desc_label: Label
var _sell_price_label: Label
var _status_label: Label
var _claim_button: Button
var _sell_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	layer = 80
	set_process_input(true)
	_build_ui()
	_refresh_ui()


func setup(marker_snapshot: Dictionary, reward_snapshot: Dictionary = {}) -> void:
	_marker_snapshot = marker_snapshot.duplicate(true)
	_reward_snapshot = reward_snapshot.duplicate(true)
	_refresh_ui()


func show_result_message(message: String, enable_actions := true) -> void:
	if _status_label != null:
		_status_label.text = message
	_set_action_buttons_enabled(enable_actions and bool(_reward_snapshot.get("ok", false)))


func get_debug_snapshot() -> Dictionary:
	return {
		"marker_id": String(_marker_snapshot.get("marker_id", "")),
		"reward_item_id": String(_reward_snapshot.get("item_id", "")),
		"reward_rank": String(_reward_snapshot.get("rank", "")),
		"sell_price": int(_reward_snapshot.get("sell_price", 0)),
		"claim_enabled": _claim_button != null and not _claim_button.disabled,
		"sell_enabled": _sell_button != null and not _sell_button.disabled,
	}


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_menu", false, false):
		_on_close_pressed()
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.74)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color("141b24"), Color("c9a24a")))
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_bottom", 28)
	panel.add_child(margin)

	var root := VBoxContainer.new()
	root.custom_minimum_size = Vector2(660.0, 470.0)
	root.add_theme_constant_override("separation", 16)
	margin.add_child(root)

	var title := Label.new()
	title.text = "TREASURE CHEST"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color("f4d77a"))
	root.add_child(title)

	_rarity_label = Label.new()
	_rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rarity_label.add_theme_font_size_override("font_size", 22)
	root.add_child(_rarity_label)

	var reward_panel := PanelContainer.new()
	reward_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.08, 0.11, 0.15, 0.96), Color("405065")))
	root.add_child(reward_panel)

	var reward_margin := MarginContainer.new()
	reward_margin.add_theme_constant_override("margin_left", 20)
	reward_margin.add_theme_constant_override("margin_top", 18)
	reward_margin.add_theme_constant_override("margin_right", 20)
	reward_margin.add_theme_constant_override("margin_bottom", 18)
	reward_panel.add_child(reward_margin)

	var reward_box := VBoxContainer.new()
	reward_box.add_theme_constant_override("separation", 9)
	reward_margin.add_child(reward_box)

	_reward_name_label = Label.new()
	_reward_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reward_name_label.add_theme_font_size_override("font_size", 30)
	_reward_name_label.add_theme_color_override("font_color", Color("f1f5f8"))
	reward_box.add_child(_reward_name_label)

	_reward_rank_label = Label.new()
	_reward_rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reward_rank_label.add_theme_font_size_override("font_size", 20)
	_reward_rank_label.add_theme_color_override("font_color", Color("9fb4c8"))
	reward_box.add_child(_reward_rank_label)

	_category_label = Label.new()
	_category_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_category_label.add_theme_font_size_override("font_size", 18)
	_category_label.add_theme_color_override("font_color", Color("cbd7e2"))
	reward_box.add_child(_category_label)

	_desc_label = Label.new()
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc_label.add_theme_font_size_override("font_size", 17)
	_desc_label.add_theme_color_override("font_color", Color("dce5ee"))
	reward_box.add_child(_desc_label)

	_sell_price_label = Label.new()
	_sell_price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sell_price_label.add_theme_font_size_override("font_size", 19)
	_sell_price_label.add_theme_color_override("font_color", Color("f4d77a"))
	root.add_child(_sell_price_label)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 16)
	_status_label.add_theme_color_override("font_color", Color("dce5ee"))
	root.add_child(_status_label)

	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 14)
	root.add_child(button_row)

	_claim_button = Button.new()
	_claim_button.text = "Obtain"
	_claim_button.custom_minimum_size = Vector2(150.0, 54.0)
	_claim_button.add_theme_font_size_override("font_size", 21)
	_claim_button.pressed.connect(_on_claim_pressed)
	button_row.add_child(_claim_button)

	_sell_button = Button.new()
	_sell_button.custom_minimum_size = Vector2(150.0, 54.0)
	_sell_button.add_theme_font_size_override("font_size", 21)
	_sell_button.pressed.connect(_on_sell_pressed)
	button_row.add_child(_sell_button)

	var close_button := Button.new()
	close_button.text = "Close"
	close_button.custom_minimum_size = Vector2(150.0, 54.0)
	close_button.add_theme_font_size_override("font_size", 21)
	close_button.pressed.connect(_on_close_pressed)
	button_row.add_child(close_button)


func _refresh_ui() -> void:
	if _rarity_label == null:
		return
	var chest_rarity := String(_marker_snapshot.get("chest_rarity", "bronze"))
	var reward_ok := bool(_reward_snapshot.get("ok", false))
	_rarity_label.text = "%s Chest" % chest_rarity.capitalize()
	_rarity_label.add_theme_color_override("font_color", _get_rarity_color(chest_rarity))
	if reward_ok:
		_reward_name_label.text = String(_reward_snapshot.get("name", _reward_snapshot.get("item_id", "")))
		_reward_rank_label.text = "Reward Rank: %s" % String(_reward_snapshot.get("rank", "D"))
		if bool(_reward_snapshot.get("fallback_used", false)):
			_reward_rank_label.text += " (fallback from %s)" % String(_reward_snapshot.get("rolled_rank", ""))
		_category_label.text = _format_category(String(_reward_snapshot.get("item_category", "")))
		var desc := String(_reward_snapshot.get("short_desc", ""))
		if desc.is_empty():
			desc = String(_reward_snapshot.get("desc", ""))
		_desc_label.text = desc
		_sell_price_label.text = "Sell Price: %dG" % int(_reward_snapshot.get("sell_price", 0))
		_sell_button.text = "Sell +%dG" % int(_reward_snapshot.get("sell_price", 0))
		_status_label.text = "Choose Obtain to keep the item, or Sell to convert it to gold."
	else:
		_reward_name_label.text = "Reward unavailable"
		_reward_rank_label.text = "Reward Rank: -"
		_category_label.text = ""
		_desc_label.text = String(_reward_snapshot.get("reason", "No reward candidate was found."))
		_sell_price_label.text = "Sell Price: 0G"
		_sell_button.text = "Sell"
		_status_label.text = "Close this popup and continue the run."
	_set_action_buttons_enabled(reward_ok)


func _set_action_buttons_enabled(enabled: bool) -> void:
	if _claim_button != null:
		_claim_button.disabled = not enabled
	if _sell_button != null:
		_sell_button.disabled = not enabled


func _on_claim_pressed() -> void:
	_set_action_buttons_enabled(false)
	claim_requested.emit(_reward_snapshot.duplicate(true))


func _on_sell_pressed() -> void:
	_set_action_buttons_enabled(false)
	sell_requested.emit(_reward_snapshot.duplicate(true))


func _on_close_pressed() -> void:
	closed.emit()
	queue_free()


func _format_category(category: String) -> String:
	match category:
		"attack_module":
			return "Attack Module"
		"function_module":
			return "Function Module"
		"enhance_module":
			return "Enhance Module"
		_:
			return category.capitalize()


func _get_rarity_color(rarity: String) -> Color:
	match rarity:
		"silver":
			return Color("d9e7f3")
		"gold":
			return Color("ffd76a")
		"platinum":
			return Color("b9f3ff")
		_:
			return Color("d89455")


func _make_panel_style(background_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = border_color
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	return style
