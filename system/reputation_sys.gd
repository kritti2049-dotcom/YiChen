extends RefCounted
class_name ReputationSys

## ชื่อเสียงของสำนัก (Reputation) — จุดรวมคะแนนชื่อเสียง ขั้น และ "แนวทาง" (ธรรมะ ↔ มาร)
## - คะแนน = FactionSys.get_prestige (บารมีสำนัก + ถิ่นที่ยึด + ชื่อเสียง/พลังศิษย์) ไม่เก็บซ้ำ
## - ขั้นชื่อเสียงกำหนดจำนวน/คุณภาพผู้สมัคร (ApplicantSys), ความเต็มใจของตัวละครมีชื่อ (RosterSys)
## - แนวทาง (SectData.alignment −100 มาร .. +100 ธรรมะ) สะสมจากการกระทำ และเอียงชนิดผู้สมัคร/จุดจบ

## ขั้นชื่อเสียง: min = คะแนนขั้นต่ำ
const TIERS = [
	{ "min": 0, "name": "ไร้นาม" },
	{ "min": 80, "name": "เริ่มมีชื่อ" },
	{ "min": 250, "name": "ชื่อขจรในมณฑล" },
	{ "min": 550, "name": "ระบือแผ่นดิน" },
	{ "min": 1100, "name": "สะเทือนยุทธภพ" },
	{ "min": 2200, "name": "ตำนานยุทธภพ" },
]

## แคชคะแนนต่อวัน (คำนวณพลังรบของศิษย์ทุกคนแพง เรียกซ้ำหลายระบบต่อวัน) — เปลี่ยนเมื่อวัน/บารมี/จำนวนศิษย์/ถิ่นที่ยึดเปลี่ยน
static var _cache_key := ""
static var _cache_score := 0

static func score(sect: SectData) -> int:
	var key = "%d:%d:%d:%d:%d" % [sect.get_instance_id(), sect.current_day, sect.prestige, sect.disciples.size(), sect.count_owned_nodes()]
	if key != _cache_key:
		_cache_key = key
		_cache_score = FactionSys.get_prestige(sect)
	return _cache_score

static func tier(sect: SectData) -> int:
	var s = score(sect)
	var t = 0
	for i in TIERS.size():
		if s >= TIERS[i].min: t = i
	return t

static func tier_name(sect: SectData) -> String:
	return TIERS[tier(sect)].name

## คะแนนที่ต้องมีเพื่อขึ้นขั้นถัดไป (−1 = สูงสุดแล้ว)
static func next_threshold(sect: SectData) -> int:
	var t = tier(sect)
	return -1 if t >= TIERS.size() - 1 else TIERS[t + 1].min

static func add_alignment(sect: SectData, delta: int) -> void:
	sect.alignment = clampi(sect.alignment + delta, -100, 100)

static func alignment_name(sect: SectData) -> String:
	var a = sect.alignment
	if a >= 60: return "ธรรมะผู้เกรียงไกร"
	if a >= 25: return "ฝ่ายธรรมะ"
	if a > -25: return "เป็นกลาง"
	if a > -60: return "เอนไปทางมาร"
	return "จอมมารเหนือหล้า"

## ที่มาของคะแนนชื่อเสียง (ใช้แสดงใน UI ให้ผู้เล่นรู้ว่าเพราะอะไร)
static func breakdown(sect: SectData) -> Array:
	var fame = 0
	var power = 0
	for d in sect.get_active_disciples():
		fame += d.fame
		power += int(d.get_power_rating() / 5.0)
	return [
		{ "name": "บารมีสำนัก (ชนะศึก/เหตุการณ์)", "value": sect.prestige },
		{ "name": "ถิ่นที่ยึดครอง %d แห่ง" % maxi(0, sect.count_owned_nodes() - 1), "value": maxi(0, sect.count_owned_nodes() - 1) * 20 },
		{ "name": "ชื่อเสียงของศิษย์", "value": fame },
		{ "name": "พลังฝีมือศิษย์", "value": power },
	]

## ศิษย์ที่ดังที่สุด (ใช้เป็นเหตุผลที่ผู้สมัครอ้างถึง) null ถ้าไม่มี
static func star_disciple(sect: SectData) -> DiscipleData:
	var best: DiscipleData = null
	for d in sect.get_active_disciples():
		if best == null or d.fame > best.fame: best = d
	return best
