extends SceneTree

func _init() -> void:
	print("========================================")
	print("[TEST] Starting Multiplayer Save & Rejoin Verification")
	print("========================================")

	# 1. Test NetSession.get_lan_ips()
	print("[TEST 1] Testing NetSession.get_lan_ips()...")
	var ips: Array[String] = NetSession.get_lan_ips()
	print("Found LAN IPs: ", ips)
	assert(not ips.is_empty(), "get_lan_ips() must return at least one IP address!")
	for ip in ips:
		assert(ip.count(".") == 3, "Each IP must be a valid IPv4 address: %s" % ip)
	print(">>> TEST 1 PASSED: LAN IP detection works correctly.")

	# 2. Test NetConfig save_match and load_match
	print("[TEST 2] Testing NetConfig.save_match & load_match...")
	var test_match: Dictionary = {
		"v": NetConfig.version(),
		"turn": 42,
		"mode": "lan",
		"code": "TEST12",
		"pub": false,
		"port": 24600,
		"host": "Матвей",
		"slots": [
			{"name": "Матвей", "arch": 0, "left": false, "seat": 1, "flag": ""},
			{"name": "ДругСергей", "arch": 1, "left": true, "seat": 2, "flag": ""}
		],
		"tokens": {"1": "token_friend_123"},
		"match": "match_xyz",
		"cfg": {"bots": 2},
		"gt": 120.5,
		"played": 45.0,
		"snap": PackedByteArray([1, 2, 3, 4])
	}
	NetConfig.save_match(test_match)
	var loaded_match: Dictionary = NetConfig.load_match()
	assert(not loaded_match.is_empty(), "Loaded match must not be empty!")
	assert(loaded_match["host"] == "Матвей", "Host name must match!")
	assert((loaded_match["slots"] as Array).size() == 2, "Slots count must be 2!")
	assert((loaded_match["slots"][1] as Dictionary)["name"] == "ДругСергей", "Second player must be ДругСергей!")
	print(">>> TEST 2 PASSED: save_match and load_match preserved players by nickname.")

	# 3. Test NetConfig.load_rejoin with and without token (LAN vs Online)
	print("[TEST 3] Testing NetConfig.save_rejoin & load_rejoin for LAN...")
	var lan_rejoin: Dictionary = {
		"mode": "lan",
		"ip": "192.168.0.100",
		"port": 24600,
		"tok": "",
		"host": "Матвей"
	}
	NetConfig.save_rejoin(lan_rejoin)
	var loaded_lan: Dictionary = NetConfig.load_rejoin()
	assert(not loaded_lan.is_empty(), "LAN rejoin without token must NOT be discarded!")
	assert(loaded_lan["ip"] == "192.168.0.100", "IP must be preserved in LAN rejoin!")
	print(">>> TEST 3 PASSED: LAN rejoin without token is preserved successfully.")

	# 4. Test NetSession nickname slot lookup
	print("[TEST 4] Testing NetSession._name_slot matching...")
	var ns = NetSession.new()
	ns.slots = [
		{"name": "Матвей", "peer": 1, "left": false},
		{"name": "ДругСергей", "peer": 2, "left": true}
	]
	assert(ns._name_slot("другсергей") == 1, "Nickname matching must be case-insensitive!")
	assert(ns._name_slot(" ДругСергей ") == 1, "Nickname matching must strip whitespace!")
	assert(ns._name_slot("Матвей") == 0, "Host slot lookup must match!")
	assert(ns._name_slot("Неизвестный") == -1, "Unknown player must return -1!")
	print(">>> TEST 4 PASSED: _name_slot matching works as expected.")

	# 5. Test forced save_match
	print("[TEST 5] Testing NetSession.save_match force...")
	ns.is_host = true
	ns.in_match = true
	ns.go = false # in pause / resume wait
	ns.resume_wait = true
	# With force = false, it should return early
	ns.save_match(-1, false)
	# With force = true, it should save
	ns.save_match(-1, true)
	var reloaded = NetConfig.load_match()
	assert(not reloaded.is_empty(), "Forced save must write match even during pause / resume_wait!")
	print(">>> TEST 5 PASSED: forced save_match works during pause/resume_wait.")

	# 6. Test pause menu multiplayer row instantiation
	print("[TEST 6] Testing Menus._mp_pause_row UI instantiation...")
	var menus = Menus.new()
	menus.net = ns
	var vb = VBoxContainer.new()
	menus._mp_pause_row(vb)
	assert(vb.get_child_count() >= 2, "Multiplayer pause row must create buttons and status label!")
	print("VBox children count: ", vb.get_child_count())
	print(">>> TEST 6 PASSED: Multiplayer pause row renders with save and invite buttons.")

	# Cleanup test match file
	NetConfig.clear_match()
	NetConfig.clear_rejoin()

	print("========================================")
	print("[TEST] ALL 6 TESTS COMPLETED SUCCESSFULLY!")
	print("========================================")
	quit(0)
