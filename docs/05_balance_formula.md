# Burial Protocol - Balance Formula Specification

기준일: `2026-06-01`
기준 브랜치: `main`

---

## 0. 목적

이 문서는 신규 장비 체계의 수치 계산 기준을 정의한다.
현재 런타임의 공격모듈, 근거리 공격력, 원거리 공격력 공식은 legacy이며 신규 밸런스 기준으로 사용하지 않는다.

---

## 1. 밸런스 원칙

```text
플레이어 처리력 성장률은 블록 체력 성장률을 완전히 따라잡으면 안 된다.
```

- 무기는 좌클릭 기반 주 공격 수단이다.
- 드론 프로토콜은 자동 행동으로 빌드 방향을 확장한다.
- 패시브 모듈은 속성과 유형 조합을 강화한다.
- 공격속도와 드론 쿨타임 감소는 서로 다른 자원이다.
- 드론 쿨타임 감소는 희귀 스탯으로 유지한다.

---

## 2. 신규 전투 스탯

| 스탯 | 역할 | 레벨업 기본 풀 |
|---|---|---|
| 무기 공격력 | 무기 피해 flat 증가 | 포함 |
| 드론 공격력 | 공격형 프로토콜 피해 flat 증가 | 포함 |
| 공격속도 | 무기 쿨타임 감소 | 포함 |
| 드론 쿨타임 감소 | 프로토콜 쿨타임 감소 | 제외 |

제거 또는 deprecated:

- 근거리 공격력
- 원거리 공격력
- `melee_atk_up`
- `ranged_atk_up`

---

## 3. 무기 공식

```text
weapon_damage =
  floor(
    (weapon_grade_base_damage + weapon_attack_damage_flat)
    x global_damage_multiplier
    x attribute_multiplier
    x type_multiplier
    x passive_module_multiplier
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
weapon_dps =
  weapon_damage
  / weapon_cooldown
```

좌측 무기와 우측 무기는 각각 독립된 쿨타임을 가진다.
좌클릭 중 두 무기는 자신의 쿨타임이 끝났을 때 각각 발사한다.

---

## 4. 드론 프로토콜 공식

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
    x attribute_multiplier
    x type_multiplier
    x passive_module_multiplier
  )
```

동일 드론 프로토콜을 중복 장착하면 각 인스턴스가 자신의 쿨타임을 가진다.
드론 공격력은 공격형 프로토콜에 적용하며, 지원형 프로토콜은 해당 효과 전용 공식을 사용한다.

---

## 5. 등급

무기, 드론 프로토콜, 패시브 모듈:

```text
D / C / B / A / S
```

드론 본체:

```text
현재는 등급 없음
```

권장 등급 배율:

| 등급 | 피해 기준 배율 | 속도 기준 배율 |
|---|---:|---:|
| D | `1.00` | `1.00` |
| C | `1.15` | `1.05` |
| B | `1.35` | `1.10` |
| A | `1.60` | `1.15` |
| S | `2.00` | `1.25` |

실제 콘텐츠는 등급별 고정 base 값을 데이터로 가질 수 있다.
배율표는 초기 데이터 작성과 마이그레이션 검증 기준이다.

---

## 6. 속성과 유형 배율

속성:

```text
electric / fire / physical / energy / chemical / none
```

유형:

```text
support / projectile / area / beam / chain / explosion
```

속성과 유형 배율은 기본값 `1.0`으로 시작한다.
패시브 모듈이 조건을 만족할 때만 관련 배율이나 추가 효과를 적용한다.

예:

```text
electric_damage_percent
beam_split_count
chain_additional_count
explosion_radius_add_units
```

아이템 ID별 하드코딩은 사용하지 않는다.

---

## 7. 블록 HP

```text
final_block_hp =
  BLOCK_HP_PER_UNIT
  x size_hp_multiplier
  x material_hp_multiplier
  x type_hp_multiplier
  x difficulty_hp_multiplier
  x day_hp_multiplier
```

```text
BLOCK_HP_PER_UNIT = 10.0
```

Day별 실제 값은 `StageTable.tres`를 최종 진실로 둔다.

---

## 8. 난이도 배율

| 난이도 | 블록 HP 배율 |
|---|---:|
| normal | `1.0` |
| hard | `1.5` |
| extreme | `3.0` |
| hell | `5.0` |
| nightmare | `10.0` |

일반 밸런스 검증은 normal과 hard를 우선 기준으로 한다.

---

## 9. 모래 셀 HP와 무기 피해

```text
sand_cell_max_hp =
  source_block_final_hp
  / generated_sand_cell_count
```

```text
sand_damage =
  weapon_damage
  x SAND_WEAPON_DAMAGE_RATIO
```

```text
SAND_WEAPON_DAMAGE_RATIO = 0.10
SAND_FALLBACK_CELL_HP = 1.0
```

- 각 모래 셀은 독립 float HP를 가진다.
- 근접, 히트스캔, 투사체 무기 공격은 적중한 셀 각각에 피해를 적용한다.
- 비관통 투사체와 비관통 히트스캔은 첫 모래 셀에서 멈춘다.
- 관통형 공격은 블록과 모래가 같은 추가 관통 카운트를 소비한다.
- 폭발은 첫 충돌 지점에서 발생하고 범위 내 각 모래 셀에 위 공식을 적용한다.
- 드론 공격력과 드론 프로토콜 피해는 모래에 적용하지 않는다.
- 채굴 데미지, 채굴속도, 채굴범위는 좌우 벽 전용이다.
- 모래 제거는 골드를 지급하지 않는다. 기존 XP 누적 정책은 유지한다.

---

## 10. 상점 랭크와 가격

랭크별 fallback 가격:

| 랭크 | 가격 |
|---|---:|
| D | `15G` |
| C | `30G` |
| B | `60G` |
| A | `120G` |
| S | `240G` |

가격 결정 순서:

```text
1. item 데이터에 price_gold > 0이 있으면 사용
2. price_gold == 0이면 rank 기반 fallback 가격 사용
```

리롤:

```text
current_reroll_cost =
  SHOP_REROLL_BASE_COST
  + current_shop_reroll_count * SHOP_REROLL_COST_INCREMENT
```

```text
SHOP_REROLL_BASE_COST = 50G
SHOP_REROLL_COST_INCREMENT = 25G
```

---

## 11. 레벨업 카드 희귀도

| 희귀도 | 기본 확률 | 값 배율 |
|---|---:|---:|
| Normal | `70%` | `1.0` |
| Silver | `22%` | `1.6` |
| Gold | `7%` | `2.5` |
| Platinum | `1%` | `4.0` |

행운 보정:

```text
luck 1당:
  Normal   -1.00%p
  Silver   +0.50%p
  Gold     +0.35%p
  Platinum +0.15%p
```

확률 계산 후 총합이 `100%`가 되도록 정규화한다.

---

## 12. 레벨업 카드 기본 풀

전투:

- 전역 데미지 %
- 무기 공격력
- 드론 공격력
- 공격속도
- 공격범위
- 치명타 확률
- 최대 체력
- 방어력
- HP 재생

기동:

- 이동속도
- 점프력
- 배터리 회복

채굴:

- 채굴 데미지
- 채굴속도
- 채굴범위

경제:

- 행운
- 이자율

기본 풀 제외:

- 드론 쿨타임 감소
- 모래 직접 제거
- 모래 자동 정리
- 벽 복구
- 중량 직접 증가
- 특정 블록 제거
- Day 종료 시 환경 정리

---

## 13. 신규 카드 마이그레이션

| legacy 카드 | 처리 | 신규 카드 |
|---|---|---|
| `melee_atk_up` | 기본 풀에서 제거 | `weapon_attack_up` |
| `ranged_atk_up` | 기본 풀에서 제거 | `drone_attack_up` |
| `attack_speed_up` | 적용 | 무기 쿨타임 감소에만 적용 |

`drone_cooldown_reduction_up`은 기본 카드로 추가하지 않는다.

---

## 14. 상점 아이템과 레벨업 관계

```text
Normal 레벨업 카드 = D랭크 상점 아이템의 60~80%
Silver 레벨업 카드 = D~C 사이
Gold 레벨업 카드 = C~B 사이
Platinum 레벨업 카드 = B~A 사이
```

Platinum 카드가 S랭크 상점 아이템보다 강해지지 않게 한다.

---

## 15. 마이그레이션 주의사항

- legacy `module_base_damage`와 `melee/ranged/mechanic` 분기를 신규 공식에 그대로 섞지 않는다.
- 무기 공격력은 무기에만 적용한다.
- 드론 공격력은 공격형 프로토콜에만 적용한다.
- 공격속도는 무기 쿨타임에만 적용한다.
- 드론 쿨타임 감소는 프로토콜 쿨타임에만 적용한다.
- 패시브 추가 효과는 공통 evaluator를 통해 적용한다.
- 실제 수치 튜닝은 Phase 2~4 마이그레이션 후 snapshot 테스트로 진행한다.

---

## 16. Phase 6 스냅샷

- `scripts/tests/equipment_dps_snapshot.gd`가 무기 등급별 DPS와 드론 프로토콜 DPS를 기록한다.
- 생성 보고서는 `docs/reports/equipment_dps_snapshot.md`에서 확인한다.
- `scripts/tests/day_pressure_snapshot.gd`와 `scripts/tests/spawn_distribution_snapshot.gd`가 기존 블록 스폰 압력과 분포 Monte Carlo 보고서를 재생성한다.
- 생성 보고서는 `docs/reports/day_pressure_snapshot.md`, `docs/reports/spawn_distribution_snapshot.md`에서 확인한다.
- 패시브 교체 회귀는 `scripts/tests/shop_equipment_snapshot.gd`에서 5슬롯 장착, 교체 대상 필수 처리, 기존 효과 제거 후 새 효과 적용을 검증한다.
