extends RefCounted
class_name ProductionSys

## ผลผลิตรายตึก (Macro Production): แทนระบบศิษย์เดินหาของ/ขนของ (JobSystem เดิม)
## ทุกวัน แต่ละตึกที่สร้างเสร็จคำนวณผลผลิตจาก "ศิษย์ที่ประจำ" ทันที: ประสิทธิภาพ = Σ (ความเร็วงานตามทักษะ x ความเหมาะ) แล้วของเข้าคลังโดยตรง
## ศิษย์เป็นร้อยคน ตึกหลายสิบหลัง = ลูปเดียวต่อวัน ไม่มีการหาเส้นทาง
## ศิษย์ที่ไม่ได้ประจำ (อิสระ) ช่วยก่อสร้างได้ช้าๆ ทำสมาธิเล็กน้อย และออกหาของป่าเมื่อเสบียงขาด

const TICKS_PER_DAY = 360
## แรงงานก่อสร้างต่อคนต่อวัน (แต้ม) ศิษย์ว่างช่วยได้เท่านี้ x FREE_BUILD_RATIO
const BUILD_POINTS = 12.0
const FREE_BUILD_RATIO = 0.4
## เสบียงที่ศิษย์อิสระหาได้ต่อคนต่อวันเมื่อขาดแคลน
const FORAGE_FOOD = 10

## ศิษย์ที่ทำงานได้ (อยู่ในสำนัก ไม่บาดเจ็บ ไม่ใช่เด็ก)
static func able(sect: SectData) -> Array[DiscipleData]:
	var out: Array[DiscipleData] = []
	for d in PawnSys.present(sect):
		if d.is_available(): out.append(d)
	return out

## ศิษย์ที่ประจำตึก inst และทำงานได้
static func workers(sect: SectData, inst: Dictionary) -> Array[DiscipleData]:
	var out: Array[DiscipleData] = []
	for d in BuildingDB.post_members(sect, inst.uid):
		if d.is_available() and d.needs.get("ordered", -1) != sect.current_day: out.append(d)
	return out

## ประสิทธิภาพรวมของศิษย์ที่ประจำ (คนทั่วไป ~1.0) ใช้ skill ของตึกและความเหมาะ (ลานฝึก)
static func efficiency(sect: SectData, inst: Dictionary, crew: Array) -> float:
	var skill: String = BuildingDB.POSTS[inst.type].skill
	var total = 0.0
	for d in crew:
		total += PawnSys.work_speed(d, skill)
	return total

static func level_mult(inst: Dictionary, per_level := 0.18) -> float:
	return 1.0 + (int(inst.level) - 1) * per_level

static func _acc(inst: Dictionary, key: String, amount: float) -> int:
	inst.acc[key] = float(inst.acc.get(key, 0.0)) + amount
	var n = int(inst.acc[key])
	inst.acc[key] -= n
	return n

static func _stat(sect: SectData, key: String, n: int) -> void:
	sect.sim_stats[key] = sect.sim_stats.get(key, 0) + n

# ══════════════════════════════════════════
# รายวัน
# ══════════════════════════════════════════

static func daily(sect: SectData, mgr: SectManager) -> void:
	OrderSys.daily(sect, mgr) # คำสั่งงานก่อน: ศิษย์ที่ถูกเกณฑ์ไปทำตามคำสั่งจะไม่อยู่ในทีมของตึกวันนั้น
	for inst in sect.structures.duplicate():
		if int(inst.level) <= 0 or not BuildingDB.POSTS.has(inst.type): continue
		var crew = workers(sect, inst)
		if crew.is_empty():
			inst["last_out"] = ""
			continue
		var before = _snap(sect)
		var e = efficiency(sect, inst, crew)
		match BuildingDB.POSTS[inst.type].work:
			"farm": _farm(sect, inst, e)
			"logging": _logging(sect, inst, e)
			"mine": _mine(sect, inst, e)
			"cook": _cook(sect, inst, e, crew)
			"alchemy": _alchemy(sect, inst, e, crew, mgr)
			"smith": _smith(sect, inst, e, crew, mgr)
			"research": _research(sect, inst, crew, mgr)
			"train": _train(sect, inst, crew, mgr)
			"doctor": _doctor(sect, inst, e, crew, mgr)
			"warden": _warden(sect, crew, mgr)
		inst["last_out"] = _diff_text(before, _snap(sect))
		# ทักษะงานโตจากการทำงานจริง
		var skill: String = BuildingDB.POSTS[inst.type].skill
		if skill != "":
			for d in crew:
				if PawnSys.learn(d, skill, 14.0):
					mgr.log_event("%s ทักษะ%sเลื่อนเป็นระดับ %d" % [d.disciple_name, WorkDB.SKILLS[skill].name, int(d.skills[skill].lv)], [d])
	_free_labor(sect, mgr)

const SNAP_KEYS = [["เสบียง", "food"], ["สำรับ", "meals"], ["เงิน", "money"], ["ไม้", "wood"], ["หิน", "stone"], ["หญ้าวิญญาณ", "spirit_grass"], ["แร่เหล็ก", "iron_ore"]]

static func _snap(sect: SectData) -> Array:
	return [sect.food, sect.meals, sect.money, sect.get_material_count("wood"), sect.get_material_count("stone"), sect.get_material_count("spirit_grass"), sect.get_material_count("iron_ore")]

## ผลต่างของคลังก่อน/หลังตึกทำงาน เช่น "+36 เสบียง, -5 หญ้าวิญญาณ"
static func _diff_text(a: Array, b: Array) -> String:
	var parts: Array[String] = []
	for i in a.size():
		var dv = int(b[i]) - int(a[i])
		if dv != 0: parts.append("%+d %s" % [dv, SNAP_KEYS[i][0]])
	return ", ".join(parts)

static func _farm(sect: SectData, inst: Dictionary, e: float) -> void:
	var cows = AnimalSys.livestock_near(sect, inst, "cow")
	var food = int(40.0 * e * level_mult(inst, 0.2) * (1.0 + minf(cows, 4) * 0.05))
	sect.food += food
	_stat(sect, "food_grown", food)
	var grass = _acc(inst, "spirit_grass", 0.5 * e)
	if grass > 0: sect.add_material("spirit_grass", grass)

static func _logging(sect: SectData, inst: Dictionary, e: float) -> void:
	var center = inst.cell + BuildingDB.BUILDINGS[inst.type].size / 2
	var trees = _acc(inst, "clear", 1.4 * e * level_mult(inst, 0.1))
	var cleared: Array[Vector2i] = []
	if trees > 0:
		cleared = Territory.forest_near(sect, center, 6 + int(inst.level), trees)
		for c in cleared: Territory.set_at(sect, c, Territory.T.GRASS)
	# ไม้: ได้เต็มเมื่อมีต้นไม้ให้ตัด ไม่งั้นแค่เศษกิ่งไม้
	var near_forest = not Territory.forest_near(sect, center, 6 + int(inst.level), 1).is_empty() or not cleared.is_empty()
	var wood = int((8.0 if near_forest else 2.5) * e * level_mult(inst, 0.1))
	sect.add_material("wood", wood)
	_stat(sect, "wood", wood)
	if not cleared.is_empty():
		sect.sim_stats["cleared"] = sect.sim_stats.get("cleared", 0) + cleared.size()
		sect.terrain_dirty = true

static func _mine(sect: SectData, inst: Dictionary, e: float) -> void:
	var stone = int(5.0 * e * level_mult(inst, 0.1))
	sect.add_material("stone", stone)
	_stat(sect, "stone", stone)
	if sect.deep_mining:
		sect.tremor += 0.05 * e
		var ore = _acc(inst, "ore", 0.8 * e)
		if ore > 0: sect.add_material("iron_ore", ore)
		if randf() < 0.12 * e: sect.add_material("cold_iron", 1)
		if randf() < 0.04 * e: sect.add_material("spirit_stone", 1)
		if randf() < 0.015 * e: sect.add_material("star_metal", 1)

static func _cook(sect: SectData, inst: Dictionary, e: float, crew: Array) -> void:
	var cycles = _acc(inst, "cook", 3.0 * e * level_mult(inst, 0.15))
	var lv = 0.0
	for d in crew: lv = maxf(lv, PawnSys.skill_lv(d, "cooking"))
	var pawns = PawnSys.present(sect).size()
	for i in cycles:
		if sect.food < 20 or sect.meals >= pawns * 3 + 6: break
		sect.food -= 20
		var fine = 0
		for k in 4:
			if randf() < lv * 0.04: fine += 1
		sect.meals += 4
		sect.fine_meals += fine
		_stat(sect, "meals_made", 4)
		_stat(sect, "food_cooked", 20)

static func _alchemy(sect: SectData, inst: Dictionary, e: float, crew: Array, mgr: SectManager) -> void:
	var batches = _acc(inst, "alchemy", 1.5 * e)
	var lv = 0.0
	for d in crew: lv = maxf(lv, PawnSys.skill_lv(d, "alchemy"))
	for i in batches:
		if sect.get_material_count("spirit_grass") < 5: break
		if sect.count_pills("calm_tea") >= 3 and sect.count_pills("healing_pill") >= 10: break
		sect.add_material("spirit_grass", -5)
		var q = clampi(int(lv / 5.0) - 1 + (1 if randf() < 0.3 else 0), 0, 3)
		if sect.count_pills("calm_tea") < 3:
			sect.add_pill("calm_tea", q)
			mgr.log_event("ชงชาสงบจิต [%s] ที่%s" % [RecipeDB.PILL_QUALITY_NAMES[q], BuildingDB.inst_name(inst)])
		else:
			sect.add_pill("healing_pill", q)
			mgr.log_event("หลอมยาฟื้นฟูโลหิต [%s] ที่%s" % [RecipeDB.PILL_QUALITY_NAMES[q], BuildingDB.inst_name(inst)])

static func _smith(sect: SectData, inst: Dictionary, e: float, crew: Array, mgr: SectManager) -> void:
	var batches = _acc(inst, "smith", 0.8 * e)
	var lv = 0.0
	for d in crew: lv = maxf(lv, PawnSys.skill_lv(d, "crafting"))
	for i in batches:
		if sect.get_material_count("iron_ore") < 5 or sect.equipment_storage.size() >= 12: break
		sect.add_material("iron_ore", -5)
		var eq = EquipmentDB.generate_random(BuildingDB.get_forge_rarity_bonus(int(inst.level), int(lv / 2.0)) * 0.5)
		sect.equipment_storage.append(eq)
		mgr.log_event("%s ตีได้ %s [%s]" % [BuildingDB.inst_name(inst), eq.item_name, eq.get_rarity_name()])

static func _research(sect: SectData, inst: Dictionary, crew: Array, mgr: SectManager) -> void:
	for d in crew:
		var lv = PawnSys.skill_lv(d, "intellect")
		for i in 2:
			mgr.do_study(d)
		if sect.research_skill != "": sect.research_days_left = maxf(0.0, sect.research_days_left - (0.6 + lv * 0.06))

static func _train(sect: SectData, inst: Dictionary, crew: Array, mgr: SectManager) -> void:
	for d in crew:
		var fit = MasterySys.fit(d, MasterySys.train_type(d))
		d.gain_experience(maxi(2, roundi(40.0 * fit * level_mult(inst, 0.15))), sect.current_day)
		mgr.train_mastery(d)
		mgr.train_mastery(d)
		d.needs.qi = minf(1.0, d.needs.get("qi", 0.5) + 0.3)

static func _doctor(sect: SectData, inst: Dictionary, e: float, crew: Array, mgr: SectManager) -> void:
	var capacity = maxi(1, int(round(e * 2.0)))
	var patients = PawnSys.present(sect).filter(func(p): return (p.injury_days > 0 or not p.ailments.is_empty()) and p.post != inst.uid)
	patients.sort_custom(func(a, b): return a.injury_days > b.injury_days)
	var i = 0
	for p in patients.slice(0, capacity):
		HealthSystem.treat(sect, crew[i % crew.size()], p, mgr)
		i += 1

static func _warden(sect: SectData, crew: Array, mgr: SectManager) -> void:
	if sect.prisoners.is_empty(): return
	for d in crew:
		if sect.prisoners.is_empty(): break
		PrisonerSys.recruit_attempt(sect, d, 0, mgr)

# ══════════════════════════════════════════
# ศิษย์อิสระ + ก่อสร้าง
# ══════════════════════════════════════════

## ศิษย์ที่ไม่ได้ประจำตึกใด: ทำสมาธิเล็กน้อย และหาของป่าช่วยเมื่อเสบียงขาดแคลน
static func _free_labor(sect: SectData, mgr: SectManager) -> void:
	var free: Array = able(sect).filter(func(d): return d.post == "" and d.needs.get("ordered", -1) != sect.current_day)
	if free.is_empty(): return
	var shortage = food_shortage(sect)
	var forage = 0
	for d in free:
		if d.study_skill != "": mgr.do_study(d, 1.0)
		d.gain_experience(roundi(10.0 * MasterySys.fit(d, MasterySys.train_type(d))), sect.current_day)
		d.needs.qi = minf(1.0, d.needs.get("qi", 0.5) + 0.12)
		if shortage: forage += FORAGE_FOOD
	if forage > 0:
		sect.food += forage
		_stat(sect, "food_forage", forage)

## ตำแหน่งแสดงผลของศิษย์ (ภาพประกอบ): ประจำตึก = วนอยู่หน้าตึกนั้น · อิสระ = ลานกลางรอบกองไฟ/โถงหลัก
static func place_disciples(sect: SectData) -> void:
	for d in sect.get_in_sect_disciples(): place_one(sect, d)

## ศิษย์คนนี้กำลังช่วยก่อสร้างอยู่ไหม (ศิษย์ว่าง หรือช่างค่ายช่าง ขณะมีไซต์ค้าง)
static func is_building(sect: SectData, d: DiscipleData) -> bool:
	if not d.is_available() or sect.construction_sites().is_empty(): return false
	return d.post == "" or BuildingDB.post_type(sect, d) == "builders_hut"

## จัดตำแหน่งภาพของศิษย์คนเดียว (เรียกทันทีเมื่อมอบหมาย/ถอดถอน ให้เห็นเดินไปที่ตึกเลย)
static func place_one(sect: SectData, d: DiscipleData) -> void:
	if d.needs.get("ordered", -1) == sect.current_day: return # กำลังทำงานตามคำสั่ง ยืนอยู่หน้างาน
	var inst = sect.instance(d.post) if d.post != "" else {}
	# กำลังเดินไปสร้างไซต์ (construction_step ขยับตำแหน่งให้เอง) ไม่วาร์ป
	if is_building(sect, d) and d.needs.get("travel", false): return
	d.needs["travel"] = false
	if not inst.is_empty():
		var r = BuildingDB.rect_of(inst)
		d.pos = Vector2(r.position) + Vector2(r.size) / 2.0 + Vector2(randf_range(-1.4, 1.4), r.size.y / 2.0 + randf_range(0.5, 1.5))
	else:
		d.pos = Vector2(Territory.HOME) + Vector2(randf_range(-3.5, 3.5), randf_range(2.0, 6.0))

## สถานะการผลิตของตึก (ข้อความสำหรับหน้ารายละเอียด): บอกว่าทำงานอยู่ไหม ขาดอะไร
static func status_text(sect: SectData, inst: Dictionary) -> String:
	if not BuildingDB.POSTS.has(inst.type): return ""
	if int(inst.level) <= 0: return "ยังสร้างไม่เสร็จ"
	var crew = workers(sect, inst)
	if crew.is_empty(): return "⚠ ไม่มีศิษย์ประจำ — ยังไม่ผลิต"
	var e = efficiency(sect, inst, crew)
	var rate = ""
	match BuildingDB.POSTS[inst.type].work:
		"farm": rate = "ผลผลิต ~%d เสบียง/วัน" % int(40.0 * e * level_mult(inst, 0.2))
		"cook":
			if sect.food < 20: return "⚠ ขาดเสบียงดิบ (ต้องใช้ 20 ต่อรอบ)"
			rate = "ปรุงสำรับ ~%.1f รอบ/วัน" % (3.0 * e * level_mult(inst, 0.15))
		"alchemy":
			if sect.get_material_count("spirit_grass") < 5: return "⚠ ขาดหญ้าวิญญาณ (ต้องใช้ 5 ต่อชุด)"
			rate = "~%.1f ชุด/วัน" % (1.5 * e)
		"smith":
			if sect.get_material_count("iron_ore") < 5: return "⚠ ขาดแร่เหล็ก (ต้องใช้ 5 ต่อชิ้น)"
			rate = "~%.1f ชิ้น/วัน" % (0.8 * e)
		_: rate = "กำลังทำงาน"
	var last = str(inst.get("last_out", ""))
	return "✔ %s · ประสิทธิภาพรวมของทีม x%.2f%s" % [rate, e, (" · วันล่าสุด: " + last) if last != "" else ""]

## เสบียงเหลือไม่ถึง ~2 วัน (อาหารดิบ + สำรับ): ภาวะขาดแคลน
static func food_shortage(sect: SectData) -> bool:
	return sect.food + sect.meals * 5 < PawnSys.present(sect).size() * 12

## แรงงานก่อสร้างรายวัน: ค่ายช่าง (เต็มแรง) + ศิษย์อิสระ (ช้ากว่า) แบ่งให้ไซต์ที่ค้างอยู่
static func construction_points(sect: SectData) -> float:
	var pts = 0.0
	for inst in sect.instances("builders_hut"):
		if int(inst.level) <= 0: continue
		for d in workers(sect, inst):
			pts += BUILD_POINTS * PawnSys.work_speed(d, "construction") * level_mult(inst, 0.2)
	for d in able(sect):
		if d.post == "": pts += BUILD_POINTS * FREE_BUILD_RATIO * PawnSys.work_speed(d, "construction")
	return pts

## ก่อสร้างโดยศิษย์จริง: ทุก CONSTRUCTION_STEP tick ศิษย์ว่าง/ช่างค่ายช่างเดินไปที่ไซต์ (ขยับตำแหน่งจริง WALK_STEP ช่อง)
## แต้มก่อสร้างเข้าไซต์ก็ต่อเมื่อศิษย์ถึงไซต์แล้วเท่านั้น หลอดจึงค่อยๆ ขึ้นตามจำนวนคนที่ยืนสร้างอยู่
const CONSTRUCTION_STEP = 6
const WALK_STEP = 0.9
const REACH = 1.6

static func construction_step(sect: SectData, mgr: SectManager) -> void:
	var sites = sect.construction_sites()
	if sites.is_empty():
		if sect.sim_stats.get("travelers", false):
			sect.sim_stats["travelers"] = false
			place_disciples(sect)
		return
	sect.sim_stats["travelers"] = true
	var frac = CONSTRUCTION_STEP / float(GlobalGame.TICKS_PER_PHASE * 3)
	var done: Array[String] = []
	for d in able(sect):
		if not is_building(sect, d): continue
		var is_hut = d.post != ""
		var site = sites[absi(hash(d.disciple_name)) % sites.size()]
		var r = BuildingDB.rect_of(site)
		var target = Vector2(r.position) + Vector2(r.size) / 2.0 + Vector2(0.0, r.size.y / 2.0 + 0.6)
		var to = target - d.pos
		d.needs["travel"] = true
		if to.length() > REACH:
			d.pos += to.normalized() * minf(WALK_STEP, to.length())
			continue
		var pts = BUILD_POINTS * PawnSys.work_speed(d, "construction") * (1.0 if is_hut else FREE_BUILD_RATIO)
		if is_hut: pts *= 1.0 + (int(sect.instance(d.post).get("level", 1)) - 1) * 0.2
		site.site.work += pts * frac
		if site.site.work >= site.site.required and not done.has(site.uid): done.append(site.uid)
	for uid in done: mgr.complete_construction(uid)