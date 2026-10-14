extends RefCounted
class_name SkillQuestSys

## ช่องทางได้วิชาเพิ่ม (นอกจากถอดรหัส/ซื้อ/ประมูล/ยึดพื้นที่ที่มีอยู่เดิม)
## 1. ตรัสรู้จากความชำนาญ: ชำนาญสายใดถึง "แตกฉาน" (ระดับ 5) ขึ้นไป มีโอกาสคิดท่าใหม่เองระหว่างฝึก/หลังชนะศึก = วิชาประจำสำนัก
## 2. ขอเรียนจากยอดฝีมือ: ประลองชนะ + รู้จักกันลึก (insight 2) + ความรู้สึกดี = ขอให้สอนวิชาประจำตัว (เสียค่าเล่าเรียน ครั้งเดียวต่อคน)
## 3. ศิลาจารึก/สุสานยอดฝีมือ: จุดใหม่บนแผนที่ ส่งศิษย์ไปนั่งสมาธิ MEDITATE_DAYS วัน ลุ้นตรัสรู้วิชาขั้นสูง เสี่ยงธาตุไฟแตกซ่าน
## 4. แลกวิชากับสำนักที่สนิท (ความสัมพันธ์ ≥ TRADE_REL): ได้วิชาสายของเขา แต่เขาแข็งขึ้นด้วย (รอบละครั้งต่อสำนัก)
## 5. ฝากศิษย์ไปเรียนสำนักอื่น (ความสัมพันธ์ ≥ APPRENTICE_REL): หายไป APPRENTICE_DAYS วัน กลับมาพร้อมวิชาสายสำนักนั้น
## 6. เหตุการณ์สุ่ม: ศิษย์ระหว่างเดินทางพลัดตกหน้าผาเจอคัมภีร์ในถ้ำ · พ่อค้าเร่ขายคัมภีร์ (อาจเป็นของปลอม)
## 7. ร้านหนังสือในเมือง: ขายวิชาขั้นมนุษย์ (สินค้าเปลี่ยนทุกรอบ)

const INSIGHT_COOLDOWN = 60
## ทั้งสำนักตรัสรู้ได้ไม่ถี่กว่านี้ (วัน) ของหายากต้องหายากจริง
const SECT_INSIGHT_GAP = 25
const MEDITATE_DAYS = 10
const APPRENTICE_DAYS = 30
const TRADE_REL = 50
const APPRENTICE_REL = 30
const TRADE_PERIOD = 30

## สายความชำนาญ -> ชนิดวิชา (SkillDB) และคำตั้งชื่อท่า
const MASTERY_TO_SKILL = { "sword": "sword", "saber": "sword", "spear": "spear", "fist": "palm", "hidden": "hidden_weapon", "poison": "poison" }
const NAME_HEAD = {
	"sword": "กระบี่", "saber": "ดาบ", "spear": "ทวน", "fist": "ฝ่ามือ", "hidden": "เข็ม", "poison": "พิษ",
}
const NAME_MID = ["เมฆา", "อัสนี", "พิรุณ", "จันทรา", "สุริยัน", "วายุ", "มังกร", "หงส์", "พยัคฆ์", "ธารา", "หิมะ", "เพลิง", "ไร้เงา", "ร้อยบุปผา", "พันลี้"]
const NAME_TAIL = ["พลิกฟ้า", "ทะลวงใจ", "สะท้านภพ", "ไร้รอย", "ข้ามนภา", "แหวกสมุทร", "ผลาญดารา", "ล่าวิญญาณ", "หมื่นเงา", "คืนสู่เดิม"]
const TIER_POWER = [0, 18, 40, 75, 135, 260]

# ══════════════════════════════════════════
# 1. ตรัสรู้จากความชำนาญ
# ══════════════════════════════════════════

## เรียกหลังฝึกหรือชนะศึก: chance_mult = ตัวคูณโอกาส (ศึกจริงตรัสรู้ง่ายกว่าฝึกซ้อม)
static func try_insight(sect: SectData, d: DiscipleData, mtype: String, mgr: SectManager, chance_mult := 1.0) -> String:
	if mtype == "" or not MASTERY_TO_SKILL.has(mtype): return ""
	var lv = MasterySys.get_level(d, mtype)
	if lv < 5: return ""
	if sect.current_day - d.last_insight_day < INSIGHT_COOLDOWN: return ""
	if sect.current_day - int(sect.sim_stats.get("last_insight_day", -999)) < SECT_INSIGHT_GAP: return ""
	var chance = 0.003 * (lv - 4) * (1.0 + d.get_stat("comprehension") * 0.05) * chance_mult
	if randf() >= chance: return ""
	d.last_insight_day = sect.current_day
	sect.sim_stats["last_insight_day"] = sect.current_day
	# ขั้นวิชา: แตกฉาน-ยอดฝีมือ = ปฐพี · ปรมาจารย์+ = นภา · ไร้เทียมทาน+ = เซียน (เทวะได้แค่ระดับ 10 โอกาส 20%)
	var tier = 2 if lv <= 6 else (3 if lv <= 8 else 4)
	if lv >= 10 and randf() < 0.2: tier = 5
	var name = _make_name(mtype)
	var info = {
		"tier": tier, "type": MASTERY_TO_SKILL[mtype], "power": int(TIER_POWER[tier] * randf_range(0.95, 1.2)),
		"desc": "วิชาประจำ%s ที่ %s ตรัสรู้จากการฝึก%sจนแตกฉาน" % [sect.sect_name, d.disciple_name, MasterySys.type_name(mtype)],
	}
	register_skill(sect, name, info)
	if d.learned_skills.size() < d.get_max_skills(): d.learned_skills.append(name)
	d.add_fame(30)
	d.add_memory(sect.current_day, "ตรัสรู้คิดค้นวิชา " + name)
	var text = "[color=gold]%s ฝึก%sจนแตกฉาน แล้วตรัสรู้ท่าใหม่ [b]%s[/b] (ขั้น%s) — บรรจุเข้าหอตำราเป็นวิชาประจำสำนัก![/color]" % [d.disciple_name, MasterySys.type_name(mtype), name, SkillDB.TIER_NAMES[tier]]
	if mgr: mgr.log_event(text, [d])
	return text

static func _make_name(mtype: String) -> String:
	for i in 20:
		var n = "%s%s%s" % [NAME_HEAD.get(mtype, "วิชา"), NAME_MID[randi() % NAME_MID.size()], NAME_TAIL[randi() % NAME_TAIL.size()]]
		if SkillDB.get_skill(n).is_empty(): return n
	return "%s ลับ %d" % [NAME_HEAD.get(mtype, "วิชา"), randi() % 1000]

## ลงทะเบียนวิชาใหม่ของสำนัก (บันทึกในเซฟ + หอเกียรติยศ + หอตำรา)
static func register_skill(sect: SectData, name: String, info: Dictionary) -> void:
	sect.custom_skills[name] = info
	SkillDB.register_custom({ name: info })
	ArchiveSys.add_legacy_skill(name, info)
	sect.add_library_skill(name)

# ══════════════════════════════════════════
# 2. ขอเรียนจากยอดฝีมือ
# ══════════════════════════════════════════

static func teach_fee(e: Dictionary) -> int:
	return 150 + int(e.tier) * 350

## เหตุผลที่ยังขอเรียนไม่ได้ ("" = ได้)
static func teach_block(sect: SectData, e: Dictionary) -> String:
	if e.get("skill", "") == "": return "ไม่มีวิชาประจำตัวให้สอน"
	if e.get("taught", false): return "สอนวิชาให้แล้ว"
	if not e.sparred: return "ต้องประลองชนะเขาก่อน"
	if int(e.insight) < 2: return "ต้องรู้จักกันมากกว่านี้ (ถามไถ่ให้ถึงระดับ 2)"
	if int(e.opinion) < 15: return "ความรู้สึกที่มีต่อเรายังไม่พอ (ต้อง 15+)"
	if sect.money < teach_fee(e): return "ค่าเล่าเรียนไม่พอ (%d)" % teach_fee(e)
	return ""

static func teach(sect: SectData, e: Dictionary, student: DiscipleData) -> String:
	var why = teach_block(sect, e)
	if why != "": return why
	sect.money -= teach_fee(e)
	e["taught"] = true
	var s: String = e.skill
	sect.add_library_skill(s)
	var learned = ""
	if student != null and not student.learned_skills.has(s) and student.learned_skills.size() < student.get_max_skills() and MasterySys.can_learn(student, s):
		student.learned_skills.append(s)
		learned = " · %s เรียนสำเร็จทันที" % student.disciple_name
	elif student != null and not student.learned_skills.has(s):
		student.study_skill = s
		student.study_progress = 50.0
		learned = " · %s ได้พื้นฐานไปครึ่งทาง (ศึกษาต่อที่หอตำรา)" % student.disciple_name
	var text = "%s ถ่ายทอดวิชา %s ให้ (เข้าหอตำราแล้ว%s)" % [e.name, s, learned]
	sect.log_event(sect.current_day, "[color=cyan]%s[/color]" % text)
	return text

# ══════════════════════════════════════════
# 3. ศิลาจารึก / สุสานยอดฝีมือ
# ══════════════════════════════════════════

const STELES = [
	{ "name": "ศิลาจารึกกระบี่ไร้นาม", "type": "sword", "tier": 3 },
	{ "name": "สุสานจ้าวฝ่ามือเหล็ก", "type": "palm", "tier": 3 },
	{ "name": "ผาจารึกทวนพันศึก", "type": "spear", "tier": 3 },
	{ "name": "ถ้ำเซียนพิษพันปี", "type": "poison", "tier": 4 },
	{ "name": "สุสานกระบี่เทพ", "type": "sword", "tier": 4 },
]

## เพิ่มศิลาจารึกบนแผนที่ (เซฟเก่า/ใหม่) ครั้งเดียว บนป่า/ถ้ำ/แดนลับที่ยังไม่มีจุดสำคัญ
static func ensure_steles(sect: SectData) -> void:
	if sect.world_seed == 0 or sect.landmarks.any(func(l): return l.kind == "stele"): return
	var rng = RandomNumberGenerator.new()
	rng.seed = hash([sect.world_seed, "stele"])
	var used := {}
	for l in sect.landmarks: used[l.node] = true
	var nodes: Array = []
	for id in WorldDB.NODES:
		var t = WorldDB.NODES[id].type
		if (t == WorldDB.NodeType.WILD or t == WorldDB.NodeType.DUNGEON) and not used.has(id): nodes.append(id)
	nodes.sort()
	for i in range(nodes.size() - 1, 0, -1):
		var j = rng.randi_range(0, i)
		var tmp = nodes[i]
		nodes[i] = nodes[j]
		nodes[j] = tmp
	for i in mini(STELES.size(), nodes.size()):
		var s = STELES[i]
		var skill = SkillDB.get_random_skill_by_tier_and_type(s.tier, s.type)
		sect.landmarks.append({ "id": "stele_%d" % i, "node": nodes[i], "kind": "stele", "name": s.name, "tier": s.tier, "type": s.type, "skill": skill,
			"desc": "ร่องรอยวิชาของยอดฝีมือในอดีต นั่งสมาธิพินิจนานพออาจตรัสรู้ %s" % skill, "known": i < 2, "claimed": false, "acc": 0.0 })

static func stele_at(sect: SectData, node_id: String) -> Dictionary:
	for l in sect.landmarks:
		if l.kind == "stele" and l.node == node_id and l.known: return l
	return {}

## วันหนึ่งของการนั่งสมาธิ: สะสมความเข้าใจ เสี่ยงธาตุไฟ · ครบวันแล้วตัดสินผล (คืนข้อความ "" = ยังไม่จบ)
static func meditate_day(sect: SectData, d: DiscipleData, logs: Array[String]) -> void:
	var l = stele_at(sect, d.mission_target)
	if l.is_empty(): return
	var mtype = MasterySys.skill_type(l.skill)
	if mtype != "": MasterySys.gain(d, mtype, 3)
	d.needs["meditate"] = float(d.needs.get("meditate", 0.0)) + (0.08 + d.get_stat("comprehension") * 0.012) * MasterySys.fit_skill(d, l.skill)
	# เสี่ยงธาตุไฟแตกซ่าน: เครียดสะสม ยิ่งขั้นวิชาสูงยิ่งเสี่ยง
	if randf() < 0.03 + int(l.tier) * 0.01:
		StressSystem.add(d, 20.0)
		logs.append("[color=orange]%s นั่งสมาธิที่%s แล้วลมปราณปั่นป่วน (เครียด +20)[/color]" % [d.disciple_name, l.name])

static func meditate_finish(sect: SectData, d: DiscipleData) -> String:
	var l = stele_at(sect, d.mission_target)
	var gauge = float(d.needs.get("meditate", 0.0))
	d.needs.erase("meditate")
	if l.is_empty(): return ""
	if randf() < clampf(gauge, 0.05, 0.9):
		d.carried_skills.append(l.skill)
		if d.learned_skills.size() < d.get_max_skills() and MasterySys.can_learn(d, l.skill): d.learned_skills.append(l.skill)
		d.add_memory(sect.current_day, "ตรัสรู้วิชาที่" + l.name)
		return "[color=gold]%s ตรัสรู้วิชา %s จาก%s! (จะนำคัมภีร์กลับสำนัก)[/color]" % [d.disciple_name, l.skill, l.name]
	return "%s นั่งสมาธิที่%sครบแล้ว แต่ยังไม่อาจตรัสรู้ (ความเข้าใจ %d%%)" % [d.disciple_name, l.name, int(gauge * 100)]

# ══════════════════════════════════════════
# 4. แลกวิชากับสำนักที่สนิท
# ══════════════════════════════════════════

static func trade_key(sect: SectData, fid: String) -> String:
	return "trade:%s:%d" % [fid, int(sect.current_day / float(TRADE_PERIOD))]

## วิชาที่สำนัก fid ยอมแลกรอบนี้ (สายของเขา ขั้นตามความสัมพันธ์)
static func trade_offer(sect: SectData, fid: String) -> String:
	var info = FactionDB.FACTIONS[fid]
	var rel: int = sect.factions[fid].relation
	var tier = 3 if rel >= 80 else 2
	seed(hash([sect.world_seed, fid, int(sect.current_day / float(TRADE_PERIOD))]))
	var s = SkillDB.get_random_skill_by_tier_and_type(tier, info.style)
	randomize()
	return s

static func trade(sect: SectData, fid: String, give: String) -> String:
	if sect.factions[fid].relation < TRADE_REL: return "ยังไม่สนิทพอจะแลกวิชา (ต้อง %d+)" % TRADE_REL
	if sect.completed_world_tasks.has(trade_key(sect, fid)): return "รอบนี้แลกวิชากับสำนักนี้ไปแล้ว"
	var got = trade_offer(sect, fid)
	if sect.library_skills.has(got): return "เรามีวิชา %s อยู่แล้ว" % got
	sect.completed_world_tasks.append(trade_key(sect, fid))
	sect.add_library_skill(got)
	var tier = int(SkillDB.get_skill(give).get("tier", 1))
	var f = sect.factions[fid]
	f.power = int(f.power * (1.0 + 0.02 * tier))
	f.relation = mini(100, f.relation + 5)
	var text = "แลกวิชากับ%s: มอบ %s ได้ %s (สำนักนั้นแข็งขึ้น %d%%)" % [FactionDB.FACTIONS[fid].name, give, got, 2 * tier]
	sect.log_event(sect.current_day, "[color=cyan]%s[/color]" % text)
	return text

# ══════════════════════════════════════════
# 5. ฝากศิษย์ไปเรียนสำนักอื่น
# ══════════════════════════════════════════

static func apprentice_day(sect: SectData, d: DiscipleData) -> void:
	var fid: String = WorldDB.NODES.get(d.mission_target, {}).get("faction", "")
	if fid == "": return
	var style: String = FactionDB.FACTIONS[fid].style
	for t in MASTERY_TO_SKILL:
		if MASTERY_TO_SKILL[t] == style:
			MasterySys.gain(d, t, 4)
			break
	d.gain_experience(15, sect.current_day)

static func apprentice_finish(sect: SectData, d: DiscipleData) -> String:
	var fid: String = WorldDB.NODES.get(d.mission_target, {}).get("faction", "")
	if fid == "": return ""
	var rel: int = sect.factions[fid].relation
	var tier = 3 if rel >= 70 else 2
	var s = SkillDB.get_random_skill_by_tier_and_type(tier, FactionDB.FACTIONS[fid].style)
	d.carried_skills.append(s)
	if d.learned_skills.size() < d.get_max_skills() and MasterySys.can_learn(d, s): d.learned_skills.append(s)
	sect.factions[fid].relation = mini(100, rel + 3)
	return "[color=cyan]%s ฝากตัวเรียนที่%sครบกำหนด ได้วิชา %s กลับมา[/color]" % [d.disciple_name, FactionDB.FACTIONS[fid].name, s]

# ══════════════════════════════════════════
# 6. เหตุการณ์สุ่มแบบนิยายกำลังภายใน
# ══════════════════════════════════════════

static func daily(sect: SectData, mgr: SectManager) -> void:
	# ศิษย์ระหว่างเดินทาง: พลัดตกหน้าผาเจอคัมภีร์ในถ้ำลับ (บาดเจ็บแต่ได้วิชา)
	for d in sect.disciples:
		if d.status != DiscipleData.DiscipleStatus.MISSION or d.mission_phase not in ["going", "returning"]: continue
		if randf() < 0.006:
			var s = SkillDB.get_random_skill_by_tier(2 if randf() < 0.7 else 3)
			d.carried_skills.append(s)
			d.injury_days = maxi(d.injury_days, 3)
			mgr.log_event("[color=gold]%s พลัดตกหน้าผาระหว่างเดินทาง รอดตายมาได้ในถ้ำลับ และพบคัมภีร์ %s สลักอยู่บนผนังถ้ำ![/color]" % [d.disciple_name, s], [d])
	# พ่อค้าเร่ขายคัมภีร์ (อาจเป็นของปลอม)
	if sect.pending_event.is_empty() and randf() < 0.025:
		var tier = 1 if randf() < 0.6 else 2
		var s = SkillDB.get_random_skill_by_tier(tier)
		if not sect.library_skills.has(s):
			sect.pending_event = { "type": "peddler", "skill": s, "price": [0, 220, 600][tier] + randi_range(-40, 80), "fake": randf() < 0.35, "deadline": sect.total_ticks + 120 }
			mgr.log_event("[color=#e0c080]พ่อค้าเร่แปลกหน้ามาเสนอขายคัมภีร์ที่ประตูสำนัก[/color]")

static func buy_peddler(sect: SectData, mgr: SectManager) -> String:
	var ev = sect.pending_event
	sect.pending_event = {}
	if sect.money < int(ev.price): return "เงินไม่พอ พ่อค้าเร่ส่ายหน้าแล้วจากไป"
	sect.money -= int(ev.price)
	if ev.fake:
		var text = "[color=red]เปิดคัมภีร์ดูแล้ว... เป็นของปลอม! เสียเงิน %d ไปฟรีๆ[/color]" % ev.price
		mgr.log_event(text)
		return text
	sect.add_library_skill(ev.skill)
	var t2 = "[color=cyan]ซื้อคัมภีร์ %s จากพ่อค้าเร่ (ของจริง!) เข้าหอตำราแล้ว[/color]" % ev.skill
	mgr.log_event(t2)
	return t2

# ══════════════════════════════════════════
# 7. ร้านหนังสือในเมือง
# ══════════════════════════════════════════

## สินค้ารอบนี้: วิชาขั้นมนุษย์ 4 เล่ม (คงที่ต่อเมืองต่อรอบ)
static func bookstore_offers(sect: SectData, city_id: String, period: int) -> Array:
	var rng = RandomNumberGenerator.new()
	rng.seed = hash([city_id, period, "books"])
	var pool = SkillDB.SKILLS.keys().filter(func(s): return SkillDB.SKILLS[s].tier == 1)
	pool.sort()
	var out: Array = []
	for i in 4:
		if pool.is_empty(): break
		var s = pool[rng.randi() % pool.size()]
		pool.erase(s)
		out.append({ "skill": s, "price": 180 + SkillDB.SKILLS[s].power * 8 + rng.randi_range(0, 60) })
	return out
