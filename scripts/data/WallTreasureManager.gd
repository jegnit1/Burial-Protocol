extends Node2D
class_name WallTreasureManager

const MARKER_WIDTH_SUBCELLS := 2
const MARKER_HEIGHT_SUBCELLS := 2
const DEFAULT_MARKER_COUNT := 6
const MAX_PLACEMENT_ATTEMPTS_PER_MARKER := 200
const TREASURE_CHEST_MARKER_DATA_SCRIPT := preload("res://scripts/data/TreasureChestMarkerData.gd")
const PREVIEW_RARITY_COLORS := {
	"bronze": Color(0.92, 0.52, 0.24, 1.0),
	"silver": Color(0.78, 0.9, 1.0, 1.0),
	"gold": Color(1.0, 0.82, 0.24, 1.0),
	"platinum": Color(0.56, 1.0, 0.96, 1.0),
}
const REVEALED_QUADRANT_COLORS := {
	"bronze": Color(0.72, 0.45, 0.22, 0.92),
	"silver": Color(0.78, 0.84, 0.9, 0.92),
	"gold": Color(1.0, 0.77, 0.25, 0.94),
	"platinum": Color(0.65, 0.95, 1.0, 0.96),
}
const REVEALED_QUADRANT_BORDER_COLOR := Color(0.08, 0.06, 0.03, 0.72)
const FULLY_REVEALED_BORDER_COLOR := Color(1.0, 0.96, 0.72, 0.95)

const RARITY_ROLL_TABLE := [
	{"id": "bronze", "chance": 0.70},
	{"id": "silver", "chance": 0.22},
	{"id": "gold", "chance": 0.07},
	{"id": "platinum", "chance": 0.01},
]
const REWARD_RANK_ROLL_TABLES := {
	"bronze": [
		{"rank": "D", "chance": 0.80},
		{"rank": "C", "chance": 0.10},
		{"rank": "B", "chance": 0.06},
		{"rank": "A", "chance": 0.04},
		{"rank": "S", "chance": 0.00},
	],
	"silver": [
		{"rank": "D", "chance": 0.70},
		{"rank": "C", "chance": 0.15},
		{"rank": "B", "chance": 0.10},
		{"rank": "A", "chance": 0.05},
		{"rank": "S", "chance": 0.00},
	],
	"gold": [
		{"rank": "D", "chance": 0.55},
		{"rank": "C", "chance": 0.20},
		{"rank": "B", "chance": 0.10},
		{"rank": "A", "chance": 0.10},
		{"rank": "S", "chance": 0.05},
	],
	"platinum": [
		{"rank": "D", "chance": 0.40},
		{"rank": "C", "chance": 0.25},
		{"rank": "B", "chance": 0.15},
		{"rank": "A", "chance": 0.10},
		{"rank": "S", "chance": 0.10},
	],
}
const REWARD_RANK_FALLBACK_ORDER := ["D", "C", "B", "A", "S"]
const TREASURE_SELL_PRICE_RATE := 0.60

var markers: Array = []
var debug_draw_marker_outlines := true
var _preview_pulse_time := 0.0
var _prompt_label: Label
var _prompt_marker_id := ""


func setup() -> void:
	z_index = 16
	set_process(true)
	_ensure_prompt_label()
	clear_markers()


func _process(delta: float) -> void:
	_preview_pulse_time = fmod(_preview_pulse_time + delta, TAU)
	if not markers.is_empty():
		queue_redraw()


func clear_markers() -> void:
	markers.clear()
	queue_redraw()


func generate_markers_for_wall_reset(rng: RandomNumberGenerator, count := DEFAULT_MARKER_COUNT) -> Array:
	clear_markers()
	if rng == null or count <= 0:
		return markers
	var occupied := {}
	var side_sequence := _build_side_sequence(count)
	for index in range(count):
		var side := String(side_sequence[index])
		var marker = _create_marker_for_side(index, side, rng, occupied)
		if marker == null:
			push_warning("Failed to place treasure marker %d on %s wall." % [index, side])
			continue
		markers.append(marker)
		for key in marker.get_occupied_subcell_keys():
			occupied[key] = true
	queue_redraw()
	return markers


func get_marker_snapshots() -> Array[Dictionary]:
	var snapshots: Array[Dictionary] = []
	for marker in markers:
		snapshots.append(marker.to_snapshot())
	return snapshots


func get_marker_snapshot(marker) -> Dictionary:
	if marker == null:
		return {}
	return marker.to_snapshot()


func get_marker_by_id(marker_id: String):
	for marker in markers:
		if marker.marker_id == marker_id:
			return marker
	return null


func get_visual_debug_snapshot() -> Dictionary:
	var previews: Array[Dictionary] = []
	var revealed_quadrants: Array[Dictionary] = []
	for marker in markers:
		if marker.consumed:
			continue
		var preview_color: Color = _get_preview_color(marker.chest_rarity)
		var preview_rect := _get_marker_world_rect(marker)
		previews.append({
			"marker_id": marker.marker_id,
			"rarity": marker.chest_rarity,
			"visible_before_mining": true,
			"rect": _rect_to_snapshot(preview_rect),
			"color": _color_to_snapshot(preview_color),
		})
		for subcell in marker.get_revealed_global_subcells():
			revealed_quadrants.append({
				"marker_id": marker.marker_id,
				"subcell": {"x": subcell.x, "y": subcell.y},
				"rect": _rect_to_snapshot(_get_global_subcell_rect(subcell)),
				"color": _color_to_snapshot(_get_revealed_color(marker.chest_rarity)),
			})
	return {
		"preview_count": previews.size(),
		"revealed_quadrant_count": revealed_quadrants.size(),
		"debug_draw_marker_outlines": debug_draw_marker_outlines,
		"rarity_preview_palette": get_rarity_preview_palette_snapshot(),
		"previews": previews,
		"revealed_quadrants": revealed_quadrants,
	}


func get_rarity_preview_palette_snapshot() -> Dictionary:
	var result := {}
	for entry in RARITY_ROLL_TABLE:
		var row: Dictionary = entry
		var rarity := String(row["id"])
		result[rarity] = _color_to_snapshot(_get_preview_color(rarity))
	return result


func set_debug_draw_marker_outlines(enabled: bool) -> void:
	debug_draw_marker_outlines = enabled
	queue_redraw()


func update_interaction_prompt(player_position: Vector2, interaction_range: float, enabled := true):
	var marker = null
	if enabled:
		marker = get_nearest_interactable_marker(player_position, interaction_range)
	_set_prompt_marker(marker)
	return marker


func hide_interaction_prompt() -> void:
	_set_prompt_marker(null)


func get_interaction_debug_snapshot() -> Dictionary:
	return {
		"prompt_visible": _prompt_label != null and _prompt_label.visible,
		"prompt_marker_id": _prompt_marker_id,
	}


func get_marker_world_center(marker) -> Vector2:
	if marker == null:
		return Vector2.ZERO
	return _get_marker_world_center(marker)


func get_nearest_interactable_marker(player_position: Vector2, interaction_range: float):
	var best_marker = null
	var best_distance := INF
	for marker in markers:
		if not marker.is_interaction_available():
			continue
		var distance := player_position.distance_to(_get_marker_world_center(marker))
		if distance > interaction_range or distance >= best_distance:
			continue
		best_marker = marker
		best_distance = distance
	return best_marker


func handle_mined_wall_subcells(removed_subcells: Array) -> Dictionary:
	var newly_revealed_count := 0
	var updated_marker_ids: Array[String] = []
	var newly_fully_revealed_marker_ids: Array[String] = []
	for raw_subcell in removed_subcells:
		var subcell: Dictionary = raw_subcell
		var subcell_x := int(subcell.get("subcell_x", -1))
		var subcell_y := int(subcell.get("subcell_y", -1))
		for marker in markers:
			var was_fully_revealed := bool(marker.is_fully_revealed)
			if not marker.reveal_global_subcell(subcell_x, subcell_y):
				continue
			newly_revealed_count += 1
			if not updated_marker_ids.has(marker.marker_id):
				updated_marker_ids.append(marker.marker_id)
			if not was_fully_revealed and bool(marker.is_fully_revealed):
				newly_fully_revealed_marker_ids.append(marker.marker_id)
	if newly_revealed_count > 0:
		queue_redraw()
	return {
		"newly_revealed_count": newly_revealed_count,
		"updated_marker_ids": updated_marker_ids,
		"newly_fully_revealed_marker_ids": newly_fully_revealed_marker_ids,
	}


func get_rarity_roll_table() -> Array[Dictionary]:
	var table: Array[Dictionary] = []
	for entry in RARITY_ROLL_TABLE:
		table.append((entry as Dictionary).duplicate(true))
	return table


func get_reward_rank_roll_tables() -> Dictionary:
	var result := {}
	for rarity in REWARD_RANK_ROLL_TABLES.keys():
		var rows: Array[Dictionary] = []
		for entry in REWARD_RANK_ROLL_TABLES[rarity]:
			rows.append((entry as Dictionary).duplicate(true))
		result[rarity] = rows
	return result


func roll_chest_rarity(rng: RandomNumberGenerator) -> String:
	if rng == null:
		return "bronze"
	var roll := rng.randf()
	var cumulative := 0.0
	for entry in RARITY_ROLL_TABLE:
		var row: Dictionary = entry
		cumulative += float(row["chance"])
		if roll <= cumulative:
			return String(row["id"])
	return String((RARITY_ROLL_TABLE[RARITY_ROLL_TABLE.size() - 1] as Dictionary)["id"])


func roll_reward_rank(rng: RandomNumberGenerator, chest_rarity: String) -> String:
	if rng == null:
		return "D"
	var table: Array = REWARD_RANK_ROLL_TABLES.get(chest_rarity, REWARD_RANK_ROLL_TABLES["bronze"])
	var roll := rng.randf()
	var cumulative := 0.0
	var fallback := "D"
	for entry in table:
		var row: Dictionary = entry
		var rank := String(row.get("rank", fallback))
		fallback = rank
		cumulative += float(row.get("chance", 0.0))
		if roll <= cumulative:
			return rank
	return fallback


func validate_rarity_roll_table() -> Dictionary:
	var total := 0.0
	var ids: Array[String] = []
	var valid := true
	for entry in RARITY_ROLL_TABLE:
		var row: Dictionary = entry
		var rarity_id := String(row.get("id", ""))
		var chance := float(row.get("chance", -1.0))
		ids.append(rarity_id)
		total += chance
		if rarity_id.is_empty() or chance < 0.0:
			valid = false
	return {
		"ok": valid and absf(total - 1.0) <= 0.00001,
		"total": total,
		"ids": ids,
	}


func validate_reward_rank_roll_tables() -> Dictionary:
	var result := {}
	var all_ok := true
	for rarity in REWARD_RANK_ROLL_TABLES.keys():
		var total := 0.0
		var ranks: Array[String] = []
		var valid := true
		for entry in REWARD_RANK_ROLL_TABLES[rarity]:
			var row: Dictionary = entry
			var rank := String(row.get("rank", ""))
			var chance := float(row.get("chance", -1.0))
			ranks.append(rank)
			total += chance
			if rank.is_empty() or chance < 0.0:
				valid = false
		var ok := valid and absf(total - 1.0) <= 0.00001
		all_ok = all_ok and ok
		result[rarity] = {
			"ok": ok,
			"total": total,
			"ranks": ranks,
		}
	return {
		"ok": all_ok,
		"rarities": result,
	}


func prepare_reward_for_marker(marker) -> Dictionary:
	if marker == null:
		return {"ok": false, "reason": "missing_marker"}
	if marker.consumed:
		return {"ok": false, "reason": "consumed"}
	if not marker.is_fully_revealed:
		return {"ok": false, "reason": "not_fully_revealed"}
	if not String(marker.reward_item_id).is_empty():
		return _build_reward_snapshot(marker, marker.reward_rank != marker.reward_roll_rank)
	var reward_rng := RandomNumberGenerator.new()
	reward_rng.seed = int(marker.reward_seed)
	var rolled_rank := roll_reward_rank(reward_rng, marker.chest_rarity)
	var candidate_result := _get_reward_candidates_with_fallback(rolled_rank)
	var candidates: Array = candidate_result.get("candidates", [])
	if candidates.is_empty():
		push_warning("Treasure reward failed: no candidates for rank '%s'." % rolled_rank)
		return {
			"ok": false,
			"reason": "no_reward_candidates",
			"chest_rarity": marker.chest_rarity,
			"rolled_rank": rolled_rank,
		}
	var picked_index := reward_rng.randi_range(0, candidates.size() - 1)
	var picked_item: Dictionary = candidates[picked_index]
	marker.reward_roll_rank = rolled_rank
	marker.reward_rank = String(candidate_result.get("rank", rolled_rank))
	marker.reward_item_id = String(picked_item.get("item_id", ""))
	return _build_reward_snapshot(marker, bool(candidate_result.get("fallback_used", false)))


func consume_marker(marker_id: String) -> bool:
	var marker = get_marker_by_id(marker_id)
	if marker == null or marker.consumed:
		return false
	marker.consumed = true
	if _prompt_marker_id == marker.marker_id:
		_set_prompt_marker(null)
	queue_redraw()
	return true


func _get_reward_candidates_with_fallback(rolled_rank: String) -> Dictionary:
	var normalized_rank := rolled_rank.strip_edges().to_upper()
	var fallback_ranks := _build_reward_rank_fallback_sequence(normalized_rank)
	var game_data = _get_autoload_node("GameData")
	if game_data == null:
		return {
			"rank": normalized_rank,
			"fallback_used": false,
			"candidates": [],
		}
	var catalog = game_data.call("get_shop_item_catalog")
	for rank in fallback_ranks:
		var candidates: Array = catalog.get_reward_candidate_items_for_rank(rank)
		if candidates.is_empty():
			continue
		if rank != normalized_rank:
			push_warning("Treasure reward rank '%s' had no candidates; falling back to '%s'." % [normalized_rank, rank])
		return {
			"rank": rank,
			"fallback_used": rank != normalized_rank,
			"candidates": candidates,
		}
	return {
		"rank": normalized_rank,
		"fallback_used": false,
		"candidates": [],
	}


func _build_reward_rank_fallback_sequence(rolled_rank: String) -> Array[String]:
	var start_index := REWARD_RANK_FALLBACK_ORDER.find(rolled_rank)
	if start_index < 0:
		return REWARD_RANK_FALLBACK_ORDER.duplicate()
	var sequence: Array[String] = [rolled_rank]
	for index in range(start_index - 1, -1, -1):
		sequence.append(REWARD_RANK_FALLBACK_ORDER[index])
	for index in range(start_index + 1, REWARD_RANK_FALLBACK_ORDER.size()):
		sequence.append(REWARD_RANK_FALLBACK_ORDER[index])
	return sequence


func _build_reward_snapshot(marker, fallback_used: bool) -> Dictionary:
	var game_data = _get_autoload_node("GameData")
	var game_state = _get_autoload_node("GameState")
	if game_data == null or game_state == null:
		return {
			"ok": false,
			"reason": "missing_autoload",
			"marker_id": marker.marker_id,
			"item_id": marker.reward_item_id,
		}
	var definition: Dictionary = game_data.call("get_shop_item_definition", StringName(marker.reward_item_id))
	if definition.is_empty():
		return {
			"ok": false,
			"reason": "missing_reward_definition",
			"marker_id": marker.marker_id,
			"item_id": marker.reward_item_id,
		}
	var buy_price := int(game_state.call("get_effective_shop_item_price", definition))
	var sell_price := int(floor(float(buy_price) * TREASURE_SELL_PRICE_RATE))
	return {
		"ok": true,
		"marker_id": marker.marker_id,
		"chest_rarity": marker.chest_rarity,
		"rolled_rank": marker.reward_roll_rank,
		"rank": marker.reward_rank,
		"fallback_used": fallback_used,
		"item_id": String(definition.get("item_id", marker.reward_item_id)),
		"name": String(definition.get("name", marker.reward_item_id)),
		"item_category": String(definition.get("item_category", "")),
		"short_desc": String(definition.get("short_desc", "")),
		"desc": String(definition.get("desc", "")),
		"buy_price": buy_price,
		"sell_price": sell_price,
	}


func _get_autoload_node(node_name: String):
	var main_loop := Engine.get_main_loop()
	if main_loop is SceneTree:
		return (main_loop as SceneTree).root.get_node_or_null(node_name)
	return null


func validate_markers() -> Dictionary:
	var errors: Array[String] = []
	var occupied := {}
	for marker in markers:
		if marker.width_subcells != MARKER_WIDTH_SUBCELLS or marker.height_subcells != MARKER_HEIGHT_SUBCELLS:
			errors.append("%s has invalid size %dx%d" % [marker.marker_id, marker.width_subcells, marker.height_subcells])
		if not _is_valid_side(marker.wall_side):
			errors.append("%s has invalid side %s" % [marker.marker_id, marker.wall_side])
		if not _is_marker_inside_side_bounds(marker):
			errors.append("%s is out of %s wall bounds" % [marker.marker_id, marker.wall_side])
		if _touches_world_row_zero(marker):
			errors.append("%s touches world row 0" % marker.marker_id)
		for key in marker.get_occupied_subcell_keys():
			if occupied.has(key):
				errors.append("%s overlaps subcell %s" % [marker.marker_id, key])
			occupied[key] = marker.marker_id
	return {
		"ok": errors.is_empty(),
		"errors": errors,
		"count": markers.size(),
	}


func _create_marker_for_side(index: int, side: String, rng: RandomNumberGenerator, occupied: Dictionary):
	var bounds := _get_side_subcell_bounds(side)
	if bounds.is_empty():
		return null
	for _attempt in range(MAX_PLACEMENT_ATTEMPTS_PER_MARKER):
		var origin_x := rng.randi_range(int(bounds["min_x"]), int(bounds["max_x"]))
		var origin_y := rng.randi_range(int(bounds["min_y"]), int(bounds["max_y"]))
		if _would_overlap(origin_x, origin_y, occupied):
			continue
		var marker_id := "treasure_%04d" % (index + 1)
		var marker = TREASURE_CHEST_MARKER_DATA_SCRIPT.new()
		marker.setup(
			marker_id,
			roll_chest_rarity(rng),
			side,
			origin_x,
			origin_y,
			rng.randi()
		)
		return marker
	return null


func _build_side_sequence(count: int) -> Array[String]:
	var sequence: Array[String] = []
	for index in range(count):
		sequence.append("left" if index % 2 == 0 else "right")
	return sequence


func _get_side_subcell_bounds(side: String) -> Dictionary:
	var subcells_per_unit := GameConstants.WALL_SUBCELLS_PER_UNIT
	var min_y := subcells_per_unit
	var max_y := GameConstants.FLOOR_ROW * subcells_per_unit - MARKER_HEIGHT_SUBCELLS
	if side == "left":
		return {
			"min_x": 0,
			"max_x": GameConstants.WALL_COLUMNS * subcells_per_unit - MARKER_WIDTH_SUBCELLS,
			"min_y": min_y,
			"max_y": max_y,
		}
	if side == "right":
		return {
			"min_x": (GameConstants.WORLD_COLUMNS - GameConstants.WALL_COLUMNS) * subcells_per_unit,
			"max_x": GameConstants.WORLD_COLUMNS * subcells_per_unit - MARKER_WIDTH_SUBCELLS,
			"min_y": min_y,
			"max_y": max_y,
		}
	return {}


func _is_marker_inside_side_bounds(marker) -> bool:
	var bounds := _get_side_subcell_bounds(marker.wall_side)
	if bounds.is_empty():
		return false
	return (
		marker.origin_subcell_x >= int(bounds["min_x"])
		and marker.origin_subcell_x <= int(bounds["max_x"])
		and marker.origin_subcell_y >= int(bounds["min_y"])
		and marker.origin_subcell_y <= int(bounds["max_y"])
	)


func _touches_world_row_zero(marker) -> bool:
	return marker.origin_subcell_y < GameConstants.WALL_SUBCELLS_PER_UNIT


func _would_overlap(origin_x: int, origin_y: int, occupied: Dictionary) -> bool:
	for local_y in range(MARKER_HEIGHT_SUBCELLS):
		for local_x in range(MARKER_WIDTH_SUBCELLS):
			if occupied.has("%d,%d" % [origin_x + local_x, origin_y + local_y]):
				return true
	return false


func _is_valid_side(side: String) -> bool:
	return side == "left" or side == "right"


func _draw() -> void:
	for marker in markers:
		if marker.consumed:
			continue
		_draw_marker_preview(marker)
		_draw_marker_revealed_quadrants(marker)


func _draw_marker_preview(marker) -> void:
	var rect := _get_marker_world_rect(marker)
	var base_color := _get_preview_color(marker.chest_rarity)
	var pulse := 0.5 + sin(_preview_pulse_time * 2.4) * 0.5
	var glow_color := Color(base_color.r, base_color.g, base_color.b, 0.09 + pulse * 0.05)
	var outline_color := Color(base_color.r, base_color.g, base_color.b, 0.56 + pulse * 0.22)
	var inner_color := Color(base_color.r, base_color.g, base_color.b, 0.26 + pulse * 0.12)
	draw_rect(rect.grow(5.0), Color(base_color.r, base_color.g, base_color.b, 0.05 + pulse * 0.04))
	draw_rect(rect.grow(1.0), glow_color)
	draw_rect(rect.grow(-2.0), outline_color, false, 3.0)
	draw_rect(rect.grow(-7.0), inner_color, false, 1.0)
	var center_x := rect.position.x + rect.size.x * 0.5
	var center_y := rect.position.y + rect.size.y * 0.5
	draw_line(Vector2(center_x, rect.position.y + 6.0), Vector2(center_x, rect.end.y - 6.0), Color(base_color.r, base_color.g, base_color.b, 0.24), 1.0)
	draw_line(Vector2(rect.position.x + 6.0, center_y), Vector2(rect.end.x - 6.0, center_y), Color(base_color.r, base_color.g, base_color.b, 0.24), 1.0)
	if debug_draw_marker_outlines:
		draw_rect(rect, Color(base_color.r, base_color.g, base_color.b, 0.9), false, 1.0)


func _draw_marker_revealed_quadrants(marker) -> void:
	var color := _get_revealed_color(marker.chest_rarity)
	for subcell in marker.get_revealed_global_subcells():
		var rect := _get_global_subcell_rect(subcell)
		draw_rect(rect.grow(-3.0), color)
		draw_rect(rect.grow(-3.0), REVEALED_QUADRANT_BORDER_COLOR, false, 2.0)
	if marker.is_fully_revealed:
		draw_rect(_get_marker_world_rect(marker).grow(-1.0), FULLY_REVEALED_BORDER_COLOR, false, 4.0)


func _get_preview_color(rarity: String) -> Color:
	return PREVIEW_RARITY_COLORS.get(rarity, PREVIEW_RARITY_COLORS["bronze"])


func _get_revealed_color(rarity: String) -> Color:
	return REVEALED_QUADRANT_COLORS.get(rarity, REVEALED_QUADRANT_COLORS["bronze"])


func _get_marker_world_rect(marker) -> Rect2:
	return Rect2(
		Vector2(GameConstants.WORLD_ORIGIN) + Vector2(marker.origin_subcell_x, marker.origin_subcell_y) * GameConstants.WALL_SUBCELL_SIZE,
		Vector2(marker.width_subcells, marker.height_subcells) * GameConstants.WALL_SUBCELL_SIZE
	)


func _get_marker_world_center(marker) -> Vector2:
	return _get_marker_world_rect(marker).get_center()


func _get_global_subcell_rect(subcell: Vector2i) -> Rect2:
	return Rect2(
		Vector2(GameConstants.WORLD_ORIGIN) + Vector2(subcell) * GameConstants.WALL_SUBCELL_SIZE,
		Vector2.ONE * GameConstants.WALL_SUBCELL_SIZE
	)


func _rect_to_snapshot(rect: Rect2) -> Dictionary:
	return {
		"x": rect.position.x,
		"y": rect.position.y,
		"w": rect.size.x,
		"h": rect.size.y,
	}


func _color_to_snapshot(color: Color) -> Dictionary:
	return {
		"r": color.r,
		"g": color.g,
		"b": color.b,
		"a": color.a,
	}


func _ensure_prompt_label() -> void:
	if _prompt_label != null:
		return
	_prompt_label = Label.new()
	_prompt_label.text = "E - TREASURE"
	_prompt_label.visible = false
	_prompt_label.z_index = 18
	_prompt_label.add_theme_font_size_override("font_size", 20)
	_prompt_label.add_theme_color_override("font_color", Color("fff1a8"))
	_prompt_label.add_theme_color_override("font_shadow_color", Color(0.03, 0.02, 0.01, 0.95))
	_prompt_label.add_theme_constant_override("shadow_offset_x", 2)
	_prompt_label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(_prompt_label)


func _set_prompt_marker(marker) -> void:
	_ensure_prompt_label()
	if marker == null:
		_prompt_marker_id = ""
		_prompt_label.visible = false
		return
	_prompt_marker_id = marker.marker_id
	var rect := _get_marker_world_rect(marker)
	_prompt_label.text = "E - TREASURE"
	_prompt_label.position = Vector2(rect.position.x - 22.0, rect.position.y - 30.0)
	_prompt_label.visible = true
