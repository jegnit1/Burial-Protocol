# Burial Protocol - Base State Specification

## 0. 목적

이 문서는 현재 프로젝트의 공용 상태 구조를 정리한다.
무엇이 저장 데이터인지, 무엇이 런타임 상태인지, 어떤 UI가 어떤 상태를 읽는지 기록한다.

기준일: `2026-04-20`

---

## 1. 상태 층 구분

현재 프로젝트는 크게 아래 세 층의 상태를 사용한다.

1. 저장 상태
2. 현재 런 상태
3. 씬 내부 진행 상태

---

## 2. 저장 상태

저장 주체: `scripts/autoload/GameState.gd`

- 경로: `user://profile.save`
- 형식: JSON
- 버전 필드: `save_version`

### 2-1. 현재 저장 필드

- `selected_character_id`
- `last_selected_difficulty_id`
- `persistent_currencies`
- `settings`
- `growth`
- `unlocked_character_ids`
- `unlocked_achievement_ids`
- `best_records_by_character`
- `cleared_difficulty_ids`

### 2-2. 저장 범위 설명

#### 캐릭터 관련

- 현재 선택 캐릭터
- 해금 캐릭터 목록
- 캐릭터별 최고 기록

#### 난이도 관련

- 마지막 선택 난이도
- 클리어한 난이도 목록

#### placeholder 메타 관련

- 영구 재화
- 설정
- 성장 데이터
- 업적 데이터

중요:
메타 시스템은 구조만 저장되고 있으며, 실제 기능은 아직 제한적이다.

---

## 3. 현재 런 상태

현재 런 상태는 주로 `GameState.gd`가 소유한다.

### 3-1. 기본 런 필드

- `gold`
- `player_health`
- `status_text`
- `current_run_stage_reached`
- `current_day`
- `day_time_remaining`
- `run_cleared`

### 3-2. 경험치/레벨 필드

- `player_level`
- `player_current_xp`
- `player_next_level_xp`

### 3-3. 런타임 스탯 보너스 필드

- `run_bonus_attack_damage`
- `run_bonus_move_speed`
- `run_bonus_max_hp`
- `run_attack_speed_mult`
- `run_bonus_mining_damage`
- `run_mining_speed_mult`
- `run_bonus_crit_chance`
- `run_bonus_hp_regen`
- `run_bonus_defense`
- `run_bonus_luck`
- `run_bonus_interest_rate`
- `run_attack_range_mult`
- `run_mining_range_mult`
- `run_bonus_jump_power`

즉, `GameConstants`가 기본값을 가지고,
`GameState`는 현재 런에서 쌓인 추가 보너스를 가진다.

---

## 4. 최종 스탯 getter

`GameState.gd`는 현재 UI와 로직이 직접 읽는 최종 스탯 getter를 제공한다.

### 4-1. 전투 관련

- `get_attack_damage()`
- `get_attack_cooldown_duration()`
- `get_attacks_per_second()`
- `get_attack_range_multiplier()`
- `get_critical_chance_ratio()`
- `get_critical_chance_percent()`
- `get_critical_damage_multiplier()`
- `get_critical_damage_percent()`

### 4-2. 생존 관련

- `get_player_max_health()`
- `get_defense()`
- `get_hp_regen_stat()`
- `get_hp_regen_interval()`

### 4-3. 이동 관련

- `get_move_speed()`
- `get_jump_speed()`
- `get_jump_power()`

### 4-4. 채굴 관련

- `get_mining_damage()`
- `get_mining_cooldown_duration()`
- `get_mines_per_second()`
- `get_mining_range_multiplier()`

### 4-5. 경제/기타 관련

- `get_interest_rate()`
- `get_interest_percent()`
- `calculate_interest_payout()`
- `get_luck()`

---

## 5. 캐릭터/난이도 상태

### 5-1. 캐릭터

- `selected_character_id`
- `selected_character_name`
- `current_run_character_id`
- `current_run_character_name`

설명:

- `selected_*` 는 허브에서 선택된 현재 값
- `current_run_*` 는 실제 런 시작 시 복사된 값

### 5-2. 난이도

- `last_selected_difficulty_id`
- `last_selected_difficulty_name`
- `current_run_difficulty_id`
- `current_run_difficulty_name`
- `cleared_difficulty_ids`

---

## 6. Signal 구조

`GameState`가 현재 제공하는 UI 연동 signal:

- `gold_changed`
- `health_changed`
- `status_text_changed`
- `selected_character_changed`
- `xp_changed`
- `level_changed`
- `level_up_ready`

### 6-1. 현재 signal 소비처

주요 소비처:

- `HUD`
- 허브/캐릭터 선택 계열 UI
- `LevelUpUI`
- `PauseMenu`의 초기 데이터 생성

---

## 7. 씬 내부 진행 상태

씬 내부 진행 플래그는 `GameState`가 아니라 `Main.gd`가 관리한다.

현재 핵심 플래그:

- `_is_day_active`
- `_is_intermission`
- `_is_intermission_locked`
- `_is_next_day_transitioning`
- `_shop_ui_open`
- `_waiting_for_day_kiosk`
- `_pending_wall_reset_for_next_day`

중요:
Day 진행과 전환 플래그는 저장 상태가 아니다.
현재 `Main` 씬 내부의 진행 제어값이다.

---

## 8. Player 고유 런타임 상태

일부 상태는 `GameState`가 아니라 `Player.gd`가 직접 소유한다.

예:

- `current_battery`
- `is_wall_climbing`
- `dash_cooldown_remaining`
- `damage_cooldown`
- `hurt_flash_remaining`
- `extra_jumps_left`

HUD는 필요한 값만 Player getter를 통해 읽는다.

예:

- `get_current_battery()`
- `get_max_battery()`
- `get_dash_cooldown_remaining()`
- `get_dash_cooldown_duration()`
- `can_dash()`

---

## 9. 스탯 패널용 상태

`PauseMenu.gd`는 개별 getter를 직접 나열하지 않고,
`GameState.get_stat_panel_entries()`가 반환하는 배열을 사용한다.

현재 포함 항목:

- 공격력
- 공격속도
- 공격범위
- 치명타 확률
- 치명타 배율
- 현재 체력
- 방어력
- HP 재생
- 이동속도
- 점프력
- 채굴 데미지
- 채굴 속도
- 채굴 범위
- 이자율
- 행운

행운은 현재 `"효과 없음"`으로 표시한다.

---

## 10. 전환과 경제 상태

현재 Day 전환 시 경제 상태에서 중요한 값:

- `gold`
- `calculate_interest_payout()`
- `get_interest_rate()`

Next Day 전환 시점에만 이자가 적용되며,
상점 진입 시점이나 intermission 진입 시점에는 중복 지급되지 않는다.

---

## 11. 콘텐츠 데이터와 상태의 분리

중요:
블록/Day 콘텐츠 데이터는 `GameState`가 소유하지 않는다.

현재 구조:

- `GameConstants`: 전역 상수
- `GameData`: `.tres` 콘텐츠 데이터 로더
- `GameState`: 저장 + 런타임 스탯/자원 상태
- `Main`: 씬 진행 플래그

즉, 값의 성격에 따라 소유권이 분리되어 있다.

---

## 12. 현재 주의점

- `status_text`는 계속 갱신되지만 HUD에 직접 노출하지는 않는다
- intermission 플래그는 `GameState`가 아니라 `Main`에 있으므로 메뉴/UI 문서에 혼동해서 적지 않는다
- 배터리는 Player 고유 상태이므로 저장 데이터가 아니다
- 상점 구매 상태는 아직 본격 구조가 없다
