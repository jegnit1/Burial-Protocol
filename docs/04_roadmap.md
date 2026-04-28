# Burial Protocol - Roadmap

기준일: `2026-04-28`  
기준 브랜치: `main`

---

## 0. 목적

이 문서는 현재 구현 상태를 기준으로 앞으로 해야 할 작업을 정리한다.
구현된 시스템 설명은 `01_gdd.md`, `02_systems_spec.md`, `03_data_and_state_spec.md`에 두고, 이 문서에는 완료/진행/보류/TODO와 우선순위만 둔다.

밸런스 수치 공식은 `05_balance_formula.md`를 기준으로 한다.
아이템 데이터 구조와 조건부 효과 스키마는 `03_data_and_state_spec.md`의 `Item Object Schema`를 기준으로 한다.

---

## 1. 현재 구현된 코어

현재 구현 완료 또는 실제 연결된 영역:

- Title -> MainHub -> Main -> Result 흐름
- 기본 캐릭터 선택
- 난이도 선택과 순차 해금 구조
- 30 Day 런 구조
- 낙하 블록 스폰
- 보스 Day 스폰
- 블록 파괴/분해
- StageTable의 Day별 `block_hp_multiplier` 런타임 HP 반영
- Day 10/20/30 보스 resolve 정합성
- 모래 생성과 모래 시뮬레이션
- 중량 한도 기반 실패
- 좌우 벽 채굴
- 마우스 방향 기반 채굴
- 점프, 추가 점프, 대시, 벽타기
- 공격모듈 기반 공격
- melee/ranged/mechanic 공격모듈 타입
- Day 종료 후 intermission
- 낙하형 키오스크
- Day 상점 UI
- 상점 아이템 5개 롤
- attack_module/function_module/enhance_module 구매
- 공격모듈 즉시 장착, 중복 장착, 합성
- 아이템 객체 스키마의 `conditions/effects/apply_timing` 병행 수용
- `stat_query` 기반 조건부 스탯 보너스 1차 구현
- 조건부 상점 아이템 테스트 2종 검증
- XP와 레벨업 카드
- 레벨업 카드 17종 풀 (melee_atk_up, ranged_atk_up 추가)
- 레벨업 카드 5장 제시 방식
- 레벨업 카드 Normal/Silver/Gold/Platinum 희귀도
- Luck 기반 레벨업 희귀도 보정
- 레벨업 희귀도별 UI 색상/테두리/라벨 표시
- 근거리/원거리 공격력 분리 (`run_bonus_melee_attack_damage`, `run_bonus_ranged_attack_damage`)
- 공격모듈 attack_style/effect_style 시스템 (`AttackModuleStyleResolver`)
- 상점 아이템 랭크별 가격 티어링 (`SHOP_ITEM_RANK_FALLBACK_PRICES`)
- 런타임 스탯 증가
- HUD와 ESC 스탯 패널
- 저장 파일과 최고 기록 저장
- 밸런스 스냅샷/회귀 검증 스크립트 일부

---

## 2. 완료된 최근 작업

아래 항목은 최근 로드맵 작업으로 완료된 상태다.

### 2-1. 아이템 객체 스키마 1차 기반

완료:

- `ShopItemDefinition`에 `conditions`, `effects`, `apply_timing` 필드 추가
- 기존 아이템에 새 필드가 없어도 안전하게 기본값 처리
- 기존 `effect_values`를 `effects = [{ type, value }]` 형태로 병행 변환
- `conditional_stat_bonus + stat_query` 평가 helper 추가
- `attack_damage_flat`, `attack_damage_percent`를 공격력 getter에 연결
- `attack_hit_side` 같은 공격 순간 조건은 TODO로 유지

검증:

- 기존 `stat_bonus` 아이템 정상
- 기존 공격모듈 구매/장착/합성 정상
- 조건부 테스트 아이템 2종 정상

### 2-2. 조건부 아이템 테스트

추가/검증 완료:

- `melee_purity_core`
  - 모든 공격모듈이 melee일 때 공격력 percent 증가
- `module_focus_circuit`
  - 장착 공격모듈 수가 일정 이상일 때 공격력 flat 증가

검증 완료:

- 조건 만족 시 공격력 증가
- 조건 불만족 시 공격력 증가 없음
- 기존 상점/공격모듈 회귀 통과

### 2-3. 밸런스 스냅샷 스크립트

완료:

- `scripts/tests/balance_snapshot.gd` 추가/확장
- 기본 스탯, StageTable, BlockCatalog, ShopItemCatalog, 레벨업 카드 출력
- Day 1/10/20/30 기준 HP 비교
- 보스 HP/처치 시간 비교
- 상점 아이템 랭크별 문서 기준 비교
- 레벨업 희귀도 확률/효과값 출력

용도:

- 실제 수치 변경 전후 비교
- 회귀 확인
- Codex 작업 결과 검증

### 2-4. StageTable HP 배율 적용

완료:

- `StageTable.tres`의 Day별 `block_hp_multiplier`를 실제 블록 HP 계산에 연결
- 최종 HP 공식에 `day_hp_multiplier` 반영
- 비정상 값 fallback `1.0` 처리
- `BlockResolvedDefinition`, `BlockData`, `balance_snapshot.gd`에 Day 배율 정보 반영

현재 기본 wood 1x1 normal 기준:

| Day | 실제 HP |
|---:|---:|
| 1 | 10 |
| 10 | 15 |
| 20 | 20 |
| 30 | 25 |

### 2-5. 보스 Day 정합성 수정

완료:

- Day 10 보스가 `steel`의 `min_stage = 14` 제한 때문에 resolve 실패하던 문제 수정
- Day 10 보스 material을 `steel -> marble`로 최소 데이터 수정
- Day 10/20/30 보스 resolve 정상 확인

현재 보스 HP:

| Day | Boss Definition | HP |
|---:|---|---:|
| 10 | marble / size_2x1 / boss | 174 |
| 20 | steel / size_2x1 / boss | 585 |
| 30 | steel / size_2x1 / boss | 750 |

보스 보상 구조는 아직 별도 설계하지 않는다.

### 2-6. 레벨업 카드 Normal 기준 정리

완료:

- 기존 레벨업 카드 수치를 `05_balance_formula.md`의 Normal 기준에 맞춰 정리
- 공격력, 공격속도, 최대 HP, 이동속도, 채굴속도, 공격범위, 치명타 확률, 점프력, 채굴범위 조정
- 방어력, HP 재생, 채굴 데미지는 기존 수치 유지

### 2-7. 누락 레벨업 카드 추가

완료:

- `battery_recovery_up`
- `luck_up`
- `interest_up`

이 시점에서 레벨업 카드 풀은 15종이었다. (→ 이후 2-12에서 17종으로 확장)

### 2-8. 레벨업 카드 희귀도 시스템

완료:

- Normal / Silver / Gold / Platinum 희귀도 구현
- 카드 슬롯별 독립 희귀도 roll
- 같은 카드 + 같은 희귀도 중복 방지
- 같은 카드라도 희귀도가 다르면 허용
- Luck 기반 확률 보정
- 희귀도별 효과값 배율 적용

기본 확률:

| Rarity | Chance | Multiplier |
|---|---:|---:|
| Normal | 70% | 1.0 |
| Silver | 22% | 1.6 |
| Gold | 7% | 2.5 |
| Platinum | 1% | 4.0 |

### 2-9. 레벨업 희귀도 UI 피드백

완료:

- 카드 상단 희귀도 라벨 추가
- Normal/Silver/Gold/Platinum별 배경/테두리/라벨 색상 적용
- Gold/Platinum은 더 눈에 띄는 두꺼운 테두리와 라벨 사용
- `rarity_id` 없는 카드 데이터는 Normal fallback
- 사운드 피드백은 에셋 없음으로 TODO 유지

### 2-10. 상점 아이템 밸런스 진단

완료:

- `ShopItemCatalog.tres`의 enhance/stat_bonus/conditional_stat_bonus 수치를 문서 기준과 비교
- 전체 76개 비교 항목 중 20개 near, 41개 high, 11개 low, 4개 no_doc_target로 분류
- 실제 상점 아이템 수치는 아직 수정하지 않음

발견된 주요 과잉:

- `interest_rate_percent` 계열
- 고랭크 최대 HP
- 고랭크 치명타 확률
- 고랭크 행운
- 이동속도/점프력 계열

상점 아이템 나머지 수치 조정은 필요할 때 별도 판단한다.

### 2-11. 공격모듈 스타일 시스템

완료:

- `scripts/data/AttackModuleStyleResolver.gd` 추가
- 공격모듈 데이터에 `attack_style`, `effect_style` 필드 처리
- melee (`slash`, `stab`, `pierce`, `cleave`, `smash`) / ranged (`shotgun`, `sniper`, `laser`, `rifle`, `revolver`) 스타일 분리
- `AttackModuleStyleResolver`가 attack_style별 shape, range growth 계수, projectile 옵션 등을 반환
- mechanic 모듈은 스타일 시스템 예외로 유지

### 2-12. 근거리/원거리 공격력 분리

완료:

- `GameState.gd`에 `run_bonus_melee_attack_damage`, `run_bonus_ranged_attack_damage` 추가
- `get_melee_base_attack_damage()`, `get_ranged_base_attack_damage()` getter 추가
- `melee_atk_up`, `ranged_atk_up` 레벨업 카드 추가 (레벨업 카드 풀 15종 → 17종)
- `reset_run()`에서 초기화 포함

### 2-13. 상점 아이템 랭크별 가격 티어링

완료:

- `GameConstants.gd`에 `SHOP_ITEM_RANK_FALLBACK_PRICES = {D:15, C:30, B:60, A:120, S:240}` 추가
- `GameState.get_effective_shop_item_price(item_id)` 구현
- `price_gold`가 없거나 0인 아이템은 랭크 기본 가격을 자동 적용
- `DayShopUI.gd`에서 가격 표시 시 유효 가격 getter 사용

### 2-14. 레벨업 카드 5장 제시

완료:

- `LevelUpUI`에서 카드 제시 수를 3장 → 5장으로 확장
- `GameConstants.LEVEL_UP_CARD_COUNT` 기준

---

## 3. 현재 보류 중인 항목

아래 항목은 의도적으로 당장 처리하지 않는다.

### 3-1. 상점 아이템 세부 수치 조정

보류 사유:

- 진단 리포트는 완료되었으나, 실제 수치 조정은 플레이 감각과 직접 연결된다.
- 필요할 때 항목별로 별도 판단한다.

우선 보류 대상:

- 이자율 계열 하향
- 이동속도/점프력 계열 조정
- 최대 HP/치명타/행운 고랭크 조정
- 채굴속도 계열 상향
- `max_weight_flat`, `attack_damage_percent` 기준 예산 추가

### 3-2. 보스 보상 구조

보류 사유:

- 보스 HP/정합성은 확인되었으나, 보스 보상은 추후 별도 설계한다.
- 현재 보스 보상은 낮지만 당장 수정하지 않는다.

### 3-3. 고급 조건부 아이템

보류 사유:

- `stat_query` 기반 조건부 아이템은 1차 검증 완료.
- `weight_ratio_at_least`는 GameState 단독으로 현재 모래 무게를 알 수 없어 context 설계가 필요하다.
- `attack_hit_side`는 공격 판정 context 설계가 필요하다.

후순위 조건:

- `weight_ratio_at_least`
- `attack_hit_side`
- `on_attack_hit`
- `on_block_destroyed`
- `on_sand_removed`
- `on_player_damaged`

---

## 4. 다음 작업 순서

현재 권장 순서는 아래를 따른다.

```text
1. 공격모듈 기본 장비/수치 정리
2. 블록 material/size/type 스펙 정리 및 데이터 구조 점검
3. 블록 size spawn weight / 난이도 / Stage 조건 설계
4. Google Sheets import/export 데이터 파이프라인 정리
5. Day별 블록 HP/스폰/모래 압박 테스트
6. 채굴 확장: 보물상자/크립 시스템 설계
7. HUD/상점 UI 한글화 및 가독성 개선
8. 모래 렌더링 고도화
9. 아트 적용 기준 확정
```

현재는 밸런스 기반과 레벨업 시스템이 어느 정도 정리되었으므로, 다음 큰 축은 `공격모듈 정리`와 `블록 시스템 정리`다.

---

## 5. 최우선 작업

### 5-1. 공격모듈 기본 장비/수치 정리

목표:

- 공격모듈을 임시 테스트 구조에서 실제 장비 구조로 정리한다.
- 시작 장비, 모듈 등급, 합성, 타입별 전투 감각을 안정화한다.

작업:

- 현재 공격모듈 목록 정리
- 각 모듈의 melee/ranged/mechanic 타입 확인
- damage multiplier / attack speed multiplier / range / shape 확인
- 등급 D/C/B/A/S 배율 적용 후 예상 DPS 비교
- 현재 시작 모듈 지급 위치 확인
- 기본 시작 모듈을 캐릭터 데이터로 이전할지 검토
- melee/ranged/mechanic 간 밸런스 차이 확인
- 모듈 합성 시 DPS 상승폭 확인
- 투사체/레이저/메카닉 피드백 강화
- 오라형 공격모듈 세부 동작 확정 여부 결정

주의:

- mechanic 모듈은 플레이어 공격력 보너스 영향을 받지 않는 예외를 유지한다.
- ranged/melee는 플레이어 공격력/공속/범위 성장과 연결된다.
- 먼저 비교표/진단을 만들고, 실제 수치 변경은 별도로 판단한다.

### 5-2. 블록 material/size/type 스펙 정리 및 데이터 구조 점검

목표:

- 블록 시스템을 `Material x Size + optional Type` 기준으로 완전히 정리한다.
- Material은 재질만 정의하고, Size는 별도 랜덤 축으로 분리한다.
- 블록 size의 스폰 확률/최소 등장 조건을 난이도와 Stage에 따라 제어할 수 있게 한다.
- Google Sheets에서 작성/import/export 가능한 구조를 설계한다.

핵심 원칙:

- 블록 베이스/base/material에는 사이즈가 포함되면 안 된다.
- Material은 재질을 정의한다.
- Material은 HP 배율, 보상 배율, 색상, 스폰 확률, 등장 제한 등을 가진다.
- Size는 Material과 별개로 랜덤 선택된다.
- Type은 optional modifier/affix로 유지한다.

HP 원칙:

```text
final_hp =
  BLOCK_HP_PER_UNIT
  x material_hp_multiplier
  x size_area_multiplier
  x difficulty_hp_multiplier
  x day_hp_multiplier
  x type_hp_multiplier
```

Size 기본 HP 배율:

```text
1U x 1U = 1x
2U x 1U = 2x
1U x 2U = 2x
2U x 2U = 4x
```

즉, size는 기본적으로 `width_u * height_u` 면적만큼 HP 요구치를 늘린다.

가로/세로 size의 게임플레이 의미:

- 가로 size 증가는 플레이어의 회피 공간을 직접 제한한다.
- 가로 size 증가는 공격스탯 요구치와 회피 요구치를 동시에 올린다.
- 세로 size 증가는 주로 공격스탯 요구치를 올린다.
- 세로 size는 공간 압박이 없지는 않지만, 가로 size만큼 즉각적인 회피 공간 제한을 만들지는 않는다.

Size 스폰 정책:

- size별 등장 확률은 난이도와 Stage에 따라 달라져야 한다.
- 높은 난이도일수록 큰 블록이 등장할 확률이 높아진다.
- 높은 Stage일수록 큰 블록이 등장할 확률이 높아진다.
- size별 최소 난이도와 최소 Stage를 설정할 수 있어야 한다.

예시 제한:

- Normal 저Stage에서 가로 4U 블록은 등장하면 안 된다.
- 가로세로 합 8U 수준의 대형 블록은 Hard 이상부터 등장해야 한다.

데이터/툴링 요구:

- Material / Size / Type / Size Spawn Rule은 Google Spreadsheet에서 관리 가능해야 한다.
- TSV/CSV import/export를 지원해야 한다.
- Godot `.tres` 데이터와 spreadsheet source가 서로 동기화 가능해야 한다.
- 데이터 파이프라인은 `data_tsv` 또는 별도 pipeline 로그와 함께 검증 가능해야 한다.

점검 작업:

- 현재 BlockCatalog의 material/size/type 분리 상태 확인
- 기존 코드에 size가 base/material에 섞여 있는지 확인
- size별 HP/보상/모래량/등장 제한 확인
- size spawn weight가 난이도/Stage별로 분리 가능한지 확인
- BlockSpawnResolver가 material 선택과 size 선택을 독립적으로 수행하는지 확인
- Google Sheets import/export에서 size spawn rule을 표현할 수 있는지 확인

### 5-3. Day별 블록 HP/스폰/모래 압박 테스트

목표:

- 공식과 데이터가 실제 플레이 감각에서 맞는지 검증한다.

검증 Day:

- Day 1
- Day 5
- Day 10
- Day 15
- Day 20
- Day 25
- Day 30

확인 항목:

- 평균 블록 처리 시간
- 평균 모래 생성량
- 중량 실패까지 걸리는 시간
- 상점 구매 후 다음 Day 체감 변화
- 공격모듈 빌드와 채굴 빌드의 차이
- 보스 Day 압박감
- 가로로 큰 블록이 회피 공간을 과도하게 막는지
- 세로로 큰 블록이 공격스탯 요구만 과도하게 올리는지

### 5-4. 채굴 확장: 보물상자/크립 시스템 설계

목표:

- 좌우 벽 채굴을 단순 벽 제거가 아니라 탐사/보상/리스크 관리 루프로 확장한다.
- 보물상자는 보상형 특수 객체, 크립은 리스크형 특수 객체로 설계한다.

보물상자 설계 작업:

- 빛나는 벽블록 이펙트 규칙 정의
- 보물상자 Normal/Silver/Gold/Platinum 등급 정의
- 등급별 보물상자 이미지/연출 방향 정의
- `E` 상호작용과 보상 팝업 일시정지 구조 정의
- 랜덤 보상 연출 UI 설계
- 보물상자 등급별 보상 테이블 설계
- 고등급 보물상자의 깊이/높이 출현 경향성 설계

보상 체계 원칙:

- 모든 보상은 `D~S` 등급 보상 아이템으로 정의한다.
- `소량/보통/대량` 표현은 사용하지 않는다.
- 예시는 `S급 골드주머니`, `B급 경험치 물약`, `C급 모래제거 프로토콜`처럼 작성한다.
- Gold/XP/Item(Module)/Sand Removal 모두 D~S 등급 보상으로 관리한다.
- 일정 등급 이상의 보물상자는 D/C급 모듈을 제외하거나, 낮은 등급 보상이 나올 경우 최소 B~S급 XP/Gold/Sand Removal 보상으로 보정한다.

크립 설계 작업:

- 크립의 노출/활성화/경고 규칙 정의
- 공격형 크립의 공격 패턴 설계
- 디버프형 크립의 디버프 후보 정의
- 저난이도/저스테이지 출현 제한 정의
- 동시 활성 디버프형 크립 수 제한 검토

주의:

- 보물상자는 채굴 중 블록 처리를 포기하는 리스크에 대한 저점을 보장해야 한다.
- 크립은 불합리한 억까가 아니라 경고 후 대응 가능한 리스크로 설계한다.

---

## 6. 근시일 내 작업

### 6-1. HUD / UI

- HUD 문자열 한글화
- 상점 UI 가독성 개선
- 공격모듈 장착 상태 표시 개선
- 스킬 슬롯 2, 3번 활용 방향 결정
- 세로 센서 HUD 위험도 표시 추가 검토
- 중량 경고 연출 강화
- 보물상자 보상 팝업 UI/랜덤 연출 방향 검토
- 레벨업 희귀도 UI 색상/줄바꿈 실제 화면 확인

### 6-2. 플레이어 감각

- 1U, 플레이어 크기, 카메라 배율 최종 점검
- 벽타기 상단 제한 플레이 감각 확인
- 대시와 모래 충돌 감각 점검
- 채굴 범위와 리듬 튜닝
- 공격모듈별 공격속도 체감 점검

### 6-3. 모래 / 중량

- 모래 총량 증가 속도 밸런스 확인
- 중량 실패까지 걸리는 평균 시간 측정
- Day별 모래 압박 곡선 조정
- 벽 복구 아이템 도입 여부 결정
- 모래 렌더링 고도화

모래 렌더링 우선 방향:

- 물리 셀 크기는 우선 유지한다.
- 셀 좌표 기반 deterministic noise를 적용한다.
- 셀 하나를 여러 grain pixel처럼 보이게 렌더링하는 방안을 검토한다.
- 외곽 셀에 파편/먼지 픽셀을 추가한다.
- 표면 하이라이트와 내부 음영을 분리한다.
- 내부 셀은 단순 렌더링하고 외곽/표면 셀 위주로 디테일을 준다.

---

## 7. 중기 작업

### 7-1. 아트 적용

- 플레이어 최종 도트 스프라이트 적용
- run/idle 애니메이션 개선
- 공격모듈 아이콘/공전 에셋 제작
- 블록 재질별 비주얼 구분
- 모래 색상/질감 개선
- 키오스크 비주얼 개선
- HUD 스타일 정리
- 레벨업 카드 희귀도별 색상/테두리 정리
- 보물상자 등급별 이미지와 빛나는 벽블록 이펙트 정리
- 크립 계열 비주얼 방향 정리

### 7-2. 콘텐츠 확장

- 공격모듈 종류 확장
- 기능 모듈 확장
- 강화 모듈 확장
- 조건부 아이템 확장
- 블록 재질 확장
- 블록 특수 결과 확장
- 보물상자 보상 테이블 확장
- 크립 종류/효과 확장
- 보스 Day 패턴 강화

### 7-3. 메타 시스템

- 영구 재화 사용처 확정
- 성장 트리 설계
- 업적 조건과 보상 설계
- 캐릭터 해금 조건 설계
- 캐릭터별 시작 장비/스탯 차별화

---

## 8. 후순위 작업

- 설정 메뉴 실기능
- 사운드 옵션
- 키 바인딩 변경
- 저장 슬롯/프로필 확장
- 튜토리얼
- 도감/아이템 리스트 UI
- 결과 화면 통계 확장
- 스팀 출시용 설정

---

## 9. 현재 제한/TODO 목록

아래 항목은 아직 완성 시스템이 아니거나 추가 확인이 필요하다.

- 설정 메뉴 실기능 미완성
- 메타 성장 실효과 제한적
- 업적 실효과 제한적
- 인벤토리/도감 UI 미완성
- 모든 블록 특수 결과의 본격 구현 미완성
- 오라형 공격모듈 세부 동작 미확정
- 상점 UI 최종 비주얼/한글화 미완성
- 공격모듈과 상점 아이템 최종 밸런스 미확정
- 상점 아이템 세부 수치 조정 보류
- 고급 조건부 아이템 context 미구현
- `weight_ratio_at_least` context 미구현
- `attack_hit_side` context 미구현
- 채굴 확장용 보물상자/크립 시스템 미구현
- 보물상자 등급별 D~S 보상 테이블 미정
- 크립 종류/효과/등장 조건 미정
- 블록 size spawn rule / 난이도 / Stage별 weight 미정
- Google Sheets import/export 데이터 파이프라인 정리 필요
- 보스 보상 구조 미정
- 최종 아트 미적용

---

## 10. 개발 판단 원칙

### 10-1. 아이템 객체 스키마 선행 원칙

조건부 아이템은 아이템 객체 스키마를 먼저 정의하고, 데이터 기반으로 표현한다.

권장 순서:

```text
아이템 객체 스키마 확정
→ condition/effect/apply_timing 타입 정의
→ 기존 stat_bonus 아이템 호환성 검증
→ stat_query 조건부 효과 구현
→ on_attack_hit 조건부 효과 구현
→ 이벤트형 효과 구현
```

금지 방향:

```text
아이템 ID별 하드코딩 분기
```

새 아이템은 가능한 한 데이터로 정의하고, 코드는 조건/효과/적용 타이밍 해석기를 확장한다.

### 10-2. 밸런스 개선과 블록 고도화 순서

권장 순서:

```text
공격모듈 수치 정리
→ 블록 material/size/type 스펙 정리
→ size spawn rule / spreadsheet pipeline 정리
→ Day별 실전 테스트
→ 채굴 확장 보상/리스크 시스템 설계
```

블록 고도화에서 중요한 점:

- Material과 Size는 반드시 분리한다.
- Size는 HP와 회피 공간 압박의 핵심 축이다.
- 가로 size는 회피 난이도에 직접 영향을 준다.
- 세로 size는 공격스탯 요구치를 주로 올린다.
- size별 spawn weight는 난이도와 Stage에 따라 달라져야 한다.
- Google Sheets 기반 데이터 관리가 가능해야 한다.

### 10-3. 환경대응 카드 원칙

레벨업 카드는 플레이어 본체 성장 중심으로 유지한다.

레벨업 카드에서 제외:

- 모래 직접 제거
- 모래 자동 정리
- 벽 복구
- 중량 직접 증가
- 특정 블록 제거
- Day 종료 시 환경 정리

환경대응 성격의 효과는 상점 아이템, 기능 모듈, 보물상자 보상, 특수 이벤트로 제한한다.

---

## 11. 다음 Codex 작업 추천

다음 Codex 작업은 아래 순서가 좋다.

```text
1. 공격모듈별 실제 DPS 비교표 작성
2. 현재 시작 모듈 지급 위치와 캐릭터 데이터 이전 필요성 조사
3. BlockCatalog의 Material/Size/Type 분리 상태 조사
4. size가 material/base에 섞여 있는 코드/데이터가 있는지 확인
5. size별 HP/보상/모래량/등장 제한 비교표 작성
6. size spawn rule을 난이도/Stage별로 표현하는 데이터 구조 초안 작성
7. Google Sheets/TSV import-export 파이프라인 요구사항 정리
8. Day별 블록 HP/스폰/모래 압박 계측
9. 채굴 확장용 보물상자/크립 데이터 구조 초안 작성
10. 보물상자 보상 항목을 D~S 등급 보상 아이템 체계로 설계
```

이 작업들은 우선 조사/비교표/데이터 구조 초안 중심으로 진행하고, 실제 수치 변경은 별도 판단 후 진행한다.
