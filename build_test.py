#!/usr/bin/env python3
"""
DroneFlames Reborn - Test Version Builder
Builds separate experimental/test packages (Portable ZIP, Installer, APK/DMG)
without conflicting with stable releases.
Author: Reborn Team
"""

from __future__ import annotations

import os
import sys
import json
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parent

def load_version() -> str:
    v_file = ROOT_DIR / "version_info.json"
    if v_file.exists():
        try:
            data = json.loads(v_file.read_text(encoding="utf-8"))
            if "version" in data:
                return str(data["version"])
        except Exception:
            pass
    return "0.33.5.4"

def set_test_version(new_version: str) -> None:
    v_file = ROOT_DIR / "version_info.json"
    if v_file.exists():
        try:
            data = json.loads(v_file.read_text(encoding="utf-8"))
            data["version"] = new_version
            data["build"] = "test"
            v_file.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
            print(f"[TestBuilder] Updated version_info.json to '{new_version}'")
        except Exception as e:
            print(f"[TestBuilder] Warning: could not update version_info.json: {e}")

def main():
    current_ver = load_version()
    
    # Check if a custom version was passed as an argument
    custom_ver = None
    for arg in sys.argv[1:]:
        if not arg.startswith("-"):
            custom_ver = arg
            break

    if custom_ver:
        test_version = custom_ver if "-test" in custom_ver else f"{custom_ver}-test"
    else:
        test_version = current_ver if "-test" in current_ver else f"{current_ver}-test"

    print("==================================================")
    print(f"  DroneFlames - Test Build Automation")
    print(f"  Target Test Version: {test_version}")
    print("==================================================")

    # Set test version in version_info.json if needed
    if current_ver != test_version:
        set_test_version(test_version)

    # Run build with test flag
    os.environ["BUILD_TEST"] = "1"
    sys.argv = [sys.argv[0], "--test"]
    
    import build
    build.VERSION = test_version
    build.STAGE_NAME = f"{build.APP_NAME}_PC_v{test_version}_{build.PUBLISHER}"
    build.STAGE_DIR = build.BUILD_DIR / build.STAGE_NAME
    build.main()

if __name__ == "__main__":
    main()
