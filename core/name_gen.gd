class_name NameGen
extends RefCounted


const CITY_PRE: Array = ["Ново", "Старо", "Верхне", "Нижне", "Красно", "Бело", "Светло", "Каменно", "Заречно", "Подгорно", "Сухо", "Тихо", "", "", "", ""]
const CITY_ROOT: Array = ["озёр", "бор", "дол", "яр", "лес", "вод", "мир", "кам", "сад", "луж", "степ", "веж", "ольх", "ясен", "рудн", "топол", "кринич", "берез", "калин", "сосн", "медн", "зорь"]
const CITY_END: Array = ["ск", "ов", "ино", "оград", "ополь", "ец", "ка", "ное", "ичи", "ань"]
const C_SYL1: Array = ["Ве", "Ла", "Сар", "Мо", "Тав", "Ри", "Кор", "Ал", "Ва", "Дан", "Ос", "Бер", "Зар", "Ил", "Нор", "Тер"]
const C_SYL2: Array = ["ле", "ра", "ма", "ни", "ри", "во", "ди", "на", "ло", "се", "та", "го"]
const C_END: Array = ["рия", "ния", "лия", "дия", "вия", "кия"]


static func _cap(s: String) -> String:
	if s.is_empty():
		return s
	return s.substr(0, 1).to_upper() + s.substr(1)



const REAL: Array = ["Красноярск", "Березино", "Белоозёрск", "Новомирград", "Каменка", "Сосновка", "Медное", "Красноозёрск", 
	"Сардиния", "Моравия", "Бервия", "Ливия", "Сирия", "Ирия", "Сербия", "Нория", "Иллирия", "Далмания", "Мония", "Валия"]






static func city(rng: Rng, style: int = 0, taken: Array = []) -> String:
	var east: String = _city_east(rng)
	if style <= 0 or style > 3:
		return _east_fix(east, taken)
	return city_styled(style, int(east.hash() & 2147483647) + taken.size() * 7919 + style * 104729, taken)




static func _east_fix(east: String, taken: Array) -> String:
	if not _east_bad(east, taken):
		return east
	var r: = Rng.new(maxi(1, int(east.hash() & 2147483647) + taken.size() * 7919 + 17))
	for k in 64:
		var n: String = _city_east(r)
		if not _east_bad(n, taken):
			return n
	return east


static func _east_bad(n: String, taken: Array) -> bool:
	if is_real_city(n) or is_rude(n):
		return true
	var low: String = _norm(n)
	for t: Variant in taken:
		if _norm(String(t)) == low:
			return true
	return false


static func _city_east(rng: Rng) -> String:
	for k in 8:
		var pre: String = rng.pick(CITY_PRE)
		var root: String = rng.pick(CITY_ROOT)
		var end: String = rng.pick(CITY_END)
		var n: String = _cap(pre + root + end)
		if not REAL.has(n):
			return n
	return "Новый посёлок"


static func country(rng: Rng, taken: Array = []) -> String:
	var first: String = "Нордания"
	for k in 8:
		var s: String = String(rng.pick(C_SYL1)) + String(rng.pick(C_SYL2)) + String(rng.pick(C_END))
		if not REAL.has(s):
			first = s
			break
	if not clashes(first, taken):
		return first


	var r2: = Rng.new(int(first.hash() & 2147483647) + taken.size() * 7919 + 1)
	for k2 in 64:
		var s2: String = String(r2.pick(C_SYL1)) + String(r2.pick(C_SYL2)) + String(r2.pick(C_END))
		if not REAL.has(s2) and not clashes(s2, taken):
			return s2
	return first



static func clashes(s: String, taken: Array) -> bool:
	var a: String = s.to_lower()
	for t: Variant in taken:
		var b: String = String(t).to_lower()
		if b == "":
			continue
		if a.left(4) == b.left(4) or edit_distance(a, b) <= 2:
			return true
	return false


static func edit_distance(a: String, b: String) -> int:
	var prev: = PackedInt32Array()
	prev.resize(b.length() + 1)
	for j in b.length() + 1:
		prev[j] = j
	for i in range(1, a.length() + 1):
		var cur: = PackedInt32Array()
		cur.resize(b.length() + 1)
		cur[0] = i
		for j2 in range(1, b.length() + 1):
			var c: int = 0 if a[i - 1] == b[j2 - 1] else 1
			cur[j2] = mini(mini(prev[j2] + 1, cur[j2 - 1] + 1), prev[j2 - 1] + c)
		prev = cur
	return prev[b.length()]



const NAME_MIN: int = 3
const NAME_MAX: int = 12

const REAL_STATES: Array = ["россия", "рф", "украина", "беларусь", "белоруссия", "сша", "америка", "китай", "кнр", "германия", 
	"франция", "англия", "британия", "великобритания", "польша", "казахстан", "грузия", "армения", "азербайджан", "молдова", 
	"молдавия", "литва", "латвия", "эстония", "финляндия", "швеция", "норвегия", "дания", "италия", "испания", "португалия", 
	"греция", "турция", "иран", "ирак", "сирия", "израиль", "палестина", "египет", "индия", "пакистан", "япония", "корея", 
	"кндр", "вьетнам", "канада", "мексика", "бразилия", "аргентина", "венгрия", "румыния", "болгария", "сербия", "хорватия", 
	"чехия", "словакия", "австрия", "швейцария", "бельгия", "нидерланды", "голландия", "ирландия", "исландия", "афганистан", 
	"узбекистан", "таджикистан", "киргизия", "кыргызстан", "туркмения", "туркменистан", "монголия", "ливия", "куба", "ссср", 
	"тайвань", "крым", "донбасс", "чечня", "ичкерия", "приднестровье", "абхазия", "осетия", "нигерия", "эфиопия", "судан", 
	"йемен", "ливан", "иордания", "саудовскаяаравия", "оаэ", "катар", "russia", "ukraine", "usa", "america", "china", 
	"germany", "france", "england", "britain", "poland", "israel", "palestine", "iran", "iraq", "ussr", "japan", "korea"]



static func clean_country(s: String) -> String:
	var re: = RegEx.new()
	re.compile("[^\\p{L} \\-]")
	var t: String = re.sub(s, "", true)
	re.compile("[ ]{2,}")
	t = re.sub(t, " ", true)
	re.compile("-{2,}")
	t = re.sub(t, "-", true)
	t = t.strip_edges().left(NAME_MAX).strip_edges()
	return _cap(t)



static func country_name_error(s: String) -> String:
	var t: String = s.strip_edges()
	if t.length() < NAME_MIN:
		return Loc.t("Минимум %d буквы") % NAME_MIN
	var k: String = t.to_lower().replace("ё", "е").replace(" ", "").replace("-", "")
	if REAL_STATES.has(k) or REAL.map( func(r: String) -> String: return r.to_lower()).has(k):
		return "Мир вымышленный — придумайте своё название"
	if is_rude(t):
		return "Без мата и оскорблений — придумайте другое"
	return ""




const RUDE_ROOTS: Array = ["хуй", "хуе", "хуя", "хуи", "хую", "пизд", "пезд", "пзд", "ебан", "ебал", "ебат", "ебуч", "ебло", "ебну", "заеб", 
	"наеб", "уеб", "выеб", "проеб", "долбоеб", "бляд", "блят", "сука", "суки", "сучк", "мудак", "мудил", "пидор", "пидар", "пидр", 
	"педик", "гандон", "гондон", "залуп", "шлюх", "дерьм", "говн", "жопа", "жопы", "дебил", "идиот", "кретин", "мразь", "твар", 
	"ублюд", "выблядок", "хохол", "хохлян", "москал", "кацап", "чурка", "чурок", "нацист", "фашист", "гитлер", 
	"fuck", "shit", "bitch", "pussy", "whore", "slut", "nigg", "faggot", "retard", "asshole", "bastard", "hitler", "nazi"]

const RUDE_WORDS: Array = ["лох", "чмо", "даун", "урод", "жид", "хач", "дурак", "тупой", "негр", "бля", "хохлы", "хохлов", "fag", "dick", 
	"cock", "ass", "jew", "cunt", 
	"рашка", "рашки", "рашке", "рашку", "рашкой", "рашкою", "рашкам", "рашками", "рашках", "рашек"]


const _HONEST: Array = ["сукач", "отвар", "москалев", "москаленк"]

const _LAT2CYR: Dictionary = {"a": "а", "b": "в", "c": "с", "e": "е", "h": "н", "k": "к", "m": "м", "o": "о", "p": "р", "t": "т", 
	"x": "х", "y": "у", "u": "и", "0": "о", "3": "з", "6": "б", "1": "и", "4": "ч"}
const _TRANSLIT: Dictionary = {"a": "а", "b": "б", "v": "в", "g": "г", "d": "д", "e": "е", "z": "з", "i": "и", "j": "й", "k": "к", 
	"l": "л", "m": "м", "n": "н", "o": "о", "p": "п", "r": "р", "s": "с", "t": "т", "u": "у", "f": "ф", "h": "х", "x": "х", 
	"c": "ц", "y": "ы", "w": "в", "q": "к", "0": "о", "3": "з", "6": "б", "1": "и", "4": "ч"}
const _DIGRAPH: Array = [["sch", "щ"], ["sh", "ш"], ["ch", "ч"], ["zh", "ж"], ["kh", "х"], ["ts", "ц"], ["ya", "я"], ["ja", "я"], 
	["yo", "е"], ["yu", "ю"], ["ju", "ю"], ["iy", "ий"], ["yi", "уи"]]
const _CYR2LAT: Dictionary = {"а": "a", "в": "b", "с": "c", "е": "e", "н": "h", "к": "k", "м": "m", "о": "o", "р": "p", "т": "t", 
	"х": "x", "у": "y", "и": "u", "0": "o", "1": "i", "3": "e", "4": "a", "5": "s"}


static func _fold(s: String, map: Dictionary) -> String:
	var out: String = ""
	for ch: String in s:
		out += String(map.get(ch, ch))
	return out



static func is_rude(s: String) -> bool:
	var low: String = s.to_lower().replace("ё", "е")
	var tr: String = low
	for d: Array in _DIGRAPH:
		tr = tr.replace(String(d[0]), String(d[1]))
	for form: String in [_fold(low, _LAT2CYR), _fold(tr, _TRANSLIT), _fold(low, _CYR2LAT)]:
		var joined: String = form.replace(" ", "").replace("-", "")
		for hn: String in _HONEST:
			joined = joined.replace(hn, "_")
		for r: String in RUDE_ROOTS:
			if joined.contains(r):
				return true
		for w: String in form.replace("-", " ").split(" ", false):
			if RUDE_WORDS.has(w):
				return true
	return false






const CITY_MAX: int = 15
const US_ROOT: Array = ["Бусг", "Келлис", "Тарвен", "Морбел", "Гарлин", "Донвер", "Пэйтри", "Ростен", "Фарнел", "Уэйлер", "Харвин", 
	"Квиллер", "Брэдмор", "Эшвин", "Клэйтор", "Окрид", "Колдер", "Ларкин", "Тоббет", "Гриндел", "Дэрроу", "Мэлкот", "Сэдлер", "Норбек"]
const US_SUF: Array = ["бург", "вилл", "таун", "дейл", "филд", "вуд", "форд", "бридж", "хилл", "вью"]
const FR_SAINT: Array = ["Морель", "Жилен", "Ловен", "Ферраль", "Ортан", "Сюзен", "Ренель", "Доран", "Кальвен", "Мирель", "Бальден", 
	"Тиверн", "Альмон", "Корваль"]
const FR_ROOT: Array = ["Бель", "Мар", "Рош", "Шан", "Флёр", "Монт", "Ривь", "Клар", "Вер", "Сов", "Лаж"]
const FR_SUF: Array = ["рёй", "ак", "мон", "ьер", "валь", "круа", "ней", "тур"]
const DE_ROOT: Array = ["Альтен", "Вальд", "Мор", "Гравен", "Ленц", "Брайт", "Фельз", "Ховен", "Ратен", "Остер", "Зиль", "Тарн", 
	"Эльм", "Хольт", "Брунн", "Эрлен", "Таннен", "Кельм", "Ауэр"]
const DE_SUF: Array = ["брук", "бург", "хайм", "дорф", "фельд", "штадт", "берг", "хаузен", "ау", "бах", "хоф", "таль"]
const IT_N: Array = ["Роса", "Мора", "Пьетра", "Сола", "Фьора", "Кьяра", "Луна", "Серра", "Велья", "Терца", "Норра", "Лючча"]
const IT_ROOT: Array = ["Кастелл", "Бор", "Роз", "Фьор", "Лун", "Сер", "Пьев", "Сальв", "Карр", "Ориц", "Вельд"]
const IT_SUF: Array = ["ано", "ино", "елло", "етта", "оне", "ина"]
const AS_A: Array = ["Сан", "Кай", "Хой", "Тхай", "Лон", "Минь", "Шао", "Тэн", "Рю", "Сэй", "Ван", "Бао", "Лэй", "Ко", "Ми", "Тао", 
	"Юн", "Дао", "Квай", "Сун", "Фэн", "Нго", "Тиен", "Ла", "Мэй", "Кам", "Фай"]
const AS_B: Array = ["Лонг", "Бинь", "Шо", "Чи", "Тан", "Хо", "Ань", "Мин", "Лин", "Сю", "Ри", "Кэ", "Тай", "Фу", "Нинь", "Дзё", 
	"Ха", "Вэй", "Сэн", "Ло", "Цзин", "Ен", "Ро", "Кхам", "Тхо", "Мэн"]
const STYLED_FALLBACK: Array = ["Новый посёлок", "Нью-Тарвен", "Сен-Морель", "Кай-Шо"]

const REAL_CITIES: Array = [

	"Хошимин", "Хо-Ши-Мин", "Хой-Чи-Мин", "Ханой", "Хюэ", "Хойан", "Дананг", "Нячанг", "Кантхо", "Хайфон", "Винь", "Тхай-Бинь", 
	"Тхай-Нгуен", "Бинь-Динь", "Нам-Динь", "Нам-Ха", "Ми-Тхо", "Фу-Ен", "Кам-Ло", "Ха-Лонг", "Лонг-Ан", "Сон-Ла", "Тан-Ан", "Да-Лат", 
	"Бао-Лок", "Лао-Кай", "Кам-Фа", "Ша-Па", "Сайгон", "Токио", "Осака", "Киото", "Нара", "Кобе", "Сендай", "Нагоя", "Саппоро", 
	"Фукуока", "Хиросима", "Иокогама", "Кавасаки", "Ниигата", "Тэнри", "Сеул", "Пусан", "Тэгу", "Инчхон", "Кванджу", "Тэджон", 
	"Ульсан", "Сувон", "Пхеньян", "Кэсон", "Вонсан", "Пекин", "Шанхай", "Гуанчжоу", "Шэньчжэнь", "Ухань", "Нанкин", "Сиань", 
	"Чэнду", "Чунцин", "Тяньцзинь", "Харбин", "Далянь", "Циндао", "Сямэнь", "Гонконг", "Макао", "Тайбэй", "Тайнань", "Гаосюн", 
	"Тайчжун", "Ханчжоу", "Сучжоу", "Нинбо", "Куньмин", "Лхаса", "Урумчи", "Ланьчжоу", "Синин", "Хэфэй", "Фучжоу", "Наньнин", 
	"Гуйлинь", "Санья", "Хайкоу", "Чжухай", "Фошань", "Чжэнчжоу", "Чанша", "Наньчан", "Тайюань", "Лоян", "Датун", "Кайфэн", 
	"Шаньтоу", "Тяньшань", "Тянь-Шань", "Шаолинь", "Бангкок", "Пхукет", "Чиангмай", "Вьентьян", "Пномпень", "Янгон", "Мандалай", 
	"Манила", "Себу", "Давао", "Джакарта", "Сингапур", "Куала-Лумпур", "Фудзи", "Хоккайдо", "Окинава", "Наха", "Сайтама", "Тиба", 
	"Минато", "Сибуя", "Синдзюку", "Мин-Ло", "Тао-Ло", "Шао-Лин", "Шао-Линь", "Ми-Сон", "Сун-Ха", 

	"Нью-Йорк", "Нью-Хейвен", "Нью-Джерси", "Нью-Орлеан", "Ньюпорт", "Нью-Бедфорд", "Нью-Бритен", "Нью-Брансуик", "Порт-Артур", 
	"Порт-Хьюрон", "Порт-Ройал", "Форт-Уэрт", "Форт-Майерс", "Форт-Уэйн", "Форт-Лодердейл", "Форт-Нокс", "Спрингфилд", "Спрингдейл", 
	"Гринвилл", "Гринвуд", "Ноксвилл", "Нэшвилл", "Джексонвилл", "Луисвилл", "Эшвилл", "Ричмонд", "Окленд", "Оклэнд", "Колдуэлл", 
	"Ларкинвилл", "Брэдфорд", "Честерфилд", "Плейнфилд", "Бейкерсфилд", "Шелбивилл", "Харрисбург", "Питтсбург", "Гаррисберг", 
	"Канзас-Сити", "Солт-Лейк-Сити", "Оклахома-Сити", "Джерси-Сити", "Карсон-Сити", "Лейк-Тахо", "Голливуд", "Бёрбанк", "Ист-Лансинг", 
	"Уэст-Пойнт", "Брэдмор", "Хиллвью", "Колдер", 

	"Альтенбург", "Альтенау", "Ротенбург", "Штайнбах", "Танненберг", "Остербург", "Вальдорф", "Вальдхайм", "Вальдау", "Эрленбах", 
	"Ленцбург", "Брайтенбах", "Фельзберг", "Хольтхаузен", "Эльмсхорн", "Гамбург", "Фрайбург", "Мангейм", "Мангхайм", "Нойштадт", 
	"Шёнберг", "Розенхайм", "Аугсбург", "Страсбург", "Люксембург", "Бранденбург", "Вюрцбург", "Морбах", "Морбург", "Ауэрбах", "Таннхайм", 
	"Альтдорф", "Брунек", "Сен-Мало", "Сен-Тропе", "Сен-Дени", "Сен-Морис", "Сен-Морель", "Бельвиль", "Бельмон", "Мармон", "Монпелье", 
	"Монако", "Шамони", "Рошфор", "Клермон", "Вердён", "Верден", "Вервье", "Шанмон", "Ривьер", "Бельфор", "Сен-Мишель", "Торино", 
	"Турин", "Верона", "Монтебелло", "Монте-Белла", "Монте-Роса", "Монтероза", "Сан-Марино", "Луино", "Серино", "Монтоне", "Розано", 
	"Борино", "Луна", "Сорренто", "Каррара", "Сальвино", "Фьорано", "Борелло", "Кастелло", "Кастеллано", "Валь-Ди-Сола", "Валь-Ди-Соле", 
	"Лучия", "Мора", "Сарагоса", "Лорена", "Реймс", "Мец", "Брюгге", 

	"Красноводск", "Беловодск", "Светловодск", "Борино", "Озёрск", "Озёрное", "Новоозёрное", "Мирное", "Мирополь", "Степное", 
	"Степань", "Лесное", "Калинино", "Березка", "Березов", "Березань", "Криничка", "Белоярск", "Белозёрск", "Каменск", "Ясенево", 
]
static var _real_n: Dictionary = {}


static func _norm(s: String) -> String:
	return s.to_lower().replace("ё", "е").replace("-", "").replace(" ", "")




static func is_real_city(s: String) -> bool:
	if _real_n.is_empty():
		for a: Array in [REAL_CITIES, REAL, REAL_STATES]:
			for v: Variant in a:
				_real_n[_norm(String(v))] = true
	if _real_n.has(_norm(s)):
		return true
	var parts: PackedStringArray = s.split("-", false)
	for i in parts.size():
		for j in range(i + 2, parts.size() + 1):
			if j - i < parts.size() and _real_n.has(_norm("".join(parts.slice(i, j)))):
				return true
	return false



static func city_styled(style: int, sd: int, taken: Array = []) -> String:
	var r: = Rng.new(maxi(1, sd))
	var tk: Dictionary = {}
	for t: Variant in taken:
		tk[_norm(String(t))] = true
	var first: String = ""
	for k in 64:
		var n: String = _styled_once(clampi(style, 1, 3), r)
		if n.length() > CITY_MAX or is_rude(n) or is_real_city(n):
			continue
		if first == "":
			first = n
		if not tk.has(_norm(n)):
			return n
	return first if first != "" else String(STYLED_FALLBACK[clampi(style, 1, 3)])


static func _styled_once(style: int, r: Rng) -> String:
	var p: int = r.range_i(100)
	match style:
		1:
			var root: String = r.pick(US_ROOT)
			var suf: String = r.pick(US_SUF)
			if p < 26:
				return "Нью-" + root + suf
			if p < 40:
				return "Порт-" + root + suf
			if p < 50:
				return "Форт-" + root
			if p < 58:
				return "Лейк-" + root
			if p < 66:
				return root + "-Сити"
			return root + suf
		2:
			if p < 20:
				return "Сен-" + String(r.pick(FR_SAINT))
			if p < 32:
				return String(r.pick(FR_ROOT)) + String(r.pick(FR_SUF))
			if p < 62:
				return String(r.pick(DE_ROOT)) + String(r.pick(DE_SUF))
			if p < 74:
				return "Валь-Ди-" + String(r.pick(IT_N))
			if p < 82:
				return "Монте-" + String(r.pick(IT_N))
			return String(r.pick(IT_ROOT)) + String(r.pick(IT_SUF))

	var b1: String = String(r.pick(AS_B))
	var a: String = String(r.pick(AS_A)) + "-" + b1
	if p >= 68:
		var b2: String = String(r.pick(AS_B))
		if b2 == b1:
			b2 = String(AS_B[(AS_B.find(b1) + 1 + r.range_i(AS_B.size() - 1)) % AS_B.size()])
		a += "-" + b2
	return a



static func city_examples(style: int, n: int = 2) -> Array:
	var out: Array = []
	for i in n:
		if style <= 0:
			out.append(_city_east(Rng.new(4241 + i * 97)))
		else:
			out.append(city_styled(style, 7001 + i * 131 + style * 17, out))
	return out
