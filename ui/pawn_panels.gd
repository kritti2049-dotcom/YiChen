extends RefCounted
class_name PawnPanels

## แท็บข้อมูลศิษย์ของระบบจำลอง (ใช้ในหน้าประวัติศิษย์)
## จิตใจ: ความต้องการ ความเครียด อารมณ์ ความคิดทั้งหมด นิสัย ความสัมพันธ์
## สถานะ: อาการบาดเจ็บ/ป่วย ธาตุไฟแตกซ่าน พรสวรรค์
## ทักษะงาน: ระดับ ความหลงใหล ความเร็วทำงาน + ความเข้ากันของพรสวรรค์กับสายวิชา

static func _bar(value: float, max_value: float, color: Color, width := 140.0) -> ProgressBar:
	var bar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(width, 12)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.show_percentage = false
	bar.max_value = max_value
	bar.value = value
	var fill = StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("fill", fill)
	return bar

static func _row(label: String, ctrl: Control, extra := "") -> HBoxContainer:
	var h = HBoxContainer.new()
	var l = UIKit.label(label, 14)
	l.custom_minimum_size = Vector2(170, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	h.add_child(l)
	if ctrl is Label:
		ctrl.autowrap_mode = TextServer.AUTOWRAP_OFF
		ctrl.custom_minimum_size = Vector2(140, 0)
	h.add_child(ctrl)
	if extra != "":
		# ป้ายตัดคำใน HBox ต้องขยายเต็มที่ว่าง ไม่งั้นถูกบีบเหลือกว้าง 1 ตัวอักษร
		var e = UIKit.label(extra, 13, WuxiaTheme.PAPER_DIM)
		e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(e)
	return h

static func mind(c: VBoxContainer, d: DiscipleData, sect: SectData, mgr: SectManager, refresh: Callable) -> void:
	UIKit.clear(c)
	c.add_child(UIKit.section("ความเครียด (ถึง 100 = ธาตุไฟแตกซ่าน)"))
	var stress_col = Color(0.55, 0.85, 0.6) if d.stress < 50 else (Color(1, 0.75, 0.35) if d.stress < StressSystem.WARN_AT else Color(1, 0.4, 0.35))
	c.add_child(_row("ความเครียด", _bar(d.stress, 100, stress_col), "%d%% · %s" % [int(d.stress), StressSystem.status_text(d)]))
	c.add_child(UIKit.label("เพิ่มจากงานหนัก/อดนอน/แพ้ศึก · ลดเมื่อนอนหลับ พักผ่อน หรือสั่งนอนที่เรือนนอน · ธาตุไฟแตกซ่านทำให้บาดเจ็บ พลังลด 25% หรือสลบ 3 วัน", 13, WuxiaTheme.PAPER_DIM))
	var row = HFlowContainer.new()
	var has_dorm = BuildingDB.get_beds(sect) > 0 or sect.get_building_level("dormitory") > 0
	row.add_child(UIKit.button("สั่งนอนพักฟื้น (เรือนนอน)", func():
		var msg = BuildingDB.sleep_disciple(sect, d)
		mgr.log_event(msg)
		UIKit.toast(c, msg, Color(0.6, 1.0, 0.6))
		refresh.call(), not has_dorm))
	row.add_child(UIKit.button("ให้ชาสงบจิต (มี %d · ติดชาแล้ว %d%%)" % [sect.count_pills("calm_tea"), int(d.tea_addiction * 100)], func():
		UIKit.toast(c, MoodSystem.give_tea(sect, d, mgr))
		refresh.call(), sect.count_pills("calm_tea") == 0))
	c.add_child(row)
	c.add_child(UIKit.section("ความต้องการ"))
	var names = { "food": "อิ่มท้อง", "rest": "พักผ่อน", "qi": "ปราณ (ฝึกตน)", "joy": "ความบันเทิง" }
	for k in names:
		c.add_child(_row(names[k], _bar(d.needs.get(k, 0.0), 1.0, Color(0.5, 0.8, 0.5) if d.needs.get(k, 0.0) > 0.3 else Color(0.9, 0.4, 0.3)), "%d%%" % int(d.needs.get(k, 0.0) * 100)))
	c.add_child(UIKit.section("อารมณ์ (ต่ำนาน + ภักดีต่ำ = ทิ้งสำนัก)"))
	c.add_child(_row("อารมณ์ปัจจุบัน", _bar(d.mood, 100, Color(0.5, 0.8, 1) if d.mood >= 35 else Color(1, 0.45, 0.35)), "%d → เป้าหมาย %d (ขยับช้าๆ)" % [d.mood, d.mood_target]))
	c.add_child(UIKit.label("ค่าฐาน %+d" % MoodSystem.base_mood(d), 14, WuxiaTheme.PAPER_DIM))
	var all: Array = MoodSystem.situational(sect, d)
	for t in d.thoughts: all.append(t)
	all.sort_custom(func(a, b): return abs(a.value) > abs(b.value))
	for t in all:
		var left = "" if not t.has("until") else " (อีก %.1f วัน)" % max(0.0, (t.until - sect.total_ticks) / float(PawnSys.TICKS_PER_DAY))
		c.add_child(UIKit.label("%s %+d%s%s" % [ThoughtDB.get_def(t.id).name, t.value, left, (" — " + t.src) if t.get("src", "") != "" else ""], 14, Color(0.6, 1, 0.6) if t.value > 0 else Color(1, 0.6, 0.55)))
	c.add_child(UIKit.section("นิสัยด้านพฤติกรรม"))
	for tr in d.btraits:
		var info = BehaviorTraitDB.get_trait(tr)
		if info.is_empty(): continue
		c.add_child(UIKit.label("%s [%s] — %s" % [info.name, { "great": "ดีมาก", "context": "เชิงบริบท", "risky": "เสี่ยง", "social": "สังคม", "bad": "ข้อเสีย" }[info.kind], info.desc], 14, Color(1, 0.55, 0.5) if info.kind in ["risky", "bad"] else WuxiaTheme.PAPER))
	c.add_child(UIKit.section("ความสัมพันธ์"))
	if d.spouse != "" or d.lover != "":
		c.add_child(UIKit.label("คู่ครอง: %s" % d.spouse if d.spouse != "" else "คนรัก: %s" % d.lover, 14))
	var rels = d.relationships.keys()
	rels.sort_custom(func(a, b): return abs(d.relationships[a].affinity) > abs(d.relationships[b].affinity))
	for r in rels.slice(0, 8):
		var rel = d.relationships[r]
		c.add_child(UIKit.label("%s — %s (ความเห็น %+d)" % [r, rel.type, rel.affinity], 13, Color(0.6, 1, 0.6) if rel.affinity > 20 else (Color(1, 0.6, 0.55) if rel.affinity < -20 else WuxiaTheme.PAPER_DIM)))

## สถานะ: อาการบาดเจ็บ/ป่วย ธาตุไฟแตกซ่าน พรสวรรค์
static func body(c: VBoxContainer, d: DiscipleData, _sect: SectData, _mgr: SectManager, _refresh: Callable) -> void:
	UIKit.clear(c)
	c.add_child(UIKit.section("พรสวรรค์"))
	c.add_child(UIKit.label("สายพรสวรรค์: %s · ธาตุ %s · พลังรบ %d" % [d.affinity_style_name(), d.element, d.get_power_rating()], 15))
	c.add_child(UIKit.section("สถานะร่างกาย"))
	c.add_child(UIKit.label(d.get_status_text() + ((" (พักฟื้นอีก %d วัน)" % d.injury_days) if d.injury_days > 0 else ""), 14, Color(1, 0.6, 0.55) if d.injury_days > 0 else WuxiaTheme.PAPER))
	if StressSystem.is_deranged(d):
		c.add_child(UIKit.label("ธาตุไฟแตกซ่าน: พลังลด 25%% จนถึงวันที่ %d" % d.debuff_until, 14, Color(1, 0.7, 0.35)))
	if d.disabled: c.add_child(UIKit.label("พิการถาวร: พลังรบลดครึ่งหนึ่ง", 14, Color(1, 0.5, 0.45)))
	for a in d.ailments:
		var info = AilmentDB.get_ailment(a.id)
		c.add_child(UIKit.label("%s (ผ่านมา %d วัน)" % [info.name, a.days], 14, Color(1, 0.6, 0.55)))
	if d.ailments.is_empty() and d.injury_days <= 0 and not d.disabled:
		c.add_child(UIKit.label("แข็งแรงดี", 14, Color(0.6, 1, 0.6)))

static func skills(c: VBoxContainer, d: DiscipleData) -> void:
	UIKit.clear(c)
	c.add_child(UIKit.section("ความเข้ากันของพรสวรรค์ (%s) กับสายวิชา" % d.affinity_style_name()))
	c.add_child(UIKit.label("ฝึกสายที่เข้ากัน EXP ขึ้นเต็มที่ · สายที่ไม่เข้ากันแทบไม่ขึ้น (ตั้งสายที่ฝึกได้ในหน้ามอบหมายศิษย์เข้าตึก)", 13, WuxiaTheme.PAPER_DIM))
	for t in MasterySys.TYPES:
		var f = MasterySys.fit(d, t)
		c.add_child(_row("%s (ระดับ %d)" % [MasterySys.type_name(t), MasterySys.get_level(d, t)], _bar(f, 1.7, MasterySys.fit_color(f), 160), "%s x%.2f" % [MasterySys.fit_label(f), f]))
	c.add_child(UIKit.section("ทักษะงาน"))
	c.add_child(UIKit.label("ทักษะงานโตจากการทำงานจริง (ทักษะเกิน 10 ที่ไม่ได้ใช้จะค่อยๆ เสื่อม) · ความหลงใหล: ไม่ชอบ x0.35 / ชอบ x1 / หลงใหล x1.5 และได้อารมณ์ดีเมื่อได้ทำ", 13, WuxiaTheme.PAPER_DIM))
	for s in WorkDB.SKILLS:
		var sk = d.skills.get(s, { "lv": 0, "xp": 0, "passion": 0 })
		var col = [Color(0.6, 0.75, 0.9), Color(1, 0.7, 0.3), Color(1, 0.35, 0.3)][sk.passion]
		c.add_child(_row("%s %s" % [WorkDB.SKILLS[s].name, WorkDB.PASSION_NAMES[sk.passion]], _bar(sk.lv, WorkDB.MAX_SKILL, col, 200), "ระดับ %d (XP %d/%d) · ความเร็วงาน x%.2f" % [sk.lv, sk.xp, WorkDB.XP_PER_LEVEL, PawnSys.work_speed(d, s)]))
