extends Node2D

const FALLING_BLOCK_SCENE := preload("res://scenes/blocks/FallingBlock.tscn")
const CAMERA_PLAYER_Y_OFFSET := 110.0
const TEMPORARY_WEIGHT_LIMIT_SAND_CELLS := 240

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


func _ready() -> void:
	GameConstants.ensure_input_actions()
	GameState.reset_run()
	rng.randomize()
	_configure_camera()
	sand_field.setup(world_grid)
	player.setup(world_grid, sand_field, blocks_root)
	spawn_timer.wait_time = GameConstants.BLOCK_SPAWN_INTERVAL
	spawn_timer.start()
	_refresh_debug()


func _physics_process(_delta: float) -> void:
	if run_finished:
		return
	if Input.is_action_just_pressed("restart"):
		_finish_temporary_run("run_end", "Run Ended")
		return
	if Input.is_action_just_pressed("ui_toggle_status"):
		hud.toggle_debug_panel()
	var attack_direction := player.consume_attack_direction()
	if attack_direction != Vector2.ZERO:
		_handle_attack_action(attack_direction)
	var mine_direction := player.consume_mining_direction()
	if mine_direction != Vector2.ZERO:
		_handle_mining_action(mine_direction)
	sand_field.step_simulation(player.get_body_rect())
	_check_run_end_conditions()
	if run_finished:
		return
	_update_camera_y()
	_refresh_debug()


func _on_spawn_timer_timeout() -> void:
	if run_finished:
		return
	var definition := GameConstants.pick_block_type_definition(rng)
	var block_data := BlockData.from_definition(definition)
	var camera_top_y := world_camera.position.y - float(GameConstants.VIEWPORT_SIZE.y) * 0.5
	var spawn_position := _pick_fair_spawn_position(block_data.size_cells, camera_top_y)
	last_spawned_column = int((spawn_position.x - float(GameConstants.WORLD_ORIGIN.x)) / float(GameConstants.CELL_SIZE))
	var block := FALLING_BLOCK_SCENE.instantiate() as FallingBlock
	blocks_root.add_child(block)
	block.setup(block_data, spawn_position, world_grid, sand_field, player)
	block.destroyed.connect(_on_block_destroyed)
	block.decomposed.connect(_on_block_decomposed)
	last_spawned_block_debug = "Spawn Base %s | %s" % [block_data.block_base_display_name, block_data.get_block_base_debug_text()]


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
			block.apply_damage(GameConstants.PLAYER_ATTACK_DAMAGE)
			hit_count += 1
	if hit_count > 0:
		GameState.set_status_text("Hit %d falling block(s)." % hit_count)
	else:
		GameState.set_status_text("The swing missed.")


func _handle_mining_action(direction: Vector2) -> void:
	var mining_direction := player.get_mining_direction(direction)
	if mining_direction == Vector2.ZERO:
		GameState.set_status_text("Can't mine in this direction.")
		return
	var mining_shape_data := player.get_mining_shape_data(mining_direction)
	var sand_result: Dictionary = sand_field.try_mine_in_shape(mining_shape_data, GameConstants.PLAYER_MINING_DAMAGE)
	var wall_result: Dictionary = world_grid.try_mine_in_shape(mining_shape_data, GameConstants.PLAYER_MINING_DAMAGE)
	var sand_hits := int(sand_result["hit_count"])
	var sand_removed := int(sand_result["removed_count"])
	var wall_hits := int(wall_result["hit_count"])
	var wall_removed := int(wall_result["removed_count"])
	if sand_hits > 0 or wall_hits > 0:
		var status_parts: Array[String] = []
		if sand_hits > 0:
			status_parts.append("Sand %d hit(s), %d removed." % [sand_hits, sand_removed])
		if wall_hits > 0:
			status_parts.append("Wall %d hit(s), %d removed." % [wall_hits, wall_removed])
		var status_text := status_parts[0]
		for index in range(1, status_parts.size()):
			status_text += " " + status_parts[index]
		GameState.set_status_text(status_text)
		return
	GameState.set_status_text("Nothing to mine here.")


func _on_block_destroyed(block: FallingBlock) -> void:
	GameState.add_gold(block.block_data.reward)
	GameState.set_status_text("Block destroyed. +%d gold." % block.block_data.reward)


func _on_block_decomposed(block: FallingBlock, reason: StringName) -> void:
	sand_field.spawn_from_block(block.get_block_rect(), block.block_data)
	if reason == "player_crush":
		GameState.set_status_text("Crushed by a falling block. Sand pressure increased.")
	else:
		GameState.set_status_text("A block broke down into sand.")


func _refresh_debug() -> void:
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
		_finish_temporary_run("health_depletion", "Health Depleted")
		return
	if sand_field.get_sand_count() >= TEMPORARY_WEIGHT_LIMIT_SAND_CELLS:
		_finish_temporary_run("weight_overload", "Weight Overload")


func _finish_temporary_run(reason_id: String = "run_end", reason_label: String = "Run Ended") -> void:
	if run_finished:
		return
	run_finished = true
	spawn_timer.stop()
	GameState.finish_temporary_run(reason_id, reason_label)
	get_tree().change_scene_to_file("res://scenes/ui/Result.tscn")
