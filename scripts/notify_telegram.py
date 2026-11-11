import os
import sys
import json
import glob
import subprocess
import urllib.request

tg_token = os.environ.get("TG_BOT_TOKEN")
chat_id = os.environ.get("TG_CHAT_ID")
tag = os.environ.get("TAG", "")
commit_sha = os.environ.get("COMMIT_SHA", "")
run_id = os.environ.get("RUN_ID", "")
is_test = os.environ.get("IS_TEST", "false").lower() == "true" or "test" in tag.lower()

if not tg_token or not chat_id:
    print("TG_BOT_TOKEN or TG_CHAT_ID not set, skipping Telegram notification.")
    sys.exit(0)

try:
    commit_desc = subprocess.check_output(["git", "log", "-1", "--pretty=format:%B"]).decode("utf-8").strip()
    commit_author = subprocess.check_output(["git", "log", "-1", "--pretty=%an"]).decode("utf-8").strip()
except Exception:
    commit_desc = "release build"
    commit_author = "unknown"

short_sha = commit_sha[:7] if commit_sha else "unknown"
repo = "makkaX2/DroneFlames-PC-Port"
base_url = f"https://github.com/{repo}"
rel_url = f"{base_url}/releases/tag/{tag}"
com_url = f"{base_url}/commit/{commit_sha}"

def dl_url(fname):
    return f"{base_url}/releases/download/{tag}/{os.path.basename(fname)}"

apk_files = glob.glob("dist/*.apk")
win_files = [f for f in glob.glob("dist/*.zip") if "PC" in f or "macOS" not in f]
win_setups = glob.glob("dist/*.exe")
mac_files = glob.glob("dist/*.dmg")

artifact_lines = []
dl_buttons = []

if win_files:
    wname = os.path.basename(win_files[0])
    artifact_lines.append(f"- windows: {wname}")
    dl_buttons.append({"text": "[windows zip]", "url": dl_url(win_files[0])})

if win_setups:
    sname = os.path.basename(win_setups[0])
    artifact_lines.append(f"- win-installer: {sname}")
    dl_buttons.append({"text": "[windows exe]", "url": dl_url(win_setups[0])})

if mac_files:
    mname = os.path.basename(mac_files[0])
    artifact_lines.append(f"- macos: {mname}")
    dl_buttons.append({"text": "[macos dmg]", "url": dl_url(mac_files[0])})

if apk_files:
    aname = os.path.basename(apk_files[0])
    artifact_lines.append(f"- android: {aname}")
    dl_buttons.append({"text": "[android apk]", "url": dl_url(apk_files[0])})

if not artifact_lines:
    artifact_lines.append("- (no files)")

artifacts_str = "\n".join(artifact_lines)

header = f"[build:test] {tag}" if is_test else f"[build:release] {tag}"
branch_name = "test" if is_test else "master"

text = f"""{header}
branch: {branch_name}
commit: {short_sha}
author: {commit_author}
url: {com_url}

commit description:
{commit_desc}

artifacts:
{artifacts_str}"""

buttons = []
if dl_buttons:
    buttons.append(dl_buttons)

buttons.append([
    {"text": "[release notes]", "callback_data": "notes"},
    {"text": "[check updates]", "callback_data": "check_now"}
])
buttons.append([
    {"text": "[release url]", "url": rel_url},
    {"text": "[commit url]", "url": com_url}
])

payload = {
    "chat_id": int(chat_id),
    "text": text,
    "disable_web_page_preview": True,
    "reply_markup": {"inline_keyboard": buttons}
}

req = urllib.request.Request(
    f"https://api.telegram.org/bot{tg_token}/sendMessage",
    data=json.dumps(payload).encode("utf-8"),
    headers={"Content-Type": "application/json"}
)
try:
    with urllib.request.urlopen(req) as resp:
        resp_data = json.loads(resp.read().decode("utf-8"))
        print("Telegram notification sent successfully:", resp.status)
        if resp_data.get("ok") and "result" in resp_data and "message_id" in resp_data["result"]:
            msg_id = resp_data["result"]["message_id"]
            pin_payload = {
                "chat_id": int(chat_id),
                "message_id": msg_id,
                "disable_notification": False
            }
            pin_req = urllib.request.Request(
                f"https://api.telegram.org/bot{tg_token}/pinChatMessage",
                data=json.dumps(pin_payload).encode("utf-8"),
                headers={"Content-Type": "application/json"}
            )
            try:
                with urllib.request.urlopen(pin_req) as pin_resp:
                    print("Telegram message pinned successfully:", pin_resp.status)
            except Exception as pe:
                print("Failed to pin Telegram message (bot may need admin rights to pin):", pe)
except Exception as e:
    print("Failed to send Telegram notification:", e)
