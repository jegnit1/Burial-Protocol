# Burial Protocol - Base State Specification

## 0. 목적

이 문서는 프로젝트가 현재 사용 중인 공유 상태 구조를 정리한다.
무엇이 세이브에 남고, 무엇이 런 중에만 존재하며,
어떤 UI/런타임 시스템이 그 상태를 참조하는지를 기록한다.

현재 이 상태의 중심 소유자는 `scripts/autoload/GameState.gd`다.

---

## 1. 상태 범주

현재 프로젝트는 실질적으로 아래 세 층의 상태를 사용한다.

1. 영구 프로필 상태
2. 현재 런 상태
3. UI 갱신용 시그널 상태

---

## 2. 영구 프로필 상태

영구 데이터는 아래 위치에 저장된다.

- 경로: `user://profile.save`
- 포맷: JSON 문자열
- 버전 필드: `save_version`

### 2-1. 현재 영구 저장 필드

현재 세이브 데이터에는 아래가 들어간다.

- `selected_character_id`
- `last_selected_difficulty_id`
- `persistent_currencies`
- `settings`
- `growth`
- `unlocked_character_ids`
- `unlocked_achievement_ids`
- `best_records_by_character`
- `cleared_difficulty_ids`

### 2-2. 영구 데이터 의미

#### 캐릭터 관련

- 선택 캐릭터 id
- 해금된 캐릭터 id 목록
- 캐릭터별 난이도 최고 기록

#### 난이도 관련

- 마지막 선택 난이도 id
- 난이도 해금용 클리어 기록

#### 메타 placeholder 관련

- 재화
- 설정
- 성장
- 업적

즉, 아직 게임플레이 사용처가 placeholder인 항목도
저장 구조 자체는 이미 들어가 있는 상태다.

---

## 3. 캐릭터 상태

현재 캐릭터 슬롯 규칙:

- 기본 작업자 슬롯 1개는 시작부터 해금
- 추가 슬롯 9개는 잠긴 placeholder
- 각 슬롯은 최고 기록 요약을 가진다

메뉴에서 현재 선택된 값:

- `selected_character_id`
- `selected_character_name`

실제 런에서는 이 값이 아래로 복사된다.

- `current_run_character_id`
- `current_run_character_name`

이 분리는 중요하다.
결과 화면은 "현재 허브에서 선택 중인 값"이 아니라
"방금 끝난 런의 값"을 보여 주기 때문이다.

---

## 4. 난이도 상태

현재 난이도 관련 상태 필드:

- `last_selected_difficulty_id`
- `last_selected_difficulty_name`
- `current_run_difficulty_id`
- `current_run_difficulty_name`
- `cleared_difficulty_ids`

해금 규칙:

- `normal`은 기본 해금
- 그 위 난이도는 이전 난이도 클리어가 필요

메인 허브는 이 상태를 읽어서 난이도 팝업과 잠금 버튼을 만든다.

---

## 5. 현재 런 상태

아래 값들은 런 시작 시 초기화된다.

- `gold`
- `player_health`
- `status_text`
- `current_run_stage_reached`
- `current_day`
- `day_time_remaining`
- `run_cleared`
- `player_level`
- `player_current_xp`
- `player_next_level_xp`
- `run_bonus_attack_damage`
- `run_bonus_move_speed`
- `run_bonus_max_hp`
- `run_attack_speed_mult`
- `run_bonus_mining_damage`
- `run_mining_speed_mult`

### 5-1. 시작 기본값

현재 런 시작 기본값:

- 골드: `0`
- 체력: `GameConstants.PLAYER_MAX_HEALTH`
- 현재 Day: `1`
- 남은 시간: `GameConstants.DAY_DURATION`
- 클리어 여부: `false`
- 레벨: `1`
- XP: `0`
- 다음 레벨 XP: `50`

### 5-2. 런 결과 상태

런 종료 시 `finish_temporary_run()`이 아래 값을 기록한다.

- `latest_run_record`
- `latest_run_reason_id`
- `latest_run_reason_label`
- `latest_run_stage_reached`
- `latest_run_difficulty_name`
- `latest_run_character_name`

이 값들이 결과 화면의 데이터 소스다.

---

## 6. UI 시그널 계층

현재 `GameState`가 제공하는 시그널은 아래와 같다.

- `gold_changed`
- `health_changed`
- `status_text_changed`
- `selected_character_changed`
- `xp_changed`
- `level_changed`
- `level_up_ready`

### 6-1. 현재 소비자

현재 이 시그널을 직접 또는 간접으로 사용하는 주요 UI:

- `HUD`
- `GameState`를 직접 읽는 메뉴 장면들
- `LevelUpUI`

### 6-2. 중요한 현재 상태

`status_text`는 게임 중 계속 바뀌지만,
현재 HUD에는 이 텍스트를 전용으로 보여 주는 위젯이 아직 없다.

즉, 상태 자체는 존재하고 갱신되지만,
표현 레이어는 아직 덜 붙은 상태다.

---

## 7. XP와 런 한정 보너스 상태

현재 XP 흐름:

- 블록 파괴 -> XP 획득
- 모래 제거 -> XP 획득
- 기준치를 넘으면 `level_up_ready` emit

현재 런 한정 보너스 필드:

- 공격력 보너스
- 이동 속도 보너스
- 최대 HP 보너스
- 공격 속도 배수
- 채굴 데미지 보너스
- 채굴 속도 배수

이 값들은 영구 성장값이 아니라 "이번 런에서만 유효한 수치"다.

---

## 8. 최고 기록 상태

최고 기록은 아래 기준으로 관리된다.

- 캐릭터별
- 난이도별
- 가장 높게 도달한 stage/day 정수값

메뉴에서는 이 값을 읽어 선택 캐릭터의 최고 기록 요약 문자열을 만든다.

즉, 현재 기록 시스템은 이후 메타 성장이나 결과 확장에도 사용할 수 있게
기본 구조는 이미 잡혀 있다.

---

## 9. 세이브 라이프사이클

현재 세이브 흐름:

- 먼저 기본 데이터를 적용
- 파일이 없으면 생성
- 잘못되었거나 빠진 필드를 정규화
- 로드 후 다시 저장해서 구조를 맞춤
- 선택/해금 변경 시 저장
- 런 종료 시 저장

현재 구조는 예외 상황에서도 기본값 복구가 잘 되도록 안정성을 우선한다.

---

## 10. 이 상태 구조로 이미 가능한 것

현재 베이스 상태 구조만으로도 아래가 가능하다.

- 메뉴 -> 런 흐름
- 캐릭터 선택
- 난이도 해금 연쇄
- 런 결과 보고
- 영구 최고 기록 저장
- placeholder 장기 재화/설정 유지
- 런 중 XP/레벨업/보너스 처리

---

## 11. 아직 비어 있는 상태 계층

아래 항목은 현재 상태 구조는 존재하거나 확장 가능하지만,
실제 게임플레이 연결은 아직 약하다.

- 영구 성장 소비 로직
- 업적 보상 로직
- 인벤토리 보유 로직
- 의미 있는 영구 재화 사용처
- 더 풍부한 런 종료 후 정산

이 기능들은 새 상태 계층을 따로 만드는 것보다,
현재 `GameState`를 조심스럽게 확장하는 편이 맞다.
