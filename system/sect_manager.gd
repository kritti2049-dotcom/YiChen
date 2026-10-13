extends Node
class_name SectManager

## บริหารจัดการสำนัก และดูแลความเป็น Dynamic (AI/Living World)
## อยู่ใน GlobalGame ตลอดเวลา เป็นตัวจัดจังหวะ (Scheduler) ของ System ต่างๆ:
## - sim_tick(): นับเวลา + ตัดสินเหตุการณ์ที่ผู้เล่นตัดสินใจไม่ทัน (ไม่มีการจำลองรายคนแล้ว)
## - process_phase(): ช่วงเวลาเปลี่ยน (เช้า/บ่าย/ค่ำ) ศิษย์ขยับไปรอบตึกที่ประจำ + สังคม
## - process_daily_update() ขึ้นวันใหม่: ผลผลิตรายตึก (ProductionSys) ความต้องการ ความเครียด อารมณ์ เศรษฐกิจ สังคม (งานมงคล/เกิด) เจตจำนงสวรรค์ การเดินทาง การเมืองยุทธภพ

signal day_passed(current_day: int)
signal sect_event_logged(event: Dictionary)
signal sect_resources_changed

var current_sect: SectData
## วันปัจจุบัน (เก็บอยู่ใน SectData เพื่อให้เซฟ/โหลดได้)
var current_day: int:
	get: return current_sect.current_day if current_sect else 1

## บทบาทของผู้เล่นในสำนักนี้ (0 = เจ้าสำนัก, 1 = ผู้อาวุโส, 2 = ศิษย์ทั่วไป, -1 = ไม่มี)
var player_role: int = 0

## ศิษย์ที่อยู่ในสำนักและทำงานได้ (ไม่บาดเจ็บ)
func _workers() -> Array[DiscipleData]:
	var result: Array[DiscipleData] = []
	for d in current_sect.disciples:
		if d.is_available(): result.append(d)
	return result

# ══════════════════════════════════════════
# ช่วงเวลาในวัน
# ══════════════════════════════════════════

func process_phase(_phase: int) -> void:
	if not current_sect: return
	ProductionSys.place_disciples(current_sect)
	SocialSystem.run(current_sect, self)
	sect_resources_changed.emit()

## จังหวะจำลอง 1 tick (GlobalGame เรียกตามเวลาจริง x ความเร็ว) — แค่นับเวลาและตัดสินเหตุการณ์ที่หมดเวลา
func sim_tick() -> void:
	var sect = current_sect
	if sect == null or sect.is_game_over: return
	sect.total_ticks += 1
	sect.phase_tick += 1
	if sect.total_ticks % ProductionSys.CONSTRUCTION_STEP == 0: ProductionSys.construction_step(sect, self)
	if sect.total_ticks % AnimalSys.UPDATE_TICKS == 0: AnimalSys.tick(sect, self)
	# เหตุการณ์ที่ผู้เล่นไม่ได้ตัดสินใจทันเวลา
	var ev = sect.pending_event
	if not ev.is_empty() and sect.total_ticks >= ev.get("deadline", 0):
		if ev.type == "raid": StorytellerSystem.auto_defend(sect, self)
		else:
			log_event("คนพเนจรรอนานเกินไปจึงเดินจากไป")
			sect.pending_event = {}

func complete_construction(uid: String) -> void:
	var sect = current_sect
	var inst = sect.instance(uid)
	if inst.is_empty(): return
	inst.site = {}
	inst.level = int(inst.level) + 1
	var lv = int(inst.level)
	log_event("[color=gold]%s %s! (ระดับ %d)[/color]" % [BuildingDB.inst_name(inst), "สร้างเสร็จแล้ว" if lv == 1 else "อัปเกรดเสร็จแล้ว", lv])
	ArchiveSys.unlock_achievement("first_building")
	if BuildingDB.CORE_TYPES.all(func(b): return sect.get_building_level(b) > 0):
		ArchiveSys.unlock_achievement("grand_sect")
	if inst.type == "farm": BuildingDB.paint_ground(sect, inst, Territory.T.FIELD)
	sect.terrain_dirty = true
	ProductionSys.place_disciples(sect)

## ศึกษาคัมภีร์ในหอตำรา: ได้ความชำนาญสายของคัมภีร์ที่อ่าน และมีโอกาสสำเร็จวิชา (ถ้าความชำนาญถึงเกณฑ์)
func do_study(d: DiscipleData) -> void:
	var unknown = current_sect.library_skills.filter(func(s): return not d.learned_skills.has(s))
	if unknown.is_empty(): return
	var learnable = unknown.filter(func(s): return MasterySys.can_learn(d, s))
	# อ่านคัมภีร์ที่ยังเรียนไม่ได้ เพื่อสะสมความชำนาญให้ถึงเกณฑ์ (ถ้ามี)
	var reading: String = unknown.pick_random() if learnable.is_empty() or randf() < 0.3 else learnable.pick_random()
	var fit = MasterySys.fit_skill(d, reading)
	_gain_mastery(d, MasterySys.skill_type(reading), maxi(1, roundi(MasterySys.GAIN_STUDY * fit)))
	if d.learned_skills.size() >= d.get_max_skills() or not MasterySys.can_learn(d, reading): return
	if randf() < (0.15 + d.get_stat("comprehension") * 0.02) * fit:
		d.learned_skills.append(reading)
		d.add_memory(current_day, "สำเร็จวิชา " + reading)
		log_event("[color=cyan]%s ศึกษาคัมภีร์จนสำเร็จวิชา %s[/color]" % [d.disciple_name, reading], [d])

## งานฝึกวิชา: ซ้อมอาวุธสายที่ถนัด (หรืออาวุธที่ถืออยู่)
func train_mastery(d: DiscipleData) -> void:
	var t = MasterySys.train_type(d)
	_gain_mastery(d, t, maxi(1, roundi(MasterySys.GAIN_TRAINING * MasterySys.fit(d, t))))

func _gain_mastery(d: DiscipleData, type: String, amount: int) -> void:
	if MasterySys.gain(d, type, amount):
		var lv = MasterySys.get_level(d, type)
		log_event("[color=gold]%s ชำนาญ%sขึ้นเป็นระดับ %d (%s)[/color]" % [d.disciple_name, MasterySys.type_name(type), lv, MasterySys.RANK_NAMES[lv]], [d])

# ══════════════════════════════════════════
# รายวัน
# ══════════════════════════════════════════

## เข้าสู่วันใหม่
func process_daily_update() -> void:
	if not current_sect: return
	var sect = current_sect
	sect.current_day += 1
	var new_year = current_day % CultivationSys.DAYS_PER_YEAR == 0

	for disciple in sect.disciples:
		if disciple.status == DiscipleData.DiscipleStatus.DEPARTED: continue
		# ระบบเก่า: สถานะฝึกซ้อมถูกแทนด้วยงาน "ฝึกวิชา"
		if disciple.status == DiscipleData.DiscipleStatus.TRAINING:
			disciple.status = DiscipleData.DiscipleStatus.IDLE

		# 0.1 อายุขัย (เพิ่มอายุทุกปี ถ้าเกินอายุขัยของขั้นพลังจะสิ้นชีพ)
		if new_year:
			disciple.age += 1
			var lifespan = CultivationSys.get_lifespan(disciple.level)
			if lifespan > 0 and disciple.age >= lifespan:
				disciple.status = DiscipleData.DiscipleStatus.DEPARTED
				disciple.death_cause = "สิ้นอายุขัย"
				log_event("%s สิ้นอายุขัยที่ %d ปี ก่อนจะทะลวงขั้นได้ทัน..." % [disciple.disciple_name, disciple.age], [disciple])
				continue

		# 0.5 พักฟื้นอาการบาดเจ็บ
		if disciple.status == DiscipleData.DiscipleStatus.INJURED:
			disciple.injury_days -= 1
			if disciple.injury_days <= 0:
				disciple.injury_days = 0
				disciple.status = DiscipleData.DiscipleStatus.IDLE
				log_event("%s หายจากอาการบาดเจ็บแล้ว" % disciple.disciple_name, [disciple])

		# 1. ตั้งค่า component ที่ยังไม่มี + ทักษะงานที่ไม่ได้ใช้นานค่อยๆ เสื่อม
		PawnSys.ensure(disciple, sect)
		_decay_skills(disciple)

		# 2. อารมณ์ต่ำนาน + ความภักดีต่ำ = ทิ้งสำนัก
		check_loyalty_and_defection(disciple)
		if disciple.status == DiscipleData.DiscipleStatus.DEPARTED: continue

		# 3. การเรียนรู้วิชาจากอาจารย์ (Skill Inheritance)
		if disciple.master and randf() < 0.1: # โอกาส 10% ต่อวัน
			if disciple.master.learned_skills.size() > 0:
				var random_skill = disciple.master.learned_skills.pick_random()
				if not disciple.learned_skills.has(random_skill) and MasterySys.can_learn(disciple, random_skill):
					disciple.learned_skills.append(random_skill)
					log_event("%s ได้เรียนรู้วิชา %s จากอาจารย์ %s" % [disciple.disciple_name, random_skill, disciple.master.disciple_name], [disciple, disciple.master])

	# 3.5 ศิษย์ที่ประจำการเกินที่นั่ง/อาคารไม่มีแล้ว = ปลดออก
	BuildingDB.validate_posts(sect)
	ProductionSys.daily(sect, self)
	AnimalSys.daily(sect, self)
	NeedsSystem.daily(sect, self)
	StressSystem.daily_run(sect, self)
	StressSystem.daily(sect, self)
	MoodSystem.run(sect, self)

	# 4. อาการที่ไม่ได้รักษาจะลุกลาม (หมอรักษาผ่านงาน [รักษา] ใน JobSystem)
	process_ailments()

	# 5. เศรษฐกิจ (ของเสื่อม ค่าซ่อมบำรุง) และสังคม (งานมงคล การเกิด เด็กเติบโต)
	EconomySystem.daily(sect, self)
	SocialSystem.daily(sect, self)
	if not sect.caravan.is_empty() and current_day > sect.caravan.until:
		sect.caravan = {}
		log_event("กองคาราวานเก็บร้านเดินทางต่อไปแล้ว")

	# 7. รายได้จากอาณาเขต (โถงหลัก)
	sect.money += BuildingDB.get_territory_income(sect.get_building_level("main_hall"))

	# 7.5 ผู้สมัครที่ประตูสำนัก (ชื่อเสียงยิ่งสูงยิ่งมาก)
	ApplicantSys.daily(sect, self)

	# 7.6 เหมืองแร่หายากที่ยึดไว้ส่งแร่เข้าคลัง
	LandmarkSys.daily(sect, self)

	# 8. งานถอดรหัสคัมภีร์ในหอตำรา
	process_research()

	# 9. ศิษย์ที่เดินทางบนแผนที่โลก
	for text in ExpeditionSys.process_day(sect, current_day):
		log_event(text)

	# 10. ข่าวแดนลับ
	if WorldDB.is_secret_realm_open(current_day) and current_day % WorldDB.SECRET_REALM_INTERVAL == 0:
		log_event("[color=violet]ฟ้าดินสั่นสะเทือน! แดนลับบรรพกาลเปิดออกแล้ว (เปิด %d วัน) รีบส่งศิษย์หัวกะทิไปแย่งชิงสมบัติ![/color]" % WorldDB.SECRET_REALM_OPEN_DAYS)
	elif WorldDB.days_until_secret_realm(current_day) == 10:
		log_event("มีข่าวลือว่าแดนลับบรรพกาลจะเปิดในอีก 10 วัน")

	# 11. การเมืองยุทธภพ (ขยายอาณาเขต สงคราม ประชุมยุทธภพ ความแค้น)
	FactionSys.daily(sect, current_day, log_event)
	# 11.5 อีเวนต์ตามเนื้อเรื่อง (โหมดพิภพโลหิตชาด)
	StorySys.daily(sect, current_day, log_event)

	# 12. เจตจำนงสวรรค์: ประเมินความมั่งคั่ง -> ส่งเหตุการณ์ (ศัตรูบุก/โรคระบาด/คนพเนจร/คาราวาน ...)
	StorytellerSystem.daily(sect, self)

	# 12.5 เช็กเงื่อนไขจุดจบ
	EndingSys.daily(sect)

	if sect.get_active_disciples().size() >= 10:
		ArchiveSys.unlock_achievement("ten_disciples")
	sect_resources_changed.emit()
	day_passed.emit(current_day)

## อาการที่ไม่ได้รักษาจะลุกลาม (พิการ/เสียชีวิต) หมอรักษาผ่านงาน [รักษา] (HealthSystem.treat)
func process_ailments() -> void:
	var sect = current_sect
	for d in sect.get_active_disciples():
		for i in range(d.ailments.size() - 1, -1, -1):
			var ail = d.ailments[i]
			var info = AilmentDB.get_ailment(ail.id)
			ail.days += 1
			if info.lethal_days > 0 and ail.days >= info.lethal_days:
				HealthSystem.kill(sect, d, info.name + "กำเริบ", self)
				break
			if info.cripple_days > 0 and ail.days >= info.cripple_days:
				d.ailments.remove_at(i)
				d.disabled = true
				log_event("[color=red]%s ไม่ได้รับการรักษา%sทันเวลา กลายเป็นคนพิการถาวร![/color]" % [d.disciple_name, info.name], [d])
			elif info.heal_days > 0 and ail.days >= info.heal_days:
				d.ailments.remove_at(i)
			elif ail.id == "gu_poison":
				d.mood = max(0, d.mood - 3)
				if info.lethal_days - ail.days == 5:
					log_event("[color=red]พิษกู่ใน %s กำเริบหนัก เหลือเวลาอีก 5 วัน! ต้องให้หมอถอนพิษด่วน[/color]" % d.disciple_name, [d])

## เดินหน้างานถอดรหัสคัมภีร์ในหอตำรา
func process_research() -> void:
	if current_sect.research_skill == "": return
	# ถอดรหัสเองช้าๆ วันละ 0.5 (ศิษย์งาน [วิจัยคัมภีร์] เร่งให้เร็วขึ้นมาก)
	current_sect.research_days_left -= 0.5
	if current_sect.research_days_left <= 0:
		var skill = current_sect.research_skill
		current_sect.research_skill = ""
		current_sect.research_days_left = 0
		current_sect.add_library_skill(skill)
		log_event("[color=cyan][หอตำรา] ถอดรหัสสำเร็จ! คัมภีร์วิชา %s (%s) ถูกบรรจุเข้าหอตำรา[/color]" % [skill, SkillDB.TIER_NAMES[SkillDB.get_skill(skill).tier]])

## เริ่มถอดรหัสคัมภีร์ชำรุดระดับ tier (คืนค่าข้อความผลลัพธ์)
func start_research(tier: int) -> String:
	if current_sect.research_skill != "":
		return "หอตำรากำลังถอดรหัส %s อยู่ (อีก %d วัน)" % [current_sect.research_skill, current_sect.research_days_left]
	if tier > current_sect.get_building_level("scripture_pavilion"):
		return "ต้องอัปเกรดหอตำราให้ถึงระดับ %d ก่อน" % tier
	var cost = BuildingDB.get_research_cost(tier)
	if current_sect.money < cost.money:
		return "เงินไม่พอ (ต้องการ %d)" % cost.money
	if current_sect.get_material_count("scripture_fragment") < cost.fragments:
		return "คัมภีร์ชำรุดไม่พอ (ต้องการ %d ชิ้น) ไปแย่งชิงมาจากดันเจี้ยน/สำนักศัตรู/แดนลับ" % cost.fragments
	var pool: Array = []
	for s in SkillDB.SKILLS:
		if SkillDB.SKILLS[s].tier == tier and not current_sect.library_skills.has(s):
			pool.append(s)
	if pool.is_empty():
		return "ถอดรหัสวิชาขั้นนี้ครบทุกวิชาแล้ว"
	current_sect.money -= cost.money
	current_sect.add_material("scripture_fragment", -cost.fragments)
	current_sect.research_skill = pool.pick_random()
	current_sect.research_days_left = cost.days
	return "เริ่มถอดรหัสคัมภีร์ชำรุดขั้น%s ใช้เวลา %d วัน" % [SkillDB.TIER_NAMES[tier], cost.days]

## ทักษะงานที่สูงกว่า 10 ค่อยๆ เสื่อมถ้าไม่ได้ใช้ (นิสัยเรียนรู้ไว = ไม่เสื่อม)
func _decay_skills(d: DiscipleData) -> void:
	if BehaviorTraitDB.has_flag(d.btraits, "no_decay"): return
	for s in d.skills:
		var sk = d.skills[s]
		if sk.lv <= 10: continue
		sk.xp -= (sk.lv - 10) * 1.5
		if sk.xp < 0:
			sk.lv -= 1
			sk.xp += WorkDB.XP_PER_LEVEL

## อารมณ์ย่ำแย่ + ความภักดีต่ำ = ทิ้งสำนัก (ผลจากระบบอารมณ์ ไม่ได้สุ่มลอยๆ)
func check_loyalty_and_defection(disciple: DiscipleData) -> void:
	if disciple.is_founder or disciple.is_child: return
	if disciple.mood < 25: disciple.loyalty = max(0.0, disciple.loyalty - 2.0)
	elif disciple.mood > 60: disciple.loyalty = min(100.0, disciple.loyalty + 0.5)
	if disciple.loyalty < 20 and disciple.mood < 20 and randf() < 0.05:
		disciple.status = DiscipleData.DiscipleStatus.DEPARTED
		disciple.death_cause = "ออกจากสำนัก"
		if disciple.btraits.has("abrasive") or disciple.ambition == "อยากตั้งสำนักเอง":
			var stolen_money = min(current_sect.money, 500)
			current_sect.money -= stolen_money
			log_event("%s ทนอยู่ไม่ไหว ทรยศสำนัก! หลบหนีไปพร้อมกับเงิน %d (เพราะ %s)" % [disciple.disciple_name, stolen_money, MoodSystem.reasons(current_sect, disciple)], [disciple])
		else:
			log_event("%s ทนไม่ไหวกับสภาพของสำนัก และเก็บของจากไปเงียบๆ (เพราะ %s)" % [disciple.disciple_name, MoodSystem.reasons(current_sect, disciple)], [disciple])

## บันทึกเหตุการณ์ลง SectData และส่ง Signal ไปยัง UI
func log_event(text: String, involved_ids: Array = []) -> void:
	if current_sect:
		current_sect.log_event(current_day, text, involved_ids)
		if current_sect.event_log.size() > 400:
			current_sect.event_log = current_sect.event_log.slice(-300)

	var event_data = {
		"day": current_day,
		"text": text,
		"involved_ids": involved_ids
	}
	sect_event_logged.emit(event_data)

func join_sect(sect: SectData, role: int) -> void:
	current_sect = sect
	player_role = role
