# BlockCatalog Material / Size / Type Audit

작성일: 2026-04-30

범위: 구조 조사 리포트만 작성했다. 코드, `.tres`, TSV, 밸런스 수치는 수정하지 않았다.

판단 기준: 문서와 코드가 충돌하면 실행 가능한 코드와 현재 데이터(`data/blocks/BlockCatalog.tres`, `data/stages/StageTable.tres`)를 우선했다.

## 확인 대상

문서:

- `docs/00_project_rules.md`
- `docs/01_gdd.md`
- `docs/02_systems_spec.md`
- `docs/03_data_and_state_spec.md`
- `docs/04_roadmap.md`
- `docs/05_balance_formula.md`

코드/데이터:

- `data/blocks/BlockCatalog.tres`
- `data/stages/StageTable.tres`
- `scripts/autoload/GameData.gd`
- `scripts/data/BlockCatalog.gd`
- `scripts/data/BlockBaseDefinition.gd`
- `scripts/data/BlockMaterialData.gd`
- `scripts/data/BlockSizeData.gd`
- `scripts/data/BlockTypeDefinition.gd`
- `scripts/data/BlockSpawnResolver.gd`
- `scripts/data/BlockResolvedDefinition.gd`
- `scripts/data_models/BlockData.gd`
- `scenes/blocks/FallingBlock.gd`
- `scenes/main/Main.gd`
- `scenes/world/SandField.gd`
- `scenes/world/WorldGrid.gd`
- `scripts/tests/balance_snapshot.gd`
- `data_tsv/block_catalog_meta.tsv`
- `data_tsv/block_materials.tsv`
- `data_tsv/block_sizes.tsv`
- `data_tsv/block_types.tsv`
- `data_tsv/stage_days.tsv`
- `scripts/tools/data_pipeline/*`

## 결론 요약

현재 `BlockCatalog`는 저장 구조상 Material / Size / Type을 별도 배열로 분리한다. 다만 실제 일반 블록 스폰은 Material을 먼저 뽑고 Size를 따로 뽑는 독립 2단계 선택이 아니라, `Material x Size` 조합 후보를 만든 뒤 조합 weight로 한 번에 선택한다.

`base` 명칭은 아직 코드와 StageTable에 남아 있지만, 실행 의미는 대부분 Material alias다. `BlockBaseDefinition.gd`도 `BlockMaterialData.gd`를 상속하는 호환 shim이다.

## 1. BlockCatalog 전체 구조 요약

| 항목 | 현재 구조 | 판단 |
|---|---|---|
| Runtime 모델 | `BlockResolvedDefinition`이 `material_id`, `size_id`, `type_id`를 보유 | `Material x Size + optional Type` 표현 가능 |
| Material 저장 | `BlockCatalog.block_materials: Array[Resource]` | 분리됨 |
| Size 저장 | `BlockCatalog.block_sizes: Array[Resource]` | 분리됨 |
| Type 저장 | `BlockCatalog.block_types: Array[Resource]` | 분리됨 |
| 기본 material | `default_block_base_id = "glass"` | 이름은 base지만 의미는 material |
| 기본 size | `default_block_size_id = "size_1x1"` | 별도 관리 |
| Optional type | `random_type_chance = 0.0`; `boss.can_spawn_randomly = false` | 구조는 있으나 일반 랜덤 type은 현재 비활성 |
| Boss type | `StageTable`의 `boss_block_base_id`, `boss_block_size_id`, `boss_block_type_id` | 명시 조합으로 resolve |
| 현재 일반 스폰 | `get_spawn_candidates()`가 material-size 조합 후보 생성 | 독립 선택이 아니라 조합 선택 |
| 최종 데이터 | `BlockData.from_resolved_definition()` | 최종 HP, reward, sand, size pixel, color 등 런타임 소비 |

## 2. Material / Base 정의 표

Material에는 물리 크기(`width_u`, `height_u`, `area`)가 들어 있지 않다. 대신 `max_allowed_area`, `max_allowed_width`, `max_allowed_height`로 해당 material이 허용하는 size 범위를 제한한다. 이는 "크기 자체"가 섞인 것은 아니지만, material 쪽에 size gating 규칙이 들어 있는 상태다.

| material_id/base_id | display_name | hp_multiplier | reward_multiplier | spawn_weight | min_day / min_stage | min_difficulty | color / visual | special_result | size 정보 섞임 여부 |
|---|---:|---:|---:|---:|---|---|---|---|---|
| `wood` | 나무 | 1.0 | 1.0 | 1.0 | min_day 없음 / stage 1 | blank(any) | `amber`, `#9a6d43ff` | `none` | 물리 size 없음, max area 4 / w 2 / h 4 제한 있음 |
| `rock` | 바위 | 1.5 | 1.0 | 1.0 | min_day 없음 / stage 4 | blank(any) | `cobalt`, `#7d8591ff` | `none` | 물리 size 없음, max area 4 / w 2 / h 3 제한 있음 |
| `marble` | 대리석 | 2.0 | 1.0 | 0.85 | min_day 없음 / stage 8 | blank(any) | `cobalt`, `#d9dde4ff` | `none` | 물리 size 없음, max area 4 / w 2 / h 2 제한 있음 |
| `cement` | 시멘트 | 3.0 | 1.0 | 0.9 | min_day 없음 / stage 12 | blank(any) | `ember`, `#707983ff` | `none` | 물리 size 없음, max area 4 / w 2 / h 4 제한 있음 |
| `steel` | 강철 | 5.0 | 1.0 | 0.8 | min_day 없음 / stage 14 | blank(any) | `ember`, `#5d6979ff` | `none` | 물리 size 없음, max area 4 / w 4 / h 2 제한 있음 |
| `bomb` | 폭탄 | 2.0 | 1.0 | 0.65 | min_day 없음 / stage 16 | blank(any) | `ember`, `#d45858ff` | `explosion` | 물리 size 없음, max area 1 / w 1 / h 1 제한 있음 |
| `glass` | 유리 | 1.0 | 1.0 | 1.0 | min_day 없음 / stage 1 | blank(any) | `amber`, `#b8d8f4ff` | `glass_shatter_damage` | 물리 size 없음, max area 4 / w 2 / h 2 제한 있음 |
| `gold` | 황금 | 3.0 | 2.5 | 0.75 | min_day 없음 / stage 10 | blank(any) | `cobalt`, `#d7b94dff` | `bonus_gold` | 물리 size 없음, max area 2 / w 2 / h 2 제한 있음 |

## 3. Size 정의 표

Size는 material과 별도 Resource로 분리되어 있으며, 현재 HP와 reward 배율은 대체로 `width_u * height_u` 면적과 일치한다. 별도 `sand_units_multiplier`는 없고, sand 계산은 `size.reward_multiplier`를 재사용한다.

| size_id | width_u | height_u | area | hp_multiplier | reward_multiplier | sand 처리 | spawn_weight | min_day / min_stage | min_difficulty | 독립 선택 가능성 |
|---|---:|---:|---:|---:|---:|---|---:|---|---|---|
| `size_1x1` | 1 | 1 | 1 | 1.0 | 1.0 | reward 배율 재사용 | 1.0 | min_day 없음 / stage 1 | blank(any) | 데이터상 가능, 현재 resolver는 조합 선택 |
| `size_1x2` | 1 | 2 | 2 | 2.0 | 2.0 | reward 배율 재사용 | 0.95 | min_day 없음 / stage 2 | blank(any) | 데이터상 가능, 현재 resolver는 조합 선택 |
| `size_2x1` | 2 | 1 | 2 | 2.0 | 2.0 | reward 배율 재사용 | 0.85 | min_day 없음 / stage 4 | blank(any) | 데이터상 가능, 현재 resolver는 조합 선택 |
| `size_2x2` | 2 | 2 | 4 | 4.0 | 4.0 | reward 배율 재사용 | 0.55 | min_day 없음 / stage 12 | `hard` | 데이터상 가능, 현재 resolver는 조합 선택 |
| `size_1x3` | 1 | 3 | 3 | 3.0 | 3.0 | reward 배율 재사용 | 0.55 | min_day 없음 / stage 14 | `hard` | 데이터상 가능, 현재 resolver는 조합 선택 |
| `size_3x1` | 3 | 1 | 3 | 3.0 | 3.0 | reward 배율 재사용 | 0.4 | min_day 없음 / stage 16 | `hard` | 데이터상 가능, 현재 resolver는 조합 선택 |
| `size_1x4` | 1 | 4 | 4 | 4.0 | 4.0 | reward 배율 재사용 | 0.3 | min_day 없음 / stage 20 | `hard` | 데이터상 가능, 현재 resolver는 조합 선택 |
| `size_4x1` | 4 | 1 | 4 | 4.0 | 4.0 | reward 배율 재사용 | 0.2 | min_day 없음 / stage 22 | `hard` | 데이터상 가능, 현재 resolver는 조합 선택 |

## 4. Type 정의 표

현재 Type 데이터는 `boss` 하나다. 구조상 optional affix/modifier로 붙일 수 있지만, 현재 일반 랜덤 type 선택은 비활성이다.

| type_id | display_name | hp_multiplier | reward_multiplier | sand_units_multiplier | prefix/suffix | special_result override | optional/random 구조 |
|---|---|---:|---:|---:|---|---|---|
| `boss` | boss | 3.0 | 1.0 | 1.0 | prefix `boss`, suffix blank | `none` | Resource 구조는 optional. 현재 `can_spawn_randomly=false`, `random_type_chance=0.0`라 일반 스폰에는 붙지 않고 StageTable boss에서 명시 사용 |

## 5. 현재 스폰 흐름 표

| 순서 | 현재 실행 흐름 | 관련 파일 |
|---:|---|---|
| 1 | `Main._on_spawn_timer_timeout()`이 일반 블록 스폰 시작 | `scenes/main/Main.gd` |
| 2 | `GameData.pick_block_type_definition_or_none(rng)` 호출. 현재 데이터에서는 항상 `null` | `scripts/autoload/GameData.gd`, `scripts/data/BlockCatalog.gd` |
| 3 | `GameData.resolve_random_block_definition()`이 난이도 정의와 StageTable day HP 배율을 준비 | `scripts/autoload/GameData.gd` |
| 4 | `BlockSpawnResolver.resolve_random_block()` 호출 | `scripts/data/BlockSpawnResolver.gd` |
| 5 | `BlockCatalog.get_spawn_candidates()`가 모든 Material x Size 조합을 순회 | `scripts/data/BlockCatalog.gd` |
| 6 | material 제한, size 제한, material의 `max_allowed_*` 제한으로 후보 필터링 | `scripts/data/BlockCatalog.gd` |
| 7 | `material.base_spawn_weight * size.base_spawn_weight * progression_weight`로 조합 weight 계산 | `scripts/data/BlockCatalog.gd` |
| 8 | 조합 후보 전체에서 weighted roll 1회 수행 | `scripts/data/BlockSpawnResolver.gd` |
| 9 | `_build_resolved_definition()`이 최종 HP/reward/sand/name/color/type 적용 | `scripts/data/BlockSpawnResolver.gd` |
| 10 | `BlockData.from_resolved_definition()`으로 런타임 데이터 생성 | `scripts/data_models/BlockData.gd` |
| 11 | `FallingBlock.setup()`으로 낙하 블록 생성 | `scenes/blocks/FallingBlock.gd` |

Boss 스폰은 별도 흐름이다. `Main._spawn_boss_block()`이 `StageTable`의 `boss_block_base_id`, `boss_block_size_id`, `boss_block_type_id`를 읽고 `resolve_specific_block_definition()`으로 명시 조합을 resolve한다. 현재 boss 데이터는 Day 10 `marble / size_2x1 / boss`, Day 20 `steel / size_2x1 / boss`, Day 30 `steel / size_2x1 / boss`다.

## 6. 목표 스폰 흐름과의 차이 표

| 목표 흐름 | 현재 구현 | 차이 / 리스크 |
|---|---|---|
| 현재 난이도와 Day 확인 | 수행함 | `GameData`가 difficulty definition과 `StageTable.block_hp_multiplier`를 전달 |
| 유효 Material 후보 수집 | 조합 생성 중 material 제한을 검사 | material 단독 후보 풀을 먼저 확정하지 않음 |
| Material weight 기반 선택 | 단독 선택하지 않음 | Material과 Size를 독립 roll로 비교/조정하기 어려움 |
| 유효 Size 후보 수집 | 각 material마다 size 제한 검사 | size 후보가 material의 `max_allowed_*`와 결합됨 |
| Size weight 기반 선택 | 단독 선택하지 않음 | size spawn rule을 순수 size 축으로 적용하려면 resolver 정책 결정 필요 |
| Optional Type 선택 | 구조 있음, 현재 일반 스폰 비활성 | `random_type_chance=0.0`, `boss.can_spawn_randomly=false` |
| Material x Size + Type resolved 생성 | 수행함 | 최종 resolved 구조는 목표와 일치 |

요약하면 현재 코드는 `Material x Size` 모델을 표현하고 resolve할 수 있지만, 스폰 선택 정책은 "Material 선택 후 Size 선택"이 아니라 "Material-Size pair 선택"이다.

## 7. HP / Reward / Sand 공식 비교표

기본 상수는 현재 `BLOCK_HP_PER_UNIT = 10.0`, `BLOCK_REWARD_PER_UNIT = 5.0`, `BLOCK_SAND_UNITS_PER_UNIT = 36.0`이다.

| 항목 | 문서상 목표 | 현재 코드 공식 | 일치 여부 |
|---|---|---|---|
| HP | `BLOCK_HP_PER_UNIT x material_hp_multiplier x size_area/size_hp_multiplier x difficulty_hp_multiplier x day_hp_multiplier x type_hp_multiplier` | `ceil(BLOCK_HP_PER_UNIT x size.hp_multiplier x material.hp_multiplier x difficulty.block_hp_multiplier x type.hp_multiplier x StageTable.block_hp_multiplier)` | 대체로 일치. `docs/02_systems_spec.md`의 HP 표기는 day 배율을 생략하지만 `docs/05_balance_formula.md`와 현재 코드는 day 배율 포함 |
| Reward | `BLOCK_REWARD_PER_UNIT x size_reward_multiplier x material_reward_multiplier x type_reward_multiplier` | `round(BLOCK_REWARD_PER_UNIT x size.reward_multiplier x material.reward_multiplier x type.reward_multiplier)` | 일치 |
| Sand | `BLOCK_SAND_UNITS_PER_UNIT x size_reward_multiplier 또는 size_sand_multiplier x type_sand_units_multiplier` | `round(BLOCK_SAND_UNITS_PER_UNIT x size.reward_multiplier x type.sand_units_multiplier)` | 현재 문서의 `size_reward_multiplier` 기준과 일치. 별도 `size_sand_units_multiplier`는 없음 |
| Stage day HP | StageTable day별 `block_hp_multiplier` | `GameData.get_block_hp_multiplier(day)`가 resolver로 전달됨 | 반영됨 |
| Stage reward_multiplier | StageDayDefinition에 필드는 있음 | 블록 reward 공식에는 사용되지 않음 | 문서/기획상 Stage 보상 배율을 의도했다면 미구현 |
| XP | 문서 요구 범위 밖이지만 balance snapshot에 포함 | block destroy XP는 `width * height * BLOCK_DESTROY_XP_PER_UNIT`; material/type reward와 별개 | Material/Type 보상 배율과 XP는 분리됨 |

Sand 소비 흐름은 `FallingBlock`이 정착/분해될 때 `Main._on_block_decomposed()`가 `SandField.spawn_from_block(block_rect, block_data)`를 호출하고, `SandField`가 `block_data.sand_units`만큼 모래 셀을 생성한다.

## 8. Size Spawn Rule 지원 여부 표

| 필요 구조 | 현재 지원 | 판단 |
|---|---|---|
| size별 spawn_weight | `BlockSizeData.base_spawn_weight` | 가능 |
| size별 min_day | 없음 | 불가능. 현재는 `min_stage`만 있음 |
| size별 min_stage | `BlockSizeData.min_stage` | 가능 |
| size별 min_difficulty | `BlockSizeData.min_difficulty` | 가능 |
| size별 max_stage | `BlockSizeData.max_stage` | 가능 |
| difficulty별 size weight 조정 | `_get_progression_weight_multiplier()`가 difficulty rank를 사용 | 부분 가능. 데이터가 아니라 하드코딩 공식 |
| day/stage별 size weight 조정 | `_get_progression_weight_multiplier()`가 stage progression을 사용 | 부분 가능. 데이터가 아니라 하드코딩 공식 |
| 큰 가로 size 제한 | size `min_difficulty`, `min_stage`, material `max_allowed_width`, hardcoded `wide_pressure` | 부분 가능 |
| Normal 저Stage 대형 제한 | `size_2x2+`가 `hard`와 높은 `min_stage`를 요구 | 현재 데이터로 가능 |
| Hard 이상 대형 허용 | `min_difficulty=hard` 크기들이 존재 | 가능 |
| material별 허용 size 제한 | material `max_allowed_area/width/height` | 가능. 단, material에 size gating이 들어감 |
| size별 sand multiplier | 없음. `reward_multiplier`를 sand에도 재사용 | 불가능 |
| 독립 Material 선택 후 Size 선택 | `pick_block_base_definition`, `pick_block_size_definition` 함수는 있으나 실제 resolver 미사용 | 현재 일반 스폰에서는 불가능 |
| size spawn rule 전용 테이블 | 없음 | 불가능 |

## 9. TSV / Google Sheets 파이프라인 지원 여부 표

현재 TSV 기반 import/export는 block catalog를 Material / Size / Type 파일로 분리해 표현할 수 있다. Google Sheets 직접 연동은 코드상 별도 구현이 아니라 TSV를 사람이 표 형태로 편집하는 흐름에 가깝다.

| 파일 / 기능 | 현재 지원 | 부족한 점 |
|---|---|---|
| `block_catalog_meta.tsv` | `default_material_id`, `default_size_id`, `random_type_chance` 지원 | Resource 필드는 아직 `default_block_base_id`라 내부 이름과 TSV 이름이 다름 |
| `block_materials.tsv` | material ID, HP/reward/spawn, special, color, min/max stage, max allowed size 제한 지원 | material별 size gating은 가능하지만 별도 rule table은 아님 |
| `block_sizes.tsv` | width/height/area, HP/reward/spawn, min difficulty/stage, tags 지원 | `size_sand_units_multiplier`, difficulty/stage별 weight curve 없음 |
| `block_types.tsv` | optional type/affix, random 여부, HP/reward/sand 배율 지원 | 현재 데이터상 random type은 비활성 |
| `stage_days.tsv` | day HP 배율, boss material/base, boss size, boss type 지원 | boss 참조 ID 유효성 검증은 제한적 |
| TSV export | `TsvExportService.gd`가 block meta/material/size/type export | Google Sheets 직접 API 연동은 아님 |
| TSV import/convert | `BlockDataImporter.gd`, `TsvToTresConverter.gd`가 `BlockCatalog.tres` 생성 | size spawn rule 전용 구조 없음 |
| Validation | header, unique id, difficulty, size area 검증 | default material/size 참조, boss material/size/type 참조, material max constraints 의미 검증은 부족 |

size spawn rule을 TSV/Google Sheets로 명확히 표현하려면 최소한 아래 중 하나가 필요하다.

- `block_sizes.tsv`에 `weight_normal`, `weight_hard`, `weight_extreme`, `weight_hell`, `weight_nightmare` 같은 difficulty별 weight 컬럼 추가
- `size_spawn_rules.tsv` 같은 별도 rule table 추가
- stage/day 범위 조건(`min_day`, `max_day`, `min_stage`, `max_stage`)과 size별 weight override 표현
- sand를 reward와 분리하려면 `size_sand_units_multiplier` 컬럼 추가

## 10. 코드 / 문서 불일치 정리

| 구분 | 내용 | 판단 |
|---|---|---|
| 문서에는 있는데 코드에는 없는 것 | `docs/04_roadmap.md`의 "Size는 Material과 별개로 랜덤 선택" | 현재 resolver는 독립 선택이 아님 |
| 문서에는 있는데 코드에는 없는 것 | size spawn rule 전용 데이터 구조 | 아직 없음 |
| 문서에는 있는데 코드에는 없는 것 | Google Sheets에서 Material / Size / Type / Size Spawn Rule 관리 | TSV 파일은 있으나 size spawn rule과 직접 Sheets 연동은 없음 |
| 문서에는 있는데 코드에는 부분만 있는 것 | difficulty/stage별 size weight 변화 | 하드코딩 progression 공식만 있음 |
| 코드에는 있는데 문서와 정리가 필요한 것 | `StageDayDefinition.reward_multiplier` | 블록 보상 공식에는 적용되지 않음 |
| 코드에는 있는데 명칭이 오래된 것 | `default_block_base_id`, `get_block_base_definition`, `boss_block_base_id`, `block_base`, `BlockBaseDefinition` | 실제 의미는 material. 기능 문제보다는 naming debt |
| 문서 간 차이 | `docs/02_systems_spec.md` HP 공식은 day 배율 생략, `docs/05_balance_formula.md`와 코드는 day 배율 포함 | 실행 코드 기준으로 day 배율 포함이 현재 사실 |
| 실제 동작상 주의 | material에 `max_allowed_area/width/height`가 있어 material-size 결합 제한을 만든다 | strict independence를 원하면 rule 위치 재검토 필요 |
| 실제 동작상 주의 | `pick_block_size_definition()`은 존재하지만 일반 스폰 resolver에서 사용하지 않음 | API 존재와 실제 동작을 혼동하면 안 됨 |
| 단순 명칭 문제 | TSV meta는 `default_material_id`, Resource는 `default_block_base_id` | import/export가 매핑하므로 현재 기능은 동작 |

## 11. 수정 필요 후보 우선순위 표

| 우선순위 | 수정 후보 | 이유 | size spawn rule 설계 전 필수 여부 |
|---|---|---|---|
| P0 | 스폰 정책 결정: 조합 후보 1회 roll 유지 vs Material roll 후 Size roll로 변경 | size spawn rule의 의미가 완전히 달라짐 | 설계 전 반드시 결정 필요 |
| P1 | size spawn rule 데이터 구조 초안 작성 | 현재는 하드코딩 progression과 size base weight만 있음 | 필요 |
| P1 | TSV schema/import/export에 size spawn rule 표현 추가 | 밸런서가 표로 조정하려면 필요 | 구현 전 필요 |
| P1 | `BlockSpawnResolver`가 새 rule을 적용할 위치 설계 | 현재 resolver는 조합 후보 weight만 받음 | 구현 전 필요 |
| P2 | `size_sand_units_multiplier` 추가 여부 결정 | sand를 reward와 분리하려면 필요 | 선택. 현재 공식 유지면 불필요 |
| P2 | validation 강화: default ids, boss ids, material-size constraints | TSV 실수 방지 | 권장 |
| P3 | `base` 명칭을 material alias로 문서화하거나 점진 rename | 혼동 완화 | 즉시 필수 아님 |
| P3 | Stage `reward_multiplier`의 의도 결정 | 코드에 필드가 있으나 블록 reward에 미사용 | 별도 밸런스 결정 필요 |

## 12. 다음 작업 판단

size spawn rule 설계 초안 작성은 바로 진행 가능하다. 단, 구현에 들어가기 전에는 "Material과 Size를 실제로 독립 선택할 것인지" 또는 "현재처럼 Material-Size 조합 후보를 유지하되 size rule을 weight 계산에 반영할 것인지"를 먼저 결정해야 한다.

현재 코드 기반에서 가장 작은 변경으로는 조합 후보 구조를 유지하고 `get_spawn_weight_for_candidate()` 안에 size rule multiplier를 추가하는 방식이 안전하다. 반대로 문서의 엄밀한 "Material 선택 후 Size 선택"을 만족하려면 `BlockSpawnResolver.resolve_random_block()`의 선택 정책을 바꾸는 작업이 필요하며, 이는 스폰 분포가 크게 달라질 수 있다.
