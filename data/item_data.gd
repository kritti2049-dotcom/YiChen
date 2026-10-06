extends Resource
class_name ItemData

enum ItemType { WEAPON, ARMOR, CONSUMABLE, MATERIAL }

@export var item_name: String = "New Item"
@export var icon: Texture2D
@export var item_type: ItemType = ItemType.WEAPON
@export var description: String = ""

## ตัวปรับ stat เมื่อสวมใส่/ใช้ (บวก/ลบได้ ใช้ตอน equip คำนวณรวมกับ UnitData)
@export var hp_modifier: int = 0
@export var attack_modifier: int = 0
@export var defense_modifier: int = 0
@export var speed_modifier: int = 0

## สำหรับ consumable: จำนวนใช้ได้ก่อนหมด (-1 = ใช้ได้ไม่จำกัด เช่น อาวุธถาวร)
@export var uses: int = -1

## สำหรับ crafting/customization system ในอนาคต: วัตถุดิบที่ใช้ทำ item นี้
@export var crafting_materials: Array[ItemData] = []
@export var crafting_material_counts: Array[int] = []
