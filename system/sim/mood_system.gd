extends RefCounted
class_name MoodSystem

## MoodSystem (อารมณ์)
## อารมณ์เป้าหมาย = ค่าฐาน (50 + นิสัย) + ความคิดตามสถานการณ์ + ความคิดแบบความทรงจำ
## อารมณ์จริงขยับเข้าหาเป้าหมายช้าๆ (moving average) ผู้เล่นจึงมีเวลาแก้ปัญหา
## อารมณ์ต่ำนาน = ความภักดีลด/ทิ้งสำนัก (ดู SectManager.check_loyalty_and_defection)
## ความเครียดจากงานหนัก/แพ้ศึก และอาการ "ธาตุไฟแตกซ่าน" อยู่ที่ StressSystem

const INTERVAL = 10
const MOOD_FOLLOW = 0.3

static func run(sect: SectData, _mgr: SectManager) -> void:
	var now = sect.total_ticks
	for d in PawnSys.present(sect):
		if d.needs.is_empty(): continue
		d.thoughts = d.thoughts.filter(func(t): return t.until > now)
		d.mood_target = target(sect, d)
		d.mood = clampf(d.mood + (d.mood_target - d.mood) * MOOD_FOLLOW, 0.0, 100.0)
		# การติดชาสงบจิต
		if d.tea_addiction > 0:
			d.tea_addiction = max(0.0, d.tea_addiction - 0.002)
			if d.tea_addiction > 0.4 and not d.thoughts.any(func(t): return t.id == "calm_tea"):
				if not d.thoughts.any(func(t): return t.id == "tea_withdrawal"): PawnSys.add_thought(d, sect, "tea_withdrawal")

static func base_mood(d: DiscipleData) -> float:
	return ThoughtDB.BASE_MOOD + BehaviorTraitDB.sum(d.btraits, "base_mood")

static func target(sect: SectData, d: DiscipleData) -> float:
	var total = base_mood(d) + PawnSys.thoughts_total(d)
	for s in situational(sect, d): total += s.value
	return clampf(total, 0.0, 100.0)

## ความคิดตามสถานการณ์ (คำนวณใหม่ทุกครั้ง ใช้แสดงใน UI ด้วย) [{ id, value }]
static func situational(sect: SectData, d: DiscipleData) -> Array:
	var out: Array = []
	var add = func(id: String, value = null):
		var v = ThoughtDB.get_def(id).value if value == null else value
		if v != 0: out.append({ "id": id, "value": v })
	var n = d.needs
	if not n.is_empty():
		if n.food <= 0.0: add.call("starving")
		elif n.food < 0.12: add.call("ravenous")
		elif n.food < 0.3: add.call("hungry")
		if n.rest < 0.1: add.call("exhausted")
		elif n.rest < 0.28: add.call("tired")
		if n.qi < 0.2: add.call("qi_lacking")
		if n.joy < 0.2: add.call("bored")
		elif n.joy > 0.8: add.call("joyful")
	# ความคาดหวัง: สำนักยิ่งร่ำรวย ศิษย์ยิ่งคาดหวังสูง (ความสุขฟรีหายไป) คำนวณจากความมั่งคั่งที่แคชไว้รายวัน
	var wealth = sect.sim_stats.get("wealth", 0)
	add.call("low_expectations" if wealth < 6000 else ("modest_expectations" if wealth < 20000 else "high_expectations"))
	var ptype = BuildingDB.post_type(sect, d)
	if not sect.fires.is_empty(): add.call("fire_in_sect")
	if d.status == DiscipleData.DiscipleStatus.INJURED: add.call("in_pain")
	if d.disabled: add.call("crippled")
	var wskill: String = BuildingDB.POSTS[ptype].skill if ptype != "" else ""
	if wskill != "" and d.skills.get(wskill, {}).get("passion", 0) > 0: add.call("passion_work", 3 * d.skills[wskill].passion)
	if ptype == "dormitory" and sect.get_building_level("dormitory") >= 3: add.call("beautiful_room")
	var glory = 0
	for inst in sect.structures: glory += int(inst.level)
	if glory >= 15: add.call("sect_glory")
	if d.ailments.any(func(a): return a.id == "fever"): add.call("sick")
	return out

## เหตุผลที่อารมณ์แย่: ความคิดลบที่มีผลมากที่สุด
static func reasons(sect: SectData, d: DiscipleData) -> String:
	var all: Array = situational(sect, d)
	for t in d.thoughts: all.append({ "id": t.id, "value": t.value })
	all.sort_custom(func(a, b): return a.value < b.value)
	var parts: Array[String] = []
	for t in all.slice(0, 4):
		if t.value >= 0: break
		parts.append("%s %d" % [ThoughtDB.get_def(t.id).name, t.value])
	return ", ".join(parts)

# ══════════════════════════════════════════
# การรับมือของผู้เล่น
# ══════════════════════════════════════════

## ให้ชาสงบจิต: อารมณ์ดีขึ้นชั่วคราว + ความเครียดลด 35 (เสี่ยงเสพติด)
static func give_tea(sect: SectData, d: DiscipleData, mgr: SectManager) -> String:
	var q = sect.take_best_pill("calm_tea")
	if q < 0: return "ไม่มีชาสงบจิตในคลัง (ให้ศิษย์ประจำหอหลอมโอสถชงที่หอหลอมโอสถ)"
	PawnSys.add_thought(d, sect, "calm_tea", 12 + q * 4)
	d.thoughts = d.thoughts.filter(func(t): return t.id != "tea_withdrawal")
	d.tea_addiction = min(1.0, d.tea_addiction + 0.2)
	StressSystem.relieve(d, 35.0)
	var text = "%s ดื่มชาสงบจิต จิตใจสงบลง ความเครียดลด" % d.disciple_name
	if d.tea_addiction > 0.6: text += " (เริ่มติดชาสงบจิต!)"
	mgr.log_event(text, [d])
	return text
