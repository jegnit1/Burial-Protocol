# Burial Protocol - Neon Minimal Art Implementation Guide

기준 레퍼런스: `references/burial_protocol_neon_minimal_wall_reference.svg`

목표: 레퍼런스 이미지와 최대한 유사한 인게임 비주얼을 구현한다. 단, 이번 작업에서는 **플레이어 캐릭터 스프라이트 교체는 제외**한다. 캐릭터 외의 월드/벽/블록/모래/채굴 피드백/공격 이펙트/HUD 톤을 레퍼런스에 맞춘다.

---

## 0. 최종 목표

현재 프로토타입성 면 채우기 화면을 아래 컨셉으로 변경한다.

```text
암흑 배경
얇은 회색/흰색 수직 샤프트 실루엣
좌우 채굴벽은 무거운 단색 덩어리가 아니라 얇은 라인/균열/서브셀 흔적 중심
중앙 전장은 10U 폭이 명확히 보이는 어두운 수직 공간
블록은 면 채우기보다 네온 외곽선 중심
모래는 덩어리 사각형보다 노란 점 입자 군집처럼 보임
채굴 가능한 벽/채굴 중인 벽은 노란 균열, 스파크, 파편으로 강하게 구분
공격은 선, 궤적, 짧은 플래시, 잔상 중심
HUD는 어두운 반투명 패널 + 고대비 숫자 + 얇은 네온 라인
```

이 작업의 핵심은 **새 아트 에셋을 많이 추가하는 것**이 아니라, 현재 `Node2D._draw()`, `Control`, `StyleBoxFlat`, `Line2D`, 파티클/잔상 연출로 레퍼런스와 유사한 스타일을 만드는 것이다.

---

## 1. 절대 유지해야 하는 게임 스펙

### 1-1. 월드 단위

현재 프로젝트 기준을 유지한다.

```text
1U = 64px
WORLD_COLUMNS = 30
WALL_COLUMNS = 10
CENTER_COLUMNS = 10
WORLD_ROWS = 200
좌측 벽 10U + 중앙 전장 10U + 우측 벽 10U
```

중앙 전장은 반드시 10U 폭으로 유지한다. 레퍼런스처럼 화면 중앙에 좁고 긴 샤프트가 보여야 한다.

### 1-2. 플레이어 캐릭터 제외

이번 작업에서 캐릭터 스프라이트 자체는 바꾸지 않는다.

금지:

```text
- assets/characters/player/main_idle.png 교체
- assets/characters/player/main_run.png 교체
- Player.tscn의 애니메이션 프레임 구조 변경
- PLAYER_SIZE 변경
- 플레이어 충돌 박스 변경
```

허용:

```text
- 플레이어 주변 공격모듈 visual의 색/라인/이펙트 조정
- 공격/채굴 프리뷰 스타일 조정
- 피격/대시/무적 플래시 색상 조정
```

### 1-3. 충돌/판정과 렌더링 분리

벽, 모래, 블록의 충돌/게임플레이 판정은 기존 로직을 유지한다. 이번 작업은 시각 표현 중심이다.

금지:

```text
- wall_cells 구조 변경
- sand_cells 구조 변경
- FallingBlock 이동/충돌 로직 변경
- Player 이동/점프/대시/벽타기 판정 변경
- 채굴 범위 수치 변경
```

---

## 2. 레퍼런스 핵심 해석

레퍼런스는 일반 픽셀아트 배경이 아니다. 아래와 같은 **절차형 네온 미니멀 스타일**이다.

```text
배경: 거의 검정색
큰 면: 거의 없음
주요 형태: 얇은 선, 외곽선, 작은 점
강조: 고채도 네온 컬러
정보 전달: 색상과 깜빡임, 스파크, 짧은 잔상
```

따라서 구현 시 아래 규칙을 따른다.

```text
면을 칠하기보다 선을 그린다.
색을 많이 쓰기보다 역할별 컬러를 고정한다.
정지 상태보다 피격/채굴/파괴 순간을 강하게 만든다.
화려한 텍스처보다 짧고 명확한 애니메이션을 쓴다.
```

---

## 3. 공통 팔레트

아래 색상을 기준으로 전역 상수 또는 별도 스타일 helper에 정의한다.

권장 위치:

```text
scripts/autoload/GameConstants.gd
```

또는 아트 스타일 전용 helper를 만들 경우:

```text
scripts/data/NeonArtStyle.gd
```

권장 색상:

```gdscript
const NEON_BG := Color("030508")
const NEON_WORLD_BG := Color("010205")
const NEON_CENTER_BG := Color("010306")

const NEON_WALL_BASE := Color("05090d")
const NEON_WALL_LINE := Color("6f7c87")
const NEON_WALL_EDGE := Color("e8f2ff")
const NEON_WALL_CRACK := Color("8f9ba7")
const NEON_WALL_MINED_BG := Color("020407")

const NEON_MINING_YELLOW := Color("ffd45f")
const NEON_MINING_ORANGE := Color("ffb72e")
const NEON_MINING_WHITE := Color("fff0a8")

const NEON_BLOCK_CYAN := Color("52e2ff")
const NEON_BLOCK_AMBER := Color("ffcc44")
const NEON_BLOCK_RED := Color("ff4f68")
const NEON_BLOCK_PURPLE := Color("bc72ff")
const NEON_BLOCK_WHITE := Color("ffffff")

const NEON_UI_PANEL := Color(0.03, 0.06, 0.09, 0.86)
const NEON_UI_BORDER := Color("334250")
const NEON_UI_TEXT := Color("e8f2ff")
const NEON_UI_SUBTEXT := Color("8191a4")
```

주의:

```text
- 배경은 완전 검정이 아니라 아주 어두운 남청/흑청 계열을 사용한다.
- 흰색 선은 중요한 경계에만 사용한다.
- 노란색은 채굴/보상/스파크 역할에 우선 배정한다.
- 빨간색은 위험/보스/중량 초과/강한 피격에 우선 배정한다.
```

---

## 4. WorldGrid 렌더링 변경

대상 파일:

```text
scenes/world/WorldGrid.gd
```

현재 문제:

```text
좌우 벽 전체를 큰 단색 사각형으로 칠하고 있음.
레퍼런스의 얇은 선 중심 벽과 다름.
```

목표:

```text
벽을 무거운 면이 아니라 얇은 라인/균열/서브셀 흔적으로 표현한다.
중앙 전장 경계선은 흰색/회색 단선으로 명확히 보인다.
손상/채굴된 셀은 노란 균열과 파편으로 더 강하게 보인다.
```

### 4-1. 기본 배경

`_draw()` 시작부는 아래 컨셉으로 바꾼다.

```gdscript
# 배경
# 전체 월드: 아주 어두운 검정/남청
# 중앙 전장: 더 깊은 검정
# 좌우 벽: 어두운 면 + 약한 라인만
```

표현 규칙:

```text
- get_world_rect(): NEON_WORLD_BG
- get_center_rect(): NEON_CENTER_BG
- 좌우 벽 rect: NEON_WALL_BASE, alpha 0.85 이하
- 중앙 전장 좌/우 경계선: NEON_WALL_EDGE, 2px, alpha 0.70~0.90
```

현재처럼 벽을 진한 단색으로 꽉 칠하지 말고, 어둡게 깔아둔 뒤 라인을 올린다.

### 4-2. 벽 라인 패턴

벽 내부에는 모든 셀을 그리드로 다 그리지 않는다. 너무 시끄러워진다.

권장 규칙:

```text
- 1U마다 전체 그리드 라인을 다 그리지 않는다.
- 2~4U 간격으로 짧은 수평 균열선을 그린다.
- 좌우 벽 안쪽 경계는 가장 밝게 그린다.
- 외곽 경계는 한 단계 어둡게 그린다.
```

예시 함수:

```gdscript
func _draw_wall_idle_cracks(rect: Rect2, side_sign: int) -> void:
    ## 벽 균열
    var cell := float(GameConstants.CELL_SIZE)
    var line_color := GameConstants.NEON_WALL_CRACK
    line_color.a = 0.45
    for row in range(2, GameConstants.FLOOR_ROW, 3):
        var y := rect.position.y + float(row) * cell + cell * 0.35
        var x_start := rect.position.x + cell * 0.6
        var length := cell * (0.5 + float((row * 37) % 5) * 0.18)
        if side_sign > 0:
            x_start = rect.end.x - cell * 0.6 - length
        draw_line(Vector2(x_start, y), Vector2(x_start + length, y), line_color, 2.0)
```

주의:

```text
랜덤을 매 프레임 사용하지 않는다.
row 기반 deterministic 패턴으로 만든다.
_draw() 호출 때마다 균열 위치가 바뀌면 안 된다.
```

### 4-3. 손상 셀 렌더링

현재 벽은 1U wall cell HP를 기준으로 스프라이트 타일 상태를 선택해 그린다.

변경 목표:

```text
손상된 셀은 구멍처럼 어둡게 보이고, 남은 서브셀은 면이 아니라 짧은 선/작은 사각형/균열 조각으로 보인다.
```

권장 표현:

```text
- 셀 배경: NEON_WALL_MINED_BG
- 남은 서브셀: 어두운 회색 면 20~35% alpha + 얇은 테두리
- 손상도가 높을수록 노란 균열선 추가
- 완전 채굴된 셀은 검은 구멍 + 가장자리 잔광
```

구체 규칙:

```gdscript
var damage_ratio := 1.0 - float(hp) / float(GameConstants.WALL_CELL_MAX_HP)
var fill_color := GameConstants.NEON_WALL_BASE.lerp(GameConstants.NEON_WALL_MINED_BG, damage_ratio)
fill_color.a = 0.45
var edge_color := GameConstants.NEON_WALL_LINE.lerp(GameConstants.NEON_MINING_YELLOW, damage_ratio)
edge_color.a = 0.35 + damage_ratio * 0.45
```

서브셀을 전부 꽉 찬 사각형으로 그리지 말고:

```text
- fill rect alpha 낮게
- draw_rect(..., edge_color, false, 1.0)로 얇은 테두리
- damage_ratio >= 0.33이면 짧은 노란 crack 1개
- damage_ratio >= 0.66이면 노란 점 1~2개
```

### 4-4. 채굴 가능/채굴 중 피드백

채굴이 성공한 순간에만 보이면 부족하다. 사용자가 “여기가 채굴되는 벽”이라는 것을 알 수 있어야 한다.

1차 구현은 이벤트 저장 없이도 가능하다.

```text
_touched_cells 주변은 노란 균열이 더 선명하게 보이도록 한다.
완전 무손상 벽은 얇고 차분한 회색.
손상된 벽은 노란/흰색 스파크 느낌.
```

추가로 가능하면 아래 상태를 추가한다.

```gdscript
var _mining_spark_events: Array[Dictionary] = []
```

채굴 성공 시 `try_mine_in_shape()`에서 hit cell 중심에 이벤트를 추가한다.

```gdscript
_mining_spark_events.append({
    "position": get_cell_rect(cell).get_center(),
    "time": 0.18,
    "seed": int(cell.x * 92821 + cell.y * 68917),
})
```

`_process(delta)` 또는 별도 update에서 time을 줄이고, `_draw()`에서 그린다.

표현:

```text
- 중심 노란 점 2~3개
- 짧은 선 2~4개
- 0.18초 이내 빠르게 사라짐
```

---

## 5. FallingBlock 렌더링 변경

대상 파일:

```text
scenes/blocks/FallingBlock.gd
```

현재 문제:

```text
블록을 block_base_color로 꽉 채우고 어두운 테두리를 두름.
레퍼런스의 네온 외곽선 블록과 다름.
```

목표:

```text
블록 내부 면을 거의 비우고, 재질별 네온 외곽선과 작은 하이라이트로 표현한다.
```

### 5-1. 기본 블록 표현

`_draw()`에서 면 채우기를 줄인다.

권장 구조:

```gdscript
func _draw() -> void:
    if block_data == null:
        return
    var rect := Rect2(-block_data.get_size_pixels() * 0.5, block_data.get_size_pixels())
    _draw_neon_block(rect)
    if _hp_overlay_timer > 0.0:
        _draw_hp_overlay()
```

`_draw_neon_block(rect)` 개념:

```text
1. 내부 아주 어두운 반투명 fill
2. 외곽선 1차: 재질 색상, 3~4px
3. 외곽선 2차: 같은 색상 alpha 낮게, rect.grow(3~5), 1~2px
4. 코너 하이라이트: 흰색 짧은 선
5. 내부 노이즈 점/짧은 선 2~5개
```

Godot 2D에서 진짜 bloom이 없어도 `rect.grow()`로 가짜 glow를 만든다.

```gdscript
var base_color := block_data.block_base_color
var glow_color := base_color
var inner_color := Color(base_color.r * 0.08, base_color.g * 0.08, base_color.b * 0.08, 0.16)

draw_rect(rect, inner_color)

glow_color.a = 0.18
draw_rect(rect.grow(5.0), glow_color, false, 2.0)

glow_color.a = 0.36
draw_rect(rect.grow(2.0), glow_color, false, 2.0)

glow_color.a = 0.95
draw_rect(rect, glow_color, false, 4.0)
```

### 5-2. 재질별 컬러 보정

`block_data.block_base_color`가 너무 탁하면 네온 느낌이 약하다. 직접 데이터 변경이 부담되면 렌더링 단계에서 보정한다.

권장 함수:

```gdscript
func _get_neon_block_color() -> Color:
    var color := block_data.block_base_color
    color = color.lightened(0.20)
    color.s = min(color.s * 1.25, 1.0)
    color.v = max(color.v, 0.85)
    return color
```

Godot `Color`에서 `s/v` 직접 접근이 애매하면 HSV 변환 대신 재질 id 기준 매핑을 사용한다.

권장 매핑:

```text
wood    -> #ffcc44 또는 #d8a640
stone   -> #a9b5c2
marble  -> #e8f2ff
steel   -> #52e2ff 또는 #6f8cff
crystal -> #bc72ff
boss    -> #ff4f68
```

### 5-3. 피격 피드백

현재 HP overlay만 표시한다. 레퍼런스 스타일에서는 피격 순간 블록 외곽선이 강하게 번쩍여야 한다.

추가 상태:

```gdscript
var _hit_flash_timer := 0.0
```

`apply_damage()`에서:

```gdscript
_hit_flash_timer = 0.08
queue_redraw()
```

`_physics_process(delta)`에서 감소.

표현:

```text
_hit_flash_timer > 0이면
- 외곽선 흰색 5px
- block color glow alpha 증가
- 작은 파편 점 3~6개 가능
```

---

## 6. SandField 렌더링 변경

대상 파일:

```text
scenes/world/SandField.gd
```

현재 문제:

```text
모래 셀을 작은 사각형으로 채움.
레퍼런스의 노란 점 입자 군집 느낌과 다름.
```

목표:

```text
모래는 노란색 점/작은 입자들의 누적으로 보이게 한다.
쌓인 양은 읽혀야 하므로 완전히 희미하게 만들면 안 된다.
```

### 6-1. 셀별 점 렌더링

현재 `_draw()`에서 `draw_rect(rect, draw_color)`를 호출한다.

변경:

```text
- 셀 rect 전체를 칠하지 않는다.
- 셀 중심 또는 deterministic offset 위치에 작은 원/사각 점을 찍는다.
- 안정된 셀은 어두운 노랑.
- 불안정/이동 가능 셀은 밝은 노랑.
- 손상도/HP 낮음은 어둡게.
```

권장:

```gdscript
func _draw_sand_particle(cell: Vector2i, sand_cell: SandCellData) -> void:
    var rect := get_sand_cell_rect(cell)
    var seed := int(cell.x * 73856093 ^ cell.y * 19349663)
    var ox := float(seed % 5 - 2) * 0.6
    var oy := float((seed / 7) % 5 - 2) * 0.6
    var center := rect.get_center() + Vector2(ox, oy)
    var radius := clampf(rect.size.x * 0.22, 1.2, 3.0)
    var color := GameConstants.NEON_MINING_YELLOW
    if sand_cell.stable:
        color = Color("f4b93c")
    var damage_ratio := 1.0 - float(sand_cell.hp) / float(sand_cell.max_hp)
    color = color.darkened(damage_ratio * 0.35)
    draw_circle(center, radius, color)
```

주의:

```text
모래 셀 수가 많으므로 과한 glow/라인은 성능에 부담.
각 셀마다 여러 원을 그리지 말 것.
기본은 셀 1개당 점 1개.
표면/최근 채굴 주변만 추가 점 허용.
```

### 6-2. 표면 강조

모래 더미의 형태를 읽기 위해 표면 셀은 더 밝게 보인다.

간단 판정:

```gdscript
var above := cell + Vector2i.UP
var is_surface := not sand_cells.has(above)
```

표현:

```text
surface cell: radius +0.4, color lightened
inner cell: darker amber
```

### 6-3. 중량 위험 색상

중량이 위험 구간이면 모래 점 일부를 주황/빨강으로 섞을 수 있다. 단, 1차 작업에서는 HUD만으로도 충분하므로 필수 아님.

---

## 7. 공격/채굴 프리뷰 변경

대상 파일:

```text
scenes/player/Player.gd
```

캐릭터 스프라이트는 제외하지만, 공격/채굴 프리뷰는 레퍼런스 스타일로 바꾼다.

현재:

```text
공격 프리뷰 polygon fill + outline
채굴 프리뷰 polygon fill + outline
```

목표:

```text
면 채우기를 최소화하고, 얇은 네온 outline + 짧은 잔상으로 표현한다.
```

### 7-1. 공격 프리뷰

`attack_visual_time > 0.0`일 때:

```text
- polygon fill alpha를 0.06~0.10으로 줄임
- 외곽선은 빨강/주황 2px
- 진행 방향 중심선 1개 추가
- 끝점에 작은 spark 1개
```

### 7-2. 채굴 프리뷰

`mining_visual_time > 0.0`일 때:

```text
- polygon fill alpha 0.05 이하
- 외곽선 노란색 2px
- 앞쪽 edge에 밝은 노란 선
- 타격 방향으로 작은 점 2~3개
```

채굴은 벽/모래와 상호작용하는 핵심 피드백이므로 공격보다 노란색을 더 명확하게 쓴다.

---

## 8. 공격모듈 visual/이펙트 방향

이번 md의 1차 목표는 월드 스타일 적용이지만, 이후 공격모듈 이펙트와 충돌하지 않도록 기준을 둔다.

현재 `AttackModuleStyleResolver.gd`에는 아래 스타일이 있다.

```text
melee: slash, stab, pierce, cleave, smash
ranged: rifle, shotgun, sniper, laser, revolver
```

각 `effect_style`은 아래처럼 보이도록 한다.

```text
slash_arc        : 짧은 곡선 arc, 주황/흰색, 0.10초
short_stab       : 짧은 직선 찌르기, 흰색 중심선 + 노란 끝점
long_pierce      : 긴 얇은 선, 시안/흰색, 관통 느낌
big_cleave       : 큰 반원 arc, 붉은/주황 잔상
blunt_smash      : 원형 충격파 + 점 파편
rifle_projectile : 작은 시안/흰색 탄환 + 짧은 trail
shotgun_spread   : 작은 점 3~5개 + 짧은 분산 trail
sniper_projectile: 긴 얇은 선 + 강한 impact flash
laser_beam       : 즉시 히트스캔 직선 + 짧은 glow
revolver_projectile: 짧고 굵은 탄환 + 노란 muzzle flash
```

새 아트 에셋을 추가하지 말고, `Line2D`, `_draw()`, `CPUParticles2D`, 짧은 lifetime Node2D로 처리한다.

---

## 9. HUD/UI 톤 조정

대상 파일:

```text
scenes/ui/HUD.gd
```

현재 HUD는 이미 코드 기반 `Control`/`Label`/`ProgressBar`/`Panel` 조합이다. 이 구조는 유지한다.

목표:

```text
어두운 반투명 패널
얇은 회색/시안 border
큰 숫자 고대비
위험 구간은 빨강/노랑 pulse
센서 HUD는 레퍼런스처럼 미니멀 스캔 패널 느낌
```

### 9-1. 패널 스타일

`StyleBoxFlat` 생성 시 아래 기준을 사용한다.

```text
bg_color: rgba(0.03, 0.06, 0.09, 0.80~0.90)
border_color: #334250 또는 상태별 네온 색
border_width: 1~2
corner_radius: 8~12
```

### 9-2. ProgressBar

진행바 배경은 거의 검정.
fill 색상은 역할별 고정.

```text
Time: amber, 10초 이하 red
HP: green, 30% 이하 red
Battery: cyan, 30% 이하 orange
Weight: safe green -> slow amber -> crush orange -> danger red
XP: cyan 또는 purple
```

fill이 바뀔 때 단순 변경만 하지 말고 가능하면 짧은 Tween 또는 label pulse를 준다. 단, 1차 구현에서 Tween이 부담되면 색상 통일만 먼저 한다.

### 9-3. 센서 HUD

`SeismicSensorDraw`는 레퍼런스와 잘 맞는 영역이다.

변경 방향:

```text
- 배경: 어두운 패널
- viewport box: 노란 얇은 outline
- falling block: 네온 사각 outline 또는 짧은 bar
- player: 시안 점 + 작은 glow 원
- 모래/중량 정보는 필요시 노란 점 밀도 느낌
```

---

## 10. 파일별 작업 지시

### 10-1. `GameConstants.gd`

추가:

```text
Neon art palette 상수
필요하면 helper color 함수
```

주의:

```text
기존 게임플레이 수치 변경 금지
```

### 10-2. `WorldGrid.gd`

변경:

```text
_draw()의 벽 전체 단색 렌더링을 얇은 라인 중심 렌더링으로 변경
1U wall cell 렌더링을 tile/shake/chip particle 느낌으로 변경
중앙 전장 경계선 강조
채굴 손상 셀 노란 균열 표시
```

선택 추가:

```text
_mining_spark_events 구현
```

### 10-3. `FallingBlock.gd`

변경:

```text
면 채우기 block rendering 제거 또는 대폭 약화
네온 외곽선 + 가짜 glow + 코너 하이라이트 구현
피격 flash timer 추가
```

### 10-4. `SandField.gd`

변경:

```text
모래 사각형 fill을 점 렌더링으로 변경
surface cell 밝기 강조
stable/unstable 색상 차이
```

### 10-5. `Player.gd`

변경:

```text
공격/채굴 preview fill alpha 축소
outline/center line/spark 중심으로 변경
대시 trail 색상은 cyan 계열 유지
```

금지:

```text
캐릭터 sprite 변경
충돌 rect 변경
PLAYER_SIZE 변경
```

### 10-6. `HUD.gd`

변경:

```text
HUD StyleBox 색상 통일
센서 HUD 미니멀 네온 스타일로 정리
스킬 슬롯 border/fill 색상 레퍼런스 톤으로 변경
```

---

## 11. 구현 우선순위

한 번에 모든 것을 바꾸지 말고 아래 순서로 진행한다.

```text
1. 팔레트 상수 추가
2. WorldGrid 벽/중앙 샤프트 렌더링 변경
3. FallingBlock 네온 외곽선 렌더링 변경
4. SandField 점 입자 렌더링 변경
5. Player 공격/채굴 프리뷰 변경
6. HUD 톤 정리
7. 채굴 스파크 이벤트 추가
8. 피격 flash/파괴 파편 추가
```

1~4까지만 완료되어도 레퍼런스와 화면 인상이 크게 가까워져야 한다.

---

## 12. 시각 검수 기준

작업 후 반드시 아래 기준으로 확인한다.

### 12-1. 전체 화면

```text
- 화면을 처음 봤을 때 암흑 수직 샤프트 느낌이 나는가?
- 좌우 벽이 단색 덩어리가 아니라 얇은 구조물처럼 보이는가?
- 중앙 전장 10U 폭이 명확히 읽히는가?
- 블록이 네온 외곽선으로 보이는가?
- 모래가 노란 점 군집처럼 보이는가?
```

### 12-2. 게임플레이 가독성

```text
- 블록의 위치/크기가 기존보다 읽기 어려워지지 않았는가?
- 모래가 얼마나 쌓였는지 읽히는가?
- 채굴 가능한 벽과 손상된 벽이 구분되는가?
- 공격/채굴 범위가 너무 희미하지 않은가?
- 위험 상태 빨강/노랑이 충분히 강한가?
```

### 12-3. 성능

```text
- SandField에서 셀마다 과한 glow를 그리지 않았는가?
- WorldGrid에서 모든 벽 서브셀을 매 프레임 과도하게 그리지 않았는가?
- _draw()에 매번 랜덤을 사용하지 않았는가?
- 파티클/이벤트 lifetime이 짧게 정리되는가?
```

---

## 13. 금지 사항

아래는 하지 않는다.

```text
- 플레이어 캐릭터 스프라이트 교체
- 캐릭터 크기/충돌박스 변경
- 월드 1U 크기 변경
- 중앙 전장 10U 폭 변경
- 벽/모래/블록 판정 로직 변경
- 새 텍스처 대량 추가
- 모든 셀에 고비용 glow/shader 적용
- 랜덤 기반으로 매 프레임 다른 벽 균열 표시
- 블록 내부를 밝은 색으로 꽉 채우기
- 벽을 기존처럼 단색 덩어리로 유지하기
```

---

## 14. 완료 조건

작업 완료 판단 기준:

```text
- `references/burial_protocol_neon_minimal_wall_reference.svg`와 비교했을 때 월드 분위기가 명확히 유사함
- 중앙 샤프트/좌우 벽/네온 블록/노란 모래/채굴 스파크 방향성이 반영됨
- 캐릭터 스프라이트는 변경되지 않음
- 기존 이동/공격/채굴/모래/블록 충돌 동작이 유지됨
- Day 진행, 블록 낙하, 모래 생성, 채굴, 공격, HUD 표시가 정상 동작함
```

---

## 15. Codex 작업 요청 요약

Codex는 아래 목표로 작업한다.

```text
레퍼런스 `references/burial_protocol_neon_minimal_wall_reference.svg`를 기준으로,
캐릭터 스프라이트를 제외한 인게임 월드 비주얼을 네온 미니멀 스타일로 변경한다.

핵심 변경 대상은 WorldGrid, FallingBlock, SandField, Player의 공격/채굴 프리뷰, HUD다.
게임플레이 판정과 수치는 변경하지 않는다.
새 이미지 에셋을 대량 추가하지 말고 Godot의 draw/Control/StyleBox/Line/짧은 이벤트 기반 이펙트로 구현한다.
```

## Current Visual Implementation Snapshot - 2026-05-25

This section records the current visual implementation after the UI/gameplay pass.

### Mining And Wall Visuals

- Mining preview range boxes are disabled.
- Continuous drill visual is active while right-click is held and a mineable target exists.
- Drill texture: `assets/characters/drill.png`.
- Wall block texture: `assets/world/walls/wall_brick_normal.png`.
- Wall glow texture: `assets/world/walls/wall_brick_glow.png`.
- Wall chip particle texture: `assets/world/walls/wall_brick_normal_shard.png`.
- Wall cell rendering is 1U-based, not subcell-based.
- Wall hit shake is visual-only.
- Wall chip particles use actual shard sprites rather than colored rects.

### Attack Module Visuals

- Attack-module orbit visuals use asset sprites instead of placeholder shapes when textures exist.
- Each module combines a grade slot ring with a weapon sprite.
- Slot rings are grade-colored and shared across all modules.
- Weapon sprites keep their own color; grade color must not recolor the weapon.
- Slot target size is `64 x 64` for every module.
- Weapon target sizes vary by weapon silhouette.
- Orbit radius is `64px`.
- Alpha is `70%` to reduce player occlusion.
- The visual layer is independent of attack hit shapes and projectile collision.
