extends Node2D
class_name SandField

var world_grid: WorldGrid
var sand_cells: Dictionary = {}
var active_cells: Dictionary = {}
var flow_flip := false
var blocked_push_signature := ""
var blocked_jump_signature := ""
var blocked_jump_retry_frame := -1
var push_attempt_visited: Dictionary = {}
var push_check_budget := 0
var push_move_budget := 0
var push_origin_occupied: Dictionary = {}
var jump_attempt_visited: Dictionary = {}
var jump_check_budget := 0
var jump_move_budget := 0


func setup(target_world: WorldGrid) -> void:
	world_grid = target_world
	sand_cells.clear()
	active_cells.clear()
	blocked_push_signature = ""
	blocked_jump_signature = ""
	blocked_jump_retry_frame = -1
	push_attempt_visited.clear()
	push_origin_occupied.clear()
	jump_attempt_visited.clear()
	queue_redraw()


func rect_collides(rect: Rect2) -> bool:
	var min_cell := world_to_sand_cell(rect.position)
	var max_cell := world_to_sand_cell(rect.position + rect.size - Vector2.ONE)
	for y in range(min_cell.y, max_cell.y + 1):
		for x in range(min_cell.x, max_cell.x + 1):
			var cell := Vector2i(x, y)
			if sand_cells.has(cell) and get_sand_cell_rect(cell).intersects(rect):
				return true
	return false


func spawn_from_block(block_rect: Rect2, block_data: BlockData) -> void:
	if world_grid == null:
		return
	var spawned_any := false
	var min_cell := world_to_sand_cell(block_rect.position)
	var max_cell := world_to_sand_cell(block_rect.position + block_rect.size - Vector2.ONE)
	var spawn_columns: Array[int] = []
	for x in range(max(min_cell.x, 0), min(max_cell.x, _get_sand_columns() - 1) + 1):
		spawn_columns.append(x)
	if spawn_columns.is_empty():
		spawn_columns.append(clampi(min_cell.x, 0, _get_sand_columns() - 1))
	var spawn_row := clampi(max_cell.y, 0, _get_sand_rows() - 1)
	for index in range(block_data.sand_units):
		var column := spawn_columns[index % spawn_columns.size()]
		var offset_row := int(index / max(spawn_columns.size(), 1))
		var cell := Vector2i(column, max(spawn_row - offset_row, 0))
		while cell.y > 0 and not _can_occupy(cell):
			cell.y -= 1
		if _can_occupy(cell):
			sand_cells[cell] = SandCellData.from_block(block_data)
			_mark_active(cell, GameConstants.SAND_ACTIVE_RADIUS)
			spawned_any = true
	if spawned_any:
		blocked_push_signature = ""
		blocked_jump_signature = ""
		blocked_jump_retry_frame = -1
	queue_redraw()


func step_simulation(focus_rect: Rect2) -> void:
	if world_grid == null or sand_cells.is_empty():
		return
	_mark_active_rect(focus_rect, 1)
	if active_cells.is_empty():
		return
	flow_flip = not flow_flip
	var cells: Array[Vector2i] = []
	for key in active_cells.keys():
		var cell: Vector2i = key
		cells.append(cell)
	active_cells.clear()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.y == b.y:
			if flow_flip:
				return a.x > b.x
			return a.x < b.x
		return a.y > b.y
	)
	var moved := false
	var processed := 0
	for cell in cells:
		if processed >= GameConstants.SAND_FLOW_UPDATES_PER_TICK:
			_mark_active(cell, 0)
			continue
		if not sand_cells.has(cell):
			continue
		if _try_move_cell(cell):
			moved = true
		else:
			_update_stability_for_cell(cell)
		processed += 1
	if moved:
		queue_redraw()


func try_push_for_body(player_rect: Rect2, direction: int) -> bool:
	if world_grid == null or direction == 0:
		return false
	var push_rect := _get_push_rect(player_rect, direction)
	var push_signature := _get_push_signature(push_rect, direction)
	if push_signature == blocked_push_signature:
		return false
	var min_cell := world_to_sand_cell(push_rect.position)
	var max_cell := world_to_sand_cell(push_rect.position + push_rect.size - Vector2.ONE)
	var candidates: Array[Vector2i] = []
	for y in range(min_cell.y, max_cell.y + 1):
		for x in range(min_cell.x, max_cell.x + 1):
			var cell := Vector2i(x, y)
			if sand_cells.has(cell):
				candidates.append(cell)
	if candidates.is_empty():
		blocked_push_signature = push_signature
		return false
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.y == b.y:
			if direction > 0:
				return a.x > b.x
			return a.x < b.x
		return a.y > b.y
	)
	push_attempt_visited.clear()
	push_check_budget = GameConstants.SAND_PUSH_CHECK_LIMIT
	push_move_budget = GameConstants.SAND_PUSH_MOVE_LIMIT
	_store_push_origin_occupied(push_rect, direction)
	var moved := false
	var candidate_count := 0
	for cell in candidates:
		if candidate_count >= GameConstants.SAND_PUSH_CANDIDATE_LIMIT:
			break
		if push_check_budget <= 0 or push_move_budget <= 0:
			break
		if push_attempt_visited.has(cell):
			continue
		moved = _try_shift_chain(cell, direction, 0) or moved
		candidate_count += 1
	if moved:
		blocked_push_signature = ""
		_mark_active_rect(push_rect, 1)
		queue_redraw()
	else:
		blocked_push_signature = push_signature
	return moved


func try_clear_jump_space(player_rect: Rect2, facing_direction: int) -> bool:
	if world_grid == null:
		return false
	var clear_rect := Rect2(
		Vector2(player_rect.position.x, player_rect.position.y - GameConstants.SAND_CELL_SIZE * GameConstants.SAND_JUMP_CLEAR_HEIGHT),
		Vector2(player_rect.size.x, GameConstants.SAND_CELL_SIZE * (GameConstants.SAND_JUMP_CLEAR_HEIGHT + 1))
	)
	var jump_signature := _get_jump_signature(clear_rect, facing_direction)
	var current_frame := Engine.get_physics_frames()
	if jump_signature == blocked_jump_signature and current_frame <= blocked_jump_retry_frame:
		return false
	var min_cell := world_to_sand_cell(clear_rect.position)
	var max_cell := world_to_sand_cell(clear_rect.position + clear_rect.size - Vector2.ONE)
	var candidates: Array[Vector2i] = []
	for y in range(min_cell.y, max_cell.y + 1):
		for x in range(min_cell.x, max_cell.x + 1):
			var cell := Vector2i(x, y)
			if sand_cells.has(cell):
				candidates.append(cell)
	if candidates.is_empty():
		blocked_jump_signature = jump_signature
		blocked_jump_retry_frame = current_frame + GameConstants.SAND_JUMP_CLEAR_RETRY_DELAY_FRAMES
		return false
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.y == b.y:
			return a.x < b.x
		return a.y < b.y
	)
	jump_attempt_visited.clear()
	jump_check_budget = GameConstants.SAND_JUMP_CLEAR_CHECK_LIMIT
	jump_move_budget = GameConstants.SAND_JUMP_CLEAR_MOVE_LIMIT
	var direction := facing_direction
	if direction == 0:
		direction = 1
	var moved := false
	var candidate_count := 0
	for cell in candidates:
		if candidate_count >= GameConstants.SAND_JUMP_CLEAR_CANDIDATE_LIMIT:
			break
		if jump_check_budget <= 0 or jump_move_budget <= 0:
			break
		if jump_attempt_visited.has(cell):
			continue
		moved = _try_jump_clear(cell, direction, 0) or moved
		candidate_count += 1
	if moved:
		blocked_jump_signature = ""
		blocked_jump_retry_frame = -1
		_mark_active_rect(clear_rect, 2)
		queue_redraw()
	else:
		blocked_jump_signature = jump_signature
		blocked_jump_retry_frame = current_frame + GameConstants.SAND_JUMP_CLEAR_RETRY_DELAY_FRAMES
	return moved


func get_sand_count() -> int:
	return sand_cells.size()


func world_to_sand_cell(world_position: Vector2) -> Vector2i:
	var local_position := world_position - Vector2(GameConstants.WORLD_ORIGIN)
	return Vector2i(
		floori(local_position.x / GameConstants.SAND_CELL_SIZE),
		floori(local_position.y / GameConstants.SAND_CELL_SIZE)
	)


func sand_cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(
		GameConstants.WORLD_ORIGIN.x + cell.x * GameConstants.SAND_CELL_SIZE,
		GameConstants.WORLD_ORIGIN.y + cell.y * GameConstants.SAND_CELL_SIZE
	)


func get_sand_cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(sand_cell_to_world(cell), Vector2.ONE * GameConstants.SAND_CELL_SIZE)


func _try_shift_chain(cell: Vector2i, direction: int, depth: int) -> bool:
	if not sand_cells.has(cell):
		return false
	if depth > GameConstants.SAND_PUSH_CHAIN_LIMIT:
		return false
	if push_check_budget <= 0 or push_move_budget <= 0:
		return false
	if push_attempt_visited.has(cell):
		return false
	push_attempt_visited[cell] = true
	push_check_budget -= 1
	var forward := cell + Vector2i(direction, 0)
	if _can_accept_push_target(forward):
		_move_cell(cell, forward)
		return true
	if sand_cells.has(forward) and _try_shift_chain(forward, direction, depth + 1):
		_move_cell(cell, forward)
		return true
	var diagonal_up := cell + Vector2i(direction, -GameConstants.SAND_PUSH_UPWARD_BIAS)
	if _can_accept_push_target(diagonal_up):
		_move_cell(cell, diagonal_up)
		return true
	if sand_cells.has(diagonal_up) and _try_shift_chain(diagonal_up, direction, depth + 1):
		_move_cell(cell, diagonal_up)
		return true
	return false


func _try_jump_clear(cell: Vector2i, direction: int, depth: int) -> bool:
	if not sand_cells.has(cell):
		return false
	if depth > GameConstants.SAND_PUSH_CHAIN_LIMIT:
		return false
	if jump_check_budget <= 0 or jump_move_budget <= 0:
		return false
	if jump_attempt_visited.has(cell):
		return false
	jump_attempt_visited[cell] = true
	jump_check_budget -= 1
	var targets := [
		cell + Vector2i(0, -GameConstants.SAND_PUSH_UPWARD_BIAS),
		cell + Vector2i(direction, -GameConstants.SAND_PUSH_UPWARD_BIAS),
		cell + Vector2i(-direction, -GameConstants.SAND_PUSH_UPWARD_BIAS),
		cell + Vector2i(direction, 0),
		cell + Vector2i(-direction, 0),
	]
	for target in targets:
		if _can_occupy(target):
			_move_cell(cell, target)
			return true
		if sand_cells.has(target) and _try_jump_clear(target, direction, depth + 1):
			_move_cell(cell, target)
			return true
	return false


func _try_move_cell(cell: Vector2i) -> bool:
	var down := cell + Vector2i.DOWN
	if _can_occupy(down):
		_move_cell(cell, down)
		return true
	var side_order := [Vector2i.LEFT, Vector2i.RIGHT]
	if flow_flip:
		side_order.reverse()
	for side in side_order:
		var diagonal := cell + Vector2i(side.x, 1)
		if _can_occupy(diagonal) and _can_occupy(cell + side):
			_move_cell(cell, diagonal)
			return true
	return false


func _move_cell(from_cell: Vector2i, to_cell: Vector2i) -> void:
	sand_cells[to_cell] = sand_cells[from_cell]
	sand_cells.erase(from_cell)
	if push_move_budget > 0:
		push_move_budget -= 1
	if jump_move_budget > 0:
		jump_move_budget -= 1
	blocked_push_signature = ""
	blocked_jump_signature = ""
	blocked_jump_retry_frame = -1
	_mark_active(from_cell, 1)
	_mark_active(to_cell, 1)
	_update_stability_for_cell(to_cell)
	_update_stability_for_cell(from_cell + Vector2i.UP)


func _can_occupy(cell: Vector2i) -> bool:
	if _is_static_blocked(cell):
		return false
	return not sand_cells.has(cell)


func _update_stability_for_cell(cell: Vector2i) -> void:
	if not sand_cells.has(cell):
		return
	var below: Vector2i = cell + Vector2i.DOWN
	sand_cells[cell].stable = _is_static_blocked(below) or sand_cells.has(below)


func _mark_active(cell: Vector2i, radius: int) -> void:
	for y in range(cell.y - radius, cell.y + radius + 1):
		for x in range(cell.x - radius, cell.x + radius + 1):
			active_cells[Vector2i(x, y)] = true


func _mark_active_rect(rect: Rect2, radius: int) -> void:
	var min_cell := world_to_sand_cell(rect.position)
	var max_cell := world_to_sand_cell(rect.position + rect.size - Vector2.ONE)
	for y in range(min_cell.y - radius, max_cell.y + radius + 1):
		for x in range(min_cell.x - radius, max_cell.x + radius + 1):
			active_cells[Vector2i(x, y)] = true


func _is_static_blocked(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.x >= _get_sand_columns():
		return true
	if cell.y >= _get_sand_rows():
		return true
	if cell.y < 0:
		return false
	return world_grid.rect_collides_static(get_sand_cell_rect(cell))


func _get_sand_columns() -> int:
	return int((GameConstants.WORLD_COLUMNS * GameConstants.CELL_SIZE) / GameConstants.SAND_CELL_SIZE)


func _get_sand_rows() -> int:
	return int((GameConstants.WORLD_ROWS * GameConstants.CELL_SIZE) / GameConstants.SAND_CELL_SIZE)


func _get_push_rect(player_rect: Rect2, direction: int) -> Rect2:
	var top := player_rect.position.y + player_rect.size.y * 0.3
	var rect := Rect2(Vector2(player_rect.position.x, top), Vector2(player_rect.size.x, player_rect.end.y - top))
	if direction > 0:
		rect.size.x += GameConstants.SAND_CELL_SIZE * GameConstants.SAND_PUSH_FRONT_PADDING
	else:
		rect.position.x -= GameConstants.SAND_CELL_SIZE * GameConstants.SAND_PUSH_FRONT_PADDING
		rect.size.x += GameConstants.SAND_CELL_SIZE * GameConstants.SAND_PUSH_FRONT_PADDING
	rect.position.y -= GameConstants.SAND_CELL_SIZE * GameConstants.SAND_PUSH_VERTICAL_PADDING
	rect.size.y += GameConstants.SAND_CELL_SIZE * GameConstants.SAND_PUSH_VERTICAL_PADDING
	return rect


func _get_push_signature(push_rect: Rect2, direction: int) -> String:
	var min_cell := world_to_sand_cell(push_rect.position)
	var max_cell := world_to_sand_cell(push_rect.position + push_rect.size - Vector2.ONE)
	var sample_min_x := min_cell.x
	var sample_max_x := max_cell.x
	if direction > 0:
		sample_max_x += GameConstants.SAND_PUSH_CHAIN_LIMIT
	else:
		sample_min_x -= GameConstants.SAND_PUSH_CHAIN_LIMIT
	var sample_min_y := min_cell.y - GameConstants.SAND_PUSH_UPWARD_BIAS
	var sample_max_y := max_cell.y
	var signature: String = "%d|%d|%d|%d|%d|" % [
		direction,
		sample_min_x,
		sample_min_y,
		sample_max_x,
		sample_max_y,
	]
	for y in range(sample_min_y, sample_max_y + 1):
		for x in range(sample_min_x, sample_max_x + 1):
			var cell := Vector2i(x, y)
			if sand_cells.has(cell):
				signature += "%d:%d;" % [x, y]
	return signature


func _get_jump_signature(clear_rect: Rect2, direction: int) -> String:
	var min_cell := world_to_sand_cell(clear_rect.position)
	var max_cell := world_to_sand_cell(clear_rect.position + clear_rect.size - Vector2.ONE)
	var signature: String = "%d|%d|%d|%d|%d|" % [
		direction,
		min_cell.x,
		min_cell.y,
		max_cell.x,
		max_cell.y,
	]
	for y in range(min_cell.y, max_cell.y + 1):
		for x in range(min_cell.x, max_cell.x + 1):
			var cell := Vector2i(x, y)
			if sand_cells.has(cell):
				signature += "%d:%d;" % [x, y]
	return signature


func _store_push_origin_occupied(push_rect: Rect2, direction: int) -> void:
	push_origin_occupied.clear()
	var min_cell := world_to_sand_cell(push_rect.position)
	var max_cell := world_to_sand_cell(push_rect.position + push_rect.size - Vector2.ONE)
	var sample_min_x := min_cell.x
	var sample_max_x := max_cell.x
	if direction > 0:
		sample_max_x += GameConstants.SAND_PUSH_CHAIN_LIMIT
	else:
		sample_min_x -= GameConstants.SAND_PUSH_CHAIN_LIMIT
	var sample_min_y := min_cell.y - GameConstants.SAND_PUSH_UPWARD_BIAS
	var sample_max_y := max_cell.y
	for y in range(sample_min_y, sample_max_y + 1):
		for x in range(sample_min_x, sample_max_x + 1):
			var cell := Vector2i(x, y)
			if sand_cells.has(cell):
				push_origin_occupied[cell] = true


func _can_accept_push_target(cell: Vector2i) -> bool:
	if not _can_occupy(cell):
		return false
	return not push_origin_occupied.has(cell)


func _draw() -> void:
	if world_grid == null:
		return
	for key in sand_cells.keys():
		var cell: Vector2i = key
		var rect := get_sand_cell_rect(cell)
		draw_rect(rect, sand_cells[cell].color)
