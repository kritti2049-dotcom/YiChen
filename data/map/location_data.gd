extends Resource
class_name LocationData

## ข้อมูลพื้นฐานของแต่ละสถานที่บนแผนที่โลก

@export var location_id: String = "loc_001"
@export var location_name: String = "ชื่อสถานที่"
@export_multiline var description: String = "รายละเอียดของสถานที่แห่งนี้"

enum LocationType { SECT, TOWN, FOREST, DUNGEON, RESOURCE_NODE }
@export var type: LocationType = LocationType.TOWN

## ระยะเวลาเดินทางจากสำนักของเรา (สมมติเป็นหน่วย วัน)
@export var travel_days: int = 1

## สถานที่นี้ถูกปลดล็อกให้มองเห็น/ไปได้ หรือยัง?
@export var is_unlocked: bool = true

## ไอเทมหรือทรัพยากรที่หาได้จากที่นี่ (ไว้ต่อยอดระบบฟาร์ม)
@export var resource_drops: Array[String] = []
