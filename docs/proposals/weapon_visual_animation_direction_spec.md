# Weapon Visual / Animation Direction Specification

기준일: `2026-05-27`
상태: 설계 변경안

이 문서는 팔이 없는 캐릭터 구조에서 weapon visual을 표시하고, weapon idle pose와 공격 animation preset을 통일된 기준으로 처리하기 위한 지시문이다.

핵심 방향:

```text
모든 weapon 에셋은 우측 방향 원본 1종만 제작한다.
게임 안에서는 animation_type + facing + pivot + pose preset으로 표시 방향과 움직임을 처리한다.
weapon visual과 실제 공격 판정은 분리한다.
```

---

## 1. 기본 전제

1. `weapon`은 크게 2가지로 분류된다.

   - `melee`: 근거리 무기
   - `ranged`: 원거리 무기

2. 모든 weapon 관련 에셋 이미지는 기본적으로 **우측을 향해 가로로 그려진다.**

3. 근거리 무기의 검끝 / 창끝 / 날 끝은 우측을 향한다.

4. 원거리 무기의 총구는 우측을 향한다.

5. 근거리 무기의 손잡이는 좌측을 향한다.

6. 원거리 무기의 개머리판 / 그립은 좌측을 향한다.

7. 이 문서에서는 근거리 무기의 검끝 / 창끝 / 날 끝, 원거리 무기의 총구가 향하는 방향을 `공격방향`이라고 부른다.

8. 즉, 모든 weapon 원본 에셋의 기본 `공격방향`은 우측, 즉 3시 방향이다.

```text
원본 weapon 에셋 기준:

[손잡이 / 그립 / 개머리판] -----> [검끝 / 창끝 / 총구]
              좌측                         우측

공격방향 = 3시 방향
```

---

## 2. weapon animation_type

모든 weapon은 `animation_type`을 가진다.

초기 `animation_type`은 아래를 기준으로 한다.

| animation_type | 의미 |
|---|---|
| `one_hand_gun` | 한손 원거리 무기류 |
| `two_hand_gun` | 양손 원거리 무기류 |
| `swing` | 휘두르는 근거리 무기류 |
| `stab` | 찌르는 근거리 무기류 |

주의:

- `stap`이 아니라 `stab`으로 표기한다.
- `animation_type`은 weapon의 idle pose와 attack animation preset을 결정하는 기준값이다.
- 같은 weapon 이미지를 사용하더라도 `animation_type`이 다르면 배치와 공격 애니메이션이 달라질 수 있다.
- `animation_type`은 문자열 오타를 방지하기 위해 enum 또는 상수로 관리한다.

---

## 3. 좌표 / 방향 기준

1. 캐릭터의 기준점은 캐릭터 하단 중앙을 기준으로 한다.

```text
character_origin = 캐릭터 바닥 중앙
```

2. `bottom:0.5U`는 캐릭터 바닥 기준 위로 `0.5U` 높이를 의미한다.

3. `right:-0.25U`는 캐릭터의 우측 방향 기준으로, 캐릭터 중심에 약간 가까운 위치를 의미한다.

4. `left:-0.25U`는 캐릭터의 좌측 방향 기준으로, 캐릭터 중심에 약간 가까운 위치를 의미한다.

5. 방향 표현은 아래 기준을 따른다.

| 표현 | 의미 |
|---|---|
| 3시 방향 | 우측 |
| 2시 방향 | 우측 상단 |
| 10시 방향 | 좌측 상단 |
| 9시 방향 | 좌측 |

6. 구현 시에는 2시, 3시, 9시, 10시 방향을 실제 회전 각도로 변환해도 된다.

권장 각도 기준:

| 방향 | 권장 각도 |
|---|---:|
| 3시 | `0도` |
| 2시 | `-45도` |
| 10시 | `-135도` |
| 9시 | `180도` |

단, Godot의 실제 회전 방향 기준과 Sprite flip 처리 방식에 따라 내부 각도는 보정될 수 있다.  
중요한 것은 최종 화면에서 weapon의 `공격방향`이 의도한 방향을 향해야 한다는 점이다.

---

## 4. weapon flip / rotation 원칙

1. weapon 원본 에셋은 항상 우측을 향한 상태로 제작한다.

2. 캐릭터가 우측을 볼 때는 원본 에셋 방향을 기준으로 배치한다.

3. 캐릭터가 좌측을 볼 때는 좌우 반전 또는 회전 보정을 사용해 weapon의 `공격방향`이 좌측 기준 방향을 향하도록 한다.

4. 좌측 방향 weapon을 위해 별도 좌측용 이미지를 만들지 않는다.

5. 좌측 표시 기준은 아래와 같다.

```text
우측 facing:
- 원본 에셋 사용
- 공격방향이 우측 계열 방향을 향함

좌측 facing:
- 원본 에셋을 좌우 반전하거나 회전 보정
- 공격방향이 좌측 계열 방향을 향함
```

---

## 5. idle 상태 weapon 배치 기준

idle 상태에서 weapon은 캐릭터의 팔에 붙어 있는 것이 아니라, 캐릭터 주변에 떠 있는 장비처럼 표시한다.

### 5-1. swing / stab 근거리 무기

`animation_type`이 `swing` 또는 `stab`인 weapon은 근거리 무기로 취급한다.

#### 캐릭터가 우측을 보고 있을 때

- 캐릭터 바닥 기준 `bottom:0.5U` 높이에 배치한다.
- x축은 `right:-0.25U` 위치에 배치한다.
- weapon의 `공격방향`이 2시 방향을 향하도록 그린다.
- 즉, 검끝 / 창끝 / 날 끝이 우측 상단을 향해야 한다.

```text
facing = right
animation_type = swing / stab

position:
- y = bottom + 0.5U
- x = right - 0.25U

attack_direction:
- 2시 방향
```

#### 캐릭터가 좌측을 보고 있을 때

- 캐릭터 바닥 기준 `bottom:0.5U` 높이에 배치한다.
- x축은 `left:-0.25U` 위치에 배치한다.
- weapon의 `공격방향`이 10시 방향을 향하도록 그린다.
- 즉, 검끝 / 창끝 / 날 끝이 좌측 상단을 향해야 한다.

```text
facing = left
animation_type = swing / stab

position:
- y = bottom + 0.5U
- x = left - 0.25U

attack_direction:
- 10시 방향
```

---

### 5-2. one_hand_gun 원거리 무기

`animation_type`이 `one_hand_gun`인 weapon은 한손 원거리 무기로 취급한다.

#### 캐릭터가 우측을 보고 있을 때

- 캐릭터 바닥 기준 `bottom:0.5U` 높이에 배치한다.
- x축은 `right:-0.25U` 위치에 배치한다.
- weapon의 `공격방향`이 3시 방향을 향하도록 그린다.
- 즉, 총구가 우측을 향해야 한다.

```text
facing = right
animation_type = one_hand_gun

position:
- y = bottom + 0.5U
- x = right - 0.25U

attack_direction:
- 3시 방향
```

#### 캐릭터가 좌측을 보고 있을 때

- 캐릭터 바닥 기준 `bottom:0.5U` 높이에 배치한다.
- x축은 `left:-0.25U` 위치에 배치한다.
- weapon의 `공격방향`이 9시 방향을 향하도록 그린다.
- 즉, 총구가 좌측을 향해야 한다.

```text
facing = left
animation_type = one_hand_gun

position:
- y = bottom + 0.5U
- x = left - 0.25U

attack_direction:
- 9시 방향
```

---

### 5-3. two_hand_gun 원거리 무기

`animation_type`이 `two_hand_gun`인 weapon은 양손 원거리 무기로 취급한다.

양손 총기류는 한손 총기류보다 길이가 길고 무게감이 있어야 하므로, 캐릭터 몸에서 너무 멀리 떨어지지 않도록 배치한다.

#### 캐릭터가 우측을 보고 있을 때

- 캐릭터 바닥 기준 `bottom:0.55U` 높이에 배치한다.
- x축은 `right:-0.10U` 위치에 배치한다.
- weapon의 `공격방향`이 3시 방향을 향하도록 그린다.
- 즉, 총구가 우측을 향해야 한다.
- 한손 총보다 캐릭터 몸 중심에 더 걸친 느낌으로 배치한다.

```text
facing = right
animation_type = two_hand_gun

position:
- y = bottom + 0.55U
- x = right - 0.10U

attack_direction:
- 3시 방향
```

#### 캐릭터가 좌측을 보고 있을 때

- 캐릭터 바닥 기준 `bottom:0.55U` 높이에 배치한다.
- x축은 `left:-0.10U` 위치에 배치한다.
- weapon의 `공격방향`이 9시 방향을 향하도록 그린다.
- 즉, 총구가 좌측을 향해야 한다.
- 한손 총보다 캐릭터 몸 중심에 더 걸친 느낌으로 배치한다.

```text
facing = left
animation_type = two_hand_gun

position:
- y = bottom + 0.55U
- x = left - 0.10U

attack_direction:
- 9시 방향
```

---

## 6. idle pose 요약표

| animation_type | facing | 위치 높이 | x 위치 | 공격방향 |
|---|---|---:|---:|---|
| `swing` | right | bottom + 0.5U | right - 0.25U | 2시 |
| `swing` | left | bottom + 0.5U | left - 0.25U | 10시 |
| `stab` | right | bottom + 0.5U | right - 0.25U | 2시 |
| `stab` | left | bottom + 0.5U | left - 0.25U | 10시 |
| `one_hand_gun` | right | bottom + 0.5U | right - 0.25U | 3시 |
| `one_hand_gun` | left | bottom + 0.5U | left - 0.25U | 9시 |
| `two_hand_gun` | right | bottom + 0.55U | right - 0.10U | 3시 |
| `two_hand_gun` | left | bottom + 0.55U | left - 0.10U | 9시 |

---

## 7. attack animation 기본 원칙

1. weapon 공격 애니메이션은 캐릭터 본체 애니메이션과 분리한다.

2. 캐릭터는 팔이 없으므로, 공격 시 캐릭터 몸 전체가 무기를 휘두르는 것이 아니라 weapon visual node가 독립적으로 움직인다.

3. 캐릭터 본체는 공격 시 약한 반동, squash, tilt, recoil 정도만 적용할 수 있다.

4. 실제 공격 판정은 weapon 이미지와 분리한다.

```text
weapon visual = 보여지는 무기 움직임
attack hitbox = 실제 공격 판정
```

5. weapon 이미지가 적중한 것처럼 보여도 실제 데미지는 기존 공격모듈 판정 또는 별도 공격 shape query를 통해 처리한다.

6. attack animation은 `animation_type`에 따라 다른 preset을 사용한다.

---

## 8. animation_type별 공격 애니메이션 방향

### 8-1. swing

`swing`은 검, 대검, 도끼처럼 휘두르는 근거리 무기류에 사용한다.

기본 공격은 한 방향으로만 반복하지 않는다.

권장 공격 variant:

```text
swing_ltr = 좌측에서 우측으로 베기
swing_rtl = 우측에서 좌측으로 베기
swing_down = 위에서 아래로 내려찍기
```

기본 콤보 예시:

```text
1타: swing_ltr
2타: swing_rtl
3타: swing_down
반복
```

애니메이션 구성:

```text
준비 자세
→ 빠른 베기
→ 타격 순간 짧은 멈칫
→ 후딜 / 복귀
```

의도:

- 대검이나 도끼가 한 방향으로만 어색하게 휘둘리지 않도록 한다.
- 좌→우, 우→좌, 내려찍기를 섞어 실제로 베는 느낌을 만든다.

---

### 8-2. stab

`stab`은 창, 단검, 레이피어처럼 찌르는 근거리 무기류에 사용한다.

권장 공격 variant:

```text
stab_forward = 전방 찌르기
stab_high = 약간 위쪽 찌르기
stab_low = 약간 아래쪽 찌르기
```

애니메이션 구성:

```text
뒤로 살짝 당김
→ 공격방향으로 빠르게 전진
→ 짧은 타격 정지
→ 원위치 복귀
```

의도:

- 무기를 크게 회전시키지 않는다.
- 공격방향으로 빠르게 뻗었다가 돌아오는 느낌을 준다.
- 찌르기 무기는 타격 궤적보다 전진/후퇴 움직임이 중요하다.

---

### 8-3. one_hand_gun

`one_hand_gun`은 권총, 리볼버, 소형 에너지건 같은 한손 원거리 무기에 사용한다.

권장 공격 variant:

```text
one_hand_shot = 기본 사격
one_hand_recoil_high = 위로 튀는 반동
one_hand_recoil_back = 뒤로 밀리는 반동
```

애니메이션 구성:

```text
조준 자세
→ 사격 순간 muzzle flash
→ 짧은 후방/상방 반동
→ 원위치 복귀
```

의도:

- 총구 방향이 공격방향과 일치해야 한다.
- 사격 시 weapon 전체가 뒤로 살짝 밀리고 위로 튀는 느낌을 준다.
- 총구에는 muzzle flash 또는 발광 이펙트를 붙일 수 있다.

---

### 8-4. two_hand_gun

`two_hand_gun`은 소총, 샷건, 레이저 라이플 같은 양손 원거리 무기에 사용한다.

권장 공격 variant:

```text
two_hand_shot = 기본 사격
two_hand_heavy_recoil = 강한 후방 반동
two_hand_charge_shot = 충전 후 사격
```

애니메이션 구성:

```text
조준 자세
→ 사격 순간 muzzle flash
→ weapon 전체가 뒤로 강하게 밀림
→ 캐릭터도 아주 약하게 반동
→ 원위치 복귀
```

의도:

- 한손 총보다 무겁고 안정적인 느낌을 준다.
- 위치는 캐릭터 몸 중심에 더 걸친다.
- 반동은 크되 weapon이 캐릭터와 완전히 분리되어 보이면 안 된다.

---

## 9. weapon pivot 기준

weapon visual node는 공격 애니메이션을 위해 pivot 기준을 가져야 한다.

권장 기준:

1. 근거리 무기

   - pivot은 손잡이 쪽에 둔다.
   - `swing`은 pivot을 기준으로 회전한다.
   - `stab`은 pivot을 기준으로 앞뒤 이동한다.

2. 원거리 무기

   - pivot은 그립 또는 개머리판 근처에 둔다.
   - `one_hand_gun`은 그립 근처를 기준으로 반동한다.
   - `two_hand_gun`은 그립과 개머리판 사이 중심 쪽을 기준으로 반동한다.

주의:

- weapon sprite의 중앙점을 그대로 pivot으로 쓰면 휘두르는 느낌이 어색할 수 있다.
- 특히 대검 / 창 / 소총처럼 긴 weapon은 pivot 기준을 반드시 보정해야 한다.

---

## 10. 구현 구조 권장안

weapon visual은 캐릭터의 일부가 아니라 별도 노드로 관리한다.

권장 구조:

```text
Player
 └─ WeaponVisualRoot
     └─ WeaponVisual
         ├─ WeaponPivot
         │   └─ WeaponSprite
         ├─ TrailVisual
         └─ EffectSpawnPoint
```

역할:

| 노드 | 역할 |
|---|---|
| `WeaponVisualRoot` | 캐릭터 기준 weapon visual 위치 관리 |
| `WeaponVisual` | 현재 weapon의 pose / animation 상태 관리 |
| `WeaponPivot` | 회전 / 반동 / 찌르기 기준점 |
| `WeaponSprite` | 실제 weapon 이미지 |
| `TrailVisual` | 베기 궤적, 잔상, slash trail |
| `EffectSpawnPoint` | 총구화염, 파편, 타격 이펙트 기준점 |

---

## 11. 구현 주의사항

1. 좌측 facing용 weapon 이미지를 별도로 만들지 않는다.

2. 모든 weapon 이미지는 우측을 향한 원본 1종만 사용한다.

3. 좌측 facing은 flip 또는 rotation 보정으로 처리한다.

4. `animation_type`은 문자열 오타를 방지하기 위해 enum 또는 상수로 관리한다.

5. `stab`을 `stap`으로 쓰지 않는다.

6. weapon visual과 실제 공격 판정은 분리한다.

7. weapon visual이 아무리 크게 움직여도 실제 판정은 공격 시스템에서 정의한 범위를 따른다.

8. 근거리 weapon은 idle 상태에서 살짝 위를 향하게 배치해 장비처럼 보이게 한다.

9. 원거리 weapon은 idle 상태에서 공격방향이 수평을 향하게 배치해 조준 장비처럼 보이게 한다.

10. `two_hand_gun`은 `one_hand_gun`보다 캐릭터 몸 중심에 더 가깝게 배치한다.

11. 대검 / 소총처럼 긴 weapon은 pivot 보정 없이는 어색하므로 반드시 pivot offset을 지원한다.

12. 기존 공격 판정, 데미지 계산, 공격모듈 장착 / 합성 로직은 이 문서의 visual 작업과 분리한다.

13. 이 문서의 내용을 구현할 때는 한 번에 전체 attack animation까지 구현하지 말고, 우선 idle pose 정렬과 weapon visual 구조부터 구현하는 것을 권장한다.
