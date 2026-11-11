extends RefCounted
## MP RESILIENCE test (RESILIENT 1..5): two headless instances in a real running match.
##   LAN   (ENet):      --mp-resilience=lan-host   /  --mp-resilience=lan-guest
##   RELAY (local WSS): --mp-resilience=relay-host /  --mp-resilience=relay-guest
##     with net/server/signal_server.gd run as: -- --port=19090 --bind=127.0.0.1 --open
##     and signal_url=ws://127.0.0.1:19090/mp/signal in user://net.cfg
## PASS: both stay in the match with turns flowing; the guest's backlog stays small.
## Resyncs/desyncs are counted, not failed — they exercise the machinery under test.

var main: Node
var net: NetSession
var role: String
var t0: int = 0
var report_at: int = 0
var stall_max: float = 0.0
var holds_seen: int = 0

const CODE_FILE: String = "/tmp/df_room_code"

func run(m: Node, r: String) -> void:
	main = m
	role = r
	net = main.net
	var tree: SceneTree = main.get_tree()
	for i in 300:
		if main.menus.current == "main":
			break
		await tree.create_timer(0.1).timeout
	NetConfig.set_nick("ResHost" if r.contains("host") else "ResGuest")
	NetConfig.test_speed = 8.0  # 8x sim speed: more turns and hash checks in the same wall time
	if r == "lan-guest" or r == "relay-guest":
		await tree.create_timer(4.0).timeout
	var res: String = ""
	if r == "lan-host":
		res = net.host_lan()
		print("[MP-RES] host: LAN room open, waiting for the guest...")
	elif r == "lan-guest":
		res = net.join_lan("127.0.0.1")
	elif r == "relay-host":
		res = net.host_online(false)
		var got_code: bool = false
		for i in 1500:
			if net.room_code != "":
				got_code = true
				break
			await tree.create_timer(0.1).timeout
		if not got_code:
			push_error("[MP-RES] host: the server gave no room code (%s)" % net.status_text)
			tree.quit(1)
			return
		var f: FileAccess = FileAccess.open(CODE_FILE, FileAccess.WRITE)
		if f != null:
			f.store_line(net.room_code)
			f.close()
		print("[MP-RES] host: online room %s open, waiting for the guest..." % net.room_code)
	elif r == "relay-guest":
		var code: String = ""
		for i in 1500:
			if FileAccess.file_exists(CODE_FILE):
				code = FileAccess.open(CODE_FILE, FileAccess.READ).get_line().strip_edges()
				if code != "":
					break
			await tree.create_timer(0.5).timeout
		if code == "":
			push_error("[MP-RES] guest: no room code appeared")
			tree.quit(1)
			return
		print("[MP-RES] guest: joining online room %s..." % code)
		res = net.join_online(code)
	if res != "":
		push_error("[MP-RES] " + r + " join failed: " + res)
		tree.quit(1)
		return
	if r == "lan-host" or r == "relay-host":
		var started: bool = false
		for i in 1500:  # 150 s: both instances boot slowly headless
			if net.slots.size() >= 2 and not net.in_match:
				var err: String = net.host_start()
				if err == "":
					started = true
					print("[MP-RES] host started the match")
					break
			if i % 100 == 99:
				print("[MP-RES] host: waiting for the guest (slots=%d, status=%s)" % [net.slots.size(), net.status_text])
			await tree.create_timer(0.1).timeout
		if not started:
			push_error("[MP-RES] host never started (slots=%d, status=%s)" % [net.slots.size(), net.status_text])
			tree.quit(1)
			return
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 240000:  # the world builds can take a while headless
		await tree.create_timer(1.0).timeout
		if net.in_match and net.go and net.exec_turn > 0:
			break
	if not (net.in_match and net.go):
		push_error("[MP-RES] %s: the match never started flowing (in_match=%s go=%s status=%s)" % [role, str(net.in_match), str(net.go), net.status_text])
		tree.quit(1)
		return
	print("[MP-RES] %s: the match flows (t=%ds)" % [role, (Time.get_ticks_msec() - t0) / 1000])
	report_at = Time.get_ticks_msec()
	var watch_t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - watch_t0 < 40000:
		await tree.create_timer(0.5).timeout
		if not net.in_match or not net.go:
			continue
		stall_max = maxf(stall_max, net.stall_t)
		if net.hold_who != "":
			holds_seen += 1
		if Time.get_ticks_msec() - report_at >= 10000:
			report_at = Time.get_ticks_msec()
			print("[MP-RES] %s exec=%d last=%d stall=%.1f resyncs=%d desyncs=%d tick_ms=%.1f" % [
				role, net.exec_turn, net.last_turn, net.stall_t, net.resyncs, net.desyncs, net.perf_tick_ms])
	var behind: int = net.last_turn - net.exec_turn
	var ok: bool = net.in_match and net.go and (not r.contains("guest") or behind <= 30)
	print("[MP-RES] RESULT %s: go=%s exec=%d last=%d behind=%d stall_max=%.1f holds=%d resyncs=%d desyncs=%d asks=%d tick_ms=%.1f" % [
		role, str(net.go), net.exec_turn, net.last_turn, behind, stall_max, holds_seen, net.resyncs, net.desyncs, net.resync_asks, net.perf_tick_ms])
	if ok:
		print("[MP-RES] PASS ", role)
		tree.quit(0)
	else:
		push_error("[MP-RES] FAIL " + role)
		tree.quit(1)
