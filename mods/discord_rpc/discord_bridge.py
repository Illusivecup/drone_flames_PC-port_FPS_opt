"""
Discord Rich Presence Bridge for DroneFlames PC Port
Author: @good_boy_irl & @CryptoAngelazaz
Connects to Discord IPC Named Pipe and mirrors presence from discord_state.json.
"""

import sys
import os
import time
import json
import struct
import ctypes

CLIENT_ID = "1566515978806759500"

def get_log_path(state_path: str) -> str:
    base_dir = os.path.dirname(os.path.abspath(state_path))
    return os.path.join(base_dir, "discord_rpc.log")

def log(state_path: str, msg: str):
    try:
        lp = get_log_path(state_path)
        t = time.strftime("%Y-%m-%d %H:%M:%S")
        with open(lp, "a", encoding="utf-8") as lf:
            lf.write(f"[{t}] {msg}\n")
    except Exception:
        pass

def is_pid_running(pid: int) -> bool:
    if pid <= 0:
        return True
    PROCESS_QUERY_LIMITED_INFORMATION = 0x1000
    STILL_ACTIVE = 259
    h = ctypes.windll.kernel32.OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, False, pid)
    if not h:
        return False
    code = ctypes.c_ulong()
    res = ctypes.windll.kernel32.GetExitCodeProcess(h, ctypes.byref(code))
    ctypes.windll.kernel32.CloseHandle(h)
    return bool(res and code.value == STILL_ACTIVE)

def connect_discord_pipe(client_id: str):
    for i in range(10):
        pipe_path = f"\\\\.\\pipe\\discord-ipc-{i}"
        try:
            pipe = open(pipe_path, "r+b", buffering=0)
            # Perform handshake
            handshake = json.dumps({"v": 1, "client_id": client_id}).encode("utf-8")
            pipe.write(struct.pack("<II", 0, len(handshake)) + handshake)
            h = pipe.read(8)
            if len(h) == 8:
                op, length = struct.unpack("<II", h)
                resp = pipe.read(length)
                return pipe
            pipe.close()
        except Exception:
            continue
    return None

def send_activity(pipe, activity_dict):
    payload = {
        "cmd": "SET_ACTIVITY",
        "args": {
            "pid": os.getpid(),
            "activity": activity_dict if activity_dict else None
        },
        "nonce": str(time.time())
    }
    data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    pipe.write(struct.pack("<II", 1, len(data)) + data)
    h = pipe.read(8)
    if len(h) == 8:
        op, length = struct.unpack("<II", h)
        resp = pipe.read(length)
        return resp
    return None

def main():
    if len(sys.argv) < 2:
        print("Usage: discord_bridge.py <state_json_path> [parent_pid]")
        sys.exit(1)

    state_path = sys.argv[1]
    parent_pid = int(sys.argv[2]) if len(sys.argv) > 2 else 0

    log(state_path, f"Discord bridge started. Parent PID: {parent_pid}")

    pipe = None
    last_state_raw = ""

    while True:
        # Check if parent game process died
        if parent_pid > 0 and not is_pid_running(parent_pid):
            log(state_path, "Parent game process exited. Shutting down bridge.")
            if pipe:
                try:
                    send_activity(pipe, None)
                    pipe.close()
                except Exception:
                    pass
            sys.exit(0)

        # Check if state file exists
        if not os.path.exists(state_path):
            time.sleep(1.0)
            continue

        state_raw = ""
        try:
            with open(state_path, "r", encoding="utf-8") as f:
                state_raw = f.read().strip()
        except Exception:
            time.sleep(1.0)
            continue

        if not state_raw:
            time.sleep(1.0)
            continue

        try:
            state_data = json.loads(state_raw)
        except Exception:
            time.sleep(1.0)
            continue

        # Check shutdown flag
        if state_data.get("shutdown", False):
            log(state_path, "Shutdown signal received. Exiting.")
            if pipe:
                try:
                    send_activity(pipe, None)
                    pipe.close()
                except Exception:
                    pass
            sys.exit(0)

        cur_client_id = str(state_data.get("client_id", CLIENT_ID))

        # If pipe not connected, attempt connection
        if pipe is None:
            pipe = connect_discord_pipe(cur_client_id)
            if pipe is None:
                time.sleep(2.5)
                continue
            log(state_path, f"Connected to Discord IPC pipe using client_id {cur_client_id}")
            last_state_raw = ""  # Force resend on reconnect

        # If state changed, update presence
        if state_raw != last_state_raw:
            activity = {}
            if "details" in state_data:
                activity["details"] = state_data["details"]
            if "state" in state_data:
                activity["state"] = state_data["state"]
            if "timestamps" in state_data and isinstance(state_data["timestamps"], dict):
                activity["timestamps"] = state_data["timestamps"]
            if "assets" in state_data and isinstance(state_data["assets"], dict):
                activity["assets"] = state_data["assets"]
            if "buttons" in state_data and isinstance(state_data["buttons"], list):
                activity["buttons"] = state_data["buttons"]

            try:
                resp = send_activity(pipe, activity)
                last_state_raw = state_raw
                log(state_path, f"Sent presence: {activity.get('details')} | {activity.get('state')}")
            except Exception as e:
                log(state_path, f"Send error: {e}. Reconnecting...")
                try:
                    pipe.close()
                except Exception:
                    pass
                pipe = None
                time.sleep(1.5)
                continue

        time.sleep(1.2)

if __name__ == "__main__":
    main()
