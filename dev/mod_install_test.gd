extends SceneTree
## Headless-тест установки модов DroneFlames Reborn.
## Запуск: godot --headless --path . --script res://dev/mod_install_test.gd

func _init() -> void:
	var failures: Array[String] = []
	print("=== MOD INSTALL TEST START ===")

	# 1. ModManager инициализируется и видит встроенные моды
	var mm: Node = load("res://core/mod_manager.gd").new()
	mm.name = "ModManager"
	root.add_child(mm)
	await process_frame
	await process_frame

	var builtins: Array = mm.installed_mods.keys()
	print("[1] scan_installed_mods: найдено модов = ", builtins.size())
	if builtins.is_empty():
		failures.append("Скан модов: 0 найдено (ожидался список встроенных)")

	# 2. Каталог встроенных модов
	var cat: Array = mm.get_full_catalog()
	print("[2] get_full_catalog: = ", cat.size())
	if cat.is_empty():
		failures.append("Каталог модов пуст")

	# 3. Установка встроенного мода в user://mods
	var test_id: String = ""
	for m in cat:
		if String(m.get("id", "")) != "":
			test_id = String(m.get("id"))
			break
	if test_id != "":
		var ok: bool = mm.install_builtin_mod(test_id)
		print("[3] install_builtin_mod(%s) -> %s" % [test_id, ok])
		if not ok:
			var err: String = String(mm.installed_mods.get(test_id, {}).get("_load_error", ""))
			failures.append("install_builtin_mod(%s) failed: %s" % [test_id, err])
	else:
		failures.append("Нет ни одного мода в каталоге для теста")

	# 4. Проверка папки user://mods
	var da: DirAccess = DirAccess.open("user://mods")
	var listing: Array[String] = []
	if da:
		da.list_dir_begin()
		var f: String = da.get_next()
		while f != "":
			listing.append(f)
			f = da.get_next()
		da.list_dir_end()
	print("[4] user://mods: ", listing)
	if listing.is_empty():
		failures.append("user://mods пуст после установки")

	# 5. Компиляция entry-скрипта установленного мода
	for mid in mm.installed_mods.keys():
		var loaded: bool = mm.is_mod_loaded(mid)
		var err2: String = String(mm.installed_mods[mid].get("_load_error", ""))
		print("[5] %s loaded=%s error='%s'" % [mid, loaded, err2])
		if not loaded and err2 != "":
			failures.append("Мод %s не загрузился: %s" % [mid, err2])

	print("=== RESULT: %s ===" % ("FAIL: " + "; ".join(failures) if failures.size() > 0 else "ALL OK"))
	quit(0 if failures.is_empty() else 1)
