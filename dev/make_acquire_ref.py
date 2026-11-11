#!/usr/bin/env python3
"""Печатает ЭТАЛОННУЮ копию оригинального Army._acquire под именем _acquire_ref.
Нужна только для проверки эквивалентности (dev/bench_acq.gd); в игру не входит.

  python3 dev/make_acquire_ref.py путь/к/ОРИГИНАЛЬНОМУ/army.gd >> game/army.gd
"""
import sys
src = open(sys.argv[1], encoding="utf-8").read()
a = src.index("func _acquire(u: Unit) -> void :")
b = src.index("func _target_pos(")
print("\n\n" + src[a:b].replace("func _acquire(u: Unit) -> void :", "func _acquire_ref(u: Unit) -> void :"))
