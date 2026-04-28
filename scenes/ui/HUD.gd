extends CanvasLayer
class_name HUD

# 좌측 상단 - Stage Progress HUD
var day_label: Label
var difficulty_label: Label
var next_boss_label: Label
var time_label: Label
var time_bar: ProgressBar

# 좌측 중앙 - Seismic / Fall Sensor HUD
class SeismicSensorDraw extends Control:
	var player: Node2D
	var blocks_root: Node2D
	var sand_field: Node2D
	var camera: Camera2D
	var max_sand: float = float(GameConstants.WEIGHT_LIMIT_SAND_CELLS)
		
	func _draw() -> void:
		if not player or not blocks_root or not sand_field or not camera:
			return
		
		# Define mapping from world Y to local Y
		# Show a zoom area: 2 screens above camera (for falling blocks) and 1 screen below.
		var world_bottom := float(GameConstants.WORLD_ORIGIN.y + GameConstants.WORLD_PIXEL_HEIGHT)
		var w_min_y := float(GameConstants.WORLD_ORIGIN.y)
		var w_max_y := world_bottom
		if camera:
			var view_size = Vector2(GameConstants.VIEWPORT_SIZE) / camera.zoom
			w_min_y = camera.global_position.y - view_size.y * 2.0
			w_max_y = camera.global_position.y + view_size.y * 1.0
			
			if w_max_y > world_bottom:
				var overshot = w_max_y - world_bottom
				w_max_y = world_bottom
				w_min_y -= overshot
			
		var w_height := w_max_y - w_min_y
		if w_height <= 0.0: return
		
		# Define mapping from world X to local X: ONLY CENTER COMBAT AREA (10U)
		var c_min_x := float(GameConstants.WORLD_ORIGIN.x + GameConstants.WALL_COLUMNS * GameConstants.CELL_SIZE)
		var c_width := float(GameConstants.CENTER_COLUMNS * GameConstants.CELL_SIZE)
		if c_width <= 0.0: return
		
		var panel_w := size.x
		var panel_h := size.y
		

		# Draw Viewport Box
		if camera:
			# Just an approximation of viewport local height
			var view_size = Vector2(GameConstants.VIEWPORT_SIZE) / camera.zoom
			var cy = camera.global_position.y
			var c_top = cy - view_size.y * 0.5
			var c_bottom = cy + view_size.y * 0.5
			var start_p = (c_top - w_min_y) / w_height
			var end_p = (c_bottom - w_min_y) / w_height
			var vp_y1 = clampf(start_p * panel_h, 0.0, panel_h)
			var vp_y2 = clampf(end_p * panel_h, 0.0, panel_h)
			var vp_rect = Rect2(2, vp_y1, panel_w - 4, vp_y2 - vp_y1)
			draw_rect(vp_rect, Color(0.9, 0.8, 0.2, 0.4), false, 2.0)
		
		# Draw active blocks
		if blocks_root:
			for child in blocks_root.get_children():
				if not child.get("active"):
					continue
				var block_pos = child.global_position
				var block_p = (block_pos.y - w_min_y) / w_height
				var bl_y = clampf(block_p * panel_h, 0.0, panel_h)
				
				var block_rect: Rect2
				if child.has_method("get_block_rect"):
					block_rect = child.get_block_rect()
				else:
					continue
					
				# X ratio mapped exactly to the 10U center area
				var block_px = (block_rect.position.x - c_min_x) / c_width
				var bl_x = block_px * panel_w
				
				# Width mapped exactly to the 10U center area width
				var bl_pw = (block_rect.size.x / c_width) * panel_w
				
				var bl_rect_ui = Rect2(bl_x, bl_y - 4, bl_pw, 8)
				
				var bl_color = Color(0.7, 0.2, 0.2, 0.8) # default danger color
				if "block_data" in child and child.block_data != null:
					if "color" in child.block_data:
						bl_color = child.block_data.color
						
				draw_rect(bl_rect_ui, bl_color)
				
		# Draw Player
		if player:
			var p_y = (player.global_position.y - w_min_y) / w_height
			var py_local = clampf(p_y * panel_h, 0.0, panel_h)
			var p_x = (player.global_position.x - c_min_x) / c_width
			var px_local = clampf(p_x * panel_w, 0.0, panel_w)
			var p_center = Vector2(px_local, py_local)
			draw_circle(p_center, 6.0, Color(0.8, 1.0, 0.9, 1.0))
			draw_circle(p_center, 8.0, Color(0.5, 1.0, 0.8, 0.6)) # Glow

var sensor_draw: SeismicSensorDraw

# 좌측 하단 - Player Status HUD
var status_level_label: Label
var status_hp_label: Label
var status_hp_bar: ProgressBar
var status_battery_label: Label
var status_battery_bar: ProgressBar
var status_xp_label: Label
var status_xp_bar: ProgressBar

# 우측 상단 - Economy / Weight HUD
var econ_gold_label: Label
var econ_day_gold_label: Label
var econ_weight_label: Label
var econ_weight_bar: ProgressBar
var econ_weight_status_label: Label

var debug_label: Label

var _tracked_player: Node2D
var _skill_slot_views: Array[Dictionary] = []
var _last_day_number := 0
var _day_start_gold := 0
var _current_weight := 0
var _max_weight := GameState.get_weight_limit_sand_cells()

func _ready() -> void:
	_build_layout()
	GameState.gold_changed.connect(_on_gold_changed)
	GameState.health_changed.connect(_on_health_changed)
	GameState.status_text_changed.connect(_on_status_text_changed)
	GameState.xp_changed.connect(_on_xp_changed)
	GameState.level_changed.connect(_on_level_changed)
	_day_start_gold = GameState.gold
	_on_gold_changed(GameState.gold)
	_on_health_changed(GameState.player_health, GameConstants.PLAYER_MAX_HEALTH)
	_update_battery_ui()
	_on_status_text_changed(GameState.status_text)
	_on_xp_changed(GameState.player_current_xp, GameState.player_next_level_xp)
	_on_level_changed(GameState.player_level)
	_update_skill_ui()
	

func toggle_debug_panel() -> void:
	if debug_label != null:
		debug_label.visible = not debug_label.visible

func is_debug_visible() -> bool:
	return debug_label != null and debug_label.visible

func set_runtime_debug(block_count: int, sand_count: int, wall_count: int, extra_lines: PackedStringArray = PackedStringArray()) -> void:
	if debug_label == null:
		return
	var debug_lines: PackedStringArray = PackedStringArray([
		Locale.ltr("hud_debug_counts") % [block_count, sand_count, wall_count]
	])
	for line in extra_lines:
		debug_lines.append(line)
	debug_label.text = "\n".join(debug_lines)

func update_sensors(p_player: Node2D, p_blocks: Node2D, p_sand: Node2D, p_camera: Camera2D, p_max_weight: int) -> void:
	_tracked_player = p_player
	if sensor_draw:
		sensor_draw.player = p_player
		sensor_draw.blocks_root = p_blocks
		sensor_draw.sand_field = p_sand
		sensor_draw.camera = p_camera
		sensor_draw.max_sand = float(p_max_weight)
		sensor_draw.queue_redraw()
	
	_max_weight = p_max_weight
	if p_sand and p_sand.has_method("get_sand_count"):
		_current_weight = p_sand.get_sand_count()
	
	_update_weight_ui()
	_update_battery_ui()
	_update_skill_ui()

func set_day_info(day_number: int, total_days: int, time_remaining: float, _day_type: StringName, difficulty_name: String) -> void:
	if _last_day_number != day_number:
		_last_day_number = day_number
		_day_start_gold = GameState.gold
		_update_gold_ui()
	
	if day_label:
		day_label.text = "%02d / %02d" % [day_number, total_days]
	
	if difficulty_label:
		difficulty_label.text = difficulty_name
		
	if next_boss_label:
		var next_boss := GameData.get_next_boss_day(day_number)
		if next_boss != -1:
			next_boss_label.text = "NEXT BOSS - D" + str(next_boss)
		else:
			next_boss_label.text = ""
	
	if time_label:
		var secs = floor(time_remaining)
		var mins = floor(secs / 60)
		secs = int(secs) % 60
		
		var max_secs = floor(GameData.get_day_duration(day_number))
		var max_mins = floor(max_secs / 60)
		max_secs = int(max_secs) % 60
		
		time_label.text = "%02d:%02d / %02d:%02d" % [mins, secs, max_mins, max_secs]
	
	if time_bar:
		time_bar.max_value = GameData.get_day_duration(day_number)
		time_bar.value = time_remaining
		
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color("cda85e")
		if time_remaining <= 10.0:
			sb.bg_color = Color("d45858")
		time_bar.add_theme_stylebox_override("fill", sb)

func _on_gold_changed(_value: int) -> void:
	_update_gold_ui()

func _update_gold_ui() -> void:
	if not econ_gold_label: return
	econ_gold_label.text = str(GameState.gold)
	var day_earned = GameState.gold - _day_start_gold
	if day_earned > 0:
		econ_day_gold_label.text = "THIS DAY +" + str(day_earned)
	else:
		econ_day_gold_label.text = "THIS DAY " + str(day_earned)

func _on_health_changed(current: int, maximum: int) -> void:
	if status_hp_label:
		status_hp_label.text = str(current) + " / " + str(maximum)
	if status_hp_bar:
		status_hp_bar.max_value = maximum
		status_hp_bar.value = current
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color("68e08d")
		if float(current) / float(maximum) <= 0.3:
			sb.bg_color = Color("e06868")
		status_hp_bar.add_theme_stylebox_override("fill", sb)


# Player가 직접 소유한 배터리를 일반 HUD에서 즉시 읽어 표시한다.
func _update_battery_ui() -> void:
	var maximum := GameConstants.PLAYER_BATTERY_MAX
	var current := maximum
	if _tracked_player != null:
		maximum = _tracked_player.get_max_battery()
		current = _tracked_player.get_current_battery()
	if status_battery_label:
		status_battery_label.text = "%.0f / %.0f" % [current, maximum]
	if status_battery_bar:
		status_battery_bar.max_value = maximum
		status_battery_bar.value = current
		var ratio := 0.0 if maximum <= 0.0 else current / maximum
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("69d2c0")
		if ratio <= 0.3:
			sb.bg_color = Color("d99058")
		status_battery_bar.add_theme_stylebox_override("fill", sb)

func _on_status_text_changed(_text: String) -> void:
	pass

func _on_xp_changed(current: int, next_req: int) -> void:
	if status_xp_bar:
		status_xp_bar.max_value = next_req
		status_xp_bar.value = current
	if status_xp_label:
		status_xp_label.text = str(current) + " / " + str(next_req)

func _on_level_changed(level: int) -> void:
	if status_level_label:
		status_level_label.text = "LV\n" + str(level)

func _update_weight_ui() -> void:
	if not econ_weight_label or not econ_weight_bar: return
	econ_weight_label.text = "%s / %s %s" % [
		GameConstants.format_display_weight(_current_weight),
		GameConstants.format_display_weight(_max_weight),
		GameConstants.DISPLAY_WEIGHT_UNIT,
	]
	
	econ_weight_bar.max_value = _max_weight
	econ_weight_bar.value = _current_weight
	var ratio = float(_current_weight) / float(_max_weight)
	var sb = StyleBoxFlat.new()
	if ratio < 0.5:
		sb.bg_color = Color("85ad63")
		econ_weight_status_label.text = "SAFE"
		econ_weight_status_label.add_theme_color_override("font_color", Color("85ad63"))
	elif ratio < 0.8:
		sb.bg_color = Color("d1b74c")
		econ_weight_status_label.text = "SLOW"
		econ_weight_status_label.add_theme_color_override("font_color", Color("d1b74c"))
	elif ratio < 0.95:
		sb.bg_color = Color("d17a4c")
		econ_weight_status_label.text = "CRUSH"
		econ_weight_status_label.add_theme_color_override("font_color", Color("d17a4c"))
	else:
		sb.bg_color = Color("d45858")
		if Time.get_ticks_msec() % 500 < 250:
			econ_weight_status_label.text = "CRUSH!"
		else:
			econ_weight_status_label.text = "      "
		econ_weight_status_label.add_theme_color_override("font_color", Color("d45858"))
	econ_weight_bar.add_theme_stylebox_override("fill", sb)


func _update_skill_ui() -> void:
	if _skill_slot_views.is_empty():
		return
	var dash_remaining := 0.0
	var dash_duration := GameConstants.PLAYER_DASH_COOLDOWN
	var dash_ready := false
	if _tracked_player != null:
		dash_remaining = _tracked_player.get_dash_cooldown_remaining()
		dash_duration = _tracked_player.get_dash_cooldown_duration()
		dash_ready = _tracked_player.can_dash()
	_apply_skill_slot_state(0, "D", "DASH", "Z", dash_remaining, dash_duration, dash_ready, true)
	_apply_skill_slot_state(1, "2", "EMPTY", "", 0.0, 1.0, false, false)
	_apply_skill_slot_state(2, "3", "EMPTY", "", 0.0, 1.0, false, false)


func _apply_skill_slot_state(
	index: int,
	icon_text: String,
	name_text: String,
	hint_text: String,
	cooldown_remaining: float,
	_cooldown_duration: float,
	is_ready: bool,
	is_active_slot: bool
) -> void:
	if index < 0 or index >= _skill_slot_views.size():
		return
	var slot := _skill_slot_views[index]
	var panel := slot["panel"] as Panel
	var icon_label := slot["icon"] as Label
	var name_label := slot["name"] as Label
	var hint_label := slot["hint"] as Label
	var overlay := slot["overlay"] as ColorRect
	var cooldown_label := slot["cooldown"] as Label
	icon_label.text = icon_text
	name_label.text = name_text
	hint_label.text = hint_text
	if not is_active_slot:
		panel.add_theme_stylebox_override("panel", _make_skill_slot_style(Color(0.05, 0.07, 0.10, 0.72), Color("39424d")))
		icon_label.add_theme_color_override("font_color", Color("6c7683"))
		name_label.add_theme_color_override("font_color", Color("73808d"))
		hint_label.add_theme_color_override("font_color", Color("5f6975"))
		overlay.visible = true
		overlay.color = Color(0.02, 0.03, 0.05, 0.50)
		cooldown_label.visible = false
		return
	var on_cooldown := cooldown_remaining > 0.0
	var border_color := Color("7ed0c8") if is_ready else Color("5e6977")
	panel.add_theme_stylebox_override("panel", _make_skill_slot_style(Color(0.08, 0.11, 0.15, 0.90), border_color))
	icon_label.add_theme_color_override("font_color", Color("f1f5f8") if is_ready else Color("aab4bf"))
	name_label.add_theme_color_override("font_color", Color("dfe7ee"))
	hint_label.add_theme_color_override("font_color", Color("8aa6c0"))
	overlay.visible = on_cooldown
	overlay.color = Color(0.0, 0.0, 0.0, 0.58)
	cooldown_label.visible = on_cooldown
	if on_cooldown:
		cooldown_label.text = "%.1f" % cooldown_remaining


func _make_skill_slot_style(background_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = border_color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	return style


func _create_skill_slot(icon_text: String, name_text: String, hint_text: String) -> Panel:
	var slot_panel := Panel.new()
	slot_panel.custom_minimum_size = Vector2(80, 88)
	slot_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot_panel.add_theme_stylebox_override("panel", _make_skill_slot_style(Color(0.08, 0.11, 0.15, 0.90), Color("5e6977")))

	var content_margin := MarginContainer.new()
	content_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	content_margin.add_theme_constant_override("margin_left", 8)
	content_margin.add_theme_constant_override("margin_top", 6)
	content_margin.add_theme_constant_override("margin_right", 8)
	content_margin.add_theme_constant_override("margin_bottom", 6)
	content_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot_panel.add_child(content_margin)

	var content_vbox := VBoxContainer.new()
	content_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	content_vbox.add_theme_constant_override("separation", 2)
	content_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_margin.add_child(content_vbox)

	var icon_label := Label.new()
	icon_label.text = icon_text
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", 24)
	content_vbox.add_child(icon_label)

	var name_label := Label.new()
	name_label.text = name_text
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 13)
	content_vbox.add_child(name_label)

	var hint_label := Label.new()
	hint_label.text = hint_text
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 12)
	content_vbox.add_child(hint_label)

	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.58)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.visible = false
	slot_panel.add_child(overlay)

	var cooldown_label := Label.new()
	cooldown_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	cooldown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cooldown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cooldown_label.add_theme_font_size_override("font_size", 18)
	cooldown_label.add_theme_color_override("font_color", Color("f4f6f8"))
	cooldown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cooldown_label.visible = false
	slot_panel.add_child(cooldown_label)

	_skill_slot_views.append({
		"panel": slot_panel,
		"icon": icon_label,
		"name": name_label,
		"hint": hint_label,
		"overlay": overlay,
		"cooldown": cooldown_label,
	})
	return slot_panel


func _build_layout() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", GameConstants.HUD_SIDE_PADDING)
	margin.add_theme_constant_override("margin_top", GameConstants.HUD_TOP_PADDING)
	margin.add_theme_constant_override("margin_right", GameConstants.HUD_SIDE_PADDING)
	margin.add_theme_constant_override("margin_bottom", GameConstants.HUD_TOP_PADDING)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(margin)

	# ==========================================
	# Top Left: Stage Progress HUD
	# ==========================================
	var top_left_panel := VBoxContainer.new()
	top_left_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	top_left_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top_left_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(top_left_panel)
	
	var row1 := HBoxContainer.new()
	top_left_panel.add_child(row1)
	
	var day_lbl_title := Label.new()
	day_lbl_title.text = "CURRENT DAY"
	day_lbl_title.add_theme_font_size_override("font_size", 18)
	day_lbl_title.add_theme_color_override("font_color", Color("a28956"))
	top_left_panel.add_child(day_lbl_title)
	
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 12)
	top_left_panel.add_child(row2)
	
	day_label = Label.new()
	day_label.add_theme_font_size_override("font_size", 46)
	day_label.add_theme_color_override("font_color", Color("e5c687"))
	row2.add_child(day_label)
	
	difficulty_label = Label.new()
	difficulty_label.add_theme_font_size_override("font_size", 21)
	difficulty_label.add_theme_color_override("font_color", Color("8a95a5"))
	var diff_margin := MarginContainer.new()
	diff_margin.add_theme_constant_override("margin_top", 20)
	diff_margin.add_child(difficulty_label)
	row2.add_child(diff_margin)
	
	next_boss_label = Label.new()
	next_boss_label.add_theme_font_size_override("font_size", 18)
	next_boss_label.add_theme_color_override("font_color", Color("c87474"))
	top_left_panel.add_child(next_boss_label)
	
	var time_lbl_title := Label.new()
	time_lbl_title.text = "TIME REMAINING"
	time_lbl_title.add_theme_font_size_override("font_size", 16)
	var time_spacing := MarginContainer.new()
	time_spacing.add_theme_constant_override("margin_top", 8)
	time_spacing.add_child(time_lbl_title)
	top_left_panel.add_child(time_spacing)
	
	var time_row := HBoxContainer.new()
	time_row.add_theme_constant_override("separation", 10)
	top_left_panel.add_child(time_row)
	
	time_bar = ProgressBar.new()
	time_bar.custom_minimum_size = Vector2(176, 18)
	time_bar.show_percentage = false
	var time_bg = StyleBoxFlat.new()
	time_bg.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	time_bar.add_theme_stylebox_override("background", time_bg)
	time_row.add_child(time_bar)
	
	time_label = Label.new()
	time_label.add_theme_font_size_override("font_size", 18)
	time_row.add_child(time_label)

	# ==========================================
	# Top Right: Economy / Weight HUD
	# ==========================================
	var top_right_panel := VBoxContainer.new()
	top_right_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	top_right_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top_right_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(top_right_panel)
	
	var gold_title_row := HBoxContainer.new()
	gold_title_row.add_theme_constant_override("separation", 12)
	top_right_panel.add_child(gold_title_row)
	
	var gold_lbl_title := Label.new()
	gold_lbl_title.text = "GOLD"
	gold_lbl_title.add_theme_font_size_override("font_size", 18)
	gold_lbl_title.add_theme_color_override("font_color", Color("d7b94d"))
	gold_title_row.add_child(gold_lbl_title)
	
	econ_day_gold_label = Label.new()
	econ_day_gold_label.add_theme_font_size_override("font_size", 16)
	econ_day_gold_label.add_theme_color_override("font_color", Color("9ab184"))
	var day_gold_margin = MarginContainer.new()
	day_gold_margin.add_theme_constant_override("margin_top", 2)
	day_gold_margin.add_child(econ_day_gold_label)
	gold_title_row.add_child(day_gold_margin)
	
	econ_gold_label = Label.new()
	econ_gold_label.add_theme_font_size_override("font_size", 36)
	econ_gold_label.add_theme_color_override("font_color", Color("f0d984"))
	top_right_panel.add_child(econ_gold_label)
	
	var weight_spacing := MarginContainer.new()
	weight_spacing.add_theme_constant_override("margin_top", 12)
	var weight_title_row := HBoxContainer.new()
	weight_title_row.add_theme_constant_override("separation", 10)
	weight_spacing.add_child(weight_title_row)
	top_right_panel.add_child(weight_spacing)
	
	var weight_lbl_title := Label.new()
	weight_lbl_title.text = "WEIGHT LOAD"
	weight_lbl_title.add_theme_font_size_override("font_size", 16)
	weight_lbl_title.add_theme_color_override("font_color", Color("a2a7b0"))
	weight_title_row.add_child(weight_lbl_title)
	
	econ_weight_label = Label.new()
	econ_weight_label.add_theme_font_size_override("font_size", 16)
	weight_title_row.add_child(econ_weight_label)
	
	var wbar_row = HBoxContainer.new()
	wbar_row.add_theme_constant_override("separation", 8)
	top_right_panel.add_child(wbar_row)
	
	econ_weight_bar = ProgressBar.new()
	econ_weight_bar.custom_minimum_size = Vector2(210, 20)
	econ_weight_bar.show_percentage = false
	var wbg = StyleBoxFlat.new()
	wbg.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	econ_weight_bar.add_theme_stylebox_override("background", wbg)
	wbar_row.add_child(econ_weight_bar)
	
	econ_weight_status_label = Label.new()
	econ_weight_status_label.add_theme_font_size_override("font_size", 16)
	wbar_row.add_child(econ_weight_status_label)
	
	# ==========================================
	# Bottom Left: Player Status HUD
	# ==========================================
	var bottom_left_panel := VBoxContainer.new()
	bottom_left_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	bottom_left_panel.size_flags_vertical = Control.SIZE_SHRINK_END
	bottom_left_panel.add_theme_constant_override("separation", 8)
	bottom_left_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(bottom_left_panel)
	
	var pstat_row := HBoxContainer.new()
	pstat_row.add_theme_constant_override("separation", 12)
	bottom_left_panel.add_child(pstat_row)
	
	# Level box
	var lv_panel := PanelContainer.new()
	var lv_sb := StyleBoxFlat.new()
	lv_sb.bg_color = Color(0.15, 0.18, 0.22, 0.9)
	lv_sb.border_width_bottom = 2
	lv_sb.border_width_top = 2
	lv_sb.border_width_left = 2
	lv_sb.border_width_right = 2
	lv_sb.border_color = Color("4b5c73")
	lv_panel.add_theme_stylebox_override("panel", lv_sb)
	pstat_row.add_child(lv_panel)
	
	var lv_margin := MarginContainer.new()
	lv_margin.add_theme_constant_override("margin_left", 10)
	lv_margin.add_theme_constant_override("margin_right", 10)
	lv_margin.add_theme_constant_override("margin_top", 12)
	lv_margin.add_theme_constant_override("margin_bottom", 12)
	lv_panel.add_child(lv_margin)
	
	status_level_label = Label.new()
	status_level_label.text = "LV\nTODO"
	status_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_level_label.add_theme_font_size_override("font_size", 18)
	lv_margin.add_child(status_level_label)
	
	var bars_vbox := VBoxContainer.new()
	bars_vbox.add_theme_constant_override("separation", 6)
	bars_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	pstat_row.add_child(bars_vbox)
	
	# HP
	var hp_row := HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 8)
	bars_vbox.add_child(hp_row)
	
	var hp_title := Label.new()
	hp_title.text = "HP"
	hp_title.custom_minimum_size = Vector2(28, 0)
	hp_title.add_theme_color_override("font_color", Color("68e08d"))
	hp_title.add_theme_font_size_override("font_size", 16)
	hp_row.add_child(hp_title)
	
	status_hp_bar = ProgressBar.new()
	status_hp_bar.custom_minimum_size = Vector2(170, 18)
	status_hp_bar.show_percentage = false
	var hp_bg = StyleBoxFlat.new()
	hp_bg.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	status_hp_bar.add_theme_stylebox_override("background", hp_bg)
	hp_row.add_child(status_hp_bar)
	
	status_hp_label = Label.new()
	status_hp_label.add_theme_font_size_override("font_size", 16)
	hp_row.add_child(status_hp_label)

	var battery_row := HBoxContainer.new()
	battery_row.add_theme_constant_override("separation", 8)
	bars_vbox.add_child(battery_row)

	var battery_title := Label.new()
	battery_title.text = "BAT"
	battery_title.custom_minimum_size = Vector2(28, 0)
	battery_title.add_theme_color_override("font_color", Color("69d2c0"))
	battery_title.add_theme_font_size_override("font_size", 16)
	battery_row.add_child(battery_title)

	status_battery_bar = ProgressBar.new()
	status_battery_bar.custom_minimum_size = Vector2(170, 14)
	status_battery_bar.show_percentage = false
	var battery_bg = StyleBoxFlat.new()
	battery_bg.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	status_battery_bar.add_theme_stylebox_override("background", battery_bg)
	battery_row.add_child(status_battery_bar)

	status_battery_label = Label.new()
	status_battery_label.add_theme_font_size_override("font_size", 14)
	battery_row.add_child(status_battery_label)
	
	# XP
	var xp_row := HBoxContainer.new()
	xp_row.add_theme_constant_override("separation", 8)
	bars_vbox.add_child(xp_row)
	
	var xp_title := Label.new()
	xp_title.text = "XP"
	xp_title.custom_minimum_size = Vector2(28, 0)
	xp_title.add_theme_color_override("font_color", Color("5fb2d1"))
	xp_title.add_theme_font_size_override("font_size", 16)
	xp_row.add_child(xp_title)
	
	status_xp_bar = ProgressBar.new()
	status_xp_bar.custom_minimum_size = Vector2(170, 12)
	status_xp_bar.show_percentage = false
	status_xp_bar.max_value = 100
	status_xp_bar.value = 0
	var xp_bg = StyleBoxFlat.new()
	xp_bg.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	var xp_fill = StyleBoxFlat.new()
	xp_fill.bg_color = Color("5fb2d1")
	status_xp_bar.add_theme_stylebox_override("background", xp_bg)
	status_xp_bar.add_theme_stylebox_override("fill", xp_fill)
	xp_row.add_child(status_xp_bar)
	
	status_xp_label = Label.new()
	status_xp_label.text = "0 / TODO"
	status_xp_label.add_theme_font_size_override("font_size", 14)
	status_xp_label.add_theme_color_override("font_color", Color(0.7,0.7,0.7))
	xp_row.add_child(status_xp_label)

	# Debug Label
	debug_label = Label.new()
	debug_label.add_theme_font_size_override("font_size", GameConstants.HUD_DEBUG_FONT_SIZE)
	debug_label.visible = false
	bottom_left_panel.add_child(debug_label)

	# ==========================================
	# Center Left: Seismic / Fall Sensor HUD
	# ==========================================
	sensor_draw = SeismicSensorDraw.new()
	sensor_draw.custom_minimum_size = Vector2(72, 340)
	
	var sensor_margin := MarginContainer.new()
	sensor_margin.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	sensor_margin.add_theme_constant_override("margin_left", GameConstants.HUD_SIDE_PADDING)
	sensor_margin.add_theme_constant_override("margin_top", GameConstants.HUD_TOP_PADDING + 184)
	sensor_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var sensor_bg_panel := PanelContainer.new()
	sensor_bg_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var s_sb := StyleBoxFlat.new()
	s_sb.bg_color = Color(0.06, 0.08, 0.1, 0.7)
	s_sb.border_width_left = 1
	s_sb.border_width_right = 1
	s_sb.border_width_top = 1
	s_sb.border_width_bottom = 1
	s_sb.border_color = Color("2d3b4a")
	sensor_bg_panel.add_theme_stylebox_override("panel", s_sb)
	
	sensor_bg_panel.add_child(sensor_draw)
	sensor_margin.add_child(sensor_bg_panel)
	root.add_child(sensor_margin)

	var skill_bar_anchor := MarginContainer.new()
	skill_bar_anchor.anchor_left = 1.0
	skill_bar_anchor.anchor_top = 1.0
	skill_bar_anchor.anchor_right = 1.0
	skill_bar_anchor.anchor_bottom = 1.0
	skill_bar_anchor.offset_left = -(GameConstants.HUD_SIDE_PADDING + 272.0)
	skill_bar_anchor.offset_top = -(GameConstants.HUD_TOP_PADDING + 100.0)
	skill_bar_anchor.offset_right = -GameConstants.HUD_SIDE_PADDING
	skill_bar_anchor.offset_bottom = -GameConstants.HUD_TOP_PADDING
	skill_bar_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(skill_bar_anchor)

	var skill_bar := HBoxContainer.new()
	skill_bar.alignment = BoxContainer.ALIGNMENT_END
	skill_bar.add_theme_constant_override("separation", 10)
	skill_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skill_bar_anchor.add_child(skill_bar)

	skill_bar.add_child(_create_skill_slot("D", "DASH", "Z"))
	skill_bar.add_child(_create_skill_slot("2", "EMPTY", ""))
	skill_bar.add_child(_create_skill_slot("3", "EMPTY", ""))
