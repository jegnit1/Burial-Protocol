extends Node2D

const FALLING_BLOCK_SCENE := preload("res://scenes/blocks/FallingBlock.tscn")
const GOLD_POPUP_SCRIPT := preload("res://scenes/ui/GoldPopup.gd")
const DAY_KIOSK_SCRIPT := preload("res://scenes/world/DayKiosk.gd")
const DAY_SHOP_UI_SCRIPT := preload("res://scenes/ui/DayShopUI.gd")
const PAUSE_MENU_SCRIPT := preload("res://scenes/ui/PauseMenu.gd")
const CAMERA_PLAYER_Y_OFFSET := 110.0

@onready var world_grid: WorldGrid = $WorldGrid
@onready var sand_field: SandField = $SandField
@onready var player: Player = $Player
@onready var blocks_root: Node2D = $Blocks
@onready var hud: HUD = $HUD
@onready var world_camera: Camera2D = $WorldCamera
@onready var spawn_timer: Timer = $SpawnTimer

var rng := RandomNumberGenerator.new()
var last_spawned_block_debug := "Spawn Base -"
var last_spawned_column := -1
var run_finished := false

# Day 진행과 상점 전환 상태를 최소 범위로 분리한다.
var _is_day_active := true
var _is_intermission := false
var _is_intermission_locked := false
var _is_next_day_transitioning := false
var _shop_ui_open := false
var _intermission_elapsed := 0.0
var _day_kiosk: Node2D
var _day_shop_ui
var _fade_overlay: ColorRect
var _last_transition_sand_report := ""
var _waiting_for_day_kiosk := false
var _kiosk_spawn_delay_remaining := -1.0
var _pending_wall_reset_for_next_day := false
var _pause_menu: CanvasLayer
var _player_regen_accumulator := 0.0
var _current_shop_item_ids := PackedStringArray()
var _has_shop_inventory_for_intermission := false
var _last_mining_idle_status_text := ""
var _last_mining_idle_status_time := -INF

var _current_day := 1
var _day_time_remaining := 0.0
var _day30_boss_alive := false


func _ready() -> void:
	GameConstants.ensure_input_actions()
	GameState.reset_run()
	rng.randomize()
	_configure_camera()
	sand_field.setup(world_grid)
	player.setup(world_grid, sand_field, blocks_root)
	_ensure_fade_overlay()
	_current_day = 1
	_day_time_remaining = GameData.get_day_duration(_current_day)
	GameState.current_day = _current_day
	GameState.level_up_ready.connect(_show_level_up_ui)
	_apply_day_spawn_interval()
	spawn_timer.start()
	if GameData.is_boss_day(_current_day):
		_spawn_boss_block()
	_refresh_debug()


func _physics_process(delta: float) -> void:
	if run_finished:
		return
	if Input.is_action_just_pressed("restart"):
		_finish_temporary_run("run_end", Locale.ltr("run_end_label"))
		return
	if Input.is_action_just_pressed("pause_menu"):
		_toggle_pause_menu()
		return
	if Input.is_action_just_pressed("ui_toggle_status"):
		hud.toggle_debug_panel()

	if _is_intermission:
		_update_intermission(delta)

	if not _shop_ui_open and not _is_next_day_transitioning:
		var attack_direction := player.consume_attack_direction()
		if attack_direction != Vector2.ZERO:
			_handle_attack_action(attack_direction)

	if run_finished:
		return

	if not _shop_ui_open and not _is_next_day_transitioning and not _is_intermission_locked:
		var mine_direction := player.consume_mining_direction()
		if mine_direction != Vector2.ZERO:
			_handle_mining_action(mine_direction)
	elif player.consume_mining_direction() != Vector2.ZERO and _is_intermission_locked:
		GameState.set_status_text("상점 단계에서는 채굴이 정지됩니다.")

	if _is_day_active:
		_day_time_remaining -= delta
	_update_player_regen(delta)
	GameState.day_time_remaining = _day_time_remaining
	if _is_day_active and _day_time_remaining <= 0.0:
		_on_day_timer_expired()
		if run_finished:
			return

	if not _is_next_day_transitioning:
		sand_field.step_simulation(player.get_body_rect())

	if _is_intermission and not _shop_ui_open and not _is_next_day_transitioning:
		_update_day_kiosk_prompt()
		if Input.is_action_just_pressed("interact_action") and _is_player_near_day_kiosk():
			_open_day_shop()

	_check_run_end_conditions()
	if run_finished:
		return

	_update_camera_y()
	_refresh_debug()


func _on_spawn_timer_timeout() -> void:
	if run_finished or not _is_day_active or _is_intermission or _is_next_day_transitioning:
		return
	var type_definition = GameData.pick_block_type_definition_or_none(rng)
	var resolved_definition = GameData.resolve_random_block_definition(
		rng,
		StringName(GameState.current_run_difficulty_id),
		_current_day,
		type_definition
	)
	if resolved_definition == null:
		return
	var block_data := BlockData.from_resolved_definition(resolved_definition)
	var camera_top_y := world_camera.position.y - float(GameConstants.VIEWPORT_SIZE.y) * 0.5
	var spawn_position := _pick_fair_spawn_position(block_data.size_cells, camera_top_y)
	last_spawned_column = int((spawn_position.x - float(GameConstants.WORLD_ORIGIN.x)) / float(GameConstants.CELL_SIZE))
	var block := FALLING_BLOCK_SCENE.instantiate() as FallingBlock
	blocks_root.add_child(block)
	block.setup(block_data, spawn_position, world_grid, sand_field, player)
	block.destroyed.connect(_on_block_destroyed)
	block.decomposed.connect(_on_block_decomposed)
	last_spawned_block_debug = "Spawn %s | %s" % [block_data.display_name, block_data.get_block_base_debug_text()]


func _handle_attack_action(direction: Vector2) -> void:
	var attack_shape_data := player.get_attack_shape_data(direction)
	var attack_shape := RectangleShape2D.new()
	attack_shape.size = attack_shape_data["size"]
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = attack_shape
	query.transform = Transform2D(attack_shape_data["rotation"], attack_shape_data["center"])
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = 1
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var results: Array[Dictionary] = space_state.intersect_shape(query, 32)
	var hit_count := 0
	var crit_count := 0
	var hit_once: Dictionary = {}
	for result in results:
		var block := result["collider"] as FallingBlock
		if block != null and not hit_once.has(block):
			hit_once[block] = true
			var is_critical := rng.randf() < GameState.get_critical_chance_ratio()
			var damage := GameState.get_attack_damage()
			if is_critical:
				damage = int(round(float(damage) * GameState.get_critical_damage_multiplier()))
				crit_count += 1
			block.apply_damage(damage, is_critical)
			hit_count += 1
	if hit_count > 0:
		var status_text := Locale.ltr("status_attack_hit") % hit_count
		if crit_count > 0:
			status_text += " CRIT x%d" % crit_count
		GameState.set_status_text(status_text)
	else:
		GameState.set_status_text(Locale.ltr("status_attack_miss"))


func _handle_mining_action(direction: Vector2) -> void:
	var mining_direction := player.get_mining_direction(direction)
	if mining_direction == Vector2.ZERO:
		_set_mining_idle_status(Locale.ltr("status_mine_blocked"))
		return
	var mining_shape_data := player.get_mining_shape_data(mining_direction)
	var final_mining_damage := GameState.get_mining_damage()
	var sand_result: Dictionary = sand_field.try_mine_in_shape(mining_shape_data, final_mining_damage)
	var sand_hits := int(sand_result["hit_count"])
	var sand_removed := int(sand_result["removed_count"])
	if sand_hits > 0:
		if sand_removed > 0:
			GameState.add_xp(GameConstants.get_sand_xp(sand_removed))
		GameState.set_status_text(Locale.ltr("status_mine_sand") % [sand_hits, sand_removed])
		return
	var wall_result: Dictionary = world_grid.try_mine_in_shape(mining_shape_data, final_mining_damage)
	var wall_hits := int(wall_result["hit_count"])
	var wall_removed := int(wall_result["removed_count"])
	if wall_hits > 0:
		GameState.set_status_text(Locale.ltr("status_mine_wall") % [wall_hits, wall_removed])
		return
	_set_mining_idle_status(Locale.ltr("status_mine_nothing"))


func _on_block_destroyed(block: FallingBlock) -> void:
	var reward := block.block_data.reward
	var spawn_pos := block.global_position
	var xp_amount := GameConstants.get_block_xp(int(block.block_data.size_cells.x), int(block.block_data.size_cells.y))
	GameState.add_xp(xp_amount)
	GameState.add_gold(reward)
	GameState.set_status_text(Locale.ltr("status_block_destroyed") % reward)
	_spawn_gold_popup(spawn_pos, reward)


func _spawn_gold_popup(spawn_pos: Vector2, amount: int) -> void:
	var popup := GOLD_POPUP_SCRIPT.new() as Node2D
	blocks_root.add_child(popup)
	popup.global_position = spawn_pos
	popup.call("setup", amount)


func _on_block_decomposed(block: FallingBlock, reason: StringName) -> void:
	sand_field.spawn_from_block(block.get_block_rect(), block.block_data)
	if reason == "player_crush":
		GameState.set_status_text(Locale.ltr("status_player_crushed"))
	else:
		GameState.set_status_text(Locale.ltr("status_block_decomposed"))


func _on_day_timer_expired() -> void:
	if _current_day >= GameData.get_total_days():
		if not GameState.run_cleared:
			_finish_temporary_run("time_limit", Locale.ltr("run_time_limit"))
		return
	_enter_intermission()


func _advance_to_next_day() -> void:
	_current_day += 1
	_day_time_remaining = GameData.get_day_duration(_current_day)
	GameState.current_day = _current_day
	GameState.current_run_stage_reached = _current_day
	_apply_day_spawn_interval()
	if GameData.is_boss_day(_current_day):
		_spawn_boss_block()
	GameState.set_status_text(Locale.ltr("run_day_start") % _current_day)


func _apply_day_spawn_interval() -> void:
	spawn_timer.wait_time = GameConstants.BLOCK_SPAWN_INTERVAL * GameData.get_spawn_interval_multiplier(_current_day)


func _spawn_boss_block() -> void:
	var boss_material_definition = GameData.get_boss_block_base_definition(_current_day)
	var boss_size_definition = GameData.get_boss_block_size_definition(_current_day)
	if boss_material_definition == null or boss_size_definition == null:
		return
	var boss_type_definition = GameData.get_boss_block_type_definition(_current_day)
	var resolved_definition = GameData.resolve_specific_block_definition(
		boss_material_definition.material_id,
		boss_size_definition.size_id,
		StringName(GameState.current_run_difficulty_id),
		_current_day,
		boss_type_definition,
	)
	if resolved_definition == null:
		push_warning("Boss block could not be resolved for day %d." % _current_day)
		return
	var block_data := BlockData.from_resolved_definition(resolved_definition)
	var camera_top_y := world_camera.position.y - float(GameConstants.VIEWPORT_SIZE.y) * 0.5
	var spawn_position := _pick_fair_spawn_position(block_data.size_cells, camera_top_y)
	var block := FALLING_BLOCK_SCENE.instantiate() as FallingBlock
	blocks_root.add_child(block)
	block.setup(block_data, spawn_position, world_grid, sand_field, player)
	block.destroyed.connect(_on_block_destroyed)
	block.decomposed.connect(_on_block_decomposed)
	if _current_day == GameData.get_total_days():
		_day30_boss_alive = true
		block.destroyed.connect(_on_day30_boss_destroyed)
		block.decomposed.connect(_on_day30_boss_decomposed)
	last_spawned_block_debug = "Boss Spawn | %s" % block_data.get_block_base_debug_text()


func _on_day30_boss_destroyed(_block: FallingBlock) -> void:
	if run_finished:
		return
	_day30_boss_alive = false
	GameState.run_cleared = true
	GameState.current_run_stage_reached = _current_day
	_finish_temporary_run("cleared", Locale.ltr("run_day30_clear"))


func _on_day30_boss_decomposed(_block: FallingBlock, _reason: StringName) -> void:
	if run_finished:
		return
	_day30_boss_alive = false
	var surviving := GameState.player_health > 0 and sand_field.get_sand_count() < GameState.get_weight_limit_sand_cells()
	if surviving:
		GameState.run_cleared = true
		GameState.current_run_stage_reached = _current_day
		_finish_temporary_run("cleared", Locale.ltr("run_day30_clear"))


func _enter_intermission() -> void:
	if _is_intermission or _is_next_day_transitioning:
		return
	_is_day_active = false
	_is_intermission = true
	_is_intermission_locked = false
	_intermission_elapsed = 0.0
	_shop_ui_open = false
	_waiting_for_day_kiosk = true
	_kiosk_spawn_delay_remaining = -1.0
	_current_shop_item_ids = PackedStringArray()
	_has_shop_inventory_for_intermission = false
	_day_time_remaining = 0.0
	GameState.day_time_remaining = 0.0
	spawn_timer.stop()
	GameState.set_status_text("Day 종료. 키오스크와 상호작용해 다음 날로 이동하세요.")


func _update_intermission(delta: float) -> void:
	_update_day_kiosk_deployment(delta)
	if _is_intermission_locked:
		return
	_intermission_elapsed += delta
	if _intermission_elapsed >= GameConstants.DAY_INTERMISSION_GRACE_DURATION:
		_is_intermission_locked = true
		GameState.set_status_text("유예 시간이 끝났습니다. 채굴만 정지되고 모래 반응은 유지됩니다.")


func _spawn_day_kiosk() -> void:
	if _day_kiosk != null and is_instance_valid(_day_kiosk):
		return
	_waiting_for_day_kiosk = false
	_kiosk_spawn_delay_remaining = -1.0
	_day_kiosk = DAY_KIOSK_SCRIPT.new() as Node2D
	add_child(_day_kiosk)
	var center_rect := GameConstants.get_center_rect()
	var camera_top_y := world_camera.position.y - float(GameConstants.VIEWPORT_SIZE.y) * 0.5
	var spawn_position := Vector2(
		center_rect.position.x + center_rect.size.x * 0.5,
		camera_top_y - 96.0
	)
	if _day_kiosk.has_method("setup"):
		_day_kiosk.call("setup", world_grid, sand_field, blocks_root, spawn_position)
	else:
		_day_kiosk.global_position = spawn_position
	_update_day_kiosk_prompt()


func _update_day_kiosk_prompt() -> void:
	if _day_kiosk == null or not is_instance_valid(_day_kiosk):
		return
	var kiosk_ready := true
	if _day_kiosk.has_method("is_interactable"):
		kiosk_ready = bool(_day_kiosk.call("is_interactable"))
	var can_interact := kiosk_ready and _is_player_near_day_kiosk() and not _shop_ui_open and not _is_next_day_transitioning
	if _day_kiosk.has_method("set_interaction_available"):
		_day_kiosk.call("set_interaction_available", can_interact)


func _despawn_day_kiosk() -> void:
	_waiting_for_day_kiosk = false
	_kiosk_spawn_delay_remaining = -1.0
	if _day_kiosk == null or not is_instance_valid(_day_kiosk):
		return
	_day_kiosk.queue_free()
	_day_kiosk = null


func _is_player_near_day_kiosk() -> bool:
	if _day_kiosk == null or not is_instance_valid(_day_kiosk):
		return false
	if _day_kiosk.has_method("is_interactable") and not bool(_day_kiosk.call("is_interactable")):
		return false
	return player.global_position.distance_to(_day_kiosk.global_position) <= GameConstants.DAY_KIOSK_INTERACTION_RANGE


func _open_day_shop() -> void:
	if _shop_ui_open or _is_next_day_transitioning:
		return
	if not _has_shop_inventory_for_intermission:
		_current_shop_item_ids = GameData.roll_shop_item_ids(
			rng,
			GameConstants.DAY_SHOP_ITEM_COUNT,
			GameState.get_shop_roll_context()
		)
		_has_shop_inventory_for_intermission = true
	_day_shop_ui = DAY_SHOP_UI_SCRIPT.new()
	add_child(_day_shop_ui)
	if _day_shop_ui.has_method("set_shop_item_ids"):
		_day_shop_ui.call("set_shop_item_ids", _current_shop_item_ids)
	_day_shop_ui.next_day_requested.connect(_request_next_day_transition)
	_day_shop_ui.closed.connect(_on_day_shop_closed)
	if _day_shop_ui.has_signal("item_purchased"):
		_day_shop_ui.item_purchased.connect(_on_day_shop_item_purchased)
	_shop_ui_open = true
	_update_day_kiosk_prompt()
	GameState.set_status_text("상점 화면이 열렸습니다. Next Day 버튼으로 다음 날을 시작할 수 있습니다.")


func _close_day_shop() -> void:
	if _day_shop_ui == null or not is_instance_valid(_day_shop_ui):
		_day_shop_ui = null
		_shop_ui_open = false
		return
	_day_shop_ui.queue_free()
	_day_shop_ui = null
	_shop_ui_open = false
	_update_day_kiosk_prompt()


func _on_day_shop_closed() -> void:
	_day_shop_ui = null
	_shop_ui_open = false
	_update_day_kiosk_prompt()


func _set_mining_idle_status(text: String) -> void:
	var now := Time.get_ticks_msec() * 0.001
	if text == _last_mining_idle_status_text:
		if now - _last_mining_idle_status_time < GameConstants.PLAYER_MINING_STATUS_MESSAGE_INTERVAL:
			return
	_last_mining_idle_status_text = text
	_last_mining_idle_status_time = now
	GameState.set_status_text(text)
	GameState.set_status_text("상점을 닫았습니다. 키오스크에서 다시 열 수 있습니다.")


func _on_day_shop_item_purchased(item_id: StringName) -> void:
	# 같은 상점 단계에서는 구매한 상품을 메인 보관 목록에서도 제거해 재등장을 막는다.
	var item_key := String(item_id)
	if not _current_shop_item_ids.has(item_key):
		return
	var remaining_ids := PackedStringArray()
	for raw_item_id in _current_shop_item_ids:
		if raw_item_id == item_key:
			continue
		remaining_ids.append(raw_item_id)
	_current_shop_item_ids = remaining_ids


func _request_next_day_transition() -> void:
	if _is_next_day_transitioning:
		return
	_start_next_day_transition()


func _start_next_day_transition() -> void:
	_is_next_day_transitioning = true
	_close_day_shop()
	_despawn_day_kiosk()
	await _play_fade(1.0, GameConstants.DAY_TRANSITION_FADE_DURATION)
	_apply_next_day_interest()
	_apply_pending_wall_reset_for_next_day()
	_is_intermission = false
	_is_intermission_locked = false
	_intermission_elapsed = 0.0
	_is_day_active = true
	_advance_to_next_day()
	spawn_timer.start()
	await _play_fade(0.0, GameConstants.DAY_TRANSITION_FADE_DURATION)
	_is_next_day_transitioning = false


func queue_wall_reset_for_next_day() -> void:
	# TODO: 특정 상점 구매가 확정되면 이 훅을 호출해 다음 Day 전환에서만 벽을 복구한다.
	_pending_wall_reset_for_next_day = true


func _apply_pending_wall_reset_for_next_day() -> void:
	if not _pending_wall_reset_for_next_day:
		_last_transition_sand_report = "skipped(reset=false)"
		return
	_pending_wall_reset_for_next_day = false
	_restore_side_walls_preserving_sand()


func _restore_side_walls_preserving_sand() -> void:
	var sand_before := sand_field.get_sand_count()
	var wall_rects = world_grid.get_wall_restore_rects()
	var extracted_cells = sand_field.extract_sand_cells_in_rects(wall_rects)
	var collected_count := extracted_cells.size()
	var sand_after_extract := sand_field.get_sand_count()
	world_grid.restore_mining_walls()
	var blocked_rects := _collect_transition_blocking_rects()
	var placed_count := sand_field.redistribute_sand_cells_to_center(extracted_cells, blocked_rects)
	if placed_count < extracted_cells.size():
		var remaining_cells: Array = []
		for index in range(placed_count, extracted_cells.size()):
			remaining_cells.append(extracted_cells[index])
		placed_count += sand_field.redistribute_sand_cells_to_center(remaining_cells)
	var sand_after := sand_field.get_sand_count()
	var expected_after_extract := sand_before - collected_count
	var expected_after := expected_after_extract + placed_count
	_last_transition_sand_report = "before=%d collected=%d after_extract=%d reapplied=%d after=%d" % [
		sand_before,
		collected_count,
		sand_after_extract,
		placed_count,
		sand_after,
	]
	print("DayTransitionSandReport ", _last_transition_sand_report)
	if sand_after_extract != expected_after_extract:
		push_error("Day transition sand extraction mismatch: expected=%s actual=%s | %s" % [
			expected_after_extract,
			sand_after_extract,
			_last_transition_sand_report,
		])
	if sand_after != expected_after:
		push_error("Day transition sand reapply mismatch: expected=%s actual=%s | %s" % [
			expected_after,
			sand_after,
			_last_transition_sand_report,
		])
	if sand_before != sand_after or placed_count != collected_count:
		push_error("Day transition sand preservation mismatch | %s" % _last_transition_sand_report)


func _update_day_kiosk_deployment(delta: float) -> void:
	if not _waiting_for_day_kiosk or _is_next_day_transitioning:
		return
	if _day_kiosk != null and is_instance_valid(_day_kiosk):
		_waiting_for_day_kiosk = false
		return
	if _get_active_block_count() > 0:
		return
	if _kiosk_spawn_delay_remaining < 0.0:
		_kiosk_spawn_delay_remaining = GameConstants.DAY_KIOSK_DEPLOY_DELAY
		GameState.set_status_text("마지막 블록 정리 완료. 키오스크 투하를 준비합니다.")
		return
	_kiosk_spawn_delay_remaining = max(_kiosk_spawn_delay_remaining - delta, 0.0)
	if _kiosk_spawn_delay_remaining > 0.0:
		return
	_spawn_day_kiosk()
	GameState.set_status_text("키오스크가 투하되었습니다. 안착 후 상호작용할 수 있습니다.")


func _get_active_block_count() -> int:
	var active_count := 0
	for child in blocks_root.get_children():
		var block := child as FallingBlock
		if block != null and block.active:
			active_count += 1
	return active_count


func _collect_transition_blocking_rects() -> Array[Rect2]:
	var blocked_rects: Array[Rect2] = [player.get_body_rect()]
	for child in blocks_root.get_children():
		var block := child as FallingBlock
		if block != null and block.active:
			blocked_rects.append(block.get_block_rect())
	return blocked_rects


func _ensure_fade_overlay() -> void:
	if _fade_overlay != null:
		return
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 100
	add_child(fade_layer)
	_fade_overlay = ColorRect.new()
	_fade_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	fade_layer.add_child(_fade_overlay)


func _toggle_pause_menu() -> void:
	if _shop_ui_open:
		_close_day_shop()
		GameState.set_status_text("?곸젏???レ븯?듬땲?? ?ㅼ삤?ㅽ겕?먯꽌 ?ㅼ떆 ?????덉뒿?덈떎.")
		return
	if _is_next_day_transitioning or run_finished:
		return
	if _pause_menu != null and is_instance_valid(_pause_menu):
		_close_pause_menu()
		return
	_open_pause_menu()


func _open_pause_menu() -> void:
	if _pause_menu != null and is_instance_valid(_pause_menu):
		return
	_pause_menu = PAUSE_MENU_SCRIPT.new()
	add_child(_pause_menu)
	if _pause_menu.has_signal("closed"):
		_pause_menu.closed.connect(_on_pause_menu_closed)
	get_tree().paused = true


func _close_pause_menu() -> void:
	if _pause_menu == null or not is_instance_valid(_pause_menu):
		_pause_menu = null
		get_tree().paused = false
		return
	get_tree().paused = false
	_pause_menu.queue_free()
	_pause_menu = null


func _on_pause_menu_closed() -> void:
	_pause_menu = null


func _update_player_regen(delta: float) -> void:
	if _shop_ui_open or _is_next_day_transitioning:
		return
	if GameState.player_health <= 0 or GameState.player_health >= GameState.get_player_max_health():
		return
	var regen_interval := GameState.get_hp_regen_interval()
	if not is_finite(regen_interval) or regen_interval <= 0.0:
		return
	_player_regen_accumulator += delta
	while _player_regen_accumulator >= regen_interval:
		_player_regen_accumulator -= regen_interval
		if GameState.player_health >= GameState.get_player_max_health():
			break
		GameState.heal_player(1)


func _apply_next_day_interest() -> void:
	var interest_amount := GameState.calculate_interest_payout()
	if interest_amount <= 0:
		return
	GameState.add_gold(interest_amount)


func _play_fade(target_alpha: float, duration: float) -> void:
	if _fade_overlay == null:
		return
	var tween := create_tween()
	tween.tween_property(_fade_overlay, "color:a", target_alpha, duration)
	await tween.finished


func _refresh_debug() -> void:
	hud.set_day_info(
		_current_day,
		GameData.get_total_days(),
		_day_time_remaining,
		GameData.get_day_type(_current_day),
		GameState.current_run_difficulty_name
	)
	if hud.has_method("update_sensors"):
		hud.update_sensors(player, blocks_root, sand_field, world_camera, GameState.get_weight_limit_sand_cells())
	if not hud.is_debug_visible():
		return
	hud.set_runtime_debug(
		blocks_root.get_child_count(),
		sand_field.get_sand_count(),
		world_grid.get_active_wall_count(),
		PackedStringArray([
			player.get_dash_debug_text(),
			last_spawned_block_debug,
		])
	)


func _configure_camera() -> void:
	world_camera.zoom = Vector2.ONE
	world_camera.position_smoothing_enabled = false
	world_camera.limit_left = GameConstants.WORLD_ORIGIN.x
	world_camera.limit_right = GameConstants.WORLD_ORIGIN.x + GameConstants.WORLD_PIXEL_WIDTH
	world_camera.limit_top = GameConstants.WORLD_ORIGIN.y
	world_camera.limit_bottom = GameConstants.WORLD_ORIGIN.y + GameConstants.WORLD_PIXEL_HEIGHT
	world_camera.position = Vector2(
		float(GameConstants.WORLD_ORIGIN.x) + float(GameConstants.WORLD_PIXEL_WIDTH) * 0.5,
		player.position.y - CAMERA_PLAYER_Y_OFFSET
	)


func _update_camera_y() -> void:
	world_camera.position.y = player.position.y - CAMERA_PLAYER_Y_OFFSET


func _pick_fair_spawn_position(size_cells: Vector2i, camera_top_y: float) -> Vector2:
	var min_col := GameConstants.WALL_COLUMNS
	var max_col := GameConstants.WORLD_COLUMNS - GameConstants.WALL_COLUMNS - size_cells.x
	var spawn_y := camera_top_y - float(GameConstants.CELL_SIZE) * 3.0 - float(size_cells.y) * float(GameConstants.CELL_SIZE) * 0.5
	for attempt in range(8):
		var col := rng.randi_range(min_col, max_col)
		if attempt == 0 and last_spawned_column >= 0 and max_col > min_col:
			var tries := 0
			while col == last_spawned_column and tries < 4:
				col = rng.randi_range(min_col, max_col)
				tries += 1
		var spawn_x := float(GameConstants.WORLD_ORIGIN.x) + (float(col) + float(size_cells.x) * 0.5) * float(GameConstants.CELL_SIZE)
		var spawn_pos := Vector2(spawn_x, spawn_y)
		var half_size := Vector2(size_cells) * float(GameConstants.CELL_SIZE) * 0.5
		var spawn_rect := Rect2(spawn_pos - half_size, half_size * 2.0)
		if player != null and spawn_rect.intersects(player.get_body_rect()):
			continue
		if _spawn_rect_overlaps_active_block(spawn_rect):
			continue
		return spawn_pos
	var col := rng.randi_range(min_col, max_col)
	var spawn_x := float(GameConstants.WORLD_ORIGIN.x) + (float(col) + float(size_cells.x) * 0.5) * float(GameConstants.CELL_SIZE)
	return Vector2(spawn_x, spawn_y)


func _spawn_rect_overlaps_active_block(rect: Rect2) -> bool:
	for child in blocks_root.get_children():
		var block := child as FallingBlock
		if block != null and block.active and block.get_block_rect().intersects(rect):
			return true
	return false


func _check_run_end_conditions() -> void:
	if GameState.player_health <= 0:
		_finish_temporary_run("health_depletion", Locale.ltr("run_health_depleted"))
		return
	if sand_field.get_sand_count() >= GameState.get_weight_limit_sand_cells():
		_finish_temporary_run("weight_overload", Locale.ltr("run_weight_overload"))


func _finish_temporary_run(reason_id: String = "run_end", reason_label: String = "Run Ended") -> void:
	if run_finished:
		return
	run_finished = true
	spawn_timer.stop()
	GameState.finish_temporary_run(reason_id, reason_label)
	get_tree().change_scene_to_file("res://scenes/ui/Result.tscn")


func _show_level_up_ui() -> void:
	if get_tree().paused:
		return
	get_tree().paused = true
	var level_up_ui_script = load("res://scenes/ui/LevelUpUI.gd")
	if level_up_ui_script:
		var level_ui = level_up_ui_script.new()
		add_child(level_ui)
