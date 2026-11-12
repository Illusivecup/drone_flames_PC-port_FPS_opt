# df_native — нативный ускоритель боевой логики (Rust)

GDExtension-библиотека DroneFlames Reborn: перевод горячих пассов боевой
логики из GDScript в Rust через godot-rust (gdext 0.5.5, api-4-7).

## Что переведено (v2)

| Метод | Что делает | Эталон GDScript |
|---|---|---|
| `acquire_one` | поиск ближайшей цели-юнита (`Army._acquire`) | `_acq_units_gd` |
| `valid_one` | валидация юнит-цели: враждебность+дистанция+дым (`Army._valid`) | `_valid_gd` |
| `spot_all` | весь пасс «кто кого видит»: глаза×юниты/здания (`ArmyFire._spot`) | тело `_spot` |
| `rockets_step` | полёт ATGM/RPG: разворот, шаг, трейл (`Army._update_rockets`) | `_update_rockets_gd` |
| `shells_step` | тайминги снарядов: t, свист, трейл-тик, прибытие (`ArmyFire._update_shells`) | `_update_shells_gd` |
| `smoke_at` | `Army.in_smoke`: круги операций + армейские эллипсы 16x9 | тело `in_smoke` |
| `aim_pick` | выбор точки огня артиллерии: окопанные/запросы/spotted (`ArmyFire._pick`) | `_pick_gd` |
| `occupy_candidates` | префильтр кандидатов в окопы + posted (`Army.occupy`) | полный перебор |

## Результаты

Пик плотного боя (BENCH_HOME=1, 1250 юнитов, `--bench`):

- `fire:_spot` (разведка, O(страны×юниты×глаза)): **9.4 → ~0.6 мс/кадр (−90%+)**,
  выпал из топ-9 профиля;
- `army:fire` целиком: **16.7 → 8.4–9.4 мс/кадр (−45–50%)**;
- юнит-пасс поиска целей (v1): **74.6 → 3.6 мс (×20.8)**;
- `army:_posts` (occupy): 4.4 → 3.4 мс/кадр;
- пик кадра: **83.0 → 75.7 мс** на одинаковой карте.

Парити на всех переводах — `dev/bench_nat2.gd` (`--bench-nat2`): на бою
700 юнитов / 612 пар valid / 68 пиков артиллерии / 582 кандидата occupy —
**mismatches=0**. Ключ к parity: дистанции считаются в f32 (как
`Vector2.distance_squared_to`), бокс — точная эмуляция f32-цепочки
`Rect2.expand/grow/has_point`.

## Архитектура

- `push_units(...)` — снапшот живых не-FPV юнитов (позиции, страна, биты
  флагов: техника/воздух/окоп/без-поста/операция/резерв/не-осада) + тип +
  пространственная сетка (128 px). Свежий снапшот: `Army._nat_sync()` по
  требованию (spot, occupy) и в `_build_grid` (один проход с GDScript-сеткой).
- `push_smokes(...)` — дымы операций (круги) и армейские (эллипсы 16x9),
  пуш каждый кадр из `Army.update` — дым виден текущим кадром.
- Дистанции — f32 (как в Godot), границы бокса — полуоткрытый интервал
  `[min, max)` (как `Rect2.has_point` в 4.x).
- RNG остаётся в GDScript (гейты rf()/rfr() и разброс попаданий) — порядок
  вызовов RNG совпадает с эталоном байт-в-байт.
- Сторонние эффекты (fx, sfx, урон, nav_path) — всегда GDScript; Rust
  возвращает плоские массивы решений, GDScript применяет.

## Отказоустойчивость

Если библиотека не собрана под платформу (Android и т.п.) или не загрузилась,
`Army._nat_init()` не находит класс `DfNative` в ClassDB и игра целиком работает
по прежнему GDScript-коду (эталоны `_pick_gd`, `_valid_gd`,
`_update_rockets_gd`, `_update_shells_gd`, GDScript-`_spot`). Натив — чистая
оптимизация, не зависимость.

## Сборка

```bash
cargo build --release --manifest-path native/df_native/Cargo.toml
cp native/df_native/target/release/libdf_native.so addons/df_native/bin/   # linux
cp native/df_native/target/release/df_native.dll   addons/df_native/bin/   # windows
cp native/df_native/target/release/libdf_native.dylib addons/df_native/bin/ # macos
```

CI собирает библиотеку на каждом раннере перед экспортом (Windows — MSVC со
статическим CRT, macOS — universal2 через lipo). Linux-сборка лежит в
`addons/df_native/bin/libdf_native.so` в репозитории.

## Проверки

```bash
# парити всех нативных пассов (BENCH_UNITS/BENCH_WARM_S — плотность боя):
godot --headless --path . --bench-nat2
# парити поиска целей (v1):
godot --headless --path . --bench-acq
# A/B профиль систем:
BENCH_UNITS=250 BENCH_HOME=1 godot --headless --path . --bench
```
