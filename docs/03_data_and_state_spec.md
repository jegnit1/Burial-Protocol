# Burial Protocol - Data and State Specification

기준일: `2026-04-24`  
기준 브랜치: `main`

---

## 0. 목적

이 문서는 Burial Protocol의 데이터 소유권, 저장 상태, 런타임 상태, UI signal 구조를 정리한다.
기존 `base_state_spec.md`와 여러 문서에 흩어진 데이터 구조 설명을 이 문서로 통합한다.

---

## 1. 상태 층 구분

현재 프로젝트는 크게 아래 세 층의 상태를 사용한다.

1. 저장 상태
2. 현재 런 상태
3. 씬 내부 진행 상태

원칙:

- 저장/런타임 공용 상태는 `GameState.gd`
- 콘텐츠 데이터 로딩은 `GameData.gd`
- 전역 상수는 `GameConstants.gd`
- 씬 진행 플래그는 `Main.gd`
- 플레이어 순간 동작 상태는 `Player.gd`

---

## 2. GameConstants

`GameConstants.gd`는 전역 상수와 정적 유틸을 가진다.

범위:

- 기준 해상도
- 월드 크기
- HUD 레이아웃
- 색상
- 플레이어 이동 수치
- 공격/채굴 수치
- 대시/벽타기 수치
- 공격모듈 최대 장착 수와 등급 배율
- 중량 한도와 표시 스케일
- 키오스크/페이드 수치
- 난이도 옵션
- 입력 바인딩
- 레벨업 카드 정의
- 공통 계산 유틸

중요:

`GameConstants.gd`에 콘텐츠 테이블을 계속 추가하지 않는다.
블록, 스테이지, 상점 아이템은 별도 `.tres`와 데이터 해석 스크립트가 소유한다.

---

## 3. GameData

`GameData.gd`는 콘텐츠 데이터 로딩 진입점이다.

현재 주요 preload:

- `data/blocks/BlockCatalog.tres`
- `data/stages/StageTable.tres`
- `data/items/ShopItemCatalog.tres`
- `scripts/data/ShopItemCatalog.gd`
- `scripts/data/BlockSpawnResolver.gd`

주요 책임:

- 블록 material/size/type 정의 접근
- 블록 스폰 resolved definition 생성
- Day 정의 접근
- 보스 블록 정의 접근
- 공격모듈 정의 접근
- 상점 아이템 정의 접근
- 상점 아이템 롤

---

## 4. Block Data

최신 블록 데이터 모델:

```text
Runtime Block = Material x Size + optional Type
```

### 4-1. Material

Material은 블록의 재질/성질을 담당한다.

역할:

- material id
- 표시 이름
- HP 배율
- 보상 배율
- 색상
- spawn weight
- special result
- 등장 제한

### 4-2. Size

Size는 블록의 물리 크기를 담당한다.

역할:

- size id
- width/height
- size cells
- HP 배율
- 보상 배율
- spawn weight
- 등장 제한

### 4-3. Type

Type은 선택 affix/modifier다.

역할:

- HP 배율
- 보상 배율
- sand units 배율
- 접두/접미 표시
- special result override

### 4-4. BlockSpawnResolver

`BlockSpawnResolver.gd`는 현재 난이도/Day/후보 weight를 바탕으로 최종 블록 정의를 만든다.

결과물은 `BlockResolvedDefinition`이며, 이후 `BlockData.from_resolved_definition()`을 통해 런타임 블록 데이터로 변환된다.

---

## 5. Stage Data

`StageTable.tres`는 Day 정보를 소유한다.

사용되는 정보:

- 총 Day 수
- Day 타입
- Day 지속 시간
- Day별 블록 HP 배율
- Day별 스폰 간격 배율
- 보스 Day 여부
- 다음 보스 Day
- 보스 블록 material/base id
- 보스 블록 size id
- 보스 블록 type id

`Main.gd`는 Day 시작, 스폰 타이머, 보스 스폰, Day 30 판정에서 이 데이터를 사용한다.

---

## 6. Shop Item Data

상점 아이템은 `data/items/ShopItemCatalog.tres`와 `scripts/data/ShopItemCatalog.gd`가 담당한다.

카테고리:

- `attack_module`
- `function_module`
- `enhance_module`

랭크:

- D
- C
- B
- A
- S

`ShopItemCatalog.gd`는 Day 구간별 랭크 weight table을 사용한다.
행운은 랭크 weight를 보정한다.

구매 가능성 최종 판단은 `GameState.purchase_shop_item()`과 관련 helper가 담당한다.

---

## 7. 저장 상태

저장 주체: `scripts/autoload/GameState.gd`

- 경로: `user://profile.save`
- 형식: JSON
- 버전 필드: `save_version`

현재 저장 필드:

- `selected_character_id`
- `last_selected_difficulty_id`
- `persistent_currencies`
- `settings`
- `growth`
- `unlocked_character_ids`
- `unlocked_achievement_ids`
- `best_records_by_character`
- `cleared_difficulty_ids`

저장 범위:

- 현재 선택 캐릭터
- 해금 캐릭터 목록
- 캐릭터별 최고 기록
- 마지막 선택 난이도
- 클리어한 난이도 목록
- 영구 재화
- 설정
- 성장 데이터
- 업적 데이터

메타 시스템은 구조는 있으나 실제 기능은 아직 제한적이다.

---

## 8. 현재 런 상태

현재 런 상태는 주로 `GameState.gd`가 소유한다.

기본 런 필드:

- `gold`
- `player_health`
- `status_text`
- `current_run_stage_reached`
- `current_day`
- `day_time_remaining`
- `run_cleared`

경험치/레벨 필드:

- `player_level`
- `player_current_xp`
- `player_next_level_xp`

런타임 스탯 보너스:

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
- `run_move_speed_mult`
- `run_jump_power_mult`
- `run_bonus_max_weight`
- `run_bonus_battery_recovery`

---

## 9. 공격모듈 상태

`GameState.gd`는 공격모듈 관련 상태를 소유한다.

주요 필드:

- `owned_attack_module_ids`
- `equipped_attack_module_id`
- `equipped_attack_modules`
- `attack_module_instance_sequence`
- `attack_module_runtime_state`

주요 getter/helper:

- `get_equipped_attack_module_entries()`
- `get_input_attack_module_entries()`
- `get_mechanic_attack_module_entries()`
- `get_attack_module_definition_from_entry()`
- `get_attack_module_damage()`
- `get_mechanic_attack_module_damage()`
- `get_attack_module_cooldown_duration()`
- `get_attack_module_shape_size_units()`
- `can_add_or_synthesize_attack_module()`

주의:

- `equipped_attack_module_id`는 과거 단일 장착 구조 호환용 성격이 남아 있다.
- 실제 최신 구조는 `equipped_attack_modules` 배열 기반 다중 장착이다.

---

## 10. 기능/강화 모듈 상태

현재 상점 아이템 시스템은 공격모듈 외에도 기능/강화 모듈 상태를 가진다.

주요 필드:

- `owned_function_module_ids`
- `owned_enhance_module_counts`
- `current_run_items`
- `current_run_effects`

의미:

- 기능 모듈은 현재 런에 특정 효과를 등록한다.
- 강화 모듈은 스탯 보너스 또는 스택으로 반영된다.
- 현재 런 효과는 `current_run_effects`에 누적된다.

---

## 11. 최종 스탯 getter

`GameState.gd`는 UI와 로직이 직접 읽는 최종 스탯 getter를 제공한다.

전투:

- `get_attack_damage()`
- `get_base_attack_damage()`
- `get_attack_cooldown_duration()`
- `get_attacks_per_second()`
- `get_attack_range_multiplier()`
- `get_critical_chance_ratio()`
- `get_critical_chance_percent()`
- `get_critical_damage_multiplier()`
- `get_critical_damage_percent()`

생존:

- `get_player_max_health()`
- `get_defense()`
- `get_hp_regen_stat()`
- `get_hp_regen_interval()`
- `get_weight_limit_sand_cells()`

이동:

- `get_move_speed()`
- `get_air_move_speed()`
- `get_jump_speed()`
- `get_jump_power()`
- `get_battery_recovery_per_second()`

채굴:

- `get_mining_damage()`
- `get_mining_cooldown_duration()`
- `get_mines_per_second()`
- `get_mining_range_multiplier()`

경제/기타:

- `get_interest_rate()`
- `get_interest_percent()`
- `calculate_interest_payout()`
- `get_luck()`

---

## 12. 캐릭터 / 난이도 상태

캐릭터:

- `selected_character_id`
- `selected_character_name`
- `current_run_character_id`
- `current_run_character_name`

설명:

- `selected_*`는 허브에서 선택된 현재 값
- `current_run_*`는 실제 런 시작 시 복사된 값

난이도:

- `last_selected_difficulty_id`
- `last_selected_difficulty_name`
- `current_run_difficulty_id`
- `current_run_difficulty_name`
- `cleared_difficulty_ids`

---

## 13. Signal 구조

`GameState`가 제공하는 주요 signal:

- `gold_changed`
- `health_changed`
- `status_text_changed`
- `selected_character_changed`
- `xp_changed`
- `level_changed`
- `level_up_ready`
- `attack_module_changed`
- `owned_attack_modules_changed`
- `run_items_changed`

주요 소비처:

- `HUD`
- 허브/캐릭터 선택 UI
- `LevelUpUI`
- `PauseMenu`
- `DayShopUI`
- `Player`

---

## 14. Player 고유 상태

일부 상태는 `GameState`가 아니라 `Player.gd`가 직접 소유한다.

예:

- `velocity`
- `facing`
- `extra_jumps_left`
- `jump_buffer_remaining`
- `coyote_time_remaining`
- `attack_module_cooldowns`
- `mining_cooldown`
- `dash_cooldown_remaining`
- `current_battery`
- `is_wall_climbing`
- `damage_cooldown`
- `hurt_flash_remaining`
- 공격모듈 시각 공전 상태

HUD는 필요한 값만 Player getter를 통해 읽는다.

예:

- `get_current_battery()`
- `get_max_battery()`
- `get_dash_cooldown_remaining()`
- `get_dash_cooldown_duration()`
- `can_dash()`

---

## 15. 스탯 패널 상태

`PauseMenu.gd`는 `GameState.get_stat_panel_entries()`가 반환하는 배열을 사용한다.

현재 표시 항목:

- 공격 모듈
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

---

## 16. 상태 소유권 주의사항

- 블록/Day/상점 아이템 콘텐츠 데이터는 `GameState`가 소유하지 않는다.
- intermission 진행 플래그는 `GameState`가 아니라 `Main.gd`가 소유한다.
- 배터리와 대시 쿨다운은 `Player.gd`가 소유한다.
- 공격모듈 장착/보유 상태는 `GameState.gd`가 소유한다.
- 공격모듈별 순간 쿨다운은 `Player.gd`가 소유한다.
- 상점 아이템 롤 결과는 해당 intermission 동안 `Main.gd`가 `_current_shop_item_ids`로 들고 있다.
- 구매 결과와 런 효과는 `GameState.gd`가 소유한다.

---

## 17. 문서 갱신 체크리스트

데이터/상태 구조를 바꿀 때는 아래를 확인한다.

- `GameConstants`에 콘텐츠 데이터가 새로 섞이지 않았는가
- `.tres` 데이터와 로더가 일치하는가
- `GameState` getter와 UI 표시가 일치하는가
- `DayShopUI` snapshot과 `GameState.get_day_shop_snapshot()`이 일치하는가
- 공격모듈 다중 장착 구조와 UI 표시가 일치하는가
- `Player` 고유 상태를 저장 상태로 잘못 문서화하지 않았는가
- 새 signal이 있다면 소비처와 함께 적었는가
