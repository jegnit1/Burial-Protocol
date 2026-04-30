# Size Spawn Rule Design Draft

작성일: 2026-04-30

범위: 설계 초안 리포트만 작성했다. 코드, `.tres`, TSV, 밸런스 수치는 수정하지 않았다.

기준 리포트:

- `docs/reports/block_catalog_material_size_type_audit.md`

기준 전제:

- Runtime Block = `Material x Size + optional Type`
- 현재 일반 스폰은 `Material x Size` 조합 후보를 만들고 조합 weight로 한 번에 roll한다.
- 목표 구조는 `Material roll -> 선택된 Material이 허용하는 Size 후보 필터 -> Size rule weight roll -> Optional Type roll`이다.
- Material의 size gating(`max_allowed_area`, `max_allowed_width`, `max_allowed_height`)은 유지한다.
- 일반 스폰 목표 height는 최대 3U다. height 4U 이상은 일반 스폰에서 제외한다.
- width 후보는 중앙 전장 10U 기준으로 1U~10U까지 설계 후보에 포함한다.
- Normal에서도 모든 size가 등장 가능해야 하지만, "등장 가능"과 "높은 확률 등장"은 분리한다. 큰 width/area는 Normal 초반에 hard lock 대신 epsilon 수준 weight로만 둔다.

## 1. 목표 스폰 흐름 정의

### 현재 방식과 목표 방식 비교

| 항목 | 현재 방식 | 목표 방식 | 장점 | 단점 | 마이그레이션 영향 |
|---|---|---|---|---|---|
| 선택 단위 | `Material x Size` 조합 후보 1회 roll | Material 1회 roll 후 Size 1회 roll | size rule을 독립 축으로 설계 가능 | 기존 분포와 달라질 가능성 큼 | distribution snapshot 필요 |
| Material 확률 | material weight와 size 후보 수/size weight가 섞임 | material weight가 먼저 확정됨 | material 등장률을 직접 통제 가능 | size 후보가 많은 material이 받던 간접 효과 사라짐 | material 등장률 재검증 필요 |
| Size 확률 | material별 후보 안에서 조합 weight에 포함 | 선택된 material의 허용 size 안에서 별도 roll | size curve를 day/difficulty별로 조정 가능 | material별 허용 size가 적으면 size 분포가 크게 달라짐 | material gating fallback 필요 |
| Type 선택 | 일반 스폰에서 먼저 optional type roll 후 resolver 전달 | Size 선택 후 optional type roll | 최종 block context 기반 type rule 확장 가능 | 현재 코드보다 resolver 책임 증가 | Type rule은 2차 확장으로 분리 가능 |
| 데이터 소유권 | `BlockSizeData.base_spawn_weight`와 hard min 조건 중심 | `BlockSizeData`는 물리/기본값, `SizeSpawnRule`은 등장 curve | sheet/TSV 밸런싱 쉬움 | 새 Resource/TSV/검증 필요 | data pipeline 확장 필요 |
| Normal 대형 size | 현재 hard `min_difficulty=hard`로 차단 | hard lock 제거, epsilon/ramp weight 사용 | Normal 후반 희귀 등장 가능 | 초반 억까 방지 설계 필요 | size min_difficulty 의미 변경 필요 |

### 목표 실행 흐름

```text
resolve_random_block_v2(day, difficulty):
  material_candidates = get_valid_material_candidates(day, difficulty)
  material = roll_material(material_candidates, rng)

  raw_size_candidates = get_sizes_allowed_by_material(material, day, difficulty)
  weighted_size_candidates = apply_size_spawn_rules(raw_size_candidates, day, difficulty)
  size = roll_size(weighted_size_candidates, rng)

  type = roll_optional_type(day, difficulty, material, size)
  return resolve_block(material, size, type)
```

중요한 차이:

- Material gating은 Size rule보다 먼저 적용한다.
- Size rule은 "허용된 size 후보"의 weight만 보정한다.
- Material이 금지한 size를 Size rule이 되살릴 수 없다.

## 2. Size Spawn Rule 데이터 구조 초안

### 권장 Resource 개념

`BlockSizeData`는 크기 자체와 기본 HP/reward/sand 기준을 담당하고, 새 `BlockSizeSpawnRuleData`가 등장 확률 정책을 담당한다.

```text
BlockSizeData
  size_id
  width_u
  height_u
  area
  hp_multiplier
  reward_multiplier
  base_spawn_weight
  tags

BlockSizeSpawnRuleData
  size_id
  rule_enabled
  base_spawn_weight_override
  recommended_min_stage
  recommended_min_difficulty
  use_min_difficulty_as_hard_lock
  normal_weight_mult
  hard_weight_mult
  extreme_weight_mult
  hell_weight_mult
  nightmare_weight_mult
  day_1_5_weight_mult
  day_6_10_weight_mult
  day_11_15_weight_mult
  day_16_20_weight_mult
  day_21_25_weight_mult
  day_26_30_weight_mult
  width_pressure_group
  height_pressure_group
  area_group
  horizontal_pressure_score
  vertical_pressure_score
  spawn_policy_group
  first_implementation
  notes
```

### 필수 표현 방식

| 필드 | 의미 | hard lock 여부 | 비고 |
|---|---|---:|---|
| `size_id` | `BlockSizeData.size_id` 참조 | N/A | primary key |
| `width_u`, `height_u`, `area` | sheet 가독성용 mirror 또는 export-only | N/A | import 시 `BlockSizeData`와 불일치하면 오류 처리 권장 |
| `base_spawn_weight` | size의 기본 등장 가중치 | 아니오 | `BlockSizeData.base_spawn_weight`를 기본값으로 쓰고 rule override 가능 |
| `recommended_min_stage` | curve가 본격 상승하기 시작하는 기준 Day/Stage | 아니오 | 기존 `min_stage` hard gate와 구분 |
| `recommended_min_difficulty` | curve reference difficulty | 아니오 | `normal`, `hard`, `extreme`, `hell`, `nightmare` |
| `use_min_difficulty_as_hard_lock` | 예외적 hard lock 허용 여부 | 선택 | 일반 size는 false 권장 |
| `day_*_weight_mult` | Day band별 weight multiplier | 아니오 | Normal 초반 대형 size는 0이 아니라 0.001 같은 epsilon 권장 |
| `*_weight_mult` | difficulty별 multiplier | 아니오 | 큰 size는 difficulty가 높을수록 상승 |
| `width_pressure_group` | width 기반 압박 그룹 | 아니오 | 예: `w1`, `w2`, `w3_4`, `w5_6`, `w7_8`, `w9_10` |
| `height_pressure_group` | height 기반 압박 그룹 | 아니오 | 예: `h1`, `h2`, `h3` |
| `area_group` | area 기반 체력/보상/모래 압박 그룹 | 아니오 | 예: `a1`, `a2_3`, `a4_6`, `a7_10`, `a11_15`, `a16_20`, `a21_30` |
| `horizontal_pressure_score` | 회피 공간 압박 점수 | 아니오 | width 영향은 vertical보다 크게 반영 |
| `vertical_pressure_score` | 공격스탯 요구 압박 점수 | 아니오 | height 3까지만 일반 스폰 허용 |
| `spawn_policy_group` | 일반/희귀/후반/이벤트 전용 구분 | 아니오 | resolver나 simulation에서 별도 리포트 가능 |
| `first_implementation` | 1차 구현 포함 여부 | 아니오 | `yes`, `candidate`, `event_only`, `deprecated` |
| `notes` | 밸런스 의도 | 아니오 | sheet 설명용 |

### 추천 weight 계산식

```text
effective_size_weight =
  base_spawn_weight
  x difficulty_weight_multiplier[difficulty]
  x day_band_weight_multiplier[day]
  x pressure_safety_multiplier
```

`pressure_safety_multiplier`는 초기에는 데이터 컬럼이 아니라 코드 helper로 계산해도 된다.

```text
pressure_safety_multiplier =
  clamp(
    1.0 / (1.0 + horizontal_pressure_score * 0.18 + vertical_pressure_score * 0.08),
    0.15,
    1.0
  )
```

width는 회피 공간을 직접 줄이므로 vertical보다 큰 감쇠를 권장한다.

## 3. Day / Difficulty별 Size Weight 보정 방식

### Difficulty multiplier 정책

| difficulty | 작은 size | 중간 size | 넓은 size | 큰 area size | 목적 |
|---|---:|---:|---:|---:|---|
| `normal` | 1.0 | 0.5~1.0 | 0.001~0.25 | 0.001~0.15 | 모든 size 가능, 초반 억까 방지 |
| `hard` | 0.9 | 1.0~1.5 | 0.05~0.8 | 0.05~0.6 | 큰 size 등장 시점 앞당김 |
| `extreme` | 0.8 | 1.2~2.0 | 0.2~1.4 | 0.15~1.0 | 넓은/큰 블록을 핵심 압박으로 사용 |
| `hell` | 0.75 | 1.4~2.4 | 0.4~2.0 | 0.3~1.5 | 큰 size를 일반 압박으로 전환 |
| `nightmare` | 0.7 | 1.6~3.0 | 0.6~2.8 | 0.5~2.2 | telegraph/event size도 낮은 빈도로 허용 |

### Day band multiplier 정책

| Day band | 작은 size | 중간 size | 넓은 size | 큰 area size | 설계 의도 |
|---|---:|---:|---:|---:|---|
| 1-5 | 1.0 | 0.15~0.5 | 0.001~0.03 | 0.001 | 튜토리얼/초반 안정 |
| 6-10 | 1.0 | 0.4~0.9 | 0.005~0.12 | 0.001~0.03 | 2U/3U 노출 시작 |
| 11-15 | 0.9 | 0.8~1.2 | 0.02~0.3 | 0.005~0.08 | 4U/5U 희귀 노출 |
| 16-20 | 0.85 | 1.0~1.6 | 0.08~0.6 | 0.02~0.18 | 넓은 블록 압박 도입 |
| 21-25 | 0.8 | 1.1~1.8 | 0.15~1.0 | 0.05~0.4 | 후반 mixed pressure |
| 26-30 | 0.75 | 1.2~2.0 | 0.25~1.4 | 0.1~0.7 | 최종 압박. 단 9~10U는 telegraph 권장 |

### Normal에서 억까를 막는 핵심 규칙

- hard `min_difficulty`로 막지 않는다.
- Normal 초반 대형 size는 `0.001` 같은 epsilon multiplier를 사용한다.
- width 7U 이상은 regular random이 아니라 `spawn_policy_group=telegraphed_rare` 또는 `event_only`를 권장한다.
- width 9U~10U는 중앙 전장 대부분/전체를 막으므로 일반 무예고 낙하에는 부적합하다. Normal에서도 등장 가능하게 하려면 warning, spawn delay, clear lane, boss/event context가 필요하다.
- 같은 화면에 width 6U 이상 active block이 이미 있으면 다음 wide size weight를 0에 가깝게 낮추는 runtime safety rule을 별도로 권장한다.

## 4. 목표 Size 체계 / Group 분류 초안

### Group 기준

| group | 조건 | 의미 |
|---|---|---|
| `a1` | area 1 | 기본 |
| `a2_3` | area 2~3 | 초반 확장 |
| `a4_6` | area 4~6 | 중반 일반 압박 |
| `a7_10` | area 7~10 | 후반/고난이도 압박 |
| `a11_15` | area 11~15 | 고난이도 중심 |
| `a16_20` | area 16~20 | 매우 높은 압박 |
| `a21_30` | area 21~30 | 이벤트/보스/기믹 성격 |

`horizontal_pressure_score`는 `width_u - 1`, `vertical_pressure_score`는 `height_u - 1`을 기본 제안으로 둔다. 실제 weight 계산에서는 horizontal score를 더 크게 반영한다.

### Size 후보 1x1~10x3

`recommended_min_difficulty`는 hard lock이 아니라 curve reference다. Normal에서도 epsilon weight로 등장 가능하게 설계한다.

| size_id | w | h | area | area_group | H score | V score | recommended_min_day | recommended_min_difficulty | recommended_base_weight | normal_weight_policy | hard_weight_policy | extreme+_weight_policy | 1차 구현 | notes |
|---|---:|---:|---:|---|---:|---:|---:|---|---:|---|---|---|---|---|
| `size_1x1` | 1 | 1 | 1 | `a1` | 0 | 0 | 1 | `normal` | 1.00 | full from day 1 | stable | taper slightly | yes | 기본 블록 |
| `size_2x1` | 2 | 1 | 2 | `a2_3` | 1 | 0 | 2 | `normal` | 0.85 | early common | common | common | yes | 현재 데이터 유지 후보 |
| `size_3x1` | 3 | 1 | 3 | `a2_3` | 2 | 0 | 6 | `normal` | 0.55 | rare early, ramp mid | common after day 6 | common | yes | 기존 hard lock 제거 대상 |
| `size_4x1` | 4 | 1 | 4 | `a4_6` | 3 | 0 | 10 | `hard` | 0.35 | epsilon early, rare late | uncommon mid | common late | yes | 현재 존재, soft curve 전환 |
| `size_5x1` | 5 | 1 | 5 | `a4_6` | 4 | 0 | 14 | `hard` | 0.22 | epsilon early, rare day 20+ | uncommon | common in high diff | yes | 첫 wide pressure 확장 후보 |
| `size_6x1` | 6 | 1 | 6 | `a4_6` | 5 | 0 | 18 | `extreme` | 0.14 | epsilon, very rare late | rare | uncommon/common | yes | 1차 상한 후보. runtime safety 필요 |
| `size_7x1` | 7 | 1 | 7 | `a7_10` | 6 | 0 | 22 | `extreme` | 0.08 | epsilon only | rare late | uncommon | candidate | 중앙 70% 차단. telegraph 권장 |
| `size_8x1` | 8 | 1 | 8 | `a7_10` | 7 | 0 | 25 | `hell` | 0.05 | epsilon only | very rare | rare/uncommon | candidate | 일반 random은 위험 |
| `size_9x1` | 9 | 1 | 9 | `a7_10` | 8 | 0 | 28 | `hell` | 0.03 | epsilon/event | event rare | event | event_only | 거의 전장 봉쇄 |
| `size_10x1` | 10 | 1 | 10 | `a7_10` | 9 | 0 | 30 | `nightmare` | 0.02 | event only | event only | event only | event_only | 중앙 전장 전체 폭. 일반 낙하 부적합 |
| `size_1x2` | 1 | 2 | 2 | `a2_3` | 0 | 1 | 2 | `normal` | 0.90 | early common | common | common | yes | 현재 데이터 유지 후보 |
| `size_2x2` | 2 | 2 | 4 | `a4_6` | 1 | 1 | 6 | `normal` | 0.55 | rare early, ramp mid | common | common | yes | 기존 hard lock 제거 대상 |
| `size_3x2` | 3 | 2 | 6 | `a4_6` | 2 | 1 | 12 | `hard` | 0.30 | epsilon early, rare late | uncommon | common | yes | 1차 확장 추천. material gate 확장 필요 |
| `size_4x2` | 4 | 2 | 8 | `a7_10` | 3 | 1 | 16 | `hard` | 0.18 | epsilon, very rare late | rare/uncommon | common late | yes | steel 컨셉과 맞지만 current max_area 4가 막음 |
| `size_5x2` | 5 | 2 | 10 | `a7_10` | 4 | 1 | 20 | `extreme` | 0.10 | epsilon only | rare late | uncommon | candidate | 넓이/체력 모두 큼 |
| `size_6x2` | 6 | 2 | 12 | `a11_15` | 5 | 1 | 23 | `extreme` | 0.06 | epsilon only | very rare | rare/uncommon | candidate | runtime safety 필요 |
| `size_7x2` | 7 | 2 | 14 | `a11_15` | 6 | 1 | 26 | `hell` | 0.035 | epsilon/event | event rare | rare event | candidate | 일반 random 상한 후보 밖 |
| `size_8x2` | 8 | 2 | 16 | `a16_20` | 7 | 1 | 28 | `hell` | 0.020 | event only | event only | event rare | event_only | 전장 압박 과다 |
| `size_9x2` | 9 | 2 | 18 | `a16_20` | 8 | 1 | 30 | `nightmare` | 0.012 | event only | event only | event only | event_only | boss/gimmick 권장 |
| `size_10x2` | 10 | 2 | 20 | `a16_20` | 9 | 1 | 30 | `nightmare` | 0.008 | event only | event only | event only | event_only | 일반 무예고 스폰 금지 권장 |
| `size_1x3` | 1 | 3 | 3 | `a2_3` | 0 | 2 | 6 | `normal` | 0.60 | rare early, ramp mid | common | common | yes | height 3 허용. 기존 hard lock 제거 대상 |
| `size_2x3` | 2 | 3 | 6 | `a4_6` | 1 | 2 | 12 | `hard` | 0.32 | epsilon early, rare late | uncommon | common | yes | vertical stat pressure |
| `size_3x3` | 3 | 3 | 9 | `a7_10` | 2 | 2 | 18 | `extreme` | 0.16 | epsilon only | rare | uncommon | candidate | 높은 HP 요구 |
| `size_4x3` | 4 | 3 | 12 | `a11_15` | 3 | 2 | 22 | `extreme` | 0.08 | epsilon only | very rare | rare/uncommon | candidate | width+height 복합 압박 |
| `size_5x3` | 5 | 3 | 15 | `a11_15` | 4 | 2 | 25 | `hell` | 0.04 | epsilon/event | event rare | rare | candidate | high diff용 |
| `size_6x3` | 6 | 3 | 18 | `a16_20` | 5 | 2 | 27 | `hell` | 0.02 | event only | event rare | rare event | event_only | 일반 random 비추천 |
| `size_7x3` | 7 | 3 | 21 | `a21_30` | 6 | 2 | 29 | `nightmare` | 0.012 | event only | event only | event rare | event_only | boss/gimmick 권장 |
| `size_8x3` | 8 | 3 | 24 | `a21_30` | 7 | 2 | 30 | `nightmare` | 0.006 | event only | event only | event only | event_only | 일반 낙하 부적합 |
| `size_9x3` | 9 | 3 | 27 | `a21_30` | 8 | 2 | 30 | `nightmare` | 0.003 | event only | event only | event only | event_only | arena hazard 성격 |
| `size_10x3` | 10 | 3 | 30 | `a21_30` | 9 | 2 | 30 | `nightmare` | 0.001 | event only | event only | event only | event_only | 보스/기믹 전용 |

### 1차 구현 포함 여부 정리

| 분류 | size_id | 이유 |
|---|---|---|
| 1차 즉시 포함 | `size_1x1`, `size_1x2`, `size_2x1`, `size_2x2`, `size_1x3`, `size_3x1`, `size_4x1` | 현재 존재하거나 height 3 이하, area 4 이하라 비교적 안전 |
| 1차 확장 포함 | `size_2x3`, `size_3x2`, `size_4x2`, `size_5x1`, `size_6x1` | 목표 width/height 압박을 테스트하기 좋은 최소 확장 |
| 후보로 유지 | `size_7x1`, `size_8x1`, `size_5x2`, `size_6x2`, `size_7x2`, `size_3x3`, `size_4x3`, `size_5x3` | 고난이도/후반용. distribution simulation 후 도입 |
| 이벤트/보스/기믹 전용 | `size_9x1`, `size_10x1`, `size_8x2`, `size_9x2`, `size_10x2`, `size_6x3`, `size_7x3`, `size_8x3`, `size_9x3`, `size_10x3` | 중앙 전장 봉쇄 또는 과도한 HP 요구 |
| 제거/비추천/마이그레이션 | `size_1x4` 및 모든 height 4U 이상 | 목표 일반 스폰 height 상한 3U와 불일치 |

주의: 현재 material gating은 대부분 `max_allowed_area <= 4`라서 `size_2x3`, `size_3x2`, `size_4x2`, `size_5x1`, `size_6x1`은 실제로는 거의 또는 전혀 선택되지 않는다. 1차 확장을 구현하려면 material gating 정책도 함께 검토해야 한다.

## 5. Material Size Gating과의 관계

### 우선순위

```text
1. Material roll
2. 선택된 Material의 material gating 적용
3. Size base 조건 및 rule_enabled 적용
4. Size spawn rule weight 계산
5. Size roll
```

Material gating은 hard constraint다. Size spawn rule은 weight constraint다.

### 충돌 처리

| 상황 | 권장 처리 |
|---|---|
| Size rule weight는 높지만 material `max_allowed_area`가 막음 | spawn 후보에서 제거. Size rule이 material gate를 우회하지 않음 |
| 선택된 material의 허용 size가 1개뿐 | 해당 size 확정. weight normalization으로 인한 왜곡을 문제로 보지 않음 |
| 선택된 material의 허용 size가 0개 | `default_size_id`가 material gate를 통과하면 fallback, 아니면 material reroll 후 warning |
| material gate가 지나치게 좁아 새 size가 거의 안 나옴 | material data를 별도 마이그레이션 대상으로 보고 simulation에서 경고 |
| boss/specific block resolve | 일반 random rule을 적용하지 않고 explicit material/size/type resolve 유지 |

### 주요 material 처리

| material | 현재 gating | 목표 처리 |
|---|---|---|
| `bomb` | max area 1, width 1, height 1 | 1x1만 허용 유지. Size roll은 degenerate 확정 |
| `gold` | max area 2, width 2, height 2 | 1x1, 1x2, 2x1만 허용. reward material이라 넓은 size로 확장하지 않는 편이 안전 |
| `steel` | max area 4, width 4, height 2 | 현재대로면 4x2도 area 8이라 불가. steel을 넓은 금속 블록 컨셉으로 쓰려면 max area를 별도 검토해야 함 |
| `wood`, `rock`, `marble`, `cement`, `glass` | 대부분 max area 4, width 2~4, height 2~4 | 목표 width 5~10을 실제 스폰하려면 material별 max_allowed_area/width 재설계 필요 |

핵심: size 후보군을 1~10U로 설계하더라도, 현재 material gating을 유지하면 일반 스폰에서 실제로 나올 수 있는 후보는 매우 제한된다. size spawn rule 구현 전후로 material gate audit이 한 번 더 필요하다.

## 6. TSV / Google Sheets 표현 방식

### 선택지 비교

| 안 | 설명 | 장점 | 단점 | 판단 |
|---|---|---|---|---|
| A. `block_sizes.tsv` 확장 | size 정의 파일에 curve 컬럼을 모두 추가 | 파일 하나에서 편집 가능 | physical size와 spawn policy가 섞임. 컬럼이 과밀해짐 | 비추천 |
| B. `block_size_spawn_rules.tsv` 추가 | size physical data와 spawn rule을 분리 | 데이터 소유권 명확. Google Sheets 탭 분리 쉬움. curve 확장 가능 | 새 Resource/import/export/validation 필요 | 최종 추천 |
| C. `BlockCatalog.tres` 내부 size Resource에 필드 추가 | `BlockSizeData`에 rule 필드 직접 추가 | Resource 수가 적음 | 코드상 역할 분리 약화. TSV도 결국 과밀해짐 | 단기 편의안 |
| D. `StageTable.tres`에 Day별 size weight override 추가 | Day 데이터에 size weight를 넣음 | Day별 이벤트 제어 쉬움 | size 기본 정책과 stage 이벤트가 뒤섞임. 30일 x size matrix 관리 부담 | override 전용 2차 기능으로만 권장 |

### 최종 추천

최종 추천은 B다.

```text
data_tsv/block_sizes.tsv
  - size의 물리/스탯 정의

data_tsv/block_size_spawn_rules.tsv
  - size의 day/difficulty 등장 rule
```

런타임 `.tres` 기준으로는 `BlockCatalog.tres`에 새 배열을 추가하는 방향이 자연스럽다.

```text
BlockCatalog
  block_materials
  block_sizes
  block_types
  block_size_spawn_rules
```

### `block_size_spawn_rules.tsv` 컬럼 초안

| column | type | import rule |
|---|---|---|
| `size_id` | StringName | required, `block_sizes.tsv`에 존재해야 함 |
| `width_u` | int | optional mirror, mismatch 시 validation error |
| `height_u` | int | optional mirror, mismatch 시 validation error |
| `area` | int | optional mirror, mismatch 시 validation error |
| `base_spawn_weight` | float | empty면 `BlockSizeData.base_spawn_weight` 사용 |
| `recommended_min_stage` | int | hard lock 아님 |
| `recommended_min_difficulty` | StringName | hard lock 아님 |
| `use_min_difficulty_as_hard_lock` | bool | 기본 false |
| `normal_weight_mult` | float | required |
| `hard_weight_mult` | float | required |
| `extreme_weight_mult` | float | required |
| `hell_weight_mult` | float | required |
| `nightmare_weight_mult` | float | required |
| `day_1_5_weight_mult` | float | required |
| `day_6_10_weight_mult` | float | required |
| `day_11_15_weight_mult` | float | required |
| `day_16_20_weight_mult` | float | required |
| `day_21_25_weight_mult` | float | required |
| `day_26_30_weight_mult` | float | required |
| `width_pressure_group` | String | required |
| `height_pressure_group` | String | required |
| `area_group` | String | required |
| `horizontal_pressure_score` | float | required |
| `vertical_pressure_score` | float | required |
| `spawn_policy_group` | String | required |
| `first_implementation` | String | `yes`, `candidate`, `event_only`, `deprecated` |
| `notes` | String | optional |

### `block_sizes.tsv` 최소 변경 방향

`block_sizes.tsv`에는 물리 정의와 기본 스탯만 남긴다.

```text
size_id
width_u
height_u
area
hp_multiplier
reward_multiplier
base_spawn_weight
min_difficulty
min_stage
max_stage
is_enabled
tags
notes
```

다만 목표 구조에서는 `min_difficulty`와 `min_stage`를 hard lock으로 계속 쓰면 Normal 모든 size 허용 원칙과 충돌한다. 구현 단계에서는 다음 중 하나를 선택해야 한다.

| 선택 | 설명 | 추천 |
|---|---|---|
| `min_difficulty`, `min_stage`를 모두 soft reference로 의미 변경 | 기존 함수 수정 필요 | 가능하지만 이름 혼동 큼 |
| `block_sizes.tsv`의 hard lock 필드는 blank/1로 완화하고 rule TSV에서 recommended 값 사용 | 기존 구조와 충돌 적음 | 추천 |
| hard lock 필드는 boss/event 전용 size에만 사용 | 일반 size는 false/blank | 추천 |

## 7. BlockSpawnResolver 변경 초안

### 책임 분리

| 함수 | 책임 |
|---|---|
| `get_valid_material_candidates(day, difficulty)` | enabled, min/max stage, min difficulty를 만족하는 material 후보 수집 |
| `roll_material(candidates, rng)` | material `base_spawn_weight` 기반 roll |
| `get_valid_size_candidates(material, day, difficulty)` | enabled size 중 material gate를 통과하는 후보 수집 |
| `apply_size_spawn_rules(size_candidates, day, difficulty)` | `block_size_spawn_rules`를 적용해 effective weight 계산 |
| `roll_size(weighted_size_candidates, rng)` | size effective weight 기반 roll |
| `roll_optional_type(day, difficulty, material, size)` | optional type roll. 초기에는 기존 `pick_block_type_definition_or_none()` 유지 가능 |
| `resolve_block(material, size, type)` | `_build_resolved_definition()` 재사용 |

### 기존 함수와의 관계

| 현재 함수 | 목표 처리 |
|---|---|
| `BlockCatalog.get_spawn_candidates()` | v1 compatibility로 유지하거나 simulation 비교용으로 유지 |
| `BlockCatalog.get_spawn_weight_for_candidate()` | v1 compatibility. v2에서는 size rule weight 계산과 분리 |
| `BlockCatalog.is_material_size_allowed()` | material gate helper로 유지 |
| `BlockSpawnResolver.resolve_random_block()` | 내부를 v2 flow로 교체하거나 `resolve_random_block_v2()`를 추가 후 전환 |
| `BlockSpawnResolver.resolve_specific_block()` | boss/테스트용으로 유지. random size rule 적용하지 않음 |
| `_build_resolved_definition()` | 그대로 재사용 가능 |

### fallback 권장

```text
if material_candidates.empty:
  fallback to default material + default size, warning

if size_candidates.empty after material gate:
  if default_size allowed:
    use default size, warning
  else:
    reroll material once, then fallback, warning

if all size effective weights <= 0:
  use highest base_spawn_weight size among allowed candidates, warning
```

## 8. 회귀 위험 분석

| 리스크 | 원인 | 완화 |
|---|---|---|
| material 등장률 변화 | 조합 후보 roll에서 material-first roll로 바뀜 | v1/v2 material distribution 비교 |
| size 등장률 변화 | size 후보 수와 material weight 분리 | Day/difficulty별 size distribution snapshot |
| size 후보가 적은 material 확률 왜곡 | bomb/gold처럼 gate가 좁음 | material 확률은 유지하고 size만 normalized. 별도 경고 리포트 |
| bomb 처리 | 1x1만 허용 | degenerate size 확정으로 처리 |
| gold 처리 | reward material이 큰 size와 결합하면 보상 폭증 | gold max area 2 유지 권장 |
| steel 처리 | width 4/height 2 의도와 max area 4 충돌 | steel gate 재검토 필요 |
| Normal wide 억까 | width 7~10이 무예고로 떨어짐 | epsilon weight, telegraph group, active wide cooldown |
| 10U width 전장 봉쇄 | 중앙 전장 폭과 동일 | 일반 random 제외 또는 event/boss 전용 |
| height 3U 과도한 HP 요구 | area와 size hp가 같이 증가 | base weight 낮게, Normal에서는 rare |
| boss resolve 회귀 | random rule을 boss에도 적용하면 기존 boss가 바뀜 | `resolve_specific_block()`은 rule 미적용 유지 |
| balance_snapshot 변화 | 스폰 분포와 candidate count 변화 | snapshot 확장 후 기준값 재승인 |
| TSV 실수 | 새 rule table과 size table 불일치 | validation에서 `size_id`, width/height/area mismatch 검증 |

## 9. 구현 전 검증 계획

실제 구현 전에는 최소한 simulation 리포트를 먼저 추가하는 것이 좋다.

| 검증 | 목적 |
|---|---|
| Day별 material distribution simulation | v1/v2 전환 후 material 등장률 변화 확인 |
| Day별 size distribution simulation | Normal 초반/후반 size 분포 확인 |
| difficulty별 size distribution simulation | Hard 이상에서 큰 size가 충분히 증가하는지 확인 |
| 10,000회 spawn Monte Carlo 리포트 | 실제 roll 기반 분포 검증 |
| 기존 방식 vs 신규 방식 비교 리포트 | 마이그레이션 영향 수치화 |
| width pressure distribution 리포트 | width 5+ / 7+ / 9+ 빈도 확인 |
| area distribution 리포트 | HP/보상/모래 압박의 간접 지표 확인 |
| material gate coverage 리포트 | 각 material에서 실제 가능한 size 수와 weight 합 확인 |
| event-only leakage 리포트 | event_only size가 regular random에 섞이지 않는지 확인 |
| balance_snapshot 확장 | `block_catalog.size_spawn_rules`, distribution summary 추가 |

권장 출력:

```text
docs/reports/block_spawn_distribution_snapshot.md
docs/reports/block_spawn_distribution_diff_v1_v2.md
```

## 10. 최종 권장안

### 추천 구조

최종 추천은 B: 별도 `data_tsv/block_size_spawn_rules.tsv` 추가다.

`block_sizes.tsv`는 "무엇인가"를 정의하고, `block_size_spawn_rules.tsv`는 "언제 얼마나 나오는가"를 정의한다. 이 분리가 가장 오래 버틴다.

### 구현 순서 초안

| 순서 | 작업 | 비고 |
|---:|---|---|
| 1 | `BlockSizeSpawnRuleData.gd` Resource 추가 | 코드 구현 단계에서 수행 |
| 2 | `BlockCatalog.gd`에 `block_size_spawn_rules` 배열과 lookup 추가 | data source 확장 |
| 3 | `data_tsv/block_size_spawn_rules.tsv` schema/import/export/validation 추가 | Google Sheets 탭 대응 |
| 4 | `BlockSpawnResolver`에 v2 material-first / size-second flow 추가 | v1과 비교 가능하게 flag 또는 별도 함수 권장 |
| 5 | distribution simulation 테스트 추가 | 실제 전환 전 필수 |
| 6 | `block_sizes.tsv` hard min_difficulty/min_stage 완화 | Normal 모든 size 허용 전제 반영 |
| 7 | material gating 재검토 | width 5~10 실제 등장 가능 여부 결정 |

### 다음 구현으로 넘어가기 전 결정 필요 사항

| 결정 | 추천 |
|---|---|
| size rule 저장 위치 | `data_tsv/block_size_spawn_rules.tsv` + `BlockCatalog.block_size_spawn_rules` |
| Normal 대형 size 처리 | hard lock 금지, epsilon weight + event/telegraph group |
| width 9~10 처리 | 일반 random 비추천, event/boss/gimmick 전용 |
| height 4 처리 | 일반 스폰 제거/마이그레이션 |
| material gate 우선순위 | material gate hard, size rule soft |
| current max_allowed_area 문제 | 1차 구현 전 material gate coverage 리포트로 확인 |

## 11. 한 줄 결론

Size spawn rule은 `block_sizes.tsv`에 섞지 말고 별도 `block_size_spawn_rules.tsv`로 분리하는 것이 좋다. 목표 resolver는 material을 먼저 뽑고, 해당 material의 hard size gate를 통과한 후보에만 day/difficulty weight curve를 적용해야 한다.
