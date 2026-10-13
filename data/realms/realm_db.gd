extends Resource
class_name RealmDB

## ฐานข้อมูลลำดับขั้นบำเพ็ญทั้งหมด (แก้ไขได้ใน Inspector ที่ res://data/realms/realm_db.tres)
## realms[0] = คนธรรมดา, realms[1..] = ขั้นใหญ่ แต่ละขั้นใหญ่มี 9 ขั้นย่อย (ขั้นที่ 9 = คอขวด ต้องทะลวง)
## ฟิลด์ของแต่ละขั้น: name, desc, lifespan (ปี, -1 = อมตะ), mult (ตัวคูณค่าพลังต่อสู้), color (สีบนผังขั้นบำเพ็ญ)

const PATH = "res://data/realms/realm_db.tres"
const MINOR_STEPS = 9
## ตัวคูณเพิ่มต่อขั้นย่อยภายในขั้นใหญ่เดียวกัน (ขั้นย่อย 9 = +48%)
const MINOR_GROWTH = 0.06

@export var realms: Array[Dictionary] = []

static var _db: RealmDB

static func get_db() -> RealmDB:
	if _db == null:
		_db = load(PATH) as RealmDB
		if _db == null or _db.realms.is_empty():
			push_error("RealmDB: โหลด %s ไม่ได้" % PATH)
	return _db

static func all() -> Array[Dictionary]:
	return get_db().realms

static func major_count() -> int:
	return get_db().realms.size()

static func get_major(index: int) -> Dictionary:
	var list = get_db().realms
	return list[clampi(index, 0, list.size() - 1)]

## เลเวลสูงสุด (ขั้นใหญ่สุดท้าย ขั้นย่อย 9)
static func max_level() -> int:
	return (major_count() - 1) * MINOR_STEPS

## แยกเลเวล (1-81) เป็น [ขั้นใหญ่, ขั้นย่อย]
static func split(level: int) -> Array[int]:
	if level <= 0: return [0, 0]
	level = mini(level, max_level())
	var minor = level % MINOR_STEPS
	if minor == 0: minor = MINOR_STEPS
	return [int(ceil(level / float(MINOR_STEPS))), minor]

## เลเวลแรกของขั้นใหญ่ major
static func first_level(major: int) -> int:
	return (major - 1) * MINOR_STEPS + 1

## ตัวคูณค่าพลังต่อสู้ของเลเวลนี้ (ชั้นที่ 2 ของ StatSys)
static func multiplier(level: int) -> float:
	var s = split(level)
	var base: float = get_major(s[0]).get("mult", 1.0)
	if s[0] == 0: return base
	return base * (1.0 + (s[1] - 1) * MINOR_GROWTH)
