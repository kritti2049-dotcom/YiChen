extends RefCounted
class_name SimWindows

## หน้าต่าง UI ของระบบจำลองสำนัก (สร้างเนื้อหาลงใน VBoxContainer ของ UIKit.open_window)
## มอบหมายศิษย์เข้าตึก / ผู้สมัคร / เจตจำนงสวรรค์ / นักโทษ / กองคาราวาน
## refresh = Callable ที่สร้างหน้าต่างใหม่หลังข้อมูลเปลี่ยน

## ตัวกรองรายชื่อศิษย์ในหน้ามอบหมาย: 0 ทั้งหมด · 1 ยังว่าง · 2 เครียดจัด (จำค่าไว้ตอนเปิดซ้ำ)
static var _board_filter := 0

# ══════════════════════════════════════════
# มอบหมายศิษย์เข้าตึก (Facility Assignment) — ต่อตึกแต่ละหลัง
# ══════════════════════════════════════════

## ความเข้ากันของศิษย์กับตึก (ใช้แสดงผล): ลานฝึก = สายที่กำลังฝึก, ที่อื่น = ไม่คิด
static func post_fit(d: DiscipleData, type: String) -> float:
	if type == "training_ground": return MasterySys.fit(d, MasterySys.train_type(d))
	return 1.0

## ลิสต์ตึกที่ประจำการได้และสร้างเสร็จแล้ว เรียงตามชนิด
static func _postable(sect: SectData) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for type in BuildingDB.POSTS:
		for inst in sect.instances(type):
			if int(inst.level) > 0: out.append(inst)
	return out

static func assign_board(c: VBoxContainer, sect: SectData, refresh: Callable) -> void:
	c.add_child(UIKit.label("เลือกตึกให้ศิษย์ไปประจำ — ตึกผลิตของ/EXP ให้เองทุกวัน ไม่ต้องเดินหยิบของ · หากศิษย์เครียดหรืออ่อนล้า สามารถกดสั่งนอนพักฟื้นที่เรือนนอนได้ทันที · ศิษย์ว่างช่วยก่อสร้างช้าๆ และหาของป่าเมื่อเสบียงขาด", 12, WuxiaTheme.PAPER_DIM))
	var top = HBoxContainer.new()
	top.add_child(UIKit.button("จัดอัตโนมัติ (เติมที่นั่งว่างตามความเหมาะสม)", func():
		var n = BuildingDB.auto_assign(sect)
		UIKit.toast(c, "จัดศิษย์เข้าประจำเพิ่ม %d คน" % n)
		refresh.call()))
	top.add_child(UIKit.button("ปลดทุกคน", func():
		for d in sect.get_active_disciples(): d.post = ""
		refresh.call()))
	var filter = OptionButton.new()
	for t in ["แสดง: ทั้งหมด", "แสดง: ยังว่าง", "แสดง: เครียดจัด"]: filter.add_item(t)
	filter.select(_board_filter)
	filter.item_selected.connect(func(i):
		_board_filter = i
		refresh.call())
	top.add_child(filter)
	c.add_child(top)
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 400)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.add_child(scroll)
	var box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	var pawns = PawnSys.present(sect).filter(func(d): return not d.is_child)
	# ── การ์ดตึกแต่ละหลัง ──
	var insts = _postable(sect)
	if insts.is_empty():
		box.add_child(UIKit.label("ยังไม่มีตึกที่ประจำการได้ — เปิดเมนู 'สร้างตึก' เพื่อวางตึกบนพื้นที่โล่ง", 14, WuxiaTheme.PAPER_DIM))
	for inst in insts:
		var info = BuildingDB.POSTS[inst.type]
		var slots = BuildingDB.post_slots(sect, inst.uid)
		var members = BuildingDB.post_members(sect, inst.uid)
		box.add_child(UIKit.section("%s Lv.%d  (%d/%d)" % [BuildingDB.inst_name(inst), inst.level, members.size(), slots]))
		box.add_child(UIKit.label(info.out, 12, WuxiaTheme.PAPER_DIM))
		for d in members:
			var f = post_fit(d, inst.type)
			var line = "%s · เครียด %d%%" % [d.disciple_name, int(d.stress)]
			if inst.type == "training_ground": line += " · ฝึก%s [%s]" % [MasterySys.type_name(MasterySys.train_type(d)), MasterySys.fit_label(f)]
			var btns: Array = []
			if inst.type == "training_ground":
				btns.append(_focus_picker(d, refresh))
			btns.append(UIKit.button("ถอดถอน", func():
				BuildingDB.assign_post(sect, d, "")
				refresh.call()))
			box.add_child(UIKit.row(line, btns, MasterySys.fit_color(f) if inst.type == "training_ground" else (Color(1, 0.55, 0.45) if d.stress >= 70 else null)))
	# ── ศิษย์ทั้งหมด ──
	var shown = pawns.filter(func(d): return _board_filter == 0 or (_board_filter == 1 and d.post == "") or (_board_filter == 2 and d.stress >= 70))
	box.add_child(UIKit.section("ศิษย์ (%d / %d)" % [shown.size(), pawns.size()]))
	for d in shown:
		box.add_child(_pawn_row(sect, d, insts, refresh))

static func applicants(c: VBoxContainer, sect: SectData, mgr: SectManager, refresh: Callable) -> void:
	var tier_name = ReputationSys.tier_name(sect)
	var nxt = ReputationSys.next_threshold(sect)
	c.add_child(UIKit.label("ชื่อเสียงสำนัก: %s (คะแนน %d%s) · แนวทาง: %s (%d)" % [tier_name, ReputationSys.score(sect), (" / ขั้นต่อไป %d" % nxt) if nxt > 0 else "", ReputationSys.alignment_name(sect), sect.alignment], 15, Color(1, 0.85, 0.4)))
	c.add_child(UIKit.label("ชื่อเสียงสูง = ผู้สมัครมาบ่อย/มาก/เก่งขึ้น (รอได้สูงสุด %d คน · อยู่ %d วัน) · ศิษย์ %d/%d" % [ApplicantSys.capacity(sect), ApplicantSys.EXPIRE_DAYS, sect.get_active_disciples().size(), sect.get_max_disciples()], 12, WuxiaTheme.PAPER_DIM))
	for b in ReputationSys.breakdown(sect):
		c.add_child(UIKit.label("  %s: %+d" % [b.name, b.value], 12, WuxiaTheme.PAPER_DIM))
	c.add_child(UIKit.section("ผู้สมัครที่รอที่ประตู (%d)" % sect.applicants.size()))
	if sect.applicants.is_empty():
		c.add_child(UIKit.label("ยังไม่มีผู้สมัคร — สร้างชื่อเสียงด้วยการชนะศึก ยึดถิ่น ส่งศิษย์ออกประลอง", 14, WuxiaTheme.PAPER_DIM))
	var full = sect.get_active_disciples().size() >= sect.get_max_disciples()
	for i in sect.applicants.size():
		var a = sect.applicants[i]
		var npc: DiscipleData = a.npc
		var line = "%s · %s · พรสวรรค์%s · สาย%s ธาตุ%s · พลังรบ %d · รออีก %d วัน\n   เหตุผล: %s" % [npc.disciple_name, npc.realm_name, NPCGenerator.TIER_NAMES[a.talent], npc.affinity_style_name(), npc.element, npc.get_power_rating(), maxi(0, a.expire - sect.current_day), a.reason]
		c.add_child(UIKit.row(line, [
			UIKit.button("รับเข้าสำนัก", func():
				var text = ApplicantSys.accept(sect, i, mgr)
				UIKit.toast(c, text)
				refresh.call(), full),
			UIKit.button("ปฏิเสธ", func():
				ApplicantSys.reject(sect, i)
				refresh.call())
		], [Color(0.85, 0.85, 0.85), Color(0.5, 0.8, 1), Color(0.95, 0.65, 1)][a.talent]))

static func _focus_picker(d: DiscipleData, refresh: Callable) -> OptionButton:
	var opt = OptionButton.new()
	opt.add_theme_font_size_override("font_size", 11)
	var keys: Array = [""] + MasterySys.TYPES.keys()
	opt.add_item("ฝึก: อัตโนมัติ")
	for k in MasterySys.TYPES.keys():
		opt.add_item("ฝึก%s (%s)" % [MasterySys.type_name(k), MasterySys.fit_label(MasterySys.fit(d, k))])
	opt.select(keys.find(d.train_focus))
	opt.item_selected.connect(func(i):
		d.train_focus = keys[i]
		refresh.call())
	return opt

static func _pawn_row(sect: SectData, d: DiscipleData, insts: Array[Dictionary], refresh: Callable) -> HBoxContainer:
	var row = HBoxContainer.new()
	var name_l = UIKit.label("%s  [%s]" % [d.disciple_name, d.affinity_style_name()], 13, Color(1, 0.6, 0.5) if d.stress >= 70 else WuxiaTheme.PAPER)
	name_l.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_l.custom_minimum_size = Vector2(190, 0)
	name_l.tooltip_text = "พรสวรรค์: %s · ธาตุ %s · พลังรบ %d\nอารมณ์ %d · ความเครียด %d" % [d.affinity_style_name(), d.element, d.get_power_rating(), d.mood, int(d.stress)]
	name_l.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(name_l)
	var stress_bar = ProgressBar.new()
	stress_bar.max_value = 100
	stress_bar.value = d.stress
	stress_bar.show_percentage = false
	stress_bar.custom_minimum_size = Vector2(80, 14)
	stress_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stress_bar.tooltip_text = "ความเครียด %d/100 (ถึง 100 = ธาตุไฟแตกซ่าน)" % int(d.stress)
	row.add_child(stress_bar)
	var act = UIKit.label(SectView.activity_text(d), 11, WuxiaTheme.PAPER_DIM)
	act.autowrap_mode = TextServer.AUTOWRAP_OFF
	act.clip_text = true
	act.custom_minimum_size = Vector2(110, 0)
	row.add_child(act)
	var opt = OptionButton.new()
	opt.add_theme_font_size_override("font_size", 12)
	opt.add_item("ว่าง (ไม่ประจำ)")
	var uids: Array = [""]
	for inst in insts:
		var slots = BuildingDB.post_slots(sect, inst.uid)
		var used = BuildingDB.post_members(sect, inst.uid).size()
		opt.add_item("%s (%d/%d)%s" % [BuildingDB.inst_name(inst), used, slots, "" if inst.type != "training_ground" else " · " + MasterySys.fit_label(MasterySys.fit(d, MasterySys.train_type(d)))])
		uids.append(inst.uid)
		opt.set_item_disabled(uids.size() - 1, used >= slots and d.post != inst.uid)
	opt.select(maxi(0, uids.find(d.post)))
	opt.item_selected.connect(func(i):
		var err = BuildingDB.assign_post(sect, d, uids[i])
		if err != "": push_warning(err)
		refresh.call())
	row.add_child(opt)
	return row

# ══════════════════════════════════════════
# เจตจำนงสวรรค์
# ══════════════════════════════════════════

static func storyteller(c: VBoxContainer, sect: SectData, refresh: Callable) -> void:
	var t = StorytellerDB.get_teller(sect.storyteller)
	c.add_child(UIKit.label("ผู้กำกับ: %s (%s) — %s" % [t.name, t.style, t.desc], 16, Color(1, 0.85, 0.5)))
	var w = StorytellerSystem.wealth_breakdown(sect)
	var tp = StorytellerSystem.threat_points(sect)
	c.add_child(UIKit.section("ความมั่งคั่งของสำนัก"))
	c.add_child(UIKit.label("รวม %d = ของในคลัง %d (นับเต็ม) + อาคาร/อุปกรณ์ที่ติดตั้ง %d (นับครึ่งเดียว) + ศิษย์ %d (%d คน x %d)" % [w.total, w.items, w.installed, w.pawns, PawnSys.present(sect).size(), StorytellerDB.PAWN_VALUE], 15))
	c.add_child(UIKit.label("ของที่กองในคลังนับเต็มมูลค่า: กักตุนมาก = ภัยแรงขึ้น (ใช้ลงทุนสร้างอาคารดีกว่า)", 13, WuxiaTheme.PAPER_DIM))
	c.add_child(UIKit.section("คะแนนภัยคุกคาม"))
	c.add_child(UIKit.label("คะแนนภัย %d / เพดาน %d · ตัวคูณปรับตัว x%.2f (ไม่สูญเสียนาน = สูงขึ้น, เพิ่งสูญเสีย = ลดลง)" % [tp, StorytellerDB.HARD_CAP, sect.adaptation], 15))
	var ramp = StorytellerSystem.early_ramp(sect)
	if ramp < 1.0: c.add_child(UIKit.label("ช่วงตั้งตัว: ภัยเหลือ %d%% ของปกติ (เต็มที่วันที่ 50)" % roundi(ramp * 100), 14, Color(0.6, 1, 0.6)))
	var sample = StorytellerSystem.buy_enemies(tp, StorytellerDB.RAID_POOL)
	c.add_child(UIKit.label("ถ้าถูกบุกวันนี้ จะมาประมาณ: %s" % ", ".join(sample.map(func(e): return EnemyDB.ENEMIES[e].name)), 14, Color(1, 0.6, 0.5)))
	var nt = StorytellerSystem.notoriety(sect)
	c.add_child(UIKit.label("ขั้นชื่อเสียง: %s · แนวทาง: %s" % [nt.tier, ReputationSys.alignment_name(sect)], 14, Color(1, 0.85, 0.4)))
	c.add_child(UIKit.section("ชื่อเสียงขจรขจาย (ยุทธภพหมายตา)"))
	c.add_child(UIKit.label("คะแนนชื่อเสียง %d = ชื่อเสียงศิษย์รวม %d + บารมีสำนัก %d + เงิน %d%s" % [nt.score, nt.fame, nt.prestige, nt.wealth, " + %s" % EquipmentDB.CURSED_SWORD if nt.sword else ""], 14))
	var lure = StorytellerSystem.lure_reason(sect)
	if lure != "":
		var cd = maxi(0, StorytellerSystem.TARGETED_COOLDOWN - (sect.current_day - sect.last_targeted_day))
		c.add_child(UIKit.label("ถูกหมายตา: %s · ทัพที่หมายตาจะมาภายใน %d วัน (ตั้งค่ายกล + ให้ศิษย์ประจำค่ายกลเพื่อรับมือ)" % [StorytellerSystem.LURE_TEXT[lure], cd], 14, Color(1, 0.5, 0.4)))
	else:
		c.add_child(UIKit.label("ยังไม่ถูกหมายตา — จะถูกบุกเป็นพิเศษเมื่อ: ครอบครองกระบี่มหาโชคมาร · เงินถึง %d · ชื่อเสียงศิษย์รวมถึง %d หรือบารมีสำนักถึง %d" % [StorytellerSystem.WEALTH_LURE, StorytellerSystem.FAME_LURE, StorytellerSystem.PRESTIGE_LURE], 13, WuxiaTheme.PAPER_DIM))
	c.add_child(UIKit.label("เหตุการณ์ถัดไปราววันที่ %d · ความสั่นสะเทือนจากเหมืองลึก %.2f (สูง = สัตว์อสูรใต้ดิน)" % [sect.next_event_day, sect.tremor], 14))
	var st = sect.sim_stats
	c.add_child(UIKit.label("สถิติ: ถูกบุก %d ครั้ง · ธาตุไฟแตกซ่าน %d ครั้ง · วิวาท %d ครั้ง · เสียชีวิต %d คน · เหตุการณ์ทั้งหมด %d" % [st.get("raids", 0), st.get("breaks", 0), st.get("fights", 0), st.get("deaths", 0), st.get("events", 0)], 14, WuxiaTheme.PAPER_DIM))
	c.add_child(UIKit.section("เปลี่ยนผู้กำกับ"))
	var row = HFlowContainer.new()
	for id in StorytellerDB.STORYTELLERS:
		var s = StorytellerDB.STORYTELLERS[id]
		row.add_child(UIKit.button(s.name + (" ✓" if id == sect.storyteller else ""), func():
			sect.storyteller = id
			refresh.call(), id == sect.storyteller))
	c.add_child(row)

# ══════════════════════════════════════════
# นักโทษ
# ══════════════════════════════════════════

static func prisoners(c: VBoxContainer, sect: SectData, mgr: SectManager, refresh: Callable) -> void:
	c.add_child(UIKit.label("นักโทษได้มาจากการขับไล่ผู้บุกรุก · เปิดงาน [คุมขัง] ให้ศิษย์ที่เจรจาเก่งชักชวนเข้าสำนัก", 13, WuxiaTheme.PAPER_DIM))
	if sect.prisoners.is_empty():
		c.add_child(UIKit.label("ห้องขังว่างเปล่า", 15, WuxiaTheme.PAPER_DIM))
	for i in sect.prisoners.size():
		var p = sect.prisoners[i]
		c.add_child(UIKit.section("%s (%s)" % [p.name, p.title]))
		c.add_child(UIKit.label("ความคืบหน้าการชักชวน %d%%" % p.recruit, 14))
		var row = HFlowContainer.new()
		row.add_child(UIKit.button("ปล่อยตัว", func():
			PrisonerSys.release(sect, i, mgr)
			refresh.call()))
		row.add_child(UIKit.button("ประหาร", func():
			PrisonerSys.execute(sect, i, mgr)
			refresh.call()))
		c.add_child(row)

# ══════════════════════════════════════════
# กองคาราวาน
# ══════════════════════════════════════════

static func caravan(c: VBoxContainer, sect: SectData, refresh: Callable) -> void:
	if sect.caravan.is_empty():
		c.add_child(UIKit.label("ยังไม่มีกองคาราวานมาเยือน (เจตจำนงสวรรค์จะส่งมาเป็นครั้งคราว)", 15, WuxiaTheme.PAPER_DIM))
		return
	c.add_child(UIKit.label("กองคาราวานอยู่ถึงวันที่ %d · ราคาซื้อรวมค่าธรรมเนียม 20%% · รับซื้อ 60%% · เงินสำนัก %d" % [sect.caravan.until, sect.money], 14, Color(1, 0.85, 0.5)))
	c.add_child(UIKit.section("ซื้อ"))
	for item in sect.caravan.stock:
		var price = int(MaterialDB.get_price(item.mat) * 1.2) + 1
		c.add_child(UIKit.row("%s (เหลือ %d) - %d/ชิ้น" % [MaterialDB.get_material_name(item.mat), item.amount, price], [UIKit.button("ซื้อ 1", func():
			sect.money -= price
			sect.add_material(item.mat, 1)
			item.amount -= 1
			refresh.call(), item.amount <= 0 or sect.money < price)]))
	c.add_child(UIKit.section("ขาย"))
	for m in sect.materials.keys():
		var price = max(1, int(MaterialDB.get_price(m) * 0.6))
		c.add_child(UIKit.row("%s x%d - %d/ชิ้น" % [MaterialDB.get_material_name(m), sect.get_material_count(m), price], [UIKit.button("ขาย 5", func():
			var n = min(5, sect.get_material_count(m))
			sect.add_material(m, -n)
			sect.money += n * price
			refresh.call())]))
