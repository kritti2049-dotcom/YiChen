extends Node

## เครื่องมือจำลองเร่งเวลา (Accelerated Simulation) ใช้ปรับสมดุลเกมโดยไม่ต้องเล่นเอง
## รันแบบไม่มีหน้าจอ:
##   godot --headless --path . res://tools/simulate.tscn -- --days=300 --teller=wrath --seed=1 --every=30
## ตัวเลือก:
##   --days=N        จำนวนวันที่จำลอง (ค่าเริ่ม 120)
##   --teller=ID     wrath / mercy / chaos (เจตจำนงสวรรค์)
##   --seed=N        เมล็ดสุ่ม (รันซ้ำได้ผลเดิม)
##   --every=N       พิมพ์รายงานทุก N วัน (ค่าเริ่ม 30)
##   --pawns=N       จำนวนศิษย์ตั้งต้น (ค่าเริ่ม 5)
##   --slot=N        โหลดเซฟสล็อต N มาจำลองต่อแทนการสร้างสำนักใหม่ (ผลลัพธ์ไม่ถูกบันทึกทับสล็อตเดิม)
##   --no-accept     ไม่รับคนพเนจร (ค่าเริ่ม: รับทุกคน)
##   --log=TEXT      พิมพ์บันทึกเหตุการณ์ที่มีข้อความนี้ (เช่น --log=บุก, --log=all = ทุกบรรทัด)
##   --money=N       เริ่มด้วยเงิน N (ทดสอบการถูกหมายตาเพราะทรัพย์ ≥ 100000)
##   --hall=N        ระดับโถงหลักเริ่มต้น (ศิษย์สูงสุด = 5+3N) ใช้ทดสอบศิษย์เป็นร้อยด้วย --pawns=100 --hall=10
##   --fame=N        เริ่มด้วยบารมีสำนัก N (ทดสอบผู้สมัครตามชื่อเสียง)
##   --sword         เริ่มโดยมีกระบี่มหาโชคมารในคลัง (ทดสอบทัพที่ตามล่า)
##   --formation=N   สร้างค่ายกลปกป้องสำนักระดับ N และให้ศิษย์ประจำค่ายกล
##   --no-assign     ไม่มอบหมายศิษย์เข้าตึกอัตโนมัติ (ค่าเริ่ม: จัดคนเข้าลานฝึก/หอหลอมโอสถ/เรือนนอนให้)
##   --trace         พิมพ์สัดส่วนเวลาที่ศิษย์ใช้กับงานแต่ละประเภท + การไหลของอาหารในแต่ละช่วงรายงาน
## ผลลัพธ์: ตารางความมั่งคั่ง/คะแนนภัย/เงิน/อาหาร/ศิษย์/อารมณ์เฉลี่ย/ธาตุไฟแตกซ่าน/ศัตรูบุก/ตาย ทุกช่วง + สรุปท้ายรัน
## การจำลองใช้ sim_tick เดียวกับเกมจริง (ศัตรูบุก = ตั้งรับอัตโนมัติเมื่อหมดเวลาตัดสินใจ)

const SIM_SLOT = 99

var opts := { "days": 120, "teller": "wrath", "seed": -1, "every": 30, "pawns": 5, "slot": 0, "accept": true, "trace": false, "log": "", "assign": true, "hall": 1, "fame": 0, "money": 0, "sword": false, "formation": 0, "orders": false }
## จำนวน tick ที่ใช้กับงานแต่ละประเภท (ใน 1 ช่วงรายงาน)
var _work_ticks := {}
## ผลรวมความคิด (อารมณ์) แยกตามชนิด และจำนวนครั้งที่สุ่มตัวอย่าง
var _thought_sum := {}
var _thought_samples := 0
var sim_applicants := 0
var sim_endings := []

func _ready() -> void:
	_parse_args()
	if opts.seed >= 0: seed(opts.seed)
	var gg = get_node("/root/GlobalGame")
	var sect: SectData
	if opts.slot > 0:
		var path = gg.slot_path(opts.slot)
		if not ResourceLoader.exists(path):
			printerr("ไม่พบเซฟสล็อต %d" % opts.slot)
			get_tree().quit(1)
			return
		sect = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as SectData
	else:
		sect = new_sect(opts.teller, opts.pawns, opts.hall)
	if opts.money > 0: sect.money = opts.money
	if opts.fame > 0: sect.prestige += opts.fame
	if opts.sword: sect.equipment_storage.append(EquipmentDB.make_cursed_sword())
	if opts.formation > 0: sect.add_structure("sect_formation", Territory.HOME + Vector2i(1, 5), opts.formation)
	gg.current_slot = SIM_SLOT
	gg.set_sect(sect)
	if opts.log != "":
		var re = RegEx.create_from_string("\\[[^\\]]*\\]")
		gg.sect_manager.sect_event_logged.connect(func(e):
			var text = re.sub(str(e.get("text", "")), "", true)
			if opts.log == "all" or text.contains(opts.log): print("   [วัน %d] %s" % [gg.current_sect.current_day, text]))
	if opts.slot > 0 and opts.teller != "": sect.storyteller = opts.teller
	print("== จำลอง %d วัน · เจตจำนง %s · ศิษย์ %d คน ==" % [opts.days, StorytellerDB.get_teller(sect.storyteller).name, sect.get_active_disciples().size()])
	print(_header())
	var t0 = Time.get_ticks_msec()
	var start_day = sect.current_day
	while sect.current_day < start_day + opts.days and not sect.is_game_over:
		gg.sect_manager.sim_tick()
		if opts.trace:
			if sect.total_ticks % 30 == 0:
				for d in PawnSys.present(sect):
					var w = BuildingDB.post_type(sect, d)
					w = "ว่าง" if w == "" else w
					_work_ticks[w] = _work_ticks.get(w, 0) + 1
				_sample_thoughts(sect)
		if sect.phase_tick < GlobalGame.TICKS_PER_PHASE: continue
		gg.advance_phase(true)
		_auto_decide(sect, gg)
		if opts.assign: _auto_assign(sect)
		if opts.orders and sect.orders.size() < 10: _auto_orders(sect)
		if sect.pending_ending != "" and not sect.is_game_over:
			sim_endings.append("%s (วันที่ %d)" % [EndingDB.ENDINGS[sect.pending_ending].name, sect.current_day])
			sect.pending_ending = ""
		if sect.time_phase == 0 and (sect.current_day - start_day) % opts.every == 0:
			print(_row(sect))
			if opts.trace: _print_trace()
	var ms = Time.get_ticks_msec() - t0
	print(_row(sect))
	print(_summary(sect, ms, sect.current_day - start_day))
	gg.delete_slot(SIM_SLOT)
	get_tree().quit()

## --orders: ทดสอบระบบสั่งงานทั่วแผนที่ สั่งตัดไม้/ทุบหิน/ล่าสัตว์รอบสำนักเมื่อคิวใกล้หมด
func _auto_orders(sect: SectData) -> void:
	var H = Territory.HOME
	for k in ["chop", "mine", "hunt"]:
		if OrderSys.count(sect, k) >= 4: continue
		var r = 22 if k != "hunt" else 34
		var added = OrderSys.add_area(sect, k, Rect2i(H - Vector2i(r, r), Vector2i(2 * r, 2 * r)))
		var extra = sect.orders.filter(func(o): return o.kind == k)
		while extra.size() > 5: sect.orders.erase(extra.pop_back())

func _print_trace() -> void:
	var total = 0
	for w in _work_ticks: total += _work_ticks[w]
	var keys = _work_ticks.keys()
	keys.sort_custom(func(a, b): return _work_ticks[a] > _work_ticks[b])
	print("      งาน: " + ", ".join(keys.map(func(w): return "%s %d%%" % [w, roundi(100.0 * _work_ticks[w] / max(1, total))])))
	_work_ticks.clear()
	var st = GlobalGame.current_sect.sim_stats
	var flow = ["food_grown", "food_forage", "food_cooked", "food_raw", "meals_made", "meals_eaten", "wood", "stone", "cleared"]
	print("      ผลผลิต (สะสม): เสบียงปลูก %d · หาของป่า %d · นำไปปรุง %d · กินดิบ %d · สำรับที่ทำ %d · สำรับที่กิน %d · ไม้ %d · หิน %d · ช่องป่าที่ถาง %d" % flow.map(func(k): return st.get(k, 0)))
	var ids = _thought_sum.keys()
	ids.sort_custom(func(a, b): return abs(_thought_sum[a]) > abs(_thought_sum[b]))
	print("      อารมณ์ (เฉลี่ยต่อคน): " + ", ".join(ids.slice(0, 10).map(func(id): return "%s %+.1f" % [ThoughtDB.get_def(id).name, _thought_sum[id] / max(1, _thought_samples)])))
	_thought_sum.clear()
	_thought_samples = 0

func _sample_thoughts(sect: SectData) -> void:
	for d in PawnSys.present(sect):
		if d.is_child: continue
		_thought_samples += 1
		var all: Array = MoodSystem.situational(sect, d)
		for t in d.thoughts: all.append(t)
		for t in all: _thought_sum[t.id] = _thought_sum.get(t.id, 0.0) + t.value
		var base = MoodSystem.base_mood(d) - ThoughtDB.BASE_MOOD
		if base != 0: _thought_sum["นิสัย(ค่าฐาน)"] = _thought_sum.get("นิสัย(ค่าฐาน)", 0.0) + base

func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a in ["--no-accept", "--trace", "--no-assign", "--sword", "--orders"]:
			opts[a.trim_prefix("--").replace("no-", "")] = a in ["--trace", "--sword", "--orders"]
			continue
		var kv = a.trim_prefix("--").split("=")
		if kv.size() != 2 or not opts.has(kv[0]): continue
		opts[kv[0]] = kv[1] if kv[0] in ["teller", "log"] else int(kv[1])

## สำนักทดสอบมาตรฐาน: อาคารพื้นฐานครบ ศิษย์ N คน
static func new_sect(teller: String, pawns: int, hall := 1) -> SectData:
	var s = SectData.new()
	s.sect_name = "สำนักจำลอง"
	s.difficulty = 1
	s.money = 1200
	s.food = 450
	s.add_materials({ "wood": 40, "stone": 40, "spirit_grass": 20 })
	s.world_version = 2
	s.storyteller = teller
	s.world_seed = 777
	var H = Territory.HOME
	s.add_structure("main_hall", H + Vector2i(-1, -1), hall)
	var layout = [
		["dormitory", Vector2i(3, -4)], ["dormitory", Vector2i(5, -4)], ["training_ground", Vector2i(3, 1)], ["farm", Vector2i(-7, -2)], ["farm", Vector2i(-7, 1)],
		["kitchen", Vector2i(-4, 2)], ["lumber_camp", Vector2i(-3, 5)], ["alchemy_lab", Vector2i(0, -7)], ["scripture_pavilion", Vector2i(-3, -5)], ["campfire", Vector2i(0, 3)],
	]
	for e in layout:
		s.add_structure(e[0], H + e[1], 1)
	for i in pawns:
		var d = NPCGenerator.generate_npc(0 if i > 0 else 1, randi_range(1, 4))
		if i == 0:
			d.is_founder = true
			d.loyalty = 100
		s.disciples.append(d)
	return s

## จัดศิษย์เข้าตึกแทนผู้เล่น: คนเครียดจัดสั่งนอนพักที่เรือนนอน คนว่างเติมที่นั่งอัตโนมัติ (ฟาร์ม/ครัว/ลานฝึก ฯลฯ)
func _auto_assign(sect: SectData) -> void:
	for d in PawnSys.present(sect):
		if d.is_child: continue
		if d.stress >= 70:
			BuildingDB.sleep_disciple(sect, d)
	BuildingDB.auto_assign(sect)

## ตัดสินใจแทนผู้เล่น: รับคนพเนจร (ตามตัวเลือก) ศัตรูบุก = ปล่อยให้ตั้งรับอัตโนมัติเมื่อหมดเวลา
func _auto_decide(sect: SectData, gg) -> void:
	if opts.accept:
		while not sect.applicants.is_empty() and sect.get_active_disciples().size() < sect.get_max_disciples():
			sim_applicants += 1
			ApplicantSys.accept(sect, 0, gg.sect_manager)

func _header() -> String:
	return "%5s | %8s | %6s | %6s | %5s | %5s | %5s | %5s | %6s | %5s | %5s | %4s" % ["วัน", "มั่งคั่ง", "ภัย", "เงิน", "อาหาร", "สำรับ", "ศิษย์", "อารมณ์", "ธาตุแตก", "บุก", "ตาย", "ปรับตัว"]

func _row(sect: SectData) -> String:
	var pawns = PawnSys.present(sect)
	var mood = 0.0
	for d in pawns: mood += d.mood
	mood = mood / max(1, pawns.size())
	var st = sect.sim_stats
	return "%5d | %8d | %6d | %6d | %5d | %5d | %5d | %5.1f | %6d | %5d | %5d | %4.2f" % [
		sect.current_day, int(StorytellerSystem.wealth_breakdown(sect).total), int(StorytellerSystem.threat_points(sect)),
		sect.money, sect.food, sect.meals, pawns.size(), mood, st.get("breaks", 0), st.get("raids", 0), st.get("deaths", 0), sect.adaptation]

func _summary(sect: SectData, ms: int, days: int) -> String:
	var st = sect.sim_stats
	var lines = ["== สรุป ==",
		"เวลาจริง %.1f วินาที (%.1f ms/วัน)" % [ms / 1000.0, ms / float(max(1, days))],
		"เหตุการณ์ %d · ศัตรูบุก %d · ธาตุไฟแตกซ่าน %d · ต่อยกัน %d · ตาย %d" % [st.get("events", 0), st.get("raids", 0), st.get("breaks", 0), st.get("fights", 0), st.get("deaths", 0)],
		"สถานะ: %s" % ("สำนักล่มสลาย" if sect.is_game_over else "ยังอยู่รอด"),
	]
	var married = sect.disciples.filter(func(d): return d.spouse != "" and d.status != DiscipleData.DiscipleStatus.DEPARTED)
	lines.append("เด็กเกิดใหม่ %d · คู่สมรส %d คน · นักโทษ %d" % [st.get("births", 0), married.size(), sect.prisoners.size()])
	lines.append("สัตว์: %s · เหยื่อถูกล่า %d · ฆ่าหมาป่า %d · เสบียงจากสัตว์เลี้ยง %d" % [AnimalSys.summary(sect), st.get("prey_lost", 0), st.get("wolves_killed", 0), st.get("food_livestock", 0)])
	lines.append("ชื่อเสียง: %s (คะแนน %d) · แนวทาง %s (%d) · ผู้สมัครที่รับ %d · รอที่ประตู %d" % [ReputationSys.tier_name(sect), ReputationSys.score(sect), ReputationSys.alignment_name(sect), sect.alignment, sim_applicants, sect.applicants.size()])
	lines.append("จุดจบที่พบ: %s" % (", ".join(sim_endings) if not sim_endings.is_empty() else ("ล่มสลาย" if sect.is_game_over else "ยังไม่มี")))
	return "\n".join(lines)
