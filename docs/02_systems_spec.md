# Burial Protocol - Systems Specification

기준일: `2026-04-24`  
기준 브랜치: `main`

---

## 0. 목적

이 문서는 Burial Protocol의 실제 구현 기준 시스템 스펙을 하나로 통합한 문서다.
기존의 `game_structure_spec`, `gameplay_systems_spec`, `attack_module_system_spec`, `block material/size draft`, `HUD/UI 문서`에 흩어져 있던 내용을 이 문서로 통합한다.

이 문서는 Codex 또는 개발자가 기능을 수정할 때 우선 참고하는 메인 시스템 스펙이다.

---

## 1. 기준 상수

| 항목 | 값 |
|---|---:|
| 기준 해상도 | `1920 x 1080` |
| 1U | `64px` |
| 월드 가로 | `30칸` |
| 좌측 채굴벽 | `10칸` |
| 중앙 전장 | `10칸` |
| 우측 채굴벽 | `10칸` |
| 월드 세로 | `200칸` |
| 총 Day 수 | `30` |
| 기본 Day 시간 | `40초` |
| 모래 셀 밀도 | `1U = 6 x 6 cells` |
| 중량 한도 | `2400 sand cells` |
| HUD 표시 중량 | `240.0 KG` |

---

## 2. Scene / Run Flow

현재 상위 흐름:

1. `Title`
2. `MainHub`
3. 필요 시 `CharacterList`
4. 난이도 선택
5. `Main`
6. Day active
7. Intermission
8. 키오스크 상호작용
9. Day Shop
10. Next Day
11. Day 30 클리어 또는 실패
12. `Result`
13. `MainHub`

주요 씬 역할:

| 씬/스크립트 | 역할 |
|---|---|
| `Title.tscn` | 시작 화면 |
| `MainHub.tscn` | 캐릭터/난이도/시작 허브 |
| `CharacterList.tscn` | 캐릭터 선택. 현재 기본 일꾼 중심 |
| `Main.tscn` | 실제 런 플레이 씬 |
| `Result.tscn` | 런 결과 표시 |
| `DayKiosk.gd` | intermission 상점 진입 오브젝트 |
| `DayShopUI.gd` | 상점 구매/Next Day UI |
| `PauseMenu.gd` | ESC 일시정지/스탯 확인 |
| `LevelUpUI.gd` | 레벨업 카드 선택 |

---

## 3. Main Scene 책임

`Main.gd`는 전투 루프와 Day 전환을 총괄한다.

주요 책임:

- Day 타이머
- 일반 블록 스폰
- 보스 블록 스폰
- 공격모듈 트리거 처리
- 투사체/레이저/메카닉 공격 처리
- 채굴 처리
- 블록 파괴/분해 처리
- 모래 시뮬레이션 호출
- 플레이어 HP 재생
- intermission 진입
- 키오스크 투하
- 상점 아이템 롤
- 상점 UI 열기/닫기
- 구매 후 상점 목록 갱신
- Next Day 전환
- 이자 지급
- 조건부 벽 복구
- 런 종료 판정

`Main.gd`의 진행 플래그는 저장 상태가 아니며 씬 내부 진행 상태다.

대표 플래그:

- `_is_day_active`
- `_is_intermission`
- `_is_intermission_locked`
- `_is_next_day_transitioning`
- `_shop_ui_open`
- `_waiting_for_day_kiosk`
- `_pending_wall_reset_for_next_day`
- `_current_shop_item_ids`
- `_has_shop_inventory_for_intermission`

---

## 4. 입력 체계

현재 기본 입력:

| 행동 | 입력 |
|---|---|
| 좌 이동 | `A`, `Left Arrow` |
| 우 이동 | `D`, `Right Arrow` |
| 점프 | `W`, `Up Arrow`, `Space` |
| 아래/급강하 | `S`, `Down Arrow` |
| 공격 | `Left Mouse Button` |
| 채굴 | `Right Mouse Button` |
| 대시 | `Z`, 좌/우/하 더블탭 |
| 상호작용 | `E` |
| 디버그 패널 | `Tab` |
| 일시정지 | `ESC` |
| 수동 종료/리스타트 | `R` |

입력 보장은 `GameConstants.ensure_input_actions()`가 담당한다.

---

## 5. Player Movement

### 5-1. 기본 이동

| 항목 | 값 |
|---|---:|
| 지상 이동 속도 | `426 px/s` |
| 공중 이동 속도 | `373 px/s` |
| 모래 속 이동 배율 | `0.62` |
| 중력 | `2000 px/s^2` |
| 점프 속도 | `-853` |
| 추가 점프 | `1회` |
| 벽 점프 가로 속도 | `480` |
| 점프 버퍼 | `0.14초` |
| 코요테 타임 | `0.10초` |
| 빠른 낙하 가속 | `2933 px/s^2` |
| 빠른 낙하 최대 속도 | `1306 px/s` |

### 5-2. 대시

지원 방향:

- 좌
- 우
- 하

미지원:

- 상향 대시

수치:

| 항목 | 값 |
|---|---:|
| 대시 거리 | `4U` |
| 대시 지속시간 | `0.08초` |
| 더블탭 입력창 | `0.22초` |
| 쿨다운 | `0.45초` |

### 5-3. 벽타기

벽타기 조건:

- 대시 중 아님
- 배터리 `> 0`
- 고정벽 접촉
- 접촉한 벽 방향 입력 유지
- 플레이 가능 상단 제한 아래

수치:

| 항목 | 값 |
|---|---:|
| 배터리 최대치 | `100` |
| 소모량 | `5/sec` |
| 기본 회복량 | `5/sec` |
| 벽타기 낙하 제한 | `110 px/s` |

벽타기는 falling block 측면, 모래, 동적 오브젝트에는 적용하지 않는다.

---

## 6. Mining

채굴은 우클릭 기반 환경 상호작용이다.
공격모듈과 별개다.

대상:

- 모래 셀
- 좌우 벽 서브셀

비대상:

- 낙하 블록

수치:

| 항목 | 값 |
|---|---:|
| 기본 채굴 데미지 | `1` |
| 채굴 쿨다운 | `0.15초` |
| 채굴 버퍼 | `0.12초` |
| 채굴 거리 | `0.25U` |
| 채굴 높이 | `1U` |

intermission 진입 후 `3초` 유예가 지나면 채굴만 정지된다.
플레이어 이동, 모래 자연 반응, 모래 밀림은 유지한다.

---

## 7. Attack Module

### 7-1. 정의

공격모듈은 플레이어가 장착하는 무기 아이템이다.
현재 전투는 단일 기본 공격이 아니라 장착된 공격모듈들이 각자 발동하는 구조다.

시각적으로 모듈은 플레이어 주변을 공전한다.
실제 판정 기준은 모듈 위치가 아니라 캐릭터 위치다.

### 7-2. 장착 규칙

| 항목 | 규칙 |
|---|---|
| 최대 장착 수 | `5개` |
| 중복 장착 | 가능 |
| 구매 결과 | 즉시 장착 |
| 빈 슬롯 있음 | 추가 장착 |
| 슬롯 가득 참 | 기본 구매 불가 |
| 예외 | 동일 모듈/동일 등급 합성 가능 시 구매 허용 |
| 등급 | `D`, `C`, `B`, `A`, `S` |

### 7-3. 합성 규칙

합성 조건:

```text
동일 모듈 + 동일 등급 2개
```

결과:

```text
상위 등급 동일 모듈 1개
```

슬롯이 가득 찬 상태에서도 구매하려는 모듈이 즉시 합성 가능하면 구매가 허용된다.

### 7-4. 타입

| 타입 | 발동 | 구현 방식 |
|---|---|---|
| `melee` | 좌클릭 기반 | 캐릭터 기준 회전 직사각형 shape query |
| `ranged` | 좌클릭 기반 | 투사체 또는 레이저 히트스캔 |
| `mechanic` | 좌클릭 무관 | 자동 타겟팅/자동 공격 |

### 7-5. 공격 대상

대상:

- 활성 낙하 블록
- 보스 블록

비대상:

- 모래
- 벽
- 플레이어
- 환경물

### 7-6. 치명타

- 기본 치명타 확률: `1%`
- 치명타 배율: `200%`

치명타는 공격에만 적용되며 채굴에는 적용되지 않는다.

---

## 8. Block / Spawn

### 8-1. 최신 블록 모델

최신 블록 모델:

```text
Runtime Block = Material x Size + optional Type
```

- Material = 재질/성질
- Size = 가로/세로 크기
- Type = 선택 affix/modifier

기존 코드에 `base` 명칭이 남아 있을 수 있으나 문서상 기준은 material/size/type이다.

### 8-2. 스폰 흐름

1. 현재 난이도와 Day 확인
2. `BlockCatalog`에서 유효 candidate 수집
3. candidate weight 기반 랜덤 선택
4. optional type 선택
5. `BlockSpawnResolver`가 resolved definition 생성
6. `BlockData`로 변환
7. `FallingBlock` 생성

### 8-3. 최종 HP

```text
final_hp =
  BLOCK_HP_PER_UNIT
  x size_hp_multiplier
  x material_hp_multiplier
  x difficulty_hp_multiplier
  x type_hp_multiplier
```

기본값:

- `BLOCK_HP_PER_UNIT = 10.0`

### 8-4. 최종 보상

```text
final_reward =
  BLOCK_REWARD_PER_UNIT
  x size_reward_multiplier
  x material_reward_multiplier
  x type_reward_multiplier
```

기본값:

- `BLOCK_REWARD_PER_UNIT = 5.0`

### 8-5. 최종 모래량

```text
final_sand_units =
  BLOCK_SAND_UNITS_PER_UNIT
  x size_reward_multiplier
  x type_sand_units_multiplier
```

기본값:

- `BLOCK_SAND_UNITS_PER_UNIT = 36.0`

### 8-6. 블록 종료 방식

| 종료 방식 | 결과 |
|---|---|
| 공격으로 파괴 | 골드 + XP 지급 |
| 지형/모래 접촉으로 분해 | 모래 생성 |
| 플레이어 압착 | 피해 + 모래 생성 |
| Day 30 보스 파괴 | 런 클리어 |
| Day 30 보스 분해 후 생존 | 런 클리어 |

---

## 9. Sand / Weight

모래는 블록이 분해될 때 생성되는 주요 위험 자원이다.

역할:

- 전장 공간 점유
- 플레이어 이동 방해
- 채굴 대상 제공
- 중량 실패 조건 누적

기준:

| 항목 | 값 |
|---|---:|
| 내부 실패 기준 | `2400 cells` |
| 표시 환산 | `1 cell = 0.1 KG` |
| HUD 최대 표시 | `240.0 KG` |

이동 규칙:

- 아래로 낙하 우선
- 대각선 확산
- 플레이어 이동 중 밀림 해결
- 점프 공간 확보 시도

---

## 10. Day / Intermission / Shop

### 10-1. Day Active

Day active 중 동작:

- Day 타이머 감소
- 블록 스폰
- 보스 Day 처리
- 공격모듈 공격
- 채굴
- 모래 시뮬레이션
- HP 재생
- XP/골드 획득
- 실패 조건 체크

### 10-2. Day 종료

Day 1~29에서 시간이 끝나면 intermission으로 진입한다.

흐름:

1. Day active 종료
2. 스폰 중단
3. intermission 진입
4. 마지막 활성 블록 정리 대기
5. `1.25초` 뒤 키오스크 투하
6. `3초` 뒤 채굴 잠금
7. 키오스크 상호작용으로 상점 진입

### 10-3. 키오스크

| 항목 | 값 |
|---|---:|
| 상호작용 키 | `E` |
| 상호작용 거리 | `2U` |
| 낙하 속도 | `780 px/s` |
| 투하 지연 | `1.25초` |

### 10-4. 상점

상점은 실제 구매 UI다.

현재 기능:

- 상점 아이템 5개 롤
- 아이템 목록 표시
- 상세 정보 표시
- 가격 표시
- 구매 가능 여부 표시
- 구매 처리
- 구매 성공 시 현재 상점 목록에서 제거
- `Close`
- `Next Day`

카테고리:

- `attack_module`
- `function_module`
- `enhance_module`

### 10-5. Next Day

`Next Day` 버튼을 누르면:

1. 상점 닫기
2. 키오스크 제거
3. 페이드 아웃
4. 이자 지급
5. 예약된 벽 복구가 있으면 실행
6. intermission 종료
7. Day 증가
8. 새 Day 시간 설정
9. 스폰 타이머 재시작
10. 페이드 인

기본 규칙:

- 벽은 자동 복구하지 않는다.
- 모래도 기본 유지한다.
- 벽 복구는 특정 효과가 예약했을 때만 실행한다.

---

## 11. Shop Item

### 11-1. 카테고리

| 카테고리 | 의미 |
|---|---|
| `attack_module` | 장착 무기 모듈 |
| `function_module` | 런 중 기능 효과 모듈 |
| `enhance_module` | 스탯 강화 모듈 |

### 11-2. 랭크

아이템 랭크:

- D
- C
- B
- A
- S

Day가 높아질수록 높은 랭크 비중이 증가한다.
행운은 랭크 weight를 보정한다.

### 11-3. 구매 결과

- 공격모듈: 즉시 장착 또는 합성
- 기능 모듈: 현재 런 효과로 등록
- 강화 모듈: 현재 런 스탯에 즉시 적용 또는 stack 증가

---

## 12. XP / Level Up

XP 획득:

- 블록 파괴 XP
- 모래 제거 XP

레벨업:

- 레벨업 준비 시 일시정지
- `LevelUpUI` 표시
- 카드 3장 제시
- 선택 즉시 적용

대표 카드:

- 공격력 증가
- 공격속도 증가
- 최대 체력 증가
- 이동속도 증가
- 채굴 데미지 증가
- 채굴 속도 증가
- 공격범위 증가
- 치명타 확률 증가
- 방어력 증가
- HP 재생 증가
- 점프력 증가
- 채굴범위 증가

---

## 13. HUD / UI

현재 런 UI 역할:

- Day 진행 정보 전달
- 보스 Day 예고
- 생존 자원 표시
- 배터리 표시
- XP 표시
- 골드 표시
- 중량 경고
- 대시 쿨다운 표시
- intermission 상점 진입
- 상세 스탯 확인

주요 UI 구성:

| UI | 역할 |
|---|---|
| 좌측 상단 HUD | Day, 난이도, 보스 예고, 남은 시간 |
| 좌측 중단 센서 | 카메라 기준 세로 전장 정보 |
| 좌측 하단 HUD | 레벨, HP, 배터리, XP |
| 우측 상단 HUD | 골드, 중량 |
| 우측 하단 슬롯 | 대시와 향후 스킬 슬롯 |
| ESC 메뉴 | 일시정지와 상세 스탯 |
| DayShopUI | 상점 구매와 Next Day |
| LevelUpUI | 레벨업 카드 선택 |

---

## 14. Run End

실패 조건:

- HP 0
- 모래 중량 한도 초과
- Day 30 시간 종료
- 수동 종료

클리어 조건:

1. Day 30 보스를 직접 파괴
2. Day 30 보스가 모래로 분해되었지만 플레이어가 생존하고 중량 초과가 아님

런 종료 시:

1. `GameState.finish_temporary_run()`
2. 결과 데이터 저장
3. `Result.tscn` 전환

---

## 15. 현재 제한/TODO

아래는 아직 완성 시스템이 아니다.

- 설정 메뉴 실기능
- 메타 성장/업적/인벤토리 실기능
- 모든 블록 특수 결과의 본격 처리
- 오라형 공격모듈 세부 동작
- 상점 UI 최종 비주얼/한글화
- 공격모듈과 상점 아이템 최종 밸런스
- 최종 아트 적용
