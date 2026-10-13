extends Node
class_name RecipeDB

## สูตรหลอมโอสถ (หอหลอมโอสถ) และสูตรหลอมศาสตรา (โรงหลอมศาสตรา)

## คุณภาพของยา (ได้จากมินิเกมหลอมโอสถ)
const PILL_QUALITY_NAMES = ["ขั้นต่ำ", "ขั้นกลาง", "ขั้นสูง", "ขั้นสมบูรณ์"]
const PILL_QUALITY_COLORS = [Color(0.8, 0.8, 0.8), Color(0.4, 0.9, 0.4), Color(0.4, 0.7, 1.0), Color(1.0, 0.65, 0.2)]

const PILLS = {
	"breakthrough_pill": {
		"name": "ยาทะลวงปราณ", "lab_level": 1, "money": 100,
		"materials": { "spirit_grass": 10 },
		"desc": "ใช้ตอนทะลวงคอขวด: เพิ่มเวลามินิเกม/เพิ่มโอกาสสำเร็จตามคุณภาพยา",
	},
	"calm_tea": {
		"name": "ชาสงบจิต", "lab_level": 1, "money": 20,
		"materials": { "spirit_grass": 3 },
		"desc": "ดึงอารมณ์ขึ้นชั่วคราวและลดความเครียด 35 (ดื่มบ่อยเสี่ยงเสพติด)",
	},
	"healing_pill": {
		"name": "ยาฟื้นฟูโลหิต", "lab_level": 1, "money": 30,
		"materials": { "spirit_grass": 5 },
		"desc": "รักษาอาการบาดเจ็บ (ลดวันพักฟื้นตามคุณภาพยา)",
	},
	"qi_pill": {
		"name": "ยาบำรุงปราณ", "lab_level": 2, "money": 80,
		"materials": { "spirit_grass": 5, "blood_ginseng": 2 },
		"desc": "เพิ่ม EXP การฝึกตนทันที",
	},
	"marrow_pill": {
		"name": "ยาชำระไขกระดูก", "lab_level": 3, "money": 300,
		"materials": { "blood_ginseng": 3, "beast_core": 1 },
		"desc": "เพิ่มค่าพลังหมวดร่างกายถาวร",
	},
	"heaven_pill": {
		"name": "ยาเก้าเกลียวหยกสวรรค์", "lab_level": 5, "money": 1500,
		"materials": { "snow_lotus": 2, "beast_core": 3 },
		"desc": "ยาทะลวงคอขวดระดับเซียน เพิ่มเวลา/โอกาสมหาศาล",
	},
}

## ผลของยาทะลวงตามคุณภาพ: วินาทีที่เพิ่มในมินิเกม และ % โอกาสที่เพิ่มเมื่อให้ศิษย์ทะลวงเอง
static func get_breakthrough_bonus(pill_id: String, quality: int) -> Dictionary:
	var mult = 3.0 if pill_id == "heaven_pill" else 1.0
	return {
		"seconds": (5.0 + quality * 4.0) * mult,
		"chance": (10.0 + quality * 8.0) * mult,
	}

const FORGE = {
	"weapon": {
		"name": "อาวุธ", "type": EquipmentData.EquipType.WEAPON, "forge_level": 1, "money": 80,
		"materials": { "iron_ore": 8 },
	},
	"armor": {
		"name": "ชุดเกราะ", "type": EquipmentData.EquipType.ARMOR, "forge_level": 1, "money": 80,
		"materials": { "iron_ore": 5, "beast_hide": 4 },
	},
	"accessory": {
		"name": "เครื่องราง", "type": EquipmentData.EquipType.ACCESSORY, "forge_level": 2, "money": 150,
		"materials": { "cold_iron": 2, "beast_hide": 3 },
	},
	"artifact": {
		"name": "ของวิเศษ", "type": EquipmentData.EquipType.ARTIFACT, "forge_level": 3, "money": 400,
		"materials": { "cold_iron": 3, "beast_core": 2 },
	},
}

## วัตถุดิบเสริมที่ใส่เพิ่มตอนหลอมศาสตรา เพื่อเพิ่มโอกาสได้ของหายาก
const FORGE_CATALYSTS = {
	"star_metal": 1.5,
	"dragon_scale": 3.0,
}
