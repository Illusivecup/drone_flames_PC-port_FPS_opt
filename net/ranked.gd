class_name Ranked
extends RefCounted






const MODES: Array = ["1v1", "2v2", "3v3"]
const MODES_RU: Dictionary = {"1v1": "1V1", "2v2": "2V2", "3v3": "3V3"}
const PENDING_FILE: String = "user://ranked_pending.bin"

static var me: Dictionary = {}
static var _sending: bool = false



static func fetch_me() -> Dictionary:
	var r: Dictionary = await Api.i().call_api("GET", "/ranked/me")
	if int(r["code"]) == 200 and r["data"] is Dictionary:
		me = r["data"]
		return {"ok": true, "err": ""}
	return {"ok": false, "err": String(r["err"])}



static func mode_row(mode: String) -> Dictionary:
	for it: Dictionary in me.get("ratings", []):
		if String(it.get("mode", "")) == mode:
			return it
	return {"mode": mode, "rating": float(me.get("start_rating", 1000.0)), "peak": float(me.get("start_rating", 1000.0)), 
		"games": 0, "wins": 0, "losses": 0, "calibrating": true, "place": null}


static func calibration_games() -> int:
	return int(me.get("calibration_games", 10))



static func penalty() -> int:
	return int(me.get("penalty", 0))


static func leaderboard(mode: String, offset: int = 0, limit: int = 50) -> Dictionary:
	return await Api.i().call_api("GET", "/ranked/leaderboard?mode=%s&limit=%d&offset=%d" % [mode, limit, offset])


static func match_info(mid: String) -> Dictionary:
	return await Api.i().call_api("GET", "/ranked/match/%s" % mid)



static func report(mid: String, winner_team: Variant, left: Array) -> String:
	var all: Dictionary = _pending()
	if not all.has(mid):
		all[mid] = {"winner_team": winner_team, "left": left.slice(0, 5), "t": int(Time.get_unix_time_from_system())}
		_store(all)
	return await _send(mid)



static func flush_pending() -> void :
	if _sending or not Account.signed_in():
		return
	_sending = true
	for mid: String in _pending().keys():
		await _send(mid)
	_sending = false


static func _send(mid: String) -> String:
	var all: Dictionary = _pending()
	if not all.has(mid):
		return ""
	var it: Dictionary = all[mid]
	var r: Dictionary = await Api.i().call_api("POST", "/mp/match/%s/result" % mid, {"winner_team": it["winner_team"], "left": it["left"]})
	var code: int = int(r["code"])
	if code == 200 or code == 404 or code == 422:
		all = _pending()
		all.erase(mid)
		_store(all)
	if code == 200 and r["data"] is Dictionary:
		return String((r["data"] as Dictionary).get("status", ""))
	return "gone" if code == 404 else ""


static func _pending() -> Dictionary:
	var v: Variant = DeviceCheck.secure_load("ranked_pending", PENDING_FILE, "|df-ranked")
	return v if v is Dictionary else {}


static func _store(d: Dictionary) -> void :
	DeviceCheck.secure_store("ranked_pending", d, PENDING_FILE, "|df-ranked")



static func rating_text(row: Dictionary) -> String:
	if bool(row.get("calibrating", true)):
		return "КАЛИБРОВКА %d/%d" % [int(row.get("games", 0)), calibration_games()]
	return str(roundi(float(row.get("rating", 1000.0))))



static func why_ru(why: String) -> String:
	if why.begins_with("Поиск недоступен ещё"):
		return why.to_upper()
	return {
		"Рейтинговый режим недоступен": "РЕЖИМ ВРЕМЕННО ЗАКРЫТ", 
		"Поиск временно недоступен, попробуйте позже": "ПОИСК ВРЕМЕННО НЕДОСТУПЕН", 
		"Игрок отказался от партии, продолжаем поиск": "КТО-ТО ОТКАЗАЛСЯ · ИЩЕМ ДАЛЬШЕ", 
		"Партия не принята вовремя": "ВЫ НЕ ПРИНЯЛИ БОЙ ВОВРЕМЯ", 
		"Не все приняли партию, продолжаем поиск": "НЕ ВСЕ ПРИНЯЛИ · ИЩЕМ ДАЛЬШЕ", 
		"Игрок покинул лобби, продолжаем поиск": "ИГРОК ВЫШЕЛ · ИЩЕМ ДАЛЬШЕ", 
		"Игрок покинул лобби": "ИГРОК ВЫШЕЛ ИЗ ЛОББИ", 
		"Не удалось соединиться с игроками, продолжаем поиск": "НЕ УДАЛОСЬ СОЕДИНИТЬСЯ · ИЩЕМ ДАЛЬШЕ", 
		"Не удалось соединиться с игроками": "НЕ УДАЛОСЬ СОЕДИНИТЬСЯ С ИГРОКАМИ", 
		"Партия отменена: хост несколько раз покинул игру": "ПАРТИЯ ОТМЕНЕНА: ХОСТ НЕСКОЛЬКО РАЗ ВЫШЕЛ", 
	}.get(why, why.to_upper())
