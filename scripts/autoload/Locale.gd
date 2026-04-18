extends Node

signal language_changed(lang: String)

var current_language: String = "ko"

const _STRINGS: Dictionary = {
	"ko": {
		# HUD
		"hud_gold": "골드",
		"hud_health": "체력 %d / %d",
		"hud_debug_counts": "블록 %d | 모래 %d | 벽 %d",
		"hud_rush_suffix": " | 러시",
		"hud_boss_suffix": " | 보스",
		"hud_day_info": "%s | %d일/%d일 | %d초%s",
		# 인게임 상태 메시지
		"status_attack_hit": "%d개 낙하 블록 공격!",
		"status_attack_miss": "공격이 빗나갔다.",
		"status_mine_blocked": "이 방향으로는 채굴할 수 없다.",
		"status_mine_sand": "모래 %d회 타격, %d개 제거.",
		"status_mine_wall": "벽 %d회 타격, %d개 제거.",
		"status_mine_nothing": "채굴할 것이 없다.",
		"status_block_destroyed": "블록 파괴. +%d 골드.",
		"status_player_crushed": "낙하 블록에 압사. 모래 압력 증가.",
		"status_block_decomposed": "블록이 모래로 붕괴됐다.",
		"status_run_start": "%s | %s | 런 시작. R키로 런을 종료합니다.",
		"status_run_record": "%s | %s | %d스테이지 | 골드 %d | 체력 %d/%d",
		# 런 종료 사유
		"run_end_label": "런 종료",
		"run_health_depleted": "체력 고갈",
		"run_weight_overload": "무게 초과",
		"run_time_limit": "Day 30 시간 초과",
		"run_day_start": "Day %d 시작.",
		"run_day30_clear": "Day 30 클리어",
		# 결과 화면
		"result_title": "결과",
		"result_cleared": "클리어!",
		"result_failed": "실패",
		"result_reason": "이유: %s",
		"result_character": "캐릭터: %s",
		"result_difficulty": "난이도: %s",
		"result_day_reached": "도달 일차: %d",
		"result_record": "런 기록: %s",
		# 타이틀 화면
		"title_bg_placeholder": "배경 이미지 영역",
		"title_scene_desc": "타이틀 화면",
		"title_game_title": "BURIAL PROTOCOL",
		"title_subtitle": "메인 화면",
		# 메인 허브
		"hub_title": "메인 허브",
		"hub_currency_gear": "장비",
		"hub_currency_plywood": "합판",
		"hub_currency_lubricant": "윤활제",
		"hub_currency_iron_ore": "철광석",
		"hub_currency_power": "동력",
		"hub_actions_title": "메뉴",
		"hub_selected_character_title": "선택된 캐릭터",
		"hub_character_display_placeholder": "캐릭터 이미지",
		"hub_best_record_title": "최고 기록",
		"hub_last_difficulty": "마지막 난이도: %s",
		"hub_difficulty_popup_title": "난이도 선택",
		"hub_difficulty_popup_char": "선택 캐릭터: %s",
		"hub_difficulty_popup_hint": "런 시작 전에 난이도를 선택하세요.",
		"hub_difficulty_locked_suffix": " (잠금)",
		"hub_difficulty_selected_suffix": " (마지막 선택)",
		# 캐릭터 목록
		"charlist_title": "캐릭터 목록",
		"charlist_subtitle": "기본 캐릭터를 선택하거나 잠긴 슬롯을 확인하세요.",
		"charlist_current_selection": "현재 선택: %s",
		"charlist_footer_hint": "잠긴 슬롯에 마우스를 올리면 해금 조건을 확인할 수 있습니다.",
		"char_status_available": "상태: 사용 가능",
		"char_status_locked": "상태: 잠김",
		"char_best_record": "최고 기록: %s",
		"char_hover_unlock_hint": "마우스를 올려 해금 조건 확인",
		# 업적
		"achievement_title": "업적",
		"achievement_subtitle": "플레이스홀더 화면. 진입 및 복귀 흐름만 보장됩니다.",
		"achievement_note": "업적 로직은 1단계에서 구현되지 않습니다.",
		# 성장
		"growth_title": "성장",
		"growth_subtitle": "플레이스홀더 화면. 영구 성장 시스템은 이후 단계에서 구현됩니다.",
		"growth_note": "성장 트리와 소비 흐름은 1단계에 포함되지 않습니다.",
		# 아이템 목록
		"itemlist_title": "아이템 목록",
		"itemlist_subtitle": "플레이스홀더 화면. 이 단계에서는 진입 가능한 빈 아이템 목록 씬만 정의됩니다.",
		"itemlist_note": "수집 및 소유 상세 정보는 이후 단계로 연기됩니다.",
		# 공통 버튼
		"btn_start_game": "게임 시작",
		"btn_settings": "설정",
		"btn_profile": "프로필",
		"btn_quit": "게임 종료",
		"btn_ranking": "랭킹",
		"btn_back": "뒤로",
		"btn_exit": "나가기",
		"btn_cancel": "취소",
		"btn_select": "선택",
		"btn_selected": "선택됨",
		"btn_achievements": "업적",
		"btn_character_select": "캐릭터 선택",
		"btn_growth": "성장",
		"btn_item_list": "아이템 목록",
		# GameState 공통
		"no_record_yet": "기록 없음",
		"no_run_yet": "아직 런을 진행하지 않았습니다.",
		"no_result": "결과 없음",
		"record_format": "%s - %d스테이지",
		"run_start_status": "Phase 0 초기화 완료.",
	},
	"en": {
		# HUD
		"hud_gold": "Gold",
		"hud_health": "Health %d / %d",
		"hud_debug_counts": "Blocks %d | Sand %d | Wall %d",
		"hud_rush_suffix": " | RUSH",
		"hud_boss_suffix": " | BOSS",
		"hud_day_info": "%s | Day %d/%d | %ds%s",
		# In-game status messages
		"status_attack_hit": "Hit %d falling block(s).",
		"status_attack_miss": "The swing missed.",
		"status_mine_blocked": "Can't mine in this direction.",
		"status_mine_sand": "Sand %d hit(s), %d removed.",
		"status_mine_wall": "Wall %d hit(s), %d removed.",
		"status_mine_nothing": "Nothing to mine here.",
		"status_block_destroyed": "Block destroyed. +%d gold.",
		"status_player_crushed": "Crushed by a falling block. Sand pressure increased.",
		"status_block_decomposed": "A block broke down into sand.",
		"status_run_start": "%s | %s | Run started. Press R to end the run.",
		"status_run_record": "%s | %s | Stage %d | Gold %d | Health %d/%d",
		# Run end reasons
		"run_end_label": "Run Ended",
		"run_health_depleted": "Health Depleted",
		"run_weight_overload": "Weight Overload",
		"run_time_limit": "Day 30 Time Limit",
		"run_day_start": "Day %d start.",
		"run_day30_clear": "Day 30 Cleared",
		# Result screen
		"result_title": "Result",
		"result_cleared": "CLEARED!",
		"result_failed": "FAILED",
		"result_reason": "Reason: %s",
		"result_character": "Character: %s",
		"result_difficulty": "Difficulty: %s",
		"result_day_reached": "Day Reached: %d",
		"result_record": "Run Record: %s",
		# Title screen
		"title_bg_placeholder": "Background Image Placeholder",
		"title_scene_desc": "Title scene presentation area",
		"title_game_title": "BURIAL PROTOCOL",
		"title_subtitle": "Presentation screen and entry point to the hub",
		# Main Hub
		"hub_title": "Main Hub",
		"hub_currency_gear": "Gear",
		"hub_currency_plywood": "Plywood",
		"hub_currency_lubricant": "Lubricant",
		"hub_currency_iron_ore": "Iron Ore",
		"hub_currency_power": "Power",
		"hub_actions_title": "Hub Actions",
		"hub_selected_character_title": "Selected Character",
		"hub_character_display_placeholder": "Character Display Placeholder",
		"hub_best_record_title": "Best Record",
		"hub_last_difficulty": "Last difficulty: %s",
		"hub_difficulty_popup_title": "Select Difficulty",
		"hub_difficulty_popup_char": "Character: %s",
		"hub_difficulty_popup_hint": "Select difficulty before starting the run.",
		"hub_difficulty_locked_suffix": " (Locked)",
		"hub_difficulty_selected_suffix": " (Last Selected)",
		# Character List
		"charlist_title": "Character List",
		"charlist_subtitle": "Select the default character or inspect locked placeholders.",
		"charlist_current_selection": "Current selection: %s",
		"charlist_footer_hint": "Locked slots show unlock hints on hover.",
		"char_status_available": "Status: Available",
		"char_status_locked": "Status: Locked",
		"char_best_record": "Best Record: %s",
		"char_hover_unlock_hint": "Hover to view unlock condition",
		# Achievement
		"achievement_title": "Achievements",
		"achievement_subtitle": "Placeholder screen. This phase only guarantees scene entry and return flow.",
		"achievement_note": "Real achievement logic is intentionally not implemented in phase 1.",
		# Growth
		"growth_title": "Growth",
		"growth_subtitle": "Placeholder screen. Permanent growth systems are intentionally deferred.",
		"growth_note": "Growth trees and spending flows are not part of phase 1.",
		# Item List
		"itemlist_title": "Item List",
		"itemlist_subtitle": "Placeholder screen. This phase only defines a reachable empty item list scene.",
		"itemlist_note": "Collection and ownership details are deferred to a later phase.",
		# Common buttons
		"btn_start_game": "Start Game",
		"btn_settings": "Settings",
		"btn_profile": "Profile",
		"btn_quit": "Quit Game",
		"btn_ranking": "Ranking",
		"btn_back": "Back",
		"btn_exit": "Exit",
		"btn_cancel": "Cancel",
		"btn_select": "Select",
		"btn_selected": "Selected",
		"btn_achievements": "Achievements",
		"btn_character_select": "Character Select",
		"btn_growth": "Growth",
		"btn_item_list": "Item List",
		# GameState common
		"no_record_yet": "No record yet.",
		"no_run_yet": "No run played yet.",
		"no_result": "No result",
		"record_format": "%s - Stage %d",
		"run_start_status": "Phase 0 bootstrap complete.",
	},
}


func set_language(lang: String) -> void:
	if not _STRINGS.has(lang):
		push_warning("Locale: unknown language '%s', keeping '%s'" % [lang, current_language])
		return
	current_language = lang
	language_changed.emit(lang)


func ltr(key: String) -> String:
	var lang_dict: Dictionary = _STRINGS.get(current_language, {})
	if lang_dict.has(key):
		return lang_dict[key]
	push_warning("Locale: missing key '%s' for language '%s'" % [key, current_language])
	return key
