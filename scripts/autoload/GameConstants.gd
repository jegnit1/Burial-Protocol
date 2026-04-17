extends Node

# 레이아웃과 카메라 fit 계산의 기준이 되는 기본 뷰포트 크기.
const VIEWPORT_SIZE := Vector2i(1920, 1080)
# 월드 설계의 기본 픽셀 단위. 1U는 이 픽셀 수와 같다.
const UNIT_SIZE := 64
# 게임플레이 그리드의 한 칸은 월드 1U와 동일하다.
const CELL_SIZE := UNIT_SIZE
# 중앙 샤프트 좌우에 있는 채굴 가능 벽의 두께(칸 수).
const WALL_COLUMNS := 10
# 비어 있는 중앙 샤프트의 너비(칸 수).
const CENTER_COLUMNS := 10
# 좌우 벽과 중앙 샤프트를 모두 포함한 월드 전체 가로 칸 수.
const WORLD_COLUMNS := CENTER_COLUMNS + WALL_COLUMNS * 2
# 월드 전체 세로 칸 수.
const WORLD_ROWS := 200
# 월드 맨 아래에 있는 고정 바닥 행의 인덱스.
const FLOOR_ROW := WORLD_ROWS - 1
# 월드 전체 가로 길이의 픽셀 값.
const WORLD_PIXEL_WIDTH := WORLD_COLUMNS * CELL_SIZE
# 월드 전체 세로 길이의 픽셀 값.
const WORLD_PIXEL_HEIGHT := WORLD_ROWS * CELL_SIZE
# 화면 상단 HUD 영역의 높이.
const HUD_HEIGHT := 256
# 화면 최상단과 HUD 패널 사이의 간격.
const HUD_TOP_PADDING := 40
# 뷰포트 좌우 가장자리에서 HUD 패널이 안쪽으로 들어오는 여백.
const HUD_SIDE_PADDING := 40
# HUD 패널 내부 여백.
const HUD_INNER_MARGIN := 32
# 위아래로 쌓이는 HUD 섹션 사이의 간격.
const HUD_SECTION_SPACING := 14
# HUD 상단 행 아이템들 사이의 가로 간격.
const HUD_ROW_SPACING := 52
# 골드, 체력 같은 주요 HUD 수치의 글자 크기.
const HUD_PRIMARY_FONT_SIZE := 48
# 상태 메시지 같은 보조 HUD 텍스트의 글자 크기.
const HUD_SECONDARY_FONT_SIZE := 38
# HUD 디버그 정보의 글자 크기.
const HUD_DEBUG_FONT_SIZE := 30
# HUD가 위에 들어갈 공간을 남기고 실제 월드가 시작되는 Y 오프셋.
const WORLD_TOP_MARGIN := HUD_HEIGHT + 64
# 뷰포트 내부에서 월드가 시작되는 X 오프셋.
const WORLD_SIDE_MARGIN := 64
# 화면 좌표계에서 월드 좌상단 원점 위치.
const WORLD_ORIGIN := Vector2i(WORLD_SIDE_MARGIN, WORLD_TOP_MARGIN)
# 카메라가 월드 바깥 여백을 아주 조금 포함해서 보여주도록 하는 비율.
const WORLD_CAMERA_FIT_MARGIN_RATIO := 0.98

# 월드 기준 플레이어의 충돌/표시 크기.
const PLAYER_SIZE := Vector2(128.0, 128.0)
# 샤프트 하단부 근처의 플레이어 시작 위치.
const PLAYER_SPAWN_POSITION := Vector2(
	WORLD_ORIGIN.x + CELL_SIZE * (WORLD_COLUMNS * 0.5),
	WORLD_ORIGIN.y + CELL_SIZE * (WORLD_ROWS - 5)
)
# 런 시작 시 플레이어의 최대 체력.
const PLAYER_MAX_HEALTH := 5
# 지상 이동 속도(px/s).
const PLAYER_MOVE_SPEED := 426.0
# 공중에서의 가로 이동 속도(px/s).
const PLAYER_AIR_SPEED := 373.0
# 모래 안에서 이동할 때 적용되는 속도 배율.
const PLAYER_SAND_SPEED_MULTIPLIER := 0.62
# 플레이어에게 적용되는 중력 가속도(px/s^2).
const PLAYER_GRAVITY := 2000.0
# 일반 점프 시 위쪽으로 주는 초기 속도.
const PLAYER_JUMP_SPEED := -853.0
# 바닥을 떠난 뒤 추가로 사용할 수 있는 점프 횟수.
const PLAYER_EXTRA_JUMPS := 1
# 벽 점프 시 적용되는 가로 방향 초기 속도.
const PLAYER_WALL_JUMP_SPEED_X := 480.0
# 빠른 낙하 중 추가로 더해지는 아래쪽 가속도.
const PLAYER_FAST_FALL_ACCELERATION := 2933.0
# 빠른 낙하 중 허용되는 최대 아래쪽 속도.
const PLAYER_FAST_FALL_SPEED := 1306.0
# 벽 슬라이드 중 제한되는 하강 속도.
const PLAYER_WALL_SLIDE_SPEED := 200.0
# 점프 입력을 미리 저장해두는 버퍼 시간.
const PLAYER_JUMP_BUFFER_TIME := 0.14
# 발판에서 떨어진 직후에도 점프가 허용되는 코요테 타임.
const PLAYER_COYOTE_TIME := 0.1
# 플레이어 기본 공격 1회의 피해량.
const PLAYER_ATTACK_DAMAGE := 10
# 플레이어 몸체 기준 공격 판정이 뻗는 거리 (1U).
const PLAYER_ATTACK_RANGE_WIDTH := float(CELL_SIZE)
const PLAYER_ATTACK_RANGE := PLAYER_ATTACK_RANGE_WIDTH
# 공격 판정 직사각형의 두께 (1U).
const PLAYER_ATTACK_RANGE_HEIGHT := float(CELL_SIZE)
const PLAYER_ATTACK_THICKNESS := PLAYER_ATTACK_RANGE_HEIGHT
# 연속 공격 사이의 최소 간격.
const PLAYER_ATTACK_COOLDOWN := 0.1
# 공격 입력을 미리 저장해두는 버퍼 시간.
const PLAYER_ATTACK_BUFFER_TIME := 0.12
# 공격 미리보기/피격 비주얼이 유지되는 시간.
const PLAYER_ATTACK_VISUAL_DURATION := 0.12
# 공격 방향으로 인정되기 위한 최소 입력 크기.
const PLAYER_ATTACK_DIRECTION_DEADZONE := 12.0
# 낙하 블록에 깔렸을 때 받는 피해량.
const PLAYER_CRUSH_DAMAGE := 1
# 피해를 받은 직후 적용되는 무적 시간.
const PLAYER_DAMAGE_INVULNERABILITY := 0.5

# 채굴 1회의 피해량 (현재 벽 1셀 기준).
const PLAYER_MINING_DAMAGE := 1
# 연속 채굴 사이의 최소 간격.
const PLAYER_MINING_COOLDOWN := 0.15
# 채굴 입력을 미리 저장해두는 버퍼 시간.
const PLAYER_MINING_BUFFER_TIME := 0.12
# 채굴 범위: 플레이어 몸체에서 뻗는 거리 (0.25U).
const PLAYER_MINING_RANGE_DISTANCE := float(CELL_SIZE) * 0.25
# 채굴 범위: 세로 높이 (1U).
const PLAYER_MINING_RANGE_HEIGHT := float(CELL_SIZE)
const PLAYER_UPWARD_SAND_CHECK_HEIGHT := 2.0
const PLAYER_DASH_DISTANCE := CELL_SIZE * 4.0
const PLAYER_DASH_DOUBLE_TAP_WINDOW := 0.22
const PLAYER_DASH_DURATION := 0.08
const PLAYER_DASH_COOLDOWN := 0.45
const PLAYER_DASH_DOWN_ENABLED := true
const PLAYER_DASH_UP_ENABLED := false
const SAND_CELL_MAX_HP := 3
const WALL_SUBCELL_MAX_HP := 3

# 낙하 블록의 낙하 속도(px/s).
const BLOCK_FALL_SPEED := 226.0
# 자동 낙하 블록 생성 간격(초).
const BLOCK_SPAWN_INTERVAL := 1.2
# 블록이 화면 바깥 위쪽에서 진입하도록 하는 생성 Y 오프셋.
const BLOCK_SPAWN_Y_OFFSET := 16.0

# 게임플레이 1U 안에 들어가는 모래 시뮬레이션 셀 개수.
const SAND_CELLS_PER_UNIT := 6
# 모래 시뮬레이션 셀 1칸의 픽셀 크기.
const SAND_CELL_SIZE := CELL_SIZE / SAND_CELLS_PER_UNIT
const WALL_SUBCELLS_PER_UNIT := 4
const WALL_SUBCELL_SIZE := CELL_SIZE / WALL_SUBCELLS_PER_UNIT
# 한 번의 계산에서 연쇄적으로 이어질 수 있는 모래 밀기 최대 횟수.
const SAND_PUSH_CHAIN_LIMIT := 9
# 시뮬레이션 한 틱마다 처리하는 모래 흐름 업데이트 수.
const SAND_FLOW_UPDATES_PER_TICK := 132
# 플레이어 주변에서 모래 시뮬레이션을 활성 상태로 유지하는 반경.
const SAND_ACTIVE_RADIUS := 3
const SAND_MINING_VERTICAL_ONLY_TICKS := 2
const SAND_MINING_ACTIVE_ABOVE_CELLS := 3
# 모래를 밀 때 전방으로 추가 확인하는 가로 셀 여유분.
const SAND_PUSH_FRONT_PADDING := 2
# 모래 밀기 해결 중 추가 확인하는 세로 셀 여유분.
const SAND_PUSH_VERTICAL_PADDING := 2
# 모래 밀기 해결 시 위쪽 이동을 선호하게 만드는 가중치.
const SAND_PUSH_UPWARD_BIAS := 2
# 한 번의 모래 밀기 해결에서 검토하는 후보 위치 최대 수.
const SAND_PUSH_CANDIDATE_LIMIT := 10
# 한 번의 모래 밀기 검증에서 검사하는 셀 최대 수.
const SAND_PUSH_CHECK_LIMIT := 24
# 한 번의 모래 밀기 해결에서 실제로 이동시키는 셀 최대 수.
const SAND_PUSH_MOVE_LIMIT := 6
# 플레이어가 모래에서 점프해 빠져나오기 위해 필요한 세로 여유 높이.
const SAND_JUMP_CLEAR_HEIGHT := 4
# 모래 점프 탈출 경로 계산 시 검토하는 후보 위치 최대 수.
const SAND_JUMP_CLEAR_CANDIDATE_LIMIT := 8
# 점프 탈출 가능 여부를 확인할 때 검사하는 셀 최대 수.
const SAND_JUMP_CLEAR_CHECK_LIMIT := 18
# 점프 경로를 비우기 위해 시도하는 모래 셀 이동 최대 수.
const SAND_JUMP_CLEAR_MOVE_LIMIT := 4
# 점프 경로 확보 실패 후 재시도까지 기다리는 프레임 수.
const SAND_JUMP_CLEAR_RETRY_DELAY_FRAMES := 2

# 월드 전체 바깥 배경색.
const WORLD_BACKGROUND_COLOR := Color("11161d")
# 중앙 개방 공간의 배경색.
const WORLD_CENTER_COLOR := Color("171f2a")
# 아직 채굴되지 않은 벽 셀 색상.
const WALL_CELL_COLOR := Color("344252")
# 채굴된 벽 영역에 사용할 색상.
const MINED_WALL_COLOR := Color("20262e")
# 월드 최하단 바닥 행의 색상.
const FLOOR_COLOR := Color("53616f")
# 기본 플레이어 색상.
const PLAYER_COLOR := Color("d4ede2")
# 플레이어 피격 시 잠깐 보여주는 색상.
const PLAYER_HURT_COLOR := Color("f58d7e")
# 공격 미리보기 오버레이에 쓰는 색상.
const ATTACK_PREVIEW_COLOR := Color(0.95, 0.35, 0.25, 0.32)
const MINING_PREVIEW_COLOR := Color(0.86, 0.78, 0.36, 0.28)
const MINING_DAMAGED_COLOR_RATIO := 0.28
# 디버그 패널 배경색.
const DEBUG_PANEL_COLOR := Color(0.05, 0.07, 0.09, 0.88)
# 디버그 패널 테두리 색상.
const DEBUG_BORDER_COLOR := Color("8392a6")
# 블록 피격 시 표시되는 데미지 팝업 글자 크기.
const DAMAGE_POPUP_FONT_SIZE := 40
# 데미지 팝업이 화면에 머무는 시간.
const DAMAGE_POPUP_LIFETIME := 0.55
# 데미지 팝업이 위로 떠오르는 속도(px/s).
const DAMAGE_POPUP_RISE_SPEED := 92.0
# 데미지 팝업이 좌우로 흔들리는 최대 거리(px).
const DAMAGE_POPUP_HORIZONTAL_JITTER := 22.0
# 데미지 팝업 본문 색상.
const DAMAGE_POPUP_TEXT_COLOR := Color("fff2cf")
# 데미지 팝업 그림자 색상.
const DAMAGE_POPUP_SHADOW_COLOR := Color(0.07, 0.05, 0.04, 0.88)

# 재질별 블록/모래 색상과 무게 설정.
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

const DEFAULT_BLOCK_BASE: StringName = &"rock"
const BLOCK_SPECIAL_RESULT_NONE: StringName = &"none"
const BLOCK_SPECIAL_RESULT_GLASS_SHATTER_DAMAGE: StringName = &"glass_shatter_damage"
const BLOCK_SPECIAL_RESULT_BONUS_GOLD: StringName = &"bonus_gold"
const BLOCK_SPECIAL_RESULT_EXPLOSION: StringName = &"explosion"

const BLOCK_BASES := {
	"glass": {
		"id": "glass",
		"display_name": "Glass",
		"color": Color("b8d8f4"),
		"spawn_weight": 1.0,
		"hp_multiplier": 1.0,
		"reward_multiplier": 1.0,
		"special_result_type": BLOCK_SPECIAL_RESULT_GLASS_SHATTER_DAMAGE,
	},
	"wood": {
		"id": "wood",
		"display_name": "Wood",
		"color": Color("9a6d43"),
		"spawn_weight": 1.1,
		"hp_multiplier": 1.0,
		"reward_multiplier": 1.0,
		"special_result_type": BLOCK_SPECIAL_RESULT_NONE,
	},
	"rock": {
		"id": "rock",
		"display_name": "Rock",
		"color": Color("7d8591"),
		"spawn_weight": 1.2,
		"hp_multiplier": 1.0,
		"reward_multiplier": 1.0,
		"special_result_type": BLOCK_SPECIAL_RESULT_NONE,
	},
	"marble": {
		"id": "marble",
		"display_name": "Marble",
		"color": Color("d9dde4"),
		"spawn_weight": 0.85,
		"hp_multiplier": 1.5,
		"reward_multiplier": 1.0,
		"special_result_type": BLOCK_SPECIAL_RESULT_NONE,
	},
	"gold": {
		"id": "gold",
		"display_name": "Gold",
		"color": Color("d7b94d"),
		"spawn_weight": 0.55,
		"hp_multiplier": 2.0,
		"reward_multiplier": 1.5,
		"special_result_type": BLOCK_SPECIAL_RESULT_BONUS_GOLD,
	},
	"cement": {
		"id": "cement",
		"display_name": "Cement",
		"color": Color("707983"),
		"spawn_weight": 0.9,
		"hp_multiplier": 2.0,
		"reward_multiplier": 1.0,
		"special_result_type": BLOCK_SPECIAL_RESULT_NONE,
	},
	"steel": {
		"id": "steel",
		"display_name": "Steel",
		"color": Color("5d6979"),
		"spawn_weight": 0.75,
		"hp_multiplier": 3.0,
		"reward_multiplier": 1.0,
		"special_result_type": BLOCK_SPECIAL_RESULT_NONE,
	},
	"bomb": {
		"id": "bomb",
		"display_name": "Bomb",
		"color": Color("d45858"),
		"spawn_weight": 0.5,
		"hp_multiplier": 1.5,
		"reward_multiplier": 1.0,
		"special_result_type": BLOCK_SPECIAL_RESULT_EXPLOSION,
	},
}

# 생성 시스템이 사용하는 낙하 블록 타입 정의.
const BLOCK_TYPES := [
	{
		"id": "amber_small",
		"size_cells": Vector2i(1, 1),
		"health": 8,
		"sand_units": 27,
		"reward": 2,
		"color_key": "amber",
		"spawn_weight": 1.0,
		"block_base": "glass",
	},
	{
		"id": "amber_tall_wood",
		"size_cells": Vector2i(1, 2),
		"health": 14,
		"sand_units": 54,
		"reward": 3,
		"color_key": "amber",
		"spawn_weight": 1.0,
		"block_base": "wood",
	},
	{
		"id": "cobalt_tall",
		"size_cells": Vector2i(1, 2),
		"health": 21,
		"sand_units": 54,
		"reward": 4,
		"color_key": "cobalt",
		"spawn_weight": 1.0,
		"block_base": "rock",
	},
	{
		"id": "cobalt_marble",
		"size_cells": Vector2i(2, 1),
		"health": 20,
		"sand_units": 54,
		"reward": 4,
		"color_key": "cobalt",
		"spawn_weight": 0.85,
		"block_base": "marble",
	},
	{
		"id": "cobalt_gold",
		"size_cells": Vector2i(1, 1),
		"health": 24,
		"sand_units": 27,
		"reward": 5,
		"color_key": "cobalt",
		"spawn_weight": 0.75,
		"block_base": "gold",
	},
	{
		"id": "ember_cement",
		"size_cells": Vector2i(1, 2),
		"health": 20,
		"sand_units": 54,
		"reward": 4,
		"color_key": "ember",
		"spawn_weight": 0.9,
		"block_base": "cement",
	},
	{
		"id": "ember_wide",
		"size_cells": Vector2i(2, 1),
		"health": 24,
		"sand_units": 54,
		"reward": 4,
		"color_key": "ember",
		"spawn_weight": 0.8,
		"block_base": "steel",
	},
	{
		"id": "ember_bomb",
		"size_cells": Vector2i(1, 1),
		"health": 14,
		"sand_units": 27,
		"reward": 3,
		"color_key": "ember",
		"spawn_weight": 0.65,
		"block_base": "bomb",
	},
]

# 런타임에 반드시 보장하는 기본 입력 바인딩 정의.
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
	"attack_action": [
		{"type": "mouse_button", "button_index": MOUSE_BUTTON_LEFT},
	],
	"mine_action": [
		{"type": "mouse_button", "button_index": MOUSE_BUTTON_RIGHT},
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


func get_block_base_definition(base_id: StringName) -> Dictionary:
	var resolved_base_id := base_id
	if resolved_base_id == StringName():
		resolved_base_id = DEFAULT_BLOCK_BASE
	if BLOCK_BASES.has(resolved_base_id):
		return BLOCK_BASES[resolved_base_id]
	return BLOCK_BASES[DEFAULT_BLOCK_BASE]


func get_block_type_spawn_weight(definition: Dictionary) -> float:
	var base_id := StringName(definition.get("block_base", DEFAULT_BLOCK_BASE))
	var base_definition := get_block_base_definition(base_id)
	var base_weight := float(base_definition.get("spawn_weight", 1.0))
	var type_weight := float(definition.get("spawn_weight", 1.0))
	return maxf(base_weight * type_weight, 0.0)


func pick_block_type_definition(rng: RandomNumberGenerator) -> Dictionary:
	var total_weight := 0.0
	for raw_definition in BLOCK_TYPES:
		var definition: Dictionary = raw_definition
		total_weight += get_block_type_spawn_weight(definition)
	if total_weight <= 0.0:
		return BLOCK_TYPES[0]
	var remaining_weight := rng.randf_range(0.0, total_weight)
	for raw_definition in BLOCK_TYPES:
		var definition: Dictionary = raw_definition
		remaining_weight -= get_block_type_spawn_weight(definition)
		if remaining_weight <= 0.0:
			return definition
	return BLOCK_TYPES[BLOCK_TYPES.size() - 1]


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


func is_point_inside_shape(point: Vector2, shape_data: Dictionary) -> bool:
	var local_point: Vector2 = (point - shape_data["center"]).rotated(-shape_data["rotation"])
	var half_size: Vector2 = shape_data["size"] * 0.5
	return absf(local_point.x) <= half_size.x and absf(local_point.y) <= half_size.y


func get_shape_bounds(shape_data: Dictionary) -> Rect2:
	var corners := get_shape_corners(shape_data)
	if corners.is_empty():
		return Rect2()
	var min_x := corners[0].x
	var max_x := corners[0].x
	var min_y := corners[0].y
	var max_y := corners[0].y
	for corner in corners:
		min_x = minf(min_x, corner.x)
		max_x = maxf(max_x, corner.x)
		min_y = minf(min_y, corner.y)
		max_y = maxf(max_y, corner.y)
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))


func get_shape_corners(shape_data: Dictionary) -> PackedVector2Array:
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


func get_block_color(color_key: StringName) -> Color:
	var config: Dictionary = SAND_COLOR_CONFIG.get(String(color_key), SAND_COLOR_CONFIG["amber"])
	return config["block_color"]


func get_sand_color(color_key: StringName) -> Color:
	var config: Dictionary = SAND_COLOR_CONFIG.get(String(color_key), SAND_COLOR_CONFIG["amber"])
	return config["sand_color"]


func get_sand_weight(color_key: StringName) -> float:
	var config: Dictionary = SAND_COLOR_CONFIG.get(String(color_key), SAND_COLOR_CONFIG["amber"])
	return config["weight"]
