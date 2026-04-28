extends CanvasLayer
class_name LevelUpUI

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	layer = 50

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.0, 0.0, 0.0, 0.75)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var center_container := CenterContainer.new()
	center_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center_container)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 40)
	center_container.add_child(vbox)

	var title := Label.new()
	title.text = "LEVEL UP!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color("f0d984"))
	vbox.add_child(title)

	var card_container := HBoxContainer.new()
	card_container.add_theme_constant_override("separation", 20)
	card_container.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(card_container)

	var cards := GameState.generate_level_up_card_choices(5)

	for i in range(min(5, cards.size())):
		var card_data: Dictionary = cards[i]
		var btn := _create_card_button(card_data)
		btn.pressed.connect(_on_card_selected.bind(String(card_data["id"]), String(card_data.get("rarity_id", "normal"))))
		card_container.add_child(btn)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_menu"):
		get_viewport().set_input_as_handled()


func _create_card_button(data: Dictionary) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(200, 300)
	var rarity_id := _get_card_rarity_id(data)
	var rarity_style := _get_rarity_style(rarity_id)

	var normal_sb := StyleBoxFlat.new()
	normal_sb.bg_color = rarity_style["bg"]
	normal_sb.border_width_left = int(rarity_style["border_width"])
	normal_sb.border_width_right = int(rarity_style["border_width"])
	normal_sb.border_width_top = int(rarity_style["border_width"])
	normal_sb.border_width_bottom = int(rarity_style["border_width"])
	normal_sb.border_color = rarity_style["border"]
	normal_sb.corner_radius_top_left = 8
	normal_sb.corner_radius_top_right = 8
	normal_sb.corner_radius_bottom_left = 8
	normal_sb.corner_radius_bottom_right = 8
	btn.add_theme_stylebox_override("normal", normal_sb)

	var hover_sb := normal_sb.duplicate() as StyleBoxFlat
	hover_sb.border_color = rarity_style["hover_border"]
	hover_sb.bg_color = rarity_style["hover_bg"]
	btn.add_theme_stylebox_override("hover", hover_sb)

	var pressed_sb := normal_sb.duplicate() as StyleBoxFlat
	pressed_sb.bg_color = rarity_style["pressed_bg"]
	pressed_sb.border_color = rarity_style["hover_border"]
	btn.add_theme_stylebox_override("pressed", pressed_sb)

	var container := VBoxContainer.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(container)

	var rarity_label := Label.new()
	rarity_label.text = String(data.get("rarity_title", rarity_style["label"])).to_upper()
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_label.add_theme_font_size_override("font_size", int(rarity_style["label_font_size"]))
	rarity_label.add_theme_color_override("font_color", rarity_style["label_color"])
	container.add_child(rarity_label)

	var title_label := Label.new()
	title_label.text = _strip_rarity_suffix(String(data.get("title", data.get("id", ""))))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	title_label.custom_minimum_size = Vector2(200, 0)
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", rarity_style["title_color"])
	container.add_child(title_label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	container.add_child(spacer)

	var desc_label := Label.new()
	desc_label.text = _strip_rarity_prefix(String(data.get("desc", "")), String(data.get("rarity_title", rarity_style["label"])))
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.custom_minimum_size = Vector2(200, 0)
	desc_label.add_theme_font_size_override("font_size", 16)
	desc_label.add_theme_color_override("font_color", rarity_style["desc_color"])
	container.add_child(desc_label)

	return btn


static func _get_card_rarity_id(data: Dictionary) -> String:
	return String(data.get("rarity_id", "normal")).to_lower()


static func _get_rarity_style(rarity_id: String) -> Dictionary:
	match rarity_id:
		"silver":
			return {
				"label": "Silver",
				"bg": Color(0.17, 0.18, 0.20, 1.0),
				"hover_bg": Color(0.22, 0.24, 0.27, 1.0),
				"pressed_bg": Color(0.13, 0.14, 0.16, 1.0),
				"border": Color("aeb9c4"),
				"hover_border": Color("e4edf7"),
				"title_color": Color("dde7f0"),
				"label_color": Color("c4ced8"),
				"desc_color": Color("d6dde5"),
				"border_width": 3,
				"label_font_size": 14,
			}
		"gold":
			return {
				"label": "Gold",
				"bg": Color(0.23, 0.18, 0.09, 1.0),
				"hover_bg": Color(0.29, 0.23, 0.11, 1.0),
				"pressed_bg": Color(0.18, 0.13, 0.06, 1.0),
				"border": Color("f0c75e"),
				"hover_border": Color("ffe28a"),
				"title_color": Color("ffd76a"),
				"label_color": Color("f8d987"),
				"desc_color": Color("f3e2b7"),
				"border_width": 4,
				"label_font_size": 16,
			}
		"platinum":
			return {
				"label": "Platinum",
				"bg": Color(0.14, 0.15, 0.24, 1.0),
				"hover_bg": Color(0.18, 0.19, 0.31, 1.0),
				"pressed_bg": Color(0.10, 0.11, 0.18, 1.0),
				"border": Color("b9f3ff"),
				"hover_border": Color("e6c7ff"),
				"title_color": Color("d7f8ff"),
				"label_color": Color("d6c2ff"),
				"desc_color": Color("e4ecff"),
				"border_width": 4,
				"label_font_size": 16,
			}
		_:
			return {
				"label": "Normal",
				"bg": Color(0.15, 0.18, 0.22, 1.0),
				"hover_bg": Color(0.20, 0.24, 0.28, 1.0),
				"pressed_bg": Color(0.11, 0.13, 0.16, 1.0),
				"border": Color("4b5c73"),
				"hover_border": Color("f0d984"),
				"title_color": Color("68e08d"),
				"label_color": Color("b8c2d1"),
				"desc_color": Color("d8dde4"),
				"border_width": 2,
				"label_font_size": 14,
			}


static func _strip_rarity_suffix(title: String) -> String:
	for suffix in [" [Normal]", " [Silver]", " [Gold]", " [Platinum]"]:
		if title.ends_with(suffix):
			return title.substr(0, title.length() - suffix.length())
	return title


static func _strip_rarity_prefix(desc: String, rarity_title: String) -> String:
	var prefix := rarity_title + "\n"
	if desc.begins_with(prefix):
		return desc.substr(prefix.length())
	return desc


func _on_card_selected(card_id: String, rarity_id: String = "normal") -> void:
	# TODO: Play rarity-specific level-up sounds when audio assets are available.
	GameState.apply_level_up_card(card_id, rarity_id)
	get_tree().paused = false
	queue_free()

	if GameState.player_current_xp >= GameState.player_next_level_xp:
		GameState.level_up_ready.emit()
