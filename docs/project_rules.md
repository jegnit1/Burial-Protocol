# Burial Protocol - Project Rules

## 0. 목적

이 문서는 Burial Protocol 코드베이스에서 현재 실제로 적용 중인 작업 기준을 정리한다.
기획 희망사항이나 장기 아이디어가 아니라, 지금 실행 가능한 코드와 문서를 어떤 원칙으로 맞춰야 하는지 기록한다.

기준일: `2026-04-24`
기준 브랜치: `main`

---

## 1. 진실의 기준

코드와 문서가 충돌하면 현재 실행 가능한 코드가 최종 기준이다.
문서 갱신 시 우선 확인 순서는 아래와 같다.

1. 핵심 구현 파일
2. `docs/project_rules.md`
3. `docs/gdd.md`
4. `docs/02_systems_spec.md`
5. `docs/03_data_and_state_spec.md`
6. `docs/04_roadmap.md`

기존의 세부 스펙 문서들은 위 통합 문서로 흡수한다.
새 기능 문서를 추가하기보다, 우선 기존 통합 문서의 해당 섹션을 갱신한다.

문서 수정 전 최소 확인 대상:

- `scripts/autoload/GameConstants.gd`
- `scripts/autoload/GameData.gd`
- `scripts/autoload/GameState.gd`
- `scripts/data/BlockSpawnResolver.gd`
- `scripts/data/ShopItemCatalog.gd`
- `scenes/main/Main.gd`
- `scenes/player/Player.gd`
- `scenes/blocks/FallingBlock.gd`
- `scenes/world/WorldGrid.gd`
- `scenes/world/SandField.gd`
- `scenes/world/DayKiosk.gd`
- `scenes/ui/HUD.gd`
- `scenes/ui/DayShopUI.gd`
- `scenes/ui/PauseMenu.gd`
- `scenes/ui/LevelUpUI.gd`
- `data/blocks/BlockCatalog.tres`
- `data/stages/StageTable.tres`
- `data/items/ShopItemCatalog.tres`

---

## 2. 현재 docs 구조

현재 docs는 아래 5개 문서를 기준으로 유지한다.

```text
docs/
  project_rules.md
  gdd.md
  02_systems_spec.md
  03_data_and_state_spec.md
  04_roadmap.md
```

각 문서 역할:

| 문서 | 역할 |
|---|---|
| `project_rules.md` | 작업 원칙, 문서 원칙, 반드시 지켜야 할 기준 |
| `gdd.md` | 게임 전체 기획과 현재 구현 상태 요약 |
| `02_systems_spec.md` | 실제 플레이 시스템 통합 스펙 |
| `03_data_and_state_spec.md` | 데이터 소유권, 저장/런타임 상태, signal 구조 |
| `04_roadmap.md` | TODO, 미구현, 다음 작업 우선순위 |

문서를 새로 만들기 전에 먼저 위 5개 중 어디에 들어가야 하는지 판단한다.

---

## 3. 현재 프로젝트 기준

- 엔진: Godot `4.6`
- 언어: `GDScript`
- 기본 해상도 기준: `1920 x 1080`
- 월드 단위: `1U = 64px`
- 월드 폭: `30칸`
- 좌우 채굴 벽: 각 `10칸`
- 중앙 전장: `10칸`
- 월드 높이: `200칸`
- 총 Day 수: `30`
- 기본 Day 시간: `40초`

현재 Burial Protocol은 아래 요소가 실제로 연결된 플레이 가능한 세로형 생존 루프 상태다.

- 낙하 블록 전투
- 모래 시뮬레이션과 중량 실패
- 좌우 고정벽 채굴
- 마우스 방향 공격과 채굴
- 점프, 추가 점프, 대시, 배터리 기반 벽타기
- Day 진행과 intermission
- 키오스크 기반 Day 상점
- 상점 아이템 5개 롤
- 공격모듈 구매, 즉시 장착, 중복 장착, 합성
- 기능 모듈과 강화 모듈 구매
- 경험치, 레벨업 카드, 런타임 스탯 증가
- HUD, 스킬 슬롯, ESC 스탯 확인 UI

---

## 4. 데이터 소유권 원칙

### 4-1. `GameConstants.gd`는 전역 상수와 정적 유틸만 가진다

`GameConstants.gd`는 아래 범주의 상수와 유틸을 가진다.

- 월드 크기, HUD 레이아웃, 색상
- 플레이어 이동/공격/채굴/대시/벽타기 수치
- 공격모듈 최대 장착 수와 등급 배율
- 중량 한도와 표시 스케일
- 피격 팝업, 키오스크, 페이드 관련 상수
- 난이도 옵션
- 입력 바인딩
- 레벨업 카드 정의

### 4-2. 콘텐츠 데이터는 `.tres`와 데이터 스크립트가 소유한다

콘텐츠 데이터는 코드 상수 딕셔너리로 흩뿌리지 않는다.
현재 주요 진입점은 `scripts/autoload/GameData.gd`다.

- 블록 카탈로그: `data/blocks/BlockCatalog.tres`
- Stage/Day 테이블: `data/stages/StageTable.tres`
- 상점 아이템 카탈로그: `data/items/ShopItemCatalog.tres`
- 블록 스폰 해석: `scripts/data/BlockSpawnResolver.gd`
- 상점 롤/랭크 해석: `scripts/data/ShopItemCatalog.gd`

### 4-3. 블록 개념 모델

최신 기준 블록은 아래 구조를 따른다.

- Block Material = 재질/성질
- Block Size = 가로/세로 크기
- Block Type = 선택적으로 붙는 affix/modifier
- Runtime Block = `Material x Size + optional Type`

즉, 기존의 단순 `Base + Type` 설명은 오래된 표현이다.
문서에서는 가능하면 `material`, `size`, `type` 용어를 우선 사용한다.
단, 기존 코드 호환용으로 `get_block_base_definition()` 같은 이름이 남아 있을 수 있으므로 문서에는 호환 레거시 명칭으로만 표시한다.

### 4-4. 상점 아이템 모델

상점 아이템은 현재 아래 3개 카테고리를 가진다.

- `attack_module`
- `function_module`
- `enhance_module`

상점은 더 이상 단순 placeholder가 아니다.
아이템 롤, 가격 표시, 구매, 골드 차감, 구매한 항목 제거, 공격모듈 즉시 장착/합성, 기능/강화 모듈 등록이 실제로 연결되어 있다.

---

## 5. 상태 소유권 원칙

### 5-1. `GameState.gd`

`GameState.gd`는 아래를 소유한다.

- 저장 데이터
- 현재 런의 골드, HP, XP, 레벨
- 런타임 스탯 보너스
- 공격모듈 보유/장착 상태
- 기능 모듈/강화 모듈 보유 상태
- 현재 런 아이템과 효과
- 최종 스탯 getter
- HUD/메뉴용 signal

### 5-2. `Main.gd`

전투 루프와 Day 전환 플래그는 `Main.gd`가 소유한다.

예:

- `_is_day_active`
- `_is_intermission`
- `_is_intermission_locked`
- `_is_next_day_transitioning`
- `_shop_ui_open`
- `_waiting_for_day_kiosk`
- `_pending_wall_reset_for_next_day`
- `_current_shop_item_ids`
- `_has_shop_inventory_for_intermission`

즉, 런타임 공용 수치와 저장은 `GameState`, 씬 내부 진행 플래그는 `Main`이 맡는다.

### 5-3. `Player.gd`

`Player.gd`는 아래처럼 플레이어 고유 런타임 상태를 가진다.

- 위치/속도/충돌
- 점프/코요테/버퍼
- 대시 상태와 쿨다운
- 배터리와 벽타기 상태
- 공격모듈별 쿨다운
- 공격모듈 시각 공전/타격 연출

---

## 6. 문서 작성 원칙

### 6-1. 구현된 것과 미구현을 분리한다

문서에는 아래 세 층을 섞지 않는다.

- 현재 구현되어 동작하는 것
- placeholder 또는 임시 구현
- 향후 TODO

예를 들어 현재 상점은 구매 기능이 구현되어 있다.
따라서 `상점 구매 placeholder`라고 쓰면 안 된다.
다만 상점 UI 비주얼, 밸런스, 상품 구성은 계속 조정 대상으로 적을 수 있다.

### 6-2. 수치가 고정이면 실제 상수명과 값을 적는다

예:

- `PLAYER_MAX_HEALTH = 100`
- `BLOCK_DAMAGE_PER_UNIT = 10`
- `WEIGHT_LIMIT_SAND_CELLS = 2400`
- 표시 중량 = `240.0 KG`
- `DAY_SHOP_ITEM_COUNT = 5`
- `ATTACK_MODULE_MAX_EQUIPPED = 5`
- 키오스크 유예 = `3.0초`
- 키오스크 지연 투하 = `1.25초`

### 6-3. 문서 변경 시 통합 문서를 함께 맞춘다

아래 항목이 바뀌면 관련 통합 문서를 확인한다.

- 입력 체계: `02_systems_spec.md`
- Day/intermission/shop 흐름: `02_systems_spec.md`
- HUD/ESC UI: `02_systems_spec.md`
- 스탯/레벨업 카드: `02_systems_spec.md`, `03_data_and_state_spec.md`
- 데이터 구조: `03_data_and_state_spec.md`
- 블록 material/size/type 구조: `02_systems_spec.md`, `03_data_and_state_spec.md`
- 공격모듈 장착/합성 규칙: `02_systems_spec.md`, `03_data_and_state_spec.md`
- 상점 아이템 카테고리: `02_systems_spec.md`, `03_data_and_state_spec.md`
- TODO/후순위 작업: `04_roadmap.md`

---

## 7. 현재 반드시 지켜야 하는 구현 방향

### 7-1. 현재 플레이 가능한 루프를 깨지 않는다

우선 보존 대상:

- 이동 감각
- 공격모듈 발동 리듬
- 채굴 리듬
- 낙하 블록 처리
- 모래 시뮬레이션
- Day 전환 루프
- 상점 구매/Next Day 루프
- HUD 가독성

### 7-2. Stage 전환 기본 규칙

현재 기준 기본 Stage 전환은 아래와 같다.

- Day 종료 시 바로 다음 Day로 자동 진행하지 않는다
- intermission 상태로 진입한다
- 마지막 활성 블록 정리 후 키오스크가 지연 투하된다
- 약 `3초` 뒤 채굴만 정지된다
- 키오스크 상호작용으로 상점 UI를 연다
- 상점에서 아이템을 구매하거나 스킵할 수 있다
- 상점 UI에서 `Next Day`로 다음 Day를 시작한다
- 기본적으로 채굴 벽은 초기화하지 않는다
- 벽 초기화는 특정 효과가 `queue_wall_reset_for_next_day()`를 호출할 때만 실행한다

### 7-3. 모래 처리 원칙

- 자연 물리 반응과 플레이어의 모래 밀림은 유지한다
- intermission 잠금 이후 막는 것은 채굴 입력/채굴 결과다
- 벽을 복구하지 않는 기본 경로에서는 모래 재배치를 하지 않는다
- 벽 복구 예외 경로가 실행될 때만 모래 총량 보존 검증을 수행한다

---

## 8. 현재 미구현 또는 제한된 영역

아래는 아직 완성 시스템으로 보지 않는다.

- 설정 메뉴의 실제 옵션
- 메타 성장의 실질적 효과
- 업적의 실질적 효과
- 인벤토리/도감성 UI
- 블록 특수 결과의 모든 효과 구현
- 공격모듈 개별 밸런스 확정
- 오라형 공격모듈 세부 동작
- 상점 UI의 최종 비주얼/한글화/UX

문서에 이 항목들을 적을 때는 반드시 `미구현`, `TODO`, `placeholder`, `임시 구현` 중 하나로 표시한다.

---

## 9. 체크리스트

게임플레이나 UI를 바꾼 뒤 문서를 갱신할 때 최소 확인 항목:

- 입력맵이 문서와 일치하는가
- HUD와 ESC 패널 표시값이 실제 getter와 일치하는가
- 레벨업 카드 풀과 스탯 패널 설명이 어긋나지 않는가
- Day 종료 후 intermission 흐름 설명이 실제와 맞는가
- 키오스크 등장 방식과 상호작용 조건이 맞는가
- 상점 아이템 롤/구매/제거 흐름이 실제와 맞는가
- 공격모듈 최대 장착 수와 합성 규칙이 실제와 맞는가
- 벽 초기화 기본 규칙이 `유지`로 적혀 있는가
- 블록 콘텐츠 데이터 소유권이 `.tres` 기준으로 적혀 있는가
- 블록 모델이 `Material x Size + optional Type`으로 적혀 있는가

---

## 10. 현재 개발 방향

현재 프로젝트는 대규모 재설계보다, 실행 가능한 코어 루프를 보존하면서 시스템을 하나씩 연결하는 방향을 우선한다.

핵심 방향:

- 코드와 문서를 계속 동기화한다
- 데이터는 `.gd` 규칙과 `.tres` 콘텐츠로 분리한다
- 런타임 스탯과 UI 가시성을 강화한다
- Day 종료 -> 상점 -> Next Day 루프를 안정화한다
- 공격모듈/상점/블록 데이터 구조를 기획 확장 가능한 형태로 유지한다
- 메타 시스템은 placeholder 범위를 명확히 유지한다
