extends RefCounted










enum {URGENT, NOTE, LOG, INBOX}


const RULES: Array = [

	["предлагает вам", INBOX], ["просит покровительства", INBOX], ["просит право прохода", INBOX], 
	["(торговля)", INBOX], ["призыв к войне", INBOX], ["нота протеста", INBOX], ["предлагает: ", INBOX], 
	["дипломатия: новое", INBOX], ["предлагает вступить", INBOX], 
	["капитуляция не принята", NOTE], ["конференция: время вышло", NOTE], ["конференция: вам", NOTE], 
	["срок ультиматума", NOTE], 

	["сдаётся — принять", INBOX], ["капитулирует — ваша очередь", INBOX], ["ультиматум:", INBOX], 

	["вражеский десант", URGENT], ["капитуляция", URGENT], ["конференция:", URGENT], ["ультиматум", URGENT], 
	["вы вступаете в войну", URGENT], ["по договору вы вступаете", URGENT], 
	["ваш порт заблокирован", URGENT], ["потоплен наш корабль", URGENT], ["вы лидер мира", URGENT], 
	["эскорт открыл ответный огонь", URGENT], 

	["армия №", LOG], ["группа «", LOG], ["разведдрон", LOG], ["авто", LOG], ["движение:", LOG], 
	["окоп готов", LOG], ["ряд зубов", LOG], ["блиндаж", LOG], ["готов: запас", LOG], ["груз доставлен", LOG], 
	["продано ", LOG], ["корабль вернулся", LOG], ["корабль из-за рубежа", LOG], ["импорт", LOG], ["экспорт", LOG], 
	["получено от", LOG], ["помощь от", LOG], ["ж/д путь", LOG], ["впп", LOG], ["восстановление:", LOG], 
	["восстановлено:", LOG], ["мост восстановлен", LOG], ["растёт:", LOG], ["порт растёт", LOG], ["сделка:", LOG], 
	["железная дорога:", LOG], ["пополнение армий", LOG], ["все армии", LOG], ["наступление на", LOG], 
	["бпла ", LOG], ["пуск ракеты", LOG], ["гиперзвуковая ракета: полёт", LOG], ["каб", LOG], 
	["возврат на базу", LOG], ["перезарядка", LOG], ["вражеская лодка потоплена", LOG], ["вражеский конвой", LOG], 
	["потоплен вражеский", LOG], ["пво: сбит", LOG], ["сапёры", LOG], ["план:", LOG], 
	["спущен на воду", LOG], ["верфь: заказ", LOG], ["экспедиция", LOG], ["основана колония", LOG], 
	["договор подписан", LOG], ["постоянный приказ", LOG], ["на позиции", LOG], ["сетка ", LOG], ["бетон ", LOG], 
	["ремонт ", LOG], ["вражеский разведдрон", LOG], ["развитие ", LOG], ["разведка:", LOG], ["блокада:", LOG], 
	["построено:", LOG], ["месторождение", LOG], ["автозакупка", LOG], ["очков, у вас", LOG], 
]


const MERGE: Array = [
	["мост", "МОСТЫ"], ["разрушен", "ПОТЕРИ"], ["сбит", "ПОТЕРИ"], ["потоплен", "ПОТЕРИ"], ["потерян", "ПОТЕРИ"], ["уничтожен", "ПОТЕРИ"], 
	["сеть:", "СЕТЬ"], ["обесточ", "СЕТЬ"], ["завод ждёт", "ЗАВОДЫ"], ["не хватает", "ЗАВОДЫ"], 
	["санкции", "ТОРГОВЛЯ"], ["эмбарго", "ТОРГОВЛЯ"], ["расторгает", "ДОГОВОРЫ"], 
]



static func level(text: String) -> int:
	var t: String = Loc.src_of(text).to_lower()
	for r: Array in RULES:
		if t.contains(String(r[0])):
			return int(r[1])
	return NOTE




static func news_level(text: String, player_name: String) -> int:
	var t: String = Loc.src_of(text).to_lower()
	if t.contains("предлагает вам"):
		return INBOX
	if player_name != "" and t.contains(player_name.to_lower()):
		return NOTE
	for w: String in [" вам", " вас", " ваш", "вам ", "вас "]:
		if t.contains(w):
			return NOTE
	return LOG





const IMPORTANT: Array = [
	"войн", "мир с ", "мир заключ", "мирный договор", "перемирие", "капитул", "ультиматум", 
	"летит на", "летят на", "тревог", "защита потеряна", "сбит над", "по нашим", "по нам", 
	"город взят", "потерян город", "захвачен", "аннексия", "десант", "потоплен наш", "порт заблокирован", 
]



static func important(text: String) -> bool:
	var t: String = Loc.src_of(text).to_lower()
	if t.begins_with("наш удар"):
		return false


	if t.begins_with("каб по "):
		return true
	if (t.contains("разрушен") or t.contains("поражен")) and (t.contains(" дроном") or t.contains(" бпла") or t.contains(" ракетой") or t.contains(" каб")):
		return true
	for w: String in IMPORTANT:
		if t.contains(w):
			return true
	return false



static func merge_key(text: String) -> String:
	var t: String = Loc.src_of(text).to_lower()
	for r: Array in MERGE:
		if t.contains(String(r[0])):
			return String(r[1])
	return ""
