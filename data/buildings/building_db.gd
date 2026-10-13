extends Node
class_name BuildingDB

## ฐานข้อมูลสิ่งปลูกสร้างในสำนัก (2.5D) + ระดับความยาก
## ตึกเป็น "อินสแตนซ์" ใน SectData.structures [{ uid, type, cell, level, site, acc }] สร้างกี่หลังก็ได้ วางตรงไหนก็ได้บนช่องหญ้า/ดิน (ดู Territory)
## การสร้าง/อัปเกรด: จ่ายวัสดุ -> ไซต์ก่อสร้าง (site) -> ศิษย์ช่วยกันสร้างรายวัน (ProductionSys) จนเสร็จ
## ผลผลิตรายตึก: จับศิษย์เข้าประจำ (POSTS) ตึกผลิตของเข้าคลังให้เอง ไม่ต้องเดินหยิบ (ProductionSys)
## size = ขนาดฐาน (ช่อง) · need_terrain = ต้องมีช่องภูมิประเทศชนิดนี้ติดฐาน (เช่น เหมืองหินติดหิน)

const BUILDINGS = {
	"main_hall": {
		"name": "โถงหลัก", "max_level": 10, "size": Vector2i(3, 3),
		"base_money": 300, "wood": 30, "stone": 30, "materials": {},
		"roof": Color(0.55, 0.12, 0.1), "unique": true,
		"desc": "หัวใจของสำนัก เพิ่มจำนวนศิษย์สูงสุดและขยายอาณาเขต (รายได้รายวัน)",
	},
	"dormitory": {
		"name": "เรือนนอน", "max_level": 5, "size": Vector2i(2, 2),
		"base_money": 120, "wood": 25, "stone": 10, "materials": {},
		"roof": Color(0.35, 0.25, 0.18),
		"desc": "ที่พักของศิษย์ ที่นอนไม่พอศิษย์จะนอนกลางแจ้งและอารมณ์เสีย (สร้างหลายหลังได้) ศิษย์ที่ประจำที่นี่ลดความเครียด",
	},
	"training_ground": {
		"name": "ลานฝึกยุทธ์", "max_level": 5, "size": Vector2i(3, 3),
		"base_money": 150, "wood": 10, "stone": 30, "materials": {},
		"roof": Color(0.6, 0.55, 0.45),
		"desc": "ศิษย์ที่ประจำฝึกวิชาได้ EXP และความชำนาญตามพรสวรรค์ทุกวัน ระดับสูงขึ้น = ได้มากขึ้น",
	},
	"scripture_pavilion": {
		"name": "หอตำรา", "max_level": 5, "size": Vector2i(2, 2),
		"base_money": 400, "wood": 30, "stone": 20, "materials": { "spirit_stone": 2 },
		"roof": Color(0.2, 0.3, 0.5),
		"desc": "ถอดรหัสคัมภีร์ชำรุดเป็นวิชาใหม่ ระดับหอ = ขั้นวิชาสูงสุดที่ถอดรหัสได้ ศิษย์ที่ประจำศึกษาคัมภีร์",
	},
	"alchemy_lab": {
		"name": "หอหลอมโอสถ", "max_level": 5, "size": Vector2i(2, 2),
		"base_money": 350, "wood": 20, "stone": 25, "materials": { "spirit_grass": 10 },
		"roof": Color(0.25, 0.45, 0.25),
		"desc": "ศิษย์ที่ประจำหลอมยาจากหญ้าวิญญาณให้เองทุกวัน ระดับสูงขึ้น = ปลดล็อกสูตรและยาคุณภาพดีขึ้น",
	},
	"forging_pavilion": {
		"name": "โรงหลอมศาสตรา", "max_level": 5, "size": Vector2i(2, 2),
		"base_money": 500, "wood": 15, "stone": 35, "materials": { "iron_ore": 10 },
		"roof": Color(0.3, 0.3, 0.32),
		"desc": "ศิษย์ที่ประจำตีอาวุธ/เกราะจากแร่เหล็กให้เองทุกวัน ระดับสูงขึ้น = ได้ของหายากมากขึ้น",
	},
	"infirmary": {
		"name": "หอแพทย์", "max_level": 5, "size": Vector2i(2, 2),
		"base_money": 250, "wood": 20, "stone": 15, "materials": { "spirit_grass": 5 },
		"roof": Color(0.75, 0.75, 0.7),
		"desc": "หมอที่ประจำรักษาผู้บาดเจ็บ/ป่วยและถอนพิษกู่ ระดับสูงขึ้นรักษาได้เร็วและแม่นขึ้น",
	},
	"sect_formation": {
		"name": "ค่ายกลปกป้องสำนัก", "max_level": 10, "size": Vector2i(2, 2),
		"base_money": 600, "wood": 5, "stone": 40, "materials": { "spirit_stone": 3 },
		"roof": Color(0.6, 0.45, 0.8),
		"desc": "ป้องกันการบุกรุกจากสำนักศัตรูและสัตว์อสูร ศิษย์ที่ประจำค่ายกลเพิ่มพลังป้องกัน",
	},
	"farm": {
		"name": "แปลงเกษตร", "max_level": 5, "size": Vector2i(3, 3),
		"base_money": 80, "wood": 15, "stone": 0, "materials": {},
		"roof": Color(0.4, 0.6, 0.25),
		"desc": "ศิษย์ที่ประจำปลูกข้าวและหญ้าวิญญาณให้ทุกวัน (เสบียงของสำนัก) วางบนช่องหญ้า วัวใกล้ๆ ช่วยให้ผลผลิตดีขึ้น",
	},
	"lumber_camp": {
		"name": "ค่ายตัดไม้", "max_level": 5, "size": Vector2i(2, 2),
		"base_money": 60, "wood": 10, "stone": 5, "materials": {},
		"roof": Color(0.5, 0.35, 0.2),
		"desc": "ศิษย์ที่ประจำตัดไม้และถางป่ารอบค่าย (รัศมี 6+ช่อง) ช่องป่ากลายเป็นหญ้าให้สร้างต่อได้",
	},
	"quarry": {
		"name": "เหมืองหิน", "max_level": 5, "size": Vector2i(2, 2), "need_terrain": 2,
		"base_money": 90, "wood": 15, "stone": 5, "materials": {},
		"roof": Color(0.5, 0.48, 0.45),
		"desc": "ต้องวางติดช่องหิน ศิษย์ที่ประจำขุดหิน (เปิดเหมืองลึก = ได้แร่เหล็ก/เหล็กเย็น/ผลึกวิญญาณ แต่ปลุกสัตว์อสูรใต้ดิน)",
	},
	"kitchen": {
		"name": "โรงครัว", "max_level": 5, "size": Vector2i(2, 2),
		"base_money": 70, "wood": 20, "stone": 10, "materials": {},
		"roof": Color(0.6, 0.35, 0.2),
		"desc": "ศิษย์ที่ประจำทำเสบียงดิบเป็นอาหารปรุงสุก (ฝีมือดี = อาหารชั้นเลิศ ศิษย์อารมณ์ดี)",
	},
	"campfire": {
		"name": "กองไฟ", "max_level": 3, "size": Vector2i(1, 1),
		"base_money": 0, "wood": 5, "stone": 2, "materials": {},
		"roof": Color(1.0, 0.55, 0.2),
		"desc": "ให้แสงสว่างและความอบอุ่น สัตว์เลี้ยง (วัว ไก่) ชอบอยู่ใกล้ สัตว์ป่าเกรงกลัว ระดับสูงขึ้น = รัศมียิ่งกว้าง",
	},
	"watchtower": {
		"name": "หอยาม", "max_level": 5, "size": Vector2i(1, 1),
		"base_money": 150, "wood": 25, "stone": 20, "materials": {},
		"roof": Color(0.45, 0.35, 0.3),
		"desc": "ศิษย์ที่ประจำเฝ้ายามไล่สัตว์ร้ายในรัศมีและเพิ่มพลังป้องกันสำนัก",
	},
	"builders_hut": {
		"name": "ค่ายช่าง", "max_level": 5, "size": Vector2i(2, 2),
		"base_money": 100, "wood": 25, "stone": 10, "materials": {},
		"roof": Color(0.55, 0.45, 0.3),
		"desc": "ศิษย์ที่ประจำช่วยก่อสร้างเร็วขึ้นมาก (ศิษย์ว่างช่วยได้แต่ช้ากว่า)",
	},
}

## ตึกหลักที่ใช้นับความสำเร็จ "สำนักใหญ่โต"
const CORE_TYPES = ["main_hall", "dormitory", "training_ground", "scripture_pavilion", "alchemy_lab", "forging_pavilion", "infirmary", "sect_formation"]

## ตึกที่มอบหมายศิษย์ไปประจำการได้ (Facility Assignment)
## work = ชนิดงาน (ดู ProductionSys), per_level = จำนวนที่นั่งต่อระดับตึก, skill = ทักษะงานที่ใช้คำนวณประสิทธิภาพ
const POSTS = {
	"training_ground": { "work": "train", "per_level": 2, "skill": "martial", "out": "ฝึกวิชา ได้ EXP + ความชำนาญตามพรสวรรค์" },
	"alchemy_lab": { "work": "alchemy", "per_level": 2, "skill": "alchemy", "out": "หลอมยาฟื้นฟู / ชาสงบจิต (ใช้หญ้าวิญญาณ)" },
	"forging_pavilion": { "work": "smith", "per_level": 2, "skill": "crafting", "out": "ตีอาวุธ/เกราะ (ใช้แร่เหล็ก)" },
	"scripture_pavilion": { "work": "research", "per_level": 2, "skill": "intellect", "out": "ศึกษาคัมภีร์ เร่งถอดรหัสวิชา" },
	"infirmary": { "work": "doctor", "per_level": 2, "skill": "medicine", "out": "รักษาผู้บาดเจ็บ/ป่วย" },
	"sect_formation": { "work": "guard", "per_level": 2, "skill": "melee", "out": "ประจำค่ายกล เพิ่มพลังป้องกันตอนถูกบุก" },
	"main_hall": { "work": "warden", "per_level": 1, "skill": "social", "out": "ดูแลและชักชวนนักโทษ งานบริหาร" },
	"farm": { "work": "farm", "per_level": 2, "skill": "plants", "out": "ปลูกข้าว (เสบียง) และหญ้าวิญญาณ" },
	"lumber_camp": { "work": "logging", "per_level": 2, "skill": "plants", "out": "ตัดไม้ ถางป่ารอบค่าย" },
	"quarry": { "work": "mine", "per_level": 2, "skill": "mining", "out": "ขุดหิน (และแร่เมื่อเปิดเหมืองลึก)" },
	"kitchen": { "work": "cook", "per_level": 2, "skill": "cooking", "out": "ทำอาหารปรุงสุกจากเสบียงดิบ" },
	"watchtower": { "work": "guard", "per_level": 1, "skill": "melee", "out": "เฝ้ายาม ไล่สัตว์ร้าย เพิ่มพลังป้องกัน" },
	"builders_hut": { "work": "construct", "per_level": 2, "skill": "construction", "out": "ก่อสร้าง/อัปเกรดตึกเร็วขึ้น" },
}

## ชื่องานที่แสดงเหนือหัวศิษย์ (จาก POSTS[type].work)
const WORK_NAMES = {
	"train": "ฝึกยุทธ์", "alchemy": "หลอมยา", "smith": "ตีอาวุธ", "research": "ศึกษาคัมภีร์", "doctor": "รักษาคนไข้", "guard": "เฝ้ายาม",
	"rest": "พักผ่อน", "farm": "เพาะปลูก", "logging": "ตัดไม้", "mine": "ขุดหิน", "cook": "ทำอาหาร", "construct": "ก่อสร้าง", "warden": "ดูแลนักโทษ",
}

## รหัสอินสแตนซ์ตึกขึ้นต้นด้วย "#" (แยกจากชื่อชนิดตึก)
static func is_uid(key: String) -> bool:
	return key.begins_with("#")

## ชื่อแสดงผลของอินสแตนซ์ เช่น "เรือนนอน #3"
static func inst_name(inst: Dictionary) -> String:
	return "%s %s" % [BUILDINGS[inst.type].name, inst.uid]

## ฐานของอินสแตนซ์ (ช่อง)
static func rect_of(inst: Dictionary) -> Rect2i:
	return Rect2i(inst.cell, BUILDINGS[inst.type].size)

# ── วางตึก (Free-form) ──

## ลองวางตึกชนิด type ที่มุม cell: คืนข้อความผิดพลาด ("" = วางได้) ignore_uid = ข้ามตึกนี้ (ตอนย้าย)
static func can_place(sect: SectData, type: String, cell: Vector2i, ignore_uid := "") -> String:
	var b = BUILDINGS[type]
	if b.get("unique", false) and sect.instances(type).size() > 0 and ignore_uid == "":
		return "มี%sได้เพียงหลังเดียว" % b.name
	var r = Rect2i(cell, b.size)
	var own = rect_of(sect.instance(ignore_uid)) if ignore_uid != "" else Rect2i()
	for x in range(r.position.x, r.end.x):
		for y in range(r.position.y, r.end.y):
			var c = Vector2i(x, y)
			if not Territory.in_bounds(c): return "นอกเขตอาณาเขต"
			var t = Territory.at(sect, c)
			if own.has_point(c) and t == Territory.T.FIELD: continue
			if t != Territory.T.GRASS and t != Territory.T.DIRT:
				return "ต้องวางบนที่โล่ง (ติด%s)" % Territory.NAMES[t]
	for inst in sect.structures:
		if inst.uid != ignore_uid and rect_of(inst).intersects(r):
			return "ทับกับ%s" % inst_name(inst)
	if b.has("need_terrain") and not Territory.touches(sect, r, b.need_terrain):
		return "ต้องวางติดช่อง%s" % Territory.NAMES[b.need_terrain]
	return ""

## ค่าย้ายตึก (ตึกที่ยังไม่เสร็จย้ายฟรี)
static func move_cost(inst: Dictionary) -> int:
	return 40 * int(inst.level)

## ย้ายอินสแตนซ์ไปมุม cell: คืนข้อความผิดพลาด ("" = สำเร็จ) หักค่าย้ายเมื่อเป็นตึกที่สร้างเสร็จแล้ว
static func move_structure(sect: SectData, uid: String, cell: Vector2i) -> String:
	var inst = sect.instance(uid)
	if inst.is_empty(): return "ไม่พบตึก"
	if not inst.site.is_empty(): return "%sกำลังก่อสร้าง ย้ายไม่ได้" % inst_name(inst)
	if cell == inst.cell: return ""
	var err = can_place(sect, inst.type, cell, uid)
	if err != "": return err
	var cost = move_cost(inst)
	if sect.money < cost: return "เงินไม่พอค่าย้ายตึก (%d)" % cost
	sect.money -= cost
	var is_farm = inst.type == "farm"
	if is_farm: paint_ground(sect, inst, Territory.T.GRASS)
	inst.cell = cell
	if is_farm: paint_ground(sect, inst, Territory.T.FIELD)
	return ""

## วางตึกใหม่: จ่ายวัสดุแล้วสร้างไซต์ก่อสร้าง (คืนข้อความผิดพลาด "" = สำเร็จ, uid ผ่าน sect.structures[-1])
static func place_new(sect: SectData, type: String, cell: Vector2i) -> String:
	var err = can_place(sect, type, cell)
	if err != "": return err
	var cost = get_upgrade_cost(type, 0)
	if sect.money < cost.money or not sect.has_materials(cost.materials): return "วัสดุหรือเงินไม่พอ"
	sect.money -= cost.money
	sect.consume_materials(cost.materials)
	var inst = sect.add_structure(type, cell, 0)
	sect.start_construction(inst.uid)
	return ""

## ระบายพื้นภูมิประเทศใต้ฐานตึก (แปลงเกษตร = FIELD, รื้อแล้วกลับเป็นหญ้า)
static func paint_ground(sect: SectData, inst: Dictionary, t: int) -> void:
	var r = rect_of(inst)
	for x in range(r.position.x, r.end.x):
		for y in range(r.position.y, r.end.y):
			Territory.set_at(sect, Vector2i(x, y), t)
	sect.terrain_dirty = true

## รื้อตึก: คืนวัสดุครึ่งหนึ่งของที่ลงทุน ศิษย์ที่ประจำถูกปลด
static func demolish(sect: SectData, uid: String) -> String:
	var inst = sect.instance(uid)
	if inst.is_empty(): return "ไม่พบตึก"
	if BUILDINGS[inst.type].get("unique", false) and inst.type == "main_hall": return "รื้อโถงหลักไม่ได้"
	var refund_money = 0
	var refund_wood = 0
	var refund_stone = 0
	for lv in int(inst.level):
		var c = get_upgrade_cost(inst.type, lv)
		refund_money += c.money / 2
		refund_wood += c.materials.get("wood", 0) / 2
		refund_stone += c.materials.get("stone", 0) / 2
	# ไซต์ที่ยังสร้างไม่เสร็จ (เลเวล 0 หรือกำลังอัปเกรด): คืนทุนเต็มถ้ายังไม่เริ่มลงแรง ไม่งั้นครึ่งหนึ่ง
	var site = inst.get("site", {})
	if int(inst.level) == 0 or not site.is_empty():
		var c0 = get_upgrade_cost(inst.type, int(inst.level))
		var k = 1.0 if float(site.get("work", 0)) <= 0.0 else 0.5
		refund_money += int(c0.money * k)
		refund_wood += int(c0.materials.get("wood", 0) * k)
		refund_stone += int(c0.materials.get("stone", 0) * k)
	sect.money += refund_money
	sect.add_material("wood", refund_wood)
	sect.add_material("stone", refund_stone)
	for d in post_members(sect, uid): d.post = ""
	if inst.type == "farm": paint_ground(sect, inst, Territory.T.GRASS)
	sect.remove_structure(uid)
	return ""

# ── ประจำการ (Facility Assignment) ──

## จำนวนที่นั่ง: key เป็น uid = เฉพาะตึกนั้น, เป็นชื่อชนิด = รวมทุกหลังที่สร้างเสร็จ
static func post_slots(sect: SectData, key: String) -> int:
	if is_uid(key):
		var inst = sect.instance(key)
		if inst.is_empty() or not POSTS.has(inst.type): return 0
		return int(inst.level) * POSTS[inst.type].per_level
	var n = 0
	for inst in sect.instances(key): n += post_slots(sect, inst.uid)
	return n

## ศิษย์ที่ประจำการอยู่ที่ key (uid หรือชนิดตึก)
static func post_members(sect: SectData, key: String) -> Array[DiscipleData]:
	var out: Array[DiscipleData] = []
	for d in sect.get_active_disciples():
		if d.post == "": continue
		if is_uid(key):
			if d.post == key: out.append(d)
		elif post_type(sect, d) == key:
			out.append(d)
	return out

## ชนิดตึกที่ศิษย์ประจำอยู่ ("" = ไม่ได้ประจำ)
static func post_type(sect: SectData, d: DiscipleData) -> String:
	if d.post == "": return ""
	var inst = sect.instance(d.post)
	return "" if inst.is_empty() else inst.type

## uid ของตึกชนิด type หลังแรกที่สร้างเสร็จและยังมีที่นั่งว่าง ("" = ไม่มี)
static func first_open(sect: SectData, type: String) -> String:
	for inst in sect.instances(type):
		if int(inst.level) > 0 and post_members(sect, inst.uid).size() < post_slots(sect, inst.uid): return inst.uid
	return ""

## มอบหมายศิษย์เข้าตึก uid ("" = ยกเลิก) คืนข้อความผิดพลาด ("" = สำเร็จ)
static func assign_post(sect: SectData, d: DiscipleData, uid: String) -> String:
	if uid != "":
		var inst = sect.instance(uid)
		if inst.is_empty() or not POSTS.has(inst.type): return "ตึกนี้ประจำการไม่ได้"
		if int(inst.level) <= 0: return "ยังสร้าง%sไม่เสร็จ" % inst_name(inst)
		if d.post != uid and post_members(sect, uid).size() >= post_slots(sect, uid): return "%sเต็มแล้ว (อัปเกรดเพื่อเพิ่มที่นั่ง)" % inst_name(inst)
	d.post = uid
	ProductionSys.place_one(sect, d)
	return ""

## ตัดคนที่ประจำเกินที่นั่ง / ตึกถูกทำลายออก
static func validate_posts(sect: SectData) -> void:
	for d in sect.get_active_disciples():
		if d.post == "": continue
		var inst = sect.instance(d.post)
		if inst.is_empty() or int(inst.level) <= 0 or not POSTS.has(inst.type): d.post = ""
	for inst in sect.structures:
		if not POSTS.has(inst.type): continue
		var members = post_members(sect, inst.uid)
		var slots = post_slots(sect, inst.uid)
		for i in range(slots, members.size()): members[i].post = ""

## จัดศิษย์ที่ว่างเข้าที่นั่งที่เหลืออัตโนมัติ (ผู้เล่นกดปุ่ม "จัดอัตโนมัติ") ตามความเหมาะกับตึก คืนจำนวนที่จัด
## priority = ลำดับชนิดตึกที่เติมก่อน
const AUTO_PRIORITY = ["farm", "kitchen", "watchtower", "sect_formation", "lumber_camp", "quarry", "builders_hut", "training_ground", "alchemy_lab", "forging_pavilion", "scripture_pavilion", "infirmary"]

static func auto_assign(sect: SectData) -> int:
	var free: Array = sect.get_active_disciples().filter(func(d): return d.post == "" and d.is_available())
	var n = 0
	var pop = sect.get_active_disciples().size()
	for type in AUTO_PRIORITY:
		var budget = _auto_cap(sect, type, pop) - post_members(sect, type).size()
		for inst in sect.instances(type):
			if int(inst.level) <= 0 or budget <= 0 or free.is_empty(): continue
			var open = mini(post_slots(sect, inst.uid) - post_members(sect, inst.uid).size(), budget)
			if open <= 0: continue
			var skill: String = POSTS[type].skill
			free.sort_custom(func(a, b): return _aptitude(a, type, skill) > _aptitude(b, type, skill))
			for i in mini(open, free.size()):
				assign_post(sect, free[0], inst.uid)
				free.remove_at(0)
				n += 1
				budget -= 1
	return n

## จำนวนคนสูงสุดของงานชนิดนี้ที่ "จัดอัตโนมัติ" จะเติมให้ (กันเทศิษย์ทั้งหมดลงฟาร์ม) ผู้เล่นจัดเองเกินนี้ได้
static func _auto_cap(sect: SectData, type: String, pop: int) -> int:
	match type:
		"farm": return maxi(1, ceili(pop / 6.0))
		"kitchen": return maxi(1, ceili(pop / 12.0))
		"lumber_camp": return maxi(1, ceili(pop / 10.0))
		"quarry": return 1
		"builders_hut": return 2 if not sect.construction_sites().is_empty() else 0
		"watchtower", "sect_formation": return maxi(1, ceili(pop / 8.0))
		"infirmary": return maxi(1, ceili(pop / 10.0))
	return 999

static func _aptitude(d: DiscipleData, type: String, skill: String) -> float:
	var s = PawnSys.skill_lv(d, skill) if skill != "" else 5.0
	if type == "training_ground": s += MasterySys.fit(d, MasterySys.train_type(d)) * 5.0
	return s

# ── ระดับความยาก (ส่งผลกับ 4X) ──
## 0 = ง่าย, 1 = ปานกลาง, 2 = นรก, 3 = กำหนดเอง (ใช้ค่าปานกลาง)
const DIFFICULTY = [
	{ "name": "ง่าย", "enemy": 0.8, "invasion": 0.7, "expand_days": 35, "faction_growth": 0.6, "death": 0.0 },
	{ "name": "ปานกลาง", "enemy": 1.0, "invasion": 1.0, "expand_days": 20, "faction_growth": 1.0, "death": 0.1 },
	{ "name": "นรก", "enemy": 1.5, "invasion": 1.4, "expand_days": 10, "faction_growth": 1.6, "death": 0.25 },
	{ "name": "กำหนดเอง", "enemy": 1.0, "invasion": 1.0, "expand_days": 20, "faction_growth": 1.0, "death": 0.1 },
]

static func diff(level: int) -> Dictionary:
	return DIFFICULTY[clampi(level, 0, DIFFICULTY.size() - 1)]

## ค่าใช้จ่ายในการอัปเกรดจาก current_level -> current_level + 1 { money, materials (รวมไม้/หิน) }
static func get_upgrade_cost(id: String, current_level: int) -> Dictionary:
	var b = BUILDINGS[id]
	var mats = { "wood": int(b.wood * (current_level + 1)), "stone": int(b.stone * (current_level + 1)) }
	for m in b.materials:
		mats[m] = int(ceil(b.materials[m] * (current_level + 1)))
	return { "money": int(b.base_money * pow(1.8, current_level)), "materials": mats }

## แรงงานก่อสร้างที่ต้องใช้ (แต้ม) ศิษย์ 1 คนทำได้ราว 10 แต้มต่อวัน
static func get_work_required(current_level: int) -> float:
	return 20.0 * (current_level + 1)

# ── ผลของสิ่งปลูกสร้าง ──

static func get_max_disciples(main_hall_level: int) -> int:
	return 5 + main_hall_level * 3

## รายได้รายวันจากอาณาเขต
static func get_territory_income(main_hall_level: int) -> int:
	return main_hall_level * 15

static func get_territory_size(main_hall_level: int) -> int:
	return main_hall_level * 10

## จำนวนที่นอนรวมทุกเรือนนอน
static func get_beds(sect: SectData) -> int:
	var n = 0
	for inst in sect.instances("dormitory"): n += int(inst.level) * 4
	return n

## สั่งศิษย์เข้านอนพักฟื้นที่เรือนนอน (ฟื้นฟู Rest ทันที 100% + ลดความเครียด)
static func sleep_disciple(sect: SectData, d: DiscipleData) -> String:
	var beds = get_beds(sect)
	var dorm_lv = sect.get_building_level("dormitory")
	if beds <= 0 and dorm_lv <= 0:
		return "สำนักยังไม่มีเรือนนอนหรือที่นอน! กรุณาสร้างเรือนนอนก่อน"
	d.needs.rest = 1.0
	var relief = 35.0 + dorm_lv * 5.0
	StressSystem.relieve(d, relief)
	PawnSys.add_thought(d, sect, "slept_well")
	return "%s เข้าพักผ่อนที่เรือนนอน ฟื้นฟูกำลังเต็ม 100%% และลดความเครียด %.0f%%" % [d.disciple_name, relief]

static func get_meditation_exp(training_level: int) -> int:
	return int(25 * (1.0 + training_level * 0.3))

## พลังป้องกันของค่ายกล (สเกลเดียวกับพลังรบรวมของศิษย์) รวมทุกหลัง
static func get_formation_defense(sect: SectData) -> int:
	var n = 0
	for inst in sect.instances("sect_formation"):
		var lv = int(inst.level)
		n += lv * 25 + lv * lv * 25
	for inst in sect.instances("watchtower"): n += int(inst.level) * 12
	return n

## ความกว้างของโซนไฟพอดีในมินิเกมหลอมโอสถ (0-1)
static func get_alchemy_zone_width(lab_level: int, alchemy_stat: int) -> float:
	return clamp(0.12 + lab_level * 0.025 + alchemy_stat * 0.004, 0.12, 0.4)

## โบนัสสุ่มความหายากตอนหลอมศาสตรา
static func get_forge_rarity_bonus(forge_level: int, forging_stat: int) -> float:
	return forge_level * 0.25 + forging_stat * 0.04

## ถอดรหัสคัมภีร์ชำรุด: เงิน + เศษคัมภีร์ + เวลา
static func get_research_cost(tier: int) -> Dictionary:
	return { "money": int(200 * pow(3, tier - 1)), "fragments": tier * 2, "days": 3 * tier }
