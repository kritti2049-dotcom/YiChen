extends Resource
class_name SectData

## ข้อมูลสถานะของสำนักหนึ่งๆ
## สร้างใหม่: คลิกขวาใน FileSystem > New Resource > SectData

@export var sect_name: String = "สำนักไร้นาม"

## ระดับความยาก (ดู BuildingDB.DIFFICULTY) ส่งผลกับศัตรู การบุก และการขยายตัวของสำนักอื่น
@export var difficulty: int = 1
## สำนักนี้ล่มสลายแล้ว (Game Over) แต่ข้อมูลยังเก็บไว้ในสล็อต
@export var is_game_over: bool = false

@export_group("Time")
## วันในเกม (เดินหน้าอัตโนมัติตามนาฬิกา 3 ช่วงเวลา)
@export var current_day: int = 1
## ช่วงเวลาในวัน 0 = เช้า, 1 = บ่าย, 2 = กลางคืน
@export var time_phase: int = 0
## ความคืบหน้าของช่วงเวลาปัจจุบัน 0-1
@export var phase_progress: float = 0.0

@export_group("Resources")
## จำนวนเงินของสำนัก
@export var money: int = 1000
## จำนวนเสบียงอาหารของสำนัก
@export var food: int = 500
## (เลิกใช้แล้ว ย้ายไปเก็บใน materials["spirit_grass"]) เก็บไว้เพื่อแปลงเซฟเก่า
@export var herbs: int = 0
## (เลิกใช้แล้ว ย้ายไปเก็บใน pills) เก็บไว้เพื่อแปลงเซฟเก่า
@export var breakthrough_pills: int = 0

@export_group("Inventory")
## คลังวัตถุดิบ { "material_id": จำนวน } (ดู MaterialDB)
@export var materials: Dictionary = {}
## คลังยา { "pill_id:quality": จำนวน } (ดู RecipeDB)
@export var pills: Dictionary = {}
## คลังอุปกรณ์ที่ยังไม่มีใครสวมใส่
@export var equipment_storage: Array[EquipmentData] = []

@export_group("Members & Assets")
## รายชื่อลูกศิษย์ในสำนัก
@export var disciples: Array[DiscipleData] = []
## อาคารที่สร้างแล้วในสำนัก (ระบบเก่า)
@export var buildings: Array[BuildingData] = []
## (เลิกใช้แล้ว) ระดับตึกแบบเก่า { "building_id": level } เก็บไว้แปลงเซฟเก่าเป็น structures
@export var building_levels: Dictionary = {}
@export var construction: Dictionary = {}
@export var plots: Dictionary = {}
## ตึกในสำนักแบบรายหลัง [{ uid: "#1", type, cell: Vector2i (มุมซ้ายบนของฐาน), level (0 = ยังสร้างไม่เสร็จ),
##   site: { work, required } (ไซต์ก่อสร้าง/อัปเกรดที่ค้าง, ว่าง = ไม่มี), acc: { ตัวสะสมผลผลิตเศษส่วน } }] ดู BuildingDB
@export var structures: Array[Dictionary] = []
@export var next_struct_id: int = 1
## ภูมิประเทศอาณาเขต SIZE x SIZE ช่อง (Territory.T) และคำสั่งถางป่า
@export var terrain: PackedByteArray = PackedByteArray()
## ภูมิประเทศเปลี่ยน (ถางป่า ฯลฯ) ให้ SectView วาดช่องใหม่ (ไม่บันทึก)
var terrain_dirty := false
## สัตว์ในอาณาเขต (AnimalSys) [{ id, species, pos, target, hp, hunger, tame, fire_days, group, state, age }] และช่องหญ้าที่ถูกกิน { ดัชนีช่อง: วันที่ถูกกิน }
@export var animals: Array[Dictionary] = []
@export var next_animal_id: int = 1
@export var grazed: Dictionary = {}

@export_group("Research")
## วิชาที่อยู่ในหอตำราของสำนัก (ศิษย์ศึกษาได้)
@export var library_skills: Array[String] = []
## วิชาที่สำนักคิดค้นเอง { ชื่อ: { tier, type, desc, power } }
@export var custom_skills: Dictionary = {}
## วิชาที่กำลังวิจัยอยู่ ("" = ไม่มี)
@export var research_skill: String = ""
@export var research_days_left: float = 0.0

@export_group("World")
## รหัสสร้างโลก (Seed) ไม่สุ่มตำแหน่งมณฑล แต่สุ่มความสัมพันธ์ เจ้าเมือง ผลผลิต และเหตุการณ์ (0 = ยังไม่ได้สุ่ม)
@export var world_seed: int = 0
## โหมดโลก: "story" = พิภพโลหิตชาด (เนื้อเรื่อง), "sandbox" = โกลาหลยุทธภพ (สุ่มทั้งหมด) ดู WorldMode
@export var world_mode: String = "story"
## อีเวนต์เนื้อเรื่องที่เกิดขึ้นแล้ว และอีเวนต์ที่รอผู้เล่นตัดสินใจ (ดู StorySys)
@export var story_done: Array[String] = []
@export var pending_story: Dictionary = {}
## จุดตั้งสำนักของเรา (WorldDB.START_SITES)
@export var start_site: String = ""
## รุ่นของแผนที่โลก (2 = แผนที่ตามตำนานพิภพโลหิตชาด) ใช้แปลงเซฟเก่า
@export var world_version: int = 0
## ตัวคูณผลผลิตของแต่ละพื้นที่ (สุ่มตาม Seed และเปลี่ยนตามเหตุการณ์) { node_id: float }
@export var node_yield: Dictionary = {}
## ภารกิจ/ล็อตประมูลที่ทำเสร็จแล้ว (key ไม่ซ้ำกัน เช่น "quest:capital:3:1")
@export var completed_world_tasks: Array[String] = []
## รอบเปิดแดนลับล่าสุดที่สำนักเราเข้าร่วมแล้ว
@export var last_secret_realm_cycle: int = -1

@export_group("Jianghu")
## สถานะสำนักอื่นในยุทธภพ { faction_id: { "power": int, "relation": int, "war": bool } }
@export var factions: Dictionary = {}
## เจ้าของพื้นที่บนแผนที่โลก { node_id: faction_id หรือ "player" }
@export var node_owner: Dictionary = {}
## ยอดฝีมือของสำนักอื่นในทำเนียบยุทธภพ [{ name, faction, power, fame, title }]
@export var champions: Array[Dictionary] = []
## ความสัมพันธ์ระหว่างขั้วอำนาจด้วยกันเอง { "a|b" (เรียงตามตัวอักษร): -100..100 }
@export var faction_rel: Dictionary = {}
## เจ้าเมือง { city_id: { "name": ชื่อ, "faction": faction_id } } (สุ่มตาม Seed สิบขันทีอาจยึดเปลี่ยนตัวได้)
@export var city_lords: Dictionary = {}
## สิบขันทีเรียกส่วย { "amount": int, "deadline": วัน } ว่าง = ไม่มี
@export var pending_tribute: Dictionary = {}
## สัญญาลอบสังหารจากสมาคมนักฆ่า { city, target, faction, reward, risk, key } ว่าง = ไม่มี
@export var active_contract: Dictionary = {}
## ความลับของขั้วอำนาจที่ซื้อมา { faction_id: วันที่หมดอายุ } (ศัตรูฝ่ายนั้นอ่อนลงในการต่อสู้)
@export var intel: Dictionary = {}
## จ้าวยุทธภพคนปัจจุบัน (faction_id, "player" หรือ "")
@export var wulin_leader: String = ""
## ชื่อเสียงของสำนัก (ใช้ในการโหวตจ้าวยุทธภพ)
@export var prestige: int = 0

@export_group("Colony Sim")
## นาฬิกาจำลอง: tick สะสมทั้งเกม และ tick ภายในช่วงเวลาปัจจุบัน (ดู SimScheduler)
@export var total_ticks: int = 0
@export var phase_tick: int = 0
## เจตจำนงสวรรค์ (StorytellerDB) + ตัวคูณปรับตัวตามความสูญเสีย
@export var storyteller: String = "wrath"
@export var adaptation: float = 1.0
@export var next_event_day: int = 8
@export var last_raid_day: int = 0
## วันที่ถูกบุกเพราะ "ชื่อเสียง/ทรัพย์/ของวิเศษ" ครั้งล่าสุด (StorytellerSystem.targeted_raid)
@export var last_targeted_day: int = -99
## แนวทางสำนัก −100 (มาร) .. +100 (ธรรมะ) ดู ReputationSys
@export var alignment: int = 0
## ผู้สมัครที่รอที่ประตูสำนัก [{ npc: DiscipleData, talent, reason, expire }] ดู ApplicantSys
@export var applicants: Array[Dictionary] = []
@export var next_applicant_day: int = 5
## ธงสำหรับเงื่อนไขจุดจบ (EndingSys)
@export var ending_flags: Dictionary = {}
## จุดจบที่รอแสดงให้ผู้เล่น (id ใน EndingDB) ว่าง = ไม่มี
@export var pending_ending: String = ""
## ตัวละครมีชื่อที่ชวนเข้าสำนักได้ (RosterSys) [{ id, name, node, status, opinion, ... }]
@export var roster: Array[Dictionary] = []
## จุดสำคัญบนแผนที่โลก: แร่/คัมภีร์ลับ/ของวิเศษ (LandmarkSys)
@export var landmarks: Array[Dictionary] = []
## คำสั่งงานทั่วแผนที่ (OrderSys): [{kind: chop|mine|hunt, cell: Vector2i, animal: id}]
@export var orders: Array[Dictionary] = []
## true = คำสั่งงานเกณฑ์ศิษย์ที่ประจำตึกมาช่วยเมื่อศิษย์ว่างไม่พอ (ตึกนั้นเสียกำลังงานของวันนั้น)
@export var order_draft: bool = false
## อาหารปรุงสุก (อาหารชั้นเลิศนับรวมอยู่ใน meals)
@export var meals: int = 0
@export var fine_meals: int = 0
## ของที่วางบนพื้นรอขนเข้าคลัง { spot: { mat: จำนวน } } ("food" = เสบียงดิบ)
@export var ground: Dictionary = {}
## ความสกปรกต่ออาคาร 0..1 และไฟไหม้ต่ออาคาร 0..1
@export var filth: Dictionary = {}
@export var fires: Dictionary = {}
## นักโทษ [{ name, enemy, faction, recruit }]
@export var prisoners: Array[Dictionary] = []
## เหมืองลึก (ได้แร่หายาก แต่สั่นสะเทือนปลุกสัตว์อสูรใต้ดิน)
@export var deep_mining: bool = false
@export var tremor: float = 0.0
## เหตุการณ์ที่รอผู้เล่นตัดสินใจ (ศัตรูบุก / คนขอเข้าสำนัก / กองคาราวาน)
@export var pending_event: Dictionary = {}
@export var caravan: Dictionary = {}
## สถิติสำหรับปรับสมดุล { raids, breaks, deaths, ... }
@export var sim_stats: Dictionary = {}
## การจองงาน (ไม่บันทึก): { key: ชื่อศิษย์ }
var reservations: Dictionary = {}

@export_group("History & Events")
## ประวัติเหตุการณ์ของสำนัก (Newsfeed)
## แต่ละรายการคือ Dictionary: { "day": int, "text": String, "involved_ids": Array }
@export var event_log: Array[Dictionary] = []

## ฟังก์ชันช่วยเหลือสำหรับเพิ่มเหตุการณ์เข้าสู่ประวัติสำนัก
func log_event(day: int, text: String, involved_ids: Array = []) -> void:
	event_log.append({
		"day": day,
		"text": text,
		"involved_ids": involved_ids
	})

## เติมค่าเริ่มต้นให้ระบบใหม่ และแปลงเซฟรุ่นเก่า (เรียกหลังสร้าง/โหลดสำนัก)
func ensure_defaults() -> void:
	if world_seed == 0:
		world_seed = randi() % 2000000000 + 1
	WorldMode.activate(self)
	_migrate_structures()
	if herbs > 0:
		add_material("spirit_grass", herbs)
		herbs = 0
	if breakthrough_pills > 0:
		add_pill("breakthrough_pill", 0, breakthrough_pills)
		breakthrough_pills = 0
	for d in disciples:
		d.ensure_defaults()
	for eq in equipment_storage: eq.migrate()
	if WorldDB.START_SITES.filter(func(s): return s.id == start_site).is_empty():
		start_site = WorldDB.START_SITES[0].id
	if world_version < 2:
		_migrate_lore_world()
	SkillDB.register_custom(custom_skills)
	SkillDB.register_custom(ArchiveSys.data().legacy_skills)
	FactionSys.init_world(self)
	Territory.init_world(self)
	AnimalSys.init_world(self)
	RosterSys.init_world(self)
	LandmarkSys.init_world(self)
	SkillQuestSys.ensure_steles(self)

## เซฟเก่าใช้แผนที่สุ่มแบบเดิม: ล้างข้อมูลยุทธภพเก่าเพื่อสร้างใหม่ตามแผนที่ตำนาน และเรียกศิษย์ที่อยู่นอกสำนักกลับบ้าน
func _migrate_lore_world() -> void:
	factions = {}
	node_owner = {}
	champions.clear()
	faction_rel = {}
	city_lords = {}
	node_yield = {}
	wulin_leader = ""
	for d in disciples:
		if d.status != DiscipleData.DiscipleStatus.MISSION: continue
		add_materials(d.carried_materials)
		equipment_storage.append_array(d.carried_equipment)
		for s in d.carried_skills: add_library_skill(s)
		d.carried_materials = {}
		d.carried_equipment.clear()
		d.carried_skills.clear()
		d.status = DiscipleData.DiscipleStatus.IDLE
		d.mission_type = ""
		d.mission_phase = ""
		d.mission_target = ""
	for d in disciples:
		if d.feud_target != "" and not FactionDB.FACTIONS.has(d.feud_target):
			d.feud_target = ""
			d.feud_intensity = 0
	world_version = 2
	log_event(current_day, "แผนที่โลกถูกสร้างใหม่ตามตำนานพิภพโลหิตชาด (5 มณฑล 6 ดินแดนชายขอบ) ศิษย์ที่อยู่นอกสำนักเดินทางกลับมาแล้ว")

func get_node_yield(id: String) -> float:
	return node_yield.get(id, 1.0)

## เมืองที่รุ่งเรือง (ผลผลิตสูง) ของถูกลง เมืองที่ฝืดเคืองของแพงขึ้น
func get_city_price_factor(id: String) -> float:
	return 1.0 + (1.0 - get_node_yield(id)) * 0.3

# ── สิ่งปลูกสร้าง ──

## ระดับสูงสุดของตึกชนิดนี้ที่สร้างเสร็จแล้ว (0 = ยังไม่มี) ใช้ปลดล็อกสูตร/ขั้นวิชา
func get_building_level(type: String) -> int:
	var best = 0
	for inst in structures:
		if inst.type == type: best = maxi(best, int(inst.level))
	return best

## ตึกชนิดนี้ที่สร้างเสร็จแล้วกี่หลัง
func building_count(type: String) -> int:
	var n = 0
	for inst in structures:
		if inst.type == type and int(inst.level) > 0: n += 1
	return n

## อินสแตนซ์ทั้งหมดของชนิดนี้ (รวมที่ยังไม่เสร็จ)
func instances(type: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for inst in structures:
		if inst.type == type: out.append(inst)
	return out

## อินสแตนซ์ตาม uid ({} ถ้าไม่มี)
func instance(uid: String) -> Dictionary:
	for inst in structures:
		if inst.uid == uid: return inst
	return {}

## เพิ่มตึกใหม่ที่มุม cell ระดับ level (0 = ยังไม่เสร็จ) คืนอินสแตนซ์
func add_structure(type: String, cell: Vector2i, level := 0) -> Dictionary:
	var inst = { "uid": "#%d" % next_struct_id, "type": type, "cell": cell, "level": level, "site": {}, "acc": {} }
	next_struct_id += 1
	structures.append(inst)
	return inst

func remove_structure(uid: String) -> void:
	for i in structures.size():
		if structures[i].uid == uid:
			structures.remove_at(i)
			fires.erase(uid)
			return

## เริ่มสร้าง/อัปเกรดอินสแตนซ์ uid (จ่ายวัสดุแล้ว) -> ไซต์ก่อสร้างที่แรงงานศิษย์ช่วยกันสร้างรายวัน
func start_construction(uid: String) -> void:
	var inst = instance(uid)
	if inst.is_empty(): return
	inst.site = { "work": 0.0, "required": BuildingDB.get_work_required(int(inst.level)) }

## uid ของไซต์ก่อสร้างแรกที่ค้างอยู่ ("" = ไม่มี)
func get_construction_site() -> String:
	for inst in structures:
		if not inst.site.is_empty(): return inst.uid
	return ""

func construction_sites() -> Array[Dictionary]:
	return structures.filter(func(i): return not i.site.is_empty())

## เซฟเก่า (ตึกชนิดละหลัง) -> อินสแตนซ์ ตำแหน่งเดิมเลื่อนมาอยู่กลางอาณาเขตใหม่
func _migrate_structures() -> void:
	if not structures.is_empty() or (building_levels.is_empty() and construction.is_empty()): return
	var shift = Territory.HOME - Vector2i(7, 7)
	var old_plots = {
		"main_hall": Vector2i(6, 2), "dormitory": Vector2i(10, 2), "training_ground": Vector2i(6, 6), "scripture_pavilion": Vector2i(2, 5),
		"alchemy_lab": Vector2i(10, 6), "forging_pavilion": Vector2i(2, 9), "infirmary": Vector2i(10, 10), "sect_formation": Vector2i(6, 10),
	}
	for type in old_plots:
		var lv: int = building_levels.get(type, 0)
		if lv <= 0 and not construction.has(type): continue
		var cell: Vector2i = plots.get(type, old_plots[type])
		var inst = add_structure(type, cell + shift, lv)
		if construction.has(type): inst.site = construction[type].duplicate()
	building_levels = {}
	construction = {}
	plots = {}
	_migrate_posts()

## ศิษย์ที่เคยประจำ "ชนิดตึก" (เซฟรุ่นก่อน) -> ประจำอินสแตนซ์แรกของชนิดนั้นที่ยังมีที่นั่ง
func _migrate_posts() -> void:
	for d in disciples:
		if d.post == "" or d.post.begins_with("#"): continue
		var type = d.post
		d.post = ""
		for inst in instances(type):
			if int(inst.level) > 0 and BuildingDB.post_members(self, inst.uid).size() < BuildingDB.post_slots(self, inst.uid):
				d.post = inst.uid
				break

## เพิ่มคัมภีร์เข้าหอตำรา และปลดล็อกในหอเกียรติยศ (Archive) สำหรับเซฟต่อไป
func add_library_skill(skill: String) -> bool:
	if skill == "" or library_skills.has(skill): return false
	library_skills.append(skill)
	ArchiveSys.unlock_skill(skill)
	return true

func get_founder() -> DiscipleData:
	for d in disciples:
		if d.is_founder: return d
	return disciples[0] if not disciples.is_empty() else null

func get_in_sect_disciples() -> Array[DiscipleData]:
	var result: Array[DiscipleData] = []
	for d in disciples:
		if d.status in [DiscipleData.DiscipleStatus.IDLE, DiscipleData.DiscipleStatus.TRAINING, DiscipleData.DiscipleStatus.INJURED]:
			result.append(d)
	return result

func count_owned_nodes() -> int:
	return node_owner.values().count("player")

func get_max_disciples() -> int:
	return BuildingDB.get_max_disciples(get_building_level("main_hall"))

func get_active_disciples() -> Array[DiscipleData]:
	var result: Array[DiscipleData] = []
	for d in disciples:
		if d.status != DiscipleData.DiscipleStatus.DEPARTED:
			result.append(d)
	return result

# ── วัตถุดิบ ──

func get_material_count(id: String) -> int:
	return materials.get(id, 0)

func add_material(id: String, amount: int) -> void:
	materials[id] = materials.get(id, 0) + amount
	if materials[id] <= 0:
		materials.erase(id)

func has_materials(req: Dictionary) -> bool:
	for id in req:
		if get_material_count(id) < req[id]:
			return false
	return true

func consume_materials(req: Dictionary) -> void:
	for id in req:
		add_material(id, -req[id])

func add_materials(mats: Dictionary) -> void:
	for id in mats:
		add_material(id, mats[id])

# ── ยา ──

func add_pill(pill_id: String, quality: int, amount: int = 1) -> void:
	var key = "%s:%d" % [pill_id, quality]
	pills[key] = pills.get(key, 0) + amount
	if pills[key] <= 0:
		pills.erase(key)

func count_pills(pill_id: String) -> int:
	var total = 0
	for key in pills:
		if key.begins_with(pill_id + ":"):
			total += pills[key]
	return total

## คุณภาพสูงสุดของยาชนิดนี้ที่มีอยู่ (-1 = ไม่มี)
func get_best_pill_quality(pill_id: String) -> int:
	var best = -1
	for key in pills:
		var parts = key.split(":")
		if parts[0] == pill_id and pills[key] > 0:
			best = max(best, int(parts[1]))
	return best

## ใช้ยาที่ดีที่สุดของชนิดนี้ 1 เม็ด คืนค่าคุณภาพ (-1 = ไม่มี)
func take_best_pill(pill_id: String) -> int:
	var q = get_best_pill_quality(pill_id)
	if q >= 0:
		add_pill(pill_id, q, -1)
	return q
