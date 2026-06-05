# Burial Protocol - Roadmap

기준일: `2026-06-05`
기준 브랜치: `main`

---

## 0. 목적

이 문서는 현재 구현 상태를 기준으로 앞으로 해야 할 작업을 정리한다.
구현된 시스템 설명은 `01_gdd.md`, `02_systems_spec.md`, `03_data_and_state_spec.md`에 두고, 이 문서에는 완료/진행/보류/TODO와 우선순위만 둔다.

밸런스 수치 공식은 `05_balance_formula.md`를 기준으로 한다.
아이템 데이터 구조와 조건부 효과 스키마는 `03_data_and_state_spec.md`의 `Item / Effect Object Schema`를 기준으로 한다.

장비 체계는 아래 4분류를 기준으로 한다.

```text
Weapon   = 좌/우 슬롯 기본공격
Protocol = 드론 자동공격
Module   = 패시브 스킬
Item     = 누적 스탯 제공품
```

현재 코드의 `attack_module/function_module/enhance_module`은 legacy 구현명이며, 최종 설계 카테고리가 아니다.

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
- legacy attack_module 기반 공격 처리
- legacy melee/ranged/mechanic 공격 타입 처리
- Day 종료 후 intermission
- 낙하형 키오스크
- Day 상점 UI
- 상점 아이템 5개 롤
- legacy attack_module/function_module/enhance_module 구매 처리
- 아이템 객체 스키마의 `conditions/effects/apply_timing` 병행 수용
- `stat_query` 기반 조건부 스탯 보너스 1차 구현
- 조건부 상점 아이템 테스트 2종 검증
- XP와 레벨업 카드
- 레벨업 카드 17종 풀
- 레벨업 카드 5장 제시 방식
- 레벨업 카드 Normal/Silver/Gold/Platinum 희귀도
- Luck 기반 레벨업 희귀도 보정
- 레벨업 희귀도별 UI 색상/테두리/라벨 표시
- 근거리/원거리 공격력 분리 (`run_bonus_melee_attack_damage`, `run_bonus_ranged_attack_damage`)
- 공격 스타일/연출 스타일 시스템 (`AttackModuleStyleResolver`)
- 상점 아이템 랭크별 가격 티어링 (`SHOP_ITEM_RANK_FALLBACK_PRICES`)
- 런타임 스탯 증가
- HUD와 ESC 스탯 패널
- 저장 파일과 최고 기록 저장
- 밸런스 스냅샷/회귀 검증 스크립트 일부

주의:

- 위 목록은 현재 코드 동작 상태를 기록한 것이다.
- 최종 설계 기준은 `Weapon / Protocol / Module / Item`이다.
- legacy 구현을 유지한 채 신규 문서 기준을 먼저 정리한 상태다.

---

## 2. 완료된 최근 작업

### 2-1. 문서 장비 체계 재정리

완료:

- canonical 장비/성장 객체를 `Weapon / Protocol / Module / Item`으로 정리
- legacy `attack_module/function_module/enhance_module`을 migration 대상으로 명시
- `00_project_rules.md`, `01_gdd.md`, `02_systems_spec.md`, `03_data_and_state_spec.md`, `04_roadmap.md`, `05_balance_formula.md`를 새 분류 기준으로 갱신

의도:

- Codex가 낡은 “공격모듈 5개 장착” 구조를 최종 설계로 오해하지 않게 한다.
- 직접 조작 공격, 자동공격, 패시브 스킬, 누적 스탯 제공을 명확히 분리한다.

### 2-2. 아이템 객체 스키마 1차 기반

완료:

- `ShopItemDefinition`에 `conditions`, `effects`, `apply_timing` 필드 추가
- 기존 아이템에 새 필드가 없어도 안전하게 기본값 처리
- 기존 `effect_values`를 `effects = [{ type, value }]` 형태로 병행 변환
- `conditional_stat_bonus + stat_query` 평가 helper 추가
- `attack_damage_flat`, `attack_damage_percent`를 공격력 getter에 연결
- `attack_hit_side` 같은 공격 순간 조건은 TODO로 유지

검증:

- 기존 `stat_bonus` 아이템 정상
- 기존 legacy 공격모듈 구매/장착/합성 정상
- 조건부 테스트 아이템 2종 정상

migration 필요:

- 조건부 효과의 조건명은 Weapon/Protocol/Module 기준으로 재정리해야 한다.
- `all_attack_modules_type` 같은 legacy condition은 신규 condition으로 대체해야 한다.

### 2-3. 조건부 아이템 테스트

추가/검증 완료:

- `melee_purity_core`
  - 기존 기준: 모든 공격모듈이 melee일 때 공격력 percent 증가
  - 신규 기준: 좌/우 무기 또는 프로토콜의 `attack_type`/태그 조건으로 재정의 필요
- `module_focus_circuit`
  - 기존 기준: 장착 공격모듈 수가 일정 이상일 때 공격력 flat 증가
  - 신규 기준: 프로토콜 수, 모듈 수, 무기 조건 중 하나로 재정의 필요

### 2-4. 밸런스 스냅샷 스크립트

완료:

- `scripts/tests/balance_snapshot.gd` 추가/확장
- 기본 스탯, StageTable, BlockCatalog, ShopItemCatalog, 레벨업 카드 출력
- Day 1/10/20/30 기준 HP 비교
- 보스 HP/처치 시간 비교
- 상점 아이템 랭크별 문서 기준 비교
- 레벨업 희귀도 확률/효과값 출력

migration 필요:

- 스냅샷 출력 항목을 Weapon/Protocol/Module/Item 기준으로 재분류해야 한다.
- legacy attack_module DPS 출력은 무기/프로토콜 분리 이후 갱신해야 한다.

### 2-5. StageTable HP 배율 적용

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

### 2-6. 보스 Day 정합성 수정

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

### 2-7. 레벨업 카드 Normal 기준 정리

완료:

- 기존 레벨업 카드 수치를 `05_balance_formula.md`의 Normal 기준에 맞춰 정리
- 공격력, 공격속도, 최대 HP, 이동속도, 채굴속도, 공격범위, 치명타 확률, 점프력, 채굴범위 조정
- 방어력, HP 재생, 채굴 데미지는 기존 수치 유지

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

### 2-11. 공격 스타일 시스템

완료:

- `scripts/data/AttackModuleStyleResolver.gd` 추가
- legacy 공격모듈 데이터에 `attack_style`, `effect_style` 필드 처리
- melee (`slash`, `stab`, `pierce`, `cleave`, `smash`) / ranged (`shotgun`, `sniper`, `laser`, `rifle`, `revolver`) 스타일 분리
- `AttackModuleStyleResolver`가 attack_style별 shape, range growth 계수, projectile 옵션 등을 반환
- mechanic 모듈은 스타일 시스템 예외로 유지

migration 필요:

- 입력 기반 melee/ranged 스타일은 Weapon으로 이전한다.
- mechanic/auto 계열은 Protocol로 이전한다.
- 신규 데이터는 `attribute + attack_type + activation_mode + hit_model + hit_shape + effect_style` 기준으로 정리한다.

### 2-12. 근거리/원거리 공격력 분리

완료:

- `GameState.gd`에 `run_bonus_melee_attack_damage`, `run_bonus_ranged_attack_damage` 추가
- `get_melee_base_attack_damage()`, `get_ranged_base_attack_damage()` getter 추가
- `melee_atk_up`, `ranged_atk_up` 레벨업 카드 추가
- `reset_run()`에서 초기화 포함

신규 기준:

- 근거리/원거리 공격력은 특정 장비 계층이 아니라 공격 판정 태그에 적용한다.
- 무기와 프로토콜 모두 해당 태그를 가질 수 있으나, 밸런스상 적용 범위는 별도 결정한다.

### 2-13. 상점 아이템 랭크별 가격 티어링

완료:

- `GameConstants.gd`에 `SHOP_ITEM_RANK_FALLBACK_PRICES = {D:15, C:30, B:60, A:120, S:240}` 추가
- `GameState.get_effective_shop_item_price(item_id)` 구현
- `price_gold`가 없거나 0인 아이템은 랭크 기본 가격을 자동 적용
- `DayShopUI.gd`에서 가격 표시 시 유효 가격 getter 사용

### 2-14. 레벨업 카드 5장 제시

완료:

- `LevelUpUI`에서 카드 제시 수를 3장 -> 5장으로 확장
- `GameConstants.LEVEL_UP_CARD_COUNT` 기준

---

## 3. 현재 보류 중인 항목

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

### 3-3. 고급 조건부 효과

보류 사유:

- `stat_query` 기반 조건부 효과는 1차 검증 완료.
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
1. ShopItemCatalog의 기존 항목을 Weapon / Protocol / Module / Item으로 분류표 작성
2. legacy attack_module 중 입력 기반 공격은 Weapon 후보로 분리
3. legacy mechanic/auto 계열은 Protocol 후보로 분리
4. legacy function/enhance 계열은 Module 또는 Item으로 분리
5. Day pressure snapshot 기반 실제 플레이 테스트
6. normal/hard 문제 Day 구간을 StageTable 조정 후보로 분리
7. v2 spawn distribution snapshot의 위험 조합 weight 튜닝
8. v2 resolver live 전환 전 v1/v2 비교 리포트 재생성
9. 무기/프로토콜 DPS/피드백 플레이테스트 후 수치 조정 여부 결정
10. 상점 lock UX와 HUD 가독성 확인
11. 채굴 확장용 보물상자/크립 데이터 구조 초안 작성
12. 보물상자 보상 항목을 D~S 등급 보상 아이템 체계로 설계
```

---

## 5. 최우선 작업

### 5-1. legacy 장비 데이터 재분류

목표:

- 현재 `ShopItemCatalog.tres`의 `attack_module/function_module/enhance_module` 항목을 신규 카테고리로 분류한다.
- 실제 코드 변경 전, 어떤 항목이 무기/프로토콜/모듈/아이템인지 표로 확정한다.

분류 기준:

| 기존 성격 | 신규 분류 |
|---|---|
| 플레이어 입력으로 공격 생성 | Weapon |
| 자동 타겟팅/자동 공격 | Protocol |
| 직접 공격을 만들지 않는 패시브 룰 변경 | Module |
| 단순 스탯 증가/누적 성장 | Item |

산출물:

- 기존 item_id
- 현재 category
- 신규 category
- migration 난이도
- UI 영향
- 밸런스 영향

### 5-2. Weapon / Protocol 전투 기준 분리

목표:

- 직접 조작 공격과 자동공격의 밸런스 기준을 분리한다.
- 기존 공격모듈 DPS 스냅샷을 무기/프로토콜 기준으로 다시 읽을 수 있게 만든다.

작업:

- 좌/우 무기 슬롯의 기본 공격 주기 정의
- 프로토콜 5개 장착 시 기대 자동 DPS 예산 정의
- 무기와 프로토콜의 공격 대상 범위 정의
- 모래 피해/모래 제거 정책 재확인
- 크립 대응 시 무기와 프로토콜 역할 분리

주의:

- 프로토콜이 기본공격보다 항상 강하면 직접 조작 감각이 죽는다.
- 무기는 플레이어의 주 공격 정체성을 가져야 한다.
- 프로토콜은 안정적인 보조 처리력과 빌드 시너지를 담당해야 한다.

### 5-3. Module / Item 역할 분리

목표:

- 모듈과 아이템이 모두 “스탯 증가”처럼 보이지 않도록 역할을 분리한다.

기준:

| 효과 성격 | 우선 배치 |
|---|---|
| 단순 스탯 증가 | Item |
| 조건부 스탯 증가 | Module 또는 특수 Item |
| 장비 간 시너지 | Module |
| 공격 판정 변형 | Module |
| 경제 보너스 | Item |
| 소지 제한 없는 누적 성장 | Item |
| 소지 제한 있는 강한 룰 변경 | Module 또는 unique Item |

---

## 6. 근시일 내 작업

### 6-1. HUD / UI

- HUD 문자열 한글화
- 상점 UI 가독성 개선
- 좌/우 무기 슬롯 표시
- 드론 프로토콜 5슬롯 표시
- 패시브 모듈 5슬롯 표시
- 아이템 누적 목록 표시 방향 결정
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
- 무기별 공격속도 체감 점검
- 프로토콜 자동공격 체감 점검

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
- 무기 아이콘/공격 에셋 제작
- 프로토콜/드론 시각 에셋 제작
- 모듈 아이콘 제작
- 아이템 아이콘 제작
- 블록 재질별 비주얼 구분
- 모래 색상/질감 개선
- 키오스크 비주얼 개선
- HUD 스타일 정리
- 레벨업 카드 희귀도별 색상/테두리 정리
- 보물상자 등급별 이미지와 빛나는 벽블록 이펙트 정리
- 크립 계열 비주얼 방향 정리

### 7-2. 콘텐츠 확장

- 무기 종류 확장
- 프로토콜 종류 확장
- 모듈 종류 확장
- 아이템 종류 확장
- 조건부 효과 확장
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
- 캐릭터별 시작 무기/스탯 차별화

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
- Weapon / Protocol / Module / Item 데이터 완전 분리 미완성
- legacy `attack_module/function_module/enhance_module` 제거 미완성
- 좌/우 무기 슬롯 미구현
- 드론 프로토콜 슬롯 미구현
- 패시브 모듈 슬롯 미구현
- 아이템 소지 제한/unique 처리 미구현
- 상점 UI 최종 비주얼/한글화 미완성
- 무기/프로토콜/모듈/아이템 최종 밸런스 미확정
- 상점 아이템 세부 수치 조정 보류
- 고급 조건부 효과 context 미구현
- `weight_ratio_at_least` context 미구현
- `attack_hit_side` context 미구현
- 채굴 확장용 보물상자/크립 시스템 미구현
- 보물상자 등급별 D~S 보상 테이블 미정
- 크립 종류/효과/등장 조건 미정
- 블록 v2 spawn rule live 전환 여부 미정
- TSV -> TRES 파이프라인은 연결되어 있으나, live resolver 전환 전 추가 검증 필요
- 보스 보상 구조 미정
- 최종 아트 미적용

---

## 10. 개발 판단 원칙

### 10-1. 장비 4분류 우선 원칙

새 장비/성장 요소는 반드시 아래 중 하나로 먼저 분류한다.

```text
Weapon / Protocol / Module / Item
```

분류가 애매하면 아래 기준을 따른다.

- 플레이어 입력으로 공격을 생성하면 Weapon
- 드론이 자동으로 공격하면 Protocol
- 장착 슬롯을 차지하며 패시브 룰을 바꾸면 Module
- 기본적으로 무제한 소지되고 스탯을 제공하면 Item

### 10-2. 효과 객체 스키마 선행 원칙

조건부 효과는 객체 스키마를 먼저 정의하고, 데이터 기반으로 표현한다.

권장 순서:

```text
효과 객체 스키마 확정
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

새 효과는 가능한 한 데이터로 정의하고, 코드는 조건/효과/적용 타이밍 해석기를 확장한다.

### 10-3. 밸런스 개선과 블록 고도화 순서

권장 순서:

```text
장비 4분류 정리
→ 무기/프로토콜 수치 분리
→ 블록 material/size/type 스펙 정리
→ TSV 기반 size spawn rule / material-size weight rule 검증
→ Day별 실전 테스트와 pressure snapshot 비교
→ 채굴 확장 보상/리스크 시스템 설계
```

### 10-4. 환경대응 카드 원칙

레벨업 카드는 플레이어 본체 성장 중심으로 유지한다.

레벨업 카드에서 제외:

- 모래 직접 제거
- 모래 자동 정리
- 벽 복구
- 중량 직접 증가
- 특정 블록 제거
- Day 종료 시 환경 정리

환경대응 성격의 효과는 상점 아이템, 보물상자 보상, 특수 이벤트로 제한한다.

---

## 11. 다음 Codex 작업 추천

다음 Codex 작업은 아래 순서가 좋다.

```text
1. ShopItemCatalog.tres 전체 항목을 Weapon / Protocol / Module / Item으로 분류하는 리포트 작성
2. legacy attack_module 중 Weapon 후보와 Protocol 후보를 분리
3. legacy function_module/enhance_module 중 Module 후보와 Item 후보를 분리
4. 분류표 기준으로 UI/상점/상태 migration 영향도 작성
5. 무기 좌/우 슬롯 상태 모델 초안 작성
6. 프로토콜 5슬롯 상태 모델 초안 작성
7. 모듈 5슬롯 상태 모델 초안 작성
8. 아이템 stack/unique 소지 모델 초안 작성
9. Day pressure snapshot 기반 실제 플레이 테스트
10. normal/hard 문제 Day 구간을 StageTable 조정 후보로 분리
```

이 작업들은 우선 조사/비교표/데이터 구조 초안 중심으로 진행하고, 실제 수치 변경은 별도 판단 후 진행한다.
