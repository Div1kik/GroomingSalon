extends Node
class_name GameState

signal state_changed
signal day_passed(day_num: int, month_num: int, salary_paid: int)
signal guest_visited_changed(is_visiting: bool, salon_name: String)

var money: int = 1200
var reputation: float = 3.5 # 1.0 .. 10.0
var salon_level: int = 1 # 1 .. 5
var salon_name: String = "Нежный Хвостик"

var game_minute: int = 10 * 60
var day_num: int = 1
var month_num: int = 1
var is_24h_mode: bool = false

var grooming_stations: int = 1
var wash_stations: int = 1
var dry_stations: int = 1
var has_drying_cabinet: bool = false
var equipment_tier: int = 1 # 1 .. 4

var pet_memory: Dictionary = {}
var known_clients: Array[Dictionary] = [] # постоянные клиенты, которые могут вернуться
var hired_staff: Array[Dictionary] = []

var candidate_pool: Array[Dictionary] = [
	{
		"id": "anna",
		"name": "Аня",
		"role": "Грумер-универсал",
		"min_level": 1,
		"salary": 250,
		"income_bonus": 35,
		"rep_delta": 0.08,
		"phrase": "Какой мягкий хвостик! Сейчас всё сделаем аккуратно."
	},
	{
		"id": "lev",
		"name": "Лев",
		"role": "Специалист по сушке и шерсти",
		"min_level": 2,
		"salary": 420,
		"income_bonus": 60,
		"rep_delta": 0.14,
		"phrase": "Тише-тише, я включу самый мягкий поток воздуха."
	},
	{
		"id": "mila",
		"name": "Мила",
		"role": "Мастер деликатного ухода",
		"min_level": 3,
		"salary": 680,
		"income_bonus": 95,
		"rep_delta": 0.22,
		"phrase": "Сначала познакомимся и дадим любимую игрушку — никакого стресса!"
	},
	{
		"id": "dima",
		"name": "Дима",
		"role": "Старший грумер ночной смены",
		"min_level": 4,
		"salary": 950,
		"income_bonus": 140,
		"rep_delta": 0.30,
		"phrase": "Даже в полночь у нас тихо, уютно и по расписанию."
	}
]

var placed_decor: Array[Dictionary] = [
	{"id": "plant_monstera", "label": "Монстера в кашпо", "category": "Растение", "pos_x": 150.0, "pos_y": 1140.0, "color": Color("6f9e7b")},
	{"id": "lounge_sofa", "label": "Уютный диванчик гостей", "category": "Лаунж-зона", "pos_x": 850.0, "pos_y": 1160.0, "color": Color("d8b89c")}
]

var decor_catalog: Array[Dictionary] = [
	{"id": "plant_monstera", "label": "Монстера в кашпо", "category": "Растение", "price": 180, "color": Color("6f9e7b")},
	{"id": "plant_lavender", "label": "Горшочек лаванды", "category": "Растение", "price": 220, "color": Color("9a8ec4")},
	{"id": "lounge_sofa", "label": "Уютный диванчик гостей", "category": "Лаунж-зона", "price": 450, "color": Color("d8b89c")},
	{"id": "lounge_tea", "label": "Столик с травяным чаем", "category": "Лаунж-зона", "price": 520, "color": Color("c9a68b")},
	{"id": "lamp_warm", "label": "Тёплый торшер", "category": "Атмосфера", "price": 300, "color": Color("e7c888")}
]

# Пулы для процедурной генерации питомцев, пород, окрасов и характеров
const BREED_POOL: Array[Dictionary] = [
	{"species": "Котик", "breed": "Персидский", "visual_type": "persian", "coat": "Длинная шёлковая шерсть", "coat_type": "long", "sprite_path": "res://assets/pets/persian.png"},
	{"species": "Котик", "breed": "Мейн-кун", "visual_type": "persian", "coat": "Густой воротник и кисточки", "coat_type": "long", "sprite_path": "res://assets/pets/mainecoon.png"},
	{"species": "Котик", "breed": "Британский короткошёрстный", "visual_type": "british", "coat": "Плюшевый подшёрсток", "coat_type": "short", "sprite_path": "res://assets/pets/british.png"},
	{"species": "Котик", "breed": "Шотландский вислоухий", "visual_type": "lop_cat", "coat": "Мягкая плюшевая шубка", "coat_type": "short", "sprite_path": "res://assets/pets/scottish.png"},
	{"species": "Котик", "breed": "Сибирский", "visual_type": "persian", "coat": "Пышная тёплая шерсть", "coat_type": "long", "sprite_path": "res://assets/pets/siberian.png"},
	{"species": "Пёсик", "breed": "Вельш-корги", "visual_type": "corgi", "coat": "Густой плотный подшёрсток", "coat_type": "dense", "sprite_path": "res://assets/pets/corgi.png"},
	{"species": "Пёсик", "breed": "Той-пудель", "visual_type": "poodle", "coat": "Кудрявая мягкая шерсть", "coat_type": "curly", "sprite_path": "res://assets/pets/poodle.png"},
	{"species": "Пёсик", "breed": "Померанский шпиц", "visual_type": "spitz", "coat": "Воздушная пушистая шубка", "coat_type": "long", "sprite_path": "res://assets/pets/spitz.png"},
	{"species": "Пёсик", "breed": "Самоед", "visual_type": "spitz", "coat": "Белоснежное облако шерсти", "coat_type": "long", "sprite_path": "res://assets/pets/samoyed.png"},
	{"species": "Пёсик", "breed": "Такса", "visual_type": "dachshund", "coat": "Гладкая блестящая шерсть", "coat_type": "short", "sprite_path": "res://assets/pets/dachshund.png"},
	{"species": "Пёсик", "breed": "Бигль", "visual_type": "dachshund", "coat": "Плотная короткая шерсть", "coat_type": "short", "sprite_path": "res://assets/pets/beagle.png"}
]

const CAT_NAMES: Array[String] = [
	"Персик", "Дымка", "Зефир", "Бусинка", "Маркиз", "Плюша", "Карамель", "Тучка",
	"Симба", "Милка", "Кокос", "Барсик", "Луна", "Снежок", "Изюм", "Фисташка"
]

const DOG_NAMES: Array[String] = [
	"Булочка", "Латте", "Бублик", "Арчи", "Оливка", "Чарли", "Кекс", "Бруно",
	"Тоффи", "Бейли", "Марс", "Честер", "Пончик", "Гретта", "Норд", "Бисквит"
]

const COAT_PALETTES: Array[Dictionary] = [
	{"name": "медовый", "body": Color("e6a968"), "accent": Color("fff9f0"), "eye": Color("4a3525")},
	{"name": "кремовый", "body": Color("f5dfc4"), "accent": Color("e3b88d"), "eye": Color("d9822b")},
	{"name": "дымчатый", "body": Color("a9b5c2"), "accent": Color("d8e0e8"), "eye": Color("e09a3e")},
	{"name": "карамельный", "body": Color("d9a679"), "accent": Color("f7ead9"), "eye": Color("3d2d22")},
	{"name": "белоснежный", "body": Color("f7f4ef"), "accent": Color("e6ddd0"), "eye": Color("5c85a6")},
	{"name": "шоколадный", "body": Color("8c6249"), "accent": Color("c99f82"), "eye": Color("d99838")},
	{"name": "персиковый", "body": Color("f0be99"), "accent": Color("fff5eb"), "eye": Color("5e7a52")},
	{"name": "графитовый", "body": Color("6e7680"), "accent": Color("b3bcc7"), "eye": Color("e3a83b")}
]

const TEMPERAMENTS: Array[Dictionary] = [
	{
		"fear_water": false, "fear_dryer": true,
		"habit": "Боится громкого фена, но обожает плавное расчёсывание.",
		"problem": "ужасно боится шума фена после прошлого опыта",
		"wish": "Бережная сушка + вычесать колтуны"
	},
	{
		"fear_water": true, "fear_dryer": false,
		"habit": "Недолюбливает воду — лучше сначала успокоить и дать игрушку.",
		"problem": "испачкался на прогулке, но воду совсем не любит",
		"wish": "Мягкое купание + ароматный шампунь"
	},
	{
		"fear_water": true, "fear_dryer": true,
		"habit": "Очень чувствительный хвостик: ценит тишину и внимание.",
		"problem": "стесняется незнакомых мест и громких звуков",
		"wish": "Деликатный спа-уход без спешки"
	},
	{
		"fear_water": false, "fear_dryer": false,
		"habit": "Дружелюбный непоседа — обожает внимание и наводить красоту.",
		"problem": "зарос перед выходными и просит стильную укладку",
		"wish": "Полный комплекс + праздничный бантик"
	}
]

const TOY_POOL: Array[String] = [
	"Мягкая мышка", "Плетёный канатик", "Шуршащий бантик",
	"Резиновый пончик", "Плюшевая уточка", "Мячик с колокольчиком"
]

const OWNER_NAMES: Array[String] = [
	"Алина", "Максим", "Елена", "Соня", "Артём", "Даша", "Кирилл", "Настя", "Игорь", "Полина"
]

const OWNER_SHIRTS: Array[Color] = [
	Color("d69e85"), Color("8fb39e"), Color("9ab8c9"), Color("c7a6c9"), Color("d9be82"), Color("b59b84")
]

const OWNER_HAIRS: Array[Color] = [
	Color("6b4e3d"), Color("3b2f2a"), Color("b88856"), Color("8f4e38"), Color("59524c")
]

const BOW_COLORS: Array[Color] = [
	Color("e68c7a"), Color("7da388"), Color("c78bb8"), Color("7ca4c4"), Color("e3b06b")
]

var guest_salons: Array[Dictionary] = [
	{
		"name": "«Солнечная Лапка» (Гостевой визит)",
		"note": "Светлый зал с обилием живых растений и широкой лаунж-зоной у окна.",
		"accent": Color("dcebe2"),
		"highlight": Color("7da388")
	},
	{
		"name": "«Облачко и Щётка» (Гостевой визит)",
		"note": "Уютная студия с сушильным шкафом и мягкими креслами для хозяев.",
		"accent": Color("f3e7dc"),
		"highlight": Color("c99e76")
	}
]

var is_visiting_guest: bool = false
var active_guest_salon: Dictionary = {}

func _ready() -> void:
	hired_staff.append({
		"id": "anna",
		"name": "Аня",
		"role": "Грумер-универсал",
		"min_level": 1,
		"salary": 250,
		"income_bonus": 35,
		"rep_delta": 0.08,
		"phrase": "Какой мягкий хвостик! Сейчас всё сделаем аккуратно."
	})

func spawn_pet_client() -> Dictionary:
	# С вероятностью 35% возвращается один из постоянных довольных клиентов
	if known_clients.size() >= 2 and randf() < 0.35:
		var returning: Dictionary = known_clients[randi() % known_clients.size()].duplicate(true)
		var mem_ret: Dictionary = pet_memory.get(returning["id"], {"trust": 0.0, "visits": 0, "banished": false})
		if not mem_ret.get("banished", false):
			returning["trust"] = mem_ret.get("trust", 0.0)
			returning["visits"] = mem_ret.get("visits", 0)
			returning["base_price"] = get_service_price()
			returning["owner_replica"] = "«Снова здравствуйте! %s так понравилось в прошлый раз, что мы пришли освежить причёску!»" % returning["name"]
			return returning

	# Процедурная генерация нового уникального клиента
	var breed_info: Dictionary = BREED_POOL[randi() % BREED_POOL.size()]
	var is_cat: bool = str(breed_info["species"]) == "Котик"
	var pet_name: String = CAT_NAMES[randi() % CAT_NAMES.size()] if is_cat else DOG_NAMES[randi() % DOG_NAMES.size()]
	var owner_name: String = OWNER_NAMES[randi() % OWNER_NAMES.size()]

	# Для самоеда чаще подбираем светлый окрас
	var pal: Dictionary = COAT_PALETTES[randi() % COAT_PALETTES.size()]
	if str(breed_info["breed"]) == "Самоед":
		pal = COAT_PALETTES[4]

	var temp: Dictionary = TEMPERAMENTS[randi() % TEMPERAMENTS.size()]
	var toy: String = TOY_POOL[randi() % TOY_POOL.size()]
	var bow_col: Color = BOW_COLORS[randi() % BOW_COLORS.size()]
	var owner_shirt: Color = OWNER_SHIRTS[randi() % OWNER_SHIRTS.size()]
	var owner_hair: Color = OWNER_HAIRS[randi() % OWNER_HAIRS.size()]

	var uid: String = "%s_%s_%s" % [breed_info["visual_type"], pet_name, owner_name]
	var mem: Dictionary = pet_memory.get(uid, {"trust": 0.0, "visits": 0, "banished": false})

	var replica: String = "«Здравствуйте! Я %s, а это %s (%s). У нас %s — приведёте в порядок?»" % [
		owner_name,
		pet_name,
		str(breed_info["breed"]).to_lower(),
		str(temp["problem"])
	]

	var client := {
		"id": uid,
		"visual_type": breed_info["visual_type"],
		"sprite_path": breed_info["sprite_path"],
		"name": pet_name,
		"owner_name": owner_name,
		"owner_shirt": owner_shirt,
		"owner_hair": owner_hair,
		"owner_replica": replica,
		"wish_tag": temp["wish"],
		"species": breed_info["species"],
		"breed": breed_info["breed"],
		"coat": "%s (%s окрас)" % [breed_info["coat"], pal["name"]],
		"coat_type": breed_info["coat_type"],
		"fear_dryer": temp["fear_dryer"],
		"fear_water": temp["fear_water"],
		"toy": toy,
		"body_color": pal["body"],
		"accent_color": pal["accent"],
		"eye_color": pal["eye"],
		"bow_color": bow_col,
		"habit_note": temp["habit"],
		"trust": mem.get("trust", 0.0),
		"visits": mem.get("visits", 0),
		"base_price": get_service_price()
	}
	return client

func record_pet_outcome(pet_id: String, calm_score: float, earned_money: int, pet_snapshot: Dictionary = {}) -> void:
	money += earned_money
	var mem: Dictionary = pet_memory.get(pet_id, {"trust": 0.0, "visits": 0, "banished": false}).duplicate(true)
	mem["visits"] = int(mem.get("visits", 0)) + 1

	var trust: float = float(mem.get("trust", 0.0))
	if calm_score >= 0.72:
		trust = clamp(trust + 0.25, -1.0, 1.0)
		reputation = clamp(reputation + 0.18, 1.0, 10.0)
	elif calm_score >= 0.42:
		trust = clamp(trust + 0.05, -1.0, 1.0)
		reputation = clamp(reputation + 0.04, 1.0, 10.0)
	else:
		trust = clamp(trust - 0.45, -1.0, 1.0)
		reputation = clamp(reputation - 0.55, 1.0, 10.0)
		if trust <= -0.85 and int(mem["visits"]) >= 2:
			mem["banished"] = true

	mem["trust"] = trust
	pet_memory[pet_id] = mem

	if not pet_snapshot.is_empty() and not mem.get("banished", false):
		var exists := false
		for kc in known_clients:
			if str(kc.get("id", "")) == pet_id:
				exists = true
				break
		if not exists and known_clients.size() < 24:
			known_clients.append(pet_snapshot.duplicate(true))

	emit_signal("state_changed")

func get_service_price() -> int:
	var rep_mult: float = 0.75 + (reputation / 10.0) * 0.85
	var lvl_mult: float = 1.0 + (salon_level - 1) * 0.35
	return int(round(180.0 * rep_mult * lvl_mult))

func get_level_upgrade_cost() -> int:
	match salon_level:
		1: return 650
		2: return 1400
		3: return 2600
		4: return 4500
		_: return 0

func upgrade_salon_level() -> bool:
	if salon_level >= 5:
		return false
	var cost: int = get_level_upgrade_cost()
	if money < cost:
		return false
	money -= cost
	salon_level += 1
	reputation = clamp(reputation + 0.35, 1.0, 10.0)

	if salon_level == 2:
		wash_stations += 1
	elif salon_level == 3:
		grooming_stations += 1
		has_drying_cabinet = true
	elif salon_level == 4:
		dry_stations += 1
		equipment_tier = max(equipment_tier, 2)
	elif salon_level == 5:
		is_24h_mode = true
		equipment_tier = max(equipment_tier, 3)

	emit_signal("state_changed")
	return true

func toggle_24h_mode() -> void:
	if salon_level >= 5:
		is_24h_mode = not is_24h_mode
		emit_signal("state_changed")

func get_end_minute() -> int:
	if is_24h_mode and salon_level >= 5:
		return 24 * 60
	return 22 * 60

func advance_time(minutes: int) -> void:
	game_minute += minutes
	var end_min: int = get_end_minute()
	if game_minute >= end_min:
		_finish_day()
	emit_signal("state_changed")

func _finish_day() -> void:
	var staff_income: int = 0
	for s in hired_staff:
		staff_income += int(s.get("income_bonus", 0))
		reputation = clamp(reputation + float(s.get("rep_delta", 0.0)) * 0.5, 1.0, 10.0)
	money += staff_income

	day_num += 1
	game_minute = 10 * 60

	var salary_paid: int = 0
	if (day_num - 1) % 30 == 0:
		for s in hired_staff:
			salary_paid += int(s.get("salary", 0))
		money -= salary_paid
		month_num += 1

	emit_signal("day_passed", day_num, month_num, salary_paid)
	emit_signal("state_changed")

func hire_or_replace_staff(candidate: Dictionary, replace_index: int = -1) -> bool:
	if salon_level < int(candidate.get("min_level", 1)):
		return false
	var entry: Dictionary = candidate.duplicate(true)
	if replace_index >= 0 and replace_index < hired_staff.size():
		hired_staff[replace_index] = entry
	else:
		var max_slots: int = 1 + salon_level
		if hired_staff.size() >= max_slots:
			return false
		hired_staff.append(entry)
	emit_signal("state_changed")
	return true

func buy_and_place_decor(item: Dictionary) -> bool:
	var cost: int = int(item.get("price", 0))
	if money < cost:
		return false
	money -= cost
	placed_decor.append({
		"id": item["id"],
		"label": item["label"],
		"category": item["category"],
		"pos_x": randf_range(160.0, 920.0),
		"pos_y": randf_range(1120.0, 1340.0),
		"color": item["color"]
	})
	reputation = clamp(reputation + 0.12, 1.0, 10.0)
	emit_signal("state_changed")
	return true

func update_decor_position(index: int, new_pos: Vector2) -> void:
	if index < 0 or index >= placed_decor.size():
		return
	placed_decor[index]["pos_x"] = clamp(new_pos.x, 80.0, 1000.0)
	placed_decor[index]["pos_y"] = clamp(new_pos.y, 1050.0, 1420.0)
	emit_signal("state_changed")

func enter_guest_visit() -> void:
	active_guest_salon = guest_salons[randi() % guest_salons.size()]
	is_visiting_guest = true
	emit_signal("guest_visited_changed", true, str(active_guest_salon.get("name", "")))

func exit_guest_visit() -> void:
	is_visiting_guest = false
	active_guest_salon = {}
	emit_signal("guest_visited_changed", false, "")

func format_clock() -> String:
	var h: int = int(float(game_minute) / 60.0) % 24
	var m: int = game_minute % 60
	return "%02d:%02d" % [h, m]
