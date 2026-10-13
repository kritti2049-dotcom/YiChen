extends RefCounted
class_name ArchiveSys

## หอเกียรติยศ (Archive) — ข้อมูลข้ามเซฟแบบ Rogue-lite เก็บแยกจากเซฟสล็อต
## - คัมภีร์ที่เคยได้มาในรอบใดก็ตาม จะถูกปลดล็อกให้เลือกเป็นวิชาเริ่มต้นในเซฟใหม่
## - วิชาที่สำนักคิดค้นเอง (Legacy) ส่งต่อให้รุ่นต่อไปได้
## - ความสำเร็จแต่ละอันให้แต้มเริ่มต้นเพิ่มตอนสร้างตัวละคร

const PATH = "user://archive.json"
const POINTS_PER_ACHIEVEMENT = 2
const POINTS_PER_ENDING = 5

## วิชาพื้นฐานที่เลือกได้ตั้งแต่แรกโดยไม่ต้องปลดล็อก
const BASIC_SKILLS = ["หมัดคนตัดไม้", "กระบี่ไม้ไผ่", "ก้าวลวงตา", "ปราณฟื้นฟู", "ดาบผ่าฟืน", "ปราณพื้นฐานสำนัก", "มีดสั้นบิน", "พิษงูเขียว", "ทวนพื้นฐานทหารหลวง"]

const ACHIEVEMENTS = {
	"first_building": { "name": "วางศิลาฤกษ์", "desc": "สร้างสิ่งปลูกสร้างหลังแรกเสร็จ" },
	"grand_sect": { "name": "สำนักใหญ่โต", "desc": "มีสิ่งปลูกสร้างครบทุกประเภท" },
	"ten_disciples": { "name": "ศิษย์เต็มลาน", "desc": "มีศิษย์ในสำนักพร้อมกัน 10 คน" },
	"first_breakthrough": { "name": "ทะลวงคอขวด", "desc": "ศิษย์ทะลวงคอขวดขั้นใหญ่สำเร็จครั้งแรก" },
	"golden_core": { "name": "แกนทองคำ", "desc": "มีศิษย์บรรลุขั้นแกนทองคำ" },
	"nascent_soul": { "name": "วิญญาณแรกกำเนิด", "desc": "มีศิษย์บรรลุขั้นวิญญาณแรกกำเนิด" },
	"secret_realm_sweep": { "name": "กวาดแดนลับ", "desc": "ชนะคู่แข่งครบ 3/3 ในแดนลับ" },
	"custom_skill": { "name": "ปรมาจารย์ผู้คิดค้น", "desc": "คิดค้นวิชาเฉพาะของสำนักเอง" },
	"divine_doctor": { "name": "หมอเทวดา", "desc": "รักษาเส้นชีพจรขาดสะบั้นสำเร็จ" },
	"feud_avenged": { "name": "ล้างแค้นสำเร็จ", "desc": "ศิษย์ล้างแค้นให้สหายที่ถูกฆ่าได้" },
	"conqueror": { "name": "ขยายอาณาเขต", "desc": "ยึดครองพื้นที่บนแผนที่โลก 5 แห่ง" },
	"sect_destroyer": { "name": "ถล่มสำนัก", "desc": "บุกตีสำนักใหญ่จนพลังเหลือต่ำกว่าครึ่ง" },
	"top_ranked": { "name": "อันดับหนึ่งใต้หล้า", "desc": "ศิษย์ขึ้นอันดับ 1 ทำเนียบยุทธภพ" },
	"wulin_leader": { "name": "จ้าวยุทธภพ", "desc": "ได้รับเลือกเป็นจ้าวยุทธภพในที่ประชุมยุทธภพ" },
	"survive_100": { "name": "ร้อยวันแห่งการบ่มเพาะ", "desc": "ประคองสำนักได้ครบ 100 วัน" },
	"survive_365": { "name": "หนึ่งปีแห่งยุทธภพ", "desc": "ประคองสำนักได้ครบ 1 ปี" },
}

static var _data := {}

static func data() -> Dictionary:
	if _data.is_empty():
		_data = { "unlocked_skills": [], "achievements": {}, "legacy_skills": {}, "endings": {}, "runs": 0 }
		if FileAccess.file_exists(PATH):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
			if parsed is Dictionary:
				for k in parsed: _data[k] = parsed[k]
	return _data

static func save() -> void:
	var f = FileAccess.open(PATH, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(data(), "\t"))

## ปลดล็อกคัมภีร์ (คืนค่า true ถ้าเพิ่งปลดล็อกครั้งแรก)
static func unlock_skill(skill: String) -> bool:
	if skill == "" or BASIC_SKILLS.has(skill) or data().unlocked_skills.has(skill): return false
	data().unlocked_skills.append(skill)
	save()
	return true

static func is_skill_unlocked(skill: String) -> bool:
	return BASIC_SKILLS.has(skill) or data().unlocked_skills.has(skill) or data().legacy_skills.has(skill)

## ปลดล็อกความสำเร็จ (คืนค่า true ถ้าเพิ่งได้ครั้งแรก)
static func unlock_achievement(id: String) -> bool:
	if not ACHIEVEMENTS.has(id) or data().achievements.has(id): return false
	data().achievements[id] = Time.get_date_string_from_system()
	save()
	return true

static func has_achievement(id: String) -> bool:
	return data().achievements.has(id)

static func bonus_points() -> int:
	return data().achievements.size() * POINTS_PER_ACHIEVEMENT + data().endings.size() * POINTS_PER_ENDING

## บันทึกจุดจบที่เคยพบ (คืน true ถ้าเพิ่งพบครั้งแรก) ให้แต้มเริ่มต้นเพิ่มในเซฟถัดไป
static func unlock_ending(id: String) -> bool:
	if data().endings.has(id): return false
	data().endings[id] = Time.get_date_string_from_system()
	save()
	return true

static func has_ending(id: String) -> bool:
	return data().endings.has(id)

## บันทึกวิชาที่สำนักคิดค้นเอง เพื่อส่งต่อข้ามรุ่น
static func add_legacy_skill(skill_name: String, info: Dictionary) -> void:
	data().legacy_skills[skill_name] = info.duplicate()
	save()

static func new_run() -> void:
	data().runs = int(data().get("runs", 0)) + 1
	save()
