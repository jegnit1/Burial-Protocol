# Burial Protocol - Game Structure Specification

## 0. 목적

이 문서는 현재 코드 기준 Burial Protocol의 전체 씬 흐름과 런 구조를 정리한다.
특히 Day 진행, intermission, 키오스크, 상점 UI, Next Day 전환 구조를 실제 구현 기준으로 기록한다.

기준일: `2026-04-20`

---

## 1. 상위 흐름

현재 게임의 상위 루프는 아래와 같다.

1. `Title`
2. `MainHub`
3. 필요 시 `CharacterList`
4. 난이도 선택 후 `Main`
5. Day 기반 전투/채굴/성장 루프 진행
6. Day 종료 시 intermission 진입
7. 키오스크 상호작용으로 상점 UI 진입
8. `Next Day`로 다음 Day 시작
9. 런 종료 시 `Result`
10. 다시 `MainHub`

즉, 현재는 "Title -> Hub -> Main -> Result" 골격 위에
`Day active -> intermission -> shop -> next day` 내부 루프가 실제로 연결된 상태다.

---

## 2. 주요 씬과 역할

### 2-1. `Title.tscn`

- 시작 화면
- 메인 허브 진입
- 설정/프로필 버튼은 placeholder
- 게임 종료 가능

### 2-2. `MainHub.tscn`

- 메인 허브
- 현재 선택 캐릭터/최고 기록 표시
- 난이도 선택 및 게임 시작
- 업적/성장/아이템 목록은 placeholder 화면

### 2-3. `CharacterList.tscn`

- 캐릭터 선택 화면
- 기본 일꾼 1개만 사용 가능
- 나머지 슬롯은 잠금 placeholder

### 2-4. `Main.tscn`

현재 실제 플레이 씬이다.
핵심 노드:

- `WorldGrid`
- `SandField`
- `Player`
- `Blocks`
- `HUD`
- `WorldCamera`
- `SpawnTimer`

`Main.gd`가 아래를 총괄한다.

- Day 타이머
- 일반 블록 스폰
- 보스 Day 처리
- 공격/채굴 연결
- intermission 진입
- 키오스크 투하
- 상점 UI 열기
- Next Day 전환
- 페이드 연출

### 2-5. `Result.tscn`

- 런 종료 화면
- 종료 사유
- 캐릭터/난이도/최고 도달 Day 기록 표시

### 2-6. `DayKiosk.gd`

별도 씬 파일이 아니라 코드 기반 Node2D 프록시로 생성된다.

- Day 종료 후 중앙 상단에서 낙하
- 플레이어와 물리 충돌하지 않음
- 모래/고정 지형/활성 블록 위에 안착
- 안착 후 `E` 상호작용 허용

### 2-7. `DayShopUI.gd`

현재 상점 단계용 최소 UI다.

- `Close`
- `Next Day`

구매 시스템은 아직 placeholder이며,
현재 역할은 상점 단계 진입과 다음 Day 전환 게이트다.

### 2-8. `PauseMenu.gd`

ESC 일시정지 메뉴다.

- 계속하기
- 메인 허브로
- 게임 종료
- 설정 버튼 placeholder
- 오른쪽 스탯 리스트 패널

---

## 3. 데이터 구조 진입점

### 3-1. 전역 상수

`GameConstants.gd`

- 월드/플레이어/입력/HUD/피드백 상수
- 난이도 옵션
- 레벨업 카드 정의

### 3-2. 콘텐츠 데이터

`GameData.gd`

- `BlockCatalog.tres`
- `StageTable.tres`

즉, 블록 본체/affix/Day 정보는 `.tres`가 소유하고,
`Main.gd`와 `BlockData`가 그 값을 읽어 런타임 조합을 만든다.

### 3-3. 런타임/저장 상태

`GameState.gd`

- 저장 데이터
- 현재 런의 골드, HP, XP, 레벨
- 런타임 스탯 보너스
- HUD와 메뉴용 signal

---

## 4. 런 시작 구조

현재 런 시작 흐름:

1. 허브에서 캐릭터와 난이도 선택
2. `GameState.begin_run(difficulty_id)`
3. `Main._ready()`
4. `GameState.reset_run()`
5. Day 1 시작
6. `SpawnTimer` 가동

초기값:

- Day: `1`
- Day 시간: `40.0초`
- 골드: `0`
- HP: `100`
- 레벨: `1`
- XP: `0 / 50`

---

## 5. Day 구조

### 5-1. 전체 Day 수

- 총 Day 수: `30`
- Day 30은 최종 보스 Day

### 5-2. Day 타입

`StageTable.tres` 기준으로 Day 타입이 정의된다.

- `normal`
- `rush`
- `boss`

현재 기본 규칙:

- Rush Day: `5`, `15`, `25`
- Boss Day: `10`, `20`, `30`

### 5-3. Day active 상태

Day active 상태에서는 아래가 동작한다.

- Day 타이머 감소
- 일반 블록 스폰
- 공격/채굴
- 모래 시뮬레이션
- XP/골드 획득

### 5-4. Day 종료 시 intermission

Day 1~29에서 시간이 0이 되면 즉시 결과 화면으로 가지 않는다.
현재는 아래 흐름으로 들어간다.

1. `_is_day_active = false`
2. `_is_intermission = true`
3. 일반 블록 스폰 중단
4. 마지막 활성 블록 정리 대기
5. 정리 완료 후 `1.25초` 대기
6. 키오스크 투하
7. intermission 시작 후 `3.0초` 뒤 채굴 잠금

### 5-5. 키오스크 등장 방식

현재 키오스크는 고정 위치 생성이 아니다.

- 중앙 전장 상단에서 낙하
- 낙하 속도: `780 px/s`
- 플레이어와 물리 충돌 없음
- 모래/지형/활성 블록 위에 착지
- 착지 전 상호작용 불가
- 착지 후 `E` 상호작용 가능

### 5-6. 상점 단계

키오스크와 상호작용하면 `DayShopUI`가 열린다.

현재 상점 단계 특징:

- 실제 구매 시스템은 미구현
- `Close` 가능
- `Next Day`로 다음 Day 진행 가능
- 상점을 닫아도 키오스크에서 다시 열 수 있음

### 5-7. Next Day 전환

현재 `Next Day` 버튼을 누르면 아래 순서가 실행된다.

1. 페이드 아웃
2. 이자 지급
3. 조건부 벽 초기화 훅 실행
4. intermission 종료
5. Day 증가
6. 새 Day 시간 설정
7. 스폰 타이머 재시작
8. 페이드 인

---

## 6. 벽 초기화 규칙

현재 기본 규칙은 "벽 유지"다.

- Day 전환 시 좌우 채굴 벽을 자동 복구하지 않는다
- 이전 Day까지 판 벽 모양이 그대로 유지된다

예외 훅:

- `queue_wall_reset_for_next_day()`
- `_pending_wall_reset_for_next_day`

즉, 향후 특정 상점 구매가 생기면
그때만 다음 Day 전환에서 벽 복구를 실행하도록 구조만 준비되어 있다.

---

## 7. 모래 총량 보존 구조

기본 전환 경로에서는 벽을 복구하지 않으므로 모래 재배치도 실행되지 않는다.

다만 예외적으로 벽 복구가 실행될 때는 아래 순서를 사용한다.

1. 복구 예정 벽 영역 안의 모래 셀 추출
2. 좌우 채굴 벽 복구
3. 중앙 유효 공간으로 모래 재배치
4. 전후 총량 검증 로그/에러 체크

검증 지표:

- `before`
- `collected`
- `after_extract`
- `reapplied`
- `after`

즉, 벽 복구 예외 경로는 실제 총량 보존 검증까지 포함한다.

---

## 8. Day 30 처리

Day 30은 최종 보스 Day다.

현재 클리어 조건:

1. Day 30 보스를 직접 파괴
2. 또는 Day 30 보스가 모래로 분해된 뒤에도 플레이어가 생존하고 중량 초과가 아님

실패 조건:

- HP 0
- 중량 한도 초과
- Day 30 시간 종료

---

## 9. 런 종료 구조

현재 런 종료는 아래 조건 중 하나에서 발생한다.

- 플레이어 HP 0
- 모래 총량이 중량 한도 도달
- Day 30 시간 종료
- Day 30 클리어
- 수동 종료(`R`)

종료 시:

1. `GameState.finish_temporary_run()`
2. 결과 데이터 저장
3. `Result.tscn` 전환

---

## 10. 현재 구조 밖의 영역

아래는 아직 본격 구현 범위 밖이다.

- 상점 실제 구매 아이템
- 메타 성장
- 업적 실기능
- 인벤토리
- 설정 메뉴 기능

즉, 현재 구조 문서의 핵심은
"코어 전투/채굴/Day 전환 루프는 구현됨, 메타와 상점 구매는 아직 제한적"이라는 점이다.
