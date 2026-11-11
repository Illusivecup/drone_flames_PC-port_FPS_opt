# Стенд замеров (Godot 4.7, без графики)

Не требует видеокарты: `--headless`. Перед запуском применить хуки (две строки в `main.gd`):

    git apply dev/bench_hooks.patch        # или patch -p1 < dev/bench_hooks.patch

## 1. Вся симуляция (A/B двух версий `army.gd`)
    BENCH_HOME=1 BENCH_UNITS=250 godot --headless --path . -- --bench
Печатает каждые 40 игровых секунд: кадр, число юнитов, затраты `perf_sys` по системам (мс за кадр).
Переменные: `BENCH_UNITS` (юнитов на страну), `BENCH_HOME=1` (армии у столиц), `BENCH_RAID=1` (часть армии у чужих баз),
`BENCH_FRONT=1` (две коалиции у линии фронта). Без переменных — все со всеми, юниты перемешаны.

## 2. Эквивалентность и скорость `_acquire`
Нужна эталонная копия оригинала (временно, в игру не входит):

    python3 dev/make_acquire_ref.py путь/к/ОРИГИНАЛЬНОМУ/army.gd >> game/army.gd
    BENCH_HOME=1 BENCH_RAID=1 BENCH_UNITS=250 BENCH_GAME_S=30 godot --headless --path . -- --bench-acq

Вывод: `mismatches=0` — выбор целей совпал у всех юнитов; затем время прохода эталона и нового кода.
