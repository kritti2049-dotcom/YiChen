extends Resource
class_name UnitData

## ข้อมูลพื้นฐานของ unit หนึ่งตัว (ทั้ง player และ enemy ใช้ resource นี้ร่วมกัน)
## สร้าง unit ใหม่โดยไม่ต้องเขียนโค้ด: คลิกขวาใน FileSystem > New Resource > UnitData

@export var unit_name: String = "New Unit"
@export var portrait: Texture2D
@export var sprite: Texture2D

## Stats หลัก
@export var max_hp: int = 100
@export var attack: int = 10
@export var defense: int = 5
@export var speed: int = 10  ## ใช้กำหนดลำดับเทิร์น ยิ่งสูงยิ่งได้เดินก่อน
@export var move_range: int = 3

## สำหรับระบบ 4X/customization: tag ไว้จัดกลุ่ม/กรอง (เช่น "faction_a", "melee", "mechanical")
@export var tags: Array[String] = []

## รายการ item ที่ unit นี้ถืออยู่ตอนเริ่ม (อ้างอิง ItemData resource)
@export var starting_equipment: Array[ItemData] = []

## สำหรับ tech tree / customization: unit นี้ต้องปลดล็อกอะไรก่อนถึงจะใช้ได้
@export var required_tech: String = ""
