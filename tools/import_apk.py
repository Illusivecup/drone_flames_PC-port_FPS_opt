#!/usr/bin/env python3
"""
DroneFlames APK Importer & Versioning Tool
Extracts Godot project assets from APK, reconstructs project.godot,
records metadata, and commits/tags in Git.
"""

import os
import sys
import json
import shutil
import hashlib
import struct
import zipfile
import subprocess
from datetime import datetime

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
GAME_DIR = os.path.join(ROOT_DIR, "game")
DOCS_DIR = os.path.join(ROOT_DIR, "docs")
APKS_DIR = os.path.join(ROOT_DIR, "apks")


def get_sha256(filepath):
    h = hashlib.sha256()
    with open(filepath, "rb") as f:
        while chunk := f.read(1024 * 1024):
            h.update(chunk)
    return h.hexdigest()


def parse_manifest_strings(manifest_bytes):
    # Quick extraction of utf-16le strings from binary AndroidManifest.xml
    import re
    strings = re.findall(b"(?:[\x20-\x7e]\x00){2,}", manifest_bytes)
    result = [s.decode("utf-16le", errors="ignore") for s in strings]
    return result


def decode_project_binary(b):
    if not b.startswith(b"ECFG"):
        raise ValueError("Invalid project.binary magic")

    offset = 4
    count = struct.unpack("<I", b[offset:offset+4])[0]
    offset += 4

    config = {}

    for _ in range(count):
        klen = struct.unpack("<I", b[offset:offset+4])[0]
        offset += 4
        key = b[offset:offset+klen].decode("utf-8")
        offset += klen

        vlen = struct.unpack("<I", b[offset:offset+4])[0]
        offset += 4
        vdata = b[offset:offset+vlen]
        offset += vlen

        vtype = struct.unpack("<I", vdata[:4])[0]
        payload = vdata[4:]

        if vtype == 1:  # bool
            val = struct.unpack("<I", payload[:4])[0] != 0
        elif vtype == 2:  # int
            val = struct.unpack("<i", payload[:4])[0]
        elif vtype == 3:  # float
            val = struct.unpack("<d", payload[:8])[0]
        elif vtype == 4:  # string
            slen = struct.unpack("<I", payload[:4])[0]
            val = payload[4:4+slen].decode("utf-8", errors="replace").rstrip("\x00")
        elif vtype == 34:  # PackedStringArray
            cnt = struct.unpack("<I", payload[:4])[0]
            pos = 4
            arr = []
            for _ in range(cnt):
                slen = struct.unpack("<I", payload[pos:pos+4])[0]
                pos += 4
                s = payload[pos:pos+slen].decode("utf-8", errors="replace").rstrip("\x00")
                pos += (slen + 3) & ~3
                arr.append(s)
            val = arr
        else:
            val = f"<raw:{payload.hex()}>"

        config[key] = val

    return config


def generate_project_godot(config, out_path):
    # Group settings by section
    sections = {}
    for key, val in config.items():
        if "/" in key:
            section, prop = key.split("/", 1)
        else:
            section, prop = "", key

        if section not in sections:
            sections[section] = []
        sections[section].append((prop, val))

    lines = [
        "; Engine configuration file.",
        "; Reconstructed from project.binary by DroneFlames Porting Tool",
        "",
        "config_version=5",
        ""
    ]

    for section, props in sections.items():
        if section:
            lines.append(f"[{section}]")
        for prop, val in props:
            if isinstance(val, bool):
                val_str = "true" if val else "false"
            elif isinstance(val, (int, float)):
                val_str = str(val)
            elif isinstance(val, str):
                val_str = f'"{val}"'
            elif isinstance(val, list):
                items = ", ".join(f'"{x}"' for x in val)
                val_str = f"PackedStringArray({items})"
            else:
                val_str = f'"{val}"'
            lines.append(f"{prop}={val_str}")
        lines.append("")

    with open(out_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))


def import_apk(apk_path, create_git_commit=True):
    apk_path = os.path.abspath(apk_path)
    if not os.path.exists(apk_path):
        print(f"Error: APK not found at {apk_path}")
        return False

    apk_filename = os.path.basename(apk_path)
    sha256 = get_sha256(apk_path)
    file_size_mb = os.path.getsize(apk_path) / (1024 * 1024)

    print(f"Processing: {apk_filename} ({file_size_mb:.2f} MB)")
    print(f"SHA-256: {sha256}")

    with zipfile.ZipFile(apk_path, "r") as z:
        manifest_raw = z.read("AndroidManifest.xml")
        manifest_strings = parse_manifest_strings(manifest_raw)

        # Detect version name
        version_name = "0.32.0"
        for s in manifest_strings:
            if s.startswith("0.") or s.startswith("1."):
                version_name = s
                break

        godot_ver = "4.7.2.stable"
        for s in manifest_strings:
            if "4." in s and ("stable" in s or "dev" in s or "beta" in s):
                godot_ver = s
                break

        package_name = "com.kolesnyk.droneflames"
        for s in manifest_strings:
            if "droneflames" in s.lower() and "." in s:
                package_name = s
                break

        print(f"Detected: Version={version_name}, Godot={godot_ver}, Package={package_name}")

        # Clean old game directory if exists, preserving webrtc windows dlls if present
        saved_dlls = {}
        webrtc_lib_dir = os.path.join(GAME_DIR, "addons", "webrtc_native", "lib")
        if os.path.exists(webrtc_lib_dir):
            for f in os.listdir(webrtc_lib_dir):
                if f.endswith(".dll"):
                    with open(os.path.join(webrtc_lib_dir, f), "rb") as fp:
                        saved_dlls[f] = fp.read()

        if os.path.exists(GAME_DIR):
            shutil.rmtree(GAME_DIR)
        os.makedirs(GAME_DIR, exist_ok=True)

        # Extract assets/ into GAME_DIR
        extracted_count = 0
        for item in z.infolist():
            if item.filename.startswith("assets/"):
                rel_path = item.filename[len("assets/"):]
                if not rel_path or rel_path.endswith("/"):
                    continue
                dest_path = os.path.join(GAME_DIR, rel_path)
                os.makedirs(os.path.dirname(dest_path), exist_ok=True)
                with z.open(item) as src, open(dest_path, "wb") as dst:
                    shutil.copyfileobj(src, dst)
                extracted_count += 1

        # Restore saved windows dlls
        if saved_dlls:
            os.makedirs(webrtc_lib_dir, exist_ok=True)
            for f, data in saved_dlls.items():
                with open(os.path.join(webrtc_lib_dir, f), "wb") as fp:
                    fp.write(data)

        # Patch extension_list.cfg for Windows (remove df_device which lacks Windows binaries)
        ext_cfg = os.path.join(GAME_DIR, ".godot", "extension_list.cfg")
        if os.path.exists(ext_cfg):
            with open(ext_cfg, "r", encoding="utf-8") as f:
                lines = [l.strip() for l in f if "df_device" not in l and l.strip()]
            with open(ext_cfg, "w", encoding="utf-8") as f:
                f.write("\n".join(lines) + "\n")

        print(f"Extracted {extracted_count} game files to {GAME_DIR}")

        # Parse project.binary and generate project.godot
        proj_bin_path = os.path.join(GAME_DIR, "project.binary")
        if os.path.exists(proj_bin_path):
            with open(proj_bin_path, "rb") as f:
                config = decode_project_binary(f.read())
            proj_godot_path = os.path.join(GAME_DIR, "project.godot")
            generate_project_godot(config, proj_godot_path)
            print(f"Generated text project.godot with {len(config)} settings")

        # Save metadata info
        meta = {
            "version": version_name,
            "apk_filename": apk_filename,
            "apk_sha256": sha256,
            "apk_size_bytes": os.path.getsize(apk_path),
            "godot_version": godot_ver,
            "package_name": package_name,
            "imported_at": datetime.now().isoformat(),
            "extracted_files_count": extracted_count,
        }

        with open(os.path.join(ROOT_DIR, "version_info.json"), "w", encoding="utf-8") as f:
            json.dump(meta, f, indent=2)

    # Git management
    if create_git_commit:
        if not os.path.exists(os.path.join(ROOT_DIR, ".git")):
            print("Initializing Git repository...")
            subprocess.run(["git", "init"], cwd=ROOT_DIR, check=True)

        # Stage and commit
        print("Staging files in Git...")
        subprocess.run(["git", "add", "."], cwd=ROOT_DIR, check=True)

        commit_msg = f"v{version_name}: Import from {apk_filename}\n\nEngine: Godot {godot_ver}\nPackage: {package_name}\nSHA-256: {sha256}"
        try:
            subprocess.run(["git", "commit", "-m", commit_msg], cwd=ROOT_DIR, check=True)
            print(f"Created commit for v{version_name}")
        except subprocess.CalledProcessError:
            print("No changes to commit or commit failed.")

        # Tag
        tag_name = f"v{version_name}"
        subprocess.run(["git", "tag", "-f", tag_name], cwd=ROOT_DIR, check=True)
        print(f"Created Git tag: {tag_name}")

    print("\nImport complete!")
    return True


if __name__ == "__main__":
    if len(sys.argv) > 1:
        target_apk = sys.argv[1]
    else:
        target_apk = r"c:\Users\mxka\Downloads\exDesktop\DroneFlames_v0.32.0_2610312032_TEST_wt_test.apk"

    import_apk(target_apk)
