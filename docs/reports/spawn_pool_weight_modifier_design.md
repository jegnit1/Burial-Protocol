# Block Spawn Pool + Weight Modifier Design

작성일: 2026-05-01

범위: 설계 리포트 작성만 수행한다. 코드, `.tres`, TSV, 밸런스 수치는 수정하지 않는다.

## 1. 목적

현재 블록 데이터는 `Material`, `Size`, `Type` 리소스로 분리되어 있지만, 일반 블록 스폰은 `Material x Size` 조합 후보를 만든 뒤 Material의 `max_allowed_area`, `max_allowed_width`, `max_allowed_height`로 Size를 hard block하고, 남은 조합을 하나의 weight pool에서 roll한다.

앞으로의 목표는 이 구조를 업계식 `Spawn Pool + Weight Modifier` 방식으로 바꾸는 것이다.

- 모든 `Material x Size` 조합은 가능하다.
- Material은 Size 후보를 제거하지 않는다.
- 위험 조합은 hard block이 아니라 낮은 `weight_multiplier`로 제어한다.
- 일반 스폰의 hard block은 물리적으로 불가능하거나 규칙상 금지되는 전역 조건에만 사용한다.
- `max_allowed_area`, `max_allowed_width`, `max_allowed_height`는 장기적으로 deprecated 또는 제거 대상이다.

## 2. 확인 기준

참고한 기존 리포트:

| 문서 | 핵심 참고 내용 |
| --- | --- |
| `docs/reports/block_catalog_material_size_type_audit.md` | 현재 BlockCatalog는 Material/Size/Type 데이터를 분리 보유하지만, 스폰은 Material x Size 조합 roll이다. |
| `docs/reports/size_spawn_rule_design.md` | Size spawn rule은 별도 TSV로 분리하는 방향이 적합하며, width 1~10, height 1~3 후보를 설계 대상으로 본다. |
| `docs/reports/material_size_gating_refactor_report.md` | `max_allowed_area` 제거만으로는 width 5~10 확장이 해결되지 않으며, `max_allowed_width/height`도 재검토가 필요하다. |

확인한 런타임/데이터:

| 파일 | 현재 역할 |
| --- | --- |
| `data/blocks/BlockCatalog.tres` | Material, Size, Type 리소스 배열을 보유한다. |
| `data_tsv/block_materials.tsv` | Material 기본값과 `max_allowed_*` 제한을 보유한다. |
| `data_tsv/block_sizes.tsv` | 현재 Size 기본값과 hard unlock 성격의 `min_difficulty/min_stage`를 보유한다. |
| `data_tsv/block_types.tsv` | 현재 `boss` type만 있으며 random spawn은 꺼져 있다. |
| `scripts/data/BlockCatalog.gd` | `get_spawn_candidates()`에서 Material x Size 조합을 만들고 hard gate를 적용한다. |
| `scripts/data/BlockSpawnResolver.gd` | weighted candidate를 받아 final HP/reward/sand를 계산한다. |
| `scripts/tools/data_pipeline/*` | block TSV import/export/schema에 `max_allowed_*`가 연결되어 있다. |
| `scripts/tests/balance_snapshot.gd` | 현재 `get_spawn_candidates()` 기반 분포와 resolved block 수치를 스냅샷으로 출력한다. |

## 3. 기존 Material Gate 방식의 문제

현재 `BlockCatalog.is_material_size_allowed()`는 다음 조건으로 Size를 제거한다.

| 조건 | 현재 의미 | 장기 구조 문제 |
| --- | --- | --- |
| `max_allowed_area` | Size 면적이 Material 허용 면적을 넘으면 차단 | width와 height의 플레이 의미를 같은 값으로 뭉갠다. `5x1`과 `1x5`를 같은 area로 본다. |
| `max_allowed_width` | Size width가 Material 허용 폭을 넘으면 차단 | width 1~10 확장 시 대부분 material이 넓은 블록을 가질 수 없게 된다. |
| `max_allowed_height` | Size height가 Material 허용 높이를 넘으면 차단 | height 1~3 목표 구조와는 일부 맞지만, material 궁합을 hard block으로 처리한다. |
| Size `min_difficulty` | 현재 일부 size를 hard 이상으로 제한 | Normal에서도 모든 size가 낮은 확률로 등장 가능해야 한다는 새 전제와 충돌한다. |
| Size `min_stage` | 특정 Day 이전 size를 제거 | Day별 ramp-up weight가 아니라 하드락으로 동작한다. |

문제의 핵심은 Material이 Size 후보를 제거한다는 점이다. `bomb + huge`, `gold + huge`, `glass + wide_large` 같은 위험 조합은 실제로 금지할 조합이 아니라 매우 낮은 확률, 후반 Day, 이벤트성 telegraph로 제어할 조합이다.

현재 구조는 콘텐츠 조합 가능성을 줄이고, 확장 size를 추가할수록 `max_allowed_*` 값이 실제 스폰 디자인을 우회적으로 지배하게 된다. 또한 `resolve_specific_block()`도 같은 gate를 쓰기 때문에 보스, 이벤트, 테스트용 특정 조합 resolve까지 거절될 수 있다.

## 4. 새 Spawn Pool + Weight Modifier 구조

목표 구조는 데이터를 아래 책임으로 분리한다.

| 데이터 | 책임 | hard block 여부 |
| --- | --- | --- |
| `MaterialData` | 재질 자체의 성격. HP, reward, base spawn weight, visual/color, special result | Size를 hard block하지 않는다. |
| `SizeData` | 물리 크기. width, height, area, HP/reward/sand 배율, pressure score, group | 전역 물리 규칙만 따른다. |
| `BlockSizeSpawnRule` | Day/difficulty별 Size 등장 확률과 ramp-up | hard lock보다 weight curve 중심 |
| `MaterialSizeWeightRule` | Material x Size 궁합 multiplier | 후보 제거 금지. 0 대신 epsilon 사용 |
| `OptionalTypeRule` | Type/Affix의 optional 부착과 weight | type 자체의 별도 정책 |

### MaterialData

Material은 재질 자체의 성격만 담당한다.

유지할 값:

- `material_id`
- `display_name`
- `hp_multiplier`
- `reward_multiplier`
- `base_spawn_weight`
- `special_result_type`
- `color_key`
- `block_color`
- `is_enabled`
- `notes`

Deprecated 후보:

- `max_allowed_area`
- `max_allowed_width`
- `max_allowed_height`

검토 대상:

- `min_difficulty`
- `min_stage`
- `max_stage`

Material의 Day/difficulty 노출 시점도 장기적으로는 hard lock보다 material spawn weight modifier로 바꾸는 편이 더 일관적이다. 다만 이번 설계의 핵심은 Material이 Size를 제거하지 않는 것이다.

### SizeData

Size는 블록의 물리 크기와 기본 배율을 담당한다.

권장 필드:

- `size_id`
- `width_u`
- `height_u`
- `area`
- `hp_multiplier`
- `reward_multiplier`
- `sand_multiplier` 또는 sand 계산 기준
- `base_spawn_weight`
- `horizontal_pressure_score`
- `vertical_pressure_score`
- `area_group`
- `width_group`
- `height_group`
- `size_group`
- `is_enabled`
- `tags`
- `notes`

현재 `min_difficulty/min_stage`는 hard unlock으로 쓰이고 있으나, 목표 구조에서는 `BlockSizeSpawnRule`의 day/difficulty weight ramp로 이동하는 것이 좋다.

## 5. 현재 흐름과 목표 흐름 비교

| 항목 | 현재 방식 | 목표 방식 | 장점 | 단점/위험 | 마이그레이션 영향 |
| --- | --- | --- | --- | --- | --- |
| 후보 생성 | 모든 Material x Size 조합 생성 후 `is_material_size_allowed()`로 필터 | Material roll 후 전체 Size pool을 가져오고 전역 규칙만 필터 | Material과 Size 책임이 분리된다 | 기존 분포와 달라진다 | distribution snapshot 필요 |
| Material 처리 | 조합 weight 안에 material weight가 포함 | material pool에서 먼저 roll | material 등장률 제어가 명확해진다 | 2단계 roll로 pair 확률 변화 | material distribution 비교 필요 |
| Size 처리 | material gate를 통과한 size만 조합 후보가 됨 | size spawn rule + material-size multiplier로 최종 size weight 계산 | 큰 size ramp-up 제어가 쉬움 | wide 억까 제어가 필요 | size pressure simulation 필요 |
| Material x Size 궁합 | `max_allowed_*` hard block | `MaterialSizeWeightRule` multiplier | 모든 조합 가능, 위험 조합은 극저확률 | multiplier 튜닝 필요 | 새 TSV/resource 필요 |
| Type 처리 | random chance가 0이면 없음, boss는 specific spawn | optional type roll을 별도 책임으로 유지 | 일반 affix 확장 가능 | boss resolve와 일반 spawn 분리 필요 | Type rule 확장 가능 |
| 특정 조합 resolve | 일반 gate에 걸리면 rejected | 일반 spawn gate와 specific resolve policy 분리 | 보스/이벤트 조합 안전 | 정책 분리 필요 | resolver API 조정 필요 |

## 6. 목표 스폰 흐름

권장 흐름:

1. 현재 Day, difficulty, stage context를 만든다.
2. 유효 Material 후보를 수집한다.
3. Material `base_spawn_weight`와 Day/difficulty modifier를 적용한다.
4. Material을 roll한다.
5. 전체 Size 후보를 수집한다.
6. Size 후보에는 전역 hard rule만 적용한다.
   - `width_u <= center_play_width`
   - `height_u <= general_spawn_max_height`
   - `width_u > 0`, `height_u > 0`
   - `is_enabled == true`
   - 특수 stage에서 의도적으로 잠근 경우
7. `BlockSizeSpawnRule`로 Day/difficulty별 size weight를 계산한다.
8. 선택된 Material과 각 Size 조합에 `MaterialSizeWeightRule` multiplier를 적용한다.
9. 최종 Size를 roll한다.
10. Optional Type을 roll한다.
11. Material x Size + optional Type으로 resolved block을 생성한다.

핵심 원칙:

- Material은 Size 후보를 제거하지 않는다.
- `MaterialSizeWeightRule`은 weight multiplier만 제공한다.
- 별도 rule이 없으면 multiplier는 `1.0`이다.
- 일반적으로 multiplier `0`은 금지한다.
- 위험 조합은 `0.001`, `0.005`, `0.01` 같은 epsilon multiplier로 제어한다.

## 7. MaterialSizeWeightRule 데이터 구조 초안

추천 신규 TSV:

- `data_tsv/block_material_size_weight_rules.tsv`

권장 Resource:

- `scripts/data/BlockMaterialSizeWeightRule.gd`

권장 컬럼:

| 컬럼 | 의미 |
| --- | --- |
| `rule_id` | rule 고유 id |
| `material_id` | 대상 material. 비우거나 `*`면 전체 material 기본값으로 사용 가능 |
| `size_id` | 가장 구체적인 size 지정 |
| `size_group` | size 그룹 지정 |
| `area_group` | area 그룹 지정 |
| `width_group` | width 그룹 지정 |
| `height_group` | height 그룹 지정 |
| `weight_multiplier` | 기본 궁합 multiplier |
| `normal_multiplier` | Normal difficulty 보정 |
| `hard_multiplier` | Hard difficulty 보정 |
| `extreme_multiplier` | Extreme difficulty 보정 |
| `hell_multiplier` | Hell difficulty 보정 |
| `nightmare_multiplier` | Nightmare difficulty 보정 |
| `day_1_5_multiplier` | Day 1~5 보정 |
| `day_6_10_multiplier` | Day 6~10 보정 |
| `day_11_15_multiplier` | Day 11~15 보정 |
| `day_16_20_multiplier` | Day 16~20 보정 |
| `day_21_25_multiplier` | Day 21~25 보정 |
| `day_26_30_multiplier` | Day 26~30 보정 |
| `min_day_hint` | hard lock이 아니라 밸런서 참고용 hint |
| `notes` | 설계 메모 |

우선순위:

| 우선순위 | Rule 형태 | 설명 |
| --- | --- | --- |
| 1 | `material_id + size_id` | 가장 구체적인 조합 rule |
| 2 | `material_id + size_group` | material별 size group 기본 rule |
| 3 | `material_id + area_group` | material별 area 계층 rule |
| 4 | `material_id + width_group` | material별 가로 압박 rule |
| 5 | `material_id + height_group` | material별 세로 압박 rule |
| 6 | `* + group` | 전역 그룹 보정 |
| 7 | no rule | multiplier `1.0` |

구체 rule이 여러 개 매칭될 수 있으므로 구현 시에는 “가장 구체적인 단일 rule 우선” 또는 “카테고리별 multiplier 곱셈” 중 하나를 명확히 결정해야 한다. 1차 구현은 디버깅이 쉬운 “가장 구체적인 단일 rule 우선, 없으면 그룹 rule”을 추천한다.

금지:

- `allowed_size_ids`
- `blocked_size_ids`
- `allowed_size_groups`
- `blocked_size_groups`
- 일반 스폰에서 material별 size hard block

## 8. Size group taxonomy 초안

전제:

- width 후보: 1~10U
- height 후보: 1~3U
- 일반 스폰 height 최대: 3U
- 중앙 전장 폭 기준: 10U
- `size_1x4` 같은 height 4U 이상은 일반 스폰 제외 및 마이그레이션 대상

그룹 정의:

| 그룹 | 기준 | 의미 |
| --- | --- | --- |
| `tiny` | `1x1` | 기본 단위 |
| `small` | area 2, 낮은 width pressure | 초반 기본 확장 |
| `medium` | area 3~4, 폭 압박 낮음 | 중반 핵심 |
| `wide_small` | width 3~4, height 1 | 회피 공간 압박 시작 |
| `wide_medium` | width 5~6 또는 width 4 height 2 | 넓은 회피 압박 |
| `wide_large` | width 7~8, height 1~2 | 일반 스폰 주의 |
| `tall_small` | height 2~3, width 1 | 처리 시간/공격 요구 증가 |
| `tall_medium` | height 3, width 2~3 | 세로 처리 요구 큼 |
| `large` | area 7~12 중 폭/높이 모두 의미 있음 | 후반 일반 후보 |
| `huge` | area 13~20 | 극저확률 또는 Hard 이상 중심 |
| `event_like` | width 9~10 또는 area 21 이상 | 무예고 일반 스폰 위험, 이벤트/telegraph 권장 |

목표 size 후보:

| size_id | W | H | Area | width_group | height_group | area_group | size_group | H pressure | V pressure | Normal policy | Hard+ policy | 일반 스폰 | Event/Boss/Gimmick | notes |
| --- | ---: | ---: | ---: | --- | --- | --- | --- | ---: | ---: | --- | --- | --- | --- | --- |
| `size_1x1` | 1 | 1 | 1 | `w1` | `h1` | `a1` | `tiny` | 0 | 0 | common | common | 적합 | 적합 | 기본 단위 |
| `size_1x2` | 1 | 2 | 2 | `w1` | `h2` | `a2_3` | `tall_small` | 0 | 1 | common | common | 적합 | 적합 | 현재 존재 |
| `size_1x3` | 1 | 3 | 3 | `w1` | `h3` | `a2_3` | `tall_small` | 0 | 2 | low early, ramp | common | 적합 | 적합 | 현재는 Hard lock, 목표는 weight ramp |
| `size_2x1` | 2 | 1 | 2 | `w2` | `h1` | `a2_3` | `small` | 1 | 0 | common | common | 적합 | 적합 | 현재 존재 |
| `size_2x2` | 2 | 2 | 4 | `w2` | `h2` | `a4_6` | `medium` | 1 | 1 | low early, ramp | common | 적합 | 적합 | 현재는 Hard lock |
| `size_2x3` | 2 | 3 | 6 | `w2` | `h3` | `a4_6` | `tall_medium` | 1 | 2 | epsilon early, ramp | common later | 적합 | 적합 | 세로 처리 요구 큼 |
| `size_3x1` | 3 | 1 | 3 | `w3_4` | `h1` | `a2_3` | `wide_small` | 2 | 0 | low early, ramp | common | 적합 | 적합 | 현재는 Hard lock |
| `size_3x2` | 3 | 2 | 6 | `w3_4` | `h2` | `a4_6` | `medium` | 2 | 1 | epsilon early, ramp | common later | 적합 | 적합 | 1차 구현 후보 |
| `size_3x3` | 3 | 3 | 9 | `w3_4` | `h3` | `a7_10` | `large` | 2 | 2 | epsilon | ramp later | 적합, 낮은 weight | 적합 | HP 요구 높음 |
| `size_4x1` | 4 | 1 | 4 | `w3_4` | `h1` | `a4_6` | `wide_small` | 3 | 0 | low early, ramp | common later | 적합 | 적합 | 현재 존재 |
| `size_4x2` | 4 | 2 | 8 | `w3_4` | `h2` | `a7_10` | `wide_medium` | 3 | 1 | epsilon | ramp later | 적합, 낮은 weight | 적합 | 폭 압박과 area 모두 증가 |
| `size_4x3` | 4 | 3 | 12 | `w3_4` | `h3` | `a11_15` | `large` | 3 | 2 | epsilon | low later | 주의 | 적합 | 후반 전용 성격 |
| `size_5x1` | 5 | 1 | 5 | `w5_6` | `h1` | `a4_6` | `wide_medium` | 4 | 0 | epsilon, telegraph 검토 | ramp | 적합, 낮은 weight | 적합 | 회피 공간 압박 큼 |
| `size_5x2` | 5 | 2 | 10 | `w5_6` | `h2` | `a7_10` | `large` | 4 | 1 | epsilon | low later | 주의 | 적합 | 보상/모래량 리스크 |
| `size_5x3` | 5 | 3 | 15 | `w5_6` | `h3` | `a11_15` | `huge` | 4 | 2 | epsilon only | low Hard+ | 매우 주의 | 적합 | 큰 HP 요구 |
| `size_6x1` | 6 | 1 | 6 | `w5_6` | `h1` | `a4_6` | `wide_medium` | 5 | 0 | epsilon, telegraph 검토 | ramp | 주의 | 적합 | 넓지만 낮은 area |
| `size_6x2` | 6 | 2 | 12 | `w5_6` | `h2` | `a11_15` | `large` | 5 | 1 | epsilon | low later | 주의 | 적합 | 회피/처리 압박 동시 발생 |
| `size_6x3` | 6 | 3 | 18 | `w5_6` | `h3` | `a16_20` | `huge` | 5 | 2 | epsilon only | very low | 매우 주의 | 적합 | 일반 무예고 위험 |
| `size_7x1` | 7 | 1 | 7 | `w7_8` | `h1` | `a7_10` | `wide_large` | 6 | 0 | epsilon only | low Hard+ | 매우 주의 | 적합 | 전장 절반 이상 압박 |
| `size_7x2` | 7 | 2 | 14 | `w7_8` | `h2` | `a11_15` | `huge` | 6 | 1 | epsilon only | very low | 매우 주의 | 적합 | gold/bomb/glass 위험 |
| `size_7x3` | 7 | 3 | 21 | `w7_8` | `h3` | `a21_30` | `event_like` | 6 | 2 | event/epsilon | event/telegraph | 일반 비추천 | 적합 | telegraph 권장 |
| `size_8x1` | 8 | 1 | 8 | `w7_8` | `h1` | `a7_10` | `wide_large` | 7 | 0 | epsilon only | very low | 매우 주의 | 적합 | 이동 경로 차단 리스크 |
| `size_8x2` | 8 | 2 | 16 | `w7_8` | `h2` | `a16_20` | `huge` | 7 | 1 | event/epsilon | very low | 일반 비추천 | 적합 | 보상/모래량 리스크 큼 |
| `size_8x3` | 8 | 3 | 24 | `w7_8` | `h3` | `a21_30` | `event_like` | 7 | 2 | event only | event/telegraph | 일반 비추천 | 적합 | 특수 스폰 성격 |
| `size_9x1` | 9 | 1 | 9 | `w9_10` | `h1` | `a7_10` | `event_like` | 8 | 0 | event/epsilon | event/telegraph | 일반 비추천 | 적합 | 10U 전장 기준 거의 봉쇄 |
| `size_9x2` | 9 | 2 | 18 | `w9_10` | `h2` | `a16_20` | `event_like` | 8 | 1 | event only | event/telegraph | 일반 비추천 | 적합 | 무예고 스폰 금지 권장 |
| `size_9x3` | 9 | 3 | 27 | `w9_10` | `h3` | `a21_30` | `event_like` | 8 | 2 | event only | event/telegraph | 일반 비추천 | 적합 | boss/gimmick 후보 |
| `size_10x1` | 10 | 1 | 10 | `w9_10` | `h1` | `a7_10` | `event_like` | 9 | 0 | event/epsilon | event/telegraph | 일반 비추천 | 적합 | 중앙 전장 전체 폭 |
| `size_10x2` | 10 | 2 | 20 | `w9_10` | `h2` | `a16_20` | `event_like` | 9 | 1 | event only | event/telegraph | 일반 비추천 | 적합 | clear lane/예고 필요 |
| `size_10x3` | 10 | 3 | 30 | `w9_10` | `h3` | `a21_30` | `event_like` | 9 | 2 | event only | event/telegraph | 일반 비추천 | 적합 | 일반 스폰보다는 기믹 |

1차 구현 추천 size:

- `size_1x1`
- `size_1x2`
- `size_2x1`
- `size_2x2`
- `size_1x3`
- `size_3x1`
- `size_3x2`
- `size_2x3`
- `size_4x1`
- `size_4x2`
- `size_5x1`
- `size_6x1`

후보로 유지:

- `size_3x3`
- `size_4x3`
- `size_5x2`
- `size_5x3`
- `size_6x2`
- `size_6x3`
- `size_7x1`
- `size_7x2`
- `size_8x1`

이벤트/보스/기믹 우선:

- `size_7x3`
- `size_8x2`
- `size_8x3`
- `size_9x1`
- `size_9x2`
- `size_9x3`
- `size_10x1`
- `size_10x2`
- `size_10x3`

제거/비추천/마이그레이션 대상:

- `size_1x4`: height 4U라서 일반 스폰 최대 3U 전제와 맞지 않는다. 필요하면 특수 기믹 전용으로 분리한다.

## 9. Material별 weight policy 초안

모든 material은 모든 size로 등장 가능해야 한다. 아래 값은 hard block이 아니라 `MaterialSizeWeightRule`의 초기 multiplier 초안이다. 실제 수치는 구현 전 Monte Carlo로 검증해야 한다.

| material | small/tiny | medium | wide | tall | large | huge | event_like | 특수 주의 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| `wood` | 1.00 | 1.00 | 1.00 | 0.90 | 0.45 | 0.12 | 0.02 | 넓은 목재는 자연스럽지만 초대형은 낮게 유지 |
| `rock` | 1.00 | 0.95 | 0.75 | 0.90 | 0.55 | 0.18 | 0.03 | 중대형 허용, 폭 압박은 wood보다 낮춤 |
| `marble` | 1.00 | 1.05 | 0.65 | 0.75 | 0.35 | 0.10 | 0.02 | medium 중심, huge는 낮게 |
| `cement` | 0.90 | 1.00 | 1.10 | 0.90 | 0.75 | 0.25 | 0.05 | wide/large 허용 가능 |
| `steel` | 0.80 | 1.00 | 1.30 | 0.65 | 0.90 | 0.35 | 0.08 | wide 계열 선호 가능, tall은 낮춤 |
| `bomb` | 0.80 | 0.15 | 0.08 | 0.10 | 0.03 | 0.005 | 0.001 | 대형 폭탄은 금지하지 않되 극저확률/이벤트성 |
| `glass` | 1.00 | 0.80 | 0.45 | 0.45 | 0.15 | 0.02 | 0.005 | shatter 위험 때문에 큰 size 낮춤 |
| `gold` | 1.00 | 0.45 | 0.12 | 0.18 | 0.05 | 0.005 | 0.001 | reward 폭증 때문에 대형은 극저확률 |

주의:

- 위 값에 `BlockSizeSpawnRule`의 Day/difficulty multiplier가 추가로 곱해진다.
- Normal 초반에는 huge/event_like size 자체가 epsilon weight이므로, `gold + huge`는 더 낮아진다.
- multiplier는 0이 아니므로 모든 조합은 이론상 가능하다.

## 10. BlockSizeSpawnRule과 MaterialSizeWeightRule 계산 순서

권장 계산식:

```text
final_material_weight =
  material.base_spawn_weight
  x material_day_multiplier
  x material_difficulty_multiplier
  x optional_stage_material_multiplier

final_size_weight =
  size.base_spawn_weight
  x size_spawn_rule.day_multiplier
  x size_spawn_rule.difficulty_multiplier
  x material_size_weight_multiplier
  x optional_stage_size_multiplier
```

흐름:

1. `final_material_weight`로 Material을 먼저 roll한다.
2. 선택된 Material은 Size 후보를 제거하지 않는다.
3. 전역 Size pool에서 물리/규칙상 불가능한 size만 제거한다.
4. 각 Size에 대해 `final_size_weight`를 계산한다.
5. 최종 Size를 roll한다.

이 구조는 Material 등장률과 Size 압박 곡선을 분리한다. `steel`이 wide를 선호하더라도 wide size 자체가 Normal Day 1~5에서 epsilon이면 실제 등장률은 낮다. 반대로 Hard 후반에는 Size rule이 wide를 밀어주고, steel multiplier가 이를 더 강조한다.

## 11. Normal 난이도 억까 방지 방식

Normal에서도 모든 size는 등장 가능해야 하지만, 등장 가능과 높은 확률 등장은 다르다. Normal 억까 방지는 다음 장치를 조합한다.

| 장치 | 설명 |
| --- | --- |
| 대형 width epsilon weight | `wide_large`, `huge`, `event_like`는 Normal 초반에 `0.001~0.01` 수준으로 둔다. |
| Day band ramp-up | Day 1~5, 6~10, 11~15, 16~20, 21~25, 26~30 구간별로 큰 size multiplier를 천천히 올린다. |
| active wide cooldown | 넓은 block이 화면에 존재하는 동안 추가 wide spawn weight를 낮춘다. |
| 최근 N회 wide 제한 | 최근 N회 spawn에 wide block이 많으면 wide group multiplier를 낮춘다. |
| width pressure budget | 일정 시간 또는 화면 단위로 누적 horizontal pressure 상한을 둔다. |
| area pressure budget | HP/reward/sand 폭증을 막기 위해 area 누적 상한을 둔다. |
| telegraph/event group 분리 | `event_like` size는 일반 무예고 스폰이 아니라 예고, clear lane, 이벤트 스폰으로 분리한다. |
| 10U 폭 size 안전장치 | 중앙 전장 전체를 막을 수 있으므로 무예고 일반 스폰은 비추천한다. 사용 시 예고와 escape timing이 필요하다. |

Normal용 정책 예시:

| Size group | Day 1~5 | Day 6~10 | Day 11~15 | Day 16~20 | Day 21~30 |
| --- | ---: | ---: | ---: | ---: | ---: |
| `tiny/small` | 1.00 | 1.00 | 0.90 | 0.80 | 0.70 |
| `medium` | 0.15 | 0.40 | 0.75 | 1.00 | 1.00 |
| `wide_small` | 0.03 | 0.12 | 0.35 | 0.65 | 0.90 |
| `wide_medium` | 0.005 | 0.02 | 0.08 | 0.18 | 0.35 |
| `wide_large` | 0.001 | 0.003 | 0.008 | 0.02 | 0.05 |
| `huge` | 0.001 | 0.001 | 0.003 | 0.008 | 0.02 |
| `event_like` | 0.001 | 0.001 | 0.001 | 0.003 | 0.005 |

이 표는 구조 예시이며 밸런스 확정값이 아니다.

## 12. 기존 max_allowed_* 필드 처리 방안

| 방안 | 설명 | 장점 | 단점 | 추천 |
| --- | --- | --- | --- | --- |
| A. 즉시 제거 | Resource, TSV, importer/exporter, runtime에서 바로 삭제 | 모델이 깔끔해짐 | 현재 데이터 파이프라인과 스냅샷이 크게 흔들림 | 비추천 |
| B. 필드는 남기되 런타임에서 무시하고 deprecated 처리 | 기존 TSV 호환을 유지하며 resolver v2에서는 사용하지 않음 | 안전한 전환 가능 | 사용자가 값이 적용된다고 오해할 수 있음 | 1차 추천 |
| C. import/export에서는 유지하되 값은 무시 | Google Sheets 호환 전환 기간 확보 | bat 워크플로우가 덜 깨짐 | legacy 컬럼이 남아 혼란 | B와 함께 단기 추천 |
| D. 마이그레이션 후 제거 | v2 검증 후 Resource/TSV/schema에서 삭제 | 최종 구조가 깔끔함 | 선행 검증 필요 | 최종 추천 |

추천 순서:

1. 새 rule TSV와 시뮬레이션 리포트부터 추가한다.
2. resolver v2에서 `max_allowed_*`를 regular random spawn에 사용하지 않는다.
3. 기존 resolver와 v2 resolver 분포 비교를 통과한다.
4. `block_materials.tsv`의 `max_allowed_*`를 deprecated column으로 표시한다.
5. 충분히 검증되면 TSV/schema/resource에서 제거한다.

즉, `max_allowed_area/width/height`는 즉시 삭제보다 “deprecated 후 무시, 이후 제거”가 안전하다.

## 13. TSV / Google Sheets 구조 제안

추천 파일 구조:

| TSV | 책임 |
| --- | --- |
| `data_tsv/block_materials.tsv` | Material 기본값. 장기적으로 size 제한 컬럼 제거 |
| `data_tsv/block_sizes.tsv` | Size 물리값과 기본 배율. group/pressure 컬럼 추가 후보 |
| `data_tsv/block_size_spawn_rules.tsv` | Day/difficulty별 size 등장 확률과 ramp-up |
| `data_tsv/block_material_size_weight_rules.tsv` | Material x Size/Group 궁합 multiplier |
| `data_tsv/block_types.tsv` | Optional Type/Affix 기본값 |
| `data_tsv/stage_days.tsv` | Day별 HP/spawn tempo/boss specific data |

`block_sizes.tsv` 권장 추가 컬럼:

- `sand_multiplier`
- `horizontal_pressure_score`
- `vertical_pressure_score`
- `width_group`
- `height_group`
- `area_group`
- `size_group`
- `general_spawn_policy`
- `event_spawn_policy`

`block_size_spawn_rules.tsv` 권장 컬럼:

- `size_id`
- `size_group`
- `base_spawn_weight`
- `normal_multiplier`
- `hard_multiplier`
- `extreme_multiplier`
- `hell_multiplier`
- `nightmare_multiplier`
- `day_1_5_multiplier`
- `day_6_10_multiplier`
- `day_11_15_multiplier`
- `day_16_20_multiplier`
- `day_21_25_multiplier`
- `day_26_30_multiplier`
- `min_day_hint`
- `notes`

`block_material_size_weight_rules.tsv`는 앞의 7번 구조를 따른다.

## 14. BlockSpawnResolver 변경 초안

실제 구현은 하지 않았지만, 책임 분리는 아래처럼 가는 것이 좋다.

| 함수 | 책임 |
| --- | --- |
| `get_valid_material_candidates(day, difficulty)` | material enabled와 material spawn policy 기준 후보 수집 |
| `apply_material_spawn_modifiers(materials, day, difficulty)` | material Day/difficulty weight 보정 |
| `roll_material(candidates, rng)` | Material roll |
| `get_all_size_candidates(day, difficulty)` | 전역 hard rule만 적용한 Size pool 반환 |
| `apply_size_spawn_rules(size_candidates, day, difficulty)` | Day/difficulty별 size weight 계산 |
| `apply_material_size_weight_rules(material, size_candidates, day, difficulty)` | 선택 Material과 Size 궁합 multiplier 적용 |
| `apply_pressure_safety_modifiers(size_candidates, spawn_context)` | wide cooldown, recent spawn, pressure budget 적용 |
| `roll_size(weighted_size_candidates, rng)` | Size roll |
| `roll_optional_type(day, difficulty, material, size)` | Optional Type roll |
| `resolve_block(material, size, type, day, difficulty)` | final HP/reward/sand 계산 |

중요:

- `get_all_size_candidates()`는 material gate로 size를 제거하지 않는다.
- `width > center_play_width`, `height > general_spawn_max_height` 같은 전역 규칙만 필터링한다.
- `resolve_specific_block()`은 일반 random spawn policy와 분리해야 한다. 보스/이벤트는 특정 조합을 안전하게 resolve할 수 있어야 한다.

## 15. HP / reward / sand 계산과 새 구조의 관계

현재 `BlockSpawnResolver._build_resolved_definition()` 기준:

```text
final_hp =
  BLOCK_HP_PER_UNIT
  x size.hp_multiplier
  x material.hp_multiplier
  x difficulty.block_hp_multiplier
  x type.hp_multiplier
  x day_hp_multiplier

final_reward =
  BLOCK_REWARD_PER_UNIT
  x size.reward_multiplier
  x material.reward_multiplier
  x type.reward_multiplier

final_sand_units =
  BLOCK_SAND_UNITS_PER_UNIT
  x size.reward_multiplier
  x type.sand_units_multiplier
```

새 Spawn Pool 구조는 “무엇이 얼마나 자주 나오나”를 바꾸는 설계이고, final 수치 계산식을 직접 바꾸는 설계가 아니다. 다만 width 1~10, height 1~3 확장 후에는 area가 커지면서 HP/reward/sand 최대치가 커지므로 다음 리포트가 필요하다.

- HP maximum risk report
- reward maximum risk report
- sand maximum risk report
- material-size pair별 expected value report

특히 `gold + huge`, `bomb + huge`, `glass + wide_large`, `steel + huge`는 multiplier가 낮더라도 실제로 나왔을 때의 위험이 크므로 별도 검증이 필요하다.

## 16. 회귀 위험 분석

| 위험 | 설명 | 대응 |
| --- | --- | --- |
| material 분포 변화 | 1단계 material roll로 기존 pair-roll 기반 material 확률이 바뀔 수 있음 | 기존 vs v2 material distribution 비교 |
| size 분포 변화 | Size pool이 material gate 없이 넓어져 큰 size 비율이 늘 수 있음 | size spawn rule ramp와 pressure budget |
| pair 분포 변화 | `material x size` 조합 확률이 크게 달라짐 | pair distribution simulation |
| `gold + huge` reward 폭증 | 낮은 확률이어도 reward spike가 큼 | epsilon multiplier와 reward risk report |
| `bomb + huge` 폭발 리스크 | 폭탄 효과 범위/피해가 size와 만나 과해질 수 있음 | event_like 분리, telegraph, special regression |
| `glass + wide_large` shatter 리스크 | 넓은 유리가 무작위 피해를 과하게 만들 수 있음 | low multiplier, active pressure budget |
| wide block 억까 | width 7~10은 이동 경로를 막을 수 있음 | cooldown, recent N 제한, telegraph |
| 10U block 전장 봉쇄 | 중앙 전장 전체 폭을 차지함 | 일반 무예고 스폰 비추천, 이벤트/보스 우선 |
| `balance_snapshot` 변화 | 현재 snapshot은 기존 `get_spawn_candidates()`에 의존 | v1/v2 snapshot 병렬 출력 |
| 보스 resolve 영향 | 기존 specific resolve도 gate를 타므로 정책 변경 시 boss 영향 가능 | random spawn resolver와 specific resolver 분리 |

## 17. 구현 전 검증 계획

필수 검증 리포트:

| 리포트 | 목적 |
| --- | --- |
| material distribution simulation | Day/difficulty별 material 등장률 확인 |
| size distribution simulation | Day/difficulty별 size 등장률 확인 |
| material-size pair distribution simulation | 위험 조합 실제 확률 확인 |
| difficulty별 distribution simulation | Hard 이상에서 큰 size 상승 시점 확인 |
| Day band별 distribution simulation | Normal 후반 ramp-up 확인 |
| width pressure distribution | 넓은 block 누적 압박 확인 |
| area pressure distribution | HP/reward/sand 폭증 위험 확인 |
| HP/reward/sand maximum risk report | 최악 조합 수치 확인 |
| 10,000회 Monte Carlo spawn report | 실제 random 흐름 근사 검증 |
| 기존 방식 vs 신규 방식 비교 report | 분포 변화량 확인 |
| `balance_snapshot` 확장 | v1/v2 결과와 핵심 수치 회귀 확인 |

검증 기준:

- Normal Day 1~5에서 wide_large/huge/event_like의 실효 등장률이 극저확률이어야 한다.
- Normal 후반에는 모든 size가 가능하지만 wide pressure가 연속으로 몰리지 않아야 한다.
- Hard 이상에서는 large/huge 등장률이 Normal보다 빠르고 높아야 한다.
- `gold + huge`, `bomb + huge`, `glass + huge`는 가능하지만 매우 낮은 확률이어야 한다.
- 10U width는 일반 무예고 스폰보다 이벤트/telegraph 그룹으로 관리되어야 한다.

## 18. 최종 권장안

권장 결론:

| 항목 | 추천 |
| --- | --- |
| `max_allowed_area/width/height` 처리 | 즉시 제거하지 말고 deprecated 후 resolver v2에서 무시, 검증 후 삭제 |
| `block_size_spawn_rules.tsv` | 추가 권장 |
| `block_material_size_weight_rules.tsv` | 추가 권장 |
| Material gate | 일반 스폰에서 size hard block 금지 |
| 위험 조합 | epsilon multiplier와 event/telegraph policy로 제어 |
| Size 범위 | width 1~10, height 1~3 |
| height 4U 이상 | 일반 스폰 제외, 기존 `size_1x4`는 마이그레이션 대상 |
| 구현 방식 | resolver v2 또는 feature flag로 기존 분포와 병렬 비교 |

권장 구현 순서:

1. `block_size_spawn_rules.tsv`와 `block_material_size_weight_rules.tsv`의 스키마 초안을 추가한다.
2. 기존 resolver를 바꾸기 전에 distribution simulation tool을 추가한다.
3. `BlockSizeSpawnRule`과 `MaterialSizeWeightRule` Resource를 추가한다.
4. `BlockSpawnResolver` v2를 기존 random spawn과 병렬로 돌릴 수 있게 만든다.
5. v1/v2 Monte Carlo 리포트로 material, size, pair 분포를 비교한다.
6. wide pressure budget과 recent wide cooldown을 검증한다.
7. regular random spawn에서 `max_allowed_*`를 무시하도록 전환한다.
8. 충분히 검증되면 `max_allowed_*` TSV/schema/resource 필드를 제거한다.

바로 구현해도 되는 범위:

- 신규 TSV 스키마 초안
- 신규 Resource 정의 초안
- v1/v2 비교용 시뮬레이션 리포트
- `balance_snapshot` 확장

아직 바로 라이브 전환하면 안 되는 범위:

- 기존 `get_spawn_candidates()`를 즉시 v2로 교체
- `max_allowed_*` 필드 즉시 삭제
- 큰 size를 실제 `.tres`에 대량 추가하고 실스폰에 반영

결론적으로, 다음 구현 작업으로 넘어갈 수는 있다. 다만 첫 구현 목표는 실제 스폰 동작 변경이 아니라 “v2 데이터 구조 + 시뮬레이션 + 비교 스냅샷”이어야 한다. 라이브 resolver 전환은 위험 조합 확률과 Normal 억까 방지가 수치로 확인된 뒤 진행하는 것이 안전하다.
