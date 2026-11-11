#!/usr/bin/env python3
"""
Build styled macOS DMG installer for DroneFlames using dmgbuild.
Falls back to native hdiutil if dmgbuild is not available or fails.
"""

import argparse
import os
import shutil
import subprocess
import sys

ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PKG_DIR = os.path.join(ROOT_DIR, "packaging", "macos")

def build_with_dmgbuild(app_path: str, output_dmg: str, volume_name: str = "DroneFlames") -> bool:
    try:
        import dmgbuild
    except ImportError:
        print("[build_dmg] dmgbuild Python package not installed.")
        return False

    print(f"[build_dmg] Building styled DMG with dmgbuild: {output_dmg}")
    
    # Ensure parent output directory exists
    os.makedirs(os.path.dirname(os.path.abspath(output_dmg)), exist_ok=True)
    if os.path.exists(output_dmg):
        os.remove(output_dmg)

    bg_tiff = os.path.join(PKG_DIR, "background.tiff")
    vol_icon = os.path.join(PKG_DIR, "VolumeIcon.icns")

    settings = {
        "files": [app_path],
        "symlinks": {
            "Applications": "/Applications"
        },
        "background": bg_tiff if os.path.isfile(bg_tiff) else None,
        "icon": vol_icon if os.path.isfile(vol_icon) else None,
        "window_rect": ((200, 120), (600, 400)),
        "default_view": "icon-view",
        "icon_size": 96,
        "text_size": 12,
        "icon_locations": {
            "DroneFlames.app": (150, 195),
            "Applications": (450, 195)
        },
        "hide_extensions": ["DroneFlames.app"],
        "show_status_bar": False,
        "show_tab_view": False,
        "show_toolbar": False,
        "show_pathbar": False,
        "show_sidebar": False,
    }

    try:
        dmgbuild.build_dmg(
            filename=output_dmg,
            volume_name=volume_name,
            settings=settings,
            lookForHiDPI=True
        )
        print(f"[build_dmg] Successfully created styled DMG at: {output_dmg}")
        return True
    except Exception as e:
        print(f"[build_dmg] dmgbuild failed: {e}")
        return False

def build_with_hdiutil(app_path: str, output_dmg: str, volume_name: str = "DroneFlames"):
    print(f"[build_dmg] Fallback: Building DMG with native hdiutil...")
    staging_dir = os.path.join(ROOT_DIR, "dist", "dmg_fallback_staging")
    if os.path.exists(staging_dir):
        shutil.rmtree(staging_dir)
    os.makedirs(staging_dir, exist_ok=True)

    target_app = os.path.join(staging_dir, "DroneFlames.app")
    if os.path.isdir(app_path):
        subprocess.check_call(["/usr/bin/ditto", app_path, target_app])
    
    app_link = os.path.join(staging_dir, "Applications")
    if not os.path.exists(app_link):
        os.symlink("/Applications", app_link)

    if os.path.exists(output_dmg):
        os.remove(output_dmg)

    subprocess.check_call([
        "hdiutil", "create",
        "-volname", volume_name,
        "-srcfolder", staging_dir,
        "-ov",
        "-format", "UDZO",
        output_dmg
    ])
    shutil.rmtree(staging_dir, ignore_errors=True)
    print(f"[build_dmg] Fallback DMG created: {output_dmg}")

def main():
    parser = argparse.ArgumentParser(description="Create styled DroneFlames macOS DMG")
    parser.add_argument("--app", default=os.path.join(ROOT_DIR, "dist", "DroneFlames.app"), help="Path to DroneFlames.app")
    parser.add_argument("--output", default=os.path.join(ROOT_DIR, "dist", "DroneFlames_macOS.dmg"), help="Output DMG path")
    parser.add_argument("--volume-name", default="DroneFlames", help="Volume name for DMG")

    args = parser.parse_args()

    app_path = os.path.abspath(args.app)
    output_dmg = os.path.abspath(args.output)

    if not os.path.isdir(app_path):
        print(f"[build_dmg] Error: App bundle not found at {app_path}", file=sys.stderr)
        sys.exit(1)

    success = build_with_dmgbuild(app_path, output_dmg, args.volume_name)
    if not success:
        build_with_hdiutil(app_path, output_dmg, args.volume_name)

if __name__ == "__main__":
    main()
