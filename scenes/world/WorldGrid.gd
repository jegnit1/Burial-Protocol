extends Node2D
class_name WorldGrid

const WALL_SUBCELL_COUNT := GameConstants.WALL_SUBCELLS_PER_UNIT * GameConstants.WALL_SUBCELLS_PER_UNIT

var wall_cells: Dictionary = {}

# 손상된 적 있는 셀 집합. _draw()에서 이 셀만 서브셀 단위로 개별 렌더링한다.
# 한 번 추가되면 제거하지 않는다(완전 채굴 후에도 MINED_WALL_COLOR 배경이 필요).
var _touched_cells: Dictionary = {}

# get_active_wall_count()용 캐시. 서브셀 HP가 0이 될 때마다 차감한다.
var _active_subcell_count := 0

# _draw()에서 반복 계산을 피하기 위해 미리 계산해둔 사각형.
var _left_wall_rect := Rect2()
var _right_wall_rect := Rect2()
var _floor_rect := Rect2()


func _ready() -> void:
	_build_wall_cells()
	queue_redraw()


func _build_wall_cells() -> void:
	wall_cells.clear()
	_touched_cells.clear()
	for y in range(GameConstants.FLOOR_ROW):
		for x in range(GameConstants.WORLD_COLUMNS):
			if _is_wall_column(x):
				wall_cells[Vector2i(x, y)] = _create_full_wall_subcells()
	_active_subcell_count = wall_cells.size() * WALL_SUBCELL_COUNT
	_precalculate_rects()


func _precalculate_rects() -> void:
	var ox := float(GameConstants.WORLD_ORIGIN.x)
	var oy := float(GameConstants.WORLD_ORIGIN.y)
	var cell := float(GameConstants.CELL_SIZE)
	var wall_w := float(GameConstants.WALL_COLUMNS) * cell
	var wall_h := float(GameConstants.FLOOR_ROW) * cell
	_left_wall_rect = Rect2(Vector2(ox, oy), Vector2(wall_w, wall_h))
	_right_wall_rect = Rect2(
		Vector2(ox + float(GameConstants.WORLD_COLUMNS - GameConstants.WALL_COLUMNS) * cell, oy),
		Vector2(wall_w, wall_h)
	)
	_floor_rect = Rect2(
		Vector2(ox, oy + float(GameConstants.FLOOR_ROW) * cell),
		Vector2(float(GameConstants.WORLD_PIXEL_WIDTH), cell)
	)


func _create_full_wall_subcells() -> PackedByteArray:
	var subcell_hps := PackedByteArray()
	subcell_hps.resize(WALL_SUBCELL_COUNT)
	subcell_hps.fill(GameConstants.WALL_SUBCELL_MAX_HP)
	return subcell_hps


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
	return _wall_cell_has_solid_subcells(cell)


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


func get_wall_subcell_rect(cell: Vector2i, sub_x: int, sub_y: int) -> Rect2:
	return Rect2(
		cell_to_world(cell) + Vector2(sub_x, sub_y) * GameConstants.WALL_SUBCELL_SIZE,
		Vector2.ONE * GameConstants.WALL_SUBCELL_SIZE
	)


func rect_collides_static(rect: Rect2) -> bool:
	var min_cell := world_to_cell(rect.position)
	var max_cell := world_to_cell(rect.position + rect.size - Vector2.ONE)
	for y in range(min_cell.y, max_cell.y + 1):
		for x in range(min_cell.x, max_cell.x + 1):
			var cell := Vector2i(x, y)
			if cell.y < 0:
				continue
			if cell.x < 0 or cell.x >= GameConstants.WORLD_COLUMNS or cell.y >= GameConstants.WORLD_ROWS:
				if get_cell_rect(cell).intersects(rect):
					return true
				continue
			if cell.y == GameConstants.FLOOR_ROW:
				if get_cell_rect(cell).intersects(rect):
					return true
				continue
			if not _wall_cell_has_solid_subcells(cell):
				continue
			if _wall_cell_rect_collides(cell, rect):
				return true
	return false


func try_mine_in_shape(shape_data: Dictionary, mining_damage: int) -> Dictionary:
	var result := {
		"hit_count": 0,
		"removed_count": 0,
	}
	if mining_damage <= 0:
		return result
	var shape_bounds := GameConstants.get_shape_bounds(shape_data)
	var min_cell := world_to_cell(shape_bounds.position)
	var max_cell := world_to_cell(shape_bounds.position + shape_bounds.size - Vector2.ONE)
	for y in range(min_cell.y, max_cell.y + 1):
		for x in range(min_cell.x, max_cell.x + 1):
			var cell := Vector2i(x, y)
			if not _wall_cell_has_solid_subcells(cell):
				continue
			var subcell_hps: PackedByteArray = wall_cells[cell]
			var changed := false
			for sub_y in range(GameConstants.WALL_SUBCELLS_PER_UNIT):
				for sub_x in range(GameConstants.WALL_SUBCELLS_PER_UNIT):
					var subcell_index := _get_subcell_index(sub_x, sub_y)
					if subcell_hps[subcell_index] == 0:
						continue
					var subcell_rect := get_wall_subcell_rect(cell, sub_x, sub_y)
					if not subcell_rect.intersects(shape_bounds):
						continue
					if not GameConstants.is_point_inside_shape(subcell_rect.get_center(), shape_data):
						continue
					result["hit_count"] += 1
					changed = true
					var remaining_hp := maxi(int(subcell_hps[subcell_index]) - mining_damage, 0)
					if remaining_hp == 0:
						result["removed_count"] += 1
						_active_subcell_count -= 1
					subcell_hps[subcell_index] = remaining_hp
			if not changed:
				continue
			_touched_cells[cell] = true
			if _packed_byte_array_is_empty(subcell_hps):
				wall_cells.erase(cell)
			else:
				wall_cells[cell] = subcell_hps
	if int(result["hit_count"]) > 0:
		queue_redraw()
	return result


func get_active_wall_count() -> int:
	return _active_subcell_count


func restore_mining_walls() -> void:
	_build_wall_cells()
	queue_redraw()


func get_wall_restore_rects() -> Array[Rect2]:
	return [_left_wall_rect, _right_wall_rect]


func get_spawn_position(size_cells: Vector2i, rng: RandomNumberGenerator, camera_top_y: float) -> Vector2:
	var min_column := GameConstants.WALL_COLUMNS
	var max_column := GameConstants.WORLD_COLUMNS - GameConstants.WALL_COLUMNS - size_cells.x
	var column := rng.randi_range(min_column, max_column)
	var spawn_y := camera_top_y - float(GameConstants.CELL_SIZE) * 3.0 - float(size_cells.y) * float(GameConstants.CELL_SIZE) * 0.5
	return Vector2(
		GameConstants.WORLD_ORIGIN.x + (column + size_cells.x * 0.5) * GameConstants.CELL_SIZE,
		spawn_y
	)


func _wall_cell_has_solid_subcells(cell: Vector2i) -> bool:
	if not wall_cells.has(cell):
		return false
	var subcell_hps: PackedByteArray = wall_cells[cell]
	for hp in subcell_hps:
		if hp > 0:
			return true
	return false


func _wall_cell_rect_collides(cell: Vector2i, rect: Rect2) -> bool:
	var subcell_hps: PackedByteArray = wall_cells[cell]
	for sub_y in range(GameConstants.WALL_SUBCELLS_PER_UNIT):
		for sub_x in range(GameConstants.WALL_SUBCELLS_PER_UNIT):
			if subcell_hps[_get_subcell_index(sub_x, sub_y)] == 0:
				continue
			if get_wall_subcell_rect(cell, sub_x, sub_y).intersects(rect):
				return true
	return false


func _get_subcell_index(sub_x: int, sub_y: int) -> int:
	return sub_y * GameConstants.WALL_SUBCELLS_PER_UNIT + sub_x


func _packed_byte_array_is_empty(data: PackedByteArray) -> bool:
	for value in data:
		if value > 0:
			return false
	return true


func _draw() -> void:
	draw_rect(GameConstants.get_world_rect(), GameConstants.WORLD_BACKGROUND_COLOR)
	draw_rect(GameConstants.get_center_rect(), GameConstants.WORLD_CENTER_COLOR)
	# 좌우 벽 전체를 단색 사각형 2개로 표현
	draw_rect(_left_wall_rect, GameConstants.WALL_CELL_COLOR)
	draw_rect(_right_wall_rect, GameConstants.WALL_CELL_COLOR)
	# 손상된 셀만 서브셀 단위로 덮어씀
	for key in _touched_cells.keys():
		var cell: Vector2i = key
		_draw_damaged_cell(cell)
	# 바닥은 1개 rect
	draw_rect(_floor_rect, GameConstants.FLOOR_COLOR)


func _draw_damaged_cell(cell: Vector2i) -> void:
	# 손상 배경 먼저 (완전 채굴 셀은 여기서 끝)
	draw_rect(get_cell_rect(cell), GameConstants.MINED_WALL_COLOR)
	if not wall_cells.has(cell):
		return
	var subcell_hps: PackedByteArray = wall_cells[cell]
	for sub_y in range(GameConstants.WALL_SUBCELLS_PER_UNIT):
		for sub_x in range(GameConstants.WALL_SUBCELLS_PER_UNIT):
			var hp := int(subcell_hps[_get_subcell_index(sub_x, sub_y)])
			if hp <= 0:
				continue
			var damage_ratio := 1.0 - float(hp) / float(GameConstants.WALL_SUBCELL_MAX_HP)
			var draw_color := GameConstants.WALL_CELL_COLOR.lerp(GameConstants.MINED_WALL_COLOR, damage_ratio)
			draw_rect(get_wall_subcell_rect(cell, sub_x, sub_y), draw_color)
