extends Node
class_name EquipmentDB

## ฐานข้อมูลของสวมใส่ + ตัวสุ่มสร้างอุปกรณ์ตามระดับความหายาก
## ระดับความหายาก: ขาว (ทั่วไป) -> เขียว (ดี) -> ฟ้า (หายาก) -> ม่วง (ตำนาน) -> ส้ม (เทพ)
## ค่าพลังของอุปกรณ์เป็น "ชั้นที่ 3" ของ StatSys: บวกเพิ่มแบบคงที่หลังคูณตัวคูณขั้นบำเพ็ญแล้ว
## (ศิษย์ใหม่มีพลังโจมตีราว 4 กระบี่ธรรมดา +3 จึงช่วยได้มาก แต่ยอดฝีมือขั้นสูงพึ่งพาขั้นบำเพ็ญเป็นหลัก)

const RARITY_NAMES = ["ทั่วไป", "ดี", "หายาก", "ตำนาน", "เทพ"]
const RARITY_MULT = [1.0, 2.0, 4.0, 8.0, 16.0]
const RARITY_PREFIX = ["", "ชั้นดี", "เหล็กเย็น", "อัคคีมังกร", "สวรรค์"]
## น้ำหนักการสุ่มพื้นฐานของแต่ละระดับ
const RARITY_WEIGHTS = [60.0, 25.0, 10.0, 4.0, 1.0]

const TYPE_NAMES = ["อาวุธ", "ชุดเกราะ", "เครื่องราง", "ของวิเศษ"]

const BASES = {
	EquipmentData.EquipType.WEAPON: [
		{ "name": "กระบี่", "atk": 3, "spd": 1 },
		{ "name": "ดาบใหญ่", "atk": 4 },
		{ "name": "พัดเหล็ก", "atk": 2, "spd": 1 },
		{ "name": "ทวน", "atk": 3, "def": 1 },
		{ "name": "สนับมือเหล็ก", "atk": 2, "def": 1 },
		{ "name": "เข็มเงินอาบพิษ", "atk": 2, "spd": 1 },
	],
	EquipmentData.EquipType.ARMOR: [
		{ "name": "ชุดเกราะหนัง", "def": 2, "hp": 8 },
		{ "name": "เสื้อคลุมไหมฟ้า", "def": 1, "hp": 5, "spd": 1 },
		{ "name": "เกราะเกล็ดเหล็ก", "def": 3, "hp": 10 },
	],
	EquipmentData.EquipType.ACCESSORY: [
		{ "name": "ปิ่นหยก", "hp": 5, "spd": 1 },
		{ "name": "กำไลทองแดง", "atk": 1, "def": 1 },
		{ "name": "จี้หยกวิญญาณ", "hp": 10 },
	],
	EquipmentData.EquipType.ARTIFACT: [
		{ "name": "กระจกแปดทิศ", "def": 2 },
		{ "name": "กระดิ่งวิญญาณ", "hp": 8 },
		{ "name": "ตราประทับสวรรค์", "atk": 2 },
		{ "name": "น้ำเต้ากลืนฟ้า", "hp": 12 },
	],
}

## สกิลติดตัวของ "ของวิเศษ" (ทำงานจริงในฉากต่อสู้ ดู combat_scene.gd)
const PASSIVES = {
	"regen": { "name": "ปราณฟื้นคืน", "desc": "ฟื้นฟู HP 10% ทุกเทิร์น" },
	"last_stand": { "name": "โล่ไร้พ่าย", "desc": "เมื่อ HP ต่ำกว่า 25% จะกางโล่ไร้พ่าย 1 เทิร์น (ครั้งเดียวต่อการต่อสู้)" },
	"guard": { "name": "เกราะปราณ", "desc": "ลดความเสียหายที่ได้รับ 15%" },
	"lifesteal": { "name": "ดูดโลหิต", "desc": "ดูดเลือด 20% ของความเสียหายที่ทำ" },
	"crit": { "name": "จิตสังหาร", "desc": "โอกาส 25% โจมตีคริติคอล x2" },
}

static func get_passive_desc(id: String) -> String:
	if not PASSIVES.has(id): return ""
	return "%s: %s" % [PASSIVES[id].name, PASSIVES[id].desc]

## สุ่มระดับความหายาก bonus ยิ่งมาก ยิ่งดันน้ำหนักไปทางของดี
static func roll_rarity(bonus: float = 0.0, min_rarity: int = 0) -> int:
	var weights: Array[float] = []
	for i in RARITY_WEIGHTS.size():
		var w = RARITY_WEIGHTS[i] * (1.0 + bonus * i)
		weights.append(w if i >= min_rarity else 0.0)
	var total = 0.0
	for w in weights: total += w
	var roll = randf() * total
	for i in weights.size():
		roll -= weights[i]
		if roll <= 0.0:
			return i
	return weights.size() - 1

## สร้างอุปกรณ์ใหม่ 1 ชิ้น
static func generate(type: int, rarity: int) -> EquipmentData:
	var base: Dictionary = BASES[type].pick_random()
	var mult: float = RARITY_MULT[rarity]
	var eq = EquipmentData.new()
	eq.type = type as EquipmentData.EquipType
	eq.rarity = rarity as EquipmentData.Rarity
	eq.item_name = base.name + RARITY_PREFIX[rarity]
	eq.bonus_hp = int(base.get("hp", 0) * mult)
	eq.bonus_atk = int(base.get("atk", 0) * mult)
	eq.bonus_def = int(base.get("def", 0) * mult)
	eq.bonus_spd = int(base.get("spd", 0) * mult)
	eq.stat_version = 2
	if type == EquipmentData.EquipType.ARTIFACT:
		eq.passive_skill = PASSIVES.keys().pick_random()
	return eq

## ยุทธภัณฑ์ต้องคำสาป: ครอบครองไว้ = ยุทธภพหมายตา (ดู StorytellerSystem.lure_reason)
const CURSED_SWORD = "กระบี่มหาโชคมาร"

static func make_cursed_sword() -> EquipmentData:
	var eq = EquipmentData.new()
	eq.type = EquipmentData.EquipType.WEAPON
	eq.rarity = EquipmentData.Rarity.LEGENDARY
	eq.item_name = CURSED_SWORD
	eq.bonus_atk = 45
	eq.bonus_spd = 3
	eq.bonus_hp = 20
	eq.passive_skill = "lifesteal"
	eq.stat_version = 2
	return eq

static func generate_random(rarity_bonus: float = 0.0, min_rarity: int = 0) -> EquipmentData:
	var type = BASES.keys().pick_random()
	return generate(type, roll_rarity(rarity_bonus, min_rarity))
