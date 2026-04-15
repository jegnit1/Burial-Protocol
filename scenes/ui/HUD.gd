extends CanvasLayer
class_name HUD

var gold_label: Label
var health_label: Label
var status_label: Label
var debug_label: Label


func _ready() -> void:
	_build_layout()
	GameState.gold_changed.connect(_on_gold_changed)
	GameState.health_changed.connect(_on_health_changed)
	GameState.status_text_changed.connect(_on_status_text_changed)
	_on_gold_changed(GameState.gold)
	_on_health_changed(GameState.player_health, GameConstants.PLAYER_MAX_HEALTH)
	_on_status_text_changed(GameState.status_text)


func set_runtime_debug(block_count: int, sand_count: int, wall_count: int) -> void:
	if debug_label == null:
		return
	debug_label.text = "Blocks %d | Sand %d | Wall %d" % [block_count, sand_count, wall_count]


func toggle_debug_panel() -> void:
	if debug_label != null:
		debug_label.visible = not debug_label.visible


func _build_layout() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	panel.offset_left = float(GameConstants.HUD_SIDE_PADDING)
	panel.offset_top = float(GameConstants.HUD_TOP_PADDING)
	panel.offset_right = -float(GameConstants.HUD_SIDE_PADDING)
	panel.offset_bottom = float(GameConstants.HUD_TOP_PADDING + GameConstants.HUD_HEIGHT)
	root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", GameConstants.HUD_INNER_MARGIN)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", GameConstants.HUD_INNER_MARGIN)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", GameConstants.HUD_SECTION_SPACING)
	margin.add_child(column)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", GameConstants.HUD_ROW_SPACING)
	column.add_child(top_row)

	gold_label = Label.new()
	health_label = Label.new()
	gold_label.add_theme_font_size_override("font_size", GameConstants.HUD_PRIMARY_FONT_SIZE)
	health_label.add_theme_font_size_override("font_size", GameConstants.HUD_PRIMARY_FONT_SIZE)
	top_row.add_child(gold_label)
	top_row.add_child(health_label)

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", GameConstants.HUD_SECONDARY_FONT_SIZE)
	column.add_child(status_label)

	debug_label = Label.new()
	debug_label.add_theme_font_size_override("font_size", GameConstants.HUD_DEBUG_FONT_SIZE)
	column.add_child(debug_label)


func _on_gold_changed(value: int) -> void:
	gold_label.text = "Gold %d" % value


func _on_health_changed(current: int, maximum: int) -> void:
	health_label.text = "Health %d / %d" % [current, maximum]


func _on_status_text_changed(text: String) -> void:
	status_label.text = text
