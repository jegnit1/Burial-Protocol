# Burial Protocol - Attack Module Style Specification

기준일: `2026-04-24`  
기준 브랜치: `main`

---

## 0. 목적

이 문서는 공격모듈의 `module_type` 아래에 붙는 세부 공격 방식과 연출 방식을 정의한다.

공격모듈의 최상위 타입은 아래 3개다.

- `melee`
- `ranged`
- `mechanic`

이 문서는 그중 `melee`와 `ranged`의 하위 공격 스타일을 먼저 정의한다.

핵심 목적:

- 같은 `melee`라도 slash, stab, pierce, cleave, smash를 다르게 처리한다.
- 같은 `ranged`라도 shotgun, sniper, laser, rifle, revolver를 다르게 처리한다.
- 판정 데이터와 시각 이펙트를 분리한다.
- 특정 모듈 ID별 하드코딩을 피하고, `attack_style`과 `effect_style` 기반으로 처리한다.

---

## 1. 기본 원칙

### 1-1. module_type과 attack_style 분리

`module_type`은 공격모듈의 최상위 타입이다.

```text
module_type:
- melee
- ranged
- mechanic
```

`attack_style`은 최상위 타입 내부의 세부 공격 방식이다.

```text
melee attack_style:
- slash
- stab
- pierce
- cleave
- smash

ranged attack_style:
- shotgun
- sniper
- laser
- rifle
- revolver
```

즉, `melee`라는 값만으로 판정과 연출을 결정하지 않는다.

예:

```text
sword_module      -> module_type: melee,  attack_style: slash
lance_module      -> module_type: melee,  attack_style: pierce
greatsword_module -> module_type: melee,  attack_style: cleave
shotgun_module    -> module_type: ranged, attack_style: shotgun
laser_module      -> module_type: ranged, attack_style: laser
```

### 1-2. 판정과 이펙트 분리

공격 판정과 시각 이펙트는 분리한다.

- 판정은 `hit_shape`, `base_shape_units`, `projectile_options`, `hitscan_options` 같은 데이터로 처리한다.
- 이펙트는 `effect_style` 또는 `effect_scene_path`로 처리한다.
- 이펙트가 데미지 판정을 직접 소유하지 않는다.

금지 방향:

```text
if module_id == "lance_module":
    ...
```

권장 방향:

```text
if attack_style == "pierce":
    ...
```

더 좋은 방향:

```text
attack_style 데이터를 읽고 공통 AttackStyleResolver가 판정/이펙트를 구성한다.
```

### 1-3. 판정 기준점

공격모듈은 시각적으로 플레이어 주변을 공전하더라도 실제 공격 판정 기준점은 캐릭터 위치다.

- 근거리 판정 시작점: 캐릭터 위치 기준
- 원거리 발사 시작점: 캐릭터 위치 기준
- 공격 방향: 마우스 방향 또는 현재 facing 방향
- 모듈 공전 위치는 시각 표현 전용

---

## 2. 공통 데이터 필드

공격모듈 데이터는 최소 아래 계층을 가진다.

```text
module_id
module_type
attack_style
effect_style
rank
module_base_damage
damage_multiplier
attack_speed_multiplier
range_multiplier
base_shape_units
range_growth_width_scale
range_growth_height_scale
projectile_options
hitscan_options
mechanic_options
```

`module_base_damage` is the primary damage field.
For attack modules, `rank` is also the equipped module `grade`.
Purchasing or auto-granting an attack module equips it at its data `rank`.
Rank/grade is not multiplied in the final damage formula.
Rank/grade only selects or derives the fixed module base damage for that grade.
`damage_multiplier` is kept as legacy data and as a fallback source when `module_base_damage` is missing.
Fallback conversion:

```text
D-grade module_base_damage = round(10 x damage_multiplier)
grade module_base_damage = round(D-grade module_base_damage x legacy grade damage factor)
```

Final damage uses grade module base damage, type-specific flat attack bonuses, and global damage percent.
The only final damage multiplier is `global_damage_multiplier = 1 + damage_percent`.
`damage_multiplier` is not multiplied in the final damage formula when `module_base_damage` is available.

### 2-1. melee용 주요 필드

```text
module_type = melee
attack_style
effect_style
base_shape_units
range_growth_width_scale
range_growth_height_scale
hit_shape
```

### 2-2. ranged용 주요 필드

```text
module_type = ranged
attack_style
effect_style
range_units
range_growth_scale
projectile_count
spread_angle
projectile_speed
pierce_count
is_hitscan
projectile_visual_size
```

원거리에서 공격범위 증가는 기본적으로 projectile 크기가 아니라 사거리 증가로 해석한다.

```text
range_growth_scale = 1.0
projectile_size_growth_scale = 0.0
```

---

## 3. Melee Attack Styles

근거리 공격은 좌클릭 입력 기반으로 발동한다.
대부분 캐릭터 기준 히트스캔 또는 즉발 shape query로 처리한다.

### 3-1. slash

일반적인 베기 공격이다.

용도:

- 소드 계열
- 기본 근접 무기

기본 판정:

```text
base_shape_units = 1.0U x 1.0U
```

연출:

```text
effect_style = slash_arc
짧은 베기 호
```

공격범위 증가 적용:

```text
width  = range_bonus x 1.0
height = range_bonus x 0.1
```

의미:

- 공격범위가 증가하면 전방 범위는 확실히 늘어난다.
- 세로 범위는 약간만 늘어난다.
- 범위 증가가 과도한 상하 판정 확대로 이어지지 않게 한다.

---

### 3-2. stab

빠른 짧은 찌르기 공격이다.

용도:

- 단검 계열
- 빠른 근접 무기

기본 판정:

```text
base_shape_units = 0.5U x 0.5U
```

연출:

```text
effect_style = short_stab
빠른 짧은 찌르기 플래시
```

공격범위 증가 적용:

```text
width  = range_bonus x 1.0
height = range_bonus x 0.0
```

의미:

- 공격범위 증가는 찌르는 거리만 늘린다.
- 찌르기 두께는 증가하지 않는다.
- 빠르고 좁은 고정밀 근접 무기 느낌을 유지한다.

---

### 3-3. pierce

긴 직선 찌르기 공격이다.

용도:

- 랜스 계열
- 긴 리치의 근접 무기

기본 판정:

```text
base_shape_units = 2.5U x 0.5U
```

연출:

```text
effect_style = long_pierce
긴 직선 찌르기 이펙트
```

공격범위 증가 적용:

```text
width  = range_bonus x 1.0
height = range_bonus x 0.0
```

의미:

- 공격범위 증가는 전방 찌르기 길이만 늘린다.
- 세로 두께는 증가하지 않는다.
- 랜스가 공격범위 증가로 넓은 면적 무기처럼 변하지 않게 한다.

---

### 3-4. cleave

큰 베기 궤적 공격이다.

용도:

- 대검 계열
- 느리지만 넓고 강한 근접 무기

기본 판정:

```text
base_shape_units = 1.5U x 1.0U
```

연출:

```text
effect_style = big_cleave
큰 베기 궤적
```

공격범위 증가 적용:

```text
width  = range_bonus x 1.0
height = range_bonus x 0.2
```

의미:

- 공격범위 증가 시 전방 범위가 크게 늘어난다.
- 세로 범위도 어느 정도 증가한다.
- 대검/대형 베기 무기의 넓은 궤적감을 유지한다.

---

### 3-5. smash

둔탁한 타격 공격이다.

용도:

- 해머/둔기 계열
- 충격형 근접 무기

기본 판정:

```text
base_shape_units = 1.0U x 1.0U
```

연출:

```text
effect_style = blunt_smash
짧고 둔탁한 충격 이펙트
```

공격범위 증가 적용:

```text
width  = range_bonus x 1.0
height = range_bonus x 0.1
```

의미:

- slash와 유사한 크기 확장 규칙을 쓴다.
- slash가 날카로운 베기라면 smash는 둔탁한 충격감 중심이다.
- 향후 화면 흔들림, 짧은 충격파, 파편 이펙트와 연결할 수 있다.

---

## 4. Ranged Attack Styles

원거리 공격은 좌클릭 입력 기반으로 발동한다.
대부분 투사체 방식이며, 일부는 히트스캔으로 처리한다.

공통 원칙:

- 모든 원거리 무기는 공격범위 증가 시 기본적으로 사거리만 증가한다.
- projectile의 폭/높이는 공격범위 스탯으로 증가하지 않는다.
- 원거리 무기의 projectile 크기 확대가 필요하면 별도 옵션이나 별도 아이템 효과로 처리한다.

---

### 4-1. shotgun

산탄형 원거리 공격이다.

기본 동작:

```text
projectile_count = 3
spread_angle > 0
is_hitscan = false
```

연출:

```text
effect_style = shotgun_spread
3갈래 부채꼴 투사체
```

특징:

- 총알이 3갈래 부채꼴로 나간다.
- 근/중거리에서 넓은 범위를 커버한다.
- 개별 projectile은 독립 판정을 가진다.
- 공격범위 증가는 사거리만 늘린다.

---

### 4-2. sniper

저격형 원거리 공격이다.

기본 동작:

```text
projectile_count = 1
projectile_speed = high
pierce_count > 0
is_hitscan = false
```

연출:

```text
effect_style = sniper_projectile
빠른 직선 탄환
```

특징:

- 원거리 무기 중 유일하게 기본 관통을 가진다.
- 탄속이 빠르다.
- 긴 사거리를 가진다.
- 단일 고위력/고정밀 무기 역할을 맡는다.
- 공격범위 증가는 사거리만 늘린다.

---

### 4-3. laser

레이저형 원거리 공격이다.

기본 동작:

```text
projectile_count = 0
is_hitscan = true
```

연출:

```text
effect_style = laser_beam
레이저 빔 이펙트
```

특징:

- 원거리 무기 중 유일한 히트스캔 무기다.
- 투사체 이동 시간이 없다.
- 공격 방향으로 즉시 판정한다.
- 레이저 이펙트를 반드시 동반한다.
- 공격범위 증가는 레이저 길이만 늘린다.

---

### 4-4. rifle

표준 원거리 공격이다.

기본 동작:

```text
projectile_count = 1
is_hitscan = false
pierce_count = 0
projectile_speed = medium
```

연출:

```text
effect_style = rifle_projectile
표준 투사체 이펙트
```

특징:

- 가장 표준적인 원거리 무기다.
- 낮은 데미지를 가진다.
- 안정적인 연사와 직관적인 투사체 감각을 담당한다.
- 공격범위 증가는 사거리만 늘린다.

---

### 4-5. revolver

리볼버형 원거리 공격이다.

기본 동작:

```text
projectile_count = 1
is_hitscan = false
pierce_count = 0
projectile_speed = medium_high
range_units = short
```

연출:

```text
effect_style = revolver_projectile
짧고 묵직한 투사체 이펙트
```

특징:

- 원거리 무기 중 사거리가 가장 짧다.
- 중간급 데미지를 가진다.
- rifle보다 더 짧고 묵직한 단발감을 가진다.
- 공격범위 증가는 사거리만 늘린다.

---

## 5. 공격범위 증가 처리 원칙

공격범위 스탯은 모든 공격모듈에 동일한 방식으로 적용하지 않는다.

### 5-1. melee 범위 증가

근거리 공격범위 증가는 `attack_style`별 width/height 성장 계수를 따른다.

| attack_style | width growth | height growth |
|---|---:|---:|
| slash | 1.0 | 0.1 |
| stab | 1.0 | 0.0 |
| pierce | 1.0 | 0.0 |
| cleave | 1.0 | 0.2 |
| smash | 1.0 | 0.1 |

### 5-2. ranged 범위 증가

원거리 공격범위 증가는 기본적으로 사거리만 증가시킨다.

```text
range_units *= attack_range_multiplier
```

아래 값은 공격범위 스탯으로 증가하지 않는다.

- projectile width
- projectile height
- projectile collision radius
- shotgun projectile count
- shotgun spread angle
- sniper pierce count

이 값들은 개별 모듈 옵션, 등급 강화, 별도 아이템 효과로만 변한다.

---

## 6. 구현 순서

권장 구현 순서:

```text
1. 공격모듈 데이터에 attack_style/effect_style 필드 추가
2. 기존 melee 모듈 5종에 slash/stab/pierce/cleave/smash 매핑
3. 기존 ranged 또는 향후 ranged 모듈에 shotgun/sniper/laser/rifle/revolver 매핑
4. range_growth_width_scale / range_growth_height_scale 처리 추가
5. 기존 melee shape query가 attack_style별 base_shape_units를 사용하도록 정리
6. ranged projectile/hitscan 처리에서 attack_style별 옵션을 읽도록 정리
7. AttackEffectSpawner 또는 유사한 연출 전용 helper 추가
8. 각 effect_style별 임시 디버그 이펙트 구현
9. 실제 아트/사운드 에셋 적용
```

주의:

- 1차 구현에서는 실제 아트 에셋이 없어도 된다.
- 먼저 임시 shape/line/polygon 이펙트로 스타일 차이를 확인한다.
- 판정 로직과 이펙트 로직은 분리한다.
- 개별 module_id별 if 분기를 늘리지 않는다.

---

## 7. 현재 유보 사항

아래 항목은 추후 구현 단계에서 확정한다.

- mechanic 세부 attack_style
- aura형 공격모듈의 지속 방식
- ranged projectile 크기 증가를 허용할 별도 아이템 여부
- shotgun spread angle 성장 여부
- sniper pierce count 성장 여부
- laser 다중 타격/지속 타격 여부
- slash/cleave를 실제 arc shape으로 구현할지, 회전 rect로 유지할지
- effect_scene_path를 리소스 경로로 둘지, effect_style resolver로 둘지

---

## 8. 결론

공격모듈은 `module_type`만으로 세부 동작을 결정하지 않는다.

최종 구조는 아래를 따른다.

```text
module_type  = melee / ranged / mechanic
attack_style = slash / stab / pierce / cleave / smash / shotgun / sniper / laser / rifle / revolver
effect_style = 실제 시각 연출 타입
```

이 구조를 통해 같은 근거리 모듈이라도 소드, 단검, 랜스, 대검, 해머가 서로 다른 판정과 연출을 가질 수 있다.
또한 같은 원거리 모듈이라도 산탄, 저격, 레이저, 소총, 리볼버가 서로 다른 전투 감각을 가질 수 있다.

핵심 원칙:

```text
공격 판정은 데이터 기반으로 처리한다.
시각 이펙트는 effect_style로 분리한다.
module_id별 하드코딩을 피한다.
```
