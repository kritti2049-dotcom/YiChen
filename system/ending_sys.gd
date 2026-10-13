extends RefCounted
class_name EndingSys

## ระบบจุดจบ: เช็กเงื่อนไขทุกวัน (SectManager.process_daily_update) เมื่อครบเงื่อนไขจะตั้ง SectData.pending_ending
## จุดจบแบบชนะ (win) เล่นต่อได้ ไม่เด้งซ้ำ (ending_flags.seen) · แบบแพ้ (lose) จบเกม
## ธงที่ใช้: ending_flags { seen: [id], leader_terms, sieges, throne: "prince"|"eunuch", last_raider }

const THRONE_NODES_NEEDED = 3
const LEGEND_DAYS = 1080
const LEGEND_DISCIPLES = 30
const LEADER_TERMS = 2
const DEMON_SIEGES = 2

static func seen(sect: SectData) -> Array:
	return sect.ending_flags.get("seen", [])

static func _flag(sect: SectData, key: String, default = 0):
	return sect.ending_flags.get(key, default)

## จำนวนถิ่นในมณฑลจิงจีที่เรายึดไว้
static func _core_nodes_owned(sect: SectData) -> int:
	var n = 0
	for id in sect.node_owner:
		if sect.node_owner[id] == "player" and WorldDB.NODES.get(id, {}).get("region", "") == "jingji" and id != "sect": n += 1
	return n

static func _court_weak(sect: SectData) -> bool:
	if not sect.factions.has("f_court"): return true
	return sect.factions.f_court.power < FactionDB.FACTIONS.f_court.power * 0.6

static func _top_realm(sect: SectData) -> int:
	var best = 0
	for d in sect.get_active_disciples(): best = maxi(best, RealmDB.split(d.level)[0])
	return best

## เงื่อนไขของจุดจบ: [{ text, cur, need }] ครบเมื่อ cur >= need ทุกข้อ
static func conditions(sect: SectData, id: String) -> Array:
	var tier = ReputationSys.tier(sect)
	match id:
		"wulin_leader":
			return [
				{ "text": "ได้เป็นจ้าวยุทธภพติดต่อกัน (การประชุม)", "cur": _flag(sect, "leader_terms"), "need": LEADER_TERMS },
				{ "text": "ชื่อเสียง: สะเทือนยุทธภพ", "cur": tier, "need": 4 },
			]
		"throne_prince", "throne_eunuch":
			var side = "prince" if id == "throne_prince" else "eunuch"
			return [
				{ "text": "เลือกข้างในบท 'จักรพรรดิสวรรคต' (%s)" % ("ช่วยองค์ชายสี่" if side == "prince" else "สนับสนุนสิบขันที"), "cur": 1 if _flag(sect, "throne", "") == side else 0, "need": 1 },
				{ "text": "ยึดถิ่นในมณฑลจิงจี", "cur": _core_nodes_owned(sect), "need": THRONE_NODES_NEEDED },
				{ "text": "ราชสำนักอ่อนกำลัง (เหลือไม่ถึง 60%)", "cur": 1 if _court_weak(sect) else 0, "need": 1 },
			]
		"demon_lord":
			return [
				{ "text": "แนวทางมาร (ระดับ -60)", "cur": maxi(0, -sect.alignment), "need": 60 },
				{ "text": "ครอบครอง %s" % EquipmentDB.CURSED_SWORD, "cur": 1 if StorytellerSystem.owns_cursed_sword(sect) else 0, "need": 1 },
				{ "text": "บุกตีสำนักใหญ่สำเร็จ", "cur": _flag(sect, "sieges"), "need": DEMON_SIEGES },
				{ "text": "ชื่อเสียง: สะเทือนยุทธภพ", "cur": tier, "need": 4 },
			]
		"ascension":
			return [{ "text": "ศิษย์ก้าวสู่ขั้นบำเพ็ญสูงสุด", "cur": _top_realm(sect), "need": RealmDB.major_count() - 1 }]
		"legend_sect":
			return [
				{ "text": "อยู่รอด (วัน)", "cur": sect.current_day, "need": LEGEND_DAYS },
				{ "text": "ศิษย์ในสำนัก", "cur": sect.get_active_disciples().size(), "need": LEGEND_DISCIPLES },
				{ "text": "ชื่อเสียง: สะเทือนยุทธภพ", "cur": tier, "need": 4 },
			]
	return []

## ความคืบหน้า 0..1 ของจุดจบ
static func progress(sect: SectData, id: String) -> float:
	var conds = conditions(sect, id)
	if conds.is_empty(): return 0.0
	var total = 0.0
	for c in conds: total += clampf(float(c.cur) / maxf(1.0, float(c.need)), 0.0, 1.0)
	return total / conds.size()

static func is_met(sect: SectData, id: String) -> bool:
	var conds = conditions(sect, id)
	if conds.is_empty(): return false
	for c in conds:
		if c.cur < c.need: return false
	return true

## ตรวจทุกจุดจบแบบชนะที่ยังไม่เคยเห็น คืน id แรกที่ครบ ("" = ไม่มี)
static func check(sect: SectData) -> String:
	for id in EndingDB.ORDER:
		if id in seen(sect): continue
		if is_met(sect, id): return id
	return ""

## ประกาศจุดจบ: บันทึกว่าเห็นแล้ว + เก็บเข้าหอเกียรติยศ + ตั้ง pending_ending ให้ UI แสดง
static func trigger(sect: SectData, id: String) -> void:
	if not sect.ending_flags.has("seen"): sect.ending_flags["seen"] = []
	if id not in sect.ending_flags.seen: sect.ending_flags.seen.append(id)
	sect.ending_flags["last_ending_day"] = sect.current_day
	sect.pending_ending = id
	ArchiveSys.unlock_ending(id)
	sect.log_event(sect.current_day, "[color=gold]【จุดจบ】 %s[/color]" % EndingDB.ENDINGS[id].name)
	if EndingDB.ENDINGS[id].kind == "lose":
		sect.is_game_over = true

## รายวัน (เรียกท้าย process_daily_update)
static func daily(sect: SectData) -> void:
	if sect.is_game_over or sect.pending_ending != "": return
	var id = check(sect)
	if id != "": trigger(sect, id)

# ── ตัวนับ/ธงที่ระบบอื่นเรียกใช้ ──

static func note_conference(sect: SectData) -> void:
	sect.ending_flags["leader_terms"] = _flag(sect, "leader_terms") + 1 if sect.wulin_leader == "player" else 0

static func note_siege(sect: SectData) -> void:
	sect.ending_flags["sieges"] = _flag(sect, "sieges") + 1

static func note_throne(sect: SectData, side: String) -> void:
	sect.ending_flags["throne"] = side

static func note_raider(sect: SectData, who: String) -> void:
	sect.ending_flags["last_raider"] = who

## ข้อความของจุดจบ (จุดจบแพ้ใส่ชื่อผู้ทำลายถ้ามี)
static func ending_text(sect: SectData, id: String) -> String:
	var t: String = EndingDB.ENDINGS[id].text
	if id == "collapse" and _flag(sect, "last_raider", "") != "":
		t += "\n\nผู้ที่ก่อนหน้านี้บุกสำนักครั้งสุดท้าย: %s" % _flag(sect, "last_raider", "")
	return t

## สถิติสรุปเกมสำหรับหน้าจอจุดจบ
static func summary(sect: SectData) -> Array[String]:
	return [
		"สำนัก%s · วันที่ %d" % [sect.sect_name, sect.current_day],
		"ศิษย์ในสำนัก %d คน · ถิ่นที่ยึด %d แห่ง" % [sect.get_active_disciples().size(), maxi(0, sect.count_owned_nodes() - 1)],
		"ชื่อเสียง: %s (%d) · แนวทาง: %s" % [ReputationSys.tier_name(sect), ReputationSys.score(sect), ReputationSys.alignment_name(sect)],
		"จุดจบที่พบแล้ว: %d / %d" % [seen(sect).size(), EndingDB.ENDINGS.size()],
	]
