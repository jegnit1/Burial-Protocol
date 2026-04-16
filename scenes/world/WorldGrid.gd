extends Node2D
class_name WorldGrid

var wall_cells: Dictionary = {}


func _ready() -> void:
	_build_wall_cells()
	queue_redraw()


func _build_wall_cells() -> void:
	wall_cells.clear()
	for y in range(GameConstants.FLOOR_ROW):
		for x in range(GameConstants.WORLD_COLUMNS):
			if _is_wall_column(x):
				wall_cells[Vector2i(x, y)] = true


func _is_wall_column(column: int) -> bool:
	return column < GameConstants.WALL_COLUMNS or column >= GameConstants.WORLD_COLUMNS - GameConstants.WALL_COLUMNS


func is_static_solid_cell(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.x >= GameConstants.WORLD_COLUMNS:
		return true
	if cell.y >= GameConstants.WORLD_ROWS:
		return true
	if cell.y < 0:
		return false
	if cell.y == GameConstants.FLOOR_ROW:
		return true
	return wall_cells.get(cell, false)


func world_to_cell(world_position: Vector2) -> Vector2i:
	var local_position := world_position - Vector2(GameConstants.WORLD_ORIGIN)
	return Vector2i(
		floori(local_position.x / GameConstants.CELL_SIZE),
		floori(local_position.y / GameConstants.CELL_SIZE)
	)


func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(
		GameConstants.WORLD_ORIGIN.x + cell.x * GameConstants.CELL_SIZE,
		GameConstants.WORLD_ORIGIN.y + cell.y * GameConstants.CELL_SIZE
	)


func get_cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(cell_to_world(cell), Vector2.ONE * GameConstants.CELL_SIZE)


func rect_collides_static(rect: Rect2) -> bool:
	var min_cell := world_to_cell(rect.position)
	var max_cell := world_to_cell(rect.position + rect.size - Vector2.ONE)
	for y in range(min_cell.y, max_cell.y + 1):
		for x in range(min_cell.x, max_cell.x + 1):
			var cell := Vector2i(x, y)
			if is_static_solid_cell(cell) and get_cell_rect(cell).intersects(rect):
				return true
	return false


func try_mine_in_rect(attack_rect: Rect2, direction: Vector2i, mining_damage: int = 1) -> bool:
	var min_cell := world_to_cell(attack_rect.position)
	var max_cell := world_to_cell(attack_rect.position + attack_rect.size - Vector2.ONE)
	var cell_list: Array[Vector2i] = []
	for y in range(min_cell.y, max_cell.y + 1):
		for x in range(min_cell.x, max_cell.x + 1):
			var cell := Vector2i(x, y)
			if wall_cells.get(cell, false):
				cell_list.append(cell)
	if cell_list.is_empty():
		return false
	cell_list.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if direction.x < 0:
			return a.x < b.x
		if direction.x > 0:
			return a.x > b.x
		return a.y < b.y
	)
	# 현재는 mining_damage에 무관하게 1셀 제거 유지 (향후 확장 가능)
	wall_cells.erase(cell_list[0])
	queue_redraw()
	return true


func get_active_wall_count() -> int:
	return wall_cells.size()


func get_spawn_position(size_cells: Vector2i, rng: RandomNumberGenerator) -> Vector2:
	var min_column := GameConstants.WALL_COLUMNS
	var max_column := GameConstants.WORLD_COLUMNS - GameConstants.WALL_COLUMNS - size_cells.x
	var column := rng.randi_range(min_column, max_column)
	return Vector2(
		GameConstants.WORLD_ORIGIN.x + (column + size_cells.x * 0.5) * GameConstants.CELL_SIZE,
		GameConstants.WORLD_ORIGIN.y - size_cells.y * GameConstants.CELL_SIZE * 0.5 - GameConstants.BLOCK_SPAWN_Y_OFFSET
	)


func _draw() -> void:
	draw_rect(GameConstants.get_world_rect(), GameConstants.WORLD_BACKGROUND_COLOR)
	draw_rect(GameConstants.get_center_rect(), GameConstants.WORLD_CENTER_COLOR)
	for cell in wall_cells.keys():
		draw_rect(get_cell_rect(cell), GameConstants.WALL_CELL_COLOR)
	for x in range(GameConstants.WORLD_COLUMNS):
		draw_rect(get_cell_rect(Vector2i(x, GameConstants.FLOOR_ROW)), GameConstants.FLOOR_COLOR)
