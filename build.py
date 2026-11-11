#!/usr/bin/env python3
"""
DroneFlames Reborn — Automated Build & Packaging Script.

Performs a REAL headless Godot export (this used to be missing — the release
archive contained project sources instead of the game):

  1. Ensures Godot 4.7.2 editor + matching export templates are available
     (downloads them on demand; works on CI runners and locally).
  2. Runs `godot --headless --import`, then `--export-release "Windows Desktop"`.
  3. HARD-FAILS if DroneFlames.exe / DroneFlames.pck are missing or broken
     (no more silent "sources-only" archives).
  4. Packages the Portable ZIP and compiles the Inno Setup installer.

Reborn Team
"""
from __future__ import annotations

import json
import os
import platform
import shutil
import subprocess
import sys
import time
import urllib.request
import zipfile
from pathlib import Path

GODOT_VERSION = "4.7.2-stable"          # editor release tag
TPL_DIR_NAME = "4.7.2.stable"           # export_templates folder name
GODOT_RELEASE_BASE = f"https://github.com/godotengine/godot/releases/download/{GODOT_VERSION}"
EXPORT_PRESET = "Windows Desktop"
EXE_NAME = "DroneFlames.exe"

ROOT_DIR = Path(__file__).resolve().parent
GODOT_BIN_DIR = ROOT_DIR / "godot_bin"

APP_NAME = "DroneFlames_Reborn"

BUILD_DIR = ROOT_DIR / "build"
DIST_DIR = ROOT_DIR / "dist"


def log(msg: str) -> None:
    print(msg, flush=True)


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
STAGE_NAME = f"{APP_NAME}_PC_v{VERSION}"
STAGE_DIR = BUILD_DIR / STAGE_NAME

if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass


def download(url: str, dest: Path, attempts: int = 5) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    last: Exception | None = None
    for i in range(attempts):
        try:
            log(f"  downloading {url} (attempt {i + 1}/{attempts})")
            tmp = dest.with_suffix(dest.suffix + ".part")
            with urllib.request.urlopen(url, timeout=300) as resp, open(tmp, "wb") as f:
                shutil.copyfileobj(resp, f, 1024 * 1024)
            tmp.replace(dest)
            return
        except Exception as exc:  # noqa: BLE001
            last = exc
            log(f"  download failed: {exc}")
            time.sleep(5)
    raise RuntimeError(f"failed to download {url}: {last}")


def godot_bin_path() -> Path:
    system = platform.system()
    GODOT_BIN_DIR.mkdir(parents=True, exist_ok=True)
    exe: Path | None = None
    if system == "Windows":
        exe = GODOT_BIN_DIR / f"Godot_v{GODOT_VERSION}_win64.exe"
        if not exe.exists():
            download(f"{GODOT_RELEASE_BASE}/Godot_v{GODOT_VERSION}_win64.exe.zip",
                     GODOT_BIN_DIR / "godot_win64.zip")
            with zipfile.ZipFile(GODOT_BIN_DIR / "godot_win64.zip") as zf:
                zf.extractall(GODOT_BIN_DIR)
    elif system == "Darwin":
        exe = GODOT_BIN_DIR / "Godot.app" / "Contents" / "MacOS" / "Godot"
        if not exe.exists():
            download(f"{GODOT_RELEASE_BASE}/Godot_v{GODOT_VERSION}_macos.universal.zip",
                     GODOT_BIN_DIR / "godot_macos.zip")
            subprocess.run(["unzip", "-q", "-o", str(GODOT_BIN_DIR / "godot_macos.zip"),
                            "-d", str(GODOT_BIN_DIR)], check=True)
            subprocess.run(["chmod", "+x", str(exe)], check=False)
    else:
        exe = GODOT_BIN_DIR / f"Godot_v{GODOT_VERSION}_linux.x86_64"
        if not exe.exists():
            download(f"{GODOT_RELEASE_BASE}/Godot_v{GODOT_VERSION}_linux.x86_64.zip",
                     GODOT_BIN_DIR / "godot_linux.zip")
            with zipfile.ZipFile(GODOT_BIN_DIR / "godot_linux.zip") as zf:
                zf.extractall(GODOT_BIN_DIR)
    if exe is None or not exe.exists():
        raise RuntimeError("Godot editor binary not found after extraction")
    if platform.system() != "Windows":
        exe.chmod(0o755)
    return exe


def templates_dir() -> Path:
    system = platform.system()
    if system == "Windows":
        base = Path(os.environ.get("APPDATA") or (Path.home() / "AppData" / "Roaming")) / "Godot"
    elif system == "Darwin":
        base = Path.home() / "Library" / "Application Support" / "Godot"
    else:
        base = Path(os.environ.get("XDG_DATA_HOME") or (Path.home() / ".local" / "share")) / "godot"
    return base / "export_templates" / TPL_DIR_NAME


def ensure_templates() -> Path:
    tpl_dir = templates_dir()
    if (tpl_dir / "windows_release_x86_64.exe").exists():
        log(f"Export templates already installed: {tpl_dir}")
        return tpl_dir
    tpz = GODOT_BIN_DIR / "templates.tpz"
    if not tpz.exists() or tpz.stat().st_size == 0:
        download(f"{GODOT_RELEASE_BASE}/Godot_v{GODOT_VERSION}_export_templates.tpz", tpz)
    tpl_dir.mkdir(parents=True, exist_ok=True)
    log(f"Installing export templates into {tpl_dir}")
    with zipfile.ZipFile(tpz) as zf:
        for name in zf.namelist():
            if not name.startswith("templates/"):
                continue
            rel = name[len("templates/"):]
            if not rel:
                continue
            if not (rel.startswith("windows_") or rel.startswith("linux_") or rel == "version.txt"):
                continue  # keep the unpack footprint small (windows + linux only)
            target = tpl_dir / rel
            target.parent.mkdir(parents=True, exist_ok=True)
            with zf.open(name) as src, open(target, "wb") as dst:
                shutil.copyfileobj(src, dst)
            if platform.system() != "Windows":
                target.chmod(0o755)
    if not (tpl_dir / "windows_release_x86_64.exe").exists():
        raise RuntimeError("windows_release_x86_64.exe missing after template extraction")
    return tpl_dir


def run_headless_export(godot_exe: Path, out_exe: Path) -> None:
    def run(args: list[str]) -> None:
        log("+ " + " ".join(args))
        res = subprocess.run(args, cwd=str(ROOT_DIR))
        if res.returncode != 0:
            raise RuntimeError(f"command failed (code {res.returncode}): {' '.join(args)}")

    log("Step 1/2: refreshing .godot import cache (headless import)...")
    run([str(godot_exe), "--headless", "--path", str(ROOT_DIR), "--import"])
    log(f"Step 2/2: exporting preset '{EXPORT_PRESET}' -> {out_exe.name}")
    run([str(godot_exe), "--headless", "--path", str(ROOT_DIR),
         "--export-release", EXPORT_PRESET, str(out_exe)])


def verify_build(out_exe: Path) -> None:
    pck = out_exe.with_suffix(".pck")
    if not out_exe.exists():
        raise RuntimeError("FATAL: export produced no DroneFlames.exe — refusing to package sources")
    if not pck.exists():
        raise RuntimeError("FATAL: export produced no DroneFlames.pck — refusing to package sources")
    if pck.stat().st_size < 1_000_000:
        raise RuntimeError("FATAL: DroneFlames.pck is suspiciously small")
    with open(out_exe, "rb") as f:
        if f.read(2) != b"MZ":
            raise RuntimeError("FATAL: exported exe is not a valid Windows binary (no MZ header)")
    with open(pck, "rb") as f:
        if f.read(4) != b"GDPC":
            raise RuntimeError("FATAL: .pck has invalid magic (not a Godot package)")
    log(f"[OK] Verified: {out_exe.name} = {out_exe.stat().st_size / 1048576:.1f} MB, "
        f"{pck.name} = {pck.stat().st_size / 1048576:.1f} MB")


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


LAUNCHER_BAT = (
    "@echo off\r\n"
    "title DroneFlames Reborn\r\n"
    "start \"\" \"%~dp0DroneFlames.exe\"\r\n"
)

DEBUG_BAT = (
    "@echo off\r\n"
    "title DroneFlames Reborn (Debug)\r\n"
    "start \"\" \"%~dp0DroneFlames.exe\" --verbose --log-file \"%~dp0debug.log\"\r\n"
    "echo Debug logs: debug.log (next to the game)\r\n"
)

README_TXT = f"""DroneFlames Reborn v{VERSION}
=============================

ЗАПУСК ИГРЫ
    DroneFlames.exe — обычный запуск (или Start_DroneFlames.bat).
    DroneFlames_Debug.bat — отладочный запуск: подробные логи
    пишутся в debug.log рядом с игрой.

ТРЕБОВАНИЯ
    Windows 10/11 x64. Графика: OpenGL 3.3 / Vulkan.

МОДЫ
    Кладите моды (.dfmod) в папку mods рядом с игрой.

МУЛЬТИПЛЕЕР
    Локальная сеть / VPN (Radmin, Hamachi): хост создаёт комнату,
    игроки подключаются по IP из плашки лобби. Игра переживает
    обрывы соединения: реконнект, позднее подключение и
    консенсусная скорость партии включены по умолчанию.

ДИСКЛЕЙМЕР
    Фанатская некоммерческая сборка. Команда Reborn ни на что не
    претендует: все права на оригинальную игру принадлежат её
    правообладателям.
"""


def main() -> int:
    log(f"=== Building {APP_NAME} v{VERSION} (Reborn Team) ===")

    if STAGE_DIR.exists():
        log(f"Cleaning existing stage dir: {STAGE_DIR}")
        shutil.rmtree(STAGE_DIR)
    STAGE_DIR.mkdir(parents=True, exist_ok=True)
    DIST_DIR.mkdir(parents=True, exist_ok=True)

    # 1. Toolchain: Godot editor + export templates (real export this time)
    godot_exe = godot_bin_path()
    ensure_templates()

    # 2. Export the actual game
    out_exe = STAGE_DIR / EXE_NAME
    run_headless_export(godot_exe, out_exe)
    verify_build(out_exe)

    # 3. Debug launcher (writes debug.log next to the game)
    (STAGE_DIR / "DroneFlames_Debug.bat").write_text(DEBUG_BAT, encoding="ascii")
    log("[OK] DroneFlames_Debug.bat (verbose + debug.log) added")

    # 4. Launcher + metadata + readme
    (STAGE_DIR / "Start_DroneFlames.bat").write_text(LAUNCHER_BAT, encoding="ascii")
    for meta in ("version_info.json", "app_icon.ico"):
        src = ROOT_DIR / meta
        if src.exists():
            shutil.copy2(src, STAGE_DIR / meta)
        else:
            log(f"  [Warning] missing metadata file: {meta}")
    (STAGE_DIR / "README.txt").write_text(README_TXT, encoding="utf-8-sig")

    # 5. Portable ZIP
    zip_path = DIST_DIR / f"{STAGE_NAME}.zip"
    log(f"Creating Portable ZIP archive: {zip_path.name}...")
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as zf:
        for file_path in sorted(STAGE_DIR.rglob("*")):
            if file_path.is_file():
                zf.write(file_path, file_path.relative_to(BUILD_DIR).as_posix())
    log(f"  [OK] Portable ZIP created: {zip_path.name} ({zip_path.stat().st_size / 1048576:.2f} MB)")

    # 6. Inno Setup installer
    iscc = find_iscc()
    if iscc:
        iss_path = ROOT_DIR / "installer.iss"
        if iss_path.exists():
            log(f"Compiling Inno Setup installer with {iscc}...")
            cmd = [iscc, f"/DMyAppVersion={VERSION}",
                   f"/DSourceDir={STAGE_DIR}", f"/DOutDir={DIST_DIR}", str(iss_path)]
            res = subprocess.run(cmd)
            if res.returncode != 0:
                raise RuntimeError(f"Inno Setup compilation failed (code {res.returncode})")
            setup_exe = DIST_DIR / f"{APP_NAME}_PC_Setup_v{VERSION}.exe"
            if setup_exe.exists():
                log(f"  [OK] Windows Installer created: {setup_exe.name} "
                    f"({setup_exe.stat().st_size / 1048576:.2f} MB)")
            else:
                raise RuntimeError("Inno Setup finished but the Setup exe was not produced")
        else:
            raise RuntimeError("installer.iss not found in repository root")
    else:
        msg = "Inno Setup (ISCC.exe) not found — installer .exe was NOT built."
        if platform.system() == "Windows":
            raise RuntimeError(msg)  # on CI/Windows this is a real failure
        log(f"  [Notice] {msg} (non-Windows host, portable ZIP still valid)")

    log("\n=== Build Complete! Files in dist/: ===")
    for item in sorted(DIST_DIR.iterdir()):
        if item.is_file():
            log(f"  - {item.name} ({item.stat().st_size / 1048576:.2f} MB)")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as exc:  # noqa: BLE001
        log(f"BUILD FAILED: {exc}")
        sys.exit(1)
