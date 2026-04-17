# 작업 지시서 v2

## 구현 현황 메모 (2026-04-18)

이 문서는 원래 작업 지시서지만, 현재 코드 기준 반영 상태를 아래처럼 함께 기록한다.

- 타이틀 → 메인 허브 → 난이도 선택 → 런 → 결과 화면의 최소 전체 루프가 연결되어 있다
- 캐릭터 선택 화면과 업적 / 성장 / 아이템 목록 placeholder 화면이 존재한다
- 단일 프로필 저장 구조가 있으며 선택 캐릭터, 마지막 난이도, 최소 최고기록, 영구 재화, 설정, 해금 상태를 저장한다
- 공격과 채굴은 이미 좌클릭 / 우클릭으로 분리되어 있다
- 채굴 범위 기준점은 현재 충돌 바디 기준으로 정렬되도록 보정되었다
- 남은 대표 이슈는 좌측 벽 채굴 시 바깥벽보다 안쪽 벽이 먼저 깎일 수 있는 순서 문제다

## 0. 작업 목표

Burial Protocol의 전투/채굴/모래 상호작용을 다음 기준으로 재설계하라.

### 입력 규칙

- **공격은 좌클릭**
- **채굴은 우클릭**

### 스탯 분리

- 공격 데미지와 채굴 데미지는 별도 스탯으로 관리한다.
- 공격 범위와 채굴 범위는 별도 스탯으로 관리한다.

### 기본 범위

- 공격 범위 기본값: **1U x 1U**
- 채굴 범위 기본값:
  - 채굴 높이: **1U**
  - 채굴 거리: **0.25U**

### 채굴 대상

- 채굴은 **벽**과 **모래** 둘 다 대상으로 할 수 있어야 한다.
- 우클릭 시:
  1. 모래 채굴 시도
  2. 모래가 없으면 벽 채굴 시도
  3. 둘 다 없으면 실패

### 모래 채굴 성능 원칙

- 모래 채굴은 **모래 셀 직접 삭제** 방식으로 구현한다.
- 단, 삭제 직후 **위 적층 전체의 최종 위치를 한 프레임에 계산하면 안 된다.**
- 삭제된 셀 주변만 활성화하고, 기존 `SandField.step_simulation()` 이 여러 프레임에 걸쳐 붕괴/흐름/안정화를 처리하게 한다.

---

## 1. 현재 구조에서 유지할 것

다음은 유지한다.

- `SandField.sand_cells`
- `SandField.active_cells`
- `SandField.step_simulation(focus_rect)` 기반 국소 흐름
- `WorldGrid` 의 벽 관리 책임
- `Player` 의 입력/이동/범위 계산 책임
- `Main` 의 액션 실행 책임

---

## 2. 입력 재설계

## 2-1. 입력맵 변경

현재 `project.godot` 와 `GameConstants.INPUT_BINDINGS` 에는 `primary_action` 만 존재한다. 이를 아래처럼 바꿔라.

### 새 입력 액션

- `attack_action` = 마우스 좌클릭
- `mine_action` = 마우스 우클릭

### 처리 지침

- `primary_action` 은 더 이상 핵심 액션으로 사용하지 않는다.
- 필요하면 하위 호환용으로 남겨둘 수는 있으나, 실사용 로직에서는 제거하라.

---

## 3. 스탯 재설계

## 3-1. GameConstants에 새 상수 추가

`GameConstants.gd` 에 아래 상수를 추가하라. 기존 공격 상수는 공격 전용으로 명확히 정리하라.

### 공격 스탯

- `PLAYER_ATTACK_DAMAGE := 1`
- `PLAYER_ATTACK_RANGE_WIDTH := float(CELL_SIZE)`
- `PLAYER_ATTACK_RANGE_HEIGHT := float(CELL_SIZE)`
- `PLAYER_ATTACK_COOLDOWN := 0.1`

### 채굴 스탯

- `PLAYER_MINING_DAMAGE := 1`
- `PLAYER_MINING_RANGE_DISTANCE := float(CELL_SIZE) * 0.25`
- `PLAYER_MINING_RANGE_HEIGHT := float(CELL_SIZE)`
- `PLAYER_MINING_COOLDOWN := 0.12`

### 모래 채굴 관련

- `SAND_MINING_MAX_CELLS_PER_ACTION := 3`
- `SAND_MINING_ACTIVE_RADIUS := 3`

### 벽 채굴 관련

- 현재 벽은 1회 채굴로 1셀 제거다.  
  이번 단계에서는 단순 유지 가능.
- 단, 구조상 `PLAYER_MINING_DAMAGE` 를 통해 추후 다단계 채굴이 가능하도록 설계하라.

---

## 4. Player.gd 재설계

`Player.gd` 는 더 이상 “primary_action 하나를 소비”하는 구조에 묶이지 않게 바꿔라. 현재 `consume_primary_action_direction()` 중심 구조를 공격/채굴 각각으로 분리하라.

## 4-1. 공격 입력 처리 분리

### 추가 함수

- `func consume_attack_direction() -> Vector2`
- `func can_attack() -> bool`

### 요구사항

- 좌클릭 입력 버퍼/쿨다운을 별도로 관리한다.
- 공격 방향은 현재와 동일하게 마우스 방향 기준 4방향 양자화 유지 가능.
- 공격은 기존처럼 블록 타격 전용이다.

---

## 4-2. 채굴 입력 처리 분리

### 추가 함수

- `func consume_mining_direction() -> Vector2`
- `func can_mine() -> bool`

### 요구사항

- 우클릭 입력 버퍼/쿨다운을 별도로 관리한다.
- 채굴 방향은 공격과 같은 방향 판정 기반을 재사용해도 된다.
- 단, 채굴 범위 계산은 공격 범위와 별도로 해야 한다.

---

## 4-3. 공격 범위 계산 함수 수정

현재 `get_attack_shape_data(direction)` 는 공격 범위를 반환한다. 이 함수는 공격 전용으로 유지하되, 크기를 새 상수 기준으로 변경하라.

### 요구사항

- 기본 공격 범위는 정확히 `1U x 1U`
- 플레이어 기준 시작
- 클릭 위치 기준 금지

---

## 4-4. 채굴 범위 계산 함수 추가

### 새 함수

- `func get_mining_rect(direction: Vector2) -> Rect2`

### 규칙

- 채굴 높이 = `1U`
- 채굴 거리 = `0.25U`
- 플레이어 바로 앞의 좁은 직사각형
- 방향별로 올바르게 배치할 것
- 공격 범위와 독립적으로 계산할 것

### 권장 해석

- 좌우 채굴:
  - 너비 = `0.25U`
  - 높이 = `1U`
- 상향 채굴:
  - 너비 = `1U`
  - 높이 = `0.25U`
- 하향 채굴:
  - 필요하면 지원하되, 우선순위는 낮다

---

## 4-5. 점프 시 모래 강제 정리 제거

현재 `_apply_jump_input()` 에서 `sand_field.try_clear_jump_space(...)` 를 호출한다. 이번 재설계에서는 이 호출을 제거하라.

이유:

- 점프와 모래 정리를 분리해야 한다.
- 이제 채굴이 별도 액션이므로, 점프 입력마다 모래 연쇄 정리를 넣을 이유가 없다.

---

## 5. Main.gd 재설계

현재 `_physics_process()` 와 `_handle_primary_action()` 구조를 공격/채굴로 분리하라.

## 5-1. 새 처리 구조

### `_physics_process()` 에서

- `player.consume_attack_direction()` 호출
- 방향이 있으면 `_handle_attack_action(direction)` 호출
- `player.consume_mining_direction()` 호출
- 방향이 있으면 `_handle_mining_action(direction)` 호출
- 이후 `sand_field.step_simulation(player.get_body_rect())` 유지

---

## 5-2. 공격 처리 함수 추가

### 새 함수

- `func _handle_attack_action(direction: Vector2) -> void`

### 동작

- 현재 `_handle_primary_action()` 의 블록 히트 부분을 이 함수로 이동
- 낙하 블록만 타격
- 벽/모래 채굴 로직은 포함하지 말 것
- 데미지는 `PLAYER_ATTACK_DAMAGE` 사용

---

## 5-3. 채굴 처리 함수 추가

### 새 함수

- `func _handle_mining_action(direction: Vector2) -> void`

### 우선순위

1. `sand_field.try_mine_in_rect(player.get_mining_rect(direction), direction, GameConstants.PLAYER_MINING_DAMAGE)` 호출
2. 삭제된 셀이 없으면 `world_grid.try_mine_in_rect(...)` 호출
3. 둘 다 실패하면 miss 메시지

### 상태 메시지

- 모래 채굴 성공:
  - `"Mined %d sand cell(s)."`
- 벽 채굴 성공:
  - `"Mined a wall cell to open space."`
- 실패:
  - `"Mining hit nothing."`

---

## 6. SandField.gd 재설계

## 6-1. 모래 채굴 API 추가

### 새 공개 함수

`func try_mine_in_rect(mine_rect: Rect2, direction: Vector2, mining_damage: int) -> int`

### 반환값

- 삭제한 모래 셀 수

### 동작

1. `mine_rect` 와 겹치는 `sand_cells` 후보 수집
2. 방향 기준으로 정렬
3. `min(mining_damage, SAND_MINING_MAX_CELLS_PER_ACTION)` 개까지만 삭제
4. 삭제 셀 주변만 active 처리
5. 기존 흐름에 맡긴다
6. 전체 적층 즉시 재계산 금지
7. 삭제 개수 반환

---

## 6-2. 삭제 후 처리 규칙

삭제된 셀에 대해:

- `sand_cells.erase(cell)`
- 삭제 셀 목록 저장
- push/jump signature 캐시 초기화
- `_mark_active_after_mining(mined_cells)` 호출
- `queue_redraw()`

---

## 6-3. `_mark_active_after_mining()` 추가

### 함수

`func _mark_active_after_mining(mined_cells: Array[Vector2i]) -> void`

### 활성 범위

각 삭제 셀마다:

- 위 4셀
- 아래 1셀
- 좌우 2셀

작은 국소 직사각형만 active 처리하라.

중요:

- 전역 active 처리 금지
- 삭제 후 전체 맵 흔들기 금지

---

## 6-4. 후보 셀 정렬 규칙

### 좌우 채굴

- 플레이어 쪽에 가까운 셀 우선
- 같은 거리면 더 아래 셀 우선

### 상향 채굴

- 머리 바로 위 셀 우선
- 중심축에 가까운 셀 우선

### 구현 방식

- 단순 후보 수집 후 정렬
- 재귀 탐색 금지
- 연쇄 이동 계산 금지

---

## 7. WorldGrid.gd 확장

현재 `try_mine_in_rect(attack_rect, direction)` 는 벽 셀 1개를 지운다.

이번 단계에서는 기능 유지해도 되지만, 아래처럼 인터페이스를 확장하라.

### 권장 수정

`func try_mine_in_rect(attack_rect: Rect2, direction: Vector2i, mining_damage: int = 1) -> bool`

### 요구사항

- 현재는 mining_damage를 무시하고 1셀만 제거해도 된다.
- 그러나 추후 여러 셀 제거로 확장 가능하도록 인터페이스를 열어 둬라.

---

## 8. 절대 하지 말 것

### 8-1. 모래 채굴 직후 전체 더미 최종 위치 계산 금지

하단을 팠다고 위 전체 모래의 최종 배치를 한 번에 계산하지 마라.

### 8-2. 깊은 재귀 붕괴 금지

채굴 후 연쇄적으로 셀 전체를 재귀 이동시키지 마라.

### 8-3. 공격과 채굴 재통합 금지

좌클릭/우클릭 입력을 다시 하나의 액션으로 합치지 마라.

### 8-4. 범위 하드코딩 금지

공격 범위와 채굴 범위는 반드시 상수/스탯으로 관리하라. Project Rules의 매직 넘버 금지 원칙을 따른다.

---

## 9. 변경 파일

반드시 수정:

- `project.godot`
- `scripts/autoload/GameConstants.gd`
- `scenes/player/Player.gd`
- `scenes/world/SandField.gd`
- `scenes/world/WorldGrid.gd`
- `scenes/main/Main.gd`

필요 시 경미한 HUD/디버그 수정 허용.

---

## 10. 완료 기준

1. 좌클릭으로 낙하 블록만 공격된다.
2. 우클릭으로 모래 또는 벽을 채굴한다.
3. 공격 데미지/채굴 데미지가 별도 스탯이다.
4. 공격 범위/채굴 범위가 별도 스탯이다.
5. 공격 기본 범위가 `1U x 1U` 다.
6. 채굴 기본 범위가 `높이 1U / 거리 0.25U` 다.
7. 모래 채굴 후 전체 더미가 즉시 재정렬되지 않는다.
8. 모래 채굴 후 주변만 활성화되고, 여러 프레임에 걸쳐 자연스럽게 무너진다.
9. 점프 입력이 모래 강제 정리 탐색을 일으키지 않는다.

---

## 10-1. 현재 확인된 후속 수정 항목

- 벽 채굴 셀 순회가 방향성을 반영하지 않아 좌측 채굴 우선순위가 어긋날 수 있다
- 세로 월드는 큰 고정 높이 기반이라 화면 스펙 문서의 장기 확장 요구와는 별도 점검이 더 필요하다

---

## 11. 수동 테스트 시나리오

### 시나리오 A: 좌클릭 공격

- 낙하 블록이 공격 범위 안에 있을 때 좌클릭
- 기대 결과:
  - 블록만 타격됨
  - 모래/벽 채굴 안 됨

### 시나리오 B: 우클릭 모래 채굴

- 플레이어 앞에 작은 모래 더미 생성
- 우클릭
- 기대 결과:
  - 정면 모래 셀 일부 제거
  - 위 더미는 즉시 텔레포트 재배치되지 않음
  - 몇 프레임 동안 자연 붕괴

### 시나리오 C: 우클릭 벽 채굴

- 정면에 모래 없이 벽만 있는 상태
- 우클릭
- 기대 결과:
  - 벽 1셀 제거

### 시나리오 D: 공격/채굴 범위 분리 확인

- 블록과 벽/모래를 각각 다른 거리와 위치에 배치
- 기대 결과:
  - 공격 판정과 채굴 판정이 서로 다른 범위로 동작

### 시나리오 E: 반복 채굴 안정성

- 작은 모래 더미를 향해 연속 우클릭
- 기대 결과:
  - 급격한 프레임 저하 없이 동작
  - 전체 맵 active 폭증 없음
