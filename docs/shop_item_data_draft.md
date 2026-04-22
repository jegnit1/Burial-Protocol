# Burial Protocol - Shop Item Data Draft

가격은 전부 `100G`, 등장확률 가중치는 전부 `-1`(미정)으로 둔다.

## 공통 규칙

- `price_gold = 100`
- `shop_enabled = true`
- `shop_spawn_weight = -1`
- 공격 모듈은 `stackable = false`, `max_stack = 1`
- 기능 모듈은 `stackable = false`, `max_stack = 1`
- 강화 모듈은 `stackable = true`, `max_stack = 99`

## 공격 모듈

| item_id | name | rank | type | range_width_u | range_height_u | damage_multiplier | attack_speed_multiplier | short_desc |
|---|---|---:|---|---:|---:|---:|---:|---|
| sword_module | 소드 모듈 | D | melee | 1.0 | 1.0 | 1.0 | 1.0 | 기준형 근거리 공격 모듈 |
| dagger_module | 단검 모듈 | C | melee | 0.5 | 1.0 | 0.8 | 1.4 | 짧지만 빠른 연타형 모듈 |
| lance_module | 랜스 모듈 | B | melee | 2.5 | 0.5 | 1.0 | 0.85 | 긴 리치를 가진 전방 특화 모듈 |
| axe_module | 도끼 모듈 | A | melee | 1.0 | 2.0 | 1.2 | 0.8 | 세로 커버가 넓은 중량형 모듈 |
| greatsword_module | 대검 모듈 | S | melee | 1.5 | 1.0 | 1.5 | 0.65 | 강한 한 방의 중화력 모듈 |

## 기능 모듈

| item_id | name | rank | effect_type | 핵심값 | short_desc |
|---|---|---:|---|---|---|
| combat_drone_d | 하급 전투 드론 | D | combat_drone | damage_multiplier=0.10 | 직선 미사일을 발사하는 보조 드론 |
| combat_drone_c | 중급 전투 드론 | C | combat_drone | damage_multiplier=0.20 | 직선 미사일을 발사하는 보조 드론 |
| combat_drone_b | 상급 전투 드론 | B | combat_drone | damage_multiplier=0.30 | 직선 미사일을 발사하는 보조 드론 |
| combat_drone_a | 군용 전투 드론 | A | combat_drone | damage_multiplier=0.40 | 직선 미사일을 발사하는 보조 드론 |
| combat_drone_s | 완성형 전투 드론 | S | combat_drone | damage_multiplier=0.50 | 직선 미사일을 발사하는 보조 드론 |
| cleaner_bot_d | 하급 청소로봇 | D | sand_cleaner | 5.0초마다 1개 제거 | 모래를 천천히 제거하는 보조 로봇 |
| cleaner_bot_c | 중급 청소로봇 | C | sand_cleaner | 5.0초마다 2개 제거 | 모래를 천천히 제거하는 보조 로봇 |
| cleaner_bot_b | 상급 청소로봇 | B | sand_cleaner | 5.0초마다 3개 제거 | 모래를 천천히 제거하는 보조 로봇 |
| cleaner_bot_a | 최첨단 청소로봇 | A | sand_cleaner | 1.0초마다 1개 제거 | 모래를 빠르게 제거하는 보조 로봇 |
| cleaner_bot_s | 인공지능 청소로봇 | S | sand_cleaner | 1.0초마다 2개 제거 | 모래를 매우 빠르게 제거하는 보조 로봇 |
| spark_field_d | 스파크 필드 | D | aura_damage | tick=0.5, dmg=0.10 | 주변 블록에 주기 피해를 주는 방전 필드 |
| spark_field_c | 방전 필드 | C | aura_damage | tick=0.5, dmg=0.20 | 주변 블록에 주기 피해를 주는 방전 필드 |
| spark_field_b | 아크 필드 | B | aura_damage | tick=0.5, dmg=0.30 | 주변 블록에 주기 피해를 주는 방전 필드 |
| spark_field_a | 고압 필드 | A | aura_damage | tick=0.5, dmg=0.40 | 주변 블록에 주기 피해를 주는 방전 필드 |
| spark_field_s | 테슬라 필드 | S | aura_damage | tick=0.5, dmg=0.50 | 주변 블록에 주기 피해를 주는 방전 필드 |

## 강화 모듈

전체 강화 모듈 데이터는 아래 GDScript 파일과 동일 기준을 따른다.
- 공격력
- 공격속도
- 공격범위
- 치명타 확률
- 체력
- 방어력
- 체력재생
- 최대 무게
- 채굴공격력
- 채굴속도
- 채굴범위
- 이동속도
- 점프력
- 행운
- 이자
- 배터리 회복속도

상세 key/value는 `shop_item_catalog_draft.gd`를 기준으로 사용한다.
