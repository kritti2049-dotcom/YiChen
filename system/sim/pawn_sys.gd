extends RefCounted
class_name PawnSys

## ตัวช่วยอ่าน/เขียน Component ของศิษย์ (DiscipleData เป็นแค่ที่เก็บข้อมูล ตรรกะอยู่ใน *System)
## - ensure(): ตั้งค่า component ที่ยังไม่มี (ศิษย์ใหม่ / เซฟเก่า)
## - ความคิด, ความสัมพันธ์, ทักษะงาน, ประสิทธิภาพร่างกาย, อัตราบริโภค

const TICKS_PER_DAY = 360

static func ensure(d: DiscipleData, sect: SectData) -> void:
	if d.needs.is_empty():
		d.needs = { "food": 0.8, "rest": 0.9, "qi": 0.7, "joy": 0.6 }
		d.mood_target = d.mood
	if d.skills.is_empty(): _init_skills(d)
	if d.btraits.is_empty(): d.btraits = BehaviorTraitDB.roll()
	d.comp_version = 1

static func _init_skills(d: DiscipleData) -> void:
	for s in WorkDB.SKILLS:
		var pot = d.get_stat(WorkDB.SKILLS[s].stat)
		d.skills[s] = { "lv": clampf(pot * 1.6 + randf_range(-1.5, 2.0), 0.0, WorkDB.MAX_SKILL), "xp": 0.0, "passion": 0 }
	# ความหลงใหล: ทักษะที่รากฐานดีมีโอกาสถูกเลือกมากกว่า
	var score = {}
	for s in WorkDB.SKILLS: score[s] = d.skills[s].lv + randf() * 6
	var ranked = WorkDB.SKILLS.keys()
	ranked.sort_custom(func(a, b): return score[a] > score[b])
	d.skills[ranked[0]].passion = 2
	for s in ranked.slice(1, randi_range(2, 4)): d.skills[s].passion = 1

## อัตราบริโภคอาหาร (เด็กกินครึ่งเดียว)
static func consumption(d: DiscipleData) -> float:
	return 0.5 if d.is_child else 1.0

# ── ศิษย์ในสำนัก ──

## ศิษย์ที่อยู่ในลานสำนัก (ไม่ได้ออกเดินทาง ไม่ได้จากไป)
static func present(sect: SectData) -> Array[DiscipleData]:
	var result: Array[DiscipleData] = []
	for d in sect.disciples:
		if d.status in [DiscipleData.DiscipleStatus.IDLE, DiscipleData.DiscipleStatus.TRAINING, DiscipleData.DiscipleStatus.INJURED]:
			result.append(d)
	return result

static func find(sect: SectData, pawn_name: String) -> DiscipleData:
	for d in sect.disciples:
		if d.disciple_name == pawn_name and d.status != DiscipleData.DiscipleStatus.DEPARTED: return d
	return null

# ── ความคิด (Thoughts) ──

## เพิ่มความคิดแบบความทรงจำ value = null ใช้ค่าจาก ThoughtDB
static func add_thought(d: DiscipleData, sect: SectData, id: String, value = null, src := "") -> void:
	var def = ThoughtDB.get_def(id)
	var v = def.value if value == null else value
	if v == 0: return
	var stack: int = def.get("stack", 1)
	var same = d.thoughts.filter(func(t): return t.id == id)
	if same.size() >= stack:
		# รีเฟรชอันที่เก่าที่สุด
		same.sort_custom(func(a, b): return a.until < b.until)
		same[0].until = sect.total_ticks + int(def.days * TICKS_PER_DAY)
		return
	d.thoughts.append({ "id": id, "value": v, "until": sect.total_ticks + int(def.days * TICKS_PER_DAY), "src": src })

static func thoughts_total(d: DiscipleData) -> float:
	var total = 0.0
	var seen = {}
	for t in d.thoughts:
		var n = seen.get(t.id, 0)
		total += t.value * pow(0.5, n)
		seen[t.id] = n + 1
	return total

# ── ความสัมพันธ์ (Opinion -100..100) ──

static func opinion(a: DiscipleData, b: DiscipleData) -> float:
	return a.relationships.get(b.disciple_name, {}).get("affinity", 0.0)

static func change_opinion(a: DiscipleData, b: DiscipleData, delta: float) -> void:
	if not a.relationships.has(b.disciple_name):
		a.relationships[b.disciple_name] = { "affinity": 0.0, "type": "คนรู้จัก" }
	var r = a.relationships[b.disciple_name]
	r.affinity = clampf(r.affinity + delta, -100.0, 100.0)
	if r.type in ["คู่รัก", "คู่ครอง"]: return
	if r.affinity >= 60: r.type = "สหายร่วมเป็นร่วมตาย"
	elif r.affinity >= 20: r.type = "เพื่อน"
	elif r.affinity <= -50: r.type = "ศัตรู"
	elif r.affinity <= -20: r.type = "คู่อริ"
	else: r.type = "คนรู้จัก"

# ── ทักษะงาน ──

static func skill_lv(d: DiscipleData, skill: String) -> float:
	if skill == "": return 5.0
	return d.skills.get(skill, {}).get("lv", 3.0)

## ได้ XP ทักษะ (ความหลงใหล + นิสัยเรียนรู้ไว) คืนค่า true ถ้าเลื่อนระดับ
static func learn(d: DiscipleData, skill: String, xp: float) -> bool:
	if skill == "" or not d.skills.has(skill): return false
	var s = d.skills[skill]
	if s.lv >= WorkDB.MAX_SKILL: return false
	s.xp += xp * WorkDB.PASSION_LEARN[s.passion] * BehaviorTraitDB.mult(d.btraits, "learn") * (1.0 + d.get_stat("comprehension") * 0.03)
	if s.xp >= WorkDB.XP_PER_LEVEL:
		s.xp -= WorkDB.XP_PER_LEVEL
		s.lv = min(WorkDB.MAX_SKILL, floorf(s.lv) + 1.0)
		return true
	return false

## ความเร็วในการทำงาน: ทักษะ x ร่างกาย x นิสัย x อารมณ์
static func work_speed(d: DiscipleData, skill: String) -> float:
	var lv = skill_lv(d, skill)
	var body_mult = 0.7 if d.status == DiscipleData.DiscipleStatus.INJURED else 1.0
	var mood_mult = 0.85 if d.mood < 25 else 1.0
	return max(0.1, (0.6 + lv * 0.06) * body_mult * BehaviorTraitDB.mult(d.btraits, "work_speed") * mood_mult)

# ── การบาดเจ็บ ──

## ทำให้ศิษย์บาดเจ็บ (dmg ยิ่งมากพักฟื้นยิ่งนาน) คืนข้อความสั้นๆ ไว้ใส่ในบันทึก
static func injure(d: DiscipleData, dmg: float, _cause: String, _part := "") -> String:
	var days = clampi(ceili(dmg / 3.0), 1, 12)
	d.injury_days = mini(30, d.injury_days + days)
	if d.status == DiscipleData.DiscipleStatus.IDLE or d.status == DiscipleData.DiscipleStatus.TRAINING:
		d.status = DiscipleData.DiscipleStatus.INJURED
	return "พักฟื้น %d วัน" % days
