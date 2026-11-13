"""Export guest statistics, verify a local archive, and apply a checked migration."""
import argparse
import csv
import hashlib
import json
import os
from pathlib import Path
import stat
import sys
import tempfile


FIELDS = (
    "playtime_s", "matches_played", "wins", "losses", "solo_wins",
    "created_at", "last_seen",
)


def read_database(path):
    raw = path.read_bytes()
    users = json.loads(raw)
    if not isinstance(users, dict) or any(
        not isinstance(user, dict) or user.get("is_registered", False) not in (True, False)
        for user in users.values()
    ):
        raise ValueError("Unexpected users database format")
    return raw, users


def guest_snapshot(raw, users):
    rows = []
    for key, user in users.items():
        if not user.get("is_registered", False):
            rows.append({
                "key": key, "username": user.get("username", key),
                **{field: user.get(field, 0) for field in FIELDS},
            })
    return {
        "schema": 1,
        "source_sha256": hashlib.sha256(raw).hexdigest(),
        "registered": len(users) - len(rows),
        "guests": rows,
    }


def archive(snapshot, destination):
    if snapshot["schema"] != 1 or not isinstance(snapshot["guests"], list):
        raise ValueError("Unexpected archive format")
    rows = snapshot["guests"]
    destination.mkdir(parents=True, exist_ok=False)
    json_path = destination / "guests.json"
    csv_path = destination / "guests.csv"
    json_path.write_text(json.dumps(snapshot, ensure_ascii=False, indent=2), encoding="utf-8")
    with csv_path.open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=("key", "username", *FIELDS))
        writer.writeheader()
        for row in rows:
            writer.writerow({
                key: "'" + value if isinstance(value, str) and value.startswith(("=", "+", "-", "@")) else value
                for key, value in row.items()
            })
    (destination / "RESTORE.md").write_text(
        "# Восстановление статистики\n\n"
        "Найдите гостевую запись в guests.json по старому нику и подтвердите владельца. "
        "Запишите идентификатор нового зарегистрированного аккаунта отдельно. "
        "Совпадение ников само по себе не подтверждает владельца.\n\n"
        "Сделайте резервную копию актуальной базы и остановите запись на время восстановления. "
        "Перенесите согласованные значения счётчиков в выбранный аккаунт, сохранив его "
        "идентификатор, пароль, сессии, профиль и социальные данные. Зафиксируйте перенос, "
        "чтобы не применить его повторно. После запуска сервера проверьте профиль и топ.\n",
        encoding="utf-8",
    )
    if json.loads(json_path.read_text(encoding="utf-8")) != snapshot:
        raise ValueError("JSON archive verification failed")
    with csv_path.open(encoding="utf-8-sig", newline="") as handle:
        if sum(1 for _ in csv.DictReader(handle)) != len(rows):
            raise ValueError("CSV archive verification failed")


def apply(database, archived):
    raw, users = read_database(database)
    snapshot = guest_snapshot(raw, users)
    if not snapshot["guests"]:
        return 0
    if snapshot != archived:
        raise ValueError("Database changed or the verified archive is incomplete")
    registered = {key: user for key, user in users.items() if user.get("is_registered", False)}
    original = database.stat()
    temp_path = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w", encoding="utf-8", dir=database.parent, delete=False,
        ) as handle:
            temp_path = Path(handle.name)
            json.dump(registered, handle, ensure_ascii=False, indent=2)
            handle.flush()
            os.fsync(handle.fileno())
        os.chmod(temp_path, stat.S_IMODE(original.st_mode))
        if hasattr(os, "chown"):
            os.chown(temp_path, original.st_uid, original.st_gid)
        if read_database(temp_path)[1] != registered or database.read_bytes() != raw:
            raise ValueError("Database changed or staged migration could not be verified")
        os.replace(temp_path, database)
    finally:
        if temp_path is not None:
            temp_path.unlink(missing_ok=True)
    return len(snapshot["guests"])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("snapshot").add_argument("database", type=Path)
    commands.add_parser("archive").add_argument("destination", type=Path)
    apply_parser = commands.add_parser("apply", help="Run while the database writer is stopped")
    apply_parser.add_argument("database", type=Path)
    apply_parser.add_argument("archive", type=Path)
    args = parser.parse_args()
    if args.command == "snapshot":
        print(json.dumps(guest_snapshot(*read_database(args.database)), ensure_ascii=True))
    elif args.command == "archive":
        snapshot = json.load(sys.stdin)
        archive(snapshot, args.destination)
        print(f"Archived {len(snapshot['guests'])} guest records")
    else:
        print(f"Removed {apply(args.database, json.loads(args.archive.read_text(encoding='utf-8')))} guest records")


if __name__ == "__main__":
    main()
