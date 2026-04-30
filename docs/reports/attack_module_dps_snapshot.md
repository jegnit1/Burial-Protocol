# Attack Module DPS Snapshot Report

Date: 2026-04-30

This snapshot compares each attack module at each virtual grade, not only the catalog row rank. `base_damage_by_grade` values are treated as fixed data values and are never multiplied by `grade_damage_mult`.

Damage lookup priority:

1. `base_damage_by_grade[current_grade]`
2. `module_base_damage`
3. Fallback to `1` with a warning when neither data value exists

`drone_attack_module` is included in the base damage matrix so the structure is represented, but mechanic/drone DPS is excluded from the grade comparison tables.

## Base Damage By Grade Matrix

| module_id | type | D | C | B | A | S |
|---|---:|---:|---:|---:|---:|---:|
| sword_module | melee | 10 | 15 | 20 | 25 | 30 |
| dagger_module | melee | 9 | 14 | 18 | 23 | 27 |
| lance_module | melee | 13 | 20 | 26 | 33 | 39 |
| axe_module | melee | 17 | 26 | 34 | 43 | 51 |
| greatsword_module | melee | 24 | 36 | 48 | 60 | 72 |
| bow_module | ranged | 5 | 8 | 10 | 13 | 15 |
| scatter_module | ranged | 4 | 6 | 8 | 10 | 12 |
| pierce_module | ranged | 4 | 6 | 8 | 10 | 12 |
| laser_module | ranged | 3 | 5 | 6 | 8 | 9 |
| drone_attack_module | mechanic | 6 | 9 | 12 | 15 | 18 |

## D Grade DPS Comparison

| module | type | base_damage | APS | single_projectile_DPS | full_hit_DPS |
|---|---:|---:|---:|---:|---:|
| sword D | melee | 10 | 3.333 | 33.33 | 33.33 |
| dagger D | melee | 9 | 4.667 | 42.00 | 42.00 |
| lance D | melee | 13 | 2.833 | 36.83 | 36.83 |
| axe D | melee | 17 | 2.667 | 45.33 | 45.33 |
| greatsword D | melee | 24 | 2.167 | 52.00 | 52.00 |
| bow D | ranged | 5 | 2.833 | 14.17 | 14.17 |
| scatter D | ranged | 4 | 2.333 | 9.33 | 28.00 |
| pierce D | ranged | 4 | 2.000 | 8.00 | 8.00 |
| laser D | ranged | 3 | 2.000 | 6.00 | 6.00 |

## C Grade DPS Comparison

| module | type | base_damage | APS | single_projectile_DPS | full_hit_DPS |
|---|---:|---:|---:|---:|---:|
| sword C | melee | 15 | 3.500 | 52.50 | 52.50 |
| dagger C | melee | 14 | 4.900 | 68.60 | 68.60 |
| lance C | melee | 20 | 2.975 | 59.50 | 59.50 |
| axe C | melee | 26 | 2.800 | 72.80 | 72.80 |
| greatsword C | melee | 36 | 2.275 | 81.90 | 81.90 |
| bow C | ranged | 8 | 2.975 | 23.80 | 23.80 |
| scatter C | ranged | 6 | 2.450 | 14.70 | 44.10 |
| pierce C | ranged | 6 | 2.100 | 12.60 | 12.60 |
| laser C | ranged | 5 | 2.100 | 10.50 | 10.50 |

## B Grade DPS Comparison

| module | type | base_damage | APS | single_projectile_DPS | full_hit_DPS |
|---|---:|---:|---:|---:|---:|
| sword B | melee | 20 | 3.667 | 73.33 | 73.33 |
| dagger B | melee | 18 | 5.133 | 92.40 | 92.40 |
| lance B | melee | 26 | 3.117 | 81.03 | 81.03 |
| axe B | melee | 34 | 2.933 | 99.73 | 99.73 |
| greatsword B | melee | 48 | 2.383 | 114.40 | 114.40 |
| bow B | ranged | 10 | 3.117 | 31.17 | 31.17 |
| scatter B | ranged | 8 | 2.567 | 20.53 | 61.60 |
| pierce B | ranged | 8 | 2.200 | 17.60 | 17.60 |
| laser B | ranged | 6 | 2.200 | 13.20 | 13.20 |

## A Grade DPS Comparison

| module | type | base_damage | APS | single_projectile_DPS | full_hit_DPS |
|---|---:|---:|---:|---:|---:|
| sword A | melee | 25 | 3.833 | 95.83 | 95.83 |
| dagger A | melee | 23 | 5.367 | 123.43 | 123.43 |
| lance A | melee | 33 | 3.258 | 107.53 | 107.53 |
| axe A | melee | 43 | 3.067 | 131.87 | 131.87 |
| greatsword A | melee | 60 | 2.492 | 149.50 | 149.50 |
| bow A | ranged | 13 | 3.258 | 42.36 | 42.36 |
| scatter A | ranged | 10 | 2.683 | 26.83 | 80.50 |
| pierce A | ranged | 10 | 2.300 | 23.00 | 23.00 |
| laser A | ranged | 8 | 2.300 | 18.40 | 18.40 |

## S Grade DPS Comparison

| module | type | base_damage | APS | single_projectile_DPS | full_hit_DPS |
|---|---:|---:|---:|---:|---:|
| sword S | melee | 30 | 4.167 | 125.00 | 125.00 |
| dagger S | melee | 27 | 5.833 | 157.50 | 157.50 |
| lance S | melee | 39 | 3.542 | 138.13 | 138.13 |
| axe S | melee | 51 | 3.333 | 170.00 | 170.00 |
| greatsword S | melee | 72 | 2.708 | 195.00 | 195.00 |
| bow S | ranged | 15 | 3.542 | 53.13 | 53.13 |
| scatter S | ranged | 12 | 2.917 | 35.00 | 105.00 |
| pierce S | ranged | 12 | 2.500 | 30.00 | 30.00 |
| laser S | ranged | 9 | 2.500 | 22.50 | 22.50 |

## Grade Growth Table

| module_id | D->C | C->B | B->A | A->S |
|---|---:|---:|---:|---:|
| sword_module | +50.0% | +33.3% | +25.0% | +20.0% |
| dagger_module | +55.6% | +28.6% | +27.8% | +17.4% |
| lance_module | +53.8% | +30.0% | +26.9% | +18.2% |
| axe_module | +52.9% | +30.8% | +26.5% | +18.6% |
| greatsword_module | +50.0% | +33.3% | +25.0% | +20.0% |
| bow_module | +60.0% | +25.0% | +30.0% | +15.4% |
| scatter_module | +50.0% | +33.3% | +25.0% | +20.0% |
| pierce_module | +50.0% | +33.3% | +25.0% | +20.0% |
| laser_module | +66.7% | +20.0% | +33.3% | +12.5% |
| drone_attack_module | +50.0% | +33.3% | +25.0% | +20.0% |

## Readout

- The previous row-rank comparison was invalid because it compared different module shapes at different grades instead of comparing all module shapes at the same grade.
- Same-grade comparison is now available for D/C/B/A/S across sword, dagger, lance, axe, greatsword, bow, scatter, pierce, and laser.
- Scatter reports both `single_projectile_DPS` and `full_hit_DPS`; the full-hit column assumes all projectiles connect.
- D-grade melee average full-hit DPS: 41.90.
- D-grade ranged average full-hit DPS: 14.04.
