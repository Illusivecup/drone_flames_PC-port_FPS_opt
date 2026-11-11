import sys
sys.path.append("tools")
from extract_logs import run_remote

cmd = """
python3 - << 'EOF'
import json
with open('/var/lib/df-relay-test/users_db.json', 'r', encoding='utf-8') as f:
    d = json.load(f)
keys_to_del = [k for k in d if k.startswith('TestPilot_')]
for k in keys_to_del:
    del d[k]
with open('/var/lib/df-relay-test/users_db.json', 'w', encoding='utf-8') as f:
    json.dump(d, f, ensure_ascii=False, indent=2)
print('CLEANED:', len(keys_to_del))
EOF
systemctl restart df-relay-test.service
"""
out, err = run_remote(cmd)
print(out)
if err: print("ERR:", err)
