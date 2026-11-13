"""Exercise the Linux installer against the real export without publishing a release."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
archive = Path(sys.argv[1]).resolve()
manifest = json.loads((ROOT / "version_info.json").read_text(encoding="utf-8"))
version = manifest["version"]
channel = "test" if version.endswith("-test") else "stable"
package = "droneflames-test" if channel == "test" else "droneflames"
tag = "v" + version
digest = hashlib.sha256()
with archive.open("rb") as handle:
    for chunk in iter(lambda: handle.read(1024 * 1024), b""):
        digest.update(chunk)

def metadata(version_tag, checksum):
    name = f"DroneFlames_Linux_x86_64_{version_tag}_droneflamesmod.tar.gz"
    return [{
        "tag_name": version_tag,
        "prerelease": channel == "test",
        "assets": [{
            "name": name,
            "state": "uploaded",
            "digest": "sha256:" + checksum,
            "browser_download_url": f"https://github.com/makkaX2/DroneFlames-PC-Port/releases/download/{version_tag}/{name}",
        }],
    }]

with tempfile.TemporaryDirectory(prefix="droneflames-linux-") as tmp:
    root = Path(tmp)
    home = root / "home with spaces"
    data = root / "xdg data"
    fixture_bin = root / "bin"
    fixture_bin.mkdir()
    fixture_json = root / "release.json"
    curl = fixture_bin / "curl"
    curl.write_text("""#!/usr/bin/env bash
set -eu
while (($#)); do
    case "$1" in
        -o) out="$2"; shift 2 ;;
        https://api.github.com/*) source="$FIXTURE_JSON"; shift ;;
        https://github.com/*) source="$FIXTURE_ARCHIVE"; shift ;;
        *) shift ;;
    esac
done
cp -- "$source" "$out"
""")
    curl.chmod(0o755)
    env = dict(os.environ, HOME=str(home), XDG_DATA_HOME=str(data),
               XDG_CONFIG_HOME=str(root / "config"), XDG_STATE_HOME=str(root / "state"),
               PATH=f"{fixture_bin}:{os.environ['PATH']}", FIXTURE_JSON=str(fixture_json),
               FIXTURE_ARCHIVE=str(archive), DF_SKIP_GRAPHICS_SETUP="1")
    install_root = data / package
    install_root.mkdir(parents=True)
    legacy_file = install_root / "legacy checkout or portable saves"
    legacy_file.write_text("keep me")
    saves = data / "DroneFlames-PC-Port_good_boy_irl"
    saves.mkdir()
    save = saves / "save fixture"
    save.write_text("keep me too")
    previous = install_root / ".releases" / "previous"
    previous.mkdir(parents=True)
    (previous / "version_info.json").write_text(json.dumps({"version": "0.32.0"}))
    (install_root / ".current").symlink_to(previous)
    install = ["bash", str(ROOT / "install.sh"), "--channel", channel]

    fixture_json.write_text(json.dumps(metadata(tag, digest.hexdigest())))
    subprocess.run(install, env=env, check=True)
    current = (install_root / ".current").resolve()
    assert current != previous
    assert json.loads((current / "version_info.json").read_text())["version"] == version
    assert (previous / "version_info.json").exists()
    launcher = home / ".local" / "bin" / package
    boot = subprocess.run([str(launcher), "--headless", "--max-fps", "60", "--quit-after", "900"],
                          env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=90)
    print(boot.stdout)
    assert boot.returncode == 0 and "[MainReady]" in boot.stdout and "SCRIPT ERROR" not in boot.stdout

    subprocess.run(install, env=env, check=True)
    assert (install_root / ".current").resolve() == current
    fixture_json.write_text(json.dumps(metadata("v99.0.0.0" + ("-test" if channel == "test" else ""), "0" * 64)))
    failed = subprocess.run(install, env=env, capture_output=True, text=True)
    assert failed.returncode != 0 and "Контрольная сумма" in failed.stderr
    assert (install_root / ".current").resolve() == current
    assert legacy_file.read_text() == "keep me" and save.read_text() == "keep me too"
    print("Linux installer: update, launch, repeat install, checksum rejection and data preservation passed")
