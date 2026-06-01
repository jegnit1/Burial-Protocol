# Burial Protocol - Roadmap

기준일: `2026-06-01`
기준 브랜치: `main`

---

## 0. 목적

이 문서는 앞으로 해야 할 작업과 우선순위를 정리한다.
신규 장비 시스템의 세부 기준은 `06_attack_modules.md`, 데이터 소유권은 `03_data_and_state_spec.md`, 공식은 `05_balance_formula.md`를 따른다.

---

## 1. 현재 플레이 가능한 코어

현재 실제 연결된 영역:

- Title -> MainHub -> Main -> Result
- 30 Day 런과 보스 Day
- 블록 파괴/분해
- 모래 생성, 자연 시뮬레이션, 중량 실패
- 우클릭 좌우 벽 채굴
- 좌클릭 무기 기반 모래 제거
- 점프, 추가 점프, Shift 대시
- Day 종료 후 intermission
- 마지막 활성 블록 정리 후 키오스크 투하
- 키오스크 투하 직후 유해물질 카운트다운과 단계별 고정 피해
- ESC pause, 상점 UI, Next Day 유해물질 정지/초기화
- Day 상점 5개 롤, 가격, 구매, 잠금, 리롤
- XP, 레벨업 카드 5장, 희귀도
- HUD, ESC 스탯 패널, 저장 파일

---

## 2. Legacy 전투 런타임

현재 실행 코드는 아직 아래 구조를 사용한다.

- 공격모듈 5개 장착 상수
- `attack_module`, `function_module`, `enhance_module`
- 과도기 `weapon`, `part`, `artifact` 별칭
- `melee`, `ranged`, `mechanic`
- 캐릭터 주변 공전 비주얼
- `run_bonus_melee_attack_damage`
- `run_bonus_ranged_attack_damage`
- `melee_atk_up`, `ranged_atk_up`

이 구조는 신규 장비 시스템과 함께 유지할 최종 구조가 아니다.
마이그레이션 중에도 legacy 공격모듈 5개 장착과 신규 무기 2개 장착을 동시에 활성화하지 않는다.

---

## 3. 장비 개편 Phase

### Phase 1. 문서와 충돌 분석

현재 작업 범위:

- 신규 장비 설계 문서화
- 기존 코드 충돌 지점 확인
- 데이터, 상태, 밸런스, 로드맵 문서 갱신
- 대규모 전투 로직 변경 금지

### Phase 2. 데이터 스키마

상태: `1차 완료`

- `ShopItemDefinition`에 신규 장비 공통 메타데이터 병행 수용
- 카테고리 `weapon`, `drone`, `drone_protocol`, `passive_module` 확정
- 속성 `attribute`와 유형 `attack_type` 필드 추가
- legacy TSV와 `.tres`에 신규 장비 분류 병행 저장
- 무기/프로토콜 base cooldown과 프로토콜 행동 필드 추가
- 패시브 condition/effect/apply_timing 확장 기반 추가
- 아이템 ID별 하드코딩 금지

현재 raw `item_category`는 Phase 3~5 런타임 호환을 위해 legacy 값을 유지한다.
신규 분류는 `equipment_category`로 병행 저장하며, 런타임 전환이 끝난 뒤 최종 카테고리로 승격한다.

### Phase 3. GameState

상태: `1차 완료`

- 무기 좌/우 슬롯 상태 추가
- 기본 드론 상태 추가
- 드론 프로토콜 5슬롯 추가
- 패시브 모듈 5슬롯 추가
- 신규 스탯 getter 추가
- 근거리/원거리 공격력과 legacy 레벨업 카드 제거 또는 deprecated 처리
- 신규 signal과 스탯 패널 snapshot 갱신

현재 `GameState`의 장비 원본 상태는 신규 슬롯 구조다.
`Player.gd`는 좌·우 무기와 드론 프로토콜을 신규 슬롯 기준으로 소비한다.

### Phase 4. Player / Main 전투 트리거

상태: `1차 완료`

- 좌클릭 시 장착 무기 각각 독립 쿨타임 처리
- 기본 드론 표시
- 드론 프로토콜 자동 행동과 독립 쿨타임 처리
- 공격속도는 무기 쿨타임에만 적용
- 드론 쿨타임 감소는 프로토콜에만 적용
- 우클릭 채굴 유지
- 공전 공격모듈 비주얼 제거

현재 연결된 프로토콜 행동:

- `combat_drone`, `auto_attack`: 가까운 활성 블록 단일 타격
- `sand_cleaner`: 가까운 모래 셀 제거
- `aura_damage`: 플레이어 주변 영역 피해와 펄스 표시

### Phase 5. 상점 / UI

상태: `1차 완료`

- `DayShopUI` 장비 카테고리 표시 갱신
- 무기 2슬롯 장착/교체 UI
- 드론 1슬롯 표시
- 드론 프로토콜 5슬롯 UI
- 패시브 모듈 5슬롯 UI
- 기존 가격, 잠금, 리롤, 구매 목록 제거 흐름 보존

현재 적용 범위:

- legacy 원본 카테고리를 `weapon`, `drone_protocol`, `passive_module` 런타임 카테고리로 정규화
- 무기는 빈 슬롯 우선 장착, 가득 찬 경우 선택한 좌·우 슬롯 교체
- 드론 프로토콜은 중복 장착 허용, 가득 찬 경우 선택 슬롯 교체
- 패시브 모듈은 5슬롯까지 데이터 기반 효과 적용
- 패시브 모듈은 선택 슬롯 교체와 source-instance 효과 제거 후 재적용 지원

### Phase 6. 회귀와 밸런스

상태: `1차 완료`

- legacy 공격모듈 snapshot 테스트 교체
- 무기 DPS와 드론 프로토콜 DPS snapshot 추가
- 레벨업 카드 풀 회귀 확인
- 상점 잠금/리롤/구매 회귀 확인
- Day/intermission/채굴/유해물질 회귀 확인
- 신규 장비 UI 실화면 확인

1차 적용 결과:

- 무기 `45행`, 드론 프로토콜 `16행` DPS snapshot 생성
- 패시브 5슬롯 장착, 교체 대상 필수 처리, source-instance 효과 교체 회귀 통과
- 키오스크 등장 이후 유해물질 시작, pause 정지, 단계별 고정 피해, Next Day 초기화 회귀 통과
- 기존 Day 압력과 스폰 분포 Monte Carlo snapshot 재생성

### Phase 7. 모래 제거 개편

상태: `1차 완료`

- 우클릭 채굴을 좌우 벽 전용으로 제한
- 원본 블록 최종 HP 기반 모래 셀 개별 float HP 적용
- 근접 shape, 히트스캔, 투사체 sweep에 무기 피해 `10%` 적용
- 일반 드론 프로토콜 모래 피해 차단
- `sand_cleaner`는 별도 특수 제거 효과로 유지
- 모래 제거 골드와 골드 팝업 없음 확인
- 기존 모래 제거 XP 누적 정책 유지
- `scripts/tests/SandRemovalOverhaulSnapshot.tscn` 회귀 추가

---

## 4. 다음 Phase 수정 파일

우선 검토 대상:

- `scripts/data/ShopItemDefinition.gd`
- `scripts/data/ShopItemCatalog.gd`
- `scripts/data/ShopItemResourceCatalog.gd`
- `scripts/autoload/GameData.gd`
- `scripts/autoload/GameConstants.gd`
- `scripts/autoload/GameState.gd`
- `scenes/player/Player.gd`
- `scenes/main/Main.gd`
- `scenes/ui/DayShopUI.gd`
- `scenes/ui/PauseMenu.gd`
- `scenes/ui/HUD.gd`
- `data/items/ShopItemCatalog.tres`
- `data_tsv/attack_module_items.tsv`
- `data_tsv/function_module_items.tsv`
- `data_tsv/enhance_module_items.tsv`

회귀 테스트 검토 대상:

- `scripts/tests/equipment_dps_snapshot.gd`
- `scripts/tests/balance_snapshot.gd`
- `scripts/tests/verify_conditional_shop_items.gd`
- `scripts/tests/verify_shop_lock_roll.gd`

---

## 5. 구현 리스크

- 카탈로그의 신규 카테고리 승격은 완료했다. legacy `part`, `artifact` 호환 분기는 후속 정리 대상이다.
- `GameState.gd`가 공격모듈 장착, 구매, 합성, 조건부 효과, 스탯 패널을 함께 소유한다. 단계별 이전이 필요하다.
- `Player.gd`와 `Main.gd`가 `melee/ranged/mechanic` 분기를 직접 사용한다.
- 조건부 아이템 데이터는 신규 무기/속성/유형 조건식으로 전환했다. legacy 조건식 별칭은 과도기 호환용으로만 유지한다.
- 기존 테스트가 공격모듈 DPS와 합성을 전제로 한다.
- 드론 쿨타임 감소를 레벨업 기본 풀에 실수로 넣으면 희귀 스탯 설계가 무너진다.
- 우측 무기 슬롯을 우클릭에 연결하면 채굴 입력과 충돌한다.
- legacy 5슬롯과 신규 2슬롯을 함께 켜면 구매, HUD, 쿨타임 상태가 이중화된다.

---

## 6. 장비 개편 이후 작업

- 블록 material/size/type 데이터 고도화
- Day별 블록 HP/스폰/모래 압박 계측
- 채굴 확장: 보물상자와 크립
- HUD와 상점 UI 한글화/가독성 개선
- 모래 렌더링 고도화
- 최종 아트 적용
- 메타 성장과 업적 실효과

---

## 7. 개발 판단 원칙

- 현재 플레이 가능한 Day, 채굴, 모래, intermission, 상점 흐름을 보존한다.
- 장비 콘텐츠는 데이터로 정의한다.
- 패시브 효과는 condition/effect/apply_timing 해석기로 확장한다.
- 아이템 ID별 특수 분기를 추가하지 않는다.
- 신규 장비 상태와 legacy 공격모듈 상태를 동시에 실제 전투 소스로 사용하지 않는다.
- 실제 수치 튜닝은 데이터 스키마와 런타임 마이그레이션 후 진행한다.
