# Burial Protocol - Balance Formula Specification

기준일: `2026-04-28`  
기준 브랜치: `main`

---

## 0. 목적

이 문서는 Burial Protocol의 수치 밸런스를 감이 아니라 공식으로 관리하기 위한 기준 문서다.

대상:

- 기본 플레이어 스탯
- Day별 블록 체력 증가
- 난이도 배율
- 공격모듈 등급별 고정 기본데미지
- 상점 아이템 랭크별 스탯 증가량
- 레벨업 카드 희귀도와 스탯 증가량
- 행운에 따른 레벨업 카드 희귀도 보정

이 문서는 `02_systems_spec.md`의 시스템 설명과 다르다.
`02_systems_spec.md`는 시스템이 어떻게 동작하는지 설명하고, 이 문서는 수치가 어떤 기준으로 증가해야 하는지 설명한다.

---

## 1. 밸런스 원칙

Burial Protocol의 성장 밸런스는 아래 관계를 기준으로 한다.

```text
플레이어 처리력 성장률은 블록 체력 성장률을 완전히 따라잡으면 안 된다.
```

이유:

- 플레이어가 블록 체력을 완전히 따라잡으면 모래 압박이 사라진다.
- 블록 체력이 너무 빨리 증가하면 상점/레벨업 선택과 무관하게 밀린다.
- 따라서 후반으로 갈수록 좋은 빌드일 때만 버틸 수 있어야 한다.

권장 감각:

```text
Day 1~5:
  플레이어가 약간 우세

Day 6~20:
  레벨업/상점 선택이 좋으면 비슷함

Day 21~30:
  빌드가 약하면 밀림
  빌드가 잘 풀리면 버팀
```

---

## 2. 기본 스탯 기준선

현재 기본 스탯 기준:

| 스탯 | 기본값 | 기준 |
|---|---:|---|
| 기본 모듈 데미지 | `10` | `sword_module.module_base_damage` |
| 근거리 공격력 | `0` | melee 모듈에 더하는 flat 보너스 |
| 원거리 공격력 | `0` | ranged 모듈에 더하는 flat 보너스 |
| 데미지 | `0%` | 모든 최종 피해에 곱하는 전역 보너스 |
| 공격 쿨다운 | `0.30초` | `PLAYER_ATTACK_COOLDOWN` |
| 기본 공격속도 | `3.33/sec` | `1 / 0.30` |
| 최대 체력 | `100` | `PLAYER_MAX_HEALTH` |
| 방어력 | `0` | `PLAYER_BASE_DEFENSE` |
| 치명타 확률 | `1%` | `PLAYER_BASE_CRIT_CHANCE` |
| 치명타 배율 | `200%` | `PLAYER_CRIT_DAMAGE_MULTIPLIER` |
| 채굴 데미지 | `1` | `PLAYER_MINING_DAMAGE` |
| 채굴 쿨다운 | `0.15초` | `PLAYER_MINING_COOLDOWN` |
| 기본 채굴속도 | `6.67/sec` | `1 / 0.15` |
| 이동속도 | `426 px/s` | `PLAYER_MOVE_SPEED` |
| 공중 이동속도 | `373 px/s` | `PLAYER_AIR_SPEED` |
| 점프력 | `853` | `abs(PLAYER_JUMP_SPEED)` |
| 최대 중량 | `2400 cells` | `WEIGHT_LIMIT_SAND_CELLS` |
| 배터리 회복 | `5/sec` | `PLAYER_BATTERY_RECOVERY_PER_SEC` |

핵심 기준:

```text
소드 D등급 module_base_damage 10 = 기본 1U 블록 HP 10
```

즉, 아무 배율도 없는 기본 1U 블록은 이론상 기본 공격 1타로 처리 가능한 기준이다.

---

## 3. 기본 DPS 기준

현재 소드 D등급 기준 DPS:

```text
base_dps = sword_module.module_base_damage / PLAYER_ATTACK_COOLDOWN
base_dps = 10 / 0.30 ≈ 33.33
```

공격모듈 피해는 module_base_damage 기반으로 계산한다.

```text
melee_damage =
  floor((module_base_damage + melee_attack_damage_flat)
  x global_damage_multiplier)

ranged_damage =
  floor((module_base_damage + ranged_attack_damage_flat)
  x global_damage_multiplier)

mechanic_damage =
  floor(module_base_damage
  x global_damage_multiplier)
```

`damage_multiplier`는 기존 데이터 호환용이다.
`module_base_damage`가 없을 때만 `round(10 x damage_multiplier)`로 base damage를 계산한다.
등급별 base damage 데이터가 아직 없으면, 기존 등급 피해 배율표는 최종 배율이 아니라 등급별 고정 `module_base_damage` 산정에만 사용한다.
최종 데미지 단계에서 곱해지는 배율은 `global_damage_multiplier` 하나뿐이다.
메카닉 모듈은 근거리/원거리 flat 공격력은 받지 않고, 전역 데미지 %만 받는다.

---

## 4. Day별 블록 HP 증가 공식

블록 최종 HP는 아래 개념을 따른다.

```text
final_block_hp =
  BLOCK_HP_PER_UNIT
  x size_hp_multiplier
  x material_hp_multiplier
  x type_hp_multiplier
  x difficulty_hp_multiplier
  x day_hp_multiplier
```

기본값:

```text
BLOCK_HP_PER_UNIT = 10.0
```

권장 Day HP 배율 공식:

```text
day_hp_multiplier =
  1.0
  + (day - 1) * 0.06
  + floor((day - 1) / 5) * 0.12
```

예상 배율:

| Day | 배율 |
|---:|---:|
| 1 | `1.00` |
| 5 | `1.24` |
| 10 | `1.66` |
| 15 | `2.08` |
| 20 | `2.50` |
| 25 | `2.92` |
| 30 | `3.34` |

의도:

- Day 1~5는 완만하게 증가한다.
- 5일 단위로 계단식 압박을 추가한다.
- Day 30 일반 블록은 Day 1 대비 약 3.3배 체력이 된다.

주의:

- 위 공식은 권장값이다.
- 실제 `StageTable.tres`에 이미 Day별 HP 배율이 있다면, 이 공식은 테이블 작성 기준으로 사용한다.
- 코드에서는 `StageTable.tres` 값을 최종 진실로 둔다.

---

## 5. 난이도 배율

현재 난이도별 블록 HP 배율:

| 난이도 | 배율 |
|---|---:|
| normal | `1.0` |
| hard | `1.5` |
| extreme | `3.0` |
| hell | `5.0` |
| nightmare | `10.0` |

난이도 배율은 Day HP 배율과 곱해진다.

예시:

```text
Normal Day 30 = 3.34x
Hard Day 30 = 5.01x
Extreme Day 30 = 10.02x
Hell Day 30 = 16.70x
Nightmare Day 30 = 33.40x
```

주의:

- nightmare는 도전용/엔드컨텐츠로 본다.
- 일반적인 밸런스 검증은 normal과 hard를 우선 기준으로 한다.

---

## 6. 공격모듈 등급과 고정 기본데미지

공격모듈은 장착 장비이며, 데이터의 `rank`를 장착 `grade`로 사용한다.

등급:

```text
D / C / B / A / S
```

현재 공격모듈 등급별 피해 계수는 최종 데미지 배율이 아니다.
등급별 `module_base_damage` 데이터가 준비되기 전까지, D 기준 `module_base_damage`를 등급별 고정 기본데미지로 환산하는 마이그레이션 계수다.

```text
grade_module_base_damage =
  round(d_grade_module_base_damage x legacy_grade_damage_factor)
```

| 등급 | base damage 환산 계수 |
|---|---:|
| D | `1.00` |
| C | `1.15` |
| B | `1.35` |
| A | `1.60` |
| S | `2.00` |

현재 공격모듈 등급별 공격속도 배율:

| 등급 | 속도 배율 |
|---|---:|
| D | `1.00` |
| C | `1.05` |
| B | `1.10` |
| A | `1.15` |
| S | `1.25` |

현재 공격모듈 등급별 범위 배율:

| 등급 | 범위 배율 |
|---|---:|
| D | `1.00` |
| C | `1.05` |
| B | `1.10` |
| A | `1.15` |
| S | `1.25` |

원칙:

- 공격모듈 등급은 장비 자체의 성장이다.
- 공격모듈의 `rank`는 장착 `grade`와 같다.
- 빈 슬롯에 B급 공격모듈을 구매하면 B급 모듈로 장착된다.
- 같은 `module_id`와 같은 `grade`를 다시 구매하면 합성 대상이 된다.
- 최종 데미지 계산에서 grade damage multiplier를 곱하지 않는다.
- 등급은 해당 grade의 고정 `module_base_damage`를 결정하는 데만 사용한다.
- 레벨업 카드 희귀도와 이름 체계를 섞지 않는다.
- 공격모듈은 `D/C/B/A/S`, 레벨업 카드는 `Normal/Silver/Gold/Platinum`을 사용한다.

예: `laser_module`은 B급 공격모듈이며 D 기준 `module_base_damage = 2`다.
B급 고정 기본데미지는 `round(2 x 1.35) = 3`으로 산정한다.
원거리 공격력 `+1`이면 `floor((3 + 1) x 1.0) = 4`가 정상이다.

---

## 7. 상점 아이템 랭크별 스탯 증가 공식

상점 아이템 랭크:

```text
D / C / B / A / S
```

상점 아이템은 골드를 지불하고 구매하는 선택지이므로, 레벨업 카드보다 평균 기대값이 높아도 된다.

권장 랭크 파워:

| 랭크 | rank_power |
|---|---:|
| D | `1.0` |
| C | `1.8` |
| B | `3.2` |
| A | `5.5` |
| S | `9.0` |

공식:

```text
shop_item_value =
  shop_stat_base_value
  x rank_power
```

정수 스탯은 반올림 또는 스탯별 지정 반올림을 사용한다.
퍼센트 스탯은 소수점 1자리 이하를 버리거나 데이터에 직접 입력한다.

---

## 8. 상점 아이템 스탯별 기준 증가량

아래 값은 D랭크 기준 증가량이다.

| 스탯 | D 기준값 | 비고 |
|---|---:|---|
| 데미지 | `+1%` | 모든 최종 피해 multiplier |
| 공격속도 | `+3%` | multiplier 계열 |
| 공격범위 | `+5%` | multiplier 계열 |
| 최대 체력 | `+5` | 정수 |
| 방어력 | `+1` | 정수 |
| HP 재생 | `+1` | 정수/실수 가능 |
| 이동속도 | `+3%` | multiplier 계열 |
| 점프력 | `+3%` | multiplier 계열 |
| 채굴 데미지 | `+1` | 정수 |
| 채굴속도 | `+4%` | multiplier 계열 |
| 채굴범위 | `+5%` | multiplier 계열 |
| 치명타 확률 | `+1%p` | 확률 가산 |
| 행운 | `+1` | 실수/정수 가능 |
| 이자율 | `+1%p` | 이자율 가산 |
| 배터리 회복 | `+0.5/sec` | 실수 |

중요:

- 환경대응 전용 카드는 만들지 않는다.
- 모래 직접 제거, 모래 자동 정리, 중량 직접 증가 같은 카드는 레벨업 카드 풀에서 제외한다.
- 최대 중량은 생존 스탯에 가깝지만 환경대응성이 강하므로 레벨업 카드에서는 기본 제외한다. 상점 아이템으로만 제한적으로 다룬다.

---

## 9. 상점 아이템 랭크별 예시 증가량

### 데미지

D 기준값: `+1%`

| 랭크 | 증가량 |
|---|---:|
| D | `+1%` |
| C | `+2%` |
| B | `+3%` |
| A | `+5%` |
| S | `+9%` |

### 공격속도

D 기준값: `+3%`

| 랭크 | 증가량 |
|---|---:|
| D | `+3%` |
| C | `+5%` |
| B | `+10%` |
| A | `+17%` |
| S | `+27%` |

### 최대 체력

D 기준값: `+5`

| 랭크 | 증가량 |
|---|---:|
| D | `+5` |
| C | `+9` |
| B | `+16` |
| A | `+28` |
| S | `+45` |

### 치명타 확률

D 기준값: `+1%p`

| 랭크 | 증가량 |
|---|---:|
| D | `+1%p` |
| C | `+2%p` |
| B | `+3%p` |
| A | `+6%p` |
| S | `+9%p` |

---

## 10. 상점 아이템 랭크별 가격

상점 아이템 가격 결정 순서:

```text
1. item 데이터에 price_gold > 0이 있으면 그 값을 사용한다.
2. price_gold == 0이면 rank 기반 fallback 가격을 사용한다.
```

랭크별 fallback 가격:

| 랭크 | 가격 |
|---|---:|
| D | `15G` |
| C | `30G` |
| B | `60G` |
| A | `120G` |
| S | `240G` |

의도:

- 고랭크 아이템은 더 비싸게, 저랭크 아이템은 더 싸게 판매한다.
- 상점 가격이 골드 수입과 맞게 스케일링되어야 후반 S랭크 선택이 의미 있어진다.
- 특별한 조건부 아이템(`melee_purity_core` 등)은 데이터에 직접 explicit price를 설정할 수 있다.
- 표시 가격과 실제 구매 차감 가격은 반드시 일치한다.

예외:

| 아이템 | 랭크 | 데이터 price_gold | 실제 가격 | 비고 |
|---|---|---:|---:|---|
| `melee_purity_core` | A | `320G` | `320G` | 조건부 아이템 프리미엄 |
| `module_focus_circuit` | B | `240G` | `240G` | 조건부 아이템 프리미엄 |

### Shop Reroll Cost

Shop reroll only refreshes the current intermission shop list.
It does not change item price tiering.

Formula:

```text
current_reroll_cost =
  SHOP_REROLL_BASE_COST
  + current_shop_reroll_count * SHOP_REROLL_COST_INCREMENT
```

Constants:

```text
SHOP_REROLL_BASE_COST = 50G
SHOP_REROLL_COST_INCREMENT = 25G
```

Examples:

| Current shop reroll count | Next reroll cost |
|---:|---:|
| 0 | `50G` |
| 1 | `75G` |
| 2 | `100G` |
| 3 | `125G` |

`current_shop_reroll_count` is scoped to the current shop phase and resets to `0`
when a new intermission shop is generated.

---

## 11. 레벨업 카드 희귀도

레벨업 카드는 상점 아이템과 다른 희귀도 체계를 사용한다.

희귀도:

```text
Normal / Silver / Gold / Platinum
```

의도:

- 레벨업 선택 순간의 기대감을 만든다.
- 행운 스탯의 가치를 높인다.
- 상점 아이템 랭크와 혼동하지 않는다.
- 레벨업 보상이 상점 아이템을 완전히 대체하지 않게 한다.

---

## 12. 레벨업 카드 희귀도 확률

기본 확률:

| 희귀도 | 기본 확률 |
|---|---:|
| Normal | `70%` |
| Silver | `22%` |
| Gold | `7%` |
| Platinum | `1%` |

행운 보정:

```text
luck 1당:
  Normal   -1.00%p
  Silver   +0.50%p
  Gold     +0.35%p
  Platinum +0.15%p
```

확률 제한:

| 희귀도 | 제한 |
|---|---:|
| Normal | 최소 `35%` |
| Silver | 최대 `40%` |
| Gold | 최대 `20%` |
| Platinum | 최대 `8%` |

확률 계산 후에는 총합이 100%가 되도록 정규화한다.

예시:

| 행운 | Normal | Silver | Gold | Platinum |
|---:|---:|---:|---:|---:|
| 0 | `70%` | `22%` | `7%` | `1%` |
| 10 | `60%` | `27%` | `10.5%` | `2.5%` |
| 20 | `50%` | `32%` | `14%` | `4%` |
| 30 | `40%` | `37%` | `17.5%` | `5.5%` |

---

## 13. 레벨업 카드 희귀도 배율

레벨업 카드 값은 기본 카드 값에 희귀도 배율을 곱한다.

| 희귀도 | 배율 |
|---|---:|
| Normal | `1.0` |
| Silver | `1.6` |
| Gold | `2.5` |
| Platinum | `4.0` |

공식:

```text
level_up_card_value =
  level_up_base_value
  x level_up_rarity_multiplier
```

정수 스탯은 반올림한다.
퍼센트 스탯은 `%p` 또는 multiplier 변경량으로 변환해서 적용한다.

---

## 14. 레벨업 카드 스탯 풀

레벨업 카드는 아래 스탯만 사용한다.

전투:

- 데미지 % (전역)
- 근거리 공격력 (melee 모듈 전용)
- 원거리 공격력 (ranged 모듈 전용)
- 공격속도
- 공격범위
- 치명타 확률
- 방어력
- 최대 체력
- HP 재생

기동:

- 이동속도
- 점프력
- 배터리 회복

채굴:

- 채굴 데미지
- 채굴속도
- 채굴범위

경제/운:

- 행운
- 이자율

레벨업 카드에서 제외하는 항목:

- 모래 직접 제거
- 모래 자동 정리
- 벽 복구
- 중량 직접 증가
- 특정 블록 제거
- Day 종료 시 환경 정리
- 기타 환경대응 전용 효과

제외 이유:

- 환경대응 카드는 선택지가 너무 방어적으로 흘러갈 수 있다.
- Burial Protocol의 레벨업은 플레이어 본체 성장을 중심으로 한다.
- 환경대응은 상점 아이템, 기능 모듈, 특수 이벤트로 제한하는 편이 역할 분리가 좋다.

---

## 15. 레벨업 카드 기본 증가량

아래 값은 Normal 기준이다.

| 카드 | Normal 기준값 |
|---|---:|
| 데미지 증가 (전역) | `+1%` |
| 근거리 공격력 증가 | `+1` |
| 원거리 공격력 증가 | `+1` |
| 공격속도 증가 | `+2%` |
| 공격범위 증가 | `+5%` |
| 치명타 확률 증가 | `+2%p` |
| 최대 체력 증가 | `+5` |
| 방어력 증가 | `+1` |
| HP 재생 증가 | `+1` |
| 이동속도 증가 | `+3%` |
| 점프력 증가 | `+3%` |
| 배터리 회복 증가 | `+1/sec` |
| 채굴 데미지 증가 | `+1` |
| 채굴속도 증가 | `+4%` |
| 채굴범위 증가 | `+5%` |
| 행운 증가 | `+1` |
| 이자율 증가 | `+2%p` |

---

## 16. 레벨업 카드 희귀도별 예시

### 데미지 증가

Normal 기준값: `+1%`

| 희귀도 | 증가량 |
|---|---:|
| Normal | `+1%` |
| Silver | `+2%` |
| Gold | `+3%` |
| Platinum | `+4%` |

### 공격속도 증가

Normal 기준값: `+2%`

| 희귀도 | 증가량 |
|---|---:|
| Normal | `+2%` |
| Silver | `+3%` |
| Gold | `+5%` |
| Platinum | `+8%` |

### 최대 체력 증가

Normal 기준값: `+5`

| 희귀도 | 증가량 |
|---|---:|
| Normal | `+5` |
| Silver | `+8` |
| Gold | `+13` |
| Platinum | `+20` |

### 치명타 확률 증가

Normal 기준값: `+2%p`

| 희귀도 | 증가량 |
|---|---:|
| Normal | `+2%p` |
| Silver | `+3%p` |
| Gold | `+5%p` |
| Platinum | `+8%p` |

---

## 17. 레벨업 카드 생성 방식

레벨업 시 카드 5장을 제시한다.

권장 생성 순서:

```text
1. 카드 슬롯 1 희귀도 roll
2. 카드 슬롯 1 스탯 종류 roll
3. 카드 슬롯 2 희귀도 roll
4. 카드 슬롯 2 스탯 종류 roll
5. 카드 슬롯 3 희귀도 roll
6. 카드 슬롯 3 스탯 종류 roll
7. 카드 슬롯 4 희귀도 roll
8. 카드 슬롯 4 스탯 종류 roll
9. 카드 슬롯 5 희귀도 roll
10. 카드 슬롯 5 스탯 종류 roll
```

중복 규칙:

- 완전히 같은 카드 중복은 금지한다.
- 같은 스탯이라도 희귀도가 다르면 허용한다.

허용 예시:

```text
Normal 공격력
Gold 공격력
Silver 이동속도
```

비허용 예시:

```text
Normal 공격력
Normal 공격력
Normal 공격력
```

---

## 18. 레벨업 카드와 상점 아이템의 관계

레벨업 카드는 상점 아이템보다 평균적으로 약해야 한다.
상점 아이템은 골드를 지불하고 구매하는 선택지이기 때문이다.

권장 관계:

```text
Normal 레벨업 카드 = D랭크 상점 아이템의 60~80%
Silver 레벨업 카드 = D~C 사이
Gold 레벨업 카드 = C~B 사이
Platinum 레벨업 카드 = B~A 사이
```

중요:

```text
Platinum 레벨업 카드가 떠도 S랭크 상점 아이템보다 강하면 안 된다.
```

이렇게 해야 상점의 존재감이 유지된다.

---

## 19. 구현 시 주의사항

- 레벨업 카드 희귀도는 UI에서 명확히 표시한다.
- 희귀도별 색상, 테두리, 사운드 피드백을 둔다.
- 행운은 상점 랭크와 레벨업 희귀도에 모두 영향을 줄 수 있다.
- 행운이 너무 강해지지 않도록 확률 상한을 반드시 둔다.
- 환경대응 효과는 레벨업 카드 풀에서 제외한다.
- 레벨업 카드는 플레이어 본체 스탯 성장 중심으로 유지한다.
- 상점 아이템은 장비/기능/강화의 선택지로 유지한다.

---

## 20. 향후 튜닝 체크리스트

밸런스 조정 시 아래를 확인한다.

- Day 1 기본 1U 블록이 너무 오래 버티지 않는가
- Day 10 전후에 공격력/공속 빌드가 정상 작동하는가
- Day 20 이후 빌드가 약하면 실제로 밀리는가
- Day 30에서 좋은 빌드가 클리어 가능하지만 자동 승리는 아닌가
- 레벨업 Platinum이 너무 자주 뜨지 않는가
- 행운 빌드가 과도하게 강하지 않은가
- 상점 S랭크 아이템의 가치가 Platinum 레벨업 카드보다 충분히 높은가
- 채굴 카드가 전투 카드에 비해 너무 약하거나 강하지 않은가
- 방어/체력 카드가 압착 피해 시스템과 맞는가
