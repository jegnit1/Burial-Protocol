# AGENTS.md

이 문서는 Codex/AI Agent가 이 프로젝트에서 작업할 때 반드시 따라야 하는 작업 원칙을 정의한다.

현재 프로젝트는 초기 기능 구현을 빠르게 진행하기 위해 벽, 블록, 투사체, 무기 비주얼, 일부 UI/피드백 요소를 코드 기반 `_draw()` 또는 런타임 생성 방식으로 처리하고 있다.

하지만 앞으로 남은 주요 작업은 기능 구현보다 다음 항목의 비중이 크다.

- 적절한 에셋 선정 및 적용
- 픽셀아트/스프라이트 기반 비주얼 개선
- UI 레이아웃 및 HUD 개선
- 애니메이션 프레임 구성 및 최적화
- Godot 에디터에서 직접 보고 조정 가능한 씬 구조 정리
- 무기/공격모듈/투사체/VFX의 에셋 기반 제작 파이프라인 정리

따라서 Codex는 기존의 “코드로 도형을 그려서 임시 표현하는 구조”를 점진적으로 “에셋 기반으로 교체 가능한 구조”로 리팩토링하는 방향을 우선해야 한다.

---

## 1. 핵심 작업 원칙

이번 프로젝트의 장기 방향은 기능 구현 중심의 임시 코드 비주얼에서 벗어나, 에셋 기반 제작 파이프라인으로 전환하는 것이다.

Codex는 앞으로 다음 흐름을 기본으로 삼는다.

```text
요청 분석
→ 에셋 필요 여부 판단
→ 에셋이 없으면 사용자에게 필요한 에셋과 Godot 에디터 작업 절차 안내
→ 에셋이 있으면 씬/데이터/코드 연결
→ fallback/debug 코드만 최소 유지
```

코드로 임시 도형을 그려서 “완성된 것처럼” 처리하지 않는다.

특히 아래 항목은 최종적으로 에셋 기반 구조가 되어야 한다.

- 무기
- 공격모듈
- 투사체
- VFX
- UI/HUD
- 상점/카드 UI
- 벽돌/타일
- 낙하 블록 외형
- 캐릭터 애니메이션

---

## 2. 에셋 우선 판단 규칙

앞으로 다음 유형의 요청은 무조건 “에셋 필요 여부”를 먼저 판단한다.

- 캐릭터 외형 개선
- 무기 외형 개선
- 공격모듈 외형 개선
- 투사체/VFX 개선
- UI/HUD/상점/카드 디자인 개선
- 애니메이션 개선
- 배경/벽/블록/타일 시각 개선
- 픽셀아트 품질 개선
- 게임 화면의 보기 좋음, 타격감, 연출감 개선

Codex는 위 작업에서 필요한 에셋이 없을 경우, 코드를 억지로 작성해서 가짜 아트를 만들지 않는다.

대신 반드시 사용자에게 아래 형식으로 알린다.

```text
이 작업은 코드만으로 처리하면 품질 한계가 큽니다.
먼저 아래 에셋이 필요합니다.

필요 에셋:
1. ...
2. ...
3. ...

권장 파일 위치:
- assets/...

권장 해상도:
- ...

Godot 에디터 작업 절차:
1. ...
2. ...
3. ...

에셋이 준비되면 그 다음 단계에서 연결 코드와 씬 구조를 수정하겠습니다.
```

---

## 3. Godot 에디터 절차 안내 규칙

Codex는 앞으로 코드 수정만 제안하지 않는다.

Godot 에디터에서 사용자가 직접 해야 하는 작업이 있다면 반드시 절차를 제공한다.

절차에는 가능한 한 아래 내용을 포함한다.

- 어떤 `.tscn` 파일을 열어야 하는지
- 어떤 노드를 추가해야 하는지
- 어떤 노드 이름을 써야 하는지
- Inspector에서 어떤 속성을 설정해야 하는지
- 어떤 텍스처/스프라이트를 어디에 넣어야 하는지
- Marker2D 위치를 어떻게 잡아야 하는지
- AnimationPlayer 또는 AnimatedSprite2D 프레임을 어떻게 구성해야 하는지
- 충돌 영역과 비주얼 영역이 다를 때 어떤 기준으로 맞춰야 하는지
- 저장 후 어떤 씬을 실행해서 확인해야 하는지

출력 형식 예시:

```text
Godot 에디터 작업 절차

1. `scenes/player/modules/SwordModuleVisual.tscn` 열기
2. 루트 `Node2D` 아래에 `Sprite2D` 추가
3. 노드 이름을 `Sprite2D`로 설정
4. Inspector > Texture에 `assets/weapons/sword.png` 지정
5. 루트 기준 검 끝이 +X 방향을 향하도록 이미지 피벗 조정
6. `Marker2D` 추가 후 이름을 `HitPoint`로 변경
7. `HitPoint.position`을 검 끝 위치로 이동
8. 씬 저장
9. `Main.tscn` 실행 후 공격모듈 장착 상태에서 위치 확인
```

---

## 4. 현재 코드 기반 비주얼 인식

현재 프로젝트에는 아래와 같은 코드 기반 비주얼 구조가 존재한다.

### 4-1. `WorldGrid.gd`

- 벽, 바닥, 배경을 `_draw()`의 `draw_rect()`로 직접 그림
- 벽돌/타일이 Godot 에디터에서 개별 노드나 TileMap으로 보이지 않음
- 채굴/충돌/모래화 같은 논리 그리드와 시각 표현이 강하게 결합되어 있음

### 4-2. `FallingBlock.gd`

- `block_data` 기반으로 `_draw()`에서 사각형 블록을 직접 그림
- `Sprite2D` 기반 블록 에셋 구조가 아님
- `block_data == null`인 에디터 상태에서는 시각 확인이 어렵다

### 4-3. `AttackModuleVisual.gd`

- sword, dagger, lance, axe, greatsword, drone 등의 무기 모양을 `_draw()` 함수로 직접 그림
- 실제 무기 스프라이트/애니메이션 에셋 기반 구조가 아님
- 이 구조는 임시 도형 표현으로 간주한다

### 4-4. `AttackModuleProjectile.gd`

- 투사체를 `_draw()`의 사각형과 trail로 직접 그림
- 투사체 스프라이트/VFX/파티클 에셋 기반 구조가 아님

### 4-5. `Player.gd`

- 캐릭터 본체는 `AnimatedSprite2D` 기반
- 공격 범위/채굴 범위/시각 피드백 일부는 `_draw()` 기반
- 공격모듈 비주얼은 장착 데이터 기반으로 런타임에 생성됨

---

## 5. 코드 기반 비주얼 분류 기준

Codex는 `_draw()`, `draw_rect`, `draw_line`, `draw_circle`, `draw_colored_polygon` 사용 위치를 조사할 때 아래 기준으로 분류한다.

```text
A. 반드시 에셋 기반으로 전환해야 하는 항목
B. 코드 기반 유지가 합리적인 디버그/임시 시각화 항목
C. 에셋 기반 전환 가능하지만 우선순위가 낮은 항목
D. Godot 에디터 작업 절차가 필요한 항목
```

기본 판단 기준은 다음과 같다.

- 최종 게임 화면에 계속 노출되는 비주얼이면 에셋 기반 전환 우선
- 디버그 박스, 충돌 확인, 임시 preview는 코드 기반 유지 가능
- 사용자가 아트 감각으로 조정해야 하는 요소는 Godot 에디터 절차 필요
- 없는 에셋을 코드로 가짜 제작하지 말고 필요한 에셋 목록을 먼저 요구

---

## 6. 무기 / 공격모듈 비주얼 전환 원칙

현재 `AttackModuleVisual.gd`의 `_draw_sword()`, `_draw_dagger()`, `_draw_lance()`, `_draw_axe()`, `_draw_greatsword()`, `_draw_drone()` 방식은 임시 도형 표현이다.

권장 구조:

```text
scenes/player/modules/
├─ AttackModuleVisualBase.gd
├─ SwordModuleVisual.tscn
├─ DaggerModuleVisual.tscn
├─ LanceModuleVisual.tscn
├─ AxeModuleVisual.tscn
├─ GreatswordModuleVisual.tscn
└─ DroneModuleVisual.tscn
```

각 무기 시각 씬은 가능하면 다음 노드 구조를 갖는다.

```text
WeaponVisual : Node2D
├─ Sprite2D 또는 AnimatedSprite2D
├─ MuzzlePoint 또는 HitPoint : Marker2D
└─ OptionalEffectRoot : Node2D
```

규칙:

- 실제 스프라이트 에셋이 없는 경우 임시 placeholder Sprite2D를 만들지 않는다.
- 필요한 에셋 목록을 문서 또는 작업 보고에 남긴다.
- 기존 `_draw()` 도형은 fallback 또는 debug preview로만 남긴다.
- 새 구조는 추후 에셋을 넣으면 Godot 에디터에서 바로 확인 가능해야 한다.
- 무기별 발사 위치, 회전축, 피벗 위치는 Marker2D로 조정 가능하게 한다.

---

## 7. 투사체 비주얼 전환 원칙

현재 `AttackModuleProjectile.gd`의 `_draw()` 기반 탄환 표현은 임시로 간주한다.

권장 구조:

```text
scenes/projectiles/
├─ AttackModuleProjectile.tscn
├─ AttackModuleProjectile.gd
├─ ProjectileVisualBase.gd
├─ BulletProjectileVisual.tscn
├─ BeamProjectileVisual.tscn
├─ ShardProjectileVisual.tscn
└─ ExplosionProjectileVisual.tscn
```

투사체는 다음 구조를 지향한다.

```text
Projectile : Node2D
├─ Sprite2D 또는 AnimatedSprite2D
├─ TrailRoot : Node2D / GPUParticles2D
└─ HitEffectSpawnPoint : Marker2D
```

규칙:

- 충돌/데미지 로직과 시각 표현을 분리한다.
- 투사체 이동, 관통, 유도, 수명 같은 로직은 기존대로 유지한다.
- 시각 표현은 `effect_style` 또는 데이터 정의에서 선택 가능하게 한다.
- 에셋이 없으면 필요한 에셋 사양을 문서화하고 코드로 억지 제작하지 않는다.

---

## 8. 블록 / 벽 / 벽돌 전환 원칙

현재 `WorldGrid.gd`의 벽/바닥 표현은 `_draw()` 기반이다.

이를 즉시 전면 교체하지 말고, 다음 두 단계를 구분한다.

1. 현재 기능 유지용 논리 그리드
2. 에셋 기반 시각 레이어

권장 구조:

```text
WorldGrid : Node2D
├─ LogicalGridRoot
├─ WallVisualLayer : Node2D 또는 TileMapLayer
├─ FloorVisualLayer : Node2D 또는 TileMapLayer
└─ DebugDrawLayer : Node2D
```

규칙:

- 채굴/충돌/모래화 같은 기존 논리는 유지한다.
- 벽돌 비주얼은 추후 TileSet 또는 Sprite 기반으로 교체 가능하게 한다.
- 손상된 벽돌 표현은 코드 색상 보간만으로 고정하지 않는다.
- 추후 damage stage sprite를 적용할 수 있게 구조를 분리한다.
- 실제 벽돌 타일 에셋이 없으면 필요한 TileSet 사양을 문서화한다.

예시 필요 에셋:

```text
assets/world/tiles/wall_full.png
assets/world/tiles/wall_damaged_01.png
assets/world/tiles/wall_damaged_02.png
assets/world/tiles/wall_damaged_03.png
assets/world/tiles/wall_empty.png
assets/world/tiles/floor.png
```

---

## 9. 떨어지는 블록 전환 원칙

현재 `FallingBlock.gd`는 `block_data.block_base_color`로 사각형을 그린다.

권장 구조:

```text
FallingBlock : Area2D
├─ Sprite2D 또는 AnimatedSprite2D
├─ CollisionShape2D
├─ HpBarRoot
└─ DamageEffectRoot
```

규칙:

- 블록의 논리 크기와 시각 스프라이트 크기를 분리한다.
- `BlockData`에는 `visual_scene_path`, `sprite_path`, `damage_stage_sprites` 같은 확장 가능 필드를 고려한다.
- 에셋이 없으면 임시 사각형 `_draw()`를 fallback으로 유지하되, 문서상으로는 임시 처리임을 명시한다.

---

## 10. UI / HUD 전환 원칙

HUD/UI 구조를 조사하고, 코드 중심 배치 또는 임시 스타일이 있다면 에셋 기반 UI로 전환 가능한 구조를 제안한다.

권장 구조:

```text
scenes/ui/
├─ HUD.tscn
├─ PlayerStatusPanel.tscn
├─ WeaponSlotPanel.tscn
├─ ShopPanel.tscn
├─ CardView.tscn
└─ Common/
   ├─ PixelPanel.tscn
   ├─ PixelButton.tscn
   └─ IconLabel.tscn
```

규칙:

- UI는 가능하면 Godot Control 노드 기반으로 구성한다.
- 패널 배경은 추후 NinePatchRect 또는 TextureRect로 교체 가능하게 한다.
- 버튼, 카드, 슬롯, 게이지 등 반복 요소는 재사용 씬으로 분리한다.
- 아이콘 에셋이 필요한 경우 필요한 크기와 형식을 문서화한다.

---

## 11. 코드 수정 원칙

리팩토링 시 아래 원칙을 지킨다.

- 기존 플레이 가능한 기능을 깨지 않는다.
- 한 번에 전부 갈아엎지 말고, fallback 구조를 유지한다.
- `_draw()` 기반 임시 비주얼은 바로 삭제하지 말고 `debug/fallback` 용도로 격하한다.
- 신규 에셋 기반 구조를 먼저 추가한 뒤, 데이터에서 해당 visual path를 참조하도록 한다.
- 에셋 파일이 없는 경우 빈 경로를 억지로 만들지 않는다.
- 없는 에셋을 참조하는 코드를 커밋하지 않는다.
- 에셋 누락 시 warning을 출력하되 게임이 죽지 않게 한다.
- 씬 구조 변경 후 기존 데이터/세이브/상점/장착 시스템과 연결이 유지되는지 확인한다.
- 사용자가 직접 해야 하는 에디터 작업과 Codex가 처리할 코드 작업을 명확히 분리한다.

---

## 12. 작업 완료 보고 형식

작업 완료 후 아래 형식으로 보고한다.

```text
## 완료 내용

- 수정/생성한 파일 목록
- 코드 기반 비주얼 조사 결과
- 에셋 기반 구조로 전환한 항목
- 아직 에셋이 없어 보류한 항목

## Godot 에디터에서 사용자가 해야 할 작업

1. ...
2. ...
3. ...

## 필요한 에셋 목록

| 구분 | 파일명 | 권장 위치 | 권장 크기 | 설명 |
|---|---|---|---|---|

## 다음 추천 작업

- ...
```

---

## 13. 금지 사항

Codex는 다음을 피한다.

- 없는 에셋을 있다고 가정하고 참조 코드 작성
- 코드 도형으로 임시 그림을 만든 뒤 최종 구현처럼 보고
- Godot 에디터에서 해야 할 작업을 생략하고 코드만 제시
- Sprite2D, Marker2D, AnimationPlayer, CollisionShape2D 조정 절차 없이 시각 개선 완료 처리
- 최종 게임 화면용 아트를 `_draw()`만으로 계속 확장
- 사용자의 명시 없이 기존 플레이 가능한 로직을 대규모로 갈아엎기

---

## 14. 권장 후속 문서

필요 시 아래 문서를 추가로 생성한다.

```text
docs/asset_pipeline.md
docs/godot_editor_workflow.md
docs/visual_refactor_plan.md
```

각 문서 역할:

```text
asset_pipeline.md
- 에셋 폴더 구조
- 파일명 규칙
- 픽셀아트 해상도 규칙
- 무기/투사체/UI/타일 에셋 사양

godot_editor_workflow.md
- Godot 에디터에서 씬을 열고 Sprite2D/AnimatedSprite2D/Marker2D/CollisionShape2D를 설정하는 절차

visual_refactor_plan.md
- 현재 코드 기반 비주얼 목록
- 에셋 기반 전환 우선순위
- 단계별 리팩토링 계획
```
