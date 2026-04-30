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
const WORLD_CAMERA_ZOOM := 0.75
# 화면 상단 HUD 영역의 높이.
const HUD_HEIGHT := 208
# 화면 최상단과 HUD 패널 사이의 간격.
const HUD_TOP_PADDING := 24
# 뷰포트 좌우 가장자리에서 HUD 패널이 안쪽으로 들어오는 여백.
const HUD_SIDE_PADDING := 24
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
const WORLD_TOP_MARGIN := HUD_HEIGHT + 40
# 뷰포트 내부에서 월드가 시작되는 X 오프셋.
const WORLD_SIDE_MARGIN := 32
# 화면 좌표계에서 월드 좌상단 원점 위치.
const WORLD_ORIGIN := Vector2i(WORLD_SIDE_MARGIN, WORLD_TOP_MARGIN)
# 카메라가 월드 바깥 여백을 아주 조금 포함해서 보여주도록 하는 비율.
const WORLD_CAMERA_FIT_MARGIN_RATIO := 0.98
const WORLD_PLAYABLE_TOP_EXTRA_SCREEN_MULTIPLIER := 2.0
const WORLD_PLAYABLE_TOP_Y := float(WORLD_ORIGIN.y) - float(VIEWPORT_SIZE.y) * WORLD_PLAYABLE_TOP_EXTRA_SCREEN_MULTIPLIER
const PLAYER_WALL_CLIMB_TOP_GUARD_UNITS := 4.0
const PLAYER_WALL_CLIMB_TOP_LIMIT_Y := WORLD_PLAYABLE_TOP_Y + float(CELL_SIZE) * PLAYER_WALL_CLIMB_TOP_GUARD_UNITS
const BLOCK_SPAWN_MIN_CAMERA_TOP_Y := WORLD_PLAYABLE_TOP_Y

# 월드 기준 플레이어의 충돌/표시 크기.
const PLAYER_SIZE := Vector2(128.0, 128.0)
# 샤프트 하단부 근처의 플레이어 시작 위치.
const PLAYER_SPAWN_POSITION := Vector2(
	WORLD_ORIGIN.x + CELL_SIZE * (WORLD_COLUMNS * 0.5),
	WORLD_ORIGIN.y + CELL_SIZE * (WORLD_ROWS - 5)
)
# 런 시작 시 플레이어의 최대 체력.
const PLAYER_MAX_HEALTH := 100
const PLAYER_BASE_CRIT_CHANCE := 0.01
const PLAYER_CRIT_DAMAGE_MULTIPLIER := 2.0
const PLAYER_BASE_HP_REGEN := 0.0
const PLAYER_TEST_HP_REGEN_BONUS := 10.0
const PLAYER_BASE_DEFENSE := 0
const PLAYER_BASE_LUCK := 0.0
const STAGE_INTEREST_RATE := 0.10
const PLAYER_ATTACK_RANGE_MULTIPLIER := 1.0
const PLAYER_MINING_RANGE_MULTIPLIER := 1.0
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
const PLAYER_BATTERY_MAX := 100.0
const PLAYER_WALL_CLIMB_DRAIN_PER_SEC := 5.0
const PLAYER_BATTERY_RECOVERY_PER_SEC := 5.0
const PLAYER_WALL_CLIMB_FALL_SPEED := 110.0
const PLAYER_WALL_CLIMB_INPUT_DEADZONE := 0.25
# 빠른 낙하 중 추가로 더해지는 아래쪽 가속도.
const PLAYER_FAST_FALL_ACCELERATION := 2933.0
# 빠른 낙하 중 허용되는 최대 아래쪽 속도.
const PLAYER_FAST_FALL_SPEED := 1306.0
# 벽 슬라이드 중 제한되는 하강 속도.
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
const PLAYER_ATTACK_COOLDOWN := 0.30
# 공격 입력을 미리 저장해두는 버퍼 시간.
const PLAYER_ATTACK_BUFFER_TIME := 0.12
# 공격 미리보기/피격 비주얼이 유지되는 시간.
const PLAYER_ATTACK_VISUAL_DURATION := 0.12
# 공격 방향으로 인정되기 위한 최소 입력 크기.
const PLAYER_ATTACK_DIRECTION_DEADZONE := 12.0
# 공격모듈은 전투 규칙상 슬롯 순서 의미 없이 최대 5개까지 장착한다.
const ATTACK_MODULE_MAX_EQUIPPED := 5
const ATTACK_MODULE_GRADE_ORDER := ["D", "C", "B", "A", "S"]
const ATTACK_MODULE_GRADE_DAMAGE_MULTIPLIERS := {
	"D": 1.0,
	"C": 1.15,
	"B": 1.35,
	"A": 1.6,
	"S": 2.0,
}
const ATTACK_MODULE_GRADE_SPEED_MULTIPLIERS := {
	"D": 1.0,
	"C": 1.05,
	"B": 1.1,
	"A": 1.15,
	"S": 1.25,
}
const ATTACK_MODULE_GRADE_RANGE_MULTIPLIERS := {
	"D": 1.0,
	"C": 1.05,
	"B": 1.1,
	"A": 1.15,
	"S": 1.25,
}
# 낙하 블록 1U당 플레이어가 받는 피해량.
const BLOCK_DAMAGE_PER_UNIT := 10
# 피해를 받은 직후 적용되는 무적 시간.
const PLAYER_DAMAGE_INVULNERABILITY := 0.5
# 맞는 순간 붉게 점멸하는 강한 피격 연출 시간.
const PLAYER_HURT_FLASH_DURATION := 0.12
# 무적 시간 동안 흰색 점멸이 반복되는 간격.
const PLAYER_INVULN_FLASH_INTERVAL := 0.08

# 채굴 1회의 피해량 (현재 벽 1셀 기준).
const PLAYER_MINING_DAMAGE := 1
# 연속 채굴 사이의 최소 간격.
const PLAYER_MINING_COOLDOWN := 0.15
# 채굴 입력을 미리 저장해두는 버퍼 시간.
const PLAYER_MINING_BUFFER_TIME := 0.12
# 채굴 실패/불가 상태 문구가 과도하게 반복되지 않도록 두는 최소 간격.
const PLAYER_MINING_STATUS_MESSAGE_INTERVAL := 0.3
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
const BLOCK_FALL_SPEED := 330.0
# 자동 낙하 블록 생성 간격(초).
const BLOCK_SPAWN_INTERVAL := 1.2
const BLOCK_SPAWN_BAND_NEAR_UNITS := 2.0
const BLOCK_SPAWN_BAND_FAR_UNITS := 6.0
const BLOCK_SPAWN_POSITION_ATTEMPTS := 24
const BLOCK_SPAWN_ACTIVE_BLOCK_CLEARANCE_UNITS := 0.5
const DAY_INTERMISSION_GRACE_DURATION := 3.0
const DAY_KIOSK_INTERACTION_RANGE := CELL_SIZE * 2.0
const DAY_KIOSK_DEPLOY_DELAY := 1.25
const DAY_KIOSK_FALL_SPEED := 780.0
const DAY_TRANSITION_FADE_DURATION := 0.35
const DAY_SHOP_ITEM_COUNT := 5
const SHOP_REROLL_BASE_COST := 50
const SHOP_REROLL_COST_INCREMENT := 25
# 상점 아이템 랭크별 기본 가격. price_gold가 0이면 이 값을 fallback으로 사용한다.
const SHOP_ITEM_RANK_FALLBACK_PRICES := {
	"D": 15,
	"C": 30,
	"B": 60,
	"A": 120,
	"S": 240,
}
# 1U당 블록 체력
const BLOCK_HP_PER_UNIT := 10.0
# 1U당 블록 보상
const BLOCK_REWARD_PER_UNIT := 5.0
const BLOCK_SAND_UNITS_PER_UNIT := 36.0
const BLOCK_DESTROY_XP_PER_UNIT := 18
const SAND_REMOVED_CELLS_PER_XP := 4
# 블록이 화면 바깥 위쪽에서 진입하도록 하는 생성 Y 오프셋.
const BLOCK_SPAWN_Y_OFFSET := 16.0

# 게임플레이 1U 안에 들어가는 모래 시뮬레이션 셀 개수.
const SAND_CELLS_PER_UNIT := 6
# 모래 시뮬레이션 셀 1칸의 픽셀 크기.
const SAND_CELL_SIZE := float(CELL_SIZE) / float(SAND_CELLS_PER_UNIT)
const WALL_SUBCELLS_PER_UNIT := 4
const WALL_SUBCELL_SIZE := float(CELL_SIZE) / float(WALL_SUBCELLS_PER_UNIT)
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

# 게임 오버 조건이 되는 모래 셀의 최대 개수 (최대 무게 한도).
const WEIGHT_LIMIT_SAND_CELLS := 2400
# HUD에 표시할 때 모래 셀 하나를 몇 KG로 환산할지.
const DISPLAY_WEIGHT_PER_SAND_CELL := 0.1
const DISPLAY_WEIGHT_UNIT := "KG"
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
const PLAYER_HURT_FLASH_COLOR := Color("ff6262")
const PLAYER_INVULN_FLASH_COLOR := Color("fff8ef")
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
const CRITICAL_DAMAGE_POPUP_TEXT_COLOR := Color("ffe066")
const CRITICAL_DAMAGE_POPUP_SHADOW_COLOR := Color(0.23, 0.16, 0.02, 0.92)
const PLAYER_DAMAGE_POPUP_TEXT_COLOR := Color("ff7676")
const PLAYER_DAMAGE_POPUP_SHADOW_COLOR := Color(0.18, 0.03, 0.03, 0.92)

# 피격 시 블록 위에 표시되는 HP 바 오버레이 지속 시간(초). 추가 피격 시 갱신된다.
const BLOCK_HP_OVERLAY_DURATION := 1.2
# HP 바와 블록 상단 사이의 간격(px).
const BLOCK_HP_OVERLAY_TOP_MARGIN := 5.0
# HP 바의 두께(px).
const BLOCK_HP_BAR_HEIGHT := 7.0
# HP 바 배경 색상.
const BLOCK_HP_BAR_BG_COLOR := Color(0.08, 0.08, 0.08, 0.85)
# HP 비율이 높을 때(100%) 바 채움 색상.
const BLOCK_HP_BAR_HIGH_COLOR := Color(0.3, 0.88, 0.35, 1.0)
# HP 비율이 낮을 때(0%) 바 채움 색상.
const BLOCK_HP_BAR_LOW_COLOR := Color(0.9, 0.22, 0.18, 1.0)
# HP 바 테두리 색상.
const BLOCK_HP_BAR_BORDER_COLOR := Color(0.0, 0.0, 0.0, 0.9)

# 골드 획득 팝업 글자 크기.
const GOLD_POPUP_FONT_SIZE := 36
# 골드 획득 팝업이 화면에 머무는 시간(초).
const GOLD_POPUP_LIFETIME := 1.0
# 골드 획득 팝업이 위로 떠오르는 속도(px/s).
const GOLD_POPUP_RISE_SPEED := 80.0
# 골드 획득 팝업 본문 색상.
const GOLD_POPUP_TEXT_COLOR := Color(1.0, 0.88, 0.2, 1.0)
# 골드 획득 팝업 그림자 색상.
const GOLD_POPUP_SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.85)
# 골드 팝업 아이콘 임시 텍스트. 추후 TextureRect 스프라이트로 교체할 자리.
const GOLD_POPUP_ICON_TEXT := "GOLD"

# 난이도 정의. normal은 항상 해금; 이후 난이도는 이전 단계 클리어 시 순차 해금.
# mining_hp_multiplier는 데이터 훅으로만 보관. 현재 미적용(TODO).
const DIFFICULTY_OPTIONS := [
	{"id": "normal",    "display_name": "일반",  "block_hp_multiplier": 1.0,  "mining_hp_multiplier": 1.0,  "unlock_required": ""},
	{"id": "hard",      "display_name": "어려움", "block_hp_multiplier": 1.5,  "mining_hp_multiplier": 1.5,  "unlock_required": "normal"},
	{"id": "extreme",   "display_name": "극한",  "block_hp_multiplier": 3.0,  "mining_hp_multiplier": 3.0,  "unlock_required": "hard"},
	{"id": "hell",      "display_name": "지옥",  "block_hp_multiplier": 5.0,  "mining_hp_multiplier": 5.0,  "unlock_required": "extreme"},
	{"id": "nightmare", "display_name": "악몽",  "block_hp_multiplier": 10.0, "mining_hp_multiplier": 10.0, "unlock_required": "hell"},
]

# 런 구조: 30 Day × 40초. Day 종료 후 상점 단계 진입(TODO: 상인/키오스크 UI).
# 러시 Day: 스폰 간격이 절반으로 단축된다.
# 보스 Day: 보스 블록이 추가 스폰된다. Day 30 보스 처치/모래화+생존 = 런 클리어.
# 보스 블록에만 적용되는 추가 HP 배율 (난이도 배율과 별개).

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

const BLOCK_SPECIAL_RESULT_NONE: StringName = &"none"
const BLOCK_SPECIAL_RESULT_GLASS_SHATTER_DAMAGE: StringName = &"glass_shatter_damage"
const BLOCK_SPECIAL_RESULT_BONUS_GOLD: StringName = &"bonus_gold"
const BLOCK_SPECIAL_RESULT_EXPLOSION: StringName = &"explosion"

# 블록/Day 콘텐츠 데이터는 GameData의 .tres 리소스가 소유한다.
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
	"dash_action": [
		{"type": "key", "code": KEY_Z},
	],
	"interact_action": [
		{"type": "key", "code": KEY_E},
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
	"pause_menu": [
		{"type": "key", "code": KEY_ESCAPE},
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


func sand_cells_to_display_weight(sand_cells: int) -> float:
	return float(sand_cells) * DISPLAY_WEIGHT_PER_SAND_CELL


func format_display_weight(sand_cells: int) -> String:
	return "%.1f" % sand_cells_to_display_weight(sand_cells)


func get_difficulty_definition(difficulty_id: String) -> Dictionary:
	for raw_option in DIFFICULTY_OPTIONS:
		var option: Dictionary = raw_option
		if String(option["id"]) == difficulty_id:
			return option
	return DIFFICULTY_OPTIONS[0]


func get_difficulty_rank(difficulty_id: String) -> int:
	for index in range(DIFFICULTY_OPTIONS.size()):
		var option: Dictionary = DIFFICULTY_OPTIONS[index]
		if String(option["id"]) == difficulty_id:
			return index
	return 0


# ---- 레벨업 및 경험치 시스템 ----

# 카드 풀 기본 정의 (추후 밸런스 변경 가능)
const LEVEL_UP_CARDS := {
	"damage_up": {
		"id": "damage_up",
		"title": "데미지 증가",
		"desc": "모든 최종 피해가 1% 증가합니다.",
	},
	"atk_spd_up": {
		"id": "atk_spd_up",
		"title": "공격속도 증가",
		"desc": "공격속도가 2% 증가합니다.",
	},
	"hp_up": {
		"id": "hp_up",
		"title": "최대 체력 증가",
		"desc": "최대 체력이 5 증가하고 즉시 회복됩니다.",
	},
	"spd_up": {
		"id": "spd_up",
		"title": "이동속도 증가",
		"desc": "이동속도가 3% 증가합니다.",
	},
	"mine_dmg_up": {
		"id": "mine_dmg_up",
		"title": "채굴 데미지 증가",
		"desc": "채굴 데미지가 1 증가합니다.",
	},
	"mine_spd_up": {
		"id": "mine_spd_up",
		"title": "채굴 속도 증가",
		"desc": "채굴속도가 4% 증가합니다.",
	}
}

const EXTRA_LEVEL_UP_CARDS := [
	{
		"id": "atk_range_up",
		"title": "공격범위 증가",
		"desc": "공격범위가 5% 증가합니다.",
	},
	{
		"id": "crit_chance_up",
		"title": "치명타 확률 증가",
		"desc": "치명타 확률이 2%p 증가합니다.",
	},
	{
		"id": "def_up",
		"title": "방어력 증가",
		"desc": "받는 피해를 1 줄여줍니다.",
	},
	{
		"id": "hp_regen_up",
		"title": "HP 재생 증가",
		"desc": "HP 재생이 1 증가합니다.",
	},
	{
		"id": "jump_up",
		"title": "점프력 증가",
		"desc": "점프력이 3% 증가합니다.",
	},
	{
		"id": "battery_recovery_up",
		"title": "배터리 회복 증가",
		"desc": "배터리 회복이 초당 1 증가합니다.",
	},
	{
		"id": "mine_range_up",
		"title": "채굴범위 증가",
		"desc": "채굴범위가 5% 증가합니다.",
	},
	{
		"id": "luck_up",
		"title": "행운 증가",
		"desc": "행운이 1 증가합니다.",
	},
	{
		"id": "interest_up",
		"title": "이자율 증가",
		"desc": "이자율이 2%p 증가합니다.",
	},
	{
		"id": "melee_atk_up",
		"title": "근거리 공격력 증가",
		"desc": "근거리 공격력이 1 증가합니다.",
	},
	{
		"id": "ranged_atk_up",
		"title": "원거리 공격력 증가",
		"desc": "원거리 공격력이 1 증가합니다.",
	},
]

const LEVEL_UP_CARD_RARITIES := [
	{
		"id": "normal",
		"title": "Normal",
		"base_chance": 0.70,
		"luck_chance_delta": -0.01,
		"min_chance": 0.35,
		"max_chance": 1.0,
		"multiplier": 1.0,
	},
	{
		"id": "silver",
		"title": "Silver",
		"base_chance": 0.22,
		"luck_chance_delta": 0.005,
		"min_chance": 0.0,
		"max_chance": 0.40,
		"multiplier": 1.6,
	},
	{
		"id": "gold",
		"title": "Gold",
		"base_chance": 0.07,
		"luck_chance_delta": 0.0035,
		"min_chance": 0.0,
		"max_chance": 0.20,
		"multiplier": 2.5,
	},
	{
		"id": "platinum",
		"title": "Platinum",
		"base_chance": 0.01,
		"luck_chance_delta": 0.0015,
		"min_chance": 0.0,
		"max_chance": 0.08,
		"multiplier": 4.0,
	},
]

func get_block_xp(width_cells: int, height_cells: int) -> int:
	return maxi(width_cells * height_cells, 1) * BLOCK_DESTROY_XP_PER_UNIT

func get_sand_xp(sand_count: int) -> int:
	if sand_count <= 0:
		return 0
	return int(floori(float(sand_count) / float(SAND_REMOVED_CELLS_PER_XP)))


static func get_shop_reroll_cost(current_reroll_count: int) -> int:
	return SHOP_REROLL_BASE_COST + maxi(current_reroll_count, 0) * SHOP_REROLL_COST_INCREMENT
