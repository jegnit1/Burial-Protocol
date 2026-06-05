# Burial Protocol - Project Rules

기준일: `2026-06-05`
기준 브랜치: `main`

---

## 0. 목적

이 문서는 Burial Protocol 코드베이스에서 현재 적용해야 할 작업 기준을 정리한다.
기획 희망사항과 실제 코드 상태가 섞이지 않도록, 문서 작성 시 반드시 아래 원칙을 따른다.

- 현재 실행 가능한 코드
- 현재 확정된 설계 방향
- 아직 구현되지 않은 TODO
- legacy 호환명

위 네 가지를 같은 표현으로 섞지 않는다.

---

## 1. 진실의 기준

코드와 문서가 충돌하면 현재 실행 가능한 코드가 최종 기준이다.
다만 장비/전투 구조는 현재 코드에 legacy 명칭이 남아 있더라도, 신규 문서와 신규 작업은 이 문서의 `Weapon / Protocol / Module / Item` 분류를 기준으로 한다.

문서 갱신 시 우선 확인 순서:

1. 핵심 구현 파일
2. `docs/00_project_rules.md`
3. `docs/01_gdd.md`
4. `docs/02_systems_spec.md`
5. `docs/03_data_and_state_spec.md`
6. `docs/04_roadmap.md`
7. `docs/05_balance_formula.md`

문서 수정 전 최소 확인 대상:

- `scripts/autoload/GameConstants.gd`
- `scripts/autoload/GameData.gd`
- `scripts/autoload/GameState.gd`
- `scripts/data/BlockSpawnResolver.gd`
- `scripts/data/ShopItemCatalog.gd`
- `scripts/data/AttackModuleStyleResolver.gd`
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
- `data_tsv/*.tsv`

---

## 2. 현재 docs 구조

현재 docs는 아래 6개 canonical 문서를 기준으로 유지한다.

```text
docs/
  00_project_rules.md
  01_gdd.md
  02_systems_spec.md
  03_data_and_state_spec.md
  04_roadmap.md
  05_balance_formula.md
```

| 문서 | 역할 |
|---|---|
| `00_project_rules.md` | 작업 원칙, 문서 원칙, 반드시 지켜야 할 기준 |
| `01_gdd.md` | 게임 전체 기획과 현재 구현 상태 요약 |
| `02_systems_spec.md` | 실제 플레이 시스템 통합 스펙 |
| `03_data_and_state_spec.md` | 데이터 소유권, 저장/런타임 상태, signal 구조 |
| `04_roadmap.md` | TODO, 미구현, 다음 작업 우선순위 |
| `05_balance_formula.md` | 밸런스 수치 공식과 기준 예산 |

삭제된 문서 또는 사용하지 않는 문서명을 canonical 목록에 다시 추가하지 않는다.
특히 아래 표현은 문서 기준으로 폐기한다.

- `attack_module_system_spec.md`
- `06_attack_module_style_spec.md`
- `attack_module` 중심 장비 스펙 문서
- `function_module`, `enhance_module` 중심 장비 분류 문서

새 문서를 만들기 전에 먼저 위 6개 문서 중 어디에 흡수할지 판단한다.
장비/전투/성장 구조는 우선 `02_systems_spec.md`와 `03_data_and_state_spec.md`에 정리한다.

---

## 3. 장비/성장 객체 canonical 분류

Burial Protocol의 장비/성장 객체는 아래 4계층으로 구분한다.

| 계층 | 장착/소지 방식 | 핵심 역할 |
|---|---|---|
| `Weapon` / 무기 | 좌/우 슬롯에 장착 | 플레이어 기본공격 담당 |
| `Protocol` / 프로토콜 | 드론에 최대 5개 장착 | 자동공격 담당 |
| `Module` / 모듈 | 최대 5개 장착 | 패시브 스킬, 빌드 변형 담당 |
| `Item` / 아이템 | 기본 소지 제한 없음 | 스탯 제공, 누적 성장 담당 |

### 3-1. Weapon

무기는 플레이어가 직접 사용하는 기본공격 장비다.
좌/우 슬롯에 장착하며, 입력 기반 공격의 정체성을 결정한다.

원칙:

- 무기는 기본공격을 만든다.
- 무기는 좌/우 슬롯 중 하나에 장착된다.
- 무기는 공격 버튼 입력과 직접 연결된다.
- `melee`, `ranged`, `physical`, `energy`, `linear`, `explosion` 같은 공격 속성/유형은 우선 무기 데이터의 태그로 해석한다.

### 3-2. Protocol

프로토콜은 드론에 장착하는 자동공격 루틴이다.
기존 공격모듈 5개 장착 구조가 제공하던 다중 자동 공격 감각은 장기적으로 프로토콜 체계로 이동한다.

원칙:

- 프로토콜은 드론에 장착된다.
- 프로토콜 최대 장착 수는 5개다.
- 프로토콜은 공격키 입력과 무관하게 자동으로 발동한다.
- 프로토콜은 기본공격이 아니며, 무기 슬롯을 차지하지 않는다.

### 3-3. Module

모듈은 패시브 스킬 장착물이다.
직접 공격을 생성하기보다는 규칙을 바꾸거나 시너지를 제공한다.

원칙:

- 모듈 최대 장착 수는 5개다.
- 모듈은 패시브 효과, 조건부 효과, 빌드 변형을 담당한다.
- 모듈은 무기나 프로토콜의 성능을 바꿀 수 있다.
- 모듈 자체가 기본공격이나 자동공격의 주체가 되면 안 된다.

### 3-4. Item

아이템은 스탯을 제공하는 누적 성장 객체다.
기본적으로 소지 제한이 없지만, 강력한 특수 아이템은 개별 소지 제한을 가질 수 있다.

원칙:

- 아이템은 기본적으로 장착 슬롯을 차지하지 않는다.
- 아이템은 스탯 증가, 경제 보너스, 조건부 보너스를 제공한다.
- 특정 아이템만 `max_stack`, `unique`, `limited` 같은 제한을 가질 수 있다.
- 단순 스탯 증가는 모듈보다 아이템에 우선 배치한다.

---

## 4. legacy 용어 처리 원칙

현재 코드와 데이터에는 아래 legacy 표현이 남아 있을 수 있다.

| Legacy 표현 | 신규 문서 기준 |
|---|---|
| `attack_module` | `weapon` 또는 `protocol`로 재분류 대상 |
| `function_module` | 대부분 `module` 또는 특수 `item`으로 재분류 대상 |
| `enhance_module` | 대부분 `item`으로 재분류 대상 |
| `melee/ranged/mechanic attack_module` | `weapon/protocol`의 공격 방식 또는 발동 방식으로 재분류 |
| 공격모듈 5개 장착 | 프로토콜 5개 또는 모듈 5개와 혼동 금지 |

문서 작성 규칙:

- 신규 설계 설명에서는 `attack_module/function_module/enhance_module`을 사용하지 않는다.
- 코드 호환 설명이 필요한 경우 `legacy attack_module`처럼 명시한다.
- `공격모듈`이라는 표현을 `무기`, `프로토콜`, `모듈`의 포괄어처럼 사용하지 않는다.
- 기존 코드 이름을 바꾸지 않은 상태라면, 문서에는 반드시 “현재 구현명”과 “설계상 의미”를 분리해서 적는다.

---

## 5. 현재 프로젝트 기준

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
- legacy 상점 구매/장착/런 효과 처리
- 경험치, 레벨업 카드, 런타임 스탯 증가
- HUD, 스킬 슬롯, ESC 스탯 확인 UI

주의:

- 위 구현 상태가 곧 최종 장비 분류를 의미하지 않는다.
- 장비 분류는 본 문서의 `Weapon / Protocol / Module / Item` 기준으로 정리한다.

---

## 6. 데이터 소유권 원칙

### 6-1. GameConstants

`GameConstants.gd`는 전역 상수와 정적 유틸만 가진다.

포함 가능:

- 월드 크기, HUD 레이아웃, 색상
- 플레이어 이동/공격/채굴/대시/벽타기 수치
- 무기 슬롯 수, 프로토콜 슬롯 수, 모듈 슬롯 수
- 중량 한도와 표시 스케일
- 피격 팝업, 키오스크, 페이드 관련 상수
- 난이도 옵션
- 입력 바인딩
- 레벨업 카드 정의
- 상점 랭크별 fallback 가격

포함 금지:

- 블록 콘텐츠 테이블
- 무기/프로토콜/모듈/아이템 개별 데이터 본문
- Stage/Day 콘텐츠 테이블

### 6-2. 콘텐츠 데이터

콘텐츠 데이터는 `.tres`, `data_tsv`, 데이터 해석 스크립트가 소유한다.

- 블록 카탈로그: `data/blocks/BlockCatalog.tres`
- Stage/Day 테이블: `data/stages/StageTable.tres`
- 상점/장비/아이템 카탈로그: `data/items/ShopItemCatalog.tres` 또는 향후 분리 카탈로그
- 블록 스폰 해석: `scripts/data/BlockSpawnResolver.gd`
- 상점 롤/랭크 해석: `scripts/data/ShopItemCatalog.gd`

향후 데이터 분리 방향:

```text
WeaponCatalog
ProtocolCatalog
ModuleCatalog
ItemCatalog
```

단, 실제 파일 분리는 코드 변경 작업에서 별도 판단한다.
문서에서는 먼저 의미 분리를 명확히 한다.

---

## 7. 상태 소유권 원칙

### 7-1. GameState

`GameState.gd`는 아래를 소유한다.

- 저장 데이터
- 현재 런의 골드, HP, XP, 레벨
- 런타임 스탯 보너스
- 무기/프로토콜/모듈/아이템 보유 및 장착 상태
- 현재 런 효과
- 최종 스탯 getter
- HUD/메뉴용 signal

현재 코드에 남아 있는 legacy 필드는 새 의미로 매핑해서 문서화한다.
예를 들어 `equipped_attack_modules`는 최종 설계상 무기/프로토콜/모듈 중 어디에 해당하는지 재분류 대상이다.

### 7-2. Main

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

### 7-3. Player

`Player.gd`는 플레이어 순간 동작 상태를 가진다.

예:

- 위치/속도/충돌
- 점프/코요테/버퍼
- 대시 상태와 쿨다운
- 배터리와 벽타기 상태
- 무기 입력 쿨다운
- 장착 장비의 시각 표현 상태

---

## 8. 문서 작성 원칙

### 8-1. 구현/설계/TODO 분리

문서에는 아래 세 층을 섞지 않는다.

- 현재 구현되어 동작하는 것
- 확정 설계지만 아직 코드 이전이 필요한 것
- 향후 TODO 또는 아이디어

장비 체계 문서에서는 특히 아래처럼 적는다.

```text
현재 구현명: legacy attack_module
설계상 의미: Weapon 또는 Protocol로 재분류 예정
상태: migration 필요
```

### 8-2. 수치와 상수

수치가 고정이면 실제 상수명과 값을 적는다.

예:

- `PLAYER_MAX_HEALTH = 100`
- `BLOCK_HP_PER_UNIT = 10.0`
- `WEIGHT_LIMIT_SAND_CELLS = 2400`
- 표시 중량 = `240.0 KG`
- `DAY_SHOP_ITEM_COUNT = 5`
- `WEAPON_SLOT_COUNT = 2` 또는 좌/우 슬롯
- `PROTOCOL_SLOT_COUNT = 5`
- `MODULE_SLOT_COUNT = 5`
- 키오스크 유예 = `3.0초`
- 키오스크 지연 투하 = `1.25초`

상수가 아직 코드에 없다면 `권장 상수명` 또는 `설계 기준`으로 표시한다.

### 8-3. 문서 변경 시 함께 확인할 문서

| 변경 항목 | 확인 문서 |
|---|---|
| 입력 체계 | `02_systems_spec.md` |
| Day/intermission/shop 흐름 | `02_systems_spec.md` |
| HUD/ESC UI | `02_systems_spec.md` |
| 스탯/레벨업 카드 | `02_systems_spec.md`, `03_data_and_state_spec.md`, `05_balance_formula.md` |
| 데이터 구조 | `03_data_and_state_spec.md` |
| 블록 material/size/type 구조 | `02_systems_spec.md`, `03_data_and_state_spec.md` |
| Weapon/Protocol/Module/Item 구조 | `02_systems_spec.md`, `03_data_and_state_spec.md`, `05_balance_formula.md` |
| 상점 카테고리 | `02_systems_spec.md`, `03_data_and_state_spec.md` |
| TODO/후순위 작업 | `04_roadmap.md` |

---

## 9. 현재 반드시 지켜야 하는 구현 방향

### 9-1. 플레이 가능한 루프를 깨지 않는다

우선 보존 대상:

- 이동 감각
- 기본공격 입력 리듬
- 자동공격 발동 리듬
- 채굴 리듬
- 낙하 블록 처리
- 모래 시뮬레이션
- Day 전환 루프
- 상점 구매/Next Day 루프
- HUD 가독성

### 9-2. 장비 체계 이전은 단계적으로 한다

장비 체계는 문서 기준을 먼저 확정한 뒤, 코드/데이터를 단계적으로 이전한다.

권장 순서:

```text
1. docs 기준 정리
2. 현재 ShopItemCatalog 항목을 Weapon / Protocol / Module / Item으로 분류표 작성
3. UI 표시명과 내부 category의 호환 계층 추가
4. 신규 카탈로그 또는 category 마이그레이션
5. legacy attack_module 의존 제거
```

### 9-3. Stage 전환 기본 규칙

- Day 종료 시 바로 다음 Day로 자동 진행하지 않는다.
- intermission 상태로 진입한다.
- 마지막 활성 블록 정리 후 키오스크가 지연 투하된다.
- 약 `3초` 뒤 채굴만 정지된다.
- 키오스크 상호작용으로 상점 UI를 연다.
- 상점에서 아이템을 구매하거나 스킵할 수 있다.
- 상점 UI에서 `Next Day`로 다음 Day를 시작한다.
- 기본적으로 채굴 벽은 초기화하지 않는다.
- 벽 초기화는 특정 효과가 예약했을 때만 실행한다.

### 9-4. 모래 처리 원칙

- 자연 물리 반응과 플레이어의 모래 밀림은 유지한다.
- intermission 잠금 이후 막는 것은 채굴 입력/채굴 결과다.
- 벽을 복구하지 않는 기본 경로에서는 모래 재배치를 하지 않는다.
- 벽 복구 예외 경로가 실행될 때만 모래 총량 보존 검증을 수행한다.

---

## 10. 현재 미구현 또는 제한된 영역

아래는 아직 완성 시스템으로 보지 않는다.

- 설정 메뉴의 실제 옵션
- 메타 성장의 실질적 효과
- 업적의 실질적 효과
- 인벤토리/도감성 UI
- 블록 특수 결과의 모든 효과 구현
- Weapon / Protocol / Module / Item 데이터 완전 분리
- legacy `attack_module/function_module/enhance_module` 제거
- 프로토콜 드론 장착 UI
- 모듈 패시브 슬롯 UI
- 아이템 소지 제한/unique 처리
- 상점 UI의 최종 비주얼/한글화/UX

문서에 이 항목들을 적을 때는 반드시 `미구현`, `TODO`, `placeholder`, `임시 구현`, `migration 필요` 중 하나로 표시한다.

---

## 11. 체크리스트

게임플레이나 UI를 바꾼 뒤 문서를 갱신할 때 최소 확인 항목:

- 입력맵이 문서와 일치하는가
- HUD와 ESC 패널 표시값이 실제 getter와 일치하는가
- 레벨업 카드 풀과 스탯 패널 설명이 어긋나지 않는가
- Day 종료 후 intermission 흐름 설명이 실제와 맞는가
- 키오스크 등장 방식과 상호작용 조건이 맞는가
- 상점 아이템 롤/구매/제거 흐름이 실제와 맞는가
- 무기 좌/우 슬롯 규칙이 문서와 일치하는가
- 프로토콜 최대 5개 장착 규칙이 문서와 일치하는가
- 모듈 최대 5개 장착 규칙이 문서와 일치하는가
- 아이템 기본 소지 제한 없음 원칙이 문서와 일치하는가
- legacy `attack_module` 표현을 신규 설계처럼 쓰지 않았는가
- 벽 초기화 기본 규칙이 `유지`로 적혀 있는가
- 블록 콘텐츠 데이터 소유권이 `.tres` 기준으로 적혀 있는가
- 블록 모델이 `Material x Size + optional Type`으로 적혀 있는가

---

## 12. 현재 개발 방향

현재 프로젝트는 실행 가능한 코어 루프를 보존하면서 장비/성장 구조를 명확하게 재정리하는 방향을 우선한다.

핵심 방향:

- 코드와 문서를 계속 동기화한다.
- 장비 체계는 `Weapon / Protocol / Module / Item` 기준으로 정리한다.
- 기존 `attack_module/function_module/enhance_module` 용어는 legacy 구현명으로만 취급한다.
- 데이터는 `.gd` 규칙과 `.tres` 콘텐츠로 분리한다.
- 런타임 스탯과 UI 가시성을 강화한다.
- Day 종료 -> 상점 -> Next Day 루프를 안정화한다.
- 메타 시스템은 placeholder 범위를 명확히 유지한다.
