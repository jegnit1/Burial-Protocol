extends Node2D

const FALLING_BLOCK_SCENE := preload("res://scenes/blocks/FallingBlock.tscn")

@onready var world_grid: WorldGrid = $WorldGrid
@onready var sand_field: SandField = $SandField
@onready var player: Player = $Player
@onready var blocks_root: Node2D = $Blocks
@onready var hud: HUD = $HUD
@onready var world_camera: Camera2D = $WorldCamera
@onready var spawn_timer: Timer = $SpawnTimer

var rng := RandomNumberGenerator.new()


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
	if Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()
		return
	if Input.is_action_just_pressed("ui_toggle_status"):
		hud.toggle_debug_panel()
	var action_direction := player.consume_primary_action_direction()
	if action_direction != Vector2.ZERO:
		_handle_primary_action(action_direction)
	sand_field.step_simulation(player.get_body_rect())
	_refresh_debug()


func _on_spawn_timer_timeout() -> void:
	var definition: Dictionary = GameConstants.BLOCK_TYPES[rng.randi_range(0, GameConstants.BLOCK_TYPES.size() - 1)]
	var block_data := BlockData.from_definition(definition)
	var spawn_position := world_grid.get_spawn_position(block_data.size_cells, rng)
	var block := FALLING_BLOCK_SCENE.instantiate() as FallingBlock
	blocks_root.add_child(block)
	block.setup(block_data, spawn_position, world_grid, sand_field, player)
	block.destroyed.connect(_on_block_destroyed)
	block.decomposed.connect(_on_block_decomposed)


func _handle_primary_action(direction: Vector2) -> void:
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
		return
	var mining_direction := player.get_mining_direction(direction)
	if mining_direction != Vector2i.ZERO and world_grid.try_mine_in_rect(player.get_mining_rect(mining_direction), mining_direction):
		GameState.set_status_text("Mined a wall cell to open space.")
		return
	GameState.set_status_text("The swing missed.")


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
	hud.set_runtime_debug(blocks_root.get_child_count(), sand_field.get_sand_count(), world_grid.get_active_wall_count())


func _configure_camera() -> void:
	var world_rect := GameConstants.get_world_rect()
	world_camera.zoom = _get_world_fit_zoom(world_rect)
	world_camera.limit_left = int(world_rect.position.x)
	world_camera.limit_top = int(world_rect.position.y)
	world_camera.limit_right = int(world_rect.end.x)
	world_camera.limit_bottom = int(world_rect.end.y)
	world_camera.position = world_rect.get_center()


func _get_world_fit_zoom(world_rect: Rect2) -> Vector2:
	var viewport_size := Vector2(GameConstants.VIEWPORT_SIZE)
	var zoom_x := viewport_size.x / world_rect.size.x
	var zoom_y := viewport_size.y / world_rect.size.y
	var fit_zoom := minf(zoom_x, zoom_y) * GameConstants.WORLD_CAMERA_FIT_MARGIN_RATIO
	return Vector2(fit_zoom, fit_zoom)
