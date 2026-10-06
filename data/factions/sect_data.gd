extends Resource
class_name SectData

## ข้อมูลสถานะของสำนักหนึ่งๆ
## สร้างใหม่: คลิกขวาใน FileSystem > New Resource > SectData

@export var sect_name: String = "สำนักไร้นาม"

@export_group("Resources")
## จำนวนเงินของสำนัก
@export var money: int = 1000
## จำนวนเสบียงอาหารของสำนัก
@export var food: int = 500
## จำนวนสมุนไพรวิญญาณ (ใช้ปรุงยา)
@export var herbs: int = 0
## จำนวนยาทะลวงปราณ (ช่วยเพิ่มโอกาสทะลวงคอขวด)
@export var breakthrough_pills: int = 0

@export_group("Members & Assets")
## รายชื่อลูกศิษย์ในสำนัก
@export var disciples: Array[DiscipleData] = []
## อาคารที่สร้างแล้วในสำนัก
@export var buildings: Array[BuildingData] = []

@export_group("History & Events")
## ประวัติเหตุการณ์ของสำนัก (Newsfeed)
## แต่ละรายการคือ Dictionary: { "day": int, "text": String, "involved_ids": Array }
@export var event_log: Array[Dictionary] = []

## ฟังก์ชันช่วยเหลือสำหรับเพิ่มเหตุการณ์เข้าสู่ประวัติสำนัก
func log_event(day: int, text: String, involved_ids: Array = []) -> void:
	event_log.append({
		"day": day,
		"text": text,
		"involved_ids": involved_ids
	})
