# Burial Protocol - Data and State Specification

기준일: `2026-06-05`
기준 브랜치: `main`

---

## 0. 목적

이 문서는 Burial Protocol의 데이터 소유권, 저장 상태, 런타임 상태, UI signal 구조를 정리한다.
장비/성장 객체는 신규 설계 기준인 `Weapon / Protocol / Module / Item` 4분류로 설명한다.

현재 코드와 데이터에 남아 있는 `attack_module/function_module/enhance_module`은 legacy 구현명이며, 신규 문서에서는 최종 설계 카테고리처럼 사용하지 않는다.

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
- 무기 슬롯 기준
- 프로토콜 최대 장착 수
- 모듈 최대 장착 수
- 중량 한도와 표시 스케일
- 키오스크/페이드 수치
- 난이도 옵션
- 입력 바인딩
- 레벨업 카드 정의
- 상점 랭크별 가격 기본값 (`SHOP_ITEM_RANK_FALLBACK_PRICES`)
- 공통 계산 유틸

중요:

`GameConstants.gd`에 콘텐츠 테이블을 계속 추가하지 않는다.
블록, 스테이지, 무기, 프로토콜, 모듈, 아이템은 별도 `.tres`, `data_tsv`, 데이터 해석 스크립트가 소유한다.

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
- 상점 상품 정의 접근
- 상점 상품 롤
- legacy 장비 데이터를 신규 `Weapon / Protocol / Module / Item` 의미로 해석하는 migration 경로 제공

향후 분리 후보:

```text
WeaponCatalog
ProtocolCatalog
ModuleCatalog
ItemCatalog
```

단, 실제 파일 분리는 코드 변경 작업에서 별도 판단한다.
현재 문서는 의미 분리와 migration 기준을 우선 확정한다.

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

현재 v1 라이브 스폰에서는 `max_allowed_area`, `max_allowed_width`, `max_allowed_height`가 material-size 조합 후보를 실제로 차단한다.

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
- v2 group/pressure/rule 확장 필드

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

## 6. Equipment / Shop Data

상점 상품 데이터는 현재 `data/items/ShopItemCatalog.tres`와 `scripts/data/ShopItemCatalog.gd`가 담당한다.

### 6-1. 신규 canonical category

신규 문서와 신규 데이터 설계는 아래 카테고리를 기준으로 한다.

| 카테고리 | 의미 |
|---|---|
| `weapon` | 좌/우 슬롯에 장착하는 기본공격 장비 |
| `protocol` | 드론에 최대 5개 장착하는 자동공격 장비 |
| `module` | 최대 5개 장착하는 패시브 스킬 장비 |
| `item` | 기본 소지 제한 없는 스탯 제공품 |

### 6-2. legacy category 매핑

현재 코드/데이터에 남아 있는 legacy category는 아래 기준으로 migration한다.

| legacy category | 신규 분류 기준 |
|---|---|
| `attack_module` | 입력 기반 공격이면 `weapon`, 자동공격이면 `protocol` |
| `function_module` | 패시브 룰 변경이면 `module`, 단순 보상/효과면 `item` |
| `enhance_module` | 대부분 `item`, 조건부 빌드 변형이면 `module` |

legacy category를 새 문서의 canonical category처럼 설명하지 않는다.

### 6-3. 랭크

장비/아이템 랭크:

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

## 7. Combat Data Model

무기와 프로토콜은 공격 판정 데이터를 가진다.
모듈과 아이템은 기본적으로 직접 공격 판정을 생성하지 않는다.

### 7-1. 공통 공격 데이터 필드

| 필드 | 의미 | 소유 성격 |
|---|---|---|
| `attribute` | 피해/연출 속성 | 유저/데이터 공용 |
| `attack_type` | 유저가 보는 공격 유형/시너지 태그 | 유저/빌드용 |
| `activation_mode` | 입력 또는 자동 발동 방식 | 구현/데이터용 |
| `hit_model` | 실제 피해 판정 생성 방식 | 구현/데이터용 |
| `hit_shape` | 실제 충돌/피해 판정용 추상 shape | 구현/데이터용 |
| `effect_style` | 실제 데미지 판정과 분리된 시각 연출 타입 | 아트/연출용 |
| `base_cooldown` | 피해 발생 기본 주기 | 밸런스/런타임 공용 |

`attribute` 권장 값:

- `electric`
- `fire`
- `physical`
- `energy`
- `chemical`

`attack_type` 권장 값:

- `support`
- `projectile`
- `area`
- `linear`
- `chain`
- `explosion`

`attack_type`은 개발 구현명이 아니라 유저가 장비 화면에서 확인할 유형이다.
조건부 효과와 시너지 판단에 활용될 수 있다.

### 7-2. activation_mode

| 값 | 의미 | 사용 계층 | 예시 |
|---|---|---|---|
| `hold_repeat` | 공격키를 누르고 있으면 `base_cooldown`마다 공격 인스턴스 생성 | Weapon | 권총, 샷건, 로켓 |
| `hold_channel` | 공격키를 누르고 있으면 판정 유지, `base_cooldown`마다 피해 | Weapon | 화염방사기, 지속 레이저 |
| `auto_repeat` | 공격키와 무관하게 `base_cooldown`마다 자동 공격 | Protocol | 자동 드론 사격 |
| `auto_channel` | 공격키와 무관하게 지속 판정 유지, `base_cooldown`마다 피해 | Protocol | 자동 영역 프로토콜 |

`click_once`는 사용하지 않는다.
단발형 무기라도 공격키를 누르고 있으면 `base_cooldown`마다 반복 발사한다.

### 7-3. hit_model

| 값 | 의미 | 예시 |
|---|---|---|
| `melee_shape` | 캐릭터 기준 근거리 shape 판정 | 소드, 랜스, 대검 |
| `projectile_single` | 단일 투사체 | 권총, 코어 슈터 |
| `projectile_spread` | 확산형 다중 투사체 | 샷건, 크레모아 |
| `projectile_pierce` | 관통 투사체 | 스나이퍼, 레일 드릴 |
| `projectile_explosion` | 착탄 후 폭발하는 투사체 | 로켓, 유탄, 네이팜 런처 |
| `hitscan_line` | 즉시 직선 1회 판정 | 저격총, 즉발 레이저 |
| `channel_line` | 유지형 직선 판정 | 지속 레이저, 이온 빔 |
| `channel_cone` | 유지형 부채꼴 판정 | 화염방사기 |
| `area_zone` | 특정 위치에 생성되는 지속 영역 | 독구름, 화염지대 |
| `area_orbit` | 플레이어/드론 주변 지속 영역 | 톱날 링, 커터 링 |
| `chain_jump` | 대상 간 전이 | 체인 라이트닝, 스파크 테이저 |

### 7-4. hit_shape

권장 값:

- `point`
- `line`
- `cone`
- `circle`
- `box`
- `ring`
- `arc`

`effect_style`은 판정이 아니라 VFX/연출 선택만 담당한다.
동일한 `hit_shape=line`이라도 저격총은 `sniper_tracer`, 지속 레이저는 `laser_beam`, 이온 빔은 `ion_beam`처럼 서로 다른 VFX를 쓸 수 있다.

`effect_style` 값으로 데미지, 사거리, 충돌 범위를 바꾸면 안 된다.
판정은 `hit_model`, `hit_shape`, `range_units`, `angle_degrees`, `explosion_radius_u` 같은 수치 필드가 소유한다.

### 7-5. legacy 필드 정리

기존 원거리/투사체 계열 수치 필드:

- `projectile_count`
- `angle_degrees`
- `pierce_count`
- `range_units`
- `projectile_speed`
- `explosion_radius_u`
- `chain_count`
- `area_duration`
- `sand_damage_ratio`
- `sand_collision_policy`

기존 `spread_angle`은 장기적으로 `angle_degrees`로 정리한다.
기존 `fire_mode`는 장기적으로 `activation_mode + hit_model`로 분리한다.
기존 `attack_style`은 당분간 legacy/style alias로 유지할 수 있으나, 신규 데이터는 `attribute + attack_type + activation_mode + hit_model + hit_shape + effect_style` 조합을 기준으로 한다.

legacy alias인 `projectile_spread_degrees`, `projectile_pierce_count`, `projectile_hit_scan`, `projectile_size`는 사용하지 않는다.

---

## 8. Item / Effect Object Schema

조건부 아이템, 보물상자 보상, 모듈, 레벨업 카드가 늘어나기 전에 효과 객체 스키마를 먼저 정의한다.

원칙:

```text
효과 객체 = 기본 정보 + 조건 목록 + 효과 목록 + 적용 타이밍
```

아이템별로 코드를 하드코딩하지 않는다.
새 효과는 가능한 한 데이터 추가로 표현하고, 코드는 condition/effect/apply_timing 타입을 해석하는 공통 엔진을 확장한다.

### 8-1. 기본 필드

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
- `unique`
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
조건부 아이템이나 모듈은 `conditions`, `effects`, `apply_timing`을 함께 사용한다.

### 8-2. 조건부 효과 예시

예시: 무게가 60% 이상일 때 공격력 증가

```gdscript
{
    "item_id": "pressure_overdrive",
    "name": "압력 과부하 장치",
    "rank": "B",
    "item_category": "module",
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

예시: 좌/우 무기가 모두 근거리일 때 공격력 증가

```gdscript
{
    "item_id": "melee_purity_core",
    "name": "근접 순도 코어",
    "rank": "A",
    "item_category": "module",
    "effect_type": "conditional_stat_bonus",
    "conditions": [
        {
            "type": "all_weapons_attack_tag",
            "attack_tag": "melee"
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
    "item_category": "module",
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

### 8-3. Condition 타입

상시 상태 조건:

- `weight_ratio_at_least`
- `weight_ratio_below`
- `hp_ratio_at_least`
- `hp_ratio_below`
- `gold_at_least`
- `current_day_at_least`
- `equipped_weapon_count_at_least`
- `equipped_protocol_count_at_least`
- `equipped_module_count_at_least`
- `has_weapon_attribute`
- `has_weapon_attack_type`
- `has_protocol_attribute`
- `has_protocol_attack_type`
- `all_weapons_attack_tag`
- `all_protocols_attack_tag`

공격 순간 조건:

- `source_category_is`
- `weapon_slot_is`
- `attack_attribute_is`
- `attack_type_is`
- `attack_hit_side`
- `player_is_airborne`
- `target_block_size_at_least`
- `is_critical_hit`

이벤트 조건:

- `destroyed_block_material_is`
- `destroyed_block_type_is`
- `sand_removed_at_least`
- `shop_item_rank_is`

legacy condition 이름은 신규 이름으로 이전한다.

| legacy condition | 신규 condition |
|---|---|
| `all_attack_modules_type` | `all_weapons_attack_tag` 또는 `all_protocols_attack_tag` |
| `equipped_attack_module_count_at_least` | `equipped_weapon_count_at_least` 또는 `equipped_protocol_count_at_least` |
| `has_attack_module_type` | `has_weapon_attack_type` 또는 `has_protocol_attack_type` |
| `attack_module_type_is` | `source_category_is` + `attack_type_is` |

### 8-4. Effect 타입

스탯 효과:

- `attack_damage_flat`
- `attack_damage_percent`
- `weapon_damage_flat`
- `protocol_damage_flat`
- `attack_speed_percent`
- `weapon_attack_speed_percent`
- `protocol_attack_speed_percent`
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

- `sand_remove_count`, `queue_wall_reset_next_day` 같은 환경대응 효과는 레벨업 카드가 아니라 상점 아이템, 보물상자 보상, 특수 이벤트에서만 사용한다.
- 모듈은 위 효과를 조건부로 제공할 수 있다.
- 아이템은 위 효과를 누적 스탯으로 제공할 수 있다.

### 8-5. Apply Timing

| apply_timing | 의미 | 예시 |
|---|---|---|
| `on_purchase` | 구매 즉시 적용 | 최대 체력 증가, 아이템 스택 증가 |
| `on_equip` | 장착 시 적용 | 모듈 장착 효과 등록 |
| `stat_query` | 최종 스탯 계산 시 검사 | 무게 60% 이상 공격력 증가 |
| `on_attack_start` | 공격 시작 시 검사 | 좌 슬롯 무기만 강화 |
| `on_attack_hit` | 공격이 블록에 적중한 순간 검사 | 옆면 공격 시 데미지 증가 |
| `on_block_destroyed` | 블록 파괴 시 검사 | 골드 추가 획득 |
| `on_sand_removed` | 모래 제거 시 검사 | 채굴 보너스 XP |
| `on_day_started` | Day 시작 시 검사 | 시작 보호막, 임시 버프 |
| `on_day_ended` | Day 종료 시 검사 | 이자 보너스, 벽 복구 예약 |
| `on_player_damaged` | 플레이어 피격 시 검사 | 반격, 방어 버프 |

---

## 9. 저장 상태

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

## 10. 현재 런 상태

현재 런 상태는 주로 `GameState.gd`가 소유한다.

기본 런 필드:

- `gold`
- `player_health`
- `status_text`
- `current_run_stage_reached`
- `current_day`
- `day_time_remaining`
- `run_cleared`
- `current_shop_reroll_count`
- `current_shop_locked_slots`

상점 lock 상태는 현재 런/intermission 상태다.
lock된 슬롯은 다음 shop roll에서 같은 슬롯의 한 자리를 차지하며 보존되고, 추가 상품으로 붙지 않는다.

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

## 11. 장비 상태

### 11-1. 신규 상태 모델

최종 설계상 `GameState.gd`는 아래 상태를 소유해야 한다.

| 상태 | 의미 |
|---|---|
| `owned_weapon_ids` | 보유 무기 |
| `equipped_weapon_slots` | 좌/우 무기 슬롯 상태 |
| `owned_protocol_ids` | 보유 프로토콜 |
| `equipped_protocols` | 드론에 장착된 최대 5개 프로토콜 |
| `owned_module_ids` | 보유 모듈 |
| `equipped_modules` | 장착된 최대 5개 패시브 모듈 |
| `owned_item_counts` | 소지 아이템과 스택 수 |
| `current_run_effects` | 현재 런 효과 목록 |

### 11-2. 현재 legacy 상태

현재 코드에는 아래 legacy 상태가 남아 있을 수 있다.

- `owned_attack_module_ids`
- `equipped_attack_module_id`
- `equipped_attack_modules`
- `attack_module_instance_sequence`
- `attack_module_runtime_state`
- `owned_function_module_ids`
- `owned_enhance_module_counts`
- `current_run_items`
- `current_run_effects`

migration 기준:

| legacy 상태 | 신규 상태 후보 |
|---|---|
| `owned_attack_module_ids` | `owned_weapon_ids` 또는 `owned_protocol_ids` |
| `equipped_attack_module_id` | 호환용 제거 대상 |
| `equipped_attack_modules` | `equipped_weapon_slots` 또는 `equipped_protocols` |
| `attack_module_runtime_state` | 무기/프로토콜별 runtime state로 분리 |
| `owned_function_module_ids` | `owned_module_ids` 또는 특수 item |
| `owned_enhance_module_counts` | `owned_item_counts` |
| `current_run_items` | `owned_item_counts` 또는 `current_run_effects` |

### 11-3. Player 고유 상태

`Player.gd`는 아래처럼 플레이어 고유 런타임 상태를 가진다.

- `velocity`
- `facing`
- `extra_jumps_left`
- `jump_buffer_remaining`
- `coyote_time_remaining`
- 무기 공격 쿨다운
- 프로토콜 발동 쿨다운 또는 드론 runtime state
- `mining_cooldown`
- `dash_cooldown_remaining`
- `current_battery`
- `is_wall_climbing`
- `damage_cooldown`
- `hurt_flash_remaining`
- 장비 시각 표현 상태

현재 `attack_module_cooldowns` 같은 legacy 이름은 신규 상태로 분리 대상이다.

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

향후 분리 후보:

- `get_weapon_damage()`
- `get_protocol_damage()`
- `get_weapon_cooldown_duration(slot)`
- `get_protocol_cooldown_duration(protocol_instance)`
- `get_module_effects()`
- `get_item_stat_bonuses()`

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
- `equipment_changed`
- `weapon_changed`
- `protocol_changed`
- `module_changed`
- `items_changed`
- `run_items_changed`

현재 코드에 남아 있을 수 있는 legacy signal:

- `attack_module_changed`
- `owned_attack_modules_changed`

legacy signal은 신규 장비 signal로 migration 대상이다.

주요 소비처:

- `HUD`
- 허브/캐릭터 선택 UI
- `LevelUpUI`
- `PauseMenu`
- `DayShopUI`
- `Player`

---

## 15. 스탯 패널 상태

`PauseMenu.gd`는 `GameState.get_stat_panel_entries()`가 반환하는 배열을 사용한다.

현재 표시 항목:

- 장비 요약
- 무기 슬롯
- 프로토콜 슬롯
- 모듈 슬롯
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

현재 UI가 legacy 공격모듈만 표시한다면 migration 필요 상태로 본다.

---

## 16. 상태 소유권 주의사항

- 블록/Day/상점 상품 콘텐츠 데이터는 `GameState`가 소유하지 않는다.
- intermission 진행 플래그는 `GameState`가 아니라 `Main.gd`가 소유한다.
- 배터리와 대시 쿨다운은 `Player.gd`가 소유한다.
- 무기/프로토콜/모듈/아이템 보유 및 장착 상태는 `GameState.gd`가 소유한다.
- 무기별 순간 쿨다운은 `Player.gd` 또는 장비 runtime state가 소유한다.
- 프로토콜 자동공격 runtime state는 드론/프로토콜 시스템이 소유한다.
- 상점 아이템 롤 결과는 해당 intermission 동안 `Main.gd`가 `_current_shop_item_ids`로 들고 있다.
- 구매 결과와 런 효과는 `GameState.gd`가 소유한다.
- 아이템별 조건부 효과는 아이템 ID 분기가 아니라 condition/effect/apply_timing 해석으로 처리한다.

---

## 17. 문서 갱신 체크리스트

데이터/상태 구조를 바꿀 때는 아래를 확인한다.

- `GameConstants`에 콘텐츠 데이터가 새로 섞이지 않았는가
- `.tres` 데이터와 로더가 일치하는가
- `GameState` getter와 UI 표시가 일치하는가
- `DayShopUI` snapshot과 `GameState.get_day_shop_snapshot()`이 일치하는가
- Weapon/Protocol/Module/Item 카테고리가 legacy category와 혼동되지 않는가
- 무기 좌/우 슬롯 구조와 UI 표시가 일치하는가
- 프로토콜 최대 5개 장착 구조와 UI 표시가 일치하는가
- 모듈 최대 5개 장착 구조와 UI 표시가 일치하는가
- 아이템 기본 소지 제한 없음 원칙과 stack/unique 처리가 일치하는가
- `Player` 고유 상태를 저장 상태로 잘못 문서화하지 않았는가
- 새 signal이 있다면 소비처와 함께 적었는가
- 새 조건부 효과가 아이템 ID 하드코딩 없이 condition/effect/apply_timing 구조로 표현되는가
- `fire_mode` 의존이 `activation_mode + hit_model` 구조로 병행/이전되는가
- `attack_type`이 유저용 유형/시너지 값으로 유지되고, 구현 세부값은 `hit_model`에만 들어가는가
- `effect_style`이 판정/데미지와 분리된 VFX 선택값으로만 사용되는가
