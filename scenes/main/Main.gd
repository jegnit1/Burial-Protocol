extends Node2D

const FALLING_BLOCK_SCENE := preload("res://scenes/blocks/FallingBlock.tscn")
const GOLD_POPUP_SCRIPT := preload("res://scenes/ui/GoldPopup.gd")
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

# Day 상태
var _current_day := 1
var _day_time_remaining := 0.0
# Day 30 보스 블록 추적 (보스가 처치/모래화 조건으로 클리어 판정에 사용)
var _day30_boss_alive := false


func _ready() -> void:
	GameConstants.ensure_input_actions()
	GameState.reset_run()
	rng.randomize()
	_configure_camera()
	sand_field.setup(world_grid)
	player.setup(world_grid, sand_field, blocks_root)
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
	if Input.is_action_just_pressed("ui_toggle_status"):
		hud.toggle_debug_panel()
	var attack_direction := player.consume_attack_direction()
	if attack_direction != Vector2.ZERO:
		_handle_attack_action(attack_direction)
	if run_finished:
		return
	var mine_direction := player.consume_mining_direction()
	if mine_direction != Vector2.ZERO:
		_handle_mining_action(mine_direction)
	# Day 타이머
	_day_time_remaining -= delta
	GameState.day_time_remaining = _day_time_remaining
	if _day_time_remaining <= 0.0:
		_on_day_timer_expired()
		if run_finished:
			return
	sand_field.step_simulation(player.get_body_rect())
	_check_run_end_conditions()
	if run_finished:
		return
	_update_camera_y()
	_refresh_debug()


func _on_spawn_timer_timeout() -> void:
	if run_finished:
		return
	var base_definition = GameData.pick_block_base_definition(rng)
	if base_definition == null:
		return
	var type_definition = GameData.pick_block_type_definition_or_none(rng)
	var day_definition = GameData.get_day_definition(_current_day)
	var difficulty_definition := GameConstants.get_difficulty_definition(GameState.current_run_difficulty_id)
	var block_data := BlockData.from_spawn_selection(
		base_definition,
		type_definition,
		day_definition,
		difficulty_definition
	)
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
	var hit_once: Dictionary = {}
	for result in results:
		var block := result["collider"] as FallingBlock
		if block != null and not hit_once.has(block):
			hit_once[block] = true
			block.apply_damage(GameConstants.PLAYER_ATTACK_DAMAGE + GameState.run_bonus_attack_damage)
			hit_count += 1
	if hit_count > 0:
		GameState.set_status_text(Locale.ltr("status_attack_hit") % hit_count)
	else:
		GameState.set_status_text(Locale.ltr("status_attack_miss"))


func _handle_mining_action(direction: Vector2) -> void:
	var mining_direction := player.get_mining_direction(direction)
	if mining_direction == Vector2.ZERO:
		GameState.set_status_text(Locale.ltr("status_mine_blocked"))
		return
	var mining_shape_data := player.get_mining_shape_data(mining_direction)
	var final_mining_damage := GameConstants.PLAYER_MINING_DAMAGE + GameState.run_bonus_mining_damage
	var sand_result: Dictionary = sand_field.try_mine_in_shape(mining_shape_data, final_mining_damage)
	var wall_result: Dictionary = world_grid.try_mine_in_shape(mining_shape_data, final_mining_damage)
	var sand_hits := int(sand_result["hit_count"])
	var sand_removed := int(sand_result["removed_count"])
	var wall_hits := int(wall_result["hit_count"])
	var wall_removed := int(wall_result["removed_count"])
	if sand_hits > 0 or wall_hits > 0:
		var status_parts: Array[String] = []
		if sand_hits > 0:
			status_parts.append(Locale.ltr("status_mine_sand") % [sand_hits, sand_removed])
		if wall_hits > 0:
			status_parts.append(Locale.ltr("status_mine_wall") % [wall_hits, wall_removed])
		var status_text := status_parts[0]
		for index in range(1, status_parts.size()):
			status_text += " " + status_parts[index]
		if sand_removed > 0:
			GameState.add_xp(GameConstants.get_sand_xp(sand_removed))
		GameState.set_status_text(status_text)
		return
	GameState.set_status_text(Locale.ltr("status_mine_nothing"))


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


# ---- Day 시스템 ----

func _on_day_timer_expired() -> void:
	if _current_day >= GameData.get_total_days():
		# Day 30 종료: 보스가 아직 처치/처리되지 않았다면 실패
		if not GameState.run_cleared:
			_finish_temporary_run("time_limit", Locale.ltr("run_time_limit"))
		return
	# Days 1-29 종료: 다음 Day로 진행
	# TODO: 상인/키오스크 등장 및 상점 UI 구현
	_advance_to_next_day()


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
	var boss_base_definition = GameData.get_boss_block_base_definition(_current_day)
	if boss_base_definition == null:
		return
	var boss_type_definition = GameData.get_boss_block_type_definition(_current_day)
	var day_definition = GameData.get_day_definition(_current_day)
	var difficulty_definition := GameConstants.get_difficulty_definition(GameState.current_run_difficulty_id)
	var block_data := BlockData.from_spawn_selection(
		boss_base_definition,
		boss_type_definition,
		day_definition,
		difficulty_definition
	)
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
	# 보스가 모래화됐을 때: 체력이 남아 있고 무게 한계 미초과 시 클리어 (스펙 6-6)
	var surviving := GameState.player_health > 0 and sand_field.get_sand_count() < GameConstants.WEIGHT_LIMIT_SAND_CELLS
	if surviving:
		GameState.run_cleared = true
		GameState.current_run_stage_reached = _current_day
		_finish_temporary_run("cleared", Locale.ltr("run_day30_clear"))




# ---- 기존 유틸 ----

func _refresh_debug() -> void:
	# Day 정보는 항상 갱신 (게임플레이 UI)
	hud.set_day_info(
		_current_day,
		GameData.get_total_days(),
		_day_time_remaining,
		GameData.get_day_type(_current_day),
		GameState.current_run_difficulty_name
	)
	
	if hud.has_method("update_sensors"):
		hud.update_sensors(player, blocks_root, sand_field, world_camera, GameConstants.WEIGHT_LIMIT_SAND_CELLS)
		
	# 디버그 패널이 꺼져 있으면 데이터 수집 자체를 생략
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
	if sand_field.get_sand_count() >= GameConstants.WEIGHT_LIMIT_SAND_CELLS:
		_finish_temporary_run("weight_overload", Locale.ltr("run_weight_overload"))


func _finish_temporary_run(reason_id: String = "run_end", reason_label: String = "Run Ended") -> void:
	if run_finished:
		return
	run_finished = true
	spawn_timer.stop()
	GameState.finish_temporary_run(reason_id, reason_label)
	get_tree().change_scene_to_file("res://scenes/ui/Result.tscn")

# ---- UI 커스텀 ----

func _show_level_up_ui() -> void:
	if get_tree().paused:
		return # 이미 일시중지(레벨업 팝업 중) 일 경우 방지
	get_tree().paused = true
	var LevelUpUIScript = load("res://scenes/ui/LevelUpUI.gd")
	if LevelUpUIScript:
		var level_ui = LevelUpUIScript.new()
		$".".add_child(level_ui) # Main 트리에 추가하여 표시
