# Burial Protocol - 모듈/아이템 시스템 개편 초안

기준일: `2026-05-26`  
목적: 기존 `공격모듈 5개 장착` 구조를 폐기하고, `무기 1개 + 파츠 5개 + 유물 누적` 구조로 개편하기 위한 기획/구현 기준을 정의한다.

---

## 0. 핵심 결론

기존 `모듈` 시스템은 아래 구조로 개편한다.

```text
기존 공격모듈       → 무기(weapon)
기존 기능/강화 모듈 → 파츠(part) 또는 유물(artifact)로 재분류
```

최종 아이템 체계는 아래 3종으로 구분한다.

| 분류 | 코드명 | 역할 | 장착/적용 방식 |
|---|---|---|---|
| 무기 | `weapon` | 공격 방식의 본체 | 1개만 장착 |
| 파츠 | `part` | 현재 장착 무기를 개조 | 최대 5개 장착 |
| 유물 | `artifact` | 런 전체 패시브/보조 효과 | 기본 장착 제한 없음, 구매 즉시 누적 |

핵심 방향:

```text
무기 = 플레이스타일 정체성
파츠 = 무기 커스터마이징
유물 = 런 전체 성장/패시브
```

---

## 1. 기존 시스템 개편 범위

### 1-1. 폐기되는 구조

아래 기존 구조는 폐기한다.

```text
공격모듈 최대 5개 장착
여러 공격모듈이 각각 독립 발동
공격모듈 중복 장착으로 다중 공격 구성
```

기존 공격모듈 데이터 자체는 버리지 않는다.  
단, 그 명칭과 장착 규칙을 변경한다.

```text
기존 공격모듈 데이터 → 무기 데이터로 승격/이관
```

### 1-2. 유지되는 개념

아래 개념은 유지하거나 이름만 바꿔 활용한다.

| 기존 개념 | 개편 후 |
|---|---|
| 공격모듈의 `module_type` | 무기의 `weapon_type` 또는 내부 호환 필드 |
| 공격모듈의 `attack_style` | 무기의 공격 스타일 |
| 공격모듈의 데미지/공속/범위 | 무기 기본 스탯 |
| 공격모듈의 visual scene | 무기 visual 또는 장착 무기 표시 |
| D/C/B/A/S 랭크 | 무기/파츠/유물 공통 랭크 |
| 조건/효과/적용 타이밍 구조 | 파츠/유물 효과 해석 기반 |

---

## 2. 용어 확정

### 2-1. 사용자 표시 용어

| 표시명 | 의미 |
|---|---|
| 무기 | 기존 공격모듈의 후속 개념 |
| 파츠 | 무기에 장착하는 개조 아이템 |
| 유물 | 런 전체에 적용되는 패시브 아이템 |

### 2-2. 코드/데이터 권장 용어

| 코드명 | 의미 |
|---|---|
| `weapon` | 무기 |
| `part` | 파츠 |
| `artifact` | 유물 |

신규 문서, UI, 아이템명, 상점 표시에서는 `무기 / 파츠 / 유물` 용어를 사용한다.

기존 코드 호환을 위해 내부 함수명이나 필드명에 `attack_module`이 임시로 남을 수는 있다.  
다만 신규 설계와 문서에서는 `weapon` 기준으로 정리한다.

---

## 3. 아이템 카테고리

### 3-1. 최종 카테고리

```text
weapon
part
artifact
```

### 3-2. 기존 카테고리 이관

| 기존 카테고리 | 개편 후 처리 |
|---|---|
| `attack_module` | `weapon`으로 이관 |
| `enhance_module` | 효과 성격에 따라 `part` 또는 `artifact`로 재분류 |
| `function_module` | 효과 성격에 따라 `artifact` 또는 특수 `part`로 재분류 |

분류 기준:

```text
현재 무기의 성능/동작을 바꾸면 part
플레이어/런/전장 전체에 영향을 주면 artifact
공격 방식의 본체이면 weapon
```

예:

| 아이템 | 분류 | 이유 |
|---|---|---|
| 레이저 이중화 파츠 | `part` | 레이저 무기 동작을 직접 변경 |
| 대검 경량화 부품 | `part` | 대검 무기 성능을 직접 변경 |
| 낡은 철사 | `artifact` | 런 전체 스탯 변경 |
| 중력제어장치 | `artifact` | 전장 규칙 변경 |
| 기존 소드 모듈 | `weapon` | 공격 방식의 본체 |

---

## 4. 무기 시스템

### 4-1. 정의

무기는 플레이어가 장착하는 공격 방식의 본체다.

```text
무기 = 기존 공격모듈의 후속 개념
```

무기는 1개만 장착 가능하다.

### 4-2. 장착 규칙

| 항목 | 규칙 |
|---|---|
| 최대 장착 수 | 1개 |
| 무기 교체 | 가능 |
| 기존 무기 처리 | 교체 시 장착 무기만 변경 |
| 파츠 처리 | 무기를 바꿔도 파츠는 삭제하지 않음 |
| 비호환 파츠 | 슬롯에 남지만 비활성화 |
| 다시 호환되는 무기 장착 | 비활성 파츠 자동 재활성화 |

### 4-3. 무기 기본 필드

권장 필드:

```gdscript
{
    "item_id": "greatsword_module",
    "name": "대검",
    "item_category": "weapon",
    "rank": "S",
    "weapon_type": "melee",
    "attack_style": "cleave",
    "effect_style": "big_cleave",

    "module_base_damage": 15,
    "attack_speed_multiplier": 0.65,
    "range_width_u": 1.5,
    "range_height_u": 1.0,

    "stagger_power": 4,

    "icon_path": "...",
    "world_visual_scene_path": "...",
    "tags": ["melee", "heavy", "burst"]
}
```

기존 `module_type`은 마이그레이션 초기에는 유지할 수 있다.  
단, 신규 명칭은 `weapon_type`을 권장한다.

### 4-4. 무기 타입

초기 무기 타입:

| 타입 | 의미 |
|---|---|
| `melee` | 근거리 무기 |
| `ranged` | 원거리 무기 |
| `mechanic` | 자동/메카닉 계열 무기 또는 후속 확장 영역 |

파츠 제한 조건은 특정 무기 ID뿐 아니라 무기 타입도 지원해야 한다.

예:

```text
laser_module 전용
greatsword_module 전용
melee 무기 전용
ranged 무기 전용
```

---

## 5. 파츠 시스템

### 5-1. 정의

파츠는 현재 장착한 무기에 추가 효과를 부여하는 아이템이다.

```text
파츠 = 무기 개조 아이템
```

파츠는 최대 5개 장착 가능하다.

### 5-2. 파츠 핵심 규칙

| 항목 | 규칙 |
|---|---|
| 최대 장착 수 | 5개 |
| 적용 대상 | 현재 장착한 무기 |
| 무기 교체 시 | 파츠는 삭제하지 않음 |
| 비호환 시 | 슬롯에 남지만 효과 비활성화 |
| 비활성 파츠 | UI에서 명확히 표시 |
| 효과 계산 | 활성 파츠만 반영 |
| 재활성화 | 호환되는 무기를 다시 장착하면 자동 적용 |

### 5-3. 파츠 제한 조건

파츠는 아래 제한 조건을 가질 수 있다.

| 제한 필드 | 의미 |
|---|---|
| `allowed_weapon_ids` | 특정 무기 ID 제한 |
| `allowed_weapon_types` | 근거리/원거리 등 무기 타입 제한 |
| `allowed_attack_styles` | `laser`, `cleave`, `sniper` 등 공격 스타일 제한 |
| `exclusive_group` | 같은 그룹 파츠 중복 장착 방지 |
| `stackable` | 동일 파츠 중복 장착 가능 여부 |
| `max_stack` | 최대 중복 수량 |

초기에는 최소 아래 3개를 지원한다.

```text
allowed_weapon_ids
allowed_weapon_types
exclusive_group
```

`allowed_attack_styles`는 후속 확장으로 둬도 된다.

### 5-4. 파츠 활성 여부 판정

파츠는 장착되어 있어도 현재 무기와 호환되지 않으면 비활성화된다.

판정 기준:

```text
1. allowed_weapon_ids가 비어 있지 않으면 현재 weapon_id가 포함되어야 한다.
2. allowed_weapon_types가 비어 있지 않으면 현재 weapon_type이 포함되어야 한다.
3. allowed_attack_styles가 비어 있지 않으면 현재 attack_style이 포함되어야 한다.
4. 위 조건 중 하나라도 실패하면 파츠는 비활성화된다.
5. 비활성 파츠는 효과 계산에서 제외된다.
6. 비활성 파츠는 슬롯을 계속 차지한다.
```

주의:

```text
비호환 파츠를 자동 삭제하거나 자동 해제하지 않는다.
```

### 5-5. 파츠 데이터 예시

#### 근거리 강화 파츠

```gdscript
{
    "item_id": "melee_power_part_a",
    "name": "근거리 강화 파츠",
    "rank": "A",
    "item_category": "part",
    "allowed_weapon_types": ["melee"],
    "effects": [
        {
            "type": "weapon_melee_damage_flat",
            "value": 10
        }
    ],
    "apply_timing": "stat_query"
}
```

#### 원거리 강화 파츠

```gdscript
{
    "item_id": "ranged_power_part_d",
    "name": "원거리 강화 파츠",
    "rank": "D",
    "item_category": "part",
    "allowed_weapon_types": ["ranged"],
    "effects": [
        {
            "type": "weapon_ranged_damage_flat",
            "value": 2
        }
    ],
    "apply_timing": "stat_query"
}
```

#### 공격속도 파츠

```gdscript
{
    "item_id": "attack_speed_part_c",
    "name": "공격속도 파츠",
    "rank": "C",
    "item_category": "part",
    "effects": [
        {
            "type": "weapon_attack_speed_percent",
            "value": 0.15
        }
    ],
    "apply_timing": "stat_query"
}
```

#### 레이저 조건부 데미지 파츠

```gdscript
{
    "item_id": "laser_damage_part_b",
    "name": "조건부 데미지 파츠",
    "rank": "B",
    "item_category": "part",
    "allowed_weapon_ids": ["laser_module"],
    "effects": [
        {
            "type": "weapon_damage_percent",
            "value": 0.20
        }
    ],
    "apply_timing": "stat_query"
}
```

#### 대검 조건부 공격범위 파츠

```gdscript
{
    "item_id": "greatsword_range_part_s",
    "name": "조건부 공격범위 파츠",
    "rank": "S",
    "item_category": "part",
    "allowed_weapon_ids": ["greatsword_module"],
    "effects": [
        {
            "type": "weapon_attack_range_percent",
            "value": 0.50
        }
    ],
    "apply_timing": "stat_query"
}
```

#### 도끼 조건부 공격속도 파츠

```gdscript
{
    "item_id": "axe_speed_part_c",
    "name": "조건부 공격속도 파츠",
    "rank": "C",
    "item_category": "part",
    "allowed_weapon_ids": ["axe_module"],
    "effects": [
        {
            "type": "weapon_attack_speed_percent",
            "value": 0.20
        }
    ],
    "apply_timing": "stat_query"
}
```

#### 레이저 이중화 파츠

```gdscript
{
    "item_id": "laser_dual_beam_part_s",
    "name": "레이저 이중화 파츠",
    "rank": "S",
    "item_category": "part",
    "allowed_weapon_ids": ["laser_module"],
    "exclusive_group": "laser_beam_modifier",
    "stackable": false,
    "max_stack": 1,
    "effects": [
        {
            "type": "laser_beam_count_add",
            "value": 1
        }
    ],
    "apply_timing": "weapon_attack_build",
    "short_desc": "[레이저 전용] 레이저가 2줄기로 발사됩니다."
}
```

#### 대검 경량화 부품

```gdscript
{
    "item_id": "greatsword_lightweight_part_a",
    "name": "대검 경량화 부품",
    "rank": "A",
    "item_category": "part",
    "allowed_weapon_ids": ["greatsword_module"],
    "effects": [
        {
            "type": "weapon_attack_speed_percent",
            "value": 0.75
        },
        {
            "type": "max_hp_percent",
            "value": -0.10
        }
    ],
    "apply_timing": "stat_query",
    "short_desc": "[대검 전용] 대검 공격속도가 75% 상승하지만, 체력이 10% 감소합니다."
}
```

#### 저격 스코프 모듈

```gdscript
{
    "item_id": "sniper_scope_part_a",
    "name": "저격 스코프 모듈",
    "rank": "A",
    "item_category": "part",
    "allowed_weapon_ids": ["pierce_module"],
    "effects": [
        {
            "type": "damage_multiplier_on_hit",
            "value": 1.50
        }
    ],
    "conditions": [
        {
            "type": "hit_distance_at_least",
            "value_u": 4.0
        }
    ],
    "apply_timing": "on_attack_hit",
    "short_desc": "[저격총 전용] 일정 이상 거리의 블록을 공격할 경우 50% 추가피해를 입힙니다."
}
```

---

## 6. 유물 시스템

### 6-1. 정의

유물은 플레이어 또는 런 전체에 패시브 효과를 부여하는 아이템이다.

```text
유물 = 구매 즉시 누적 적용되는 런 전체 패시브
```

### 6-2. 유물 핵심 규칙

| 항목 | 규칙 |
|---|---|
| 장착 슬롯 | 없음 |
| 기본 적용 | 구매 즉시 적용 |
| 기본 중복 | 가능 |
| 강한 효과 | `max_stack`으로 제한 |
| 효과 범위 | 플레이어 스탯, 경제, 전장 규칙, 보조 효과 |
| 무기 교체 영향 | 없음 |

유물은 기본적으로 장착 제한이 없다.  
단, 강한 유물은 `max_stack`으로 적용 제한을 둔다.

### 6-3. 유물 데이터 예시

#### 낡은 철사

```gdscript
{
    "item_id": "old_wire_d",
    "name": "낡은 철사",
    "rank": "D",
    "item_category": "artifact",
    "stackable": true,
    "max_stack": 999,
    "effects": [
        {
            "type": "ranged_attack_damage_flat",
            "value": 2
        },
        {
            "type": "melee_attack_damage_flat",
            "value": -1
        }
    ],
    "apply_timing": "stat_query"
}
```

#### 돋보기

```gdscript
{
    "item_id": "magnifier_c",
    "name": "돋보기",
    "rank": "C",
    "item_category": "artifact",
    "stackable": true,
    "max_stack": 999,
    "effects": [
        {
            "type": "attack_range_percent",
            "value": 0.10
        },
        {
            "type": "move_speed_percent",
            "value": -0.02
        }
    ],
    "apply_timing": "stat_query"
}
```

#### 목각인형

```gdscript
{
    "item_id": "wooden_doll_d",
    "name": "목각인형",
    "rank": "D",
    "item_category": "artifact",
    "stackable": true,
    "max_stack": 999,
    "effects": [
        {
            "type": "luck_flat",
            "value": 2
        },
        {
            "type": "max_hp_flat",
            "value": -1
        }
    ],
    "apply_timing": "stat_query"
}
```

#### 방패를 든 동상

```gdscript
{
    "item_id": "shield_statue_a",
    "name": "방패를 든 동상",
    "rank": "A",
    "item_category": "artifact",
    "stackable": true,
    "max_stack": 1,
    "effects": [
        {
            "type": "melee_damage_from_defense",
            "value": 1.0
        }
    ],
    "apply_timing": "stat_query",
    "short_desc": "[적용제한 1] 방어력의 수치만큼 근거리 공격력이 상승합니다."
}
```

#### 중력제어장치

```gdscript
{
    "item_id": "gravity_controller_s",
    "name": "중력제어장치",
    "rank": "S",
    "item_category": "artifact",
    "stackable": true,
    "max_stack": 2,
    "effects": [
        {
            "type": "block_fall_speed_multiplier",
            "value": 0.90
        }
    ],
    "apply_timing": "runtime_rule_query",
    "short_desc": "[적용제한 2] 블록들의 낙하속도가 10% 감소합니다."
}
```

`block_fall_speed_multiplier`는 합산보다 곱연산을 권장한다.

```text
1개: 낙하속도 x 0.90
2개: 낙하속도 x 0.81
```

---

## 7. 파츠와 유물의 차이

| 항목 | 파츠 | 유물 |
|---|---|---|
| 적용 대상 | 현재 장착 무기 | 런 전체 |
| 슬롯 | 5개 제한 | 제한 없음 |
| 무기 교체 영향 | 호환 여부에 따라 활성/비활성 | 영향 없음 |
| 예시 | 레이저 이중화, 대검 경량화 | 낡은 철사, 중력제어장치 |
| 강한 효과 제한 | `exclusive_group`, `max_stack` | `max_stack` |
| UI | 장착 슬롯 필요 | 보유 목록/누적 효과 표시 |

---

## 8. 비활성 파츠 UI 규칙

### 8-1. 필요성

무기를 교체해도 파츠는 삭제하지 않는다.  
따라서 현재 무기와 호환되지 않는 파츠가 생길 수 있다.

비활성 파츠는 반드시 UI에서 명확히 표시해야 한다.

### 8-2. 표시 규칙

활성 파츠:

```text
아이콘 정상 표시
효과 적용 중
```

비활성 파츠:

```text
아이콘 어둡게 표시
회색 오버레이
비활성 라벨 표시
툴팁에 비활성 사유 표시
```

### 8-3. 비활성 사유 문구

특정 무기 제한:

```text
현재 무기와 호환되지 않음
필요 무기: 레이저
현재 무기: 보우
```

무기 타입 제한:

```text
현재 무기와 호환되지 않음
필요 타입: 근거리 무기
현재 타입: 원거리 무기
```

공격 스타일 제한:

```text
현재 무기와 호환되지 않음
필요 스타일: 레이저
현재 스타일: 산탄
```

### 8-4. 비활성 파츠 처리

```text
비활성 파츠는 슬롯을 차지한다.
비활성 파츠는 판매/교체/해제 가능해야 한다.
비활성 파츠는 효과 계산에서 완전히 제외한다.
호환되는 무기를 다시 장착하면 자동 활성화한다.
```

---

## 9. 효과 적용 구조

### 9-1. 기존 condition/effect/apply_timing 구조 활용

새 아이템은 가능한 한 데이터로 표현한다.

```text
아이템 = 기본 정보 + 조건 목록 + 효과 목록 + 적용 타이밍
```

아이템 ID별 하드코딩은 피한다.

금지 방향:

```gdscript
if item_id == "laser_dual_beam_part_s":
    ...
```

권장 방향:

```text
condition/effect/apply_timing 해석기 확장
```

### 9-2. 권장 condition 타입

기존 조건 외에 아래 조건을 추가한다.

```text
equipped_weapon_is
equipped_weapon_type_is
equipped_weapon_attack_style_is
hit_distance_at_least
target_block_size_at_least
is_critical_hit
player_is_airborne
```

### 9-3. 권장 effect 타입

파츠용:

```text
weapon_melee_damage_flat
weapon_ranged_damage_flat
weapon_damage_percent
weapon_attack_speed_percent
weapon_attack_range_percent
weapon_stagger_power_flat
laser_beam_count_add
projectile_count_add
pierce_count_add
damage_multiplier_on_hit
```

유물용:

```text
melee_attack_damage_flat
ranged_attack_damage_flat
attack_range_percent
move_speed_percent
luck_flat
max_hp_flat
defense_flat
melee_damage_from_defense
block_fall_speed_multiplier
```

### 9-4. 권장 apply_timing

| apply_timing | 의미 |
|---|---|
| `on_purchase` | 구매 즉시 1회 적용 |
| `stat_query` | 최종 스탯 계산 시 적용 |
| `weapon_attack_build` | 무기 공격 실행 직전 공격 데이터 구성 시 적용 |
| `on_attack_hit` | 공격이 블록에 적중한 순간 적용 |
| `runtime_rule_query` | 런타임 규칙 조회 시 적용 |
| `on_block_destroyed` | 블록 파괴 시 적용 |
| `on_sand_removed` | 모래 제거 시 적용 |

---

## 10. 경직(stagger) 시스템 연계

무기 시스템 개편과 함께 무기에 `stagger_power` 스탯을 추가한다.

### 10-1. 기획 규칙

1. 무기는 `stagger_power` 스탯을 가진다.
2. 기본적으로 근거리 무기만 `stagger_power`를 1 이상 가진다.
3. 원거리 무기는 현재 `stagger_power = 0`으로 둔다.
   추후 특수 원거리 무기/파츠에서 1 이상 부여할 수 있다.
4. 블록은 `stagger_resistance` 스탯을 가진다.
5. 최종 저지력은 `max(stagger_power - stagger_resistance, 0)`으로 계산한다.
6. 최종 저지력 1당 블록 낙하를 0.05초 멈춘다.
7. 블록은 경직 면역 시간과 최대 경직 시간을 가진다.
8. 보스 블록은 경직 면역 또는 매우 높은 `stagger_resistance`를 가진다.

### 10-2. 경직 상수

```gdscript
const STAGGER_SECONDS_PER_POWER := 0.05
const BLOCK_STAGGER_IMMUNITY_SEC := 0.08
const BLOCK_MAX_STAGGER_SEC := 0.15
```

### 10-3. 경직 계산

```gdscript
effective_stagger_power = max(attacker_stagger_power - block_stagger_resistance, 0)
stun_seconds = effective_stagger_power * STAGGER_SECONDS_PER_POWER
applied_stun = min(stun_seconds, BLOCK_MAX_STAGGER_SEC)
```

### 10-4. 경직 적용 규칙

```text
stun_seconds <= 0이면 경직 없음
hit_stun_immunity_remaining > 0이면 추가 경직 없음
데미지는 경직 면역과 무관하게 정상 적용
경직은 누적 가산하지 않음
hit_stun_remaining += applied_stun 방식 금지
hit_stun_remaining = max(hit_stun_remaining, applied_stun) 방식만 사용
경직이 실제 적용된 경우에만 hit_stun_immunity_remaining 설정
```

### 10-5. FallingBlock 런타임 상태

```gdscript
var hit_stun_remaining := 0.0
var hit_stun_immunity_remaining := 0.0
```

동작 규칙:

```text
HP 오버레이 타이머는 경직 중에도 감소
damage popup은 정상 표시
경직 중에도 데미지/크리티컬/파괴/분해 흐름은 유지
hit_stun_remaining > 0 동안 낙하 이동만 스킵
블록 위치는 이동시키지 않음
넉백은 구현하지 않음
```

### 10-6. 초기 무기별 stagger_power

| 무기 | stagger_power |
|---|---:|
| 단검 | 1 |
| 소드 | 1 |
| 랜스 | 2 |
| 도끼 | 3 |
| 대검 | 4 |
| 보우 | 0 |
| 산탄 | 0 |
| 관통/저격 | 0 |
| 레이저 | 0 |
| 드론 | 0 |

---

## 11. 상태 구조

### 11-1. 현재 런 상태 권장 필드

```gdscript
var equipped_weapon_id: StringName
var equipped_parts: Array[Dictionary]
var owned_artifact_counts: Dictionary
var current_run_effects: Dictionary
```

### 11-2. 무기 상태

```text
equipped_weapon_id = 현재 장착 중인 무기
```

무기는 1개만 장착한다.

### 11-3. 파츠 상태

```text
equipped_parts = 최대 5개의 파츠 인스턴스
```

파츠 entry 예시:

```gdscript
{
    "instance_id": "part_12",
    "item_id": "greatsword_lightweight_part_a"
}
```

파츠 활성 여부는 저장값으로 들고 있기보다, 현재 무기 기준으로 계산하는 것을 권장한다.

```text
활성 여부 = 현재 weapon + part restriction으로 런타임 계산
```

### 11-4. 유물 상태

```text
owned_artifact_counts[item_id] = 보유/적용 수량
```

유물은 장착 슬롯이 없다.  
구매 시 즉시 `owned_artifact_counts`와 `current_run_effects`에 반영한다.

---

## 12. 구매 규칙

### 12-1. 무기 구매

```text
무기 구매 시 현재 무기를 교체할 수 있다.
구매 즉시 장착할지, 보유 후 선택할지는 UI 정책으로 결정한다.
초기 구현은 구매 즉시 장착을 권장한다.
기존 파츠는 유지된다.
비호환 파츠는 비활성화된다.
```

### 12-2. 파츠 구매

```text
파츠 슬롯이 비어 있으면 구매 후 장착
파츠 슬롯이 가득 차면 구매 불가 또는 교체 UI 필요
초기 구현은 슬롯 가득 참 → 구매 불가를 권장
```

비호환 파츠 구매 정책:

```text
현재 무기와 비호환인 파츠도 구매/장착 가능하게 할지 결정 필요
초기 구현은 구매 가능하되 비활성 표시를 권장
```

이유:

```text
나중에 무기를 바꿀 계획으로 파츠를 미리 구매하는 전략 가능
```

단, UI에서 비활성 사유를 명확히 표시해야 한다.

### 12-3. 유물 구매

```text
구매 즉시 적용
장착 슬롯 없음
max_stack 초과 시 구매 불가
```

---

## 13. 상점 UI 규칙

상점 아이템은 카테고리별로 구분 표시한다.

| 카테고리 | 표시 |
|---|---|
| 무기 | 무기 아이콘/현재 장착 무기와 비교 |
| 파츠 | 파츠 슬롯, 호환/비호환 여부 |
| 유물 | 누적 수량, max_stack, 적용 효과 |

### 13-1. 파츠 상점 표시

파츠는 구매 전에도 현재 무기와의 호환 여부를 표시한다.

```text
호환됨: 효과 적용 가능
비호환: 구매 가능하지만 현재 무기에는 비활성
```

예:

```text
대검 경량화 부품
[대검 전용]
현재 무기: 레이저
상태: 비호환 - 장착해도 효과가 비활성화됩니다.
```

### 13-2. 유물 상점 표시

유물은 현재 보유 수량과 최대 적용 제한을 표시한다.

```text
중력제어장치
보유: 1 / 2
효과: 블록 낙하속도 x 0.90
```

---

## 14. HUD / 스탯 패널

### 14-1. HUD 표시 권장

HUD 또는 ESC 스탯 패널에 아래 정보를 표시한다.

```text
현재 무기
무기 타입
무기 데미지
무기 공격속도
무기 공격범위
무기 저지력
파츠 슬롯 5개
비활성 파츠 수
유물 수
```

### 14-2. 파츠 슬롯 표시

```text
활성 파츠: 정상 아이콘
비활성 파츠: 회색/어두운 아이콘 + 비활성 마크
빈 슬롯: 빈 파츠 슬롯
```

### 14-3. 상세 툴팁

파츠 툴팁에는 아래를 표시한다.

```text
효과
제한 조건
현재 활성 여부
비활성 사유
```

---

## 15. 마이그레이션 원칙

### 15-1. 1차 목표

```text
기존 attack_module 데이터를 weapon으로 이름만 바꾸되, 실제 공격 동작은 최대한 유지한다.
기존 5개 공격모듈 장착 상태는 제거한다.
새로운 part 슬롯 5개를 추가한다.
artifact 누적 구조를 추가한다.
```

### 15-2. 기존 함수 호환

초기 구현에서는 아래처럼 단계적으로 변경해도 된다.

```text
1단계: 내부 함수명은 attack_module을 일부 유지
2단계: 데이터 카테고리 weapon 추가
3단계: UI 표시명 무기로 변경
4단계: GameState 상태를 equipped_weapon_id 중심으로 정리
5단계: 기존 attack_module 다중 장착 필드 제거
```

### 15-3. 금지 방향

```text
공격모듈 5개 장착 구조를 유지한 채 무기라는 이름만 붙이는 것
파츠를 기존 enhance_module과 구분 없이 처리하는 것
유물을 장착 슬롯이 필요한 아이템으로 만드는 것
아이템 ID별 하드코딩 분기
비호환 파츠를 자동 삭제하는 것
```

---

## 16. 구현 순서 권장

```text
1. 문서/용어 정리
2. item_category에 weapon/part/artifact 추가
3. 기존 attack_module 데이터를 weapon으로 이관
4. GameState에 equipped_weapon_id 추가
5. 기존 equipped_attack_modules 다중 장착 로직 제거 또는 비활성화
6. part 슬롯 5개 상태 추가
7. part 호환성 판정 함수 추가
8. 비활성 파츠 UI 표시 추가
9. artifact 누적 적용 구조 추가
10. 기존 function/enhance 아이템을 part/artifact로 재분류
11. weapon stat getter 정리
12. part/artifact effect evaluator 연결
13. 경직 stagger_power/stagger_resistance 구현
14. 상점 구매/교체/슬롯 제한 로직 정리
15. HUD/ESC 스탯 패널 갱신
16. 회귀 테스트 작성
```

---

## 17. 회귀 테스트 체크리스트

### 17-1. 무기

- 무기는 1개만 장착된다.
- 무기 구매 시 현재 무기가 교체된다.
- 기존 공격 방식이 정상 동작한다.
- 근거리/원거리/메카닉 타입 구분이 유지된다.
- 무기별 데미지/공속/범위가 정상 계산된다.

### 17-2. 파츠

- 파츠는 최대 5개 장착된다.
- 6번째 파츠 구매/장착은 제한된다.
- 호환 파츠만 효과가 적용된다.
- 비호환 파츠는 효과가 적용되지 않는다.
- 비호환 파츠는 슬롯에서 삭제되지 않는다.
- 무기를 다시 호환되는 것으로 바꾸면 파츠가 자동 활성화된다.
- `allowed_weapon_ids` 제한이 동작한다.
- `allowed_weapon_types` 제한이 동작한다.
- `exclusive_group` 중복 제한이 동작한다.

### 17-3. 유물

- 유물은 구매 즉시 적용된다.
- 유물은 장착 슬롯을 사용하지 않는다.
- 중복 구매가 가능하다.
- `max_stack`을 초과하면 구매가 제한된다.
- 유물 효과는 무기 교체와 무관하게 유지된다.

### 17-4. 경직

- 근거리 무기는 경직을 발생시킨다.
- 원거리 무기는 기본적으로 경직을 발생시키지 않는다.
- 저지력과 경직 저항 공식이 적용된다.
- 경직은 누적 가산되지 않는다.
- 경직 면역 시간이 적용된다.
- 경직 중에도 데미지/파괴/분해/팝업이 정상 동작한다.
- 넉백이나 위치 이동은 발생하지 않는다.
- 보스는 경직 면역 또는 매우 높은 저항을 가진다.

---

## 18. Codex 작업용 요약 프롬프트

```text
Burial Protocol의 모듈/아이템 시스템을 개편한다.

기존 공격모듈 5개 장착 구조는 폐기한다.
기존 공격모듈은 weapon(무기)으로 이름과 역할을 변경한다.
weapon은 1개만 장착 가능하다.

아이템 카테고리는 weapon / part / artifact 3개로 개편한다.

weapon:
- 기존 공격모듈 데이터와 공격 동작을 계승한다.
- 1개만 장착 가능하다.
- weapon_type, attack_style, damage, attack_speed, range, stagger_power를 가진다.

part:
- 무기에 장착하는 개조 아이템이다.
- 최대 5개 장착 가능하다.
- 현재 장착 weapon에만 효과를 적용한다.
- allowed_weapon_ids, allowed_weapon_types, allowed_attack_styles 제한을 지원한다.
- 현재 weapon과 호환되지 않는 part는 슬롯에 남지만 비활성화된다.
- 비활성 part는 효과 계산에서 제외한다.
- 비활성 part는 UI에서 어둡게 표시하고 비활성 사유를 툴팁에 표시한다.
- exclusive_group, stackable, max_stack을 지원한다.

artifact:
- 런 전체에 적용되는 패시브 아이템이다.
- 장착 슬롯이 없다.
- 구매 즉시 누적 적용된다.
- 기본적으로 중복 가능하다.
- 강한 artifact는 max_stack으로 적용 제한한다.

중요:
- 비호환 part를 자동 삭제하지 않는다.
- item_id별 하드코딩 분기를 만들지 않는다.
- condition/effect/apply_timing 기반의 데이터 해석 구조를 확장한다.
- 기존 function_module/enhance_module은 효과 성격에 따라 part 또는 artifact로 재분류한다.
- UI와 문서에서는 공격모듈이라는 용어 대신 무기라는 용어를 사용한다.

경직 시스템도 함께 고려한다.
- weapon은 stagger_power를 가진다.
- 근거리 weapon만 기본 stagger_power를 1 이상 가진다.
- 원거리 weapon은 현재 stagger_power = 0으로 둔다.
- block은 stagger_resistance를 가진다.
- effective_stagger_power = max(stagger_power - stagger_resistance, 0)
- 저지력 1당 낙하를 0.05초 멈춘다.
- 경직은 누적 가산하지 않는다.
- 넉백은 구현하지 않는다.
```

---

## 19. 최종 판단

이 개편안은 기존 공격모듈 다중 장착 구조보다 아래 장점이 있다.

```text
무기 정체성이 명확하다.
상점 선택지가 이해하기 쉬워진다.
파츠로 빌드 다양성을 유지할 수 있다.
유물로 런 전체 성장 재미를 만들 수 있다.
UI와 밸런스 관리가 쉬워진다.
```

최종 구조:

```text
무기 1개
파츠 5개
유물 제한 없이 누적
비호환 파츠는 삭제하지 않고 비활성화
파츠 제한은 weapon_id / weapon_type / attack_style을 지원
강한 유물은 max_stack으로 제한
```
