extends CanvasLayer
class_name DayShopUI

signal next_day_requested
signal closed
signal item_purchased(item_id: StringName)
signal reroll_requested

var _shop_item_ids := PackedStringArray()
var _selected_index := 0
var _item_buttons: Array[Button] = []
var _lock_buttons: Array[Button] = []
var _equipment_slot_buttons: Array[Button] = []
var _selected_weapon_slot := ""
var _selected_drone_protocol_slot := -1
var _selected_passive_module_slot := -1

var _gold_label: Label
var _status_label: Label
var _equipment_slots_vbox: VBoxContainer
var _item_list: VBoxContainer
var _detail_name_label: Label
var _detail_meta_label: Label
var _detail_short_desc_label: Label
var _detail_desc_label: RichTextLabel
var _detail_state_label: Label
var _action_button: Button
var _reroll_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(true)
	_build_ui()
	if not GameState.gold_changed.is_connected(_on_shop_state_changed):
		GameState.gold_changed.connect(_on_shop_state_changed)
	if not GameState.run_items_changed.is_connected(_on_shop_state_changed):
		GameState.run_items_changed.connect(_on_shop_state_changed)
	if not GameState.shop_reroll_count_changed.is_connected(_on_shop_state_changed):
		GameState.shop_reroll_count_changed.connect(_on_shop_state_changed)
	if not GameState.shop_locked_slots_changed.is_connected(_on_shop_state_changed):
		GameState.shop_locked_slots_changed.connect(_on_shop_state_changed)
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
	hint.text = "Equip two weapons, install up to five drone protocols and five passive modules, then proceed with Next Day."
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
	owned_title.text = "Equipment Slots"
	owned_title.add_theme_font_size_override("font_size", 20)
	owned_title.add_theme_color_override("font_color", Color("dfe8f2"))
	owned_vbox.add_child(owned_title)

	_equipment_slots_vbox = VBoxContainer.new()
	_equipment_slots_vbox.add_theme_constant_override("separation", 6)
	owned_vbox.add_child(_equipment_slots_vbox)

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

	_reroll_button = Button.new()
	_reroll_button.custom_minimum_size = Vector2(180.0, 48.0)
	_reroll_button.pressed.connect(_on_reroll_pressed)
	button_row.add_child(_reroll_button)

	var next_day_button := Button.new()
	next_day_button.text = "Next Day"
	next_day_button.custom_minimum_size = Vector2(180.0, 48.0)
	next_day_button.pressed.connect(_on_next_day_pressed)
	button_row.add_child(next_day_button)


func _refresh_ui() -> void:
	if _gold_label == null:
		return
	var snapshot := GameState.get_day_shop_snapshot(_shop_item_ids, _get_equipment_targets())
	_gold_label.text = "GOLD %d" % int(snapshot.get("gold", 0))
	_status_label.text = "Remaining %d | Bought items are removed immediately" % _shop_item_ids.size()
	_refresh_reroll_button(snapshot)
	_refresh_equipment_slots()
	_refresh_item_list(snapshot)
	_refresh_detail(snapshot)


func _refresh_reroll_button(snapshot: Dictionary) -> void:
	if _reroll_button == null:
		return
	var cost := int(snapshot.get("shop_reroll_cost", GameState.get_current_shop_reroll_cost()))
	_reroll_button.text = "Reroll (%dG)" % cost
	_reroll_button.disabled = not bool(snapshot.get("can_afford_shop_reroll", GameState.can_afford_shop_reroll()))


func _refresh_equipment_slots() -> void:
	if _equipment_slots_vbox == null:
		return
	for child in _equipment_slots_vbox.get_children():
		child.queue_free()
	_equipment_slot_buttons.clear()
	_add_weapon_slot_row()
	_add_drone_slot_row()
	_add_equipment_entry_row(
		"Protocols",
		GameState.get_equipped_drone_protocol_entries(),
		GameConstants.DRONE_PROTOCOL_MAX_EQUIPPED,
		"drone_protocol"
	)
	_add_equipment_entry_row(
		"Passives",
		GameState.get_equipped_passive_module_entries(),
		GameConstants.PASSIVE_MODULE_MAX_EQUIPPED,
		"passive_module"
	)


func _add_weapon_slot_row() -> void:
	var row := _make_equipment_row("Weapons")
	var entries := {
		"left": GameState.get_equipped_weapon_left(),
		"right": GameState.get_equipped_weapon_right(),
	}
	for slot in ["left", "right"]:
		var entry: Dictionary = entries[slot]
		var button := Button.new()
		button.text = "%s: %s" % [slot.capitalize(), _get_weapon_entry_label(entry)]
		button.toggle_mode = true
		button.button_pressed = _selected_weapon_slot == slot
		button.pressed.connect(_on_weapon_slot_pressed.bind(slot))
		row.add_child(button)
		_equipment_slot_buttons.append(button)


func _add_drone_slot_row() -> void:
	var row := _make_equipment_row("Drone")
	var button := Button.new()
	button.text = String(GameState.get_equipped_drone_id())
	button.disabled = true
	row.add_child(button)
	_equipment_slot_buttons.append(button)


func _add_equipment_entry_row(label_text: String, entries: Array[Dictionary], max_slots: int, category: String) -> void:
	var row := _make_equipment_row(label_text)
	for slot_index in range(max_slots):
		var button := Button.new()
		var entry: Dictionary = entries[slot_index] if slot_index < entries.size() else {}
		button.text = "%d: %s" % [slot_index + 1, _get_equipment_entry_label(entry)]
		if category == "drone_protocol":
			button.toggle_mode = true
			button.button_pressed = _selected_drone_protocol_slot == slot_index
			button.pressed.connect(_on_drone_protocol_slot_pressed.bind(slot_index))
		elif category == "passive_module":
			button.toggle_mode = true
			button.button_pressed = _selected_passive_module_slot == slot_index
			button.pressed.connect(_on_passive_module_slot_pressed.bind(slot_index))
		else:
			button.disabled = true
		row.add_child(button)
		_equipment_slot_buttons.append(button)


func _make_equipment_row(label_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_equipment_slots_vbox.add_child(row)
	var label := Label.new()
	label.text = "%s:" % label_text
	label.custom_minimum_size = Vector2(88.0, 0.0)
	label.add_theme_color_override("font_color", Color("8ea8bc"))
	row.add_child(label)
	return row


func _get_weapon_entry_label(entry: Dictionary) -> String:
	if entry.is_empty():
		return "Empty"
	return GameState.get_attack_module_entry_label(entry)


func _get_equipment_entry_label(entry: Dictionary) -> String:
	if entry.is_empty():
		return "Empty"
	var item_id := StringName(String(entry.get("item_id", "")))
	var definition := GameData.get_shop_item_definition(item_id)
	return String(definition.get("name", item_id)) if not definition.is_empty() else String(item_id)


func _refresh_item_list(snapshot: Dictionary) -> void:
	if _item_list == null:
		return
	for child in _item_list.get_children():
		child.queue_free()
	_item_buttons.clear()
	_lock_buttons.clear()
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
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_item_list.add_child(row)
		var lock_button := Button.new()
		lock_button.custom_minimum_size = Vector2(86.0, 0.0)
		lock_button.toggle_mode = true
		lock_button.button_pressed = bool(entry.get("is_locked", false))
		lock_button.text = "Unlock" if lock_button.button_pressed else "Lock"
		lock_button.disabled = not bool(entry.get("can_lock", true))
		lock_button.pressed.connect(_on_lock_pressed.bind(index))
		row.add_child(lock_button)
		_lock_buttons.append(lock_button)
		var button := Button.new()
		button.text = "[%s][%s] %s - %dG" % [
			String(entry.get("rank", "?")),
			_category_label(String(entry.get("item_category", ""))),
			String(entry.get("name", "")),
			int(entry.get("price_gold", 0)),
		]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		button.button_pressed = index == _selected_index
		button.pressed.connect(_on_item_selected.bind(index))
		row.add_child(button)
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
	var active := bool(entry.get("active", true))
	var inactive_reason := String(entry.get("inactive_reason", ""))
	var lock_text := "   LOCKED" if bool(entry.get("is_locked", false)) else ""
	_detail_name_label.text = String(entry.get("name", item_id))
	_detail_meta_label.text = "Category %s   Rank %s   Price %dG%s" % [
		_category_label(category),
		String(entry.get("rank", "?")),
		int(entry.get("price_gold", 0)),
		lock_text,
	]
	_detail_short_desc_label.text = String(entry.get("short_desc", ""))
	_detail_desc_label.text = String(entry.get("desc", ""))
	_detail_state_label.text = _build_state_text(category, owned, equipped, stack_count, can_buy, active, inactive_reason)

	match category:
		"weapon", "attack_module":
			_action_button.text = "Buy / Equip"
			_action_button.disabled = not can_buy
		"drone_protocol":
			_action_button.text = "Buy / Install"
			_action_button.disabled = not can_buy
		"passive_module":
			_action_button.text = "Buy / Install"
			_action_button.disabled = not can_buy
		"part":
			_action_button.text = "Buy"
			_action_button.disabled = not can_buy
		"artifact":
			_action_button.text = "Buy"
			_action_button.disabled = not can_buy
		"function_module":
			_action_button.text = "Owned" if owned else "Buy"
			_action_button.disabled = owned or not can_buy
		"enhance_module":
			_action_button.text = "Buy"
			_action_button.disabled = not can_buy
		_:
			_action_button.text = "Unavailable"
			_action_button.disabled = true


func _build_state_text(category: String, owned: bool, equipped: bool, stack_count: int, can_buy: bool, active: bool = true, inactive_reason: String = "") -> String:
	match category:
		"weapon", "attack_module":
			if not can_buy:
				return "Weapon slots are full. Select Left or Right above to replace that slot."
			if equipped or owned:
				return "Buying equips this weapon. Empty slots are filled first; a selected slot is replaced."
			return "Buying equips this weapon. Empty slots are filled first."
		"drone_protocol":
			if not can_buy:
				return "Protocol slots are full. Select a protocol slot above to replace it."
			if stack_count > 0:
				return "Installed copies %d. Duplicate protocols are allowed." % stack_count
			return "Buying installs this automated drone protocol."
		"passive_module":
			if not can_buy:
				return "Passive slots are full. Select a passive slot above to replace it, or check this module's stack limit."
			if stack_count > 0:
				return "Installed copies %d. Buying installs another allowed copy." % stack_count
			return "Buying installs this passive module and applies its effect."
		"part":
			if stack_count > 0:
				return "Equipped copies %d. Incompatible parts stay installed but inactive." % stack_count
			if not can_buy:
				return "Cannot buy: part slots may be full, stacked out, or exclusive with another part."
			if not active and not inactive_reason.is_empty():
				return "%s. It will stay installed but inactive until a compatible weapon is equipped." % inactive_reason
			return "Buying attaches this part to the current weapon set."
		"artifact":
			if stack_count > 0:
				return "Current stack %d. Buying again stacks immediately." % stack_count
			if not can_buy:
				return "Cannot buy this artifact right now."
			return "Buying adds this artifact to the run immediately."
		"function_module":
			if owned:
				return "Already owned in this run and registered in current effects."
			if not can_buy:
				return "Not enough gold."
			return "Buying registers it to current run effects immediately."
		"enhance_module":
			if stack_count > 0:
				return "Current stack %d. Buying again stacks immediately." % stack_count
			if not can_buy:
				return "Not enough gold."
			return "Buying applies the stat bonus immediately."
	return "Unsupported item category."


func _on_item_selected(index: int) -> void:
	_selected_index = index
	_refresh_ui()


func _on_lock_pressed(index: int) -> void:
	var snapshot := GameState.get_day_shop_snapshot(_shop_item_ids, _get_equipment_targets())
	var entries: Array = snapshot.get("item_entries", [])
	if index < 0 or index >= entries.size():
		return
	_selected_index = index
	var entry: Dictionary = entries[index]
	var item_id := StringName(String(entry.get("item_id", "")))
	var locked := GameState.toggle_shop_slot_locked(index, item_id)
	var action_text := "locked" if locked else "unlocked"
	GameState.set_status_text("%s %s." % [String(entry.get("name", "Shop item")), action_text])
	_refresh_ui()


func _on_owned_attack_module_pressed(module_id: StringName) -> void:
	if GameState.equip_attack_module(module_id):
		GameState.set_status_text("Attack module switched to %s." % GameState.get_equipped_attack_module_display_name())
	_refresh_ui()


func _on_weapon_slot_pressed(slot: String) -> void:
	_selected_weapon_slot = "" if _selected_weapon_slot == slot else slot
	_refresh_ui()


func _on_drone_protocol_slot_pressed(slot_index: int) -> void:
	_selected_drone_protocol_slot = -1 if _selected_drone_protocol_slot == slot_index else slot_index
	_refresh_ui()


func _on_passive_module_slot_pressed(slot_index: int) -> void:
	_selected_passive_module_slot = -1 if _selected_passive_module_slot == slot_index else slot_index
	_refresh_ui()


func _get_equipment_targets() -> Dictionary:
	var targets := {}
	if not _selected_weapon_slot.is_empty():
		targets["weapon_slot"] = _selected_weapon_slot
	if _selected_drone_protocol_slot >= 0:
		targets["drone_protocol_slot"] = _selected_drone_protocol_slot
	if _selected_passive_module_slot >= 0:
		targets["passive_module_slot"] = _selected_passive_module_slot
	return targets


func _on_action_pressed() -> void:
	var equipment_targets := _get_equipment_targets()
	var snapshot := GameState.get_day_shop_snapshot(_shop_item_ids, equipment_targets)
	var entries: Array = snapshot.get("item_entries", [])
	if entries.is_empty():
		return
	_selected_index = clampi(_selected_index, 0, entries.size() - 1)
	var entry: Dictionary = entries[_selected_index]
	var item_id := StringName(String(entry.get("item_id", "")))
	var category := String(entry.get("item_category", ""))
	var result := GameState.purchase_shop_item(item_id, equipment_targets)
	if bool(result.get("ok", false)):
		var purchased_index := _selected_index
		_clear_equipment_target_for_category(category)
		GameState.set_status_text("%s purchased." % String(entry.get("name", "")))
		GameState.remove_shop_slot_lock_and_shift(purchased_index)
		_remove_shop_item_at_index(purchased_index, item_id)
		item_purchased.emit(item_id)
	else:
		var reason := String(result.get("reason", "failed"))
		match reason:
			"insufficient_gold":
				GameState.set_status_text("Not enough gold.")
			"already_owned":
				GameState.set_status_text("Item already owned.")
			"part_slots_full":
				GameState.set_status_text("Part slots are full.")
			"part_stack_full", "artifact_stack_full", "stack_full":
				GameState.set_status_text("Item stack limit reached.")
			"part_exclusive_conflict":
				GameState.set_status_text("A mutually exclusive part is already equipped.")
			"weapon_slot_required":
				GameState.set_status_text("Select the Left or Right weapon slot to replace.")
			"drone_protocol_slot_required":
				GameState.set_status_text("Select a drone protocol slot to replace.")
			"passive_module_slot_required":
				GameState.set_status_text("Select a passive module slot to replace.")
			"passive_module_non_stackable", "passive_module_stack_full":
				GameState.set_status_text("This passive module cannot be installed again.")
			_:
				GameState.set_status_text("Failed to process shop item.")
	_refresh_ui()


func _clear_equipment_target_for_category(category: String) -> void:
	if category == "weapon" or category == "attack_module":
		_selected_weapon_slot = ""
	elif category == "drone_protocol":
		_selected_drone_protocol_slot = -1
	elif category == "passive_module":
		_selected_passive_module_slot = -1


func _on_reroll_pressed() -> void:
	if not GameState.can_afford_shop_reroll():
		GameState.set_status_text("Not enough gold to reroll.")
		_refresh_ui()
		return
	reroll_requested.emit()


func _on_shop_state_changed(_value = null, _value_b = null) -> void:
	_refresh_ui()


func _remove_shop_item_at_index(slot_index: int, item_id: StringName) -> void:
	# 실제 구매가 일어난 상품만 현재 상점 목록에서 제거한다.
	var item_key := String(item_id)
	var remaining_ids := PackedStringArray()
	for index in range(_shop_item_ids.size()):
		if index == slot_index and _shop_item_ids[index] == item_key:
			continue
		remaining_ids.append(_shop_item_ids[index])
	_shop_item_ids = remaining_ids
	_selected_index = clampi(_selected_index, 0, max(_shop_item_ids.size() - 1, 0))


func _on_close_pressed() -> void:
	closed.emit()
	queue_free()


func _on_next_day_pressed() -> void:
	next_day_requested.emit()


func _category_label(category: String) -> String:
	match category:
		"weapon":
			return "WPN"
		"drone_protocol":
			return "PROTO"
		"passive_module":
			return "PASSIVE"
		"part":
			return "PART"
		"artifact":
			return "ART"
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
