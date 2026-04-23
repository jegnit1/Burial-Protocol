extends CanvasLayer
class_name DayShopUI

signal next_day_requested
signal closed
signal item_purchased(item_id: StringName)

var _shop_item_ids := PackedStringArray()
var _selected_index := 0
var _item_buttons: Array[Button] = []
var _owned_attack_buttons: Array[Button] = []

var _gold_label: Label
var _status_label: Label
var _owned_attack_row: HBoxContainer
var _item_list: VBoxContainer
var _detail_name_label: Label
var _detail_meta_label: Label
var _detail_short_desc_label: Label
var _detail_desc_label: RichTextLabel
var _detail_state_label: Label
var _action_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(true)
	_build_ui()
	if not GameState.gold_changed.is_connected(_on_shop_state_changed):
		GameState.gold_changed.connect(_on_shop_state_changed)
	if not GameState.run_items_changed.is_connected(_on_shop_state_changed):
		GameState.run_items_changed.connect(_on_shop_state_changed)
	_refresh_ui()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_menu", false, false):
		_on_close_pressed()
		get_viewport().set_input_as_handled()


func set_shop_item_ids(item_ids: PackedStringArray) -> void:
	_shop_item_ids = item_ids.duplicate()
	_selected_index = clampi(_selected_index, 0, max(_shop_item_ids.size() - 1, 0))
	_refresh_ui()


func set_attack_module_shop_snapshot(_snapshot: Dictionary) -> void:
	# 기존 호출부 호환을 위해 남겨둔 진입점이다.
	_refresh_ui()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.0, 0.0, 0.0, 0.76)
	add_child(bg)

	var center_container := CenterContainer.new()
	center_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center_container)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color("18202a"), Color("5e7f95"), 16))
	center_container.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var root := VBoxContainer.new()
	root.custom_minimum_size = Vector2(1280.0, 700.0)
	root.add_theme_constant_override("separation", 16)
	margin.add_child(root)

	var title := Label.new()
	title.text = "INTERMISSION SHOP"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color("f0d984"))
	root.add_child(title)

	var hint := Label.new()
	hint.text = "Buy new items, equip owned attack modules for free, then proceed with Next Day."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Color("d9e2eb"))
	root.add_child(hint)

	var info_row := HBoxContainer.new()
	info_row.add_theme_constant_override("separation", 16)
	root.add_child(info_row)

	_gold_label = Label.new()
	_gold_label.add_theme_font_size_override("font_size", 22)
	_gold_label.add_theme_color_override("font_color", Color("f0d984"))
	info_row.add_child(_gold_label)

	_status_label = Label.new()
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status_label.add_theme_font_size_override("font_size", 16)
	_status_label.add_theme_color_override("font_color", Color("91b0c9"))
	info_row.add_child(_status_label)

	var owned_panel := PanelContainer.new()
	owned_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.10, 0.13, 0.17, 0.92), Color("435768"), 10))
	root.add_child(owned_panel)

	var owned_margin := MarginContainer.new()
	owned_margin.add_theme_constant_override("margin_left", 14)
	owned_margin.add_theme_constant_override("margin_top", 10)
	owned_margin.add_theme_constant_override("margin_right", 14)
	owned_margin.add_theme_constant_override("margin_bottom", 10)
	owned_panel.add_child(owned_margin)

	var owned_vbox := VBoxContainer.new()
	owned_vbox.add_theme_constant_override("separation", 8)
	owned_margin.add_child(owned_vbox)

	var owned_title := Label.new()
	owned_title.text = "Owned Attack Modules"
	owned_title.add_theme_font_size_override("font_size", 20)
	owned_title.add_theme_color_override("font_color", Color("dfe8f2"))
	owned_vbox.add_child(owned_title)

	_owned_attack_row = HBoxContainer.new()
	_owned_attack_row.add_theme_constant_override("separation", 10)
	owned_vbox.add_child(_owned_attack_row)

	var content_split := HBoxContainer.new()
	content_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_split.add_theme_constant_override("separation", 18)
	root.add_child(content_split)

	var list_panel := PanelContainer.new()
	list_panel.custom_minimum_size = Vector2(420.0, 0.0)
	list_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.11, 0.14, 0.18, 0.94), Color("435768"), 12))
	content_split.add_child(list_panel)

	var list_margin := MarginContainer.new()
	list_margin.add_theme_constant_override("margin_left", 14)
	list_margin.add_theme_constant_override("margin_top", 14)
	list_margin.add_theme_constant_override("margin_right", 14)
	list_margin.add_theme_constant_override("margin_bottom", 14)
	list_panel.add_child(list_margin)

	var list_vbox := VBoxContainer.new()
	list_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_vbox.add_theme_constant_override("separation", 10)
	list_margin.add_child(list_vbox)

	var list_title := Label.new()
	list_title.text = "Shop Items"
	list_title.add_theme_font_size_override("font_size", 24)
	list_title.add_theme_color_override("font_color", Color("f1f5f8"))
	list_vbox.add_child(list_title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_vbox.add_child(scroll)

	_item_list = VBoxContainer.new()
	_item_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_item_list)

	var detail_panel := PanelContainer.new()
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.09, 0.12, 0.16, 0.96), Color("435768"), 12))
	content_split.add_child(detail_panel)

	var detail_margin := MarginContainer.new()
	detail_margin.add_theme_constant_override("margin_left", 18)
	detail_margin.add_theme_constant_override("margin_top", 18)
	detail_margin.add_theme_constant_override("margin_right", 18)
	detail_margin.add_theme_constant_override("margin_bottom", 18)
	detail_panel.add_child(detail_margin)

	var detail_vbox := VBoxContainer.new()
	detail_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_vbox.add_theme_constant_override("separation", 10)
	detail_margin.add_child(detail_vbox)

	_detail_name_label = Label.new()
	_detail_name_label.add_theme_font_size_override("font_size", 30)
	_detail_name_label.add_theme_color_override("font_color", Color("f2f5f7"))
	detail_vbox.add_child(_detail_name_label)

	_detail_meta_label = Label.new()
	_detail_meta_label.add_theme_font_size_override("font_size", 18)
	_detail_meta_label.add_theme_color_override("font_color", Color("8ea8bc"))
	detail_vbox.add_child(_detail_meta_label)

	_detail_short_desc_label = Label.new()
	_detail_short_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_detail_short_desc_label.add_theme_font_size_override("font_size", 18)
	_detail_short_desc_label.add_theme_color_override("font_color", Color("d9e2eb"))
	detail_vbox.add_child(_detail_short_desc_label)

	_detail_desc_label = RichTextLabel.new()
	_detail_desc_label.bbcode_enabled = false
	_detail_desc_label.fit_content = false
	_detail_desc_label.scroll_active = true
	_detail_desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_desc_label.custom_minimum_size = Vector2(0.0, 260.0)
	detail_vbox.add_child(_detail_desc_label)

	_detail_state_label = Label.new()
	_detail_state_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_detail_state_label.add_theme_font_size_override("font_size", 17)
	_detail_state_label.add_theme_color_override("font_color", Color("f0d984"))
	detail_vbox.add_child(_detail_state_label)

	_action_button = Button.new()
	_action_button.custom_minimum_size = Vector2(180.0, 52.0)
	_action_button.add_theme_font_size_override("font_size", 22)
	_action_button.pressed.connect(_on_action_pressed)
	detail_vbox.add_child(_action_button)

	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 12)
	root.add_child(button_row)

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


func _refresh_ui() -> void:
	if _gold_label == null:
		return
	var snapshot := GameState.get_day_shop_snapshot(_shop_item_ids)
	_gold_label.text = "GOLD %d" % int(snapshot.get("gold", 0))
	_status_label.text = "Remaining %d | Price 100G | Bought items are removed immediately" % _shop_item_ids.size()
	_refresh_owned_attack_modules()
	_refresh_item_list(snapshot)
	_refresh_detail(snapshot)


func _refresh_owned_attack_modules() -> void:
	if _owned_attack_row == null:
		return
	for child in _owned_attack_row.get_children():
		child.queue_free()
	_owned_attack_buttons.clear()
	for entry in GameState.get_equipped_attack_module_entries():
		var definition = GameState.get_attack_module_definition_from_entry(entry)
		if definition == null:
			continue
		var button := Button.new()
		button.text = "%s %s" % [
			String(definition.display_name),
			String(entry.get("grade", "D")),
		]
		button.disabled = true
		_owned_attack_row.add_child(button)
		_owned_attack_buttons.append(button)
	if _owned_attack_buttons.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No owned attack modules."
		empty_label.add_theme_color_override("font_color", Color("8ea8bc"))
		_owned_attack_row.add_child(empty_label)


func _refresh_item_list(snapshot: Dictionary) -> void:
	if _item_list == null:
		return
	for child in _item_list.get_children():
		child.queue_free()
	_item_buttons.clear()
	var entries: Array = snapshot.get("item_entries", [])
	if entries.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No items remain in this shop."
		empty_label.add_theme_color_override("font_color", Color("8ea8bc"))
		_item_list.add_child(empty_label)
		_selected_index = 0
		return
	_selected_index = clampi(_selected_index, 0, entries.size() - 1)
	for index in range(entries.size()):
		var entry: Dictionary = entries[index]
		var button := Button.new()
		button.text = "[%s][%s] %s - %dG" % [
			String(entry.get("rank", "?")),
			_category_label(String(entry.get("item_category", ""))),
			String(entry.get("name", "")),
			int(entry.get("price_gold", 0)),
		]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = true
		button.button_pressed = index == _selected_index
		button.pressed.connect(_on_item_selected.bind(index))
		_item_list.add_child(button)
		_item_buttons.append(button)


func _refresh_detail(snapshot: Dictionary) -> void:
	if _detail_name_label == null:
		return
	var entries: Array = snapshot.get("item_entries", [])
	if entries.is_empty():
		_detail_name_label.text = "No Item"
		_detail_meta_label.text = ""
		_detail_short_desc_label.text = ""
		_detail_desc_label.text = "This shop has no remaining items."
		_detail_state_label.text = ""
		_action_button.disabled = true
		_action_button.text = "Unavailable"
		return
	_selected_index = clampi(_selected_index, 0, entries.size() - 1)
	var entry: Dictionary = entries[_selected_index]
	var category := String(entry.get("item_category", ""))
	var item_id := String(entry.get("item_id", ""))
	var stack_count := int(entry.get("stack_count", 0))
	var owned := bool(entry.get("owned", false))
	var equipped := bool(entry.get("equipped", false))
	var can_afford := bool(entry.get("can_afford", false))
	var can_buy := bool(entry.get("can_buy", can_afford))
	_detail_name_label.text = String(entry.get("name", item_id))
	_detail_meta_label.text = "Category %s   Rank %s   Price %dG" % [
		_category_label(category),
		String(entry.get("rank", "?")),
		int(entry.get("price_gold", 0)),
	]
	_detail_short_desc_label.text = String(entry.get("short_desc", ""))
	_detail_desc_label.text = String(entry.get("desc", ""))
	_detail_state_label.text = _build_state_text(category, owned, equipped, stack_count, can_buy)

	match category:
		"attack_module":
			_action_button.text = "Buy / Merge"
			_action_button.disabled = not can_buy
		"function_module":
			if owned:
				_action_button.text = "Owned"
				_action_button.disabled = true
			else:
				_action_button.text = "Buy"
				_action_button.disabled = not can_afford
		"enhance_module":
			_action_button.text = "Buy"
			_action_button.disabled = not can_afford
		_:
			_action_button.text = "Unavailable"
			_action_button.disabled = true


func _build_state_text(category: String, owned: bool, equipped: bool, stack_count: int, can_afford: bool) -> String:
	match category:
		"attack_module":
			if not can_afford:
				return "Not enough gold, no empty slot, or no same-grade merge target."
			if equipped or owned:
				return "Buying another copy adds a duplicate slot or merges if slots are full."
			return "Buying immediately equips this module into an empty slot."
		"function_module":
			if owned:
				return "Already owned in this run and registered in current effects."
			if not can_afford:
				return "Not enough gold."
			return "Buying registers it to current run effects immediately."
		"enhance_module":
			if stack_count > 0:
				return "Current stack %d. Buying again stacks immediately." % stack_count
			if not can_afford:
				return "Not enough gold."
			return "Buying applies the stat bonus immediately."
	return "Unsupported item category."


func _on_item_selected(index: int) -> void:
	_selected_index = index
	_refresh_ui()


func _on_owned_attack_module_pressed(module_id: StringName) -> void:
	if GameState.equip_attack_module(module_id):
		GameState.set_status_text("Attack module switched to %s." % GameState.get_equipped_attack_module_display_name())
	_refresh_ui()


func _on_action_pressed() -> void:
	var snapshot := GameState.get_day_shop_snapshot(_shop_item_ids)
	var entries: Array = snapshot.get("item_entries", [])
	if entries.is_empty():
		return
	_selected_index = clampi(_selected_index, 0, entries.size() - 1)
	var entry: Dictionary = entries[_selected_index]
	var item_id := StringName(String(entry.get("item_id", "")))
	var category := String(entry.get("item_category", ""))
	var result := GameState.purchase_shop_item(item_id)
	if bool(result.get("ok", false)):
		GameState.set_status_text("%s purchased." % String(entry.get("name", "")))
		_remove_shop_item(item_id)
		item_purchased.emit(item_id)
	else:
		var reason := String(result.get("reason", "failed"))
		match reason:
			"insufficient_gold":
				GameState.set_status_text("Not enough gold.")
			"already_owned":
				GameState.set_status_text("Item already owned.")
			_:
				GameState.set_status_text("Failed to process shop item.")
	_refresh_ui()


func _on_shop_state_changed(_value = null, _value_b = null) -> void:
	_refresh_ui()


func _remove_shop_item(item_id: StringName) -> void:
	# 실제 구매가 일어난 상품만 현재 상점 목록에서 제거한다.
	var item_key := String(item_id)
	var remaining_ids := PackedStringArray()
	for raw_item_id in _shop_item_ids:
		if raw_item_id == item_key:
			continue
		remaining_ids.append(raw_item_id)
	_shop_item_ids = remaining_ids
	_selected_index = clampi(_selected_index, 0, max(_shop_item_ids.size() - 1, 0))


func _on_close_pressed() -> void:
	closed.emit()
	queue_free()


func _on_next_day_pressed() -> void:
	next_day_requested.emit()


func _category_label(category: String) -> String:
	match category:
		"attack_module":
			return "ATK"
		"function_module":
			return "FUNC"
		"enhance_module":
			return "ENH"
	return "ETC"


func _make_panel_style(background_color: Color, border_color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = border_color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius
	return style
