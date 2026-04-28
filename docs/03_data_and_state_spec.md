# Burial Protocol - Data and State Specification

기준일: `2026-04-28`  
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
- 상점 아이템 랭크별 가격 기본값 (`SHOP_ITEM_RANK_FALLBACK_PRICES`)
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

아이템 데이터에 `price_gold`가 없거나 0이면 `GameConstants.SHOP_ITEM_RANK_FALLBACK_PRICES`의 랭크별 기본 가격을 사용한다.
최종 유효 가격 결정은 `GameState.get_effective_shop_item_price(item_id)`가 담당한다.
구매 가능성 최종 판단은 `GameState.purchase_shop_item()`과 관련 helper가 담당한다.

---

## 7. Item Object Schema

조건부 아이템, 보물상자 보상, 기능 모듈, 강화 모듈, 레벨업 카드가 늘어나기 전에 아이템 객체 스키마를 먼저 정의한다.

원칙:

```text
아이템 = 기본 정보 + 조건 목록 + 효과 목록 + 적용 타이밍
```

아이템별로 코드를 하드코딩하지 않는다.
새 아이템은 가능한 한 데이터 추가로 표현하고, 코드는 condition/effect/apply_timing 타입을 해석하는 공통 엔진을 확장한다.

### 7-1. 기본 필드

권장 기본 필드:

- `item_id`
- `name`
- `rank`
- `item_category`
- `price_gold`
- `shop_enabled`
- `shop_spawn_weight`
- `stackable`
- `max_stack`
- `effect_type`
- `effect_values`
- `conditions`
- `effects`
- `apply_timing`
- `tags`
- `icon_path`
- `short_desc`
- `desc`

현재 단순 아이템은 `effect_type`과 `effect_values`만으로 표현할 수 있다.
조건부 아이템은 `conditions`, `effects`, `apply_timing`을 함께 사용한다.

### 7-2. 조건부 아이템 예시

예시: 무게가 60% 이상일 때 공격력 증가

```gdscript
{
    "item_id": "pressure_overdrive",
    "name": "압력 과부하 장치",
    "rank": "B",
    "item_category": "enhance_module",
    "effect_type": "conditional_stat_bonus",
    "conditions": [
        {
            "type": "weight_ratio_at_least",
            "value": 0.6
        }
    ],
    "effects": [
        {
            "type": "attack_damage_percent",
            "value": 0.25
        }
    ],
    "apply_timing": "stat_query"
}
```

예시: 모든 공격모듈이 근거리일 때 공격력 증가

```gdscript
{
    "item_id": "melee_purity_core",
    "name": "근접 순도 코어",
    "rank": "A",
    "item_category": "enhance_module",
    "effect_type": "conditional_stat_bonus",
    "conditions": [
        {
            "type": "all_attack_modules_type",
            "module_type": "melee"
        }
    ],
    "effects": [
        {
            "type": "attack_damage_percent",
            "value": 0.30
        }
    ],
    "apply_timing": "stat_query"
}
```

예시: 블록 옆면 공격 시 데미지 증가

```gdscript
{
    "item_id": "side_breaker",
    "name": "측면 파쇄기",
    "rank": "B",
    "item_category": "enhance_module",
    "effect_type": "conditional_damage_bonus",
    "conditions": [
        {
            "type": "attack_hit_side",
            "allowed_sides": ["left", "right"]
        }
    ],
    "effects": [
        {
            "type": "damage_multiplier_on_hit",
            "value": 1.25
        }
    ],
    "apply_timing": "on_attack_hit"
}
```

### 7-3. Condition 타입

초기 지원 권장 condition 타입:

상시 상태 조건:

- `weight_ratio_at_least`
- `weight_ratio_below`
- `hp_ratio_at_least`
- `hp_ratio_below`
- `gold_at_least`
- `current_day_at_least`
- `all_attack_modules_type`
- `equipped_attack_module_count_at_least`
- `has_attack_module_type`

공격 순간 조건:

- `attack_module_type_is`
- `attack_hit_side`
- `player_is_airborne`
- `target_block_size_at_least`
- `is_critical_hit`

이벤트 조건:

- `destroyed_block_material_is`
- `destroyed_block_type_is`
- `sand_removed_at_least`
- `shop_item_rank_is`

처음부터 모든 condition을 구현하지 않는다.
1차 구현은 상시 상태 조건만 지원하고, 공격 순간 조건과 이벤트 조건은 이후 단계로 확장한다.

### 7-4. Effect 타입

초기 지원 권장 effect 타입:

스탯 효과:

- `attack_damage_flat`
- `attack_damage_percent`
- `attack_speed_percent`
- `attack_range_percent`
- `crit_chance_flat`
- `max_hp_flat`
- `defense_flat`
- `hp_regen_flat`
- `move_speed_percent`
- `jump_power_percent`
- `mining_damage_flat`
- `mining_speed_percent`
- `mining_range_percent`
- `luck_flat`
- `interest_rate_flat`
- `battery_recovery_flat`

공격 순간 효과:

- `damage_multiplier_on_hit`
- `additional_flat_damage_on_hit`
- `crit_chance_bonus_on_hit`

이벤트 효과:

- `gold_gain_flat`
- `xp_gain_flat`
- `sand_remove_count`
- `queue_wall_reset_next_day`

주의:

- `sand_remove_count`, `queue_wall_reset_next_day` 같은 환경대응 효과는 레벨업 카드가 아니라 상점 아이템, 기능 모듈, 보물상자 보상, 특수 이벤트에서만 사용한다.

### 7-5. Apply Timing

조건부 효과는 언제 검사하느냐가 중요하다.

권장 `apply_timing`:

| apply_timing | 의미 | 예시 |
|---|---|---|
| `on_purchase` | 구매 즉시 적용 | 최대 체력 증가, 모듈 등록 |
| `stat_query` | 최종 스탯 계산 시 검사 | 무게 60% 이상 공격력 증가 |
| `on_attack_start` | 공격 시작 시 검사 | 근거리 공격만 강화 |
| `on_attack_hit` | 공격이 블록에 적중한 순간 검사 | 옆면 공격 시 데미지 증가 |
| `on_block_destroyed` | 블록 파괴 시 검사 | 골드 추가 획득 |
| `on_sand_removed` | 모래 제거 시 검사 | 채굴 보너스 XP |
| `on_day_started` | Day 시작 시 검사 | 시작 보호막, 임시 버프 |
| `on_day_ended` | Day 종료 시 검사 | 이자 보너스, 벽 복구 예약 |
| `on_player_damaged` | 플레이어 피격 시 검사 | 반격, 방어 버프 |

### 7-6. 구현 순서 원칙

조건부 아이템 구현 순서:

```text
1. 아이템 객체 스키마 확정
2. condition 타입 목록 확정
3. effect 타입 목록 확정
4. apply_timing 목록 확정
5. 기존 stat_bonus 아이템을 새 구조로 표현 가능한지 검증
6. stat_query 기반 conditional_stat_bonus 구현
7. on_attack_hit 기반 conditional_damage_bonus 구현
8. 이벤트 기반 효과 구현
```

초기 구현 추천:

```text
1차:
- stat_bonus
- conditional_stat_bonus
- weight_ratio_at_least
- all_attack_modules_type

2차:
- on_attack_hit
- attack_hit_side
- damage_multiplier_on_hit

3차:
- on_block_destroyed
- on_sand_removed
- on_player_damaged
```

금지 방향:

```gdscript
if item_id == "pressure_overdrive":
    ...
if item_id == "side_breaker":
    ...
```

아이템 ID별 분기 하드코딩은 피한다.
새로운 효과가 필요하면 condition/effect/apply_timing 타입을 추가한다.

---

## 8. 저장 상태

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

## 9. 현재 런 상태

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
- `run_bonus_melee_attack_damage`
- `run_bonus_ranged_attack_damage`
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

## 10. 공격모듈 상태

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

## 11. 기능/강화 모듈 상태

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

향후 조건부 아이템과 이벤트형 아이템은 `current_run_effects`에 저장된 효과 목록을 condition/effect/apply_timing 엔진이 해석하는 방식으로 확장한다.

---

## 12. 최종 스탯 getter

`GameState.gd`는 UI와 로직이 직접 읽는 최종 스탯 getter를 제공한다.

전투:

- `get_attack_damage()`
- `get_base_attack_damage()`
- `get_melee_base_attack_damage()`
- `get_ranged_base_attack_damage()`
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
- `get_effective_shop_item_price(item_id)`

조건부 `stat_query` 효과를 구현할 경우, 위 getter들은 공통 effect evaluator를 통해 조건을 만족하는 스탯 보너스를 함께 반영해야 한다.

---

## 13. 캐릭터 / 난이도 상태

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

## 14. Signal 구조

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

## 15. Player 고유 상태

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

## 16. 스탯 패널 상태

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

## 17. 상태 소유권 주의사항

- 블록/Day/상점 아이템 콘텐츠 데이터는 `GameState`가 소유하지 않는다.
- intermission 진행 플래그는 `GameState`가 아니라 `Main.gd`가 소유한다.
- 배터리와 대시 쿨다운은 `Player.gd`가 소유한다.
- 공격모듈 장착/보유 상태는 `GameState.gd`가 소유한다.
- 공격모듈별 순간 쿨다운은 `Player.gd`가 소유한다.
- 상점 아이템 롤 결과는 해당 intermission 동안 `Main.gd`가 `_current_shop_item_ids`로 들고 있다.
- 구매 결과와 런 효과는 `GameState.gd`가 소유한다.
- 아이템별 조건부 효과는 아이템 ID 분기가 아니라 condition/effect/apply_timing 해석으로 처리한다.

---

## 18. 문서 갱신 체크리스트

데이터/상태 구조를 바꿀 때는 아래를 확인한다.

- `GameConstants`에 콘텐츠 데이터가 새로 섞이지 않았는가
- `.tres` 데이터와 로더가 일치하는가
- `GameState` getter와 UI 표시가 일치하는가
- `DayShopUI` snapshot과 `GameState.get_day_shop_snapshot()`이 일치하는가
- 공격모듈 다중 장착 구조와 UI 표시가 일치하는가
- `Player` 고유 상태를 저장 상태로 잘못 문서화하지 않았는가
- 새 signal이 있다면 소비처와 함께 적었는가
- 새 조건부 아이템이 아이템 ID 하드코딩 없이 condition/effect/apply_timing 구조로 표현되는가
