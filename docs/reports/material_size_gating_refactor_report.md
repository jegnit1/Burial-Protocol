# Block Material Size Gating Refactor Impact Report

작성일: 2026-04-30

범위: 영향 분석 리포트만 작성했다. 코드, `.tres`, TSV, 밸런스 수치는 수정하지 않았다.

참고 리포트:

- `docs/reports/block_catalog_material_size_type_audit.md`
- `docs/reports/size_spawn_rule_design.md`

핵심 결론:

- `max_allowed_area`는 현재 material-size 조합을 실제로 차단한다.
- 하지만 `max_allowed_area`만 제거해도 width 5U~10U 확장은 열리지 않는다. 현재 모든 material의 `max_allowed_width`가 4 이하이기 때문이다.
- 장기 구조에서는 `max_allowed_area`를 제거하고, 절대 금지 조합은 `max_allowed_width/max_allowed_height`와 `allowed/blocked size group`으로 표현하는 쪽을 추천한다.

## 1. max_allowed_area 정의/사용처

| 파일 | 함수/필드 | 역할 | runtime 사용 여부 | TSV import/export 연결 | 제거 시 영향 |
|---|---|---|---|---|---|
| `scripts/data/BlockMaterialData.gd` | `@export var max_allowed_area` | material이 허용하는 최대 size area | 직접 사용은 아니지만 Resource 필드로 로드됨 | TSV import/export 대상 | 필드 제거 시 `.tres`, TSV schema, importer/exporter 수정 필요 |
| `data/blocks/BlockCatalog.tres` | 각 material subresource의 `max_allowed_area` | 현재 material별 gate 데이터 | runtime data source | export 시 TSV로 나감 | 값 제거/0 처리 시 후보 size 증가 |
| `data_tsv/block_materials.tsv` | `max_allowed_area` column | 사람이 편집하는 material gate 원본 | convert 후 runtime 반영 | import/export 모두 연결 | column 제거 시 schema/import/export/validation 변경 필요 |
| `scripts/data/BlockCatalog.gd` | `is_material_size_allowed()` | `size_area > material.max_allowed_area`면 후보 차단 | 예. 일반 스폰과 specific resolve 모두 영향 | 간접 | 제거 시 `get_spawn_candidates()`와 boss/specific resolve 허용 범위 변경 |
| `scripts/data/BlockCatalog.gd` | `get_spawn_candidates()` | 모든 Material x Size 후보 생성 중 gate 적용 | 예. 일반 블록 스폰 후보 결정 | 간접 | 일반 스폰 distribution 변경 |
| `scripts/data/BlockSpawnResolver.gd` | `resolve_random_block()` | `get_spawn_candidates()` 결과 사용 | 예 | 간접 | 일반 스폰 후보/분포 변경 |
| `scripts/data/BlockSpawnResolver.gd` | `resolve_specific_block()` | `is_material_size_allowed()`로 명시 조합 검증 | 예. boss block에도 영향 | 간접 | boss/specific block이 더 많이 허용될 수 있음 |
| `scripts/tools/data_pipeline/TsvSchema.gd` | `BLOCK_MATERIAL_HEADERS` | TSV header 정의 | runtime 아님 | 직접 | column 제거 시 schema 변경 필요 |
| `scripts/tools/data_pipeline/BlockDataImporter.gd` | material import assignment | TSV 값을 Resource에 입력 | runtime 전 단계 | 직접 | importer 수정 필요 |
| `scripts/tools/data_pipeline/TsvExportService.gd` | `_build_block_material_rows()` | Resource 값을 TSV로 export | runtime 아님 | 직접 | exporter 수정 필요 |
| `scripts/tools/data_pipeline/TsvValidationService.gd` | `validate_block_catalog()` | required int 검증 | runtime 아님 | 직접 | validation 수정 필요 |
| `scripts/tests/balance_snapshot.gd` | `catalog.get_spawn_candidates()` 사용 | spawn candidate 기반 snapshot | 간접 | 간접 | snapshot 결과 변경 가능 |

`BlockBaseDefinition.gd`, `BlockSizeData.gd`, `BlockResolvedDefinition.gd`, `BlockData.gd`는 `max_allowed_area`를 직접 사용하지 않는다. `BlockBaseDefinition.gd`는 `BlockMaterialData.gd`를 상속하는 호환 alias이므로 필드 영향권에 포함된다.

## 2. 현재 Material Gating 표

아래 표는 현재 `data_tsv/block_sizes.tsv`에 존재하는 size만 기준으로, day/difficulty hard lock은 제외하고 material gate만 본 결과다.

| material_id | display_name | max_area | max_width | max_height | 현재 허용 size | 현재 차단 size | 주 차단 사유 |
|---|---|---:|---:|---:|---|---|---|
| `wood` | 나무 | 4 | 2 | 4 | `1x1`, `1x2`, `2x1`, `2x2`, `1x3`, `1x4` | `3x1`, `4x1` | width > 2 |
| `rock` | 바위 | 4 | 2 | 3 | `1x1`, `1x2`, `2x1`, `2x2`, `1x3` | `3x1`, `1x4`, `4x1` | width > 2 또는 height > 3 |
| `marble` | 대리석 | 4 | 2 | 2 | `1x1`, `1x2`, `2x1`, `2x2` | `1x3`, `3x1`, `1x4`, `4x1` | width > 2 또는 height > 2 |
| `cement` | 시멘트 | 4 | 2 | 4 | `1x1`, `1x2`, `2x1`, `2x2`, `1x3`, `1x4` | `3x1`, `4x1` | width > 2 |
| `steel` | 강철 | 4 | 4 | 2 | `1x1`, `1x2`, `2x1`, `2x2`, `3x1`, `4x1` | `1x3`, `1x4` | height > 2 |
| `bomb` | 폭탄 | 1 | 1 | 1 | `1x1` | `1x2`, `2x1`, `2x2`, `1x3`, `3x1`, `1x4`, `4x1` | area/width/height 모두 제한 |
| `glass` | 유리 | 4 | 2 | 2 | `1x1`, `1x2`, `2x1`, `2x2` | `1x3`, `3x1`, `1x4`, `4x1` | width > 2 또는 height > 2 |
| `gold` | 황금 | 2 | 2 | 2 | `1x1`, `1x2`, `2x1` | `2x2`, `1x3`, `3x1`, `1x4`, `4x1` | area > 2, 일부 width/height도 초과 |

현재 존재 size만 보면 `max_allowed_area` 단독으로 막는 대표 사례는 `gold -> size_2x2`다. 대부분은 width/height 제한도 같이 작동한다.

## 3. 목표 Size 후보군 기준 Matrix

목표 후보군은 `size_{width}x{height}`, width 1~10, height 1~3, 총 30개다.

### Material별 허용 변화 요약

| material | 현재 gate 허용 | `max_allowed_area`만 제거 시 추가 허용 | width/height까지 제거 시 | 계속 제한해야 할 size | 제한 사유 |
|---|---|---|---|---|---|
| `wood` | `1x1`, `2x1`, `1x2`, `2x2`, `1x3` | `2x3` | 전체 30개 | `7x1+`, `5x2+`, `4x3+`는 rare/event 권장 | 넓은 목재는 가능하지만 전장 봉쇄 위험 |
| `rock` | `1x1`, `2x1`, `1x2`, `2x2`, `1x3` | `2x3` | 전체 30개 | `7x1+`, `6x2+`, `4x3+`는 제한 권장 | 무거운 암석 대형화는 HP/모래 압박 큼 |
| `marble` | `1x1`, `2x1`, `1x2`, `2x2` | 없음 | 전체 30개 | wide/large 대부분 제한 | 중형 고급 material 성격, 큰 면적은 HP 요구 과다 |
| `cement` | `1x1`, `2x1`, `1x2`, `2x2`, `1x3` | `2x3` | 전체 30개 | `8x1+`, `6x2+`, `5x3+`는 event/rare | 중대형 허용 가능하나 wall 압박 관리 필요 |
| `steel` | `1x1`, `2x1`, `3x1`, `4x1`, `1x2`, `2x2` | `3x2`, `4x2` | 전체 30개 | height 3 대형, width 9~10 제한 | 넓은 steel slab는 컨셉상 가능, height는 과도한 HP 위험 |
| `bomb` | `1x1` | 없음 | 전체 30개 | `1x1` 외 전부 | 폭발 특수 결과 때문에 대형 bomb은 별도 기믹 전용 |
| `glass` | `1x1`, `2x1`, `1x2`, `2x2` | 없음 | 전체 30개 | wide_large, area 6+ 제한 | `glass_shatter_damage`가 대형화되면 억까 위험 |
| `gold` | `1x1`, `2x1`, `1x2` | `2x2` | 전체 30개 | area 4+ 대부분 제한 | reward_multiplier 2.5와 bonus gold 위험 |

### `max_allowed_area`만 제거했을 때 새로 열리는 size

| material | 새로 허용되는 size | 비고 |
|---|---|---|
| `wood` | `size_2x3` | width 2, height 3은 width/height gate를 통과하지만 area 6이라 현재 차단 |
| `rock` | `size_2x3` | 동일 |
| `marble` | 없음 | width 2, height 2 제한이 area 제거 효과를 흡수 |
| `cement` | `size_2x3` | 동일 |
| `steel` | `size_3x2`, `size_4x2` | steel의 width 4, height 2 의도와 맞지만 area 6/8 때문에 현재 차단 |
| `bomb` | 없음 | width 1, height 1이 그대로 1x1만 허용 |
| `glass` | 없음 | width 2, height 2 제한이 area 제거 효과를 흡수 |
| `gold` | `size_2x2` | area 4라 현재 차단. reward 폭증 리스크 있음 |

### 폭 5U~10U 관점

`max_allowed_area` 제거만으로 width 5U~10U가 허용되는 material은 없다.

| material | area 제거 후에도 width 5~10이 막히는 이유 |
|---|---|
| `wood`, `rock`, `marble`, `cement`, `glass`, `gold` | `max_allowed_width = 2` |
| `steel` | `max_allowed_width = 4` |
| `bomb` | `max_allowed_width = 1` |

따라서 width 1~10 확장 목표를 실제로 달성하려면 `max_allowed_width`도 material별로 재설계해야 한다.

### height 3U 관점

| material | 현재 height 3 허용 여부 | area 제거 후 | 비고 |
|---|---|---|---|
| `wood` | `1x3`만 허용 | `2x3` 추가 | max_height 4라 target height 3과 충돌 없음. 다만 height 4는 목표에서 제외해야 함 |
| `rock` | `1x3`만 허용 | `2x3` 추가 | max_height 3은 목표와 잘 맞음 |
| `marble` | 차단 | 차단 | max_height 2 재검토 필요 |
| `cement` | `1x3`만 허용 | `2x3` 추가 | max_height 4를 3으로 낮추는 편이 목표와 맞음 |
| `steel` | 차단 | 차단 | steel은 height 2 제한 유지 가능 |
| `bomb` | 차단 | 차단 | 유지 |
| `glass` | 차단 | 차단 | `glass_shatter_damage` 때문에 유지 또는 group 제한 권장 |
| `gold` | 차단 | 차단 | 보상 리스크 때문에 유지 권장 |

## 4. max_allowed_area 제거 영향

### 제거만으로 해결되는 것

- area 6인 `2x3`이 `wood`, `rock`, `cement`에서 열릴 수 있다.
- area 6/8인 `3x2`, `4x2`가 `steel`에서 열릴 수 있다.
- area 4인 `2x2`가 `gold`에서 열릴 수 있다.

### 제거만으로 해결되지 않는 것

- width 5~10 size 확장.
- marble/glass/gold/bomb의 height 3 확장.
- material별 "wide는 되지만 tall은 안 됨", "small gold만 허용" 같은 섬세한 정책.

### 폭증 위험

현재 size 공식은 area가 HP, reward, sand에 직접 영향을 준다. area 30인 `size_10x3`이 아무 material에나 허용되면 기본 난이도/day/type 전에도 아래 수준이 된다.

| material | material_hp | reward_mult | area 30 기본 HP | 기본 reward | sand units | 주요 위험 |
|---|---:|---:|---:|---:|---:|---|
| `wood` | 1.0 | 1.0 | 300 | 150 | 1080 | 초대형이 너무 자주 나오면 전장 봉쇄 |
| `rock` | 1.5 | 1.0 | 450 | 150 | 1080 | 초반/중반 처리 시간 폭증 |
| `marble` | 2.0 | 1.0 | 600 | 150 | 1080 | 중형 material 컨셉 붕괴 |
| `cement` | 3.0 | 1.0 | 900 | 150 | 1080 | 장시간 막힘/모래 압박 |
| `steel` | 5.0 | 1.0 | 1500 | 150 | 1080 | Day/difficulty 곱 적용 시 극단적 HP |
| `bomb` | 2.0 | 1.0 | 600 | 150 | 1080 | 대형 폭발 특수 결과는 치명적 억까 가능 |
| `glass` | 1.0 | 1.0 | 300 | 150 | 1080 | 대형 shatter damage 위험 |
| `gold` | 3.0 | 2.5 | 900 | 375 | 1080 | 보상/bonus gold 경제 붕괴 |

위 값에는 difficulty, day, boss type 배율이 포함되지 않는다. 실제 후반/고난이도에서는 훨씬 커진다.

## 5. 대체 구조 후보 비교

| 후보 | 설명 | 장점 | 단점 | TSV/Sheets 난이도 | 런타임 난이도 | 튜닝 편의성 | 특수 material 적합성 | 추천 |
|---|---|---|---|---|---|---|---|---|
| A | `max_allowed_width`, `max_allowed_height`만 유지 | 단순함. width/height 의미 분리 | area 기반 보상/HP 리스크를 group으로 표현 못 함 | 낮음 | 낮음 | 보통 | bomb/gold 정밀 제어 부족 | 부분 추천 |
| B | `allowed_size_ids`, `blocked_size_ids` 추가 | 가장 정확함 | size가 많아질수록 TSV가 길고 취약 | 높음 | 중간 | 낮음 | bomb 같은 exact exception에 좋음 | 제한적 |
| C | `allowed_size_groups`, `blocked_size_groups` 추가 | size spawn rule의 group과 잘 맞음. 관리 쉬움 | group taxonomy 설계 필요 | 중간 | 중간 | 높음 | gold/glass/wide 제한에 좋음 | 추천 |
| D | `material_size_policy_id`와 별도 `material_size_policy.tsv` | 재사용 가능한 policy layer | 현재 material 수에는 다소 과함 | 중~높음 | 중~높음 | 높음 | 장기 확장에 좋음 | 2차 추천 |
| E | material gating 최소화, size spawn rule에 대부분 위임 | 확률 제어가 깔끔함 | 절대 불가능 조합을 막기 어려움 | 중간 | 낮~중간 | 높음 | bomb/gold/glass에 부적합 | 단독 비추천 |

실질 추천은 A+C 조합이다.

- `max_allowed_area`는 제거한다.
- `max_allowed_width`, `max_allowed_height`는 "물리/컨셉상 절대 상한"으로 유지한다.
- `allowed_size_groups`, `blocked_size_groups`를 추가해 material별 theme/special risk를 표현한다.
- bomb처럼 정확히 1x1만 허용해야 하는 material은 `allowed_size_ids` 같은 exact override도 보조로 고려한다.

최종 선택지 기준으로는 **B. max_allowed_area 제거 + allowed/blocked size group 추가**를 추천한다.

## 6. Material별 Size Policy 초안

| material | max_area 제거 | max_width 권장 | max_height 권장 | group 정책 | 특수 예외 | 추천 사유 |
|---|---|---:|---:|---|---|---|
| `wood` | 제거 | 6 | 3 | allow `small`, `medium`, `wide_1x`, `tall_safe`; block `arena_blocker`, `event_only` | 없음 | 목재는 넓은 plank 성격이 자연스럽고 저위험 |
| `rock` | 제거 | 5 | 3 | allow `small`, `medium`, `heavy_medium`; block `wide_extreme`, `area_16_plus` | 없음 | 중대형 가능하지만 너무 넓으면 회피 압박 큼 |
| `marble` | 제거 | 4 | 2 또는 3 | allow `small`, `medium`; block `wide_large`, `area_10_plus` | height 3 허용 여부는 simulation 후 결정 | 고급/단단한 중형 material 중심 |
| `cement` | 제거 | 6 | 3 | allow `small`, `medium`, `wide_medium`, `tall_safe`; block `arena_blocker` | 없음 | 중대형 구조물 성격에 잘 맞음 |
| `steel` | 제거 | 8 | 2 | allow `wide_medium`, `wide_large`; block `height_3_large`, `area_16_plus` | `4x2`, `5x1`, `6x1` 1차 후보 | 넓은 steel slab는 좋지만 height 3은 HP 과다 |
| `bomb` | 제거하되 exact gate로 대체 | 1 | 1 | allow only `exact_1x1` | `allowed_size_ids = size_1x1` 권장 | 폭발 특수 결과 때문에 대형화 금지 |
| `glass` | 제거 | 3 또는 4 | 2 | allow `small`, `medium`; block `wide_large`, `tall_3`, `area_6_plus` | shatter damage scaling 검증 전 대형 금지 | 대형 glass는 shatter 억까 위험 |
| `gold` | 제거하되 reward gate로 대체 | 2 | 2 | allow `reward_small`; block `area_4_plus` 또는 `gold_large` | `2x2`는 reward 재검증 후 선택 | reward 2.5와 bonus gold로 경제 붕괴 가능 |

주의: `wood`, `rock`, `cement`, `steel`의 width 확장은 size spawn rule의 low weight curve와 함께 들어가야 한다. gate만 먼저 넓히면 기존 조합 roll 방식에서 분포가 크게 바뀔 수 있다.

## 7. Size Spawn Rule과 책임 분리

| 시스템 | 책임 | 예시 |
|---|---|---|
| Material gating | 절대 불가능한 조합만 차단 | bomb은 1x1만, gold는 reward-large 차단, glass는 shatter-large 차단 |
| Size spawn rule | day/difficulty별 등장 확률 제어 | Normal 초반 6x1 epsilon, Hard 후반 4x2 상승 |
| StageTable | day별 HP/spawn tempo 제어 | `block_hp_multiplier`, `spawn_interval_multiplier`, boss material/size/type |
| Type/Affix | 특수 효과/보스/변형 제어 | boss hp multiplier, future modifier |

`max_allowed_area`는 "절대 불가능"과 "확률적으로 드물어야 함"을 섞어버린다. 새 구조에서는 area/width/height 압박은 size spawn rule의 group/weight가 담당하고, material gate는 special result나 material fantasy상 말이 안 되는 조합만 막는 것이 좋다.

## 8. 구현 전 검증 계획

| 검증 | 목적 | 권장 출력 |
|---|---|---|
| material별 허용 size coverage 리포트 | gate 변경 전후 material별 가능한 size 수 확인 | `docs/reports/material_size_gate_coverage.md` |
| 기존 gating vs 제거 후 gating matrix | `max_allowed_area` 제거의 정확한 영향 확인 | table + CSV/TSV snapshot |
| v1/v2 spawn distribution simulation | 조합 roll과 material-first/size-second roll 차이 확인 | `block_spawn_distribution_diff_v1_v2.md` |
| HP/reward/sand maximum risk report | material x size 최악값 산출 | material별 max HP/reward/sand |
| bomb/gold/glass regression | 특수 material 대형화 누수 확인 | special material allowlist 검증 |
| balance_snapshot 확장 | candidate count, allowed size count, max risk 포함 | JSON snapshot |
| 10,000회 Monte Carlo spawn 테스트 | 실제 roll에서 wide/large 빈도 확인 | day/difficulty별 distribution |

## 9. 마이그레이션 순서 제안

| 순서 | 작업 | 이유 |
|---:|---|---|
| 1 | 리포트 기반으로 target group taxonomy 확정 | group 이름이 먼저 안정되어야 TSV 설계 가능 |
| 2 | `block_size_spawn_rules.tsv` 설계 확정 | size 확률 제어를 material gate에서 분리 |
| 3 | material gate coverage simulation 추가 | 값을 바꾸기 전 영향 수치화 |
| 4 | `max_allowed_area`를 deprecated 취급하고 runtime에서 optional ignore flag로 비교 | 즉시 삭제보다 롤백 쉬움 |
| 5 | `allowed_size_groups`, `blocked_size_groups` 추가 | material별 absolute block 표현 |
| 6 | bomb/gold/glass exact policy 추가 | 특수 material 누수 방지 |
| 7 | material별 `max_allowed_width/height` 재조정 | width 5~10 목표 반영 |
| 8 | `max_allowed_area` column 제거 또는 legacy-only 전환 | 검증 후 정리 |

## 10. 최종 권장안

추천: **B. `max_allowed_area` 제거 + allowed/blocked size group 추가**.

단, 구현 형태는 아래처럼 잡는 것이 안전하다.

```text
Material gate:
  - max_allowed_width
  - max_allowed_height
  - allowed_size_groups
  - blocked_size_groups
  - optional allowed_size_ids / blocked_size_ids for exact special cases

Size spawn rule:
  - day/difficulty weight curve
  - width/height/area pressure groups
  - first_implementation / event_only classification
```

`max_allowed_area`만 제거하는 것은 충분하지 않다. width 5~10 확장은 여전히 `max_allowed_width`에 막히며, bomb/gold/glass 같은 material은 area 제거 후에도 별도 정책이 필요하다.

## 11. 바로 구현 가능 여부

바로 삭제 구현으로 들어가기는 이르다. 먼저 아래 두 가지를 선행하는 것이 좋다.

1. material gate coverage 리포트 자동화
2. size spawn rule TSV 초안과 group taxonomy 확정

그 다음 `max_allowed_area`를 즉시 삭제하기보다 deprecated/ignored mode로 두고, v1/v2 distribution을 비교한 뒤 제거하는 순서가 안전하다.
