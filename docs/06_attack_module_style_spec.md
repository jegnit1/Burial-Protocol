# Burial Protocol - Attack Module Style / Weapon VO Specification

기준일: `2026-06-02`  
기준 브랜치: `main`

---

## 0. 목적

이 문서는 공격모듈/무기 데이터의 세부 동작 VO(Value Object)와 스타일 분류를 정의한다.

기존 문서가 `module_type`, `attack_style`, `effect_style` 중심으로 근거리/원거리 스타일을 설명했다면, 이 문서는 Google Spreadsheet의 `Weapon Catalog` 초안에서 관리할 무기 동작 모델까지 포함한다.

핵심 목적:

- 유저가 보는 무기 유형과 실제 구현 판정 방식을 분리한다.
- 화염방사기, 지속 레이저처럼 누르고 있는 동안 유지되는 무기를 표현할 수 있게 한다.
- `base_cooldown` 하나로 발사 간격과 지속 피해 tick 간격을 모두 표현한다.
- 공격 판정과 시각 이펙트를 분리해서, 향후 에셋/VFX 교체가 판정 밸런스를 바꾸지 않게 한다.
- 특정 `module_id` 또는 `weapon_id`별 하드코딩을 피하고 데이터 기반 resolver로 처리한다.

---

## 1. 용어 층 구분

공격모듈/무기 데이터는 아래 층을 분리해서 본다.

```text
module_type      = 장착/입력/성장 시스템상의 큰 구현 축
attribute        = 피해/연출 속성
attack_type      = 유저가 보는 무기 유형 / 시너지 태그
activation_mode  = 입력 또는 자동 발동 방식
hit_model        = 실제 피해 판정 방식
effect_style     = 시각 연출 스타일
```

각 값의 역할은 다르다.

| 항목 | 주 사용자 | 의미 |
|---|---|---|
| `module_type` | 코드/시스템 | `melee`, `ranged`, `mechanic` 같은 장착/발동 축 |
| `attribute` | 유저/데이터 | 전기, 화염, 물리, 에너지, 화학 같은 피해/연출 속성 |
| `attack_type` | 유저/빌드 | 투사체, 영역, 직선형, 연쇄, 폭발, 보조 같은 유형/시너지 |
| `activation_mode` | 코드/데이터 | 공격키 입력 또는 자동 발동 방식 |
| `hit_model` | 코드/데이터 | 실제 판정 생성 방식 |
| `effect_style` | 아트/코드 | VFX/이펙트 스타일 |

중요:

```text
attack_type은 구현 세부값이 아니라 유저가 장비 화면에서 확인할 유형이다.
hit_model은 실제 코드가 판정을 생성할 때 쓰는 구현값이다.
```

---

## 2. module_type

`module_type`은 공격모듈의 장착/발동/성장 시스템상 최상위 구현 축이다.

```text
module_type:
- melee
- ranged
- mechanic
```

| module_type | 의미 |
|---|---|
| `melee` | 캐릭터 기준 근거리 shape 공격 |
| `ranged` | 공격 입력 기반 투사체/직선/채널링 공격 |
| `mechanic` | 입력과 독립된 자동 공격/드론/프로토콜 축 |

`module_type`은 유저용 시너지 태그라기보다 코드와 성장 보너스 연결을 위한 축이다.
예를 들어 근거리 공격력 보너스는 `melee`, 원거리 공격력 보너스는 `ranged`에 적용할 수 있다.

---

## 3. attribute

`attribute`는 피해/연출의 성질을 나타낸다.

| attribute | 한글명 | 예시 |
|---|---|---|
| `electric` | 전기 | 스파크, 체인 라이트닝, 테이저 |
| `fire` | 화염 | 화염방사기, 소이탄, 네이팜 |
| `physical` | 물리 | 탄환, 칼날, 톱날, 파편, 충격 |
| `energy` | 에너지 | 레이저, 플라즈마, 이온 빔 |
| `chemical` | 화학 | 산성탄, 독성 구름, 부식 미스트 |

원칙:

- `attribute`는 무기의 피해 감성과 이펙트 소재를 결정한다.
- 동일한 `attack_type`이라도 `attribute`가 다르면 빌드/시너지/이펙트가 달라질 수 있다.
- 예: `fire + area`는 화염방사기, `chemical + area`는 부식 구름, `physical + area`는 톱날 링이 될 수 있다.

---

## 4. attack_type

`attack_type`은 유저가 보는 무기/장비의 유형이다.
롤토체스 기물의 시너지값처럼, 장비 선택과 빌드 판단에 사용될 수 있다.

| attack_type | 한글명 | 의미 | 예시 |
|---|---|---|---|
| `support` | 보조 | 회복, 정리, 보조 프로토콜 | 회복 프로토콜, 청소 프로토콜 |
| `projectile` | 투사체 | 탄체가 이동해서 맞는 공격 | 권총, 샷건, 로켓, 산성탄 |
| `area` | 영역 | 일정 범위에 반복/지속 피해 | 화염방사기, 톱날 링, 독구름 |
| `linear` | 직선형 | 한 방향 직선 판정 | 저격총, 레이저, 레일건, 이온 빔 |
| `chain` | 연쇄 | 대상에서 대상으로 전이 | 체인 라이트닝, 스파크 테이저 |
| `explosion` | 폭발 | 지점 주변 범위 피해 | 유탄, 로켓, 네이팜 폭발 |

### 4-1. `beam` 대신 `linear`를 사용한다

기존 `광선/beam`은 레이저, 이온 빔 같은 에너지 무기만 떠올리게 한다.
저격총, 레일건, 고속 관통탄도 같은 직선 판정 계열에 포함하려면 `linear / 직선형`이 더 적합하다.

```text
기존: beam / 광선
변경: linear / 직선형
```

`linear`의 범위:

- 저격총
- 레이저
- 레일건
- 이온 빔
- 고속 직선 관통 사격
- 히트스캔 또는 채널링 직선 판정

주의:

```text
linear는 피해 속성이 아니다.
physical + linear = 저격총/레일건
energy + linear = 레이저/이온 빔
fire + linear = 열선/화염 레이저
```

### 4-2. 샷건은 area가 아니라 projectile이다

샷건은 넓은 범위를 커버하지만, 유저 관점에서는 장판/영역 공격이 아니라 여러 탄환을 발사하는 무기다.
따라서 기본 분류는 아래가 자연스럽다.

```text
shotgun:
attribute = physical
attack_type = projectile
hit_model = projectile_spread
```

`area`는 화염방사기, 독구름, 톱날 링처럼 공간을 점유하거나 일정 범위 안에 반복 피해를 주는 공격에 사용한다.

---

## 5. activation_mode

`activation_mode`는 입력 또는 자동 발동 방식을 나타낸다.

중요 원칙:

```text
click_once는 사용하지 않는다.
단발형 무기라도 공격키를 누르고 있으면 base_cooldown마다 반복 발사한다.
```

즉, 권총도 클릭 1회에만 1발 나가는 구조가 아니라, 누르고 있으면 `base_cooldown`마다 계속 발사한다.

| activation_mode | 의미 | 예시 |
|---|---|---|
| `hold_repeat` | 공격키를 누르고 있으면 `base_cooldown`마다 공격 인스턴스를 생성 | 권총, 샷건, 로켓, 유탄 |
| `hold_channel` | 공격키를 누르고 있으면 판정이 유지되고 `base_cooldown`마다 피해 | 화염방사기, 지속 레이저 |
| `auto_repeat` | 공격키와 무관하게 `base_cooldown`마다 자동 공격 인스턴스를 생성 | 자동 드론 사격, 포탑 |
| `auto_channel` | 공격키와 무관하게 지속 판정을 유지하고 `base_cooldown`마다 피해 | 톱날 드론, 오라, 자동 영역 프로토콜 |

향후 차지 무기가 필요해지면 `charge_release`를 별도 추가할 수 있다.
현재 기본 VO에는 포함하지 않는다.

---

## 6. hit_model

`hit_model`은 실제 피해 판정 방식이다.

`attack_type`이 유저용 유형이라면, `hit_model`은 코드가 실제 공격을 생성하는 방식이다.

| hit_model | 의미 | 대표 예시 |
|---|---|---|
| `melee_shape` | 캐릭터 기준 근거리 shape 판정 | 소드, 랜스, 액스 |
| `projectile_single` | 단일 투사체 | 권총, 코어 슈터 |
| `projectile_spread` | 확산형 다중 투사체 | 샷건, 크레모아 |
| `projectile_pierce` | 관통 투사체 | 스나이퍼, 레일 드릴 |
| `projectile_explosion` | 착탄 후 폭발하는 투사체 | 로켓, 유탄, 네이팜 런처 |
| `hitscan_line` | 즉시 직선 1회 판정 | 저격총, 즉발 레이저 |
| `channel_line` | 누르고 있는 동안 유지되는 직선 판정 | 지속 레이저, 이온 빔 |
| `channel_cone` | 누르고 있는 동안 유지되는 부채꼴 판정 | 화염방사기 |
| `area_zone` | 특정 위치에 생성되는 지속 영역 | 독구름, 화염지대 |
| `area_orbit` | 플레이어/드론 주변 지속 영역 | 톱날 링, 커터 링 |
| `chain_jump` | 대상 간 전이 | 체인 라이트닝, 스파크 테이저 |

예:

```text
저격총:
attack_type = linear
hit_model = hitscan_line 또는 projectile_pierce

지속 레이저:
attack_type = linear
hit_model = channel_line

화염방사기:
attack_type = area
hit_model = channel_cone
```

---

## 7. base_cooldown

`base_cooldown`은 피해 발생 주기다.

별도의 `tick_interval`은 만들지 않는다.
발사형 무기와 tick형 무기는 동시에 쓰이지 않으므로, `base_cooldown` 하나로 통합한다.

정의:

```text
base_cooldown:
해당 무기가 피해를 발생시키는 기본 주기.
반복 발사형 무기는 발사 간격으로 사용하고,
채널링/영역형 무기는 피해 tick 간격으로 사용한다.
```

예:

| 무기 | activation_mode | hit_model | base_cooldown 의미 |
|---|---|---|---|
| 권총 | `hold_repeat` | `projectile_single` | 다음 탄 발사까지의 간격 |
| 샷건 | `hold_repeat` | `projectile_spread` | 다음 샷 발사까지의 간격 |
| 화염방사기 | `hold_channel` | `channel_cone` | 지속 화염 피해 tick 간격 |
| 지속 레이저 | `hold_channel` | `channel_line` | 레이저 피해 tick 간격 |
| 톱날 링 | `auto_channel` | `area_orbit` | 영역 피해 tick 간격 |

주의:

- `tick_interval` 컬럼은 추가하지 않는다.
- 데이터 설명에서는 `base_cooldown`을 공격 간격과 tick 간격의 공통 의미로 설명한다.

---

## 8. 지속 방식

별도의 `duration_policy`는 만들지 않는다.

지속 방식은 `activation_mode`에 종속된다.

| activation_mode | 종료 조건 |
|---|---|
| `hold_repeat` | 공격키를 떼면 반복 발사 종료 |
| `hold_channel` | 공격키를 떼면 채널링 종료 |
| `auto_repeat` | 장착/조건 유지 중 반복 |
| `auto_channel` | 장착/조건 유지 중 채널링 유지 |

단, `area_duration`은 유지한다.
`area_duration`은 입력 지속 시간이 아니라 생성된 영역 자체의 수명이다.

예:

```text
napalm_launcher:
activation_mode = hold_repeat
hit_model = projectile_explosion
area_duration = 2.0
```

의미:

```text
공격키를 누르고 있으면 base_cooldown마다 네이팜탄을 발사한다.
착탄 시 폭발하고, 착탄 지점에 2초짜리 화염지대를 남긴다.
```

반면 화염방사기는 다음처럼 본다.

```text
flame_thrower:
activation_mode = hold_channel
hit_model = channel_cone
area_duration = 0 또는 blank
```

의미:

```text
공격키를 누르고 있는 동안만 전방 화염 판정이 유지된다.
```

---

## 9. 판정 shape와 VFX 분리

shape는 추후 에셋/VFX가 붙을 것을 고려해서 판정과 시각을 분리한다.

| 컬럼 | 의미 |
|---|---|
| `hit_shape` | 실제 충돌/피해 판정용 추상 shape |
| `effect_style` | 시각 연출 계열 |
| `effect_scene_path` | 실제 Godot 이펙트 씬 경로 |
| `icon_path` | UI 아이콘 |

`hit_shape` 권장 값:

| hit_shape | 사용처 |
|---|---|
| `point` | 단일 탄 충돌 |
| `line` | 레이저, 저격, 레일건 |
| `cone` | 화염방사기 |
| `circle` | 폭발, 구름 |
| `box` | 근거리 베기/타격 |
| `ring` | 톱날 링, 오라 |
| `arc` | 짧은 부채꼴 베기 |

중요:

```text
VFX 이미지 크기나 모양이 판정 밸런스를 직접 결정하면 안 된다.
판정은 hit_shape와 수치 데이터가 소유하고,
시각은 effect_style/effect_scene_path가 소유한다.
```

예:

```text
flame_thrower:
hit_shape = cone
effect_style = flame_stream
effect_scene_path = res://effects/weapons/flame_thrower_vfx.tscn
```

---

## 10. angle / range / radius 필드 원칙

현재 초안에서는 `spread_angle`이 샷건 확산각, 화염방사기 부채꼴 각도, 분열 레이저 각도를 동시에 표현할 수 있다.
장기적으로는 아래 이름이 더 명확하다.

| 기존 | 권장 후보 | 의미 |
|---|---|---|
| `spread_angle` | `angle_degrees` | 확산/부채꼴/분기 각도를 포괄 |
| `range_units` | 유지 | 사거리 |
| `explosion_radius_u` | 유지 | 폭발 반경 |
| `area_duration` | 유지 | 생성된 영역 수명 |

`angle_degrees`는 아래에 모두 사용할 수 있다.

- 샷건 탄 퍼짐 각도
- 화염방사기 cone 각도
- 분열 레이저 줄기 간 각도

---

## 11. 권장 Weapon Catalog VO 컬럼

Weapon Catalog 초안에서 최소로 필요한 핵심 컬럼은 아래와 같다.

```text
weapon_id
name_ko
rank
attribute
attack_type
activation_mode
hit_model
hit_shape
effect_style
base_damage_d
base_damage_c
base_damage_b
base_damage_a
base_damage_s
base_cooldown
projectile_count
angle_degrees
pierce_count
range_units
projectile_speed
explosion_radius_u
chain_count
area_duration
can_hit_block
can_hit_sand
sand_damage_ratio
sand_collision_policy
short_desc
notes
```

기존 `fire_mode`는 장기적으로 아래 두 축으로 분리한다.

```text
activation_mode + hit_model
```

예:

| 기존 fire_mode 성격 | activation_mode | hit_model |
|---|---|---|
| 단일 탄 반복 발사 | `hold_repeat` | `projectile_single` |
| 샷건 반복 발사 | `hold_repeat` | `projectile_spread` |
| 착탄 폭발탄 반복 발사 | `hold_repeat` | `projectile_explosion` |
| 즉발 직선 판정 반복 | `hold_repeat` | `hitscan_line` |
| 지속 레이저 | `hold_channel` | `channel_line` |
| 화염방사기 | `hold_channel` | `channel_cone` |
| 자동 드론 사격 | `auto_repeat` | `projectile_single` |
| 자동 톱날 영역 | `auto_channel` | `area_orbit` |

---

## 12. 대표 무기 VO 예시

### 12-1. 권총

```text
weapon_id = pistol
attribute = physical
attack_type = projectile
activation_mode = hold_repeat
hit_model = projectile_single
hit_shape = point
base_cooldown = 0.3
projectile_count = 1
range_units = 6
projectile_speed = 900
sand_collision_policy = block_on_hit
```

### 12-2. 샷건

```text
weapon_id = shotgun
attribute = physical
attack_type = projectile
activation_mode = hold_repeat
hit_model = projectile_spread
hit_shape = point
base_cooldown = 0.45
projectile_count = 5
angle_degrees = 26
range_units = 4
projectile_speed = 820
sand_collision_policy = block_on_hit
```

### 12-3. 화염방사기

```text
weapon_id = flame_thrower
attribute = fire
attack_type = area
activation_mode = hold_channel
hit_model = channel_cone
hit_shape = cone
base_cooldown = 0.12
range_units = 3
angle_degrees = 35
area_duration = 0
can_hit_block = TRUE
can_hit_sand = TRUE
sand_damage_ratio = 0.1
sand_collision_policy = shape_area
effect_style = flame_stream
```

의미:

```text
공격키를 누르고 있는 동안 전방 3U, 35도 부채꼴 화염 판정이 유지된다.
범위 내 대상은 base_cooldown마다 피해를 받는다.
```

### 12-4. 지속 레이저

```text
weapon_id = laser_module
attribute = energy
attack_type = linear
activation_mode = hold_channel
hit_model = channel_line
hit_shape = line
base_cooldown = 0.08
range_units = 8
pierce_count = 0
can_hit_block = TRUE
can_hit_sand = TRUE
sand_damage_ratio = 0.1
sand_collision_policy = hitscan_first_hit
effect_style = laser_beam
```

의미:

```text
공격키를 누르고 있는 동안 마우스 방향으로 레이저가 유지된다.
레이저 선상 대상은 base_cooldown마다 피해를 받는다.
```

관통 레이저는 아래처럼 표현한다.

```text
pierce_count = 4
sand_collision_policy = hitscan_pierce_by_count
```

### 12-5. 저격총

```text
weapon_id = sniper
attribute = physical
attack_type = linear
activation_mode = hold_repeat
hit_model = hitscan_line
hit_shape = line
base_cooldown = 0.8
range_units = 12
pierce_count = 1
sand_collision_policy = hitscan_pierce_by_count
effect_style = sniper_tracer
```

### 12-6. 네이팜 런처

```text
weapon_id = napalm_launcher
attribute = fire
attack_type = explosion
activation_mode = hold_repeat
hit_model = projectile_explosion
hit_shape = circle
base_cooldown = 1.1
range_units = 8
projectile_speed = 720
explosion_radius_u = 1.6
area_duration = 2.0
sand_collision_policy = explode_on_hit
effect_style = napalm_burst
```

---

## 13. 기존 attack_style과의 관계

기존 `attack_style`은 현재 공격모듈 구현에서 스타일 resolver가 사용하는 값이다.
Weapon Catalog VO가 도입되면 `attack_style`은 아래 중 하나로 정리한다.

1. `hit_model`과 `effect_style`로 흡수한다.
2. 기존 구현 호환용 legacy/style alias로 유지한다.

권장 방향:

```text
기획/스프레드시트 원본:
attribute + attack_type + activation_mode + hit_model + hit_shape + effect_style

런타임 resolver:
위 값을 읽어 기존 AttackModuleStyleResolver 또는 신규 WeaponBehaviorResolver가 판정 옵션을 구성
```

기존 값 대응 예:

| 기존 attack_style | 신규 VO 대응 |
|---|---|
| `shotgun` | `attack_type=projectile`, `hit_model=projectile_spread` |
| `sniper` | `attack_type=linear`, `hit_model=hitscan_line` 또는 `projectile_pierce` |
| `laser` | `attack_type=linear`, `hit_model=channel_line` 또는 `hitscan_line` |
| `pierce` | `hit_model=melee_shape`, `hit_shape=box/line` |
| `cleave` | `hit_model=melee_shape`, `hit_shape=arc/box` |

---

## 14. 구현 시 주의사항

- `attack_type`에 `hitscan`, `channel_cone`, `projectile_pierce` 같은 구현값을 넣지 않는다.
- `fire_mode` 하나로 모든 동작을 표현하지 않는다. 장기적으로 `activation_mode + hit_model`로 분리한다.
- `click_once`는 추가하지 않는다. 단발 무기도 hold 상태에서 반복 발사한다.
- `tick_interval`은 추가하지 않는다. `base_cooldown`이 발사 간격과 tick 간격을 모두 담당한다.
- `duration_policy`는 추가하지 않는다. 지속 방식은 `activation_mode`로 표현한다.
- `area_duration`은 유지한다. 이는 생성된 영역의 수명이지 입력 지속 방식이 아니다.
- VFX 크기와 실제 판정 크기를 직접 묶지 않는다.
- `effect_style`과 `effect_scene_path`는 판정이 아니라 시각 연출만 담당한다.
- 새 무기 추가 시 `weapon_id`별 하드코딩 대신 VO 조합을 해석하는 resolver를 확장한다.

---

## 15. 결론

최종 원칙은 아래와 같다.

```text
attribute는 피해/연출 속성이다.
attack_type은 유저가 이해하는 유형/시너지 값이다.
activation_mode는 입력/자동 발동 방식이다.
hit_model은 코드가 실행하는 실제 판정 방식이다.
base_cooldown은 피해 발생 주기다.
effect_style은 시각 이펙트 계열이다.
```

대표 매핑:

```text
권총       = physical / projectile / hold_repeat  / projectile_single
샷건       = physical / projectile / hold_repeat  / projectile_spread
저격총     = physical / linear     / hold_repeat  / hitscan_line
화염방사기 = fire     / area       / hold_channel / channel_cone
지속 레이저 = energy   / linear     / hold_channel / channel_line
네이팜     = fire     / explosion  / hold_repeat  / projectile_explosion
톱날 링    = physical / area       / auto_channel / area_orbit
```

이 구조를 기준으로 하면 화염방사기와 지속 레이저처럼 기존 `fire_mode`만으로 표현하기 어려웠던 무기를 데이터 기반으로 정의할 수 있다.
