class_name Loc
extends RefCounted




























const LANGS: PackedStringArray = ["ru", "uk", "en", "es"]

const LANG_NAMES: Dictionary = {"ru": "Русский", "uk": "Українська", "en": "English", "es": "Español"}
const SRC: String = "ru"
const PO_DIR: String = "res://translations/"
const PSEUDO_RATIO: float = 0.3
const _SRC_MAX: int = 600

class Bus extends RefCounted:
	signal changed

static var bus: Bus = Bus.new()
static var lang: String = SRC
static var pseudo_on: bool = false
static var gen: int = 0
static var _tr: Translation = null
static var _src: Dictionary = {}
static var _names: Dictionary = {}
static var _re_ph: RegEx = null
static var as_name: Dictionary = {}






static func boot() -> void :
	var want: String = GameConfig.lang
	var ps: bool = GameConfig.pseudo_loc and GameConfig.dev_mode
	var test: bool = false
	if OS.get_environment("DF_LANG") != "":
		want = OS.get_environment("DF_LANG")
		test = true
	if OS.get_environment("DF_PSEUDO") != "":
		ps = OS.get_environment("DF_PSEUDO") != "0"
		test = true
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--lang="):
			want = a.trim_prefix("--lang=")
			test = true
		elif a == "--pseudo":
			ps = true
			test = true
	_apply(norm(want), ps)
	if test:
		print("[Loc] test override: lang=%s pseudo=%s" % [lang, pseudo_on])



static func norm(code: String) -> String:
	var c: String = code.strip_edges().to_lower().replace("-", "_").get_slice("_", 0)
	if c == "ua":
		c = "uk"
	return c if LANGS.has(c) else SRC


static func cur() -> String:
	return lang



static func set_lang(code: String, save: bool = true) -> void :
	GameConfig.lang = norm(code)
	_apply(GameConfig.lang, pseudo_on)
	if save:
		Save.save_prefs()



static func set_pseudo(on: bool, save: bool = true) -> void :
	GameConfig.pseudo_loc = on
	_apply(lang, on)
	if save:
		Save.save_prefs()


static func _apply(code: String, ps: bool) -> void :
	if _tr != null:
		TranslationServer.remove_translation(_tr)
		_tr = null
	var path: String = PO_DIR + code + ".po"
	if ResourceLoader.exists(path):
		_tr = load(path) as Translation
		if _tr != null:
			TranslationServer.add_translation(_tr)
	TranslationServer.set_locale(code)
	var d: TranslationDomain = TranslationServer.get_or_add_domain(&"")
	d.pseudolocalization_accents_enabled = false
	d.pseudolocalization_double_vowels_enabled = false
	d.pseudolocalization_fake_bidi_enabled = false
	d.pseudolocalization_skip_placeholders_enabled = true
	d.pseudolocalization_expansion_ratio = PSEUDO_RATIO
	TranslationServer.pseudolocalization_enabled = ps
	var changed: bool = code != lang or ps != pseudo_on
	lang = code
	pseudo_on = ps
	_src.clear()
	_names.clear()
	gen += 1
	if changed:
		bus.changed.emit()
		var tree: SceneTree = Engine.get_main_loop() as SceneTree
		if tree != null:
			tree.call_group("i18n", "relocalize")



static func is_src() -> bool:
	return lang == SRC and not pseudo_on




static func t(msgid: String, ctx: String = "") -> String:
	if msgid == "" or is_src():
		return msgid
	return String(TranslationServer.translate(msgid, ctx))


static func n(cnt: int, one: String, few: String, many: String, ctx: String = "") -> String:
	if is_src():
		return pick(cnt, one, few, many)
	var s: String = ""
	if _tr != null and lang != SRC:
		s = String(_tr.get_plural_message(one, many, cnt, ctx))
	if s == "":
		s = pick(cnt, one, few, many)
	return TranslationServer.pseudolocalize(s) if pseudo_on else s



static func pick(cnt: int, one: String, few: String, many: String) -> String:
	var a: int = absi(cnt)
	if a % 10 == 1 and a % 100 != 11:
		return one
	if a % 10 >= 2 and a % 10 <= 4 and (a % 100 < 10 or a % 100 >= 20):
		return few
	return many


static func f(tpl: String, args: Dictionary, ctx: String = "") -> String:
	if is_src():
		return _seen(_named(tpl, args, true), [tpl, args, ctx])
	var out: String = _named(t(tpl, ctx), args, false)
	_note_src(out, _named(tpl, args, true))
	return _seen(out, [tpl, args, ctx])


static func mk(msgid: String, args: Variant = [], ctx: String = "") -> Array:
	return [msgid, args, ctx] if ctx != "" else [msgid, args]


static func is_msg(v: Variant) -> bool:
	return v is Array and (v as Array).size() >= 1 and ((v as Array)[0] is String or (v as Array)[0] is StringName)


static func id(m: Variant) -> String:
	if is_msg(m):
		return String((m as Array)[0])
	return String(m) if m != null else ""


static func msg(m: Variant) -> String:
	if not is_msg(m):
		return String(m) if m != null else ""
	if is_src():
		return _seen(_render(m, true), m)
	var out: String = _render(m, false)
	_note_src(out, _render(m, true))
	return _seen(out, m)




static var _rend: Dictionary = {}
const _REND_MAX: int = 160


static func _seen(out: String, m: Variant) -> String:
	if _rend.size() >= _REND_MAX:
		_rend.clear()
	_rend[out] = m
	return out




static func keep(text: String) -> Variant:
	if _rend.has(text):
		return _rend[text]
	var s: String = src_of(text)
	if s != text or is_src() or _tr == null:
		return s
	if _rev_gen != gen:
		_rev_gen = gen
		_rev.clear()
		for mid: StringName in _tr.get_message_list():
			var tr2: String = String(_tr.get_message(mid))
			if tr2 != "" and not _rev.has(tr2):
				_rev[tr2] = String(mid)
	return String(_rev.get(text, text))


static var _rev: Dictionary = {}
static var _rev_gen: int = -1



static func re(k: Variant) -> String:
	if is_msg(k):
		return msg(k)
	var s: String = String(k) if k != null else ""
	return s if is_src() or not has_cyr(s) else t(s)




static func tc(msgid: String, ctx: String) -> String:
	var s: String = t(msgid, ctx)
	return t(msgid) if s == msgid else s


static func src(m: Variant) -> String:
	if not is_msg(m):
		return src_of(String(m)) if m != null else ""
	return _render(m, true)


static func src_of(text: String) -> String:
	if is_src():
		return text
	return String(_src.get(text, text))


static func _note_src(shown: String, source: String) -> void :
	if shown == source:
		return
	if _src.size() >= _SRC_MAX:
		_src.clear()
	_src[shown] = source


static func _render(m: Array, ru: bool) -> String:
	var mid: String = String(m[0])
	var ctx: String = String(m[2]) if m.size() > 2 else ""
	var tpl: String = mid if ru else t(mid, ctx)
	var args: Variant = m[1] if m.size() > 1 else null
	if args is Dictionary:
		return _named(tpl, args, ru)
	if args is Array and not (args as Array).is_empty():
		var a2: Array = []
		for v: Variant in args:
			a2.append(_val(v, ru))
		return tpl % a2
	return tpl


static func _val(v: Variant, ru: bool) -> Variant:
	if is_msg(v):
		return _render(v, ru)
	if not ru and (v is String or v is StringName):
		return _arg(String(v))
	return v





static func _arg(s: String) -> String:
	if s == "" or not has_cyr(s):
		return s
	var d: String = _defname(s)
	if d != "":
		return d
	var tr: String = t(s)
	if tr != s:
		return tr
	for tpl: String in LOC_ARG_TPL:
		var at: int = tpl.find("%s")
		var pre: String = tpl.left(at)
		var suf: String = tpl.substr(at + 2)
		if s.length() >= pre.length() + suf.length() and s.begins_with(pre) and s.ends_with(suf):
			return t(tpl) % _arg(s.substr(pre.length(), s.length() - pre.length() - suf.length()))
	if as_name.size() < 400:
		as_name[s] = true
	return name(s)




static func tx(s: String) -> String:
	return s if is_src() else _arg(s)





const LOC_ARG_TPL: Array = ["ультиматум: %s", "нарушено обещание: %s", "по просьбе страны %s", "армия страны %s мешает войне", 
	"инцидент: %s", "в поддержку %s", "наступление на %s", "блокада порта %s", "прекратите обстрелы порта %s", 
	"снимите блокаду порта %s", "не бить порт %s", "снять блокаду %s", "прекратите удары по мостам%s", "прекратите удары по нефти%s", 
	"не бить мосты%s", "не бить нефть%s", " у г. %s", "прекратите удары по поставкам: %s в дефиците", " (%s)", " · %s"]


static func has_cyr(s: String) -> bool:
	for i in s.length():
		var c: int = s.unicode_at(i)
		if c >= 1024 and c <= 1279:
			return true
	return false





const LOC_DEFNAMES: Array = ["Группа %d", "Флот %d", "Фронт", "Флот", "Конвой"]


static func _defname(s: String) -> String:
	if FORM_NAMES.has(s):
		return t(s, "group")
	for pre: String in ["Группа ", "Флот "]:
		if s.begins_with(pre) and s.substr(pre.length()).is_valid_int():
			return t(pre + "%d") % int(s.substr(pre.length()))
	if s == "Флот":
		return t("Флот", "fleet")
	if s == "Фронт" or s == "Конвой":
		return t(s)
	return ""




const FORM_NAMES: Array = ["Дивизия", "Резерв", "Бригада", "Полк", "Корпус", "Батальон", "Гвардия", "Штурм", "Танки", "Тыл"]




static func gtag(gid: int, nm: String) -> String:
	if is_src():
		return "%d·%s" % [gid, nm.to_upper()]
	if lang == "en" and FORM_NAMES.has(nm):
		return (ordinal(gid) + " " + t(nm, "group")).to_upper()
	return "%d·%s" % [gid, gname(nm).to_upper()]



static func gname(nm: String) -> String:
	if is_src():
		return nm
	var d: String = _defname(nm)
	return d if d != "" else name(nm)



static func ordinal(n: int) -> String:
	if lang != "en":
		return str(n)
	var a: int = absi(n)
	var suf: String = "th"
	if a % 100 < 11 or a % 100 > 13:
		suf = String({1: "st", 2: "nd", 3: "rd"}.get(a % 10, "th"))
	return str(n) + suf



static func uname(s: String) -> String:
	if is_src():
		return s
	var d: String = _defname(s)
	return d if d != "" else s


static func _named(tpl: String, args: Dictionary, ru: bool) -> String:
	if not tpl.contains("{"):
		return tpl
	if _re_ph == null:
		_re_ph = RegEx.create_from_string("\\{([A-Za-z_][A-Za-z0-9_]*)(?::([a-z]+))?\\}")
	var out: String = ""
	var at: int = 0
	for mt: RegExMatch in _re_ph.search_all(tpl):
		var k: String = mt.get_string(1)
		if not args.has(k):
			continue
		out += tpl.substr(at, mt.get_start() - at)
		var v: Variant = _val(args[k], ru)
		var cs: String = mt.get_string(2)
		out += case_of(str(v), cs, SRC if ru else lang) if cs != "" else str(v)
		at = mt.get_end()
	return out + tpl.substr(at)







static func case_of(nm: String, cs: String, lng: String = "") -> String:
	var l: String = lang if lng == "" else lng
	if l == "en" or l == "es":
		return name(nm)
	match cs:
		"gen":
			return BattleWatch.genitive(nm)
		"loc":
			var p: String = BattleWatch.prepositional(nm)
			return (p.left(p.length() - 1) + "і") if l == "uk" and p != nm and p.ends_with("е") else p
		"acc":
			return _ending(nm, [["ка", "ку"]])
		"dat":
			return Operations._dat(nm)
		"ins":
			return _ending(nm, [["ичи", "ичами"], ["ное", "ным"], ["ополь", "ополем"], ["оград", "оградом"], ["ань", "анью"], ["ец", "цем"], 
				["ка", "кой"], ["ск", "ском"], ["ов", "овом"], ["ок", "ком"]])
		"cgen", "cloc", "cacc", "cins":
			return ccase(nm, cs) if l == SRC else nm
	return nm




static func ccase(nm: String, cs: String) -> String:
	var ok: bool = nm.strip_edges() != ""
	for s: String in nm.split(" ", false):
		if not (s.ends_with("АЯ") or s.ends_with("ИЯ")):
			ok = false
	if not ok:
		return String({"cgen": "СТРАНЫ ", "cloc": "СТРАНЕ ", "cacc": "СТРАНУ ", "cins": "СТРАНОЙ "}.get(cs, "")) + nm
	var ends: Array = {"cgen": ["ОЙ", "ИИ"], "cloc": ["ОЙ", "ИИ"], "cacc": ["УЮ", "ИЮ"], "cins": ["ОЙ", "ИЕЙ"]}.get(cs, ["АЯ", "ИЯ"])
	var w: PackedStringArray = nm.split(" ")
	for i in w.size():
		var s2: String = w[i]
		if s2.ends_with("АЯ"):
			s2 = s2.left(s2.length() - 2) + String(ends[0])
		elif s2.ends_with("ИЯ"):
			s2 = s2.left(s2.length() - 2) + String(ends[1])
		w[i] = s2
	return " ".join(w)


static func _ending(nm: String, rules: Array) -> String:
	for e: Array in rules:
		if nm.ends_with(String(e[0])):
			return nm.substr(0, nm.length() - String(e[0]).length()) + String(e[1])
	return nm



static func name(s: String) -> String:
	if lang != "en" and lang != "es":
		return s
	if _names.has(s):
		return String(_names[s])
	var out: String = translit(s)
	if _names.size() >= 4000:
		_names.clear()
	_names[s] = out
	return out


const _STYLE_PRE: Array = [["Нью-", "New "], ["Порт-", "Port "], ["Форт-", "Fort "], ["Лейк-", "Lake "], ["Сен-", "Saint-"], 
	["Валь-Ди-", "Val di "], ["Монте-", "Monte "]]
const _LAT: Dictionary = {"а": "a", "б": "b", "в": "v", "г": "g", "д": "d", "е": "e", "ё": "yo", "ж": "zh", "з": "z", "и": "i", 
	"й": "y", "к": "k", "л": "l", "м": "m", "н": "n", "о": "o", "п": "p", "р": "r", "с": "s", "т": "t", "у": "u", "ф": "f", 
	"х": "kh", "ц": "ts", "ч": "ch", "ш": "sh", "щ": "shch", "ъ": "", "ы": "y", "ь": "", "э": "e", "ю": "yu", "я": "ya", 
	"і": "i", "ї": "yi", "є": "ye", "ґ": "g"}



static func translit(s: String) -> String:
	var w: String = s
	for pr: Array in _STYLE_PRE:
		if w.begins_with(String(pr[0])):
			w = String(pr[1]) + w.substr(String(pr[0]).length())
	if w.ends_with("-Сити"):
		w = w.left(w.length() - 5) + " City"
	var out: String = ""
	var n2: int = w.length()
	for i in n2:
		var ch: String = w[i]
		var lo: String = ch.to_lower()
		if not _LAT.has(lo):
			out += ch
			continue
		var tl: String = String(_LAT[lo])
		if ch != lo and tl != "":
			var nb: String = w[i + 1] if i + 1 < n2 else ""
			var pv: String = w[i - 1] if i > 0 else ""
			var caps: bool = (nb != "" and nb != nb.to_lower()) or (nb == "" and pv != "" and pv != pv.to_lower())
			tl = tl.to_upper() if caps else tl.left(1).to_upper() + tl.substr(1)
		out += tl
	return out




static func num(x: float, digits: int = 1) -> String:
	var s: String = ("%." + str(maxi(0, digits)) + "f") % x
	return s if lang == "en" else s.replace(".", ",")



static func dec(s: String) -> String:
	return s if lang == "en" else s.replace(".", ",")



static func inum(v: int) -> String:
	var a: String = str(absi(v))
	var sep: String = "," if lang == "en" else " "
	var out: String = ""
	while a.length() > 3:
		out = sep + a.right(3) + out
		a = a.left(a.length() - 3)
	return ("-" if v < 0 else "") + a + out



static func pct(v: int) -> String:
	return ("%d%%" if lang == "en" else "%d %%") % v



static func no(n: int) -> String:
	return ("#%d" if lang == "en" else "№%d") % n
