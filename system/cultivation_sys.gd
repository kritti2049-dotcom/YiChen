extends Node
class_name CultivationSys

## ระบบการฝึกตน (Cultivation System)
## จัดการข้อมูล 9 ขั้นใหญ่ x 9 ระดับย่อย

const MAJOR_REALMS = [
	"คนธรรมดา", # 0
	"รวบรวมลมปราณ", # 1
	"สร้างรากฐาน", # 2
	"แกนทองคำ", # 3
	"วิญญาณแรกกำเนิด", # 4
	"ตัดวิญญาณ", # 5
	"หยั่งรู้ฟ้าดิน", # 6
	"ข้ามผ่านหายนะ", # 7
	"มหายาน", # 8
	"เซียนสวรรค์" # 9
]

## คำนวณว่า เลเวล (1-81) อยู่ขั้นใหญ่และย่อยอะไร
static func get_realm_info(level: int) -> Dictionary:
	if level <= 0: return { "major": 0, "minor": 0, "name": "คนธรรมดา" }
	if level > 81: return { "major": 9, "minor": 9, "name": "เซียนสวรรค์ ขั้นสมบูรณ์" }
	
	var major_index = int(ceil(level / 9.0))
	var minor_index = level % 9
	if minor_index == 0: minor_index = 9
	
	var major_name = MAJOR_REALMS[major_index]
	
	var title = ""
	if minor_index == 9:
		title = "%s ขั้นสมบูรณ์ (คอขวด)" % major_name
	else:
		title = "%s ขั้น %d" % [major_name, minor_index]
		
	return {
		"major_index": major_index,
		"minor_index": minor_index,
		"name": title,
		"is_bottleneck": minor_index == 9
	}

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
	
	# พรสวรรค์ (Aptitude) เพิ่มโอกาสสูงสุด 20%
	var apt_bonus = (aptitude / 100.0) * 20.0
	
	return clamp(base_chance + apt_bonus + pill_bonus, 1.0, 100.0)
