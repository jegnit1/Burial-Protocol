# Burial Protocol 캐릭터 장비 시스템 전면 개편 지시

현재 Burial Protocol의 기존 공격모듈 시스템을 전면 개편한다.

기존 구조:

- 공격모듈 최대 5개 장착
- `melee`, `ranged`, `mechanic` 타입
- 근거리 공격력 / 원거리 공격력 분리
- 공격모듈이 플레이어 주변을 공전하며 각자 발동

신규 구조:

- 무기 2개
- 드론 1개
- 드론 프로토콜 5개
- 패시브 모듈 5개

이번 작업은 단순 리네이밍이 아니라 장비 슬롯, 데이터 구조, 스탯 이름, 상점 카테고리, HUD/스탯 패널, 전투 발동 구조를 새 기준으로 재정의하는 작업이다.

## 1. 신규 장비 구분

### 1-1. 무기

무기는 플레이어의 좌클릭 기반 평타 장비다.

규칙:

- 무기는 좌측 무기 슬롯과 우측 무기 슬롯으로 구분한다.
- 최대 2개 장착 가능하다.
- 캐릭터의 기본 무기값에 따라 게임 시작 시 기본 무기 1개를 장착한다.
- 기본 무기는 우선 좌측 무기 슬롯에 장착한다.
- 우측 무기 슬롯은 기본적으로 비어 있을 수 있다.
- 좌클릭 입력 시 장착된 모든 무기가 각자의 쿨타임에 따라 발사된다.
- 좌측/우측 무기는 입력 버튼 구분이 아니라 시각적/장착 슬롯 구분이다.
- 우클릭은 기존처럼 채굴 입력으로 유지한다.

무기 등급:

- D
- C
- B
- A
- S

무기 예시:

- 캐논볼: 기본적인 투사체를 발사한다.
- 테이저건: 번개 스파크를 발사하며 3회 연쇄한다.
- 레이저: 적을 관통하는 레이저를 발사한다.
- 로켓: 적중 시 폭발하는 미사일을 발사한다.

### 1-2. 드론

드론은 플레이어 근처에 부유하는 자동 지원 로봇이다.

규칙:

- 드론 자체에는 등급을 구현하지 않는다.
- 현재는 아무 능력 없는 기본 드론을 기본값으로 둔다.
- 드론은 프로토콜을 실행하는 주체다.
- 드론은 캐릭터 키보다 높은 위치에서 부유한다.
- 드론의 종류는 추후 확장 가능하지만, 이번 작업에서는 기본 드론만 기준으로 한다.

### 1-3. 프로토콜

프로토콜은 드론에 장착되는 자동 행동 장비다.

규칙:

- 드론은 프로토콜을 최대 5개 장착한다.
- 서로 다른 프로토콜 5개를 장착하면 5개의 기능이 각각 동작한다.
- 동일 프로토콜을 여러 개 중복 장착할 수 있다.
- 예: 청소 프로토콜 5개 장착 가능.
- 프로토콜은 일정 시간마다 특정 동작을 자동 수행한다.
- 프로토콜은 선택한 종류에 따라 전투 지원, 자동 공격, 회복, 배터리 회복, 모래 처리 등의 역할을 수행한다.

프로토콜 등급:

- D
- C
- B
- A
- S

프로토콜 수치 규칙:

- 프로토콜은 `n초마다 m회 수행`, `n초마다 m만큼 회복`, `n초마다 드론 공격력의 m% 데미지` 같은 구조로 정의한다.
- 등급이 높을수록 `n`은 줄어들거나, `m`은 증가한다.
- 드론 쿨타임 감소 스탯은 모든 프로토콜 쿨타임에 적용된다.

프로토콜 예시:

- 청소 프로토콜: [보조] 5초마다 필드의 모래를 1개 제거한다.
- 치유 프로토콜: [보조] 5초마다 플레이어 체력을 2 회복한다.
- 보조배터리 프로토콜: [보조] 5초마다 플레이어 배터리를 5 회복한다.
- 채굴 프로토콜: [보조] 10초마다 가까운 벽 블록 하나를 채굴하며, 채굴 데미지의 영향을 받는다.
- 사격 프로토콜: [투사체] 1초마다 가까운 블록을 향해 공격한다.
- 독가스 프로토콜: [영역] 5초마다 3초간 유지되는 독가스를 일정 영역에 생성한다.

### 1-4. 패시브 모듈

모듈은 무기/프로토콜에 추가 효과를 부여하는 패시브 장비다.

규칙:

- 최대 5개 장착 가능하다.
- 기본값은 아무것도 장착되어 있지 않다.
- 모듈은 직접 공격하지 않는다.
- 모듈은 무기와 프로토콜의 속성/유형/스탯/발동 방식에 패시브 효과를 부여한다.
- 같은 모듈명에도 여러 등급이 존재할 수 있다.
- 특정 모듈은 특정 등급 이상만 존재할 수 있다.
- 특정 모듈은 `{중복 적용 불가}` 속성을 가질 수 있다.
- `{중복 적용 불가}` 모듈은 같은 효과를 여러 번 적용하지 않는다.

모듈 등급:

- D
- C
- B
- A
- S

모듈 예시:

- 광선 이중화: [광선] 타입 장비가 2갈래로 발사된다. {중복 적용 불가}
- 연쇄 보조 모듈: [연쇄]가 1회 더 발생한다.
- 폭발 전문화 모듈: [폭발] 반경이 1칸 증가한다.
- 화염 특화 모듈: 장착한 [화염] 장비가 5개 이상인 경우, 무기 공격력이 100% 상승한다. {중복 적용 불가}
- 방사능 모듈: [화학] 피해가 20% 증가한다.
- 더블샷 모듈: [투사체] 공격이 2번 발사된다. {중복 적용 불가}

## 2. 속성 / 유형 체계

모든 무기와 공격형 프로토콜은 `속성(attribute)`과 `유형(attack_type)`을 가진다.

보조 프로토콜은 공격 장비가 아닐 수 있으므로 `attribute = none`을 허용한다.

### 2-1. 속성

속성 종류:

- 전기: 번개, 스파크, 연쇄 공격
- 화염: 지속 피해, 열, 연소
- 물리: 베기, 커터, 회전날, 칼날
- 에너지: 빔, 레이저, 플라즈마
- 화학: 산성, 독성, 부식
- none: 보조/비공격 프로토콜용

예시:

- 전기: 테이저건, 체인 라이트닝
- 화염: 화염방사기, 인페르노 코어
- 물리: 커터 프로토콜, 절단 프로토콜, 톱날
- 에너지: 레이저, 플라즈마 캐논, 이온 빔
- 화학: 산성탄, 부식 미스트

### 2-2. 유형

유형 종류:

- 보조: 치유, 모래처리, 배터리 회복, 자동 채굴
- 투사체: 탄환, 포탄, 에너지볼
- 영역: 일정 범위에 지속 피해 효과
- 광선: 직선 빔, 레이저, 열선
- 연쇄: 대상에서 대상으로 전이
- 폭발: 적중 지점 주변 범위 피해

예시:

- 보조: 청소 프로토콜, 회복 프로토콜
- 투사체: 사격 프로토콜, 캐논볼
- 영역: 화염지대, 전기장, 톱날 링, 부식 구름
- 광선: 레이저, 이온 빔
- 연쇄: 테이저건, 체인 라이트닝
- 폭발: 로켓, 폭발탄

## 3. 스탯 개편

기존 스탯 중 아래 개념을 제거한다.

- 근거리 공격력
- 원거리 공격력

신규 스탯:

- 무기 공격력
- 드론 공격력
- 공격속도
- 드론 쿨타임 감소

규칙:

- 무기 공격력은 무기 데미지에 적용된다.
- 드론 공격력은 공격형 프로토콜의 데미지에 적용된다.
- 공격속도는 무기의 공격 쿨타임을 줄인다.
- 드론 쿨타임 감소는 모든 프로토콜의 쿨타임을 줄인다.
- 드론 쿨타임 감소는 희귀 스탯으로 취급한다.
- 드론 쿨타임 감소는 레벨업 선택지에서 기본 제공하지 않는다.
- 드론 쿨타임 감소는 상점 아이템, 특수 모듈, 보물상자 보상 등 제한된 경로에서만 제공한다.

레벨업 카드 변경:

- 기존 `melee_atk_up` 제거 또는 비활성화
- 기존 `ranged_atk_up` 제거 또는 비활성화
- 신규 `weapon_attack_up` 추가
- 신규 `drone_attack_up` 추가
- `drone_cooldown_reduction_up`은 레벨업 카드 풀에 넣지 않는다.

스탯 패널 변경:

- 근거리 공격력 표시 제거
- 원거리 공격력 표시 제거
- 무기 공격력 표시 추가
- 드론 공격력 표시 추가
- 드론 쿨타임 감소 표시 추가
- 공격속도는 무기 공격속도 의미로 표시한다.

## 4. 데이터 구조 개편 방향

기존 `attack_module` 중심 구조를 아래 구조로 재정의한다.

신규 장비 카테고리:

- `weapon`
- `drone`
- `drone_protocol`
- `passive_module`

기존 카테고리 대응:

- 기존 `attack_module` 중 좌클릭 기반 공격 장비는 `weapon`으로 마이그레이션한다.
- 기존 `mechanic`/drone 계열 아이디어는 `drone_protocol`로 마이그레이션한다.
- 기존 `function_module`, `enhance_module` 중 패시브 효과 장비는 `passive_module`로 마이그레이션한다.
- 기존 상점 시스템의 구매/가격/랭크/lock/reroll 흐름은 유지하되, 카테고리만 신규 체계에 맞춘다.

권장 신규 필드:

- `equipment_id`
- `equipment_category`
- `rank`
- `price_gold`
- `shop_enabled`
- `shop_spawn_weight`
- `default_start_equipment`
- `attribute`
- `attack_type`
- `base_damage_by_grade`
- `base_cooldown_by_grade`
- `weapon_slot`
- `protocol_cooldown`
- `protocol_duration`
- `protocol_tick_count`
- `protocol_value_by_grade`
- `unique_effect`
- `non_stackable`
- `conditions`
- `effects`
- `apply_timing`
- `icon_path`
- `world_visual_scene_path`
- `tags`

주의:

- 콘텐츠 데이터는 가능하면 `.tres`와 TSV 파이프라인 기준으로 관리한다.
- `GameConstants.gd`에 무기/프로토콜/모듈 콘텐츠 테이블을 직접 넣지 않는다.
- 기존 `ShopItemDefinition.gd`를 확장할지, 신규 `EquipmentDefinition.gd`를 만들지는 현재 코드 구조를 확인한 뒤 결정한다.
- 단, 장기적으로는 `ShopItemDefinition`이 너무 공격모듈 중심이면 `EquipmentDefinition` 또는 범용 장비 정의로 분리하는 방향이 바람직하다.

## 5. 상태 구조 개편 방향

`GameState.gd`는 신규 장비 장착 상태를 소유한다.

기존 상태:

- `equipped_attack_modules`
- `owned_attack_module_ids`
- `run_bonus_melee_attack_damage`
- `run_bonus_ranged_attack_damage`
- `attack_module_runtime_state`

신규 권장 상태:

- `equipped_weapon_left`
- `equipped_weapon_right`
- `owned_weapon_ids`
- `equipped_drone_id`
- `equipped_drone_protocols`
- `owned_drone_protocol_ids`
- `equipped_passive_modules`
- `owned_passive_module_ids`
- `weapon_runtime_state`
- `drone_protocol_runtime_state`
- `run_bonus_weapon_attack_damage`
- `run_bonus_drone_attack_damage`
- `run_weapon_attack_speed_mult`
- `run_drone_cooldown_reduction`
- `run_attack_range_mult`
- `run_bonus_crit_chance`

`Player.gd`는 순간 동작 상태를 소유한다.

- 무기별 쿨타임
- 프로토콜별 쿨타임
- 무기 시각 위치
- 드론 부유 위치
- 프로토콜 실행 타이밍
- 공격/투사체/레이저/영역 생성

## 6. 발동 구조

### 6-1. 무기 발동

- 좌클릭 입력 중 또는 좌클릭 입력 시 장착된 무기들이 공격한다.
- 좌측 무기와 우측 무기는 각각 독립 쿨타임을 가진다.
- 공격속도 스탯은 무기 쿨타임을 감소시킨다.
- 무기 데미지는 무기 기본 데미지 + 무기 공격력 + 전역 데미지 배율을 기준으로 계산한다.
- 치명타는 무기 공격에 적용한다.

권장 공식:

```text
weapon_damage =
  floor((weapon_grade_base_damage + weapon_attack_damage_flat)
  x global_damage_multiplier
  x attribute/type/module multipliers)
```

권장 쿨타임:

```text
weapon_cooldown =
  weapon_base_cooldown
  / weapon_attack_speed_multiplier
  / grade_speed_multiplier
  / run_weapon_attack_speed_mult
```

### 6-2. 프로토콜 발동

- 프로토콜은 드론이 자동으로 수행한다.
- 각 프로토콜은 독립 쿨타임을 가진다.
- 동일 프로토콜을 여러 개 장착하면 각각 독립적으로 동작한다.
- 드론 쿨타임 감소는 모든 프로토콜 쿨타임에 적용된다.
- 공격형 프로토콜은 드론 공격력의 영향을 받는다.
- 보조형 프로토콜은 각 효과 타입에 맞는 스탯 영향을 받을 수 있다.
  - 채굴 프로토콜은 채굴 데미지 영향을 받는다.
  - 치유 프로토콜은 별도 회복량 스케일을 따르거나 고정값으로 둔다.
  - 청소 프로토콜은 모래 제거 개수를 등급별로 정의한다.

권장 공식:

```text
protocol_cooldown =
  protocol_base_cooldown
  x (1.0 - run_drone_cooldown_reduction)
```

```text
drone_protocol_damage =
  floor((protocol_grade_base_damage + drone_attack_damage_flat)
  x global_damage_multiplier
  x attribute/type/module multipliers)
```

드론 쿨타임 감소는 최소 쿨타임 하한을 둔다.
예:

```text
final_protocol_cooldown = max(protocol_cooldown, 0.15)
```

## 7. 모듈 효과 처리

패시브 모듈은 아이템 ID 하드코딩이 아니라 condition/effect/apply_timing 구조로 처리한다.

모듈 조건 예시:

- `equipment_attribute_is`
- `equipment_type_is`
- `equipped_attribute_count_at_least`
- `equipped_type_count_at_least`
- `weapon_slot_has_type`
- `protocol_type_is`
- `protocol_attribute_is`

모듈 효과 예시:

- `weapon_damage_percent`
- `drone_damage_percent`
- `attribute_damage_percent`
- `type_damage_percent`
- `projectile_additional_shot`
- `beam_split_count`
- `chain_additional_count`
- `explosion_radius_add_units`
- `area_duration_percent`
- `protocol_cooldown_reduction_percent`
- `sand_remove_count_bonus`
- `healing_amount_bonus`

적용 타이밍 예시:

- `stat_query`
- `on_weapon_attack_start`
- `on_weapon_hit`
- `on_protocol_trigger`
- `on_protocol_hit`
- `on_sand_removed`
- `on_player_healed`

## 8. 시각화

무기:

- 캐릭터 좌우 어깨선 높이에 부유한다.
- 좌측 무기와 우측 무기는 캐릭터에 장착된 듯하게 보이도록 한다.
- 좌우 슬롯 위치는 캐릭터 방향/마우스 방향에 따라 자연스럽게 보정할 수 있다.
- 초기 구현에서는 단순 좌우 고정 오프셋으로 충분하다.

드론:

- 캐릭터 키보다 높은 위치에서 부유한다.
- 캐릭터와 약간 떨어진 상단 위치를 유지한다.
- 프로토콜 실행 시 드론에서 이펙트가 나가거나 드론 주변에서 효과가 발생한다.

모듈:

- 패시브 모듈은 월드에 직접 표시하지 않아도 된다.
- HUD/상점/장비 UI에서 아이콘으로 표시한다.

## 9. 상점 / UI 변경

상점:

- 상점 아이템 카테고리를 신규 장비 체계에 맞게 갱신한다.
- 무기, 프로토콜, 모듈이 상점에 등장할 수 있다.
- 드론 자체는 현재 기본 드론만 사용하므로 상점 등장 대상에서 제외해도 된다.
- 기존 가격 티어링과 랭크별 가격 fallback은 유지한다.

장비 UI / HUD:

- 무기 슬롯 2개 표시
- 드론 슬롯 1개 표시
- 프로토콜 슬롯 5개 표시
- 패시브 모듈 슬롯 5개 표시
- 스탯 패널의 공격 관련 항목 갱신
- 기존 공격모듈 5슬롯 UI가 있다면 신규 슬롯 구조로 교체한다.

## 10. 문서 갱신 대상

아래 문서를 신규 구조에 맞게 갱신한다.

- `docs/01_gdd.md`
- `docs/02_systems_spec.md`
- `docs/03_data_and_state_spec.md`
- `docs/04_roadmap.md`
- `docs/05_balance_formula.md`
- `docs/06_attack_modules.md`

## 11. 구현 단계

한 번에 전부 구현하지 말고 아래 순서로 진행한다.

### Phase 1. 문서/스펙 정리

- 신규 장비 체계 문서화
- 기존 공격모듈 용어 제거 또는 deprecated 처리
- 무기/드론/프로토콜/모듈 용어 정의
- 속성/유형 정의
- 신규 스탯 정의
- 기존 근거리/원거리 공격력 제거 계획 문서화

### Phase 2. 데이터 스키마 준비

- 장비 카테고리 신규화
- 기존 attack_module 데이터를 weapon 후보로 마이그레이션
- 프로토콜 샘플 데이터 추가
- 모듈 샘플 데이터 추가
- 기존 TSV -> TRES 파이프라인이 있다면 신규 필드와 호환되도록 수정

### Phase 3. GameState 상태 마이그레이션

- 신규 장착 슬롯 추가
- 기존 공격모듈 장착 상태 제거 또는 deprecated
- 신규 getter 추가
- 스탯 패널 항목 갱신
- 레벨업 카드의 근거리/원거리 공격력 제거
- 무기 공격력/드론 공격력 카드 추가

### Phase 4. Player 발동 구조 변경

- 좌우 무기 쿨타임 처리
- 좌클릭 시 장착 무기 발동
- 드론 프로토콜 자동 쿨타임 처리
- 기본 프로토콜 샘플 동작 연결
- 기존 공격모듈 공전 시각화 제거 또는 무기/드론 시각화로 교체

### Phase 5. 상점/구매/장비 UI 변경

- 무기 구매 시 좌/우 슬롯 장착 처리
- 프로토콜 구매 시 5개 프로토콜 슬롯 처리
- 모듈 구매 시 5개 패시브 모듈 슬롯 처리
- 중복 가능/불가능 규칙 적용
- 상점 snapshot과 실제 구매 가능성 로직 일치 확인

### Phase 6. 회귀 테스트

최소 확인:

- 새 런 시작 시 기본 무기 1개가 장착되는가
- 좌클릭 시 기본 무기가 발사되는가
- 무기 2개 장착 시 두 무기가 각자 쿨타임으로 발사되는가
- 드론이 캐릭터 위쪽에 표시되는가
- 프로토콜 5개 장착이 가능한가
- 동일 프로토콜 중복 장착이 가능한가
- 패시브 모듈 5개 장착이 가능한가
- `{중복 적용 불가}` 모듈이 중복 적용되지 않는가
- 근거리/원거리 공격력 카드와 스탯 표시가 제거되었는가
- 무기 공격력/드론 공격력 스탯이 정상 반영되는가
- 드론 쿨타임 감소가 레벨업 카드에 등장하지 않는가
- 기존 Day 진행, 상점, Next Day, 유해물질 intermission, HP/XP/골드 흐름이 깨지지 않는가

## 12. 금지사항

- 아이템 ID별 하드코딩으로 모듈 효과를 처리하지 말 것.
- `GameConstants.gd`에 무기/프로토콜/모듈 콘텐츠 테이블을 직접 박지 말 것.
- 우측 무기 슬롯을 우클릭 입력으로 연결하지 말 것.
- 드론 쿨타임 감소를 레벨업 카드 기본 풀에 넣지 말 것.
- 기존 근거리/원거리 공격력과 신규 무기/드론 공격력을 동시에 유지하지 말 것.
- 기존 공격모듈 5개 장착 구조와 신규 무기 2개 구조를 동시에 활성화하지 말 것.
- 문서와 코드가 충돌한 상태로 방치하지 말 것.
