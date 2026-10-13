extends Node
class_name MaterialDB

## ฐานข้อมูลวัตถุดิบ (สมุนไพร / แร่ / ชิ้นส่วนสัตว์อสูร / ของหายาก)
## เก็บในคลังสำนักเป็น SectData.materials { "material_id": จำนวน }

const MATERIALS = {
	# สมุนไพร (ใช้หลอมโอสถ)
	"spirit_grass": { "name": "หญ้าวิญญาณ", "category": "herb", "price": 10, "rarity": 0, "desc": "สมุนไพรพื้นฐาน มีปราณเจือจาง" },
	"blood_ginseng": { "name": "โสมโลหิต", "category": "herb", "price": 40, "rarity": 1, "desc": "โสมสีแดงฉานที่ขึ้นตามซากสมรภูมิ" },
	"snow_lotus": { "name": "บัวหิมะพันปี", "category": "herb", "price": 220, "rarity": 3, "desc": "บานเพียงครั้งเดียวในพันปี บนยอดเขาหิมะ" },
	# แร่ (ใช้หลอมศาสตรา)
	"iron_ore": { "name": "แร่เหล็กดำ", "category": "ore", "price": 15, "rarity": 0, "desc": "แร่เหล็กทั่วไปสำหรับตีอาวุธ" },
	"cold_iron": { "name": "เหล็กเย็นพันปี", "category": "ore", "price": 80, "rarity": 2, "desc": "เหล็กที่เย็นเฉียบ ตีเป็นอาวุธได้คมกริบ" },
	"star_metal": { "name": "โลหะดารา", "category": "ore", "price": 320, "rarity": 3, "desc": "อุกกาบาตจากฟากฟ้า เพิ่มโอกาสได้ศาสตราระดับสูง" },
	# ชิ้นส่วนสัตว์อสูร
	"beast_hide": { "name": "หนังสัตว์อสูร", "category": "beast", "price": 20, "rarity": 0, "desc": "หนังเหนียวสำหรับทำชุดเกราะ" },
	"beast_core": { "name": "แก่นอสูร", "category": "beast", "price": 110, "rarity": 2, "desc": "แก่นพลังของสัตว์อสูร ใช้ได้ทั้งหลอมยาและศาสตรา" },
	"dragon_scale": { "name": "เกล็ดมังกร", "category": "beast", "price": 900, "rarity": 4, "desc": "เกล็ดจากมังกรบรรพกาล ของในตำนาน" },
	# วัสดุก่อสร้าง (ศิษย์ตัดไม้/ขุดหินในสำนัก)
	"wood": { "name": "ไม้", "category": "build", "price": 4, "rarity": 0, "desc": "ไม้ซุงสำหรับก่อสร้าง ได้จากการตัดไม้ในสำนัก" },
	"stone": { "name": "หิน", "category": "build", "price": 5, "rarity": 0, "desc": "หินก่อสร้าง ได้จากการขุดหินในสำนัก" },
	# คัมภีร์
	"scripture_fragment": { "name": "คัมภีร์ชำรุด", "category": "misc", "price": 150, "rarity": 2, "desc": "เศษคัมภีร์วิชาที่แย่งชิงมาจากยุทธภพ นำไปถอดรหัสที่หอตำราได้" },
	# อื่นๆ
	"spirit_stone": { "name": "หินวิญญาณ", "category": "misc", "price": 50, "rarity": 1, "desc": "ผลึกปราณ ใช้สร้างและอัปเกรดค่ายกล/สิ่งปลูกสร้าง" },
}

static func get_material(id: String) -> Dictionary:
	return MATERIALS.get(id, {})

static func get_material_name(id: String) -> String:
	return MATERIALS.get(id, {}).get("name", id)

static func get_price(id: String) -> int:
	return MATERIALS.get(id, {}).get("price", 0)

## แปลง Dictionary วัตถุดิบเป็นข้อความ เช่น "หญ้าวิญญาณ x10, แร่เหล็กดำ x2"
static func format_list(mats: Dictionary) -> String:
	var parts: Array[String] = []
	for id in mats:
		parts.append("%s x%d" % [get_material_name(id), mats[id]])
	return ", ".join(parts)
