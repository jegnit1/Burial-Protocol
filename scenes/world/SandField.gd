extends Node2D
class_name SandField

signal sand_cells_removed(removed_count: int, removal_source: StringName)

var world_grid: WorldGrid
var sand_cells: Dictionary = {}
var active_cells: Dictionary = {}
var mining_triggered_cells: Dictionary = {}
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
	mining_triggered_cells.clear()
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
	var pending_cells: Array[Vector2i] = []
	var reserved_cells: Dictionary = {}
	for index in range(block_data.sand_units):
		var column := spawn_columns[index % spawn_columns.size()]
		var offset_row := int(index / max(spawn_columns.size(), 1))
		var cell := Vector2i(column, max(spawn_row - offset_row, 0))
		while cell.y > 0 and (not _can_occupy(cell) or reserved_cells.has(cell)):
			cell.y -= 1
		if _can_occupy(cell) and not reserved_cells.has(cell):
			reserved_cells[cell] = true
			pending_cells.append(cell)
	for cell in pending_cells:
		sand_cells[cell] = SandCellData.from_block(block_data, pending_cells.size())
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
			_mark_active_cell(cell)
			continue
		if not sand_cells.has(cell):
			mining_triggered_cells.erase(cell)
			continue
		var mining_ttl := _get_mining_trigger_ttl(cell)
		if mining_ttl > 0:
			_update_stability_for_cell(cell)
			if sand_cells[cell].stable:
				mining_triggered_cells.erase(cell)
			elif _try_move_cell(cell, mining_ttl):
				moved = true
			else:
				_advance_mining_trigger(cell, mining_ttl)
		elif _try_move_cell(cell):
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
	for clear_direction in [direction, -direction]:
		jump_attempt_visited.clear()
		jump_check_budget = GameConstants.SAND_JUMP_CLEAR_CHECK_LIMIT
		jump_move_budget = GameConstants.SAND_JUMP_CLEAR_MOVE_LIMIT
		var candidate_count := 0
		for cell in candidates:
			if candidate_count >= GameConstants.SAND_JUMP_CLEAR_CANDIDATE_LIMIT:
				break
			if jump_check_budget <= 0 or jump_move_budget <= 0:
				break
			if jump_attempt_visited.has(cell):
				continue
			moved = _try_jump_clear(cell, clear_direction, 0) or moved
			candidate_count += 1
		if moved:
			break
	if moved:
		blocked_jump_signature = ""
		blocked_jump_retry_frame = -1
		_mark_active_rect(clear_rect, 2)
		queue_redraw()
	else:
		blocked_jump_signature = jump_signature
		blocked_jump_retry_frame = current_frame + GameConstants.SAND_JUMP_CLEAR_RETRY_DELAY_FRAMES
	return moved


# 모래는 우클릭 채굴 대상이 아니다. 과도기 호출을 안전하게 무시한다.
func try_mine_in_shape(_shape_data: Dictionary, _mining_damage: int = 1) -> Dictionary:
	return _make_sand_hit_result()


func has_mineable_in_shape(_shape_data: Dictionary) -> bool:
	return false


func try_mine_in_rect(_mine_rect: Rect2, _direction: Vector2i, _mining_damage: int = 1) -> int:
	return 0


func apply_weapon_damage_in_shape(
	shape_data: Dictionary,
	weapon_damage: float,
	damage_source: StringName
) -> Dictionary:
	return _apply_weapon_damage_to_sand_cells(
		get_sand_cells_in_shape(shape_data),
		weapon_damage,
		damage_source,
		{}
	)


func apply_weapon_damage_in_rect(
	hit_rect: Rect2,
	weapon_damage: float,
	damage_source: StringName,
	already_hit_cells: Dictionary = {}
) -> Dictionary:
	return _apply_weapon_damage_to_sand_cells(
		get_sand_cells_in_rect(hit_rect),
		weapon_damage,
		damage_source,
		already_hit_cells
	)


func apply_weapon_damage_in_radius(
	center: Vector2,
	radius: float,
	weapon_damage: float,
	damage_source: StringName
) -> Dictionary:
	var cells: Array[Vector2i] = []
	if world_grid == null or sand_cells.is_empty() or radius <= 0.0:
		return _make_sand_hit_result()
	var hit_rect := Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
	var min_cell := world_to_sand_cell(hit_rect.position)
	var max_cell := world_to_sand_cell(hit_rect.position + hit_rect.size - Vector2.ONE)
	for y in range(min_cell.y, max_cell.y + 1):
		for x in range(min_cell.x, max_cell.x + 1):
			var cell := Vector2i(x, y)
			if sand_cells.has(cell) and get_sand_cell_rect(cell).get_center().distance_to(center) <= radius:
				cells.append(cell)
	return _apply_weapon_damage_to_sand_cells(cells, weapon_damage, damage_source, {})


func get_sand_cells_in_shape(shape_data: Dictionary) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if world_grid == null or sand_cells.is_empty():
		return cells
	var shape_bounds := GameConstants.get_shape_bounds(shape_data)
	var min_cell := world_to_sand_cell(shape_bounds.position)
	var max_cell := world_to_sand_cell(shape_bounds.position + shape_bounds.size - Vector2.ONE)
	for y in range(min_cell.y, max_cell.y + 1):
		for x in range(min_cell.x, max_cell.x + 1):
			var cell := Vector2i(x, y)
			if not sand_cells.has(cell):
				continue
			var cell_rect := get_sand_cell_rect(cell)
			if cell_rect.intersects(shape_bounds) and GameConstants.is_point_inside_shape(cell_rect.get_center(), shape_data):
				cells.append(cell)
	return cells


func get_sand_cells_in_rect(hit_rect: Rect2) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if world_grid == null or sand_cells.is_empty():
		return cells
	var min_cell := world_to_sand_cell(hit_rect.position)
	var max_cell := world_to_sand_cell(hit_rect.position + hit_rect.size - Vector2.ONE)
	for y in range(min_cell.y, max_cell.y + 1):
		for x in range(min_cell.x, max_cell.x + 1):
			var cell := Vector2i(x, y)
			if sand_cells.has(cell) and get_sand_cell_rect(cell).intersects(hit_rect):
				cells.append(cell)
	return cells


func apply_weapon_damage_to_sand_cell(cell: Vector2i, weapon_damage: float, damage_source: StringName) -> bool:
	var result := _apply_weapon_damage_to_sand_cells([cell], weapon_damage, damage_source, {})
	return int(result.get("removed_count", 0)) > 0


func _apply_weapon_damage_to_sand_cells(
	cells: Array[Vector2i],
	weapon_damage: float,
	damage_source: StringName,
	already_hit_cells: Dictionary
) -> Dictionary:
	var result := _make_sand_hit_result()
	if damage_source != &"weapon" or weapon_damage <= 0.0:
		return result
	var sand_damage := weapon_damage * GameConstants.SAND_WEAPON_DAMAGE_RATIO
	if sand_damage <= 0.0:
		return result
	result["damage_per_cell"] = sand_damage
	var removed_cells: Array[Vector2i] = []
	for cell in cells:
		if already_hit_cells.has(cell) or not sand_cells.has(cell):
			continue
		already_hit_cells[cell] = true
		result["hit_count"] += 1
		result["hit_cells"].append(cell)
		var sand_cell: SandCellData = sand_cells[cell]
		sand_cell.hp -= sand_damage
		if sand_cell.hp > 0.0:
			continue
		sand_cells.erase(cell)
		mining_triggered_cells.erase(cell)
		removed_cells.append(cell)
		result["removed_cells"].append(cell)
		result["removed_count"] += 1
	if int(result["removed_count"]) > 0:
		blocked_push_signature = ""
		blocked_jump_signature = ""
		_mark_active_after_mining(removed_cells)
		sand_cells_removed.emit(int(result["removed_count"]), &"weapon")
	if int(result["hit_count"]) > 0:
		queue_redraw()
	return result


func _make_sand_hit_result() -> Dictionary:
	var result := {
		"hit_count": 0,
		"removed_count": 0,
		"hit_cells": [],
		"removed_cells": [],
		"damage_per_cell": 0.0,
	}
	return result


func get_sand_count() -> int:
	return sand_cells.size()


func remove_nearest_sand_cells(world_position: Vector2, count: int) -> Array[Vector2i]:
	var removed_cells: Array[Vector2i] = []
	if count <= 0 or sand_cells.is_empty():
		return removed_cells
	var candidates: Array[Vector2i] = []
	for raw_cell in sand_cells.keys():
		candidates.append(raw_cell as Vector2i)
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return sand_cell_to_world(a).distance_squared_to(world_position) < sand_cell_to_world(b).distance_squared_to(world_position)
	)
	for cell in candidates:
		if removed_cells.size() >= count:
			break
		if not sand_cells.has(cell):
			continue
		sand_cells.erase(cell)
		mining_triggered_cells.erase(cell)
		removed_cells.append(cell)
	if removed_cells.is_empty():
		return removed_cells
	blocked_push_signature = ""
	blocked_jump_signature = ""
	_mark_active_after_mining(removed_cells)
	sand_cells_removed.emit(removed_cells.size(), &"sand_cleaner")
	queue_redraw()
	return removed_cells


func extract_sand_cells_in_rects(world_rects: Array[Rect2]) -> Array[SandCellData]:
	var extracted_cells: Array[SandCellData] = []
	var removed_cells: Array[Vector2i] = []
	for key in sand_cells.keys():
		var cell: Vector2i = key
		var cell_rect := get_sand_cell_rect(cell)
		for world_rect in world_rects:
			if not world_rect.intersects(cell_rect):
				continue
			extracted_cells.append((sand_cells[cell] as SandCellData).clone())
			sand_cells.erase(cell)
			mining_triggered_cells.erase(cell)
			removed_cells.append(cell)
			break
	if not removed_cells.is_empty():
		_mark_active_after_mining(removed_cells)
		queue_redraw()
	return extracted_cells


func redistribute_sand_cells_to_center(
	extracted_cells: Array[SandCellData],
	blocked_rects: Array[Rect2] = []
) -> int:
	if extracted_cells.is_empty():
		return 0
	var center_start_x := GameConstants.WALL_COLUMNS * GameConstants.SAND_CELLS_PER_UNIT
	var center_end_x := center_start_x + GameConstants.CENTER_COLUMNS * GameConstants.SAND_CELLS_PER_UNIT - 1
	var sand_rows := _get_sand_rows()
	var placed_count := 0
	for y in range(sand_rows - 1, -1, -1):
		for x in range(center_start_x, center_end_x + 1):
			if placed_count >= extracted_cells.size():
				queue_redraw()
				return placed_count
			var target_cell := Vector2i(x, y)
			if not _can_occupy(target_cell):
				continue
			var target_rect := get_sand_cell_rect(target_cell)
			var is_blocked := false
			for blocked_rect in blocked_rects:
				if blocked_rect.intersects(target_rect):
					is_blocked = true
					break
			if is_blocked:
				continue
			sand_cells[target_cell] = extracted_cells[placed_count].clone()
			mining_triggered_cells.erase(target_cell)
			_mark_active(target_cell, 1)
			_update_stability_for_cell(target_cell)
			placed_count += 1
	queue_redraw()
	return placed_count


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


func _try_move_cell(cell: Vector2i, mining_trigger_ttl: int = 0) -> bool:
	var down := cell + Vector2i.DOWN
	if _can_occupy(down):
		var next_mining_ttl: int = max(mining_trigger_ttl - 1, 0)
		_move_cell(cell, down, next_mining_ttl, mining_trigger_ttl > 0)
		return true
	if mining_trigger_ttl > 0:
		return false
	var side_order := [Vector2i.LEFT, Vector2i.RIGHT]
	if flow_flip:
		side_order.reverse()
	for side in side_order:
		var diagonal := cell + Vector2i(side.x, 1)
		if _can_occupy(diagonal) and _can_occupy(cell + side):
			_move_cell(cell, diagonal)
			return true
	return false


func _move_cell(from_cell: Vector2i, to_cell: Vector2i, next_mining_ttl: int = 0, conservative_activation: bool = false) -> void:
	sand_cells[to_cell] = sand_cells[from_cell]
	sand_cells.erase(from_cell)
	mining_triggered_cells.erase(from_cell)
	if next_mining_ttl > 0:
		mining_triggered_cells[to_cell] = next_mining_ttl
	else:
		mining_triggered_cells.erase(to_cell)
	if push_move_budget > 0:
		push_move_budget -= 1
	if jump_move_budget > 0:
		jump_move_budget -= 1
	blocked_push_signature = ""
	blocked_jump_signature = ""
	blocked_jump_retry_frame = -1
	if conservative_activation:
		_mark_active_after_mining([from_cell, to_cell])
	else:
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


func _mark_active_after_mining(mined_cells: Array[Vector2i]) -> void:
	for cell in mined_cells:
		_mark_conservative_active(cell, false)
		for offset in range(1, GameConstants.SAND_MINING_ACTIVE_ABOVE_CELLS + 1):
			_mark_conservative_active(cell + Vector2i.UP * offset, true)
		_mark_conservative_active(cell + Vector2i.LEFT, true)
		_mark_conservative_active(cell + Vector2i.RIGHT, true)
		_mark_conservative_active(cell + Vector2i.DOWN, true)


func _mark_conservative_active(cell: Vector2i, mark_mining_trigger: bool) -> void:
	_mark_active_cell(cell)
	if not mark_mining_trigger:
		return
	if sand_cells.has(cell):
		var existing_ttl := _get_mining_trigger_ttl(cell)
		mining_triggered_cells[cell] = max(existing_ttl, GameConstants.SAND_MINING_VERTICAL_ONLY_TICKS)


func _advance_mining_trigger(cell: Vector2i, mining_ttl: int) -> void:
	if not sand_cells.has(cell):
		mining_triggered_cells.erase(cell)
		return
	var next_ttl: int = max(mining_ttl - 1, 0)
	if next_ttl > 0:
		mining_triggered_cells[cell] = next_ttl
	else:
		mining_triggered_cells.erase(cell)
	if not sand_cells[cell].stable:
		_mark_active_cell(cell)


func _get_mining_trigger_ttl(cell: Vector2i) -> int:
	if not mining_triggered_cells.has(cell):
		return 0
	return int(mining_triggered_cells[cell])


func _mark_active_cell(cell: Vector2i) -> void:
	active_cells[cell] = true


func _mark_active(cell: Vector2i, radius: int) -> void:
	for y in range(cell.y - radius, cell.y + radius + 1):
		for x in range(cell.x - radius, cell.x + radius + 1):
			_mark_active_cell(Vector2i(x, y))


func _mark_active_rect(rect: Rect2, radius: int) -> void:
	var min_cell := world_to_sand_cell(rect.position)
	var max_cell := world_to_sand_cell(rect.position + rect.size - Vector2.ONE)
	for y in range(min_cell.y - radius, max_cell.y + radius + 1):
		for x in range(min_cell.x - radius, max_cell.x + radius + 1):
			_mark_active_cell(Vector2i(x, y))


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
	var parts := PackedStringArray(["%d|%d|%d|%d|%d|" % [
		direction, sample_min_x, sample_min_y, sample_max_x, sample_max_y,
	]])
	for y in range(sample_min_y, sample_max_y + 1):
		for x in range(sample_min_x, sample_max_x + 1):
			if sand_cells.has(Vector2i(x, y)):
				parts.append("%d:%d;" % [x, y])
	return "".join(parts)


func _get_jump_signature(clear_rect: Rect2, direction: int) -> String:
	var min_cell := world_to_sand_cell(clear_rect.position)
	var max_cell := world_to_sand_cell(clear_rect.position + clear_rect.size - Vector2.ONE)
	var parts := PackedStringArray(["%d|%d|%d|%d|%d|" % [
		direction, min_cell.x, min_cell.y, max_cell.x, max_cell.y,
	]])
	for y in range(min_cell.y, max_cell.y + 1):
		for x in range(min_cell.x, max_cell.x + 1):
			if sand_cells.has(Vector2i(x, y)):
				parts.append("%d:%d;" % [x, y])
	return "".join(parts)


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


func _get_shape_polygon(shape_data: Dictionary) -> PackedVector2Array:
	var center: Vector2 = shape_data["center"]
	var size: Vector2 = shape_data["size"]
	var forward := Vector2.RIGHT.rotated(shape_data["rotation"])
	var half_forward := forward * (size.x * 0.5)
	var half_side := forward.orthogonal() * (size.y * 0.5)
	return PackedVector2Array([
		center - half_forward - half_side,
		center + half_forward - half_side,
		center + half_forward + half_side,
		center - half_forward + half_side,
	])


func _get_polygon_bounds(polygon: PackedVector2Array) -> Rect2:
	if polygon.is_empty():
		return Rect2()
	var min_x := polygon[0].x
	var max_x := polygon[0].x
	var min_y := polygon[0].y
	var max_y := polygon[0].y
	for point in polygon:
		min_x = minf(min_x, point.x)
		max_x = maxf(max_x, point.x)
		min_y = minf(min_y, point.y)
		max_y = maxf(max_y, point.y)
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))


func _polygon_intersects_rect(polygon: PackedVector2Array, rect: Rect2) -> bool:
	var rect_polygon := PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
	])
	return _polygons_intersect(polygon, rect_polygon)


func _polygons_intersect(polygon_a: PackedVector2Array, polygon_b: PackedVector2Array) -> bool:
	var axes := _get_polygon_axes(polygon_a)
	axes.append_array(_get_polygon_axes(polygon_b))
	for axis in axes:
		if axis == Vector2.ZERO:
			continue
		var normalized_axis := axis.normalized()
		var range_a := _get_projection_range(polygon_a, normalized_axis)
		var range_b := _get_projection_range(polygon_b, normalized_axis)
		if range_a.y < range_b.x or range_b.y < range_a.x:
			return false
	return true


func _get_polygon_axes(polygon: PackedVector2Array) -> Array[Vector2]:
	var axes: Array[Vector2] = []
	for index in range(polygon.size()):
		var next_index := (index + 1) % polygon.size()
		var edge := polygon[next_index] - polygon[index]
		axes.append(edge.orthogonal())
	return axes


func _get_projection_range(polygon: PackedVector2Array, axis: Vector2) -> Vector2:
	var projection := polygon[0].dot(axis)
	var min_projection := projection
	var max_projection := projection
	for index in range(1, polygon.size()):
		projection = polygon[index].dot(axis)
		min_projection = minf(min_projection, projection)
		max_projection = maxf(max_projection, projection)
	return Vector2(min_projection, max_projection)


func _draw() -> void:
	if world_grid == null:
		return
	for key in sand_cells.keys():
		var cell: Vector2i = key
		var rect := get_sand_cell_rect(cell)
		var sand_cell: SandCellData = sand_cells[cell]
		var damage_ratio := 1.0 - float(sand_cell.hp) / float(sand_cell.max_hp)
		var draw_color := sand_cell.color.darkened(damage_ratio * GameConstants.MINING_DAMAGED_COLOR_RATIO)
		draw_rect(rect, draw_color)
