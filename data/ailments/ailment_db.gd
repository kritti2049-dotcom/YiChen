extends Node
class_name AilmentDB

## อาการบาดเจ็บ/พิษที่ติดตัวหลังการต่อสู้ ต้องให้หมอประจำสำนักรักษา
## lethal_days = ไม่รักษาภายในกี่วันจะเสียชีวิต, cripple_days = ไม่รักษาภายในกี่วันจะพิการถาวร
## heal_days = หายเองได้เมื่อครบกี่วัน (0 = ไม่หายเอง), difficulty = ความยากในการรักษา (เทียบค่าการแพทย์)

const AILMENTS = {
	"gu_poison": {
		"name": "พิษกู่", "lethal_days": 20, "cripple_days": 0, "heal_days": 0, "difficulty": 45,
		"desc": "หนอนพิษกัดกินจากภายใน ถ้าไม่ถอนพิษภายใน 20 วันจะเสียชีวิต",
	},
	"meridian_damage": {
		"name": "เส้นชีพจรขาดสะบั้น", "lethal_days": 0, "cripple_days": 12, "heal_days": 0, "difficulty": 40,
		"desc": "ถ้าไม่ฝังเข็มต่อเส้นชีพจรภายใน 12 วัน จะพิการถาวร (พลังต่อสู้ลดครึ่ง)",
	},
	"fever": {
		"name": "ไข้ป่า", "lethal_days": 0, "cripple_days": 0, "heal_days": 6, "difficulty": 20,
		"desc": "โรคระบาดจากป่า อารมณ์หม่นหมอง หายเองใน 6 วัน หรือให้หมอรักษา",
	},
	"internal_injury": {
		"name": "บาดเจ็บภายใน", "lethal_days": 0, "cripple_days": 0, "heal_days": 8, "difficulty": 15,
		"desc": "ลมปราณปั่นป่วน หายเองใน 8 วัน หรือให้หมอรักษาให้เร็วขึ้น",
	},
}

static func get_ailment(id: String) -> Dictionary:
	return AILMENTS.get(id, {})

## โอกาสรักษาสำเร็จต่อวัน (0-1) medicine = ค่ารากฐานการแพทย์ของหมอ (1-10)
static func cure_chance(ailment_id: String, medicine: int, infirmary_level: int) -> float:
	var a = get_ailment(ailment_id)
	var chance = (medicine * 4 + infirmary_level * 15 - a.get("difficulty", 30) + 50) / 100.0
	if infirmary_level == 0: chance *= 0.5
	return clamp(chance, 0.05, 0.95)
