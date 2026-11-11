#!/usr/bin/env python3
"""
DroneFlames Reborn - Legacy Package Builder (for older CPUs without SSE4.2)
Creates an isolated build with 32-bit Godot 4.7.2 and OpenGL3 compatibility presets.
"""

import os
import sys
import shutil
import zipfile
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parent.parent
LEGACY_DIR = ROOT_DIR / "legacy_build"
STAGE_DIR = LEGACY_DIR / "DroneFlames_PC_Legacy_v0.33.4.4"
ZIP_OUTPUT = LEGACY_DIR / "DroneFlames_PC_Legacy_v0.33.4.4.zip"

FOLDERS = [
    "addons",
    "assets",
    "core",
    "dev",
    "game",
    "mods",
    "net",
    "translations",
    "ui",
    "world",
]

ROOT_FILES = [
    "app_icon.ico",
    "assets.sparsepck",
    "icon.png",
    "icon.svg",
    "icon_ios.png",
    "project.godot",
    "splash.png",
    "watermark.gd",
    "PORT_CREDITS_reborn.txt",
    "PORT_BY_GOOD_BOY_IRL.txt",
    "version_info.json",
]


def main():
    print(f"=== Creating Legacy SSE4.2-Fix Build ===")
    if STAGE_DIR.exists():
        print(f"Cleaning existing stage directory: {STAGE_DIR}")
        shutil.rmtree(STAGE_DIR)
    STAGE_DIR.mkdir(parents=True, exist_ok=True)

    print("1. Copying game folders...")
    for folder in FOLDERS:
        src = ROOT_DIR / folder
        dst = STAGE_DIR / folder
        if src.exists():
            shutil.copytree(
                src,
                dst,
                ignore=shutil.ignore_patterns(
                    "*.gdc", "*.remap", "*.tmp", "*.log", "__pycache__"
                ),
            )

    print("2. Copying .godot imported cache...")
    godot_src = ROOT_DIR / ".godot"
    godot_dst = STAGE_DIR / ".godot"
    if godot_src.exists():
        shutil.copytree(
            godot_src,
            godot_dst,
            ignore=shutil.ignore_patterns(
                "editor", "app_userdata", "*.tmp", "*.log"
            ),
        )

    print("3. Copying project files...")
    for rf in ROOT_FILES:
        src = ROOT_DIR / rf
        if src.exists():
            shutil.copy2(src, STAGE_DIR / rf)

    print("4. Placing 32-bit Godot binaries (SSE2 baseline, no SSE4.2 required)...")
    src_bin = ROOT_DIR / "Godot_v4.7.2-stable_win32.exe"
    src_dbg = ROOT_DIR / "Godot_v4.7.2-stable_win32_console.exe"
    if src_bin.exists():
        shutil.copy2(src_bin, STAGE_DIR / "DroneFlames.exe")
    else:
        raise FileNotFoundError(f"Missing {src_bin}")

    if src_dbg.exists():
        shutil.copy2(src_dbg, STAGE_DIR / "DroneFlames_console.exe")
        shutil.copy2(src_dbg, STAGE_DIR / "DroneFlames_Debug.exe")

    print("5. Patching webrtc_native.gdextension for 32-bit compatibility...")
    webrtc_cfg = STAGE_DIR / "addons" / "webrtc_native" / "webrtc_native.gdextension"
    if webrtc_cfg.exists():
        text = webrtc_cfg.read_text(encoding="utf-8")
        if "windows.debug.x86_32" not in text:
            text = text.replace(
                'windows.debug.x86_64 = "lib/libwebrtc_native.windows.template_debug.x86_64.dll"',
                'windows.debug.x86_64 = "lib/libwebrtc_native.windows.template_debug.x86_64.dll"\nwindows.debug.x86_32 = "lib/libwebrtc_native.windows.template_debug.x86_32.dll"',
            )
            text = text.replace(
                'windows.release.x86_64 = "lib/libwebrtc_native.windows.template_release.x86_64.dll"',
                'windows.release.x86_64 = "lib/libwebrtc_native.windows.template_release.x86_64.dll"\nwindows.release.x86_32 = "lib/libwebrtc_native.windows.template_release.x86_32.dll"',
            )
            webrtc_cfg.write_text(text, encoding="utf-8")

    print("6. Creating specialized batch launchers...")
    # Launcher OpenGL 3 (safe default for all legacy machines)
    launcher_gl = """@echo off
title DroneFlames Reborn (Legacy / OpenGL 3)
chcp 65001 >nul
cd /d "%~dp0"
echo ========================================================
echo  DroneFlames Reborn - Режим совместимости (OpenGL 3)
echo  Для старых процессоров (без SSE4.2) и старых видеокарт
echo ========================================================
start "" "%~dp0DroneFlames.exe" --path "%~dp0." --rendering-method gl_compatibility --rendering-driver opengl3
"""
    (STAGE_DIR / "Запуск_Игры.bat").write_text(launcher_gl, encoding="utf-8")
    (STAGE_DIR / "Start_DroneFlames.bat").write_text(launcher_gl, encoding="utf-8")

    # Launcher DirectX 12
    launcher_d3d = """@echo off
title DroneFlames Reborn (DirectX 12)
chcp 65001 >nul
cd /d "%~dp0"
echo ========================================================
echo  DroneFlames Reborn - Режим DirectX 12
echo ========================================================
start "" "%~dp0DroneFlames.exe" --path "%~dp0."
"""
    (STAGE_DIR / "Запуск_Игры_DirectX12.bat").write_text(launcher_d3d, encoding="utf-8")

    # Launcher Debug with console
    launcher_dbg = """@echo off
title DroneFlames Reborn (Консоль отладки)
chcp 65001 >nul
cd /d "%~dp0"
echo ========================================================
echo  DroneFlames Reborn - Запуск в консоли отладки
echo ========================================================
"%~dp0DroneFlames_console.exe" --path "%~dp0." --rendering-method gl_compatibility --rendering-driver opengl3 --verbose
pause
"""
    (STAGE_DIR / "Запуск_Консоль_Отладка.bat").write_text(launcher_dbg, encoding="utf-8")

    # Readme
    readme_txt = """===========================================================
  DroneFlames Reborn - Legacy Edition (v0.33.4.4)
  Специальная сборка для старых ПК и процессоров без SSE4.2
===========================================================

ЧТО ЭТО ЗА СБОРКА:
Стандартная 64-битная версия игры требует инструкции процессора SSE4.2
и видеокарту с поддержкой DirectX 12 / Vulkan. На старых процессорах
(Intel Core 2 Duo/Quad, AMD Phenom, Athlon II и др.) стандартная игра
выдаёт ошибку:
  "A CPU with SSE4.2 instruction set support is required"

Эта сборка исправляет данную ошибку:
1. Использует 32-битный движок Godot 4.7.2 (требует только SSE2,
   который поддерживается абсолютно всеми процессорами).
2. По умолчанию запускает графику через OpenGL 3 (Compatibility),
   поэтому игра запустится даже на старых видеокартах без поддержки DirectX 12.

КАК ЗАПУСКАТЬ:
- Основной запуск: запустите файл "Запуск_Игры.bat" (или "Start_DroneFlames.bat").
- Если на ПК видеокарта поддерживает DirectX 12: можно запускать через "Запуск_Игры_DirectX12.bat".
- Если игра вдруг закрывается: запустите "Запуск_Консоль_Отладка.bat", чтобы увидеть отладочный лог.

Собрано специально для Reborn Team
===========================================================
"""
    (STAGE_DIR / "README_ДЛЯ_СТАРЫХ_ПК.txt").write_text(readme_txt, encoding="utf-8")

    print(f"7. Compressing to ZIP: {ZIP_OUTPUT.name}...")
    if ZIP_OUTPUT.exists():
        ZIP_OUTPUT.unlink()

    with zipfile.ZipFile(ZIP_OUTPUT, "w", zipfile.ZIP_DEFLATED) as zf:
        for file_path in STAGE_DIR.rglob("*"):
            if file_path.is_file():
                arcname = file_path.relative_to(STAGE_DIR)
                zf.write(file_path, arcname=f"DroneFlames_PC_Legacy_v0.33.4.4/{arcname}")

    zip_size_mb = ZIP_OUTPUT.stat().st_size / (1024 * 1024)
    print(f"\n[SUCCESS] Legacy ZIP ready: {ZIP_OUTPUT}")
    print(f"File size: {zip_size_mb:.1f} MB")


if __name__ == "__main__":
    main()
