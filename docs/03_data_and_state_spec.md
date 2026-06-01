# Burial Protocol - Data and State Specification

기준일: `2026-06-01`
기준 브랜치: `main`

---

## 0. 목적

이 문서는 Burial Protocol의 데이터 소유권, 저장 상태, 런타임 상태, UI signal 구조를 정리한다.
신규 장비 체계는 Phase 1 확정 설계다.
`GameState`는 Phase 3 신규 슬롯 상태를 사용하며, `Player/Main`은 Phase 4 신규 무기·프로토콜 트리거를 사용한다.

---

## 1. 상태 층 구분

1. 저장 상태
2. 현재 런 상태
3. 씬 내부 진행 상태
4. 플레이어 순간 동작 상태

원칙:

- 저장/런타임 공용 상태는 `GameState.gd`
- 콘텐츠 데이터 로딩은 `GameData.gd`
- 전역 상수는 `GameConstants.gd`
- 씬 진행 플래그는 `Main.gd`
- 플레이어 순간 동작 상태는 `Player.gd`

---

## 2. GameConstants

`GameConstants.gd`는 전역 상수와 정적 유틸만 가진다.

포함 범위:

- 기준 해상도와 월드 크기
- HUD 레이아웃과 색상
- 이동, 채굴, 대시 수치
- 모래 무기 피해율과 fallback 셀 HP
- 장비 슬롯 제한과 공통 등급 배율
- intermission 유해물질 수치
- 키오스크와 페이드 수치
- 난이도 옵션
- 입력 바인딩
- 레벨업 카드 정의
- 상점 아이템 랭크별 fallback 가격

장비 콘텐츠 테이블은 `GameConstants.gd`에 넣지 않는다.
무기, 드론, 드론 프로토콜, 패시브 모듈 정의는 데이터 리소스와 카탈로그가 소유한다.

---

## 3. GameData

`GameData.gd`는 콘텐츠 데이터 로딩 진입점이다.

현재 주요 preload:

- `data/blocks/BlockCatalog.tres`
- `data/stages/StageTable.tres`
- `data/items/ShopItemCatalog.tres`
- `scripts/data/ShopItemCatalog.gd`
- `scripts/data/BlockSpawnResolver.gd`

현재 `get_attack_module_*()` 접근자는 legacy다.
Phase 2에서 장비 정의 접근자를 아래 단위로 분리한다.

- 무기 정의 접근
- 기본 드론 정의 접근
- 드론 프로토콜 정의 접근
- 패시브 모듈 정의 접근
- 상점 아이템 정의 접근
- 상점 아이템 롤

---

## 4. Block Data

최신 블록 데이터 모델:

```text
Runtime Block = Material x Size + optional Type
```

`Material`, `Size`, `Type`, `BlockSpawnResolver`의 기존 역할은 유지한다.
장비 개편은 블록 데이터 구조를 변경하지 않는다.

---

## 5. Shop Item Data

신규 장비 카테고리:

| 카테고리 | 의미 |
|---|---|
| `weapon` | 좌측/우측 슬롯 무기 |
| `drone` | 드론 본체. 현재는 기본 드론만 사용 |
| `drone_protocol` | 기본 드론이 자동 실행하는 행동 |
| `passive_module` | 무기와 프로토콜을 조건부 강화하는 장비 |

유지할 상점 개념:

- 상점 아이템 5개 롤
- 가격 표시와 골드 차감
- 랭크 기반 fallback 가격
- 상점 잠금
- 리롤
- 구매 성공 시 현재 목록에서 제거

원본 데이터의 `attack_module`, `function_module`, `enhance_module`은 런타임에서 각각 `weapon`, `drone_protocol`, `passive_module`로 정규화한다.
과도기 `part`, `artifact` 분기는 legacy 호환을 위해 남아 있다.
신규 카테고리와 legacy 카테고리를 동시에 활성 장비 체계로 운용하지 않는다.

Phase 2에서는 런타임 호환을 위해 raw `item_category`를 유지하고, 신규 분류를 `equipment_category`로 병행 저장한다.
Phase 5에서는 `equipment_category`를 기준으로 상점 런타임 카테고리를 승격했다.

---

## 6. Equipment Definition Schema

공통 장비 정의는 기존 `ShopItemDefinition`을 일반화하거나 별도 `EquipmentDefinition`으로 분리한다.
Phase 2에서 실제 리소스 클래스를 결정한다.

권장 공통 필드:

- `item_id`
- `name`
- `item_category`
- `equipment_category`
- `rank`
- `price_gold`
- `shop_enabled`
- `shop_spawn_weight`
- `attribute`
- `attack_type`
- `conditions`
- `effects`
- `apply_timing`
- `tags`
- `icon_path`
- `short_desc`
- `desc`

무기 전용 필드 예시:

- `weapon_base_damage`
- `weapon_base_cooldown`
- `projectile_scene`
- `range_units`
- `visual_scene`

드론 프로토콜 전용 필드 예시:

- `protocol_base_damage`
- `protocol_base_cooldown`
- `protocol_behavior`
- `targeting`

패시브 모듈 전용 필드 예시:

- `stackable`
- `max_stack`
- `exclusive_group`

---

## 7. Passive Effect Schema

원칙:

```text
패시브 모듈 = 기본 정보 + 조건 목록 + 효과 목록 + 적용 타이밍
```

아이템 ID별 분기 하드코딩을 금지한다.

권장 condition:

- `equipment_attribute_is`
- `equipment_type_is`
- `equipped_attribute_count_at_least`
- `equipped_type_count_at_least`
- `weapon_slot_has_type`
- `protocol_type_is`
- `protocol_attribute_is`
- `weight_ratio_at_least`
- `hp_ratio_below`

권장 effect:

- `weapon_damage_percent`
- `drone_damage_percent`
- `attribute_damage_percent`
- `type_damage_percent`
- `projectile_additional_shot`
- `beam_split_count`
- `chain_additional_count`
- `explosion_radius_add_units`
- `area_duration_percent`
- `protocol_cooldown_reduction_percent`
- `sand_remove_count_bonus`
- `healing_amount_bonus`

권장 apply timing:

- `stat_query`
- `on_weapon_attack_start`
- `on_weapon_hit`
- `on_protocol_trigger`
- `on_protocol_hit`
- `on_sand_removed`
- `on_player_healed`

예시:

```gdscript
{
    "item_id": "beam_splitter",
    "item_category": "passive_module",
    "rank": "B",
    "conditions": [
        {"type": "equipment_type_is", "attack_type": "beam"}
    ],
    "effects": [
        {"type": "beam_split_count", "value": 1}
    ],
    "apply_timing": "on_weapon_attack_start"
}
```

---

## 8. 저장 상태

저장 주체: `scripts/autoload/GameState.gd`

- 경로: `user://profile.save`
- 형식: JSON
- 버전 필드: `save_version`

현재 저장 범위:

- 선택 캐릭터
- 마지막 선택 난이도
- 해금 캐릭터와 난이도
- 최고 기록
- 영구 재화
- 설정
- 성장 데이터
- 업적 데이터

현재 런 장비는 영구 저장 대상이 아니다.

---

## 9. 신규 런 상태 목표

Phase 3에서 `GameState.gd`가 소유할 장비 상태:

- `equipped_weapon_left`
- `equipped_weapon_right`
- `owned_weapon_ids`
- `equipped_drone_id`
- `equipped_drone_protocols`
- `owned_drone_protocol_ids`
- `equipped_passive_modules`
- `owned_passive_module_ids`
- `weapon_runtime_state`
- `drone_protocol_runtime_state`

신규 런 전투 스탯:

- `run_bonus_weapon_attack_damage`
- `run_bonus_drone_attack_damage`
- `run_weapon_attack_speed_mult`
- `run_drone_cooldown_reduction`

유지 가능한 공통 스탯:

- 공격범위
- 치명타 확률과 배율
- 최대 체력
- 방어력
- HP 재생
- 이동속도
- 점프력
- 채굴 데미지, 속도, 범위
- 행운
- 이자율
- 최대 중량
- 배터리 회복

`run_drone_cooldown_reduction`은 희귀 스탯이며 레벨업 카드 기본 풀에 넣지 않는다.

---

## 10. Legacy 런 상태 충돌

현재 `GameState.gd`에는 아래 legacy 필드와 helper가 남아 있다.

- `run_bonus_melee_attack_damage`
- `run_bonus_ranged_attack_damage`
- `run_attack_speed_mult`
- `owned_attack_module_ids`
- `equipped_attack_module_id`
- `equipped_attack_modules`
- `attack_module_runtime_state`
- `owned_function_module_ids`
- `owned_enhance_module_counts`
- `get_input_attack_module_entries()`
- `get_mechanic_attack_module_entries()`
- `get_attack_module_damage()`
- `get_mechanic_attack_module_damage()`
- `get_attack_module_cooldown_duration()`
- `can_add_or_synthesize_attack_module()`

Phase 3에서는 신규 상태를 추가한 뒤 legacy 다중 공격모듈 경로를 제거한다.
두 상태 집합을 동시에 실제 전투 소스로 사용하지 않는다.

현재 구현에서는 신규 장비 슬롯을 원본 상태로 사용한다.
`owned_attack_module_ids`, `equipped_attack_module_id`, `equipped_attack_modules`, `attack_module_changed`, `owned_attack_modules_changed`는 legacy 호환 미러다.
`get_input_attack_module_entries()`는 좌·우 무기 엔트리를 반환하며, `get_mechanic_attack_module_entries()`는 빈 배열을 반환한다.

---

## 11. 레벨업 카드

제거 또는 deprecated 처리:

- `melee_atk_up`
- `ranged_atk_up`

신규 기본 풀:

- `weapon_attack_up`
- `drone_attack_up`
- `attack_speed_up`
- 기존 공통 생존, 이동, 채굴, 경제 카드

기본 풀에서 제외:

- `drone_cooldown_reduction_up`

드론 쿨타임 감소는 상점 장비, 희귀 효과, 특수 보상으로 제공한다.

현재 코드의 기본 카드 풀은 `weapon_attack_up`, `drone_attack_up`, `attack_speed_up`을 사용한다.
`melee_atk_up`, `ranged_atk_up`은 기본 풀에서 제거했다.

---

## 12. Player 순간 상태 목표

`Player.gd`가 소유할 순간 상태:

- 좌측 무기 쿨타임
- 우측 무기 쿨타임
- 프로토콜 인스턴스별 쿨타임
- 무기 좌/우 비주얼
- 플레이어 상단 드론 비주얼
- 배터리
- 채굴 쿨타임
- 대시 쿨타임
- 피격 피드백

현재 `attack_module_cooldowns`는 좌·우 무기 인스턴스별 쿨타임으로 사용한다.
`drone_protocol_cooldowns`는 프로토콜 인스턴스별 쿨타임을 소유한다.
좌·우 무기 비주얼과 플레이어 상단 기본 드론 비주얼을 표시한다.

---

## 13. Main 씬 진행 상태

`Main.gd`가 소유하는 진행 플래그:

- `_is_day_active`
- `_is_intermission`
- `_intermission_hazard_state`
- `_intermission_hazard_time_remaining`
- `_intermission_hazard_state_elapsed`
- `_intermission_hazard_damage_accumulator`
- `_intermission_hazard_glitch_elapsed`
- `_is_next_day_transitioning`
- `_shop_ui_open`
- `_waiting_for_day_kiosk`
- `_pending_wall_reset_for_next_day`
- `_current_shop_item_ids`

intermission 유해물질 상태는 장비 개편과 독립적으로 유지한다.

---

## 13-1. Phase 5 상점 장착 상태

`GameState.purchase_shop_item(item_id, equipment_targets)`는 신규 장비 카테고리를 직접 처리한다.

- `weapon`: 빈 무기 슬롯 우선 장착, 가득 찬 경우 `weapon_slot`으로 교체 대상 지정
- `drone_protocol`: 빈 프로토콜 슬롯 우선 장착, 가득 찬 경우 `drone_protocol_slot`으로 교체 대상 지정
- `passive_module`: 빈 패시브 슬롯 우선 장착, 가득 찬 경우 `passive_module_slot`으로 교체 대상 지정

패시브 모듈 런타임 효과는 구매 인스턴스의 `source_instance_id`를 기록한다.
슬롯 교체 시 해당 source-instance의 효과와 스탯 기여분만 제거한 뒤 새 효과를 적용한다.

---

## 14. Signal 목표

Phase 3~5에서 UI와 Player가 소비할 signal:

- `weapons_changed`
- `drone_changed`
- `drone_protocols_changed`
- `passive_modules_changed`
- `run_items_changed`
- 기존 `gold_changed`, `health_changed`, `xp_changed`, `level_changed`

현재 `attack_module_changed`, `owned_attack_modules_changed`는 legacy다.

---

## 14-1. SandField 런타임 상태

`SandField.gd`의 `sand_cells`는 셀 위치별 `SandCellData`를 저장한다.

- `SandCellData.max_hp`, `SandCellData.hp`는 float다.
- 블록 분해 시 `max_hp = source_block_final_hp / generated_sand_cell_count`로 계산한다.
- 블록 정보가 없는 수동 생성 셀은 `SAND_FALLBACK_CELL_HP = 1.0`을 사용한다.
- `apply_weapon_damage_*()`는 `damage_source == "weapon"`일 때만 무기 피해의 `10%`를 적용한다.
- 드론 프로토콜은 일반 피해 API를 통해 모래를 손상시킬 수 없다.
- `sand_cleaner`는 `remove_nearest_sand_cells()` 특수 제거 경로를 사용한다.
- `sand_cells_removed(removed_count, removal_source)` signal은 기존 XP 누적 경로만 호출한다. 골드는 지급하지 않는다.

---

## 15. 스탯 패널 목표

신규 표시 항목:

- 좌측 무기
- 우측 무기
- 드론
- 드론 프로토콜
- 패시브 모듈
- 무기 공격력
- 드론 공격력
- 공격속도
- 드론 쿨타임 감소
- 공격범위
- 치명타 확률과 배율
- 생존, 이동, 채굴, 경제 스탯

근거리 공격력과 원거리 공격력 표시는 제거한다.

---

## 16. 상태 소유권 주의사항

- 콘텐츠 테이블을 `GameConstants.gd`에 넣지 않는다.
- 무기와 프로토콜 정의는 데이터 리소스가 소유한다.
- 장착 상태와 런 보너스는 `GameState.gd`가 소유한다.
- 무기와 프로토콜의 순간 쿨타임은 `Player.gd`가 소유한다.
- 전투 판정과 씬 노드 생성은 `Main.gd`가 담당한다.
- 상점 롤 결과는 해당 intermission 동안 `Main.gd`가 소유한다.
- 조건부 효과는 아이템 ID가 아니라 condition/effect/apply_timing 해석으로 처리한다.
- legacy 공격모듈 5개 장착 구조와 신규 무기 2개 구조를 동시에 활성화하지 않는다.
- 신규 우측 무기를 우클릭 입력에 연결하지 않는다.

---

## 17. 문서 갱신 체크리스트

- 신규 장비 카테고리가 `weapon`, `drone`, `drone_protocol`, `passive_module`로 일치하는가
- 근거리/원거리 공격력이 신규 설계에서 제거되었는가
- 공격속도와 드론 쿨타임 감소의 적용 대상이 분리되어 있는가
- 드론 쿨타임 감소가 레벨업 카드 기본 풀에 들어가지 않았는가
- Player의 순간 쿨타임과 GameState의 장착 상태가 분리되어 있는가
- 상점 기존 흐름을 유지하면서 카테고리만 마이그레이션하는가
- 패시브 효과가 아이템 ID 하드코딩 없이 표현되는가
