extends RefCounted
class_name HealthSystem

## สุขภาพแบบเรียบง่าย: ศิษย์บาดเจ็บ = สถานะ INJURED + จำนวนวันพักฟื้น (injury_days) ไม่มีอวัยวะ/เลือดไหล
## หมอ (ศิษย์ประจำหอแพทย์ / งาน "รักษา") ลดวันพักฟื้นและรักษาอาการพิษ/เส้นชีพจร (AilmentDB)
## บาดเจ็บสะสมเกิน DEADLY_DAYS วัน = สิ้นใจ

const DEADLY_DAYS = 25

## บาดเจ็บสะสมสาหัสเกินไป = เสียชีวิต
static func check_death(sect: SectData, d: DiscipleData, mgr: SectManager) -> void:
	if d.status == DiscipleData.DiscipleStatus.DEPARTED: return
	if d.injury_days >= DEADLY_DAYS:
		kill(sect, d, "บาดเจ็บสาหัสจนสิ้นใจ", mgr)

## เสียชีวิตในสำนัก: ทุกคนเห็นศพ สหาย/คนรักเศร้าหนัก ตัวคูณปรับตัวของเจตจำนงสวรรค์ลด
static func kill(sect: SectData, d: DiscipleData, cause: String, mgr: SectManager, faction := "") -> void:
	if d.status == DiscipleData.DiscipleStatus.DEPARTED: return
	FactionSys.on_disciple_killed(sect, d, faction, cause, mgr.log_event)
	on_death(sect, d)

## ผลทางอารมณ์ของการตาย (ใช้ร่วมกับการตายจากที่อื่น เช่น การต่อสู้)
static func on_death(sect: SectData, d: DiscipleData) -> void:
	sect.sim_stats["deaths"] = sect.sim_stats.get("deaths", 0) + 1
	sect.adaptation = max(0.4, sect.adaptation - 0.25)
	for o in PawnSys.present(sect):
		if o == d: continue
		PawnSys.add_thought(o, sect, "saw_corpse", null, d.disciple_name)
		if o.lover == d.disciple_name or o.spouse == d.disciple_name:
			PawnSys.add_thought(o, sect, "lover_died", null, d.disciple_name)
			o.lover = ""
			o.spouse = ""
		elif PawnSys.opinion(o, d) >= 40:
			PawnSys.add_thought(o, sect, "friend_died", null, d.disciple_name)

## หมอรักษา: ลดวันพักฟื้น (ตามทักษะแพทย์ + หอแพทย์) แล้วลองรักษาอาการ 1 อย่าง
static func treat(sect: SectData, doc: DiscipleData, p: DiscipleData, mgr: SectManager) -> void:
	if p == null: return
	var skill = PawnSys.skill_lv(doc, "medicine")
	var infirmary = sect.get_building_level("infirmary")
	if p.injury_days > 0:
		var cut_days = 1 + int(skill / 8.0) + (1 if infirmary > 0 else 0)
		p.injury_days = max(0, p.injury_days - cut_days)
		mgr.log_event("หมอ %s รักษา %s (พักฟื้นเหลือ %d วัน)" % [doc.disciple_name, p.disciple_name, p.injury_days], [doc, p])
		if p.injury_days == 0 and p.status == DiscipleData.DiscipleStatus.INJURED: p.status = DiscipleData.DiscipleStatus.IDLE
	if not p.ailments.is_empty():
		var ail = p.ailments[0]
		var info = AilmentDB.get_ailment(ail.id)
		var chance = AilmentDB.cure_chance(ail.id, int(skill / 2.0), infirmary)
		if randf() < chance:
			p.remove_ailment(ail.id)
			doc.add_fame(2)
			mgr.log_event("[color=lime]หมอ %s รักษา%sของ %s สำเร็จ![/color]" % [doc.disciple_name, info.name, p.disciple_name], [doc, p])
			if ail.id == "meridian_damage": ArchiveSys.unlock_achievement("divine_doctor")
		else:
			mgr.log_event("หมอ %s พยายามรักษา%sของ %s แต่ยังไม่สำเร็จ (โอกาส %d%%)" % [doc.disciple_name, info.name, p.disciple_name, int(chance * 100)], [doc, p])
	PawnSys.learn(doc, "medicine", 6)
