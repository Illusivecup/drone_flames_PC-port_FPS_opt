class_name Reports
extends RefCounted




const USER_REASONS: Array = [["cheats", "ЧИТЫ", ""], ["chat_toxic", "ТОКСИЧНОСТЬ В ЧАТЕ", ""], 
	["unsporting", "НЕСПОРТИВНОЕ ПОВЕДЕНИЕ", "сдаётся нарочно, вредит союзнику"], 
	["bad_name_flag", "ОСКОРБИТЕЛЬНЫЙ НИК ИЛИ ФЛАГ", ""], ["other", "ДРУГОЕ", ""]]
const SERVER_REASONS: Array = [["high_ping", "ВЫСОКИЙ ПИНГ", ""], ["lag_desync", "ЛАГИ И РАССИНХРОНЫ", ""], 
	["disconnects", "РАЗРЫВЫ СОЕДИНЕНИЯ", ""], ["matchmaking", "ДОЛГИЙ ПОИСК СОПЕРНИКОВ", ""], ["other", "ДРУГОЕ", ""]]
const COMMENT_MAX: int = 300
const OTHER_MIN: int = 10

static var sent: Dictionary = {}


static func key(net: NetSession, seat: int) -> String:
	return "%s:%d" % [net.match_id, seat]



static func send_user(net: NetSession, cid: int, reasons: Array, comment: String) -> Dictionary:
	var seat: int = net.chat.seat_of_slot(net.chat.slot_of(cid))
	var body: Dictionary = {"match": net.match_id, "target_seat": seat, "reasons": reasons, "comment": comment.strip_edges().left(COMMENT_MAX), 
		"messages": net.chat.evidence(cid)}
	var r: Dictionary = await Api.i().call_api("POST", "/mp/user_report", body)
	var code: int = int(r["code"])
	if code == 201 or code == 409:
		sent[key(net, seat)] = true
	return {"ok": code == 201, "code": code, "why": _why(code, r["data"])}


static func send_server(net: NetSession, reasons: Array, comment: String) -> Dictionary:
	var body: Dictionary = {"match": net.match_id if net.match_id != "" else null, "reasons": reasons, 
		"comment": comment.strip_edges().left(COMMENT_MAX), "telemetry": net.net_stats()}
	var t0: int = Time.get_ticks_msec()
	var probe: Dictionary = await Api.i().call_api("GET", "/health", null, false)
	if int(probe["code"]) > 0:
		(body["telemetry"] as Dictionary)["api_ms"] = float(Time.get_ticks_msec() - t0)
	var r: Dictionary = await Api.i().call_api("POST", "/mp/server_report", body)
	var code: int = int(r["code"])
	return {"ok": code == 201, "code": code, "why": _why(code, r["data"])}


static func _why(code: int, data: Variant) -> String:
	var d: String = String((data as Dictionary).get("detail", "")) if data is Dictionary else ""
	match code:
		201:
			return "ЖАЛОБА ОТПРАВЛЕНА · СПАСИБО"
		409:
			return "НА ЭТОГО ИГРОКА ВЫ УЖЕ ПОЖАЛОВАЛИСЬ В ЭТОЙ ПАРТИИ"
		429:
			return "ЖАЛОБЫ ВРЕМЕННО НЕДОСТУПНЫ" if d == "Reports paused" else "СЛИШКОМ МНОГО ЖАЛОБ · ПОПРОБУЙТЕ ПОЗЖЕ"
		404:
			return "ПАРТИЯ НЕ НАЙДЕНА НА СЕРВЕРЕ"
		422:
			return "ДЛЯ «ДРУГОЕ» ОПИШИТЕ СИТУАЦИЮ" if d.contains("other") else "ПРОВЕРЬТЕ ПРИЧИНЫ"
		0:
			return "НЕТ СВЯЗИ С СЕРВЕРОМ · ПОВТОРИТЕ"
	return "ОШИБКА СЕРВЕРА %d · ПОВТОРИТЕ" % code
