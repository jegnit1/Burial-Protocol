# Burial Protocol - Equipment System Specification

기준일: `2026-06-01`
상태: `Phase 7 모래 제거 개편 1차 적용`

---

## 0. 목적

이 문서는 legacy 공격모듈 시스템을 대체할 신규 장비 시스템의 기준 문서다.
신규 장비 체계는 무기, 드론, 드론 프로토콜, 패시브 모듈로 구성한다.

현재 실행 코드는 신규 슬롯 상태를 기준으로 무기, 드론 프로토콜, 상점 UI를 처리한다.
일부 전투 helper와 과도기 호환 분기는 legacy 이름을 유지하며, 두 장비 체계를 동시에 활성화하지 않는다.

---

## 1. 장비 구성

| 장비 | 슬롯 | 등급 | 핵심 역할 |
|---|---:|---|---|
| 무기 | `2개` | `D~S` | 좌클릭 기반 주 공격 |
| 드론 | `1개` | 현재 없음 | 프로토콜 실행 주체 |
| 드론 프로토콜 | `5개` | `D~S` | 자동 행동 |
| 패시브 모듈 | `5개` | `D~S` | 조건부 추가 효과 |

---

## 2. 무기

### 2-1. 슬롯

- 좌측 무기 슬롯
- 우측 무기 슬롯
- 런 시작 시 좌측 슬롯에 기본 무기 1개 지급
- 우측 슬롯은 비어 있을 수 있음

### 2-2. 입력

- 좌클릭 시 장착된 모든 무기가 자신의 쿨타임을 검사한다.
- 쿨타임이 끝난 무기만 발사한다.
- 좌측과 우측 무기는 독립 쿨타임을 가진다.
- 우측 무기는 우클릭 입력에 연결하지 않는다.
- 우클릭은 좌우 벽 채굴 전용으로 유지한다.
- 모래는 좌클릭 무기 공격으로만 피해를 받는다.

### 2-3. 비주얼

- 무기는 캐릭터 어깨 좌우 영역에 표시한다.
- legacy 캐릭터 주변 공전 비주얼은 제거 대상이다.

---

## 3. 드론

- 드론 슬롯은 `1개`다.
- 현재는 기본 드론만 사용한다.
- 드론 자체에는 등급을 두지 않는다.
- 드론은 캐릭터 상단에 표시한다.
- 드론은 장착된 드론 프로토콜을 실행한다.

드론 본체 교체, 드론 등급, 복수 드론은 현재 범위가 아니다.

---

## 4. 드론 프로토콜

- 슬롯은 `5개`다.
- 자동 행동이다.
- 동일 프로토콜 중복 장착을 허용한다.
- 등급은 `D~S`다.
- 각 프로토콜 인스턴스는 독립 쿨타임을 가진다.
- 드론 쿨타임 감소 스탯의 영향을 받는다.

프로토콜 역할 예시:

- 자동 공격
- 지원
- 회복
- 배터리 보조
- 모래 제거
- 채굴 보조

공격형 프로토콜은 드론 공격력의 영향을 받는다.
지원형 프로토콜은 효과별 전용 값을 사용한다.
일반 드론 프로토콜은 모래 피해를 줄 수 없다.
`sand_cleaner`는 공격 피해가 아닌 별도 특수 제거 효과다.

---

## 5. 패시브 모듈

- 슬롯은 `5개`다.
- 등급은 `D~S`다.
- 직접 공격을 발동하지 않는다.
- 무기와 드론 프로토콜에 추가 효과를 부여한다.
- 일부 모듈은 중복 적용 불가다.

중복 금지는 데이터의 `exclusive_group`, `stackable`, `max_stack` 같은 공통 필드로 표현한다.
아이템 ID별 하드코딩으로 처리하지 않는다.

---

## 6. 속성과 유형

### 6-1. 속성

```text
electric
fire
physical
energy
chemical
none
```

### 6-2. 유형

```text
support
projectile
area
beam
chain
explosion
```

속성과 유형은 서로 다른 축이다.
패시브 모듈은 특정 속성, 특정 유형, 장착 수 조건을 기준으로 효과를 적용할 수 있다.

---

## 7. 스탯

| 스탯 | 적용 대상 |
|---|---|
| 무기 공격력 | 무기 피해 |
| 드론 공격력 | 공격형 드론 프로토콜 피해 |
| 공격속도 | 무기 쿨타임 감소 |
| 드론 쿨타임 감소 | 프로토콜 쿨타임 감소 |

드론 쿨타임 감소는 희귀 스탯이다.
레벨업 카드 기본 풀에 넣지 않는다.

제거 대상:

- 근거리 공격력
- 원거리 공격력
- `melee_atk_up`
- `ranged_atk_up`

---

## 8. 공식

```text
weapon_damage =
  floor(
    (weapon_grade_base_damage + weapon_attack_damage_flat)
    x global_damage_multiplier
    x attribute/type/passive multipliers
  )
```

```text
weapon_cooldown =
  weapon_base_cooldown
  / weapon_attack_speed_multiplier
  / grade_speed_multiplier
  / run_weapon_attack_speed_mult
```

```text
protocol_cooldown =
  protocol_base_cooldown
  x (1.0 - run_drone_cooldown_reduction)
```

```text
final_protocol_cooldown =
  max(protocol_cooldown, 0.15)
```

```text
drone_protocol_damage =
  floor(
    (protocol_grade_base_damage + drone_attack_damage_flat)
    x global_damage_multiplier
    x attribute/type/passive multipliers
  )
```

---

## 9. 데이터 카테고리

최종 장비 카테고리:

```text
weapon
drone
drone_protocol
passive_module
```

legacy 마이그레이션:

| legacy | 신규 방향 |
|---|---|
| 좌클릭 `attack_module` | `weapon` |
| `mechanic` 공격모듈과 자동 드론 효과 | `drone_protocol` |
| `function_module` | 역할에 따라 `drone_protocol` 또는 `passive_module` |
| `enhance_module` | `passive_module` |
| 과도기 `part`, `artifact` | 신규 카테고리로 재분류 |

---

## 10. 패시브 효과 해석기

조건 예시:

- `equipment_attribute_is`
- `equipment_type_is`
- `equipped_attribute_count_at_least`
- `equipped_type_count_at_least`
- `weapon_slot_has_type`
- `protocol_type_is`
- `protocol_attribute_is`

효과 예시:

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

적용 타이밍:

- `stat_query`
- `on_weapon_attack_start`
- `on_weapon_hit`
- `on_protocol_trigger`
- `on_protocol_hit`
- `on_sand_removed`
- `on_player_healed`

---

## 11. 상점

유지할 흐름:

- 아이템 5개 롤
- 가격 표시
- 구매 가능 여부
- 골드 차감
- 구매 성공 시 현재 목록 제거
- 잠금
- 리롤
- `Close`
- `Next Day`

Phase 5 적용 결과:

- legacy 원본 카테고리를 신규 장비 카테고리로 정규화
- 무기 좌/우 슬롯 표시와 교체 대상 선택
- 드론 프로토콜 5슬롯 표시와 교체 대상 선택
- 패시브 모듈 5슬롯 표시와 선택 슬롯 교체
- 기존 가격, 잠금, 리롤, 구매 목록 제거 흐름 유지

현재 기본 드론은 판매 상품이 아니어도 된다.
패시브 모듈 교체는 source-instance 기준으로 기존 효과를 제거한 뒤 새 효과를 적용한다.

---

## 12. 현재 코드 충돌 지점

| 영역 | 현재 코드 | 신규 목표 |
|---|---|---|
| 슬롯 | `ATTACK_MODULE_MAX_EQUIPPED = 5` | 무기 `2`, 드론 `1`, 프로토콜 `5`, 패시브 `5` |
| 타입 | `melee/ranged/mechanic` | 속성과 유형 분리 |
| 스탯 | 근거리/원거리 공격력 | 무기/드론 공격력 |
| 쿨타임 | `attack_module_cooldowns` | 무기 슬롯별, 프로토콜 인스턴스별 |
| 비주얼 | 공격모듈 공전 | 무기 좌우, 드론 상단 |
| 상점 | legacy 카테고리와 과도기 별칭 | 신규 네 카테고리 |
| 조건부 효과 | 공격모듈 타입 조건 | 속성/유형/슬롯/프로토콜 조건 |
| 레벨업 | `melee_atk_up`, `ranged_atk_up` | `weapon_attack_up`, `drone_attack_up` |

---

## 13. 구현 금지사항

- 실제 전투 로직을 한 번에 전부 교체하지 않는다.
- `GameState.gd`를 검증 없이 대규모 마이그레이션하지 않는다.
- 아이템 ID별 하드코딩으로 패시브 효과를 구현하지 않는다.
- 우측 무기 슬롯을 우클릭 입력으로 연결하지 않는다.
- 드론 쿨타임 감소를 레벨업 카드 기본 풀에 넣지 않는다.
- legacy 근거리/원거리 스탯과 신규 무기/드론 스탯을 동시에 활성화하지 않는다.
- legacy 공격모듈 5개 장착과 신규 무기 2개 장착을 동시에 활성화하지 않는다.

---

## 14. 구현 순서

```text
Phase 2: 데이터 스키마와 콘텐츠 마이그레이션
Phase 3: GameState 상태와 getter
Phase 4: Player/Main 트리거와 비주얼
Phase 5: 상점과 UI
Phase 6: 회귀 테스트와 밸런스 snapshot
```

Phase 3의 GameState 상태와 getter는 1차 적용됐다.
Phase 4의 Player/Main 트리거와 기본 비주얼도 1차 적용됐다.
Phase 5의 상점 구매 경로와 장비 슬롯 UI도 1차 적용됐다.
Phase 6의 조건부 상점 회귀, 패시브 교체 회귀, 무기/프로토콜 DPS snapshot도 1차 적용됐다.
좌클릭 입력은 좌·우 무기를 각자 쿨타임에 따라 발동하며, 우클릭은 채굴 입력으로 유지한다.
`combat_drone`, `auto_attack`, `sand_cleaner`, `aura_damage` 프로토콜 행동을 연결했다.

---

## 15. 모래 제거 규칙

- 좌클릭 무기 공격만 모래 셀에 피해를 준다.
- 모래 셀은 원본 블록 최종 HP를 실제 생성 셀 수로 나눈 개별 float HP를 가진다.
- 모래 셀 피해는 `weapon_damage x 0.10`이다.
- 근접 shape, 히트스캔, 투사체 sweep이 모래 피해를 적용한다.
- 모래 셀은 투사체 충돌 대상이다. 비관통 투사체와 비관통 히트스캔은 첫 모래 셀에서 멈춘다.
- 관통형 공격은 블록과 모래가 같은 추가 관통 카운트를 소비한다.
- 폭발탄은 첫 충돌 지점에서 폭발하며 범위 안의 각 모래 셀에 `weapon_damage x 0.10`을 적용한다.
- 일반 드론 프로토콜은 모래 피해를 줄 수 없다.
- `sand_cleaner`는 피해가 아닌 별도 특수 제거 효과다.
- 모래 제거는 골드와 골드 팝업을 지급하지 않는다. 기존 XP 누적 정책은 유지한다.
