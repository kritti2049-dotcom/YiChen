extends Node
class_name CultivationSys

## ระบบการฝึกตน (Cultivation System)
## จัดการกฎของ 9 ขั้นใหญ่ x 9 ระดับย่อย
## ข้อมูลของแต่ละขั้น (ชื่อ อายุขัย ตัวคูณ สี) เก็บใน RealmDB (res://data/realms/realm_db.tres)

## สีออร่าปราณตามธาตุ
const ELEMENT_COLORS = {
	"ไฟ": Color(1.0, 0.45, 0.2),
	"น้ำ": Color(0.3, 0.6, 1.0),
	"ไม้": Color(0.35, 0.9, 0.4),
	"ทอง": Color(1.0, 0.85, 0.3),
	"ดิน": Color(0.8, 0.6, 0.35),
	"สายฟ้า": Color(0.7, 0.5, 1.0),
}

## ขั้นใหญ่ที่เริ่มมีทัณฑ์สวรรค์ (ฟ้าผ่า) ตอนทะลวง
const TRIBULATION_MAJOR = 3

## 1 ปีในเกม = กี่วัน
const DAYS_PER_YEAR = 360

## คำนวณว่า เลเวล (1-81) อยู่ขั้นใหญ่และย่อยอะไร
static func get_realm_info(level: int) -> Dictionary:
	if level <= 0: return { "major_index": 0, "minor_index": 0, "name": RealmDB.get_major(0).name, "is_bottleneck": false }
	if level > RealmDB.max_level():
		return { "major_index": RealmDB.major_count() - 1, "minor_index": 9, "name": "%s ขั้นสมบูรณ์" % RealmDB.get_major(RealmDB.major_count() - 1).name, "is_bottleneck": false }
	var s = RealmDB.split(level)
	var major_name: String = RealmDB.get_major(s[0]).name
	var title = "%s ขั้นสมบูรณ์ (คอขวด)" % major_name if s[1] == 9 else "%s ขั้น %d" % [major_name, s[1]]
	return { "major_index": s[0], "minor_index": s[1], "name": title, "is_bottleneck": s[1] == 9 }

## คำนวณ EXP ที่ต้องการเพื่อขึ้นเลเวลถัดไป
static func get_required_exp(current_level: int) -> int:
	var info = get_realm_info(current_level)
	var major = info.major_index
	# ยิ่งขั้นใหญ่ยิ่งต้องการ EXP ก้าวกระโดดแบบทวีคูณ
	var base_exp = 100 * pow(3, major - 1)
	return int(base_exp + (info.minor_index * 50 * major))

## โอกาสทะลวงคอขวดขั้นใหญ่สำเร็จ (%)
static func get_breakthrough_chance(current_level: int, aptitude: int, pill_bonus: float = 0.0) -> float:
	var info = get_realm_info(current_level)
	if not info.is_bottleneck:
		return 100.0 # ไม่ใช่คอขวด ทะลวงง่ายๆ 100%

	# Base chance ลดลงเรื่อยๆ ตามระดับขั้นที่สูงขึ้น
	var base_chance = 90.0 - (info.major_index * 10.0)
	base_chance = max(5.0, base_chance)

	# รากวิญญาณ (1-10) เพิ่มโอกาสได้สูงสุด 20%
	var apt_bonus = aptitude * 2.0

	return clamp(base_chance + apt_bonus + pill_bonus, 1.0, 100.0)

static func get_lifespan(level: int) -> int:
	return RealmDB.get_major(get_realm_info(level).major_index).lifespan

static func get_realm_desc(level: int) -> String:
	return RealmDB.get_major(get_realm_info(level).major_index).desc

## สีออร่า: สีธาตุ ยิ่งขั้นสูงยิ่งสว่างอมทอง
static func get_aura_color(element: String, level: int) -> Color:
	var base: Color = ELEMENT_COLORS.get(element, Color(0.8, 0.9, 1.0))
	var major = get_realm_info(level).major_index
	return base.lerp(Color(1.0, 0.95, 0.75), clamp((major - 1) * 0.08, 0.0, 0.6))

## ทะลวงจาก current_level ไปขั้นถัดไปจะต้องรับทัณฑ์สวรรค์ไหม
static func has_tribulation(current_level: int) -> bool:
	return get_realm_info(current_level + 1).major_index >= TRIBULATION_MAJOR

## ความยากของมินิเกมต่อท่อลมปราณ: ขนาดตาราง และเวลาจำกัด (วินาที)
static func get_meridian_puzzle_params(current_level: int, aptitude: int) -> Dictionary:
	var target_major = get_realm_info(current_level + 1).major_index
	var size = clampi(4 + int(target_major / 2.0), 4, 8)
	var time_limit = max(15.0, 45.0 - target_major * 3.0 + aptitude)
	return { "size": size, "time": time_limit }
