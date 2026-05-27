extends Node2D
class_name WorldGrid

const WALL_TILESET_TEXTURE := preload("res://assets/world/walls/wall_brick_normal.png")
const WALL_CHIP_TEXTURE := preload("res://assets/world/walls/wall_brick_normal_shard.png")
const WALL_CHIP_PARTICLE_SCRIPT := preload("res://scenes/world/WallChipParticle.gd")
const WALL_TILE_SOURCE_SIZE := Vector2(32.0, 32.0)
const WALL_CHIP_SOURCE_SIZE := Vector2(7.0, 7.0)
const WALL_CHIP_SOURCE_COUNT := 4
const WALL_HIT_SHAKE_DURATION := 0.08
const WALL_HIT_SHAKE_PIXELS := 3.0
const WALL_CHIP_PARTICLE_COUNT_MIN := 7
const WALL_CHIP_PARTICLE_COUNT_MAX := 12

var wall_cells: Dictionary = {}
var _touched_cells: Dictionary = {}
var _wall_hit_shake_timers: Dictionary = {}
var _wall_hit_shake_offsets: Dictionary = {}
var _wall_mining_hit_counts: Dictionary = {}
var _left_wall_rect := Rect2()
var _right_wall_rect := Rect2()
var _floor_rect := Rect2()
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rng.randomize()
	_build_wall_cells()
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	if _wall_hit_shake_timers.is_empty():
		return
	var expired_cells: Array[Vector2i] = []
	for key in _wall_hit_shake_timers.keys():
		var cell: Vector2i = key
		var remaining := float(_wall_hit_shake_timers[cell]) - delta
		if remaining <= 0.0:
			expired_cells.append(cell)
			continue
		_wall_hit_shake_timers[cell] = remaining
		_wall_hit_shake_offsets[cell] = _make_wall_shake_offset(remaining)
	for cell in expired_cells:
		_wall_hit_shake_timers.erase(cell)
		_wall_hit_shake_offsets.erase(cell)
	queue_redraw()


func _build_wall_cells() -> void:
	wall_cells.clear()
	_touched_cells.clear()
	_wall_hit_shake_timers.clear()
	_wall_hit_shake_offsets.clear()
	_wall_mining_hit_counts.clear()
	for y in range(GameConstants.FLOOR_ROW):
		for x in range(GameConstants.WORLD_COLUMNS):
			if _is_wall_column(x):
				wall_cells[Vector2i(x, y)] = GameConstants.WALL_CELL_MAX_HP
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
	return wall_cells.has(cell)


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
			if wall_cells.has(cell) and get_cell_rect(cell).intersects(rect):
				return true
	return false


func try_mine_in_shape(shape_data: Dictionary, mining_damage: int) -> Dictionary:
	var result := {
		"hit_count": 0,
		"removed_count": 0,
		"hit_cells": [],
		"removed_cells": [],
	}
	if mining_damage <= 0:
		return result
	var shape_bounds := GameConstants.get_shape_bounds(shape_data)
	var min_cell := world_to_cell(shape_bounds.position)
	var max_cell := world_to_cell(shape_bounds.position + shape_bounds.size - Vector2.ONE)
	for y in range(min_cell.y, max_cell.y + 1):
		for x in range(min_cell.x, max_cell.x + 1):
			var cell := Vector2i(x, y)
			if not wall_cells.has(cell):
				continue
			var cell_rect := get_cell_rect(cell)
			if not cell_rect.intersects(shape_bounds):
				continue
			if not _cell_rect_intersects_shape(cell_rect, shape_data):
				continue
			_touched_cells[cell] = true
			result["hit_count"] += 1
			result["hit_cells"].append(cell)
			_register_wall_hit_effect(cell)
			var current_hp := int(wall_cells[cell])
			var tile_index_before_hit := _get_wall_tile_index_for_ratio(_get_wall_cell_remaining_ratio(cell))
			var new_hp := maxi(current_hp - mining_damage, 0)
			var chip_tile_index := tile_index_before_hit
			if new_hp <= 0:
				wall_cells.erase(cell)
				_wall_hit_shake_timers.erase(cell)
				_wall_hit_shake_offsets.erase(cell)
				result["removed_count"] += 1
				result["removed_cells"].append(cell)
			else:
				wall_cells[cell] = new_hp
				chip_tile_index = _get_wall_tile_index_for_ratio(_get_wall_cell_remaining_ratio(cell))
			var hit_count := int(_wall_mining_hit_counts.get(cell, 0)) + 1
			_wall_mining_hit_counts[cell] = hit_count
			if hit_count % 2 == 0:
				_spawn_wall_chip_particles(cell, chip_tile_index)
	if int(result["hit_count"]) > 0:
		queue_redraw()
	return result


func shake_mineable_in_shape(shape_data: Dictionary) -> int:
	var hit_count := 0
	var shape_bounds := GameConstants.get_shape_bounds(shape_data)
	var min_cell := world_to_cell(shape_bounds.position)
	var max_cell := world_to_cell(shape_bounds.position + shape_bounds.size - Vector2.ONE)
	for y in range(min_cell.y, max_cell.y + 1):
		for x in range(min_cell.x, max_cell.x + 1):
			var cell := Vector2i(x, y)
			if not wall_cells.has(cell):
				continue
			var cell_rect := get_cell_rect(cell)
			if not cell_rect.intersects(shape_bounds):
				continue
			if not _cell_rect_intersects_shape(cell_rect, shape_data):
				continue
			_register_wall_hit_effect(cell)
			hit_count += 1
	if hit_count > 0:
		queue_redraw()
	return hit_count


func has_mineable_in_shape(shape_data: Dictionary) -> bool:
	var shape_bounds := GameConstants.get_shape_bounds(shape_data)
	var min_cell := world_to_cell(shape_bounds.position)
	var max_cell := world_to_cell(shape_bounds.position + shape_bounds.size - Vector2.ONE)
	for y in range(min_cell.y, max_cell.y + 1):
		for x in range(min_cell.x, max_cell.x + 1):
			var cell := Vector2i(x, y)
			if not wall_cells.has(cell):
				continue
			var cell_rect := get_cell_rect(cell)
			if not cell_rect.intersects(shape_bounds):
				continue
			if _cell_rect_intersects_shape(cell_rect, shape_data):
				return true
	return false


func get_active_wall_count() -> int:
	return wall_cells.size()


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


func _cell_rect_intersects_shape(cell_rect: Rect2, shape_data: Dictionary) -> bool:
	var points := PackedVector2Array([
		cell_rect.get_center(),
		cell_rect.position,
		Vector2(cell_rect.end.x, cell_rect.position.y),
		cell_rect.end,
		Vector2(cell_rect.position.x, cell_rect.end.y),
		Vector2(cell_rect.get_center().x, cell_rect.position.y),
		Vector2(cell_rect.end.x, cell_rect.get_center().y),
		Vector2(cell_rect.get_center().x, cell_rect.end.y),
		Vector2(cell_rect.position.x, cell_rect.get_center().y),
	])
	for point in points:
		if GameConstants.is_point_inside_shape(point, shape_data):
			return true
	for shape_corner in GameConstants.get_shape_corners(shape_data):
		if cell_rect.has_point(shape_corner):
			return true
	return false


func _register_wall_hit_effect(cell: Vector2i) -> void:
	_wall_hit_shake_timers[cell] = WALL_HIT_SHAKE_DURATION
	_wall_hit_shake_offsets[cell] = _make_wall_shake_offset(WALL_HIT_SHAKE_DURATION)


func _make_wall_shake_offset(remaining: float) -> Vector2:
	var strength := WALL_HIT_SHAKE_PIXELS * clampf(remaining / WALL_HIT_SHAKE_DURATION, 0.0, 1.0)
	return Vector2(
		_rng.randf_range(-strength, strength),
		_rng.randf_range(-strength, strength)
	)


func _draw() -> void:
	draw_rect(GameConstants.get_world_rect(), GameConstants.WORLD_BACKGROUND_COLOR)
	draw_rect(GameConstants.get_center_rect(), GameConstants.WORLD_CENTER_COLOR)
	_draw_wall_cells()
	draw_rect(_floor_rect, GameConstants.FLOOR_COLOR)


func _draw_wall_cells() -> void:
	for key in wall_cells.keys():
		var cell: Vector2i = key
		_draw_wall_cell(cell)
	for key in _touched_cells.keys():
		var cell: Vector2i = key
		if not wall_cells.has(cell):
			draw_rect(get_cell_rect(cell), GameConstants.MINED_WALL_COLOR)


func _draw_wall_cell(cell: Vector2i) -> void:
	if not wall_cells.has(cell):
		return
	var ratio := _get_wall_cell_remaining_ratio(cell)
	var tile_index := _get_wall_tile_index_for_ratio(ratio)
	if tile_index < 0:
		return
	var dst_rect := get_cell_rect(cell)
	if _wall_hit_shake_offsets.has(cell):
		dst_rect.position += _wall_hit_shake_offsets[cell]
	draw_texture_rect_region(
		WALL_TILESET_TEXTURE,
		dst_rect,
		_get_wall_tile_source_rect(tile_index)
	)


func _get_wall_cell_remaining_ratio(cell: Vector2i) -> float:
	if not wall_cells.has(cell):
		return 0.0
	return clampf(float(int(wall_cells[cell])) / float(GameConstants.WALL_CELL_MAX_HP), 0.0, 1.0)


func _get_wall_tile_index_for_ratio(ratio: float) -> int:
	if ratio <= 0.0:
		return -1
	if ratio <= 0.25:
		return 2
	if ratio <= 0.5:
		return 1
	return 0


func _get_wall_tile_source_rect(tile_index: int) -> Rect2:
	return Rect2(Vector2(float(tile_index) * WALL_TILE_SOURCE_SIZE.x, 0.0), WALL_TILE_SOURCE_SIZE)


func _spawn_wall_chip_particles(cell: Vector2i, _tile_index := -1) -> void:
	var particle_count := _rng.randi_range(WALL_CHIP_PARTICLE_COUNT_MIN, WALL_CHIP_PARTICLE_COUNT_MAX)
	var cell_rect := get_cell_rect(cell)
	for _index in range(particle_count):
		var shard_index := _index % WALL_CHIP_SOURCE_COUNT
		var source_rect := Rect2(
			Vector2(float(shard_index) * WALL_CHIP_SOURCE_SIZE.x, 0.0),
			WALL_CHIP_SOURCE_SIZE
		)
		var particle := WALL_CHIP_PARTICLE_SCRIPT.new() as Node2D
		if particle == null:
			continue
		add_child(particle)
		particle.z_index = z_index + 2
		particle.position = cell_rect.get_center() + Vector2(
			_rng.randf_range(-GameConstants.CELL_SIZE * 0.45, GameConstants.CELL_SIZE * 0.45),
			_rng.randf_range(-GameConstants.CELL_SIZE * 0.3, GameConstants.CELL_SIZE * 0.25)
		)
		var burst_direction := Vector2(
			_rng.randf_range(-1.0, 1.0),
			_rng.randf_range(-1.2, -0.25)
		).normalized()
		var burst_speed := _rng.randf_range(180.0, 420.0)
		particle.call(
			"setup",
			WALL_CHIP_TEXTURE,
			source_rect,
			WALL_CHIP_SOURCE_SIZE * _rng.randf_range(2.2, 3.1),
			burst_direction * burst_speed + Vector2(_rng.randf_range(-90.0, 90.0), _rng.randf_range(-120.0, 10.0)),
			_rng.randf_range(0.55, 0.85)
		)
