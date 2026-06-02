# Codex 작업 지시서 - Weapon Catalog VO 확장 반영

대상 프로젝트: `Burial-Protocol`  
작업 목적: 현재 공격모듈/무기 구현을 `Weapon Catalog` 기반 신규 VO 구조로 확장한다.

---

## 0. 절대 원칙

1. 현재 플레이 가능한 코어 루프를 깨지 않는다.
2. 기존 공격모듈 구매/장착/합성/상점/레벨업/Day 루프가 정상 동작해야 한다.
3. 기존 `attack_style`, `fire_mode`, `is_hitscan` 중심 구현은 한 번에 제거하지 않는다.
4. 신규 VO를 먼저 병행 수용하고, 기존 데이터는 compatibility layer로 해석한다.
5. 무기별 `item_id` 하드코딩 분기를 만들지 않는다.
6. 데이터 기반 resolver를 확장한다.
7. 문서와 코드가 충돌하면 현재 실행 가능한 코드가 우선이지만, 신규 구현 목표는 아래 VO 구조를 따른다.

---

## 1. 현재 문서 기준

작업 전 반드시 확인할 문서:

- `docs/00_project_rules.md`
- `docs/02_systems_spec.md`
- `docs/03_data_and_state_spec.md`
- `docs/06_attack_modules.md`
- `docs/05_balance_formula.md`

특히 `03_data_and_state_spec.md`의 `Shop Item Data` 섹션에 추가된 Weapon Catalog VO 정의를 우선 기준으로 한다.

현재 공격모듈 canonical 문서는 `06_attack_modules.md`이다. 이 문서는 현재 구현 기준을 설명한다. 신규 VO 반영 후에는 이 문서도 코드 변경에 맞춰 갱신해야 한다.

---

## 2. 신규 Weapon Catalog VO 핵심 개념

신규 VO는 아래 역할을 분리한다.

```text
attribute       = 피해/연출 속성
attack_type     = 유저가 보는 무기 유형 / 시너지 태그
activation_mode = 입력 또는 자동 발동 방식
hit_model       = 실제 피해 판정 생성 방식
hit_shape       = 실제 충돌/피해 판정용 추상 shape
effect_style    = 데미지 판정과 분리된 VFX/연출 타입
base_cooldown   = 피해 발생 기본 주기
```

중요 구분:

```text
attack_type은 유저/빌드용 유형이다.
hit_model은 코드가 실행하는 판정 방식이다.
effect_style은 VFX 선택값이다.
```

`attack_type`에 `hitscan`, `channel_cone`, `projectile_pierce` 같은 구현값을 넣으면 안 된다.

---

## 3. enum 정의

### 3-1. attribute

```text
electric
fire
physical
energy
chemical
```

의미:

| value | 의미 |
|---|---|
| `electric` | 번개, 스파크, 연쇄 전기 계열 |
| `fire` | 열, 연소, 화염 계열 |
| `physical` | 탄환, 칼날, 톱날, 파편, 충격 계열 |
| `energy` | 레이저, 플라즈마, 이온 빔 계열 |
| `chemical` | 산성, 독성, 부식 계열 |

### 3-2. attack_type

```text
support
projectile
area
linear
chain
explosion
```

의미:

| value | 한글명 | 의미 |
|---|---|---|
| `support` | 보조 | 회복, 정리, 보조 프로토콜 |
| `projectile` | 투사체 | 탄체가 이동해서 맞는 공격 |
| `area` | 영역 | 일정 범위에 반복/지속 피해를 주는 공격 |
| `linear` | 직선형 | 저격총, 레이저, 레일건, 이온 빔 등 직선 판정 유형 |
| `chain` | 연쇄 | 대상에서 대상으로 전이되는 공격 |
| `explosion` | 폭발 | 착탄/지점 주변에 범위 피해를 주는 공격 |

`beam/광선`은 사용하지 않는다. 저격총도 포함해야 하므로 `linear/직선형`을 사용한다.

### 3-3. activation_mode

```text
hold_repeat
hold_channel
auto_repeat
auto_channel
```

| value | 의미 | 예시 |
|---|---|---|
| `hold_repeat` | 공격키를 누르고 있으면 `base_cooldown`마다 공격 인스턴스 생성 | 권총, 샷건, 로켓 |
| `hold_channel` | 공격키를 누르고 있으면 판정 유지, `base_cooldown`마다 피해 | 화염방사기, 지속 레이저 |
| `auto_repeat` | 공격키와 무관하게 `base_cooldown`마다 자동 공격 | 자동 드론 사격 |
| `auto_channel` | 공격키와 무관하게 지속 판정 유지, `base_cooldown`마다 피해 | 톱날 링, 오라, 자동 영역 프로토콜 |

`click_once`는 만들지 않는다. 단발형 무기라도 공격키를 누르고 있으면 `base_cooldown`마다 반복 발사한다.

### 3-4. hit_model

```text
melee_shape
projectile_single
projectile_spread
projectile_pierce
projectile_explosion
hitscan_line
channel_line
channel_cone
area_zone
area_orbit
chain_jump
```

| value | 의미 | 예시 |
|---|---|---|
| `melee_shape` | 캐릭터 기준 근거리 shape 판정 | 소드, 랜스, 대검 |
| `projectile_single` | 단일 투사체 | 권총, 코어 슈터 |
| `projectile_spread` | 확산형 다중 투사체 | 샷건, 크레모아 |
| `projectile_pierce` | 관통 투사체 | 스나이퍼, 레일 드릴 |
| `projectile_explosion` | 착탄 후 폭발하는 투사체 | 로켓, 유탄, 네이팜 런처 |
| `hitscan_line` | 즉시 직선 1회 판정 | 저격총, 즉발 레이저 |
| `channel_line` | 유지형 직선 판정 | 지속 레이저, 이온 빔 |
| `channel_cone` | 유지형 부채꼴 판정 | 화염방사기 |
| `area_zone` | 특정 위치에 생성되는 지속 영역 | 독구름, 화염지대 |
| `area_orbit` | 플레이어/드론 주변 지속 영역 | 톱날 링, 커터 링 |
| `chain_jump` | 대상 간 전이 | 체인 라이트닝, 스파크 테이저 |

### 3-5. hit_shape

```text
point
line
cone
circle
box
ring
arc
```

| value | 의미 |
|---|---|
| `point` | 단일 탄 충돌 |
| `line` | 레이저, 저격, 레일건 등 직선 판정 |
| `cone` | 화염방사기 같은 전방 부채꼴 판정 |
| `circle` | 폭발, 구름, 원형 영역 |
| `box` | 근거리 베기/타격 판정 |
| `ring` | 톱날 링, 오라 등 주변 고리 판정 |
| `arc` | 짧은 부채꼴 베기 판정 |

### 3-6. effect_style

`effect_style`은 실제 데미지 판정에 영향을 주면 안 된다. VFX/연출 선택값이다.

예:

```text
sniper_tracer
laser_beam
ion_beam
flame_stream
flame_burst
shotgun_spread
saw_ring
chain_lightning
```

동일한 `hit_shape=line`이어도 저격총은 `sniper_tracer`, 지속 레이저는 `laser_beam`, 이온 빔은 `ion_beam`을 사용할 수 있다.

---

## 4. base_cooldown 정의

`base_cooldown`은 발사 간격과 tick 간격을 모두 의미한다.

별도 `tick_interval`은 만들지 않는다.

```text
반복 발사형: base_cooldown = 다음 공격 인스턴스 생성 간격
채널링/영역형: base_cooldown = 피해 tick 간격
```

예:

| 무기 | activation_mode | hit_model | base_cooldown 의미 |
|---|---|---|---|
| 권총 | `hold_repeat` | `projectile_single` | 다음 탄 발사 간격 |
| 샷건 | `hold_repeat` | `projectile_spread` | 다음 샷 발사 간격 |
| 화염방사기 | `hold_channel` | `channel_cone` | 화염 피해 tick 간격 |
| 지속 레이저 | `hold_channel` | `channel_line` | 레이저 피해 tick 간격 |
| 톱날 링 | `auto_channel` | `area_orbit` | 영역 피해 tick 간격 |

`duration_policy`도 만들지 않는다. 지속 방식은 `activation_mode`에 종속된다.
단, `area_duration`은 유지한다. `area_duration`은 생성된 영역 자체의 수명이다.

---

## 5. 데이터 스키마 작업

### 5-1. ShopItemDefinition.gd 확장

`ShopItemDefinition.gd`에 아래 필드를 추가한다.

```gdscript
@export var attribute: String = "physical"
@export var attack_type: String = "projectile"
@export var activation_mode: String = "hold_repeat"
@export var hit_model: String = ""
@export var hit_shape: String = "point"
@export var effect_style: String = ""
```

주의:

- 기존 `module_type`, `attack_style`, `effect_style`가 이미 있다면 중복 정의하지 말고 현재 구조를 확인한 뒤 추가/정리한다.
- `effect_style`이 이미 있다면 의미를 “VFX 선택값”으로 유지한다.
- 신규 필드가 비어 있어도 기존 모듈이 깨지지 않아야 한다.

### 5-2. TSV schema 확장

`data_tsv/attack_module_items.tsv`와 관련 TSV schema/import-export 경로를 확인한다.

추가/변경 대상 컬럼:

```text
attribute
attack_type
activation_mode
hit_model
hit_shape
effect_style
angle_degrees
```

기존 `spread_angle`은 장기적으로 `angle_degrees`로 이전한다.
단, 한 번에 삭제하지 말고 다음 compatibility를 둔다.

```text
angle_degrees가 있으면 angle_degrees 사용
없으면 spread_angle fallback 사용
```

기존 `fire_mode`가 존재한다면 장기적으로 `activation_mode + hit_model`로 분리한다.
초기 단계에서는 `fire_mode`를 읽어 신규 VO를 보완하는 fallback mapper를 둔다.

---

## 6. Compatibility Layer

기존 데이터가 바로 깨지지 않도록 아래 매핑을 제공한다.

### 6-1. attack_style fallback

기존 `attack_style` 기반 fallback:

| attack_style | attack_type | hit_model | hit_shape |
|---|---|---|---|
| `slash` | `area` 또는 기존 melee 기준 유지 | `melee_shape` | `arc` 또는 `box` |
| `stab` | `area` 또는 기존 melee 기준 유지 | `melee_shape` | `line` |
| `pierce` | `linear` 또는 기존 melee/ranged 기준 | `melee_shape` 또는 `projectile_pierce` | `line` |
| `cleave` | `area` | `melee_shape` | `arc` |
| `smash` | `area` | `melee_shape` | `box` 또는 `circle` |
| `shotgun` | `projectile` | `projectile_spread` | `point` |
| `sniper` | `linear` | `projectile_pierce` 또는 `hitscan_line` | `line` 또는 `point` |
| `laser` | `linear` | `channel_line` 또는 기존 구현상 `hitscan_line` | `line` |
| `rifle` | `projectile` | `projectile_single` | `point` |
| `revolver` | `projectile` | `projectile_single` | `point` |

### 6-2. fire_mode fallback

기존 또는 Spreadsheet 초안의 `fire_mode`가 남아 있을 경우 아래처럼 해석한다.

| fire_mode | activation_mode | hit_model |
|---|---|---|
| `projectile_rapid` | `hold_repeat` | `projectile_single` |
| `projectile_spread` | `hold_repeat` | `projectile_spread` |
| `projectile_pierce` | `hold_repeat` | `projectile_pierce` |
| `explosion_on_hit` | `hold_repeat` | `projectile_explosion` |
| `hitscan_line` | `hold_repeat` | `hitscan_line` |
| `area_tick` | `hold_channel` 또는 `auto_channel` | `area_zone` |
| `chain_jump` | `hold_repeat` | `chain_jump` |
| `mechanic_auto` | `auto_repeat` | 기존 mechanic resolver 기준 |
| `cone_area_tick` | `hold_channel` | `channel_cone` |
| `hitscan_piercing_beam` | `hold_channel` | `channel_line` |
| `projectile_fire_dot` | `hold_repeat` | `projectile_explosion` 또는 `area_zone` 후속 판단 |

이 mapper는 임시 compatibility layer다. 최종 데이터가 신규 VO로 정리되면 의존도를 낮춘다.

---

## 7. Resolver 설계

기존 `AttackModuleStyleResolver.gd`를 바로 제거하지 않는다.
아래 중 하나로 진행한다.

권장 방식:

```text
WeaponBehaviorResolver.gd 신규 추가
```

역할:

- `ShopItemDefinition` 또는 공격모듈 definition을 입력받는다.
- 신규 VO 필드가 있으면 우선 사용한다.
- 신규 VO 필드가 비어 있으면 기존 `attack_style`, `is_hitscan`, `projectile_count`, `spread_angle`, `pierce_count` 등으로 fallback한다.
- 최종적으로 Main/Player가 사용할 normalized behavior dictionary 또는 Resource를 반환한다.

예상 반환 구조:

```gdscript
{
    "attribute": "fire",
    "attack_type": "area",
    "activation_mode": "hold_channel",
    "hit_model": "channel_cone",
    "hit_shape": "cone",
    "effect_style": "flame_stream",
    "base_cooldown": 0.12,
    "range_units": 3.0,
    "angle_degrees": 35.0,
    "projectile_count": 1,
    "pierce_count": 0,
    "explosion_radius_u": 0.0,
    "area_duration": 0.0,
    "sand_collision_policy": "shape_area"
}
```

---

## 8. 입력/공격 발동 구현

공격 발동은 `activation_mode`를 따른다.

### 8-1. hold_repeat

```text
공격키를 누르고 있으면 base_cooldown마다 공격 인스턴스 생성
```

예:

- 권총
- 샷건
- 로켓
- 유탄

기존 좌클릭 공격 반복 구조는 대부분 `hold_repeat`로 볼 수 있다.

### 8-2. hold_channel

```text
공격키 누름 시작 → channel 인스턴스 생성
누르고 있는 동안 → 방향/위치 갱신 + base_cooldown마다 피해
공격키 뗌 → channel 종료
```

필수 대상:

- 화염방사기: `hit_model = channel_cone`
- 지속 레이저: `hit_model = channel_line`

주의:

- 매 프레임 데미지를 넣으면 안 된다.
- `base_cooldown`마다 tick 피해만 넣는다.
- VFX는 누르고 있는 동안 유지되어야 한다.
- 판정은 마우스 방향을 계속 따라가야 한다.

### 8-3. auto_repeat

```text
공격키와 무관하게 base_cooldown마다 자동 공격 인스턴스 생성
```

예:

- 자동 드론 사격
- 포탑형 프로토콜

### 8-4. auto_channel

```text
공격키와 무관하게 지속 판정 유지 + base_cooldown마다 피해
```

예:

- 톱날 링
- 오라
- 자동 영역 프로토콜

---

## 9. hit_model별 1차 구현 범위

이번 Codex 작업에서 전체 무기를 완성하려 하지 말고, 아래 우선순위로 구현한다.

### 1차 필수

```text
projectile_single
projectile_spread
projectile_pierce
projectile_explosion
hitscan_line
channel_line
channel_cone
```

이유:

- 기존 권총/샷건/스나이퍼/로켓 계열 유지
- 신규 지속 레이저 구현 가능
- 신규 화염방사기 구현 가능

### 2차 또는 TODO

```text
area_zone
area_orbit
chain_jump
auto_repeat
auto_channel
```

단, 기존 구현이 이미 있으면 깨지지 않도록 fallback 유지한다.

---

## 10. 화염방사기 구현 기준

목표 VO:

```text
attribute = fire
attack_type = area
activation_mode = hold_channel
hit_model = channel_cone
hit_shape = cone
effect_style = flame_stream
base_cooldown = 피해 tick 간격
range_units = 사거리
angle_degrees = 부채꼴 각도
sand_collision_policy = shape_area
```

동작:

```text
공격키를 누르고 있는 동안 전방 cone 판정이 유지된다.
cone 방향은 마우스 방향을 따른다.
범위 안의 블록은 base_cooldown마다 피해를 받는다.
모래 타격 가능 여부는 can_hit_sand와 sand_collision_policy를 따른다.
```

주의:

- `area_duration`으로 화염방사기 지속시간을 표현하지 않는다.
- 화염방사기는 입력을 떼면 즉시 종료된다.
- VFX는 `effect_style=flame_stream` 또는 임시 디버그 VFX로 표시한다.

---

## 11. 지속 레이저 구현 기준

목표 VO:

```text
attribute = energy
attack_type = linear
activation_mode = hold_channel
hit_model = channel_line
hit_shape = line
effect_style = laser_beam
base_cooldown = 피해 tick 간격
range_units = 사거리
pierce_count = 관통 수
sand_collision_policy = hitscan_first_hit 또는 hitscan_pierce_by_count
```

동작:

```text
공격키를 누르고 있는 동안 마우스 방향으로 레이저 선이 유지된다.
레이저 선상 대상은 base_cooldown마다 피해를 받는다.
관통 여부는 pierce_count와 sand_collision_policy를 따른다.
```

주의:

- 즉발 히트스캔 1회가 아니다.
- 레이저가 지지지잉 유지되는 느낌이어야 한다.
- tick 피해는 `base_cooldown`마다 발생한다.
- VFX는 판정 길이와 분리하되, 표시 길이는 `range_units`를 따라가면 된다.

---

## 12. effect_style 처리 원칙

`effect_style`은 판정과 데미지를 절대 바꾸지 않는다.

허용:

```text
effect_style → VFX scene 선택
effect_style → trail/beam/flame/spark 연출 선택
effect_style → 사운드/화면 흔들림 후보 선택
```

금지:

```text
effect_style로 데미지 변경
effect_style로 사거리 변경
effect_style로 충돌 shape 변경
effect_style로 pierce_count 변경
```

VFX scene path가 아직 없으면 임시 debug drawing을 사용해도 된다.
단, 코드 구조는 나중에 `effect_scene_path` 또는 VFX registry로 확장할 수 있게 둔다.

---

## 13. sand_collision_policy 처리

기존 sand collision 정책은 유지하되 신규 hit_model과 연결한다.

권장 값:

```text
shape_area
block_on_hit
pierce_by_count
explode_on_hit
hitscan_first_hit
hitscan_pierce_by_count
```

의미:

| value | 의미 |
|---|---|
| `shape_area` | 근접/영역 shape가 범위 내 모래를 개별 판정 |
| `block_on_hit` | 비관통 투사체가 첫 충돌에서 정지 |
| `pierce_by_count` | pierce_count만큼 모래/블록 관통 |
| `explode_on_hit` | 첫 충돌 지점에서 폭발 판정 생성 |
| `hitscan_first_hit` | 비관통 직선 판정이 첫 충돌에서 정지 |
| `hitscan_pierce_by_count` | 관통 수만큼 직선 판정 진행 |

주의:

- 모래 데미지 비율은 기존 정책을 유지한다.
- 이전에 논의한 기준상 모래는 일반 데미지의 10%만 받는 방향이다.
- 드론/프로토콜이 모래에 피해를 줄 수 있는지는 별도 정책으로 제한한다.

---

## 14. 데이터 파이프라인 반영

확인/수정 대상 후보:

```text
data_tsv/attack_module_items.tsv
data/items/ShopItemCatalog.tres
scripts/data/ShopItemDefinition.gd
scripts/data/ShopItemCatalog.gd
scripts/data/AttackModuleStyleResolver.gd
scripts/data/WeaponBehaviorResolver.gd  # 신규 권장
scripts/tools/data_pipeline/*
scripts/tests/attack_module_dps_snapshot.gd
```

작업:

1. TSV schema가 신규 컬럼을 읽고 쓸 수 있게 한다.
2. TRES 변환 시 신규 필드가 보존되게 한다.
3. export 시 신규 필드가 빠지지 않게 한다.
4. 기존 TSV에 신규 컬럼이 없어도 import가 실패하지 않게 한다.
5. `spread_angle`과 `angle_degrees`는 병행 처리한다.
6. 기존 `is_hitscan`은 legacy compatibility로 유지한다.

---

## 15. 테스트/검증

작업 후 최소 검증:

```text
1. 프로젝트 로드 에러 없음
2. 기존 기본 공격모듈 정상 공격
3. 기존 샷건/스나이퍼/레이저 계열이 깨지지 않음
4. 공격모듈 구매/장착/합성 정상
5. 상점 아이템 롤 정상
6. attack_module_dps_snapshot.gd 실행 가능
7. TSV -> TRES import/export 가능
8. 신규 hold_channel 테스트 무기 1종 이상 동작
```

가능하면 추가할 테스트:

```text
- WeaponBehaviorResolver fallback test
- attack_style only 데이터 → 신규 normalized behavior 확인
- 신규 VO 데이터 → normalized behavior 확인
- hold_repeat cooldown 반복 확인
- hold_channel tick 간격 확인
- channel_line 방향 갱신 확인
- channel_cone 방향 갱신 확인
```

---

## 16. 구현 우선순위

### Phase 1. 데이터 필드 추가와 호환 유지

- `ShopItemDefinition.gd` 신규 필드 추가
- TSV schema/import/export 신규 필드 추가
- 기존 데이터 로드 실패 방지
- 기존 공격 동작 변화 최소화

### Phase 2. Resolver 도입

- `WeaponBehaviorResolver.gd` 추가 또는 `AttackModuleStyleResolver.gd` 확장
- 신규 VO 우선, 기존 attack_style/fire_mode fallback
- normalized behavior 반환

### Phase 3. 기존 발사형 무기 연결

- `hold_repeat + projectile_single`
- `hold_repeat + projectile_spread`
- `hold_repeat + projectile_pierce`
- `hold_repeat + projectile_explosion`
- `hold_repeat + hitscan_line`

### Phase 4. 채널링 무기 연결

- `hold_channel + channel_line`
- `hold_channel + channel_cone`
- 임시 레이저/화염방사기 테스트 데이터 추가 또는 기존 레이저/화염방사기 데이터 변환

### Phase 5. 문서/스냅샷 갱신

- `docs/06_attack_modules.md`를 실제 코드 변경 기준으로 갱신
- 필요 시 `docs/02_systems_spec.md`, `docs/03_data_and_state_spec.md`와 불일치 확인
- `attack_module_dps_snapshot.md` 재생성

---

## 17. 완료 조건

아래가 만족되면 작업 완료로 본다.

- 신규 VO 필드가 `ShopItemDefinition`과 TSV/TRES 파이프라인에서 보존된다.
- 기존 공격모듈이 기존처럼 동작한다.
- 신규 `activation_mode + hit_model` 조합으로 최소 1개 이상의 채널링 무기가 동작한다.
- 화염방사기형 `channel_cone`가 base_cooldown마다 tick 피해를 준다.
- 지속 레이저형 `channel_line`이 base_cooldown마다 tick 피해를 준다.
- `attack_type`이 구현 세부값이 아니라 유저용 유형으로 유지된다.
- `effect_style`이 판정/데미지에 영향을 주지 않는다.
- 테스트 또는 스냅샷으로 회귀 확인이 가능하다.
- 변경된 실제 구현 기준이 `docs/06_attack_modules.md`에 반영된다.

---

## 18. 금지 사항

- `click_once` 추가 금지
- 별도 `tick_interval` 추가 금지
- 별도 `duration_policy` 추가 금지
- `effect_style`로 판정/데미지 변경 금지
- `attack_type`에 구현 세부값 넣기 금지
- 무기별 `item_id` 하드코딩 분기 금지
- 기존 작동 무기 파괴 금지
- `damage_multiplier`를 공격모듈 직접 필드로 재도입 금지

---

## 19. Codex 응답 요구사항

작업 후 Codex는 아래를 보고한다.

```text
1. 변경 파일 목록
2. 신규/변경 필드 목록
3. 기존 데이터 호환 방식
4. 신규 resolver 구조
5. 구현된 activation_mode 목록
6. 구현된 hit_model 목록
7. 화염방사기/지속 레이저 동작 여부
8. 실행한 테스트/스냅샷
9. 남은 TODO
```

테스트를 실행하지 못한 경우, 실행하지 못한 이유와 수동 확인 방법을 명시한다.
