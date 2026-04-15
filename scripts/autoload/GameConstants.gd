extends Node

const VIEWPORT_SIZE := Vector2i(1920, 1664)
const UNIT_SIZE := 64
const CELL_SIZE := UNIT_SIZE
const WALL_COLUMNS := 10
const CENTER_COLUMNS := 10
const WORLD_COLUMNS := CENTER_COLUMNS + WALL_COLUMNS * 2
const WORLD_ROWS := 26
const FLOOR_ROW := WORLD_ROWS - 1
const WORLD_PIXEL_WIDTH := WORLD_COLUMNS * CELL_SIZE
const WORLD_PIXEL_HEIGHT := WORLD_ROWS * CELL_SIZE
const HUD_HEIGHT := 256
const HUD_TOP_PADDING := 40
const HUD_SIDE_PADDING := 40
const HUD_INNER_MARGIN := 32
const HUD_SECTION_SPACING := 14
const HUD_ROW_SPACING := 52
const HUD_PRIMARY_FONT_SIZE := 48
const HUD_SECONDARY_FONT_SIZE := 38
const HUD_DEBUG_FONT_SIZE := 30
const WORLD_TOP_MARGIN := HUD_HEIGHT + 64
const WORLD_SIDE_MARGIN := 64
const WORLD_ORIGIN := Vector2i(WORLD_SIDE_MARGIN, WORLD_TOP_MARGIN)
const WORLD_CAMERA_FIT_MARGIN_RATIO := 0.98

const PLAYER_SIZE := Vector2(float(CELL_SIZE), float(CELL_SIZE))
const PLAYER_SPAWN_POSITION := Vector2(
	WORLD_ORIGIN.x + CELL_SIZE * (WORLD_COLUMNS * 0.5),
	WORLD_ORIGIN.y + CELL_SIZE * 22.0
)
const PLAYER_MAX_HEALTH := 5
const PLAYER_MOVE_SPEED := 426.0
const PLAYER_AIR_SPEED := 373.0
const PLAYER_SAND_SPEED_MULTIPLIER := 0.62
const PLAYER_GRAVITY := 2000.0
const PLAYER_JUMP_SPEED := -853.0
const PLAYER_EXTRA_JUMPS := 1
const PLAYER_WALL_JUMP_SPEED_X := 480.0
const PLAYER_FAST_FALL_ACCELERATION := 2933.0
const PLAYER_FAST_FALL_SPEED := 1306.0
const PLAYER_WALL_SLIDE_SPEED := 200.0
const PLAYER_JUMP_BUFFER_TIME := 0.14
const PLAYER_COYOTE_TIME := 0.1
const PLAYER_ATTACK_DAMAGE := 1
const PLAYER_ATTACK_RANGE := float(CELL_SIZE)
const PLAYER_ATTACK_THICKNESS := float(CELL_SIZE)
const PLAYER_ATTACK_COOLDOWN := 0.1
const PLAYER_ATTACK_BUFFER_TIME := 0.12
const PLAYER_ATTACK_VISUAL_DURATION := 0.12
const PLAYER_ATTACK_DIRECTION_DEADZONE := 12.0
const PLAYER_CRUSH_DAMAGE := 1
const PLAYER_DAMAGE_INVULNERABILITY := 0.5

const BLOCK_FALL_SPEED := 226.0
const BLOCK_SPAWN_INTERVAL := 1.2
const BLOCK_SPAWN_Y_OFFSET := 16.0

const SAND_CELLS_PER_UNIT := 6
const SAND_CELL_SIZE := CELL_SIZE / SAND_CELLS_PER_UNIT
const SAND_PUSH_CHAIN_LIMIT := 9
const SAND_FLOW_UPDATES_PER_TICK := 132
const SAND_ACTIVE_RADIUS := 3
const SAND_PUSH_FRONT_PADDING := 2
const SAND_PUSH_VERTICAL_PADDING := 2
const SAND_PUSH_UPWARD_BIAS := 2
const SAND_PUSH_CANDIDATE_LIMIT := 10
const SAND_PUSH_CHECK_LIMIT := 24
const SAND_PUSH_MOVE_LIMIT := 6
const SAND_JUMP_CLEAR_HEIGHT := 4
const SAND_JUMP_CLEAR_CANDIDATE_LIMIT := 8
const SAND_JUMP_CLEAR_CHECK_LIMIT := 18
const SAND_JUMP_CLEAR_MOVE_LIMIT := 4
const SAND_JUMP_CLEAR_RETRY_DELAY_FRAMES := 2

const WORLD_BACKGROUND_COLOR := Color("11161d")
const WORLD_CENTER_COLOR := Color("171f2a")
const WALL_CELL_COLOR := Color("344252")
const MINED_WALL_COLOR := Color("20262e")
const FLOOR_COLOR := Color("53616f")
const PLAYER_COLOR := Color("d4ede2")
const PLAYER_HURT_COLOR := Color("f58d7e")
const ATTACK_PREVIEW_COLOR := Color(0.95, 0.35, 0.25, 0.32)
const DEBUG_PANEL_COLOR := Color(0.05, 0.07, 0.09, 0.88)
const DEBUG_BORDER_COLOR := Color("8392a6")

const SAND_COLOR_CONFIG := {
	"amber": {
		"block_color": Color("e7b34a"),
		"sand_color": Color("f0c768"),
		"weight": 1.0,
	},
	"cobalt": {
		"block_color": Color("6a8be8"),
		"sand_color": Color("88a6f2"),
		"weight": 1.2,
	},
	"ember": {
		"block_color": Color("dd7250"),
		"sand_color": Color("ee9474"),
		"weight": 1.4,
	},
}

const BLOCK_TYPES := [
	{
		"id": "amber_small",
		"size_cells": Vector2i(1, 1),
		"health": 1,
		"sand_units": 27,
		"reward": 2,
		"color_key": "amber",
	},
	{
		"id": "cobalt_tall",
		"size_cells": Vector2i(1, 2),
		"health": 2,
		"sand_units": 54,
		"reward": 4,
		"color_key": "cobalt",
	},
	{
		"id": "ember_wide",
		"size_cells": Vector2i(2, 1),
		"health": 2,
		"sand_units": 54,
		"reward": 4,
		"color_key": "ember",
	},
]

const INPUT_BINDINGS := {
	"move_left": [
		{"type": "key", "code": KEY_A},
		{"type": "key", "code": KEY_LEFT},
	],
	"move_right": [
		{"type": "key", "code": KEY_D},
		{"type": "key", "code": KEY_RIGHT},
	],
	"jump": [
		{"type": "key", "code": KEY_W},
		{"type": "key", "code": KEY_UP},
		{"type": "key", "code": KEY_SPACE},
	],
	"move_down": [
		{"type": "key", "code": KEY_S},
		{"type": "key", "code": KEY_DOWN},
	],
	"primary_action": [
		{"type": "mouse_button", "button_index": MOUSE_BUTTON_LEFT},
	],
	"restart": [
		{"type": "key", "code": KEY_R},
	],
	"ui_toggle_status": [
		{"type": "key", "code": KEY_TAB},
	],
}


func _ready() -> void:
	ensure_input_actions()


func ensure_input_actions() -> void:
	for action_name in INPUT_BINDINGS.keys():
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		for binding in INPUT_BINDINGS[action_name]:
			var binding_data: Dictionary = binding
			if _has_input_binding(action_name, binding_data):
				continue
			InputMap.action_add_event(action_name, _create_input_event(binding_data))


func _has_input_binding(action_name: StringName, binding: Dictionary) -> bool:
	for raw_event in InputMap.action_get_events(action_name):
		if binding["type"] == "key" and raw_event is InputEventKey:
			if raw_event.physical_keycode == binding["code"]:
				return true
		if binding["type"] == "mouse_button" and raw_event is InputEventMouseButton:
			if raw_event.button_index == binding["button_index"]:
				return true
	return false


func _create_input_event(binding: Dictionary) -> InputEvent:
	if binding["type"] == "mouse_button":
		var mouse_event := InputEventMouseButton.new()
		mouse_event.button_index = binding["button_index"]
		return mouse_event
	var key_event := InputEventKey.new()
	key_event.keycode = binding["code"]
	key_event.physical_keycode = binding["code"]
	return key_event


func get_world_rect() -> Rect2:
	return Rect2(
		Vector2(WORLD_ORIGIN),
		Vector2(WORLD_PIXEL_WIDTH, WORLD_PIXEL_HEIGHT)
	)


func get_center_rect() -> Rect2:
	return Rect2(
		Vector2(WORLD_ORIGIN.x + WALL_COLUMNS * CELL_SIZE, WORLD_ORIGIN.y),
		Vector2(CENTER_COLUMNS * CELL_SIZE, WORLD_PIXEL_HEIGHT)
	)


func get_block_color(color_key: StringName) -> Color:
	var config: Dictionary = SAND_COLOR_CONFIG.get(String(color_key), SAND_COLOR_CONFIG["amber"])
	return config["block_color"]


func get_sand_color(color_key: StringName) -> Color:
	var config: Dictionary = SAND_COLOR_CONFIG.get(String(color_key), SAND_COLOR_CONFIG["amber"])
	return config["sand_color"]


func get_sand_weight(color_key: StringName) -> float:
	var config: Dictionary = SAND_COLOR_CONFIG.get(String(color_key), SAND_COLOR_CONFIG["amber"])
	return config["weight"]
