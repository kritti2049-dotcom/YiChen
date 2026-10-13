extends Resource
class_name EquipmentData

enum EquipType { WEAPON, ARMOR, ACCESSORY, ARTIFACT }
enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }

@export var item_name: String = "ยุทธภัณฑ์ไร้นาม"
@export var type: EquipType = EquipType.WEAPON
@export var rarity: Rarity = Rarity.COMMON

@export_group("Stats Bonus")
@export var bonus_hp: int = 0
@export var bonus_atk: int = 0
@export var bonus_def: int = 0
@export var bonus_spd: int = 0

## รุ่นของสเกลค่าพลัง (2 = สเกลใหม่ของ StatSys) ใช้แปลงอุปกรณ์จากเซฟเก่า
@export var stat_version: int = 0

@export_group("Special Effects")
## สกิลติดตัวเฉพาะของชิ้นนี้ (id จาก EquipmentDB.PASSIVES)
@export var passive_skill: String = ""

## แปลงอุปกรณ์จากเซฟเก่า (ค่าพลังสเกลเดิมสูงกว่าราว 4 เท่า)
func migrate() -> void:
	if stat_version >= 2: return
	bonus_hp = int(round(bonus_hp / 4.0))
	bonus_atk = int(round(bonus_atk / 4.0))
	bonus_def = int(round(bonus_def / 4.0))
	bonus_spd = int(round(bonus_spd / 2.0))
	stat_version = 2

func get_rarity_color() -> Color:
	match rarity:
		Rarity.COMMON: return Color.WHITE
		Rarity.UNCOMMON: return Color(0.35, 0.9, 0.35)
		Rarity.RARE: return Color(0.35, 0.7, 1.0)
		Rarity.EPIC: return Color(0.75, 0.45, 1.0)
		Rarity.LEGENDARY: return Color(1.0, 0.6, 0.15)
	return Color.WHITE

func get_rarity_name() -> String:
	return EquipmentDB.RARITY_NAMES[rarity]

func get_type_name() -> String:
	return EquipmentDB.TYPE_NAMES[type]

## ข้อความสรุปค่าพลัง เช่น "ATK+12 SPD+2"
func get_stat_text() -> String:
	var parts: Array[String] = []
	if bonus_hp != 0: parts.append("HP%+d" % bonus_hp)
	if bonus_atk != 0: parts.append("ATK%+d" % bonus_atk)
	if bonus_def != 0: parts.append("DEF%+d" % bonus_def)
	if bonus_spd != 0: parts.append("SPD%+d" % bonus_spd)
	var text = " ".join(parts)
	if passive_skill != "":
		text += "\n[สกิลติดตัว] " + EquipmentDB.get_passive_desc(passive_skill)
	return text

## ราคาขายพื้นฐาน
func get_value() -> int:
	return int((bonus_hp * 4 + bonus_atk * 16 + bonus_def * 16 + abs(bonus_spd) * 20 + 20) * (1 + int(rarity)) * (2 if passive_skill != "" else 1))
