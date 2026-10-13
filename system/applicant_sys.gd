extends RefCounted
class_name ApplicantSys

## ผู้สมัครเข้าสำนัก: ชื่อเสียงยิ่งสูง คนยิ่งมาสมัครบ่อย/เยอะ/เก่งขึ้น (แทนการสุ่มคนพเนจรเดิม)
## ผู้สมัครรอที่ประตูสำนัก (SectData.applicants) ผู้เล่นเลือกรับ/ปฏิเสธ หมดอายุแล้วจากไปเอง
## แนวทางสำนัก (alignment) เอียงสายวิชาของผู้สมัคร และเหตุผลที่มาสมัคร

const EXPIRE_DAYS = 10
const BASE_GAP = 5
const BASE_CAP = 3

## จำนวนที่รอได้สูงสุด
static func capacity(sect: SectData) -> int:
	return BASE_CAP + ReputationSys.tier(sect)

static func gap_days(sect: SectData) -> int:
	return maxi(2, BASE_GAP - ReputationSys.tier(sect) / 2)

## รายวัน: ลบคนที่รอนานเกิน แล้วถึงเวลาก็มีผู้สมัครใหม่
static func daily(sect: SectData, mgr: SectManager) -> void:
	var day = sect.current_day
	var left: Array[Dictionary] = []
	for a in sect.applicants:
		if day > a.expire:
			mgr.log_event("%s รอที่ประตูสำนักนานเกินไปจึงเดินจากไป" % a.npc.disciple_name)
		else:
			left.append(a)
	sect.applicants = left
	if day < sect.next_applicant_day: return
	sect.next_applicant_day = day + randi_range(gap_days(sect), gap_days(sect) + 2)
	var n = 1 + (1 if ReputationSys.tier(sect) >= 3 and randf() < 0.5 else 0)
	var made = spawn(sect, n)
	if not made.is_empty():
		mgr.log_event("[color=lime]มีผู้สมัครมาที่ประตูสำนัก: %s (เปิดดูที่เมนู ประตูสำนัก)[/color]" % ", ".join(made.map(func(a): return a.npc.disciple_name)))

## สร้างผู้สมัคร n คน (คืนรายการที่เพิ่มจริง) reason = เหตุผลบังคับ ("" = เลือกตามชื่อเสียง)
static func spawn(sect: SectData, n: int, reason := "") -> Array[Dictionary]:
	var made: Array[Dictionary] = []
	var t = ReputationSys.tier(sect)
	for i in n:
		if sect.applicants.size() >= capacity(sect): break
		var roll = randf()
		var talent = 2 if roll < 0.01 + 0.012 * t else (1 if roll < 0.06 + 0.05 * t else 0)
		var level = 1 + randi_range(0, 1 + t * 2)
		var npc = NPCGenerator.generate_npc(talent, level)
		_bias_style(sect, npc)
		sect.applicants.append({ "npc": npc, "talent": talent, "reason": reason if reason != "" else _reason(sect, npc), "expire": sect.current_day + EXPIRE_DAYS })
		made.append(sect.applicants[-1])
	return made

## สำนักฝ่ายมาร ดึงดูดสายพิษ/อาวุธลับ ฝ่ายธรรมะดึงดูดสายกระบี่/ปราณ (เปลี่ยนสายพรสวรรค์ที่สุ่มมาบางส่วน)
static func _bias_style(sect: SectData, npc: DiscipleData) -> void:
	if absi(sect.alignment) < 25 or randf() > 0.5: return
	var styles = ["poison", "hidden_weapon"] if sect.alignment < 0 else ["sword", "internal", "palm"]
	npc.affinity_style = styles[randi() % styles.size()]

static func _reason(sect: SectData, npc: DiscipleData) -> String:
	var options: Array[String] = []
	var star = ReputationSys.star_disciple(sect)
	if star != null and star.fame >= 30:
		options.append("ชื่นชม%s ที่โด่งดังจากการต่อสู้" % star.get_display_name())
	if sect.count_owned_nodes() > 1:
		options.append("ได้ยินว่าสำนักยึดครองถิ่นฐานได้หลายแห่ง")
	if sect.alignment <= -25:
		options.append("ต้องการหลบหนีไปพึ่งสำนักที่ไม่ถือกฎธรรมะ")
	elif sect.alignment >= 25:
		options.append("ศรัทธาในแนวทางธรรมะของสำนัก")
	if sect.prestige >= 50:
		options.append("เลื่องลือเรื่องชัยชนะของสำนักไปทั่วมณฑล")
	if options.is_empty():
		options.append(["เร่ร่อนหาที่พึ่งพิง", "อยากเรียนวิชาเพื่อแก้แค้น", "ได้ยินข่าวลือว่าสำนักกำลังรับศิษย์"].pick_random())
	return options[randi() % options.size()]

## รับผู้สมัครลำดับ index เข้าสำนัก คืนข้อความ ("" ถ้าไม่สำเร็จ)
static func accept(sect: SectData, index: int, mgr: SectManager) -> String:
	if index < 0 or index >= sect.applicants.size(): return ""
	if sect.get_active_disciples().size() >= sect.get_max_disciples(): return "ศิษย์เต็มแล้ว อัปเกรดโถงหลักก่อน"
	var a = sect.applicants[index]
	sect.applicants.remove_at(index)
	var npc: DiscipleData = a.npc
	PawnSys.ensure(npc, sect)
	npc.pos = Territory.gate_pos()
	sect.disciples.append(npc)
	for s in npc.innate_skills: sect.add_library_skill(s)
	var text = "รับ %s เข้าสำนัก (%s · พรสวรรค์สาย%s · พลังรบ %d)" % [npc.disciple_name, npc.realm_name, npc.affinity_style_name(), npc.get_power_rating()]
	mgr.log_event(text)
	return text

static func reject(sect: SectData, index: int) -> void:
	if index >= 0 and index < sect.applicants.size(): sect.applicants.remove_at(index)
