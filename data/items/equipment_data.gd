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

@export_group("Special Effects")
## สกิลติดตัวเฉพาะของชิ้นนี้ (ถ้ามี)
@export var passive_skill: String = ""

func get_rarity_color() -> Color:
	match rarity:
		Rarity.COMMON: return Color.WHITE
		Rarity.UNCOMMON: return Color.GREEN
		Rarity.RARE: return Color.DODGER_BLUE
		Rarity.EPIC: return Color.PURPLE
		Rarity.LEGENDARY: return Color.ORANGE
	return Color.WHITE
