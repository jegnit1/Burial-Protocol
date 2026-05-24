# Burial Protocol - Treasure Chest 1차 구현 계획서

작성일: 2026-05-01  
목적: 채굴 확장용 보물상자 시스템을 한 번에 구현하지 않고, 안전하게 단계별로 구현하기 위한 작업 계획서다.

---

## 0. 문서 성격

이 문서는 **구현 지시용 계획서**다.

이번 계획의 목표는 아래와 같다.

1. 보물상자 1차 구현 범위를 명확히 한다.
2. 벽 subcell 기반 보물상자 marker 구조를 확정한다.
3. partial reveal, fully reveal, E 상호작용, reward popup, reward grant를 단계별로 나눈다.
4. Codex 작업을 Phase 단위로 쪼갤 수 있게 한다.
5. 기존 코어 루프, v1 블록 스폰, v2 시뮬레이션, 공격모듈 밸런스가 깨지지 않게 한다.

이번 계획서 자체는 코드 수정, 씬 수정, `.tres` 수정, TSV 수정, 밸런스 수치 변경을 요구하지 않는다.

---

## 1. 기존 문서 기준

보물상자는 기존 `docs/02_systems_spec.md`의 Mining 확장 항목에 이미 방향성이 있다.

기존 방향:

- 좌우 벽 내부 특수 객체는 `Treasure Chest`와 `Creep` 두 계열로 나뉜다.
- `Treasure Chest`는 보상형 특수 객체다.
- 채굴로 노출된 뒤 `E` 상호작용으로 획득한다.
- `Creep`은 리스크형 특수 객체이며, 1차 구현 범위에서는 제외한다.
- 보물상자는 벽 내부의 빛나는 벽블록으로 예고된다.
- 채굴 후 월드 오브젝트로 노출된다.
- 보상 팝업 중 게임은 일시정지된다.
- 보상은 `D~S` 등급 보상 아이템 체계를 따른다.

기존 문서의 `Normal / Silver / Gold / Platinum` 보물상자 명칭은 이번 1차 구현에서 `Bronze / Silver / Gold / Platinum`으로 정리한다.

---

## 2. 1차 구현 범위

### 포함

- 보물상자만 구현한다.
- 벽 내부 treasure marker 구조를 만든다.
- 벽 reset 시점에 treasure marker를 생성한다.
- 보물상자는 1U 크기이며, 현재 `WALL_SUBCELLS_PER_UNIT = 2` 기준으로 `2 x 2 wall subcell`을 차지한다.
- 2 x 2 중 채굴된 subcell만큼 보물상자 일부가 보인다.
- 2 x 2 네 칸이 모두 채굴되어야 fully revealed 상태가 된다.
- fully revealed 상태에서만 `E` 상호작용 가능하다.
- 상호작용 시 `TreasureRewardPopup`을 띄운다.
- 보상 아이템을 `획득`하거나 `판매`할 수 있다.
- 판매가는 해당 아이템 유효 구매가의 60%다.
- 골드 차감 없이 아이템을 지급하는 helper를 추가한다.
- 최소 회귀 테스트 또는 snapshot 테스트를 추가한다.

### 제외

- 크립 구현
- 복잡한 보상 연출
- 보물상자 전용 완성 아트
- 보물상자 등급별 정교한 위치 bias
- 보물상자 전용 신규 아이템 대량 추가
- 모래삭제 보상/XP 보상/골드주머니 보상 신규 구현
- wall reset 아이템 구현
- 기존 v1 블록 스폰 변경
- v2 Spawn Pool live 전환
- StageTable 수치 조정
- 공격모듈 밸런스 조정

---

## 3. 확정 기획

### 3-1. WALL_SUBCELLS_PER_UNIT

현재 기준:

```text
WALL_SUBCELLS_PER_UNIT = 2
```

의미:

```text
1U 벽 영역 = 2 x 2 wall subcell
```

따라서 캐릭터가 벽 안으로 완전히 들어가려면 최소 2 x 2 = 4개 subcell을 채굴해야 한다.

보물상자도 1U 크기이므로, 보물상자 하나는 정확히 2 x 2 wall subcell을 차지한다.

### 3-2. 보물상자 크기

```text
Treasure Chest world size = 1U x 1U
Treasure marker size = 2 x 2 wall subcells
```

보물상자는 반드시 wall subcell grid에 정렬되어 배치되어야 한다.

### 3-3. Partial reveal

2 x 2 marker 중 채굴된 칸만큼 보물상자 일부가 보여야 한다.

예:

```text
1칸 채굴: 보물상자 1/4 표시
2칸 채굴: 보물상자 2/4 표시
3칸 채굴: 보물상자 3/4 표시
4칸 채굴: 보물상자 전체 표시 + fully revealed
```

fully revealed 전에는 `E` 상호작용이 불가능하다.

### 3-4. Fully revealed

아래 조건을 만족하면 fully revealed다.

```text
marker가 차지하는 2 x 2 wall subcell 4칸이 모두 채굴됨
```

fully revealed 후:

- 상호작용 안내를 띄울 수 있다.
- `E` 입력으로 보상 팝업을 열 수 있다.
- 획득 또는 판매 후 consumed 처리한다.

---

## 4. 보물상자 rarity

기존 `Normal` 명칭은 사용하지 않고 `Bronze`를 사용한다.

보물상자 rarity:

| Rarity | ID |
|---|---|
| Bronze | `bronze` |
| Silver | `silver` |
| Gold | `gold` |
| Platinum | `platinum` |

### 4-1. 보물상자 rarity 출현 확률

초기값은 레벨업 카드 희귀도 확률과 동일하게 사용한다.

| Chest Rarity | Chance |
|---|---:|
| Bronze | 70% |
| Silver | 22% |
| Gold | 7% |
| Platinum | 1% |

주의:

- 초기값만 레벨업 카드 희귀도와 동일하다.
- 코드 구조상 레벨업 카드와 보물상자 rarity가 강결합되면 안 된다.
- 나중에 보물상자 전용 확률로 분리 조정 가능해야 한다.

---

## 5. 보상 rank 확률

보물상자 rarity를 먼저 roll하고, 해당 rarity에 따라 reward rank를 roll한다.

### 5-1. Bronze chest

| Reward Rank | Chance |
|---|---:|
| D | 80% |
| C | 10% |
| B | 6% |
| A | 4% |
| S | 0% |

### 5-2. Silver chest

| Reward Rank | Chance |
|---|---:|
| D | 70% |
| C | 15% |
| B | 10% |
| A | 5% |
| S | 0% |

### 5-3. Gold chest

| Reward Rank | Chance |
|---|---:|
| D | 55% |
| C | 20% |
| B | 10% |
| A | 10% |
| S | 5% |

### 5-4. Platinum chest

| Reward Rank | Chance |
|---|---:|
| D | 40% |
| C | 25% |
| B | 15% |
| A | 10% |
| S | 10% |

---

## 6. 보상 후보

1차 구현에서는 현재 `ShopItemCatalog`에 존재하는 아이템만 보상 후보로 사용한다.

포함 카테고리:

- `attack_module`
- `function_module`
- `enhance_module`

규칙:

1. chest rarity roll
2. reward rank roll
3. `ShopItemCatalog`에서 해당 rank와 일치하는 아이템 후보 수집
4. 구현되지 않은 아이템은 후보에 포함하지 않음
5. 후보 중 하나를 weighted 또는 uniform roll
6. reward popup에 표시

후보가 없을 때 fallback:

- 1차 구현에서는 인접 rank 또는 하위 rank fallback을 허용한다.
- fallback 발생 시 warning을 남긴다.
- fallback 규칙은 구현 시 명확히 주석 처리한다.

추천 fallback 순서:

```text
roll_rank 후보 없음
→ 같은 chest rarity에서 낮은 rank 방향으로 검색
→ 그래도 없으면 높은 rank 방향 검색
→ 그래도 없으면 reward 실패 처리 + warning
```

---

## 7. 판매가 공식

판매가는 해당 아이템의 유효 구매가의 60%다.

```text
sell_price = floor(GameState.get_effective_shop_item_price(item_id) * 0.6)
```

주의:

- `price_gold > 0`인 아이템은 해당 값을 기준으로 한다.
- `price_gold == 0`이면 rank fallback 가격을 기준으로 한다.
- item lookup 실패 또는 유효 가격 0인 경우 rank fallback 가격을 다시 확인한다.

현재 rank fallback 가격 기준 예시:

| Rank | Buy Fallback | Sell 60% |
|---|---:|---:|
| D | 15G | 9G |
| C | 30G | 18G |
| B | 60G | 36G |
| A | 120G | 72G |
| S | 240G | 144G |

---

## 8. 무료 아이템 지급 helper

보물상자 보상은 상점 구매가 아니므로 골드를 차감하면 안 된다.

권장 함수:

```gdscript
GameState.grant_shop_item_reward(item_id: String, source: String = "treasure_chest") -> Dictionary
```

역할:

- 골드 차감 없이 상점 아이템 효과를 지급한다.
- 기존 `purchase_shop_item()`의 “아이템 적용” 로직을 재사용한다.
- 상점 목록 제거, reroll, lock 상태 변경은 하지 않는다.
- 결과를 Dictionary로 반환한다.

권장 반환 형태:

```gdscript
{
    "success": true,
    "reason": "",
    "item_id": item_id,
    "category": item_category,
    "applied": true,
    "auto_sold": false,
    "gold_gained": 0
}
```

카테고리별 처리:

| Category | 처리 |
|---|---|
| `attack_module` | 기존 구매와 같은 장착/합성 규칙 적용. 골드 차감 없음 |
| `function_module` | 현재 런 효과 등록 |
| `enhance_module` | 즉시 스탯 적용 또는 stack 증가 |

주의:

- 기존 `purchase_shop_item()`을 복사해서 분기 늘리는 방식은 피한다.
- 가능하면 내부 공통 helper로 “아이템 적용” 부분을 분리한다.
- 기존 상점 구매 동작이 바뀌면 안 된다.

---

## 9. Treasure marker 저장 구조

### 9-1. 개념

Treasure marker는 아직 월드에 노출되지 않은 “벽 내부 숨김 정보”다.

보물상자 object와 marker는 다르다.

| 구분 | 의미 |
|---|---|
| Treasure Marker | 벽 안에 숨겨진 2 x 2 subcell 정보 |
| Treasure Visual | 채굴된 quadrant만큼 보이는 partial visual |
| Treasure Chest / Popup | fully revealed 후 상호작용 가능한 보상 UI 흐름 |

### 9-2. 권장 marker 필드

```gdscript
{
    "marker_id": "treasure_0001",
    "chest_rarity": "silver",
    "wall_side": "left",
    "origin_subcell_x": 0,
    "origin_subcell_y": 12,
    "width_subcells": 2,
    "height_subcells": 2,
    "revealed_cells": {
        "0,0": false,
        "1,0": false,
        "0,1": false,
        "1,1": false
    },
    "is_fully_revealed": false,
    "reward_item_id": "",
    "reward_seed": 12345,
    "consumed": false
}
```

### 9-3. 좌표 기준

- `origin_subcell_x`, `origin_subcell_y`는 marker의 좌상단 subcell 좌표다.
- marker는 `2 x 2` 영역을 차지한다.
- `origin_subcell_y`가 row 0에 걸쳐 상자 상단 quadrant가 유효하지 않게 되는 배치는 금지한다.
- 더 안전하게는 `2 x 2` 모든 subcell이 wall bounds 안에 들어오는지만 검사한다.

---

## 10. Marker 저장 위치 후보

### 후보 A. `Main.gd`가 저장

장점:

- 구현이 빠르다.
- Day/run 흐름과 연결하기 쉽다.
- popup, interaction, reward 지급까지 한 곳에서 연결하기 쉽다.

단점:

- `Main.gd`가 이미 무겁다.
- 벽 좌표/채굴 상태와 관련된 책임이 `Main.gd`로 더 몰린다.
- 크립까지 확장하면 관리가 복잡해진다.

### 후보 B. `WorldGrid.gd`가 저장

장점:

- 벽 subcell 상태와 가장 가깝다.
- 채굴 완료 시 marker 갱신이 쉽다.
- 좌표계 일관성이 높다.

단점:

- `WorldGrid.gd`가 treasure reward, popup, item grant까지 알면 책임이 과해진다.
- UI/보상과 연결되면 world simulation 역할이 흐려진다.

### 후보 C. 별도 `TreasureChestManager.gd` 또는 `WallTreasureManager.gd`

장점:

- 책임 분리가 가장 좋다.
- marker 생성, reveal, consumed 상태, reward roll을 독립 관리할 수 있다.
- 추후 Creep까지 `WallHiddenObjectManager` 형태로 확장하기 쉽다.
- `Main.gd`와 `WorldGrid.gd`의 비대화를 줄인다.

단점:

- 초반 구현 파일이 늘어난다.
- `Main.gd`, `WorldGrid.gd`, UI와 연결 지점이 필요하다.

### 최종 추천

1차 구현 추천은 **별도 Manager 생성**이다.

권장 이름:

```text
scenes/world/WallTreasureManager.gd
```

또는:

```text
scripts/systems/WallTreasureManager.gd
```

역할:

- wall reset 시 marker 생성
- marker bounds/overlap 검사
- mined subcell 입력을 받아 partial reveal 갱신
- fully revealed 여부 계산
- 상호작용 가능한 marker 조회
- reward roll 요청
- consumed 처리

`WorldGrid.gd`는 벽 subcell 채굴 상태를 유지하고, `Main.gd`는 Manager와 UI/interaction을 연결하는 역할만 갖는 것이 좋다.

---

## 11. Marker 배치 규칙

벽 reset 시 treasure marker를 생성한다.

현재는 게임 시작 시 wall reset이 발생하므로 런 시작 시 생성된다.
추후 벽/채굴 현황 reset 아이템이 생기면 같은 marker 생성 함수를 재사용해야 한다.

### 11-1. 기본 배치 조건

- 좌우 벽에만 생성한다.
- 중앙 전장에는 생성하지 않는다.
- marker는 `2 x 2 wall subcell`이다.
- `2 x 2` 영역이 모두 wall bounds 안에 있어야 한다.
- row 0에 걸치는 배치는 금지한다.
- 이미 채굴된 subcell에는 배치하지 않는다.
- 다른 marker와 겹치면 안 된다.
- 벽 subcell grid에 정렬되어야 한다.

### 11-2. 1차 생성 개수

테스트용 기본값:

```text
런 시작 시 좌우 벽 합산 총 6개 생성
```

추천 분배:

```text
left wall: 3개
right wall: 3개
```

이 값은 1차 테스트용이며, 추후 Day/difficulty/깊이/높이 bias를 반영해 조정한다.

### 11-3. rarity roll

각 marker 생성 시 chest rarity를 roll한다.

```text
bronze 70%
silver 22%
gold 7%
platinum 1%
```

---

## 12. Partial reveal visual 계획

### 후보 A. 1U chest texture를 2 x 2 조각으로 나누기

장점:

- 최종 아트와 가장 잘 맞는다.
- 실제 보물상자가 점점 드러나는 느낌이 좋다.

단점:

- 1차에서 texture atlas/region 설정이 번거롭다.
- 아직 아트가 없으면 구현이 임시화된다.

### 후보 B. quadrant sprite 4개 표시

장점:

- 아트 교체가 쉽다.
- 각 subcell과 visual quadrant를 1:1로 매핑하기 쉽다.
- 1차/최종 모두 쓸 수 있는 구조다.

단점:

- 임시 sprite가 필요하다.

### 후보 C. 임시 ColorRect 4개 표시

장점:

- 가장 빠르게 검증 가능하다.
- 아트 없이도 partial reveal 구조를 테스트할 수 있다.

단점:

- 실제 게임 느낌은 부족하다.
- 추후 sprite 교체가 필요하다.

### 최종 추천

**Phase 2에서는 C 또는 B로 시작**한다.

권장:

```text
구조는 B처럼 quadrant 4개 Node로 만들고,
초기 표시만 ColorRect 또는 임시 TextureRect로 처리한다.
```

즉, 나중에 실제 1U 보물상자 sprite를 4 quadrant로 교체할 수 있게 만든다.

---

## 13. Fully revealed 판정

판정 공식:

```text
is_fully_revealed = revealed_subcell_count == 4
```

또는:

```text
for each local cell in 2 x 2:
  if not revealed:
    return false
return true
```

상태 변화:

```text
hidden / partial
→ fully_revealed
→ popup_opened
→ consumed
```

규칙:

- fully revealed 전에는 interaction 안내 없음.
- fully revealed 전에는 E 입력 무시.
- consumed 후에는 visual 제거 또는 비활성 표시.
- consumed 후 재상호작용 금지.

---

## 14. E 상호작용 계획

### 14-1. 기존 입력과 충돌

현재 `E`는 키오스크 상호작용에 사용된다.

보물상자도 `E`를 사용하므로, interaction 우선순위가 필요하다.

권장 우선순위:

```text
1. fully revealed treasure chest
2. Day kiosk
```

단, 기존 interaction 구조에서 키오스크 우선이 더 안전하면 기존 구조를 우선하고, 보물상자는 별도 nearest-interactable 방식으로 붙인다.

### 14-2. Interaction range

권장:

```text
TREASURE_INTERACTION_RANGE = 1.5U ~ 2U
```

1차에서는 키오스크 interaction range `2U`를 재사용해도 된다.

### 14-3. 흐름

```text
Player presses E
→ Main checks nearest fully revealed unconsumed treasure
→ if found: open TreasureRewardPopup
→ else: existing kiosk interaction flow
```

---

## 15. TreasureRewardPopup 계획

새 UI 후보:

```text
scenes/ui/TreasureRewardPopup.tscn
scenes/ui/TreasureRewardPopup.gd
```

### 15-1. 최소 표시 항목

- 보물상자 rarity
- reward item 이름
- reward item rank
- reward item category
- reward item short_desc 또는 desc
- 판매가
- `획득` 버튼
- `판매` 버튼

### 15-2. 동작

팝업 open:

- 게임 pause
- reward item 표시
- 획득/판매 선택 대기

획득:

- `GameState.grant_shop_item_reward(item_id, "treasure_chest")` 호출
- 성공 시 marker consumed
- popup close
- pause 해제

판매:

- item 지급 없음
- `sell_price`만큼 gold 지급
- marker consumed
- popup close
- pause 해제

주의:

- LevelUpUI, DayShopUI, PauseMenu와 pause 처리가 충돌하지 않아야 한다.
- popup 중 중복 입력 방지.

---

## 16. Reward roll 계획

### 16-1. Reward roll 시점

두 가지 방식이 있다.

A. marker 생성 시 reward까지 미리 roll  
B. popup open 시 reward roll

추천은 **B. popup open 시 reward roll**이다.

이유:

- 현재 ShopItemCatalog 상태를 최신으로 반영하기 쉽다.
- marker에는 reward seed만 저장해도 된다.
- 구현이 단순하다.

다만 deterministic 테스트가 필요하면 marker 생성 시 `reward_seed`를 저장한다.

### 16-2. Roll 순서

```text
1. marker.chest_rarity 확인
2. rarity별 reward rank 확률로 rank roll
3. ShopItemCatalog에서 해당 rank 후보 수집
4. 후보 중 item roll
5. popup 표시
```

---

## 17. Phase별 구현 계획

## Phase 1. Marker 데이터 구조와 생성

목표:

- 보물상자 marker를 생성하고 관리할 수 있게 한다.
- 아직 wall mining, partial visual, popup은 구현하지 않는다.

수정/추가 예상 파일:

- `scenes/world/WallTreasureManager.gd` 또는 적절한 manager 파일
- `scenes/main/Main.gd` 연결 최소화
- 필요 시 `GameConstants.gd`에 treasure 관련 상수 추가
- `scripts/tests/treasure_chest_snapshot.gd`

구현 내용:

- rarity table 정의
- marker 구조 정의
- marker 생성 함수
- bounds 검사
- overlap 검사
- 좌우 벽 총 6개 생성
- snapshot에서 marker 목록 출력

검증:

- marker가 2 x 2인지
- wall bounds 밖에 생성되지 않는지
- row 0에 걸치지 않는지
- marker끼리 겹치지 않는지
- rarity roll table 총합이 100인지

절대 금지:

- 실제 채굴 로직 변경
- UI 추가
- reward 지급 구현
- 기존 shop 구매 로직 변경

---

## Phase 2. Mining 연동과 partial reveal

목표:

- wall subcell 채굴 완료 시 marker reveal 상태를 갱신한다.
- 채굴된 quadrant만 표시한다.
- 4칸 모두 채굴되면 fully revealed 처리한다.

수정/추가 예상 파일:

- `WallTreasureManager.gd`
- `WorldGrid.gd` 또는 실제 벽 채굴 완료 처리 파일
- `Main.gd` 연결부
- 임시 visual Node 또는 overlay 구현 파일
- `treasure_chest_snapshot.gd` 확장

구현 내용:

- mined subcell 이벤트 또는 callback 연결
- marker 영역 포함 여부 확인
- revealed_cells 갱신
- partial visual 표시
- fully revealed 판정

검증:

- 1칸 채굴 시 1/4 표시
- 2칸 채굴 시 2/4 표시
- 4칸 채굴 시 fully revealed
- fully revealed 전 interaction 불가 상태 유지

절대 금지:

- reward popup 구현
- 아이템 지급 구현
- StageTable/BlockCatalog 변경

---

## Phase 3. E 상호작용과 TreasureRewardPopup 최소 UI

목표:

- fully revealed marker 근처에서 E 상호작용으로 popup을 연다.
- popup은 아직 reward 지급 로직이 없거나 mock reward로 동작해도 된다.

수정/추가 예상 파일:

- `scenes/ui/TreasureRewardPopup.tscn`
- `scenes/ui/TreasureRewardPopup.gd`
- `Main.gd`
- `WallTreasureManager.gd`

구현 내용:

- nearest fully revealed treasure 조회
- E interaction 연결
- popup open/close
- pause 처리
- consumed 처리 준비

검증:

- fully revealed 전 E 무시
- fully revealed 후 E popup open
- 키오스크와 E 충돌 없음
- popup close 후 pause 해제

절대 금지:

- reward 지급/판매 최종 처리까지 무리하게 넣지 않음
- 기존 DayShopUI 동작 변경 금지

---

## Phase 4. Reward roll, 획득/판매, grant helper

목표:

- 실제 ShopItemCatalog 아이템을 reward로 roll한다.
- 획득/판매 선택을 구현한다.
- 골드 차감 없는 item grant helper를 추가한다.

수정/추가 예상 파일:

- `GameState.gd`
- `ShopItemCatalog.gd` 필요 시 helper 추가
- `TreasureRewardPopup.gd`
- `WallTreasureManager.gd`
- `treasure_chest_snapshot.gd` 확장

구현 내용:

- reward rank roll
- item candidate 조회
- sell price 계산
- `grant_shop_item_reward()` 구현
- 획득 버튼 처리
- 판매 버튼 처리
- consumed 처리

검증:

- sell price = effective price x 0.6 floor
- 획득 시 골드 차감 없음
- 판매 시 item 지급 없음, gold 증가
- attack_module/function_module/enhance_module 처리 정상
- 기존 purchase_shop_item 회귀 통과

절대 금지:

- 기존 상점 구매 비용/lock/reroll 동작 변경
- 공격모듈 수치 변경

---

## Phase 5. 문서 갱신과 회귀 테스트

목표:

- 구현 결과를 canonical 문서에 반영한다.
- snapshot과 회귀 테스트를 정리한다.

갱신 대상:

- `docs/02_systems_spec.md`
- `docs/03_data_and_state_spec.md`
- `docs/04_roadmap.md`

반영 내용:

- Normal chest → Bronze chest
- 1U / 2 x 2 wall subcell 구조
- partial reveal 규칙
- fully revealed 후 E 상호작용
- reward popup
- 획득/판매 선택
- 판매가 60%
- 크립은 미구현/TODO 유지

검증:

- `scripts/tests/balance_snapshot.gd`
- `scripts/tests/attack_module_dps_snapshot.gd`
- `scripts/tests/day_pressure_snapshot.gd`
- `scripts/tests/treasure_chest_snapshot.gd`
- Godot headless load
- `git diff --check`

---

## 18. 테스트 계획 상세

### Marker 테스트

- marker count가 설정값과 일치하는지
- marker size가 항상 2 x 2인지
- marker origin이 wall bounds 안인지
- marker 2 x 2 전체가 wall bounds 안인지
- row 0에 걸치지 않는지
- marker끼리 겹치지 않는지

### Reveal 테스트

- 특정 marker의 1개 subcell reveal 시 partial count 1
- 2개 reveal 시 partial count 2
- 3개 reveal 시 partial count 3
- 4개 reveal 시 fully revealed true
- 이미 revealed된 cell을 다시 reveal해도 count 중복 증가 없음

### Interaction 테스트

- hidden/partial 상태에서는 interaction 불가
- fully revealed 상태에서는 interaction 가능
- consumed 상태에서는 interaction 불가
- 키오스크 interaction과 충돌하지 않음

### Reward 테스트

- chest rarity table 총합 검증
- reward rank table 총합 검증
- reward rank S가 0%인 chest에서 S가 나오지 않음
- Gold/Platinum에서는 S 후보가 확률적으로 가능
- 후보 item이 현재 ShopItemCatalog에서 조회됨
- sell price가 유효 구매가의 60%
- grant helper가 골드 차감 없이 동작

### Regression 테스트

- 기존 상점 구매 정상
- 공격모듈 장착/합성 정상
- function/enhance module 적용 정상
- v1 블록 스폰 변경 없음
- v2 시뮬레이션 변경 없음
- day pressure snapshot 변경 없음 또는 변경 사유 명확

---

## 19. 주요 리스크

| 리스크 | 설명 | 대응 |
|---|---|---|
| 벽 좌표계 혼동 | wall column, subcell, world position 변환이 헷갈릴 수 있음 | Phase 1에서 좌표 변환 helper와 snapshot 먼저 작성 |
| Main.gd 비대화 | 모든 기능을 Main에 넣으면 유지보수 어려움 | WallTreasureManager 분리 |
| WorldGrid 책임 과다 | reward/popup까지 WorldGrid가 알면 구조가 흐려짐 | WorldGrid는 채굴 결과만 전달 |
| Partial visual 충돌 | wall tile draw와 treasure overlay가 겹칠 수 있음 | overlay layer를 별도 관리 |
| E interaction 충돌 | 키오스크와 treasure가 같은 E를 사용 | 우선순위와 range 명확화 |
| Pause 충돌 | LevelUpUI/DayShopUI/PauseMenu와 pause 충돌 가능 | popup 상태 flag와 close path 명확화 |
| Attack module 슬롯 부족 | reward가 attack_module인데 슬롯이 가득 찰 수 있음 | 합성 가능 우선, 불가 시 판매 유도/자동 판매 정책 |
| Shop 구매 회귀 | grant helper가 purchase_shop_item을 건드리다 기존 구매가 깨질 수 있음 | 공통 apply helper 분리 후 purchase regression 테스트 |

---

## 20. 첫 구현 Phase 권장

바로 구현해도 되는 범위는 **Phase 1**이다.

Phase 1 구현 지시 요약:

```text
Treasure Chest 1차 구현 계획서의 Phase 1만 구현해줘.
목표는 marker 데이터 구조와 marker 생성/snapshot까지다.
채굴 연동, partial visual, interaction, reward popup, item 지급은 아직 구현하지 마라.
```

Phase 1이 안정적으로 끝난 뒤 Phase 2로 넘어간다.

---

## 21. Codex Phase 1 지시 초안

```text
Burial Protocol 프로젝트에서 docs/reports/treasure_chest_implementation_plan.md의 Phase 1만 구현해줘.

목표:
- 보물상자 marker 데이터 구조 추가
- wall reset/런 시작 시 marker 생성 함수 추가
- 2 x 2 wall subcell bounds/overlap 검증
- bronze/silver/gold/platinum rarity roll table 추가
- marker snapshot 테스트 추가

금지:
- 채굴 연동 금지
- partial visual 금지
- E interaction 금지
- TreasureRewardPopup 금지
- reward roll/item grant 금지
- 기존 shop 구매 로직 변경 금지
- v1 블록 스폰 변경 금지
- v2 시뮬레이션 변경 금지
- StageTable/BlockCatalog/ShopItemCatalog 수치 변경 금지

완료 후 보고:
1. 추가/수정 파일
2. marker 저장 위치
3. marker 구조
4. marker 생성 개수와 rarity 확률
5. bounds/overlap 검증 방식
6. snapshot 테스트 결과
7. 기존 balance/attack/day snapshot 결과
8. Godot headless 결과
9. git diff --check 결과
```

---

## 22. 최종 결론

보물상자 1차 구현은 한 번에 진행하지 않는다.

권장 진행 순서:

```text
Phase 1: marker 생성/snapshot
Phase 2: mining reveal + partial visual
Phase 3: E interaction + popup
Phase 4: reward roll + grant/sell
Phase 5: 문서 갱신 + 회귀 테스트
```

현재 가장 안전한 다음 작업은 **Phase 1만 구현**하는 것이다.
---

## 22. 구현 완료 기록

기준일: `2026-05-17`

Phase 1~5는 현재 구현 및 문서 반영까지 완료되었다.

완료된 범위:

- Phase 1: treasure marker 데이터 구조, 2 x 2 wall subcell marker 생성, bounds/overlap/rarity snapshot
- Phase 2: wall mining 연동, 채굴 전 preview visual, 채굴된 quadrant partial reveal, fully revealed 판정
- Phase 3: fully revealed marker `E` 상호작용, prompt, `TreasureRewardPopup`, pause/close 처리
- Phase 4: reward rank roll, ShopItemCatalog reward 후보 roll, 획득/판매, grant helper, consumed 처리
- Phase 5: canonical 문서 갱신, treasure snapshot 확장, headless 검증

현재 구현 파일:

- `scripts/data/TreasureChestMarkerData.gd`
- `scripts/data/WallTreasureManager.gd`
- `scenes/ui/TreasureRewardPopup.gd`
- `scenes/ui/TreasureRewardPopup.tscn`
- `scenes/main/Main.gd`
- `scenes/world/WorldGrid.gd`
- `scripts/data/ShopItemCatalog.gd`
- `scripts/autoload/GameState.gd`
- `scripts/tests/treasure_chest_snapshot.gd`

현재 검증:

- marker 생성 수, bounds, row 0 금지, overlap 없음
- preview visual과 rarity palette
- partial reveal과 fully revealed
- interaction prompt 조건
- reward rank table 총합
- reward candidate roll과 fallback
- sell price 60%
- grant helper gold 차감 없음
- consumed 후 prompt/interaction/visual 제외
- popup signal과 paused process mode

남은 후속 작업은 공식 Phase가 아니라 별도 계획으로 분리한다.

- creep 구현
- sprite 기반 treasure art polish
- marker 생성 수와 reward 확률 밸런스 확정
- popup icon/slot full UX 개선
- 기존 shop regression 실패 항목 정리
