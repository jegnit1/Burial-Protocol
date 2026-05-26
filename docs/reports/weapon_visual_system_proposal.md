# Burial Protocol - 장착 무기 시각 연출 시스템 개편안

기준일: `2026-05-26`  
목적: 팔이 없는 캐릭터 구조에 맞춰, 장착 무기가 캐릭터의 손에 들린 것처럼 보이는 방식이 아니라 `등 뒤에 부유하다가 공격 시 머리 위 전투 위치로 이동해 공격하는 방식`으로 표현되도록 구현 지침을 정의한다.

---

## 0. 핵심 결론

캐릭터에게 팔이 없으므로, 무기를 손에 쥔 것처럼 표현하지 않는다.

최종 방향은 아래와 같다.

```text
평상시: 장착 무기는 캐릭터 등 뒤/상단에 부유한다.
공격 입력 시: 장착 무기는 캐릭터 머리 위 전투 위치로 이동한다.
연속 공격 중: 무기는 머리 위 전투 위치를 유지하며 공격 모션만 반복한다.
일정 시간 공격이 없을 때: 무기는 등 뒤 Idle 위치로 복귀한다.
```

즉, 무기 표현은 아래 개념으로 잡는다.

```text
손에 든 무기 X
등 뒤에 떠 있는 외장 무기 O
머리 위에서 자동 공격하는 무기 O
팔 없는 소형 로봇이 제어하는 부유 무기 O
```

---

## 1. 배경

현재 캐릭터 레퍼런스는 팔이 없는 단순 로봇형 캐릭터다.

따라서 일반적인 액션 게임처럼 캐릭터 손 위치에 무기를 붙이는 방식은 어색하다.

문제점:

```text
1. 캐릭터에게 팔/손이 없음
2. 손잡이 위치 기준 장착 방식이 맞지 않음
3. 무기별 손잡이 pivot을 맞춰도 시각적으로 쥐고 있는 느낌이 나기 어려움
4. 무기 공격 모션을 캐릭터 팔 애니메이션과 연결할 수 없음
```

이에 따라 무기는 캐릭터의 신체 일부가 아니라, 캐릭터가 제어하는 외장 장비/부유 무기처럼 표현한다.

---

## 2. 최종 연출 목표

### 2-1. Idle 상태

장착된 무기는 캐릭터 등 뒤 또는 머리 뒤쪽 상단에 부유한 채로 따라다닌다.

Idle 상태에서는 무기가 가만히 고정되지 않고, 위아래로 부드럽게 움직이는 bobbing motion을 가진다.

```text
무기 idle 위치 = 캐릭터 중심 기준 등 뒤/상단
무기 idle 동작 = 위아래 부유
무기 idle z_index = 캐릭터보다 뒤쪽
```

### 2-2. 공격 시작

사용자가 공격을 입력하면, 등 뒤에 있던 무기가 머리 위 전투 위치로 이동한다.

```text
등 뒤 idle 위치 → 머리 위 combat ready 위치
```

이 이동은 순간이동이 아니라 짧은 시간 동안 부드럽게 이동한다.

### 2-3. 공격 상태

무기가 머리 위 전투 위치에서 실제 공격 연출을 수행한다.

근거리 무기는 공격 스타일에 따라 베기, 찌르기, 관통, 내려찍기, 큰 베기 등의 모션을 수행한다.

원거리 무기는 발사 순간 살짝 뒤로 밀리는 반동 모션을 수행한다.

### 2-4. 연속 공격 상태

공격이 계속 이어지는 동안, 무기는 매 타격마다 등 뒤로 복귀하지 않는다.

무기는 머리 위 전투 위치에 머문 상태로 공격 모션만 반복한다.

```text
나쁜 방식:
공격마다 등 뒤 → 머리 위 → 공격 → 등 뒤 반복

좋은 방식:
첫 공격 때만 등 뒤 → 머리 위 이동
연속 공격 중에는 머리 위 유지
공격 모션만 반복
```

### 2-5. 공격 종료 후 복귀

마지막 공격 이후 일정 시간 동안 추가 공격이 없으면, 무기는 등 뒤 Idle 위치로 복귀한다.

이를 위해 `weapon_return_delay` 개념을 둔다.

```text
공격 발생 → weapon_return_delay 타이머 리셋
weapon_return_delay > 0 → 머리 위 전투 위치 유지
weapon_return_delay <= 0 → 등 뒤 Idle 위치로 복귀
```

---

## 3. 상태 머신

무기 시각 연출은 상태 머신으로 관리한다.

권장 상태:

```text
IDLE_BACK
MOVING_TO_READY
READY_OVERHEAD
ATTACKING
RETURNING_TO_BACK
```

### 3-1. IDLE_BACK

평상시 상태다.

```text
위치: 캐릭터 등 뒤/상단
동작: 위아래 bobbing
z_index: 캐릭터보다 뒤
```

### 3-2. MOVING_TO_READY

공격 입력이 들어와 무기가 머리 위 전투 위치로 이동하는 상태다.

```text
시작 위치: 등 뒤 idle 위치
목표 위치: 머리 위 ready 위치
이동 방식: lerp 또는 tween
이동 시간: 0.08~0.15초 권장
```

### 3-3. READY_OVERHEAD

무기가 머리 위에서 전투 대기 중인 상태다.

```text
위치: 머리 위 ready 위치
z_index: 캐릭터보다 앞 또는 같은 레이어 상단
동작: 아주 약한 bobbing 또는 정지
역할: 연속 공격 사이 대기
```

### 3-4. ATTACKING

무기가 현재 무기의 공격 스타일에 맞는 시각 연출을 수행하는 상태다.

```text
근거리: slash/stab/pierce/smash/cleave 모션
원거리: recoil 모션
레이저: 발사 준비/짧은 충격 모션
```

주의:

```text
무기 visual 애니메이션은 실제 공격 판정과 분리한다.
```

### 3-5. RETURNING_TO_BACK

일정 시간 공격이 없어서 무기가 등 뒤 Idle 위치로 복귀하는 상태다.

```text
시작 위치: 머리 위 ready 위치
목표 위치: 등 뒤 idle 위치
이동 방식: lerp 또는 tween
이동 시간: 0.12~0.20초 권장
복귀 완료 후 상태: IDLE_BACK
```

---

## 4. 상태 전환 규칙

### 4-1. 기본 전환

```text
IDLE_BACK
  공격 입력 발생
  → MOVING_TO_READY
  → ATTACKING
  → READY_OVERHEAD

READY_OVERHEAD
  추가 공격 발생
  → ATTACKING
  → READY_OVERHEAD

READY_OVERHEAD
  weapon_return_delay 만료
  → RETURNING_TO_BACK
  → IDLE_BACK
```

### 4-2. 공격 발생 시 공통 처리

공격이 발생하면 아래 처리를 수행한다.

```text
1. weapon_return_delay_remaining을 WEAPON_RETURN_DELAY로 리셋한다.
2. 무기가 IDLE_BACK 또는 RETURNING_TO_BACK 상태라면 MOVING_TO_READY로 전환한다.
3. 무기가 READY_OVERHEAD 상태라면 즉시 ATTACKING으로 전환한다.
4. 무기가 ATTACKING 상태라면 현재 공격 모션이 끝난 뒤 다음 공격 모션을 재생하거나, 가능한 경우 공격 모션을 갱신한다.
```

초기 구현에서는 공격 입력이 발생했을 때 기존 모션을 강제로 끊지 않아도 된다.

권장 초기 정책:

```text
현재 ATTACKING 중이면:
- return delay만 갱신한다.
- 다음 실제 공격 트리거 시 새 ATTACKING을 시작한다.
```

### 4-3. 복귀 대기시간

기본 상수:

```gdscript
const WEAPON_RETURN_DELAY := 0.45
```

무기 타입별로 후속 조정 가능하다.

| 무기 | 권장 복귀 대기시간 |
|---|---:|
| 단검 | 0.30초 |
| 소드 | 0.40초 |
| 랜스 | 0.45초 |
| 도끼 | 0.55초 |
| 대검 | 0.65초 |
| 원거리 | 0.45초 |
| 레이저 | 0.50초 |

초기 구현은 전 무기 공통 `0.45초`로 시작해도 된다.

---

## 5. 노드 구조 권장안

Player 씬 하위에 무기 시각 연출용 노드를 추가한다.

```text
Player(Node2D)
├─ AnimatedSprite2D              # 캐릭터 본체
├─ WeaponVisualRoot(Node2D)      # 무기 visual 전체 루트
│  └─ WeaponVisual(Node2D)       # 현재 장착 무기 visual 인스턴스
├─ WeaponBackAnchor(Node2D)      # 등 뒤 idle 기준 위치
└─ WeaponReadyAnchor(Node2D)     # 머리 위 전투 기준 위치
```

또는 Anchor 노드를 실제 씬에 만들지 않고, 코드 상수로 처리해도 된다.

```gdscript
const WEAPON_BACK_OFFSET := Vector2(0.0, -26.0)
const WEAPON_READY_OFFSET := Vector2(0.0, -42.0)
```

초기 구현은 코드 상수 방식이 빠르다.

---

## 6. 위치/레이어 규칙

### 6-1. Idle 위치

```gdscript
const WEAPON_BACK_OFFSET := Vector2(0.0, -26.0)
```

캐릭터 크기에 따라 조정한다.

의미:

```text
캐릭터 중심보다 위쪽
캐릭터 등 뒤에 떠 있는 느낌
몸통과 너무 겹치지 않음
```

### 6-2. Ready 위치

```gdscript
const WEAPON_READY_OFFSET := Vector2(0.0, -42.0)
```

의미:

```text
캐릭터 머리 위
공격 방향으로 움직일 여유가 있는 위치
```

### 6-3. Idle bobbing

Idle 상태에서는 위아래로 부드럽게 움직인다.

```gdscript
const WEAPON_IDLE_BOB_AMPLITUDE := 3.0
const WEAPON_IDLE_BOB_SPEED := 2.4
```

계산 예시:

```gdscript
var bob_offset := Vector2(0.0, sin(weapon_bob_time) * WEAPON_IDLE_BOB_AMPLITUDE)
```

### 6-4. z_index

평상시에는 등 뒤에 있어야 하므로 캐릭터보다 뒤에 표시한다.

```text
IDLE_BACK / RETURNING_TO_BACK:
WeaponVisual.z_index = BodySprite.z_index - 1
```

공격 준비/공격 중에는 머리 위에서 보이게 한다.

```text
MOVING_TO_READY / READY_OVERHEAD / ATTACKING:
WeaponVisual.z_index = BodySprite.z_index + 1
```

---

## 7. 무기 에셋 제작 규칙

### 7-1. 기본 방향

모든 무기 에셋은 기본 공격 방향이 오른쪽이라고 가정하고 제작한다.

```text
무기 기본 방향 = 오른쪽
```

코드는 공격 방향에 따라 이 이미지를 회전시킨다.

```gdscript
weapon_visual.rotation = attack_direction.angle()
```

### 7-2. 캔버스 크기

모든 무기 에셋은 가능하면 같은 캔버스 크기를 사용한다.

권장:

```text
48x48
또는
64x64
```

무기의 실제 크기는 달라도 된다.

```text
단검: 작게 그림
소드: 중간 크기
대검: 크게 그림
랜스: 길게 그림
```

중요한 것은 실제 무기 크기가 아니라, 에셋 기준점과 방향이 일관되는 것이다.

### 7-3. 기준점

팔/손이 없으므로 손잡이 기준점이 아니라 `부유 무기 중심 기준점`을 사용한다.

권장:

```text
무기 visual의 중심축이 캔버스 중앙 근처에 오도록 제작
무기 공격 방향은 오른쪽으로 뻗게 제작
무기의 회전 기준이 어색하지 않도록 중심 또는 연결부 위치를 맞춤
```

### 7-4. 회전 관련 주의

픽셀아트 무기를 자유 회전하면 도트가 깨져 보일 수 있다.

초기 구현은 회전으로 처리한다.

후속 고품질 작업에서는 아래 방식으로 개선할 수 있다.

```text
4방향 무기 프레임
8방향 무기 프레임
공격 스타일별 전용 스프라이트시트
```

---

## 8. 공격 스타일별 시각 연출

공격 연출은 실제 공격 판정과 분리한다.

```text
무기 visual = 화면 연출
공격 판정 = 기존 무기/공격 로직
```

### 8-1. slash

대상: 소드 등 일반 베기 무기

연출:

```text
머리 위 ready 위치에서 공격 방향으로 짧게 회전하며 베기
작은 호를 그리는 느낌
```

권장 값:

```text
회전 시작: -35도
회전 종료: +35도
전진 거리: 10~14px
시간: 0.10~0.14초
```

### 8-2. stab

대상: 단검

연출:

```text
공격 방향으로 빠르게 찌르고 즉시 복귀
회전은 거의 없음
```

권장 값:

```text
전진 거리: 14~18px
시간: 0.06~0.09초
복귀 빠름
```

### 8-3. pierce

대상: 랜스

연출:

```text
공격 방향으로 길게 뻗는 찌르기
stab보다 전진 거리가 길고 약간 느림
```

권장 값:

```text
전진 거리: 20~28px
시간: 0.10~0.14초
```

### 8-4. smash

대상: 도끼

연출:

```text
머리 위에서 살짝 들어올렸다가 공격 방향으로 내려찍는 느낌
```

권장 값:

```text
준비 회전: -25도
타격 회전: +55도
전진 거리: 10~16px
시간: 0.14~0.18초
```

### 8-5. cleave

대상: 대검

연출:

```text
큰 호를 그리며 묵직하게 베기
slash보다 회전 폭이 크고 느림
```

권장 값:

```text
회전 시작: -55도
회전 종료: +65도
전진 거리: 14~20px
시간: 0.18~0.24초
```

### 8-6. ranged / rifle

대상: 보우, 총, 기본 원거리

연출:

```text
발사 순간 공격 반대 방향으로 짧게 밀렸다가 복귀
```

권장 값:

```text
반동 거리: 6~10px
시간: 0.08~0.12초
```

### 8-7. shotgun / scatter

대상: 산탄

연출:

```text
일반 원거리보다 큰 반동
짧고 묵직하게 뒤로 밀림
```

권장 값:

```text
반동 거리: 10~14px
시간: 0.10~0.14초
```

### 8-8. sniper / pierce ranged

대상: 관통/저격 계열

연출:

```text
작지만 선명한 반동
발사 직전 짧게 고정되는 느낌 가능
```

권장 값:

```text
반동 거리: 8~12px
시간: 0.10~0.14초
```

### 8-9. laser

대상: 레이저

연출:

```text
발사 직전 짧은 충전/흔들림
발사 순간 아주 작은 반동 또는 고정
```

권장 값:

```text
반동 거리: 3~6px
시간: 0.08~0.12초
```

### 8-10. drone

대상: 드론 계열

주의:

```text
드론은 장착 무기 visual 시스템과 다르게 별도 독립 드론으로 표현할 수 있다.
```

초기에는 weapon visual 시스템에 포함해도 되지만, 후속 작업에서 별도 드론 visual manager로 분리 가능하다.

---

## 9. 코드 구조 권장안

### 9-1. Player 상태 변수

`Player.gd`에 아래 상태를 추가하는 것을 권장한다.

```gdscript
enum WeaponVisualState {
    IDLE_BACK,
    MOVING_TO_READY,
    READY_OVERHEAD,
    ATTACKING,
    RETURNING_TO_BACK,
}

var weapon_visual_state := WeaponVisualState.IDLE_BACK
var weapon_visual: Node2D
var weapon_bob_time := 0.0
var weapon_return_delay_remaining := 0.0
var weapon_attack_time_remaining := 0.0
var weapon_transition_time_remaining := 0.0
var weapon_visual_position := Vector2.ZERO
var weapon_attack_direction := Vector2.RIGHT
```

기존 `attack_module_visuals` 다중 장착 구조는 무기 1개 시스템으로 개편 시 제거 또는 단일 weapon visual 구조로 대체한다.

### 9-2. 기본 상수

```gdscript
const WEAPON_BACK_OFFSET := Vector2(0.0, -26.0)
const WEAPON_READY_OFFSET := Vector2(0.0, -42.0)
const WEAPON_IDLE_BOB_AMPLITUDE := 3.0
const WEAPON_IDLE_BOB_SPEED := 2.4
const WEAPON_MOVE_TO_READY_DURATION := 0.12
const WEAPON_RETURN_TO_BACK_DURATION := 0.16
const WEAPON_RETURN_DELAY := 0.45
```

실제 값은 캐릭터 에셋 크기에 맞게 조정한다.

### 9-3. 공격 발생 시 호출 함수

기존 공격 입력 처리 시점에서 아래 함수를 호출한다.

```gdscript
func _play_weapon_attack_visual(direction: Vector2, weapon_definition) -> void:
    if direction == Vector2.ZERO:
        direction = Vector2.RIGHT

    weapon_attack_direction = direction.normalized()
    weapon_return_delay_remaining = WEAPON_RETURN_DELAY

    if weapon_visual_state == WeaponVisualState.IDLE_BACK or weapon_visual_state == WeaponVisualState.RETURNING_TO_BACK:
        weapon_visual_state = WeaponVisualState.MOVING_TO_READY
        weapon_transition_time_remaining = WEAPON_MOVE_TO_READY_DURATION
        return

    _start_weapon_attack_motion(weapon_definition)
```

주의:

```text
첫 공격에서 MOVING_TO_READY로 전환되면, 이동 완료 후 ATTACKING을 시작해야 한다.
```

이를 위해 pending attack visual flag를 둘 수 있다.

```gdscript
var weapon_pending_attack_visual := false
```

### 9-4. 업데이트 함수

`_physics_process` 또는 `_process`에서 매 프레임 갱신한다.

```gdscript
func _update_weapon_visual(delta: float) -> void:
    weapon_bob_time += delta * WEAPON_IDLE_BOB_SPEED
    weapon_return_delay_remaining = maxf(weapon_return_delay_remaining - delta, 0.0)

    match weapon_visual_state:
        WeaponVisualState.IDLE_BACK:
            _update_weapon_idle_back(delta)
        WeaponVisualState.MOVING_TO_READY:
            _update_weapon_moving_to_ready(delta)
        WeaponVisualState.READY_OVERHEAD:
            _update_weapon_ready_overhead(delta)
        WeaponVisualState.ATTACKING:
            _update_weapon_attacking(delta)
        WeaponVisualState.RETURNING_TO_BACK:
            _update_weapon_returning_to_back(delta)
```

### 9-5. 복귀 처리

READY 상태에서 return delay가 만료되면 복귀한다.

```gdscript
func _update_weapon_ready_overhead(delta: float) -> void:
    weapon_visual.position = WEAPON_READY_OFFSET
    if weapon_return_delay_remaining <= 0.0:
        weapon_visual_state = WeaponVisualState.RETURNING_TO_BACK
        weapon_transition_time_remaining = WEAPON_RETURN_TO_BACK_DURATION
```

### 9-6. Idle bobbing 처리

```gdscript
func _update_weapon_idle_back(delta: float) -> void:
    var bob := Vector2(0.0, sin(weapon_bob_time) * WEAPON_IDLE_BOB_AMPLITUDE)
    weapon_visual.position = WEAPON_BACK_OFFSET + bob
```

---

## 10. 실제 공격 판정과의 관계

무기 visual은 실제 공격 판정에 영향을 주지 않는다.

```text
금지:
무기 이미지 위치를 기준으로 공격 판정 계산
무기 이미지 크기를 기준으로 공격 범위 계산
무기 visual 회전을 기준으로 hitbox를 직접 변경
```

권장:

```text
기존 공격 판정 로직 유지
무기 스탯/범위/공속은 데이터로 계산
무기 visual은 공격 입력과 attack_style에 맞는 화면 연출만 담당
```

이유:

```text
1. 밸런스 조정이 쉬움
2. 에셋 크기 변경이 전투 판정에 영향을 주지 않음
3. 애니메이션 수정이 데미지/히트박스 버그로 이어지지 않음
```

---

## 11. 기존 코드에서 변경 방향

현재 구조에는 공격모듈 visual을 플레이어 주위에 공전시키는 로직이 있다.

개편 후에는 아래 방향으로 변경한다.

### 11-1. 기존 개념

```text
여러 attack_module_visual이 캐릭터 주변을 원형 공전
공격 시 strike offset 적용
```

### 11-2. 신규 개념

```text
현재 장착 weapon visual 1개만 표시
평상시 등 뒤에 부유
공격 시 머리 위로 이동
연속 공격 중 머리 위 유지
일정 시간 후 등 뒤 복귀
```

### 11-3. 제거 또는 대체 대상

기존 다중 모듈 시각화 관련 상태는 무기 1개 시스템에서 제거 또는 단순화한다.

```text
attack_module_visuals Dictionary
attack_module_orbit_angle
attack_module_bob_time
ATTACK_MODULE_ORBIT_RADIUS
ATTACK_MODULE_ORBIT_SPEED
```

단, `bob_time`, `strike_direction`, `strike_duration` 같은 개념은 weapon visual용으로 이름을 바꿔 재사용해도 된다.

---

## 12. 금지사항

아래는 구현하지 않는다.

```text
무기를 캐릭터 손에 쥐는 표현
팔/손이 있는 것처럼 보이게 하는 임시 팔 추가
공격마다 등 뒤와 머리 위를 반복 왕복하는 연출
무기 이미지 크기를 실제 공격 판정으로 사용하는 방식
무기 visual을 여러 개 공전시키는 기존 공격모듈 방식 유지
무기 에셋마다 기본 방향이 제각각인 구조
```

특히 아래는 반드시 피한다.

```text
연속 공격 중 매 타격마다 등 뒤로 복귀하는 연출
```

이 방식은 공격속도가 높아질수록 무기가 과도하게 흔들리고, 화면이 산만해진다.

---

## 13. 테스트 체크리스트

### 13-1. Idle

- 장착 무기가 캐릭터 등 뒤/상단에 표시된다.
- Idle 상태에서 무기가 위아래로 부드럽게 움직인다.
- Idle 상태의 무기는 캐릭터보다 뒤에 보인다.
- 캐릭터 이동 중 무기가 자연스럽게 따라온다.

### 13-2. 첫 공격

- 첫 공격 입력 시 무기가 머리 위 전투 위치로 이동한다.
- 이동이 순간이동처럼 보이지 않는다.
- 이동 후 공격 모션이 실행된다.
- 실제 공격 판정은 기존처럼 정상 작동한다.

### 13-3. 연속 공격

- 공격을 계속하면 무기가 등 뒤로 돌아가지 않는다.
- 무기는 머리 위에 머문 상태로 공격 모션만 반복한다.
- 공격속도가 빠른 무기에서도 visual이 과도하게 왕복하지 않는다.

### 13-4. 복귀

- 마지막 공격 후 일정 시간 동안 무기가 머리 위에 머문다.
- `WEAPON_RETURN_DELAY`가 지나면 무기가 등 뒤로 복귀한다.
- 복귀 후 다시 Idle bobbing을 수행한다.

### 13-5. 스타일별 모션

- 단검/stab은 빠르게 찌르는 느낌이다.
- 소드/slash는 짧게 베는 느낌이다.
- 랜스/pierce는 길게 찌르는 느낌이다.
- 도끼/smash는 묵직하게 찍는 느낌이다.
- 대검/cleave는 크게 베는 느낌이다.
- 원거리 무기는 발사 반동이 있다.
- 레이저는 과한 반동 없이 발사 느낌이 난다.

### 13-6. 에셋 방향

- 오른쪽 방향으로 제작된 무기 에셋이 공격 방향에 맞춰 회전한다.
- 공격 방향이 왼쪽/위/아래여도 무기 방향이 크게 어색하지 않다.
- 에셋 회전으로 인한 픽셀 깨짐이 심하면 후속 작업으로 4방향 프레임화를 검토한다.

---

## 14. Codex 작업용 프롬프트

```text
Burial Protocol의 장착 무기 visual 표시 방식을 개편한다.

배경:
캐릭터 레퍼런스에는 팔이 없다.
따라서 무기를 손에 쥐는 방식은 사용하지 않는다.
무기는 캐릭터가 제어하는 부유 외장 무기로 표현한다.

목표:
1. 장착된 무기는 평상시 캐릭터 등 뒤/상단에 부유한다.
2. Idle 상태에서는 무기가 위아래로 부드럽게 움직인다.
3. 공격 입력 시 무기는 캐릭터 머리 위 전투 위치로 이동한다.
4. 공격 중에는 머리 위 전투 위치를 유지한다.
5. 연속 공격 시 매 타격마다 등 뒤로 복귀하지 않는다.
6. 공격이 발생할 때마다 weapon_return_delay 타이머를 갱신한다.
7. weapon_return_delay가 남아있는 동안 무기는 머리 위 READY 상태를 유지한다.
8. 일정 시간 동안 추가 공격이 없으면 무기는 등 뒤 Idle 위치로 복귀한다.
9. 근거리 무기는 머리 위에서 slash/stab/pierce/smash/cleave 모션을 실행한다.
10. 원거리 무기는 머리 위에서 발사 반동 모션을 실행한다.
11. 무기 에셋은 모두 오른쪽 공격 방향 기준으로 제작되어 있다고 가정한다.
12. 실제 공격 판정은 무기 이미지 애니메이션과 분리한다.

상태 머신:
- IDLE_BACK
- MOVING_TO_READY
- READY_OVERHEAD
- ATTACKING
- RETURNING_TO_BACK

권장 상수:
- WEAPON_BACK_OFFSET = Vector2(0, -26)
- WEAPON_READY_OFFSET = Vector2(0, -42)
- WEAPON_IDLE_BOB_AMPLITUDE = 3.0
- WEAPON_IDLE_BOB_SPEED = 2.4
- WEAPON_MOVE_TO_READY_DURATION = 0.12
- WEAPON_RETURN_TO_BACK_DURATION = 0.16
- WEAPON_RETURN_DELAY = 0.45

주의:
- 무기를 캐릭터 손에 쥔 것처럼 표현하지 않는다.
- 임시 팔을 추가하지 않는다.
- 공격마다 등 뒤와 머리 위를 반복 왕복하지 않는다.
- 기존 attack_module visual의 공전 방식은 weapon visual 1개 표시 방식으로 대체한다.
- 무기 visual은 실제 공격 판정에 영향을 주지 않는다.
- 공격 판정은 기존 weapon/attack logic을 유지한다.

구현 후 테스트:
- Idle 상태에서 무기가 등 뒤에 부유한다.
- 첫 공격 시 무기가 머리 위로 이동한다.
- 연속 공격 중 무기가 머리 위에 머문다.
- 공격이 끊긴 뒤 일정 시간 후 등 뒤로 복귀한다.
- 근거리 무기별 공격 스타일 모션이 구분된다.
- 원거리 무기는 반동 모션이 보인다.
- 실제 데미지/히트박스/투사체/레이저 판정은 기존처럼 정상 작동한다.
```

---

## 15. 최종 판단

이 방식은 팔 없는 캐릭터 구조에 가장 잘 맞는다.

장점:

```text
1. 팔 없는 캐릭터와 시각적으로 자연스럽다.
2. 무기를 손에 쥐는 어색함이 없다.
3. 장착 무기 정체성이 명확히 보인다.
4. 공격속도가 빨라도 visual이 과도하게 흔들리지 않는다.
5. 기존 공격 판정과 시각 연출을 분리할 수 있다.
6. 무기 1개 장착 시스템과 잘 맞는다.
```

최종 표현:

```text
팔 없는 소형 로봇
+ 등 뒤에 부유하는 외장 무기
+ 공격 시 머리 위에서 자동 전개되는 무기
= Burial Protocol에 맞는 장착 무기 visual 시스템
```
