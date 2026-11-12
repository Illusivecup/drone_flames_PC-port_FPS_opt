# df_native — нативный ускоритель боевой логики (Rust)

GDExtension-библиотека DroneFlames Reborn: перенос горячей части поиска целей
(`Army._acquire`, юнит-пасс) из GDScript в Rust через godot-rust (gdext 0.5.5,
api-4-7).

## Что ускоряется

В бенчмарке плотного боя (~1000 юнитов, `dev/README_BENCH.md`):

- юнит-пасс поиска целей: **74.6 → 3.6 мс за проход (×20.8)**;
- эквивалентность выбора целей с GDScript-эталоном: **mismatches=0**
  (включая дымовые ветки — `dev/bench_acq.gd`);
- пик боя (BENCH_HOME=1, 1250 юнитов): **frame 118.8 → 87.8 мс (−26%)**,
  `army:units_loop` 16.5 → 9.7 мс.

## Архитектура

- `DfNative.push_units(...)` — снапшот живых не-FPV юнитов + пространственная
  сетка (ячейка 128 px), собирается в `Army._build_grid` раз в скан (0.25 c).
- `DfNative.push_smokes(...)` — дымы операций (круги) и армейские (эллипсы 16x9).
- `DfNative.acquire_one(...)` — поиск ближайшей цели: 1:1 семантика GDScript
  (порядок обхода ячеек, строгий `<`, битовые маски враждебности, ATGM/дым).
- Вызовы с «охраной» (grd) и `hm == -1`, а также цели, умершие после снапшота,
  автоматически уходят в GDScript-путь `_acq_units_gd` — полная parity.

## Отказоустойчивость

Если библиотека не собрана под платформу (Android и т.п.) или не загрузилась,
`Army._nat_init()` не находит класс `DfNative` в ClassDB и игра целиком работает
по прежнему GDScript-коду. Натив — чистая оптимизация, не зависимость.

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
