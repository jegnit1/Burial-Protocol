# Burial Protocol - Project Rules

## 0. 목적

이 문서는 Burial Protocol 코드베이스에서 현재 실제로 적용 중인 작업 기준을 정리한다.
기획 희망사항이나 장기 아이디어가 아니라, 지금 코드와 문서를 어떤 원칙으로 맞춰야 하는지 기록하는 문서다.

기준일: `2026-04-20`

---

## 1. 진실의 기준

코드와 문서가 충돌하면, 현재 실행 가능한 코드가 최종 기준이다.
문서 갱신 시 우선 확인해야 하는 순서는 아래와 같다.

1. 핵심 구현 파일
2. `docs/project_rules.md`
3. `docs/game_structure_spec.md`
4. `docs/gameplay_systems_spec.md`
5. `docs/base_state_spec.md`
6. `docs/phase1_tasks.md`
7. `docs/burial_protocol_run_hud_ui_improvement.md`

문서 수정 전 최소 확인 대상:

- `scripts/autoload/GameConstants.gd`
- `scripts/autoload/GameData.gd`
- `scripts/autoload/GameState.gd`
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

---

## 2. 현재 프로젝트 기준

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

현재 Burial Protocol은 아래 요소가 실제로 연결된 "플레이 가능한 세로형 생존 루프" 상태다.

- 낙하 블록 전투
- 모래 시뮬레이션과 중량 실패
- 좌우 고정벽 채굴
- 마우스 방향 공격과 채굴
- 점프, 추가 점프, 대시, 배터리 기반 벽타기
- Day 진행과 intermission
- 키오스크 상점 게이트
- 경험치, 레벨업 카드, 런타임 스탯 증가
- HUD, 스킬 슬롯, ESC 스탯 확인 UI

---

## 3. 데이터 소유권 원칙

### 3-1. `GameConstants.gd`는 전역 상수만 가진다

`GameConstants.gd`는 아래 범주의 상수와 정적 유틸만 가진다.

- 월드 크기, HUD 레이아웃, 색상
- 플레이어 이동/공격/채굴/대시/벽타기 수치
- 중량 한도와 표시 스케일
- 피격 팝업, 키오스크, 페이드 관련 상수
- 난이도 옵션
- 입력 바인딩
- 레벨업 카드 정의

### 3-2. 콘텐츠 데이터는 `.tres`가 소유한다

블록/Day 콘텐츠 데이터는 코드 상수 딕셔너리가 아니라 `.tres` 리소스가 소유한다.

- 블록 카탈로그: `data/blocks/BlockCatalog.tres`
- Stage/Day 테이블: `data/stages/StageTable.tres`
- 로딩 진입점: `scripts/autoload/GameData.gd`

### 3-3. 블록 개념 모델은 아래를 따른다

- Block Base = 실제 블록 본체
- Block Type = Base에 선택적으로 붙는 affix/modifier
- 스폰 단위 = `Base only` 또는 `Base + Type`

즉, 크기/기본 체력/보상/모래량/색상/기본 스폰 가중치는 Base가 가진다.
Type은 추가 배율이나 부가 효과만 담당한다.

---

## 4. 상태 소유권 원칙

### 4-1. `GameState.gd`

`GameState.gd`는 아래를 소유한다.

- 저장 데이터
- 현재 런의 골드, HP, XP, 레벨
- 런타임 스탯 보너스
- 최종 스탯 getter
- HUD/메뉴용 signal

### 4-2. `Main.gd`

전투 루프와 Day 전환 플래그는 `Main.gd`가 소유한다.

예:

- `_is_day_active`
- `_is_intermission`
- `_is_intermission_locked`
- `_is_next_day_transitioning`
- `_shop_ui_open`
- `_pending_wall_reset_for_next_day`

즉, 런타임 공용 수치와 저장은 `GameState`,
씬 내부 진행 플래그는 `Main`이 맡는다.

---

## 5. 문서 작성 원칙

### 5-1. 구현된 것과 미구현을 분리한다

문서에는 아래 세 층을 섞지 않는다.

- 현재 구현되어 동작하는 것
- placeholder 또는 임시 구현
- 향후 TODO

예를 들어 현재 상점 단계는 존재하지만,
구매 기능은 placeholder이고 `Next Day` 게이트가 중심이다.
문서도 그렇게 적어야 한다.

### 5-2. 수치가 고정이면 실제 값을 적는다

현재 코드에 고정값이 있으면 모호한 표현보다 실제 수치를 적는다.

예:

- `PLAYER_MAX_HEALTH = 100`
- `BLOCK_DAMAGE_PER_UNIT = 10`
- `WEIGHT_LIMIT_SAND_CELLS = 2400`
- 표시 중량 = `240.0 KG`
- 키오스크 유예 = `3.0초`
- 키오스크 지연 투하 = `1.25초`

### 5-3. 문서 변경 시 관련 문서를 함께 맞춘다

아래 항목이 바뀌면 최소 2개 이상 문서를 같이 본다.

- 입력 체계
- Day/intermission 흐름
- HUD/ESC UI
- 스탯/레벨업 카드
- 데이터 구조

---

## 6. 현재 반드시 지켜야 하는 구현 방향

### 6-1. 현재 플레이 가능한 루프를 깨지 않는다

우선 보존 대상:

- 이동 감각
- 공격/채굴 리듬
- 낙하 블록 처리
- 모래 시뮬레이션
- Day 전환 루프
- HUD 가독성

### 6-2. Stage 전환 기본 규칙

현재 기준 기본 Stage 전환은 아래와 같다.

- Day 종료 시 바로 다음 Day로 자동 진행하지 않는다
- intermission 상태로 진입한다
- 마지막 활성 블록 정리 후 키오스크가 지연 투하된다
- 약 `3초` 뒤 채굴만 정지된다
- 상점 UI에서 `Next Day`로 다음 Day를 시작한다
- 기본적으로 채굴 벽은 초기화하지 않는다
- 벽 초기화는 향후 특정 상점 구매 시에만 예외 훅으로 연결한다

### 6-3. 모래 처리 원칙

- 자연 물리 반응과 플레이어의 모래 밀림은 유지한다
- intermission 잠금 이후 막는 것은 채굴 입력/채굴 결과다
- 벽을 복구하지 않는 기본 경로에서는 모래 재배치를 하지 않는다
- 벽 복구 예외 경로가 실행될 때만 모래 총량 보존 검증을 수행한다

---

## 7. 현재 미구현 또는 제한된 영역

아래는 아직 완성 시스템이 아니다.

- Day 상점의 실제 구매 품목
- 행운의 실제 효과
- 벽 초기화를 유발하는 상점 아이템
- 블록 특수 결과의 본격적 구현
- 메타 성장, 업적, 인벤토리의 실제 기능
- 설정 메뉴의 실제 옵션

문서에 이 항목들을 적을 때는 반드시 `미구현`, `TODO`, `placeholder`로 표시한다.

---

## 8. 체크리스트

게임플레이나 UI를 바꾼 뒤 문서를 갱신할 때 최소 확인 항목:

- 입력맵이 문서와 일치하는가
- HUD와 ESC 패널 표시값이 실제 getter와 일치하는가
- 레벨업 카드 풀과 스탯 패널 설명이 어긋나지 않는가
- Day 종료 후 intermission 흐름 설명이 실제와 맞는가
- 키오스크 등장 방식과 상호작용 조건이 맞는가
- 벽 초기화 기본 규칙이 "유지"로 적혀 있는가
- 콘텐츠 데이터 소유권이 `.tres` 기준으로 적혀 있는가

---

## 9. 현재 개발 방향

현재 프로젝트는 대규모 재설계보다,
실행 가능한 코어 루프를 보존하면서 시스템을 하나씩 연결하는 방향을 우선한다.

핵심 방향:

- 코드와 문서를 계속 동기화한다
- 데이터는 `.gd` 규칙과 `.tres` 콘텐츠로 분리한다
- 런타임 스탯과 UI 가시성을 강화한다
- Day 종료 -> 상점 -> Next Day 루프를 안정화한다
- 메타 시스템은 placeholder 범위를 명확히 유지한다
