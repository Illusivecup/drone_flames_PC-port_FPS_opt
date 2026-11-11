extends RefCounted

func run(main: Node, role: String) -> void:
	var tree: SceneTree = main.get_tree()
	for i in 300:
		if main.menus.current == "main":
			break
		await tree.create_timer(0.1).timeout
	var net: NetSession = main.net
	NetConfig.set_nick("TestHost" if role == "host" else "TestClient")
	if role == "client":
		await tree.create_timer(4.0).timeout
	var result: String = net.host_lan() if role == "host" else net.join_lan("127.0.0.1")
	if result != "":
		push_error("[LAN-TEST] " + role + " failed: " + result)
		tree.quit(1)
		return
	for i in 250:
		if net.slots.size() >= 2 and (role == "host" or net.local_slot >= 1):
			print("[LAN-TEST] PASS ", role, " slots=", net.slots.size(), " local=", net.local_slot)
			await tree.create_timer(2.0).timeout
			net.leave()
			tree.quit(0)
			return
		await tree.create_timer(0.1).timeout
	push_error("[LAN-TEST] " + role + " timeout: " + net.status_text)
	tree.quit(1)
