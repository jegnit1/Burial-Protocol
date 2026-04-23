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
	card_container.add_theme_constant_override("separation", 32)
	card_container.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(card_container)
	
	var cards := GameConstants.LEVEL_UP_CARDS.values()
	for extra_card in GameConstants.EXTRA_LEVEL_UP_CARDS:
		cards.append(extra_card)
	cards.shuffle()
	
	for i in range(min(3, cards.size())):
		var card_data: Dictionary = cards[i]
		var btn := _create_card_button(card_data)
		btn.pressed.connect(_on_card_selected.bind(String(card_data["id"])))
		card_container.add_child(btn)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_menu"):
		get_viewport().set_input_as_handled()


func _create_card_button(data: Dictionary) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(240, 320)
	
	var normal_sb := StyleBoxFlat.new()
	normal_sb.bg_color = Color(0.15, 0.18, 0.22, 1.0)
	normal_sb.border_width_left = 2
	normal_sb.border_width_right = 2
	normal_sb.border_width_top = 2
	normal_sb.border_width_bottom = 2
	normal_sb.border_color = Color("4b5c73")
	btn.add_theme_stylebox_override("normal", normal_sb)
	
	var hover_sb := normal_sb.duplicate() as StyleBoxFlat
	hover_sb.border_color = Color("f0d984")
	hover_sb.bg_color = Color(0.20, 0.24, 0.28, 1.0)
	btn.add_theme_stylebox_override("hover", hover_sb)
	
	var container := VBoxContainer.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(container)
	
	var title_label := Label.new()
	title_label.text = String(data["title"])
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", Color("68e08d"))
	container.add_child(title_label)
	
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	container.add_child(spacer)
	
	var desc_label := Label.new()
	desc_label.text = String(data["desc"])
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.custom_minimum_size = Vector2(200, 0)
	desc_label.add_theme_font_size_override("font_size", 16)
	container.add_child(desc_label)
	
	return btn


func _on_card_selected(card_id: String) -> void:
	GameState.apply_level_up_card(card_id)
	get_tree().paused = false
	queue_free()
	
	# 초과분 XP로 인해 다시 레벨업이 가능한지 즉시 검사
	if GameState.player_current_xp >= GameState.player_next_level_xp:
		GameState.level_up_ready.emit()
