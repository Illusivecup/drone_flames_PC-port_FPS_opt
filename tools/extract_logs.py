import subprocess
import sys
import tempfile

def run_remote(cmd: str):
    with tempfile.NamedTemporaryFile("w", encoding="utf-8", suffix=".sh", delete=False) as f:
        f.write(cmd)
        f_name = f.name
    res = subprocess.run(
        [sys.executable, "C:/Users/mxka/.codex/servers/remnawave-ssh.py", "--script", f_name],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace"
    )
    return res.stdout, res.stderr

if __name__ == "__main__":
    cmd = """
journalctl -u df-relay-test.service -o cat --no-pager | grep -E '\\[RelayEvent\\]' | grep -v 'status_snapshot' | tail -n 80
"""
    out, err = run_remote(cmd)
    print("STDOUT:\n", out)
    if err:
        print("STDERR:\n", err)
