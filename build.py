#!/usr/bin/env python3
"""
DroneFlames Reborn - Automated Build & Packaging Script
Prepares clean distribution, packages Portable ZIP, and compiles Inno Setup installer.
Reborn Team
"""
from __future__ import annotations

import os
import sys
import json
import shutil
import zipfile
import subprocess
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parent

def get_version() -> str:
    v_file = ROOT_DIR / "version_info.json"
    if v_file.exists():
        try:
            data = json.loads(v_file.read_text(encoding="utf-8"))
            if "version" in data:
                return str(data["version"])
        except Exception:
            pass
    return "1.0.0"

VERSION = get_version()
IS_TEST_BUILD = "--test" in sys.argv or "-test" in VERSION.lower() or os.environ.get("BUILD_TEST", "").lower() in ("1", "true")

if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass
APP_NAME = "DroneFlames_Reborn"
PUBLISHER = "reborn"

BUILD_DIR = ROOT_DIR / "build"
STAGE_NAME = f"{APP_NAME}_PC_v{VERSION}"
STAGE_DIR = BUILD_DIR / STAGE_NAME
DIST_DIR = ROOT_DIR / "dist"

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
    "icon.png",
    "icon.svg",
    "icon_ios.png",
    "project.godot",
    "splash.png",
    "watermark.gd",
    "Start_DroneFlames.bat",
    "version_info.json",
]

def find_iscc() -> str | None:
    env_path = os.environ.get("ISCC_PATH")
    if env_path and os.path.isfile(env_path):
        return env_path
    
    which_iscc = shutil.which("ISCC.exe") or shutil.which("iscc")
    if which_iscc:
        return which_iscc
    
    candidates = [
        Path(os.environ.get("LOCALAPPDATA", "")) / "Programs" / "Inno Setup 6" / "ISCC.exe",
        Path("C:/Program Files (x86)/Inno Setup 6/ISCC.exe"),
        Path("C:/Program Files/Inno Setup 6/ISCC.exe"),
        Path(os.environ.get("USERPROFILE", "")) / "AppData/Local/Programs/Inno Setup 6/ISCC.exe",
    ]
    for c in candidates:
        if c.is_file():
            return str(c)
    return None

def main():
    print(f"=== Building {APP_NAME} v{VERSION} (Reborn Team) ===")
    
    # 1. Clean and prepare directories
    if STAGE_DIR.exists():
        print(f"Cleaning existing stage dir: {STAGE_DIR}")
        shutil.rmtree(STAGE_DIR)
    
    STAGE_DIR.mkdir(parents=True, exist_ok=True)
    DIST_DIR.mkdir(parents=True, exist_ok=True)

    # 2. Copy Game Folders
    print("Copying game folders to stage directory...")
    for folder in FOLDERS:
        src = ROOT_DIR / folder
        dst = STAGE_DIR / folder
        if src.exists():
            shutil.copytree(
                src,
                dst,
                ignore=shutil.ignore_patterns(
                    "*.gdc", "*.remap", "*.tmp", "*.log", "__pycache__"
                )
            )

    # 2b. Copy .godot essential runtime cache and imported assets (fixes grey screen on startup)
    godot_src = ROOT_DIR / ".godot"
    godot_dst = STAGE_DIR / ".godot"
    if godot_src.exists():
        print("Copying .godot runtime caches and imported assets...")
        shutil.copytree(
            godot_src,
            godot_dst,
            ignore=shutil.ignore_patterns(
                "editor", "app_userdata", "shader_cache", "*.tmp", "*.log"
            )
        )
    else:
        print("  [Warning] .godot directory not found in root! Game may fail with blank/grey screen.")

    # 3. Copy Root Files
    print("Copying root game files...")
    for f in ROOT_FILES:
        src = ROOT_DIR / f
        if src.exists():
            shutil.copy2(src, STAGE_DIR / f)
        else:
            print(f"  [Warning] Missing file: {f}")

    # Ensure Start_DroneFlames.bat is in stage
    stage_launcher = STAGE_DIR / "Start_DroneFlames.bat"
    if not stage_launcher.exists():
        stage_launcher.write_text(
            "@echo off\ntitle DroneFlames Reborn\ncd /d \"%~dp0\"\nstart \"\" \"%~dp0DroneFlames.exe\" --path \"%~dp0.\"\n",
            encoding="utf-8"
        )

    # 4. Create Portable ZIP
    zip_path = DIST_DIR / f"{STAGE_NAME}.zip"
    print(f"Creating Portable ZIP archive: {zip_path.name}...")
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
        for file_path in STAGE_DIR.rglob("*"):
            if file_path.is_file():
                arcname = file_path.relative_to(BUILD_DIR)
                zf.write(file_path, arcname)

    zip_size_mb = zip_path.stat().st_size / (1024 * 1024)
    print(f"  [OK] Portable ZIP created: {zip_path.name} ({zip_size_mb:.2f} MB)")

    # 5. Compile Inno Setup Installer
    iscc = find_iscc()
    if iscc:
        print(f"Found Inno Setup compiler: {iscc}")
        iss_path = ROOT_DIR / "installer.iss"
        if iss_path.exists():
            print("Compiling Inno Setup installer...")
            cmd = [
                iscc,
                f"/DMyAppVersion={VERSION}",
                f"/DSourceDir={STAGE_DIR}",
                f"/DOutDir={DIST_DIR}",
                str(iss_path)
            ]
            res = subprocess.run(cmd)
            if res.returncode == 0:
                setup_exe = DIST_DIR / f"{APP_NAME}_PC_Setup_v{VERSION}.exe"
                if setup_exe.exists():
                    setup_size_mb = setup_exe.stat().st_size / (1024 * 1024)
                    print(f"  [OK] Windows Installer created: {setup_exe.name} ({setup_size_mb:.2f} MB)")
            else:
                print(f"  [Error] Inno Setup compilation failed with code {res.returncode}")
        else:
            print("  [Error] installer.iss not found!")
    else:
        print("  [Notice] Inno Setup (ISCC.exe) not found. Skipped installer .exe compilation.")
        print("           Portable ZIP was built successfully in dist/.")

    # 5b. Packaging for macOS (if on macOS and DroneFlames.app is present)
    if sys.platform == "darwin":
        mac_app_candidates = [
            DIST_DIR / "DroneFlames_macOS_Test" / "DroneFlames.app",
            DIST_DIR / "DroneFlames.app",
        ]
        mac_app = next((p for p in mac_app_candidates if p.exists()), None)
        if mac_app:
            dmg_name = f"{APP_NAME}_macOS_v{VERSION}.dmg"
            dmg_path = DIST_DIR / dmg_name
            print(f"Creating macOS DMG package: {dmg_name}...")
            subprocess.run([
                "hdiutil", "create",
                "-volname", APP_NAME,
                "-srcfolder", str(mac_app),
                "-ov", "-format", "UDZO",
                str(dmg_path)
            ], check=False)

    print("\n=== Build Complete! Files in dist/: ===")
    for item in DIST_DIR.iterdir():
        if item.is_file():
            print(f"  - {item.name} ({item.stat().st_size / (1024 * 1024):.2f} MB)")

if __name__ == "__main__":
    main()
