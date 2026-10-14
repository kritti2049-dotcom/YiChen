extends Resource
class_name DiscipleData

## ข้อมูลลูกศิษย์แบบเจาะจงรายบุคคล (Instance เฉพาะตัวเวลาเล่นจริง)
## ลูกศิษย์ = unit ที่มี stat เพิ่มเติมด้าน cultivation, จิตใจ, อุปนิสัย และ AI

# ──────────────────────────────────────────
# 1) Stats — ค่ารากฐาน + ความชำนาญ (ค่าพลังต่อสู้คำนวณจาก StatSys)
# ──────────────────────────────────────────

## (ระบบเก่า) ข้อมูล unit พื้นฐาน ไม่ใช้คำนวณค่าพลังแล้ว เก็บไว้ให้เซฟเก่าโหลดได้
@export var unit_data: UnitData

## ชื่อลูกศิษย์ (แสดงใน UI, แยกจาก unit_name เพราะอาจมีฉายา)
@export var disciple_name: String = "ลูกศิษย์ใหม่"

## ค่ารากฐาน (Base Potential) 28 ค่า อ้างอิงจาก StatSys คนธรรมดา 1-5 (สูงสุด StatSys.POTENTIAL_CAP)
@export var ext_stats: Dictionary = {}
## ความชำนาญอาวุธ { "sword": EXP, "saber": EXP, ... } (ดู MasterySys)
@export var mastery: Dictionary = {}
## รุ่นของระบบค่าพลัง (2 = ระบบ 3 ชั้น: รากฐาน x ขั้นบำเพ็ญ + อุปกรณ์) ใช้แปลงเซฟเก่า
@export var stat_version: int = 0

## นิสัยเชิงลึก 120 แบบ (อ้างอิงจาก TraitDB)
@export var ext_traits: Array[String] = []

## ที่มาของค่าสเตตัสแต่ละตัว (Transparent RNG)
## { "stat_key": [ { "src": "พื้นฐานสุ่ม (10-14)", "val": 12 }, ... ] }
@export var stat_sources: Dictionary = {}

# ──────────────────────────────────────────
# 1.5) Biography — ข้อมูลส่วนตัว
# ──────────────────────────────────────────

@export_enum("ชาย", "หญิง") var gender: String = ""
## เผ่าพันธุ์ (ดู BackgroundDB.RACES)
@export var race: String = ""
## เลขสุ่มสำหรับสร้างรูปหน้าตา (ArtGen)
@export var portrait_seed: int = 0
@export_multiline var background_story: String = ""
## วิชาที่ติดตัวมาตั้งแต่ก่อนเข้าสำนัก
@export var innate_skills: Array[String] = []
## หน้าตาที่ผู้เล่นปรับเอง (ทับค่าที่สุ่มจาก portrait_seed)
## { "hair_style": int, "hair_color": int, "skin": int, "robe": int }
@export var appearance: Dictionary = {}
## เป็นเจ้าสำนัก (ตัวละครของผู้เล่น)
@export var is_founder: bool = false

# ──────────────────────────────────────────
# 1.6) Jianghu — ชื่อเสียง ฉายา ความแค้น
# ──────────────────────────────────────────

## ชื่อเสียงในยุทธภพ (ใช้จัดอันดับทำเนียบยุทธภพ)
@export var fame: int = 0
## ฉายาในยุทธภพ เช่น "จอมดาบหิมะ"
@export var title: String = ""
## สำนักที่ศิษย์ผูกใจเจ็บ (faction_id) "" = ไม่มี
@export var feud_target: String = ""
## ความแค้นสะสม 0-100 ยิ่งมากยิ่งมีโอกาสแอบหนีไปล้างแค้น
@export var feud_intensity: int = 0
## ชื่อผู้ที่ศิษย์จะล้างแค้นให้
@export var feud_for: String = ""
## สาเหตุการตาย/จากไป
@export var death_cause: String = ""

# ──────────────────────────────────────────
# 2) Cultivation — ระบบปลูกฝังพลังภายในและวิชา
# ──────────────────────────────────────────

@export var aptitude_root: int = 10
@export var comprehension: int = 10
@export var internal_energy_max: int = 50
@export_enum("sword", "palm", "poison", "internal", "formation", "hidden_weapon") var affinity_style: String = "sword"
## ธาตุของรากวิญญาณ (กำหนดสีออร่าปราณ)
@export_enum("ไฟ", "น้ำ", "ไม้", "ทอง", "ดิน", "สายฟ้า") var element: String = ""
## อายุ (ปี) เพิ่มขึ้นทุก CultivationSys.DAYS_PER_YEAR วัน
@export var age: int = 0

## ข้อมูลอาจารย์ (ถ้ามี)
@export var master: DiscipleData
## รายชื่อวิชาที่เรียนรู้แล้ว (ใส่ชื่อวิชาเป็น String ไปก่อน)
@export var learned_skills: Array[String] = []
## วิชาที่เจ้าสำนักมอบหมายให้ศึกษา (จากหอตำรา) และความคืบหน้า 0-100
@export var study_skill: String = ""
## ปักหมุด (กดหัวใจ) ให้แสดงในแผงด้านขวาของหน้าสำนัก
@export var favorite: bool = false
@export var study_progress: float = 0.0
## วันล่าสุดที่ตรัสรู้วิชาเอง (คูลดาวน์ SkillQuestSys.INSIGHT_COOLDOWN)
@export var last_insight_day: int = -999

# ──────────────────────────────────────────
# 2.5) Equipment - ของสวมใส่
# ──────────────────────────────────────────
@export var equipped_weapon: EquipmentData
@export var equipped_armor: EquipmentData
@export var equipped_accessory: EquipmentData
@export var equipped_artifact: EquipmentData

# ──────────────────────────────────────────
# 3) Survival & Status
# ──────────────────────────────────────────

## ความหิว (เต็ม 100 ยิ่งน้อยยิ่งแย่ ถ้าหิวมากอารมณ์จะเสียและอาจหนี)
@export var hunger: int = 100

enum DiscipleStatus {
	IDLE,       ## ว่างอยู่ในสำนัก (AI จะหาอะไรทำเอง)
	TRAINING,   ## กำลังฝึกวิชา
	MISSION,    ## ออกไปทำภารกิจ / หาของ (EXPLORING)
	INJURED,    ## บาดเจ็บ พักรักษาตัว
	DEPARTED    ## ออกจากสำนักแล้ว (หนี/ถูกไล่/ตาย)
}
## สถานะกิจกรรมปัจจุบัน
@export var status: DiscipleStatus = DiscipleStatus.IDLE
## จำนวนวันพักฟื้นที่เหลือ (ใช้คู่กับสถานะ INJURED)
@export var injury_days: int = 0
## งานที่มอบหมายยามเช้า (ดู BuildingDB.JOBS) "" = อิสระ
@export var job: String = ""
## อาการบาดเจ็บ/พิษที่ต้องให้หมอรักษา [{ "id": ailment_id, "days": จำนวนวันที่เป็นมา }]
@export var ailments: Array[Dictionary] = []
## พิการถาวร (เส้นชีพจรขาดโดยไม่ได้รับการรักษา) พลังต่อสู้ลดครึ่ง
@export var disabled: bool = false

# ──────────────────────────────────────────
# 3.5) Expedition — การเดินทางบนแผนที่โลก (ใช้คู่กับสถานะ MISSION)
# ──────────────────────────────────────────

## ประเภทภารกิจ: "gather" (เก็บวัตถุดิบ), "station" (ไปประจำที่เมือง), "secret_realm" (บุกแดนลับ)
@export var mission_type: String = ""
## ช่วงของภารกิจ: "going", "working", "stationed", "returning"
@export var mission_phase: String = ""
## โหนดเป้าหมายบนแผนที่ (WorldDB)
@export var mission_target: String = ""
@export var mission_days_left: int = 0
@export var mission_total_days: int = 0
## ของที่ศิษย์แบกกลับมา { "material_id": จำนวน }
@export var carried_materials: Dictionary = {}
@export var carried_equipment: Array[EquipmentData] = []
@export var carried_skills: Array[String] = []

# ──────────────────────────────────────────
# 4) Romance & Relationship (Player & NPCs)
# ──────────────────────────────────────────

## ความประทับใจต่อตัวผู้เล่น
@export var affection: int = 0
## สถานะความสัมพันธ์กับผู้เล่น (เช่น NONE, FRIEND, DATING, MARRIED)
@export var romance_status: String = "NONE"

## ความสัมพันธ์ระหว่างลูกศิษย์ด้วยกันเอง
## Key = disciple_id (String), Value = Dictionary { "affinity": float, "type": String }
## type เช่น "เพื่อน", "คู่แข่ง", "คู่รัก", "ศัตรู"
@export var relationships: Dictionary = {}

# ──────────────────────────────────────────
# 5) Personality, AI & Living World
# ──────────────────────────────────────────

## ลักษณะนิสัยที่เป็นตัวถ่วงน้ำหนักในการตัดสินใจของ AI
## (เช่น "ขยัน", "เกียจคร้าน", "ทะเยอทะยาน", "ขี้อิจฉา", "ซื่อสัตย์")
@export var personality_traits: Array[String] = []

## ความทะเยอทะยาน / เป้าหมายระยะยาว
## เช่น "อยากเป็นผู้อาวุโส", "อยากแยกไปตั้งสำนักเอง", "ไม่มีเป้าหมายพิเศษ"
@export var ambition: String = "ไม่มีเป้าหมายพิเศษ"

## ความภักดีต่อสำนัก (0-100) ลดลงถ้าถูกปฏิบัติไม่ดี ส่งผลต่อโอกาสทรยศ
@export_range(0, 100) var loyalty: float = 100.0

## อารมณ์/ความเครียดปัจจุบัน (0-100) ผลจากเหตุการณ์ล่าสุด ส่งผลต่อ productivity
@export_range(0, 100) var mood: float = 100.0

## สภาพจิต (0-100) ต้านทานการตกมาร/ถูกล่อลวง
@export_range(0, 100) var mentality: int = 50

## บันทึกความจำ/เหตุการณ์สำคัญที่ตัวละครเกี่ยวข้อง
## (เก็บล่าสุด 20 รายการ) [{ "day": int, "text": String }]
@export var memory_log: Array[Dictionary] = []

# ──────────────────────────────────────────
# 6) Growth (ระบบเติบโตและระดับขั้นพลัง)
# ──────────────────────────────────────────

enum GrowthCurve { EARLY_BLOOMER, STEADY, LATE_BLOOMER }
enum TalentTier { COMMON, RARE, LEGENDARY }

@export var growth_curve: GrowthCurve = GrowthCurve.STEADY
@export var talent_tier: TalentTier = TalentTier.COMMON
@export var experience: int = 0

## ระดับขั้นพลัง
@export var level: int = 1
## ชื่อระดับพลัง (เช่น รวบรวมลมปราณ ขั้น 1)
@export var realm_name: String = "รวบรวมลมปราณ ขั้น 1"

## โบนัสค่าพลังคงที่จากบัฟพิเศษ (ระบบเก่าเก็บค่าจากการอัปเลเวลไว้ที่นี่ ตอนนี้ขั้นบำเพ็ญเป็นตัวคูณแทน)
@export var bonus_max_hp: int = 0
@export var bonus_attack: int = 0
@export var bonus_defense: int = 0
@export var bonus_speed: int = 0

# ──────────────────────────────────────────
# 7) Sim Components (ข้อมูลล้วน — ตรรกะอยู่ใน system/sim/*_system.gd)
# ──────────────────────────────────────────
@export_group("Sim Components")
## รุ่นของ component (0 = เซฟเก่า ยังไม่ได้ตั้งค่า)
@export var comp_version: int = 0
## Needs: ความต้องการ 0..1 { "food", "rest", "qi", "joy" }
@export var needs: Dictionary = {}
## Mood: ความคิดที่มีผลต่ออารมณ์ [{ "id", "value", "until" (tick, -1 = ตามสถานการณ์), "src" }] (mood = อารมณ์ปัจจุบัน)
@export var thoughts: Array[Dictionary] = []
@export var mood_target: float = 50.0
## Skills: ทักษะงาน { skill: { "lv": 0..20, "xp": float, "passion": 0..2 } }
@export var skills: Dictionary = {}
## Traits: ลักษณะนิสัยด้านพฤติกรรม (BehaviorTraitDB)
@export var btraits: Array[String] = []
## WorkPriorities: { work_id: 0 (ปิด) / 1..4 } และตารางเวลา 3 ช่วง (WorkDB.SCHEDULES)
@export var work_priorities: Dictionary = {}
@export var schedule: Array[String] = []
## TaskState: งานปัจจุบัน { work, steps: [...], step, ticks, target, desc }
@export var task: Dictionary = {}
## Position: พิกัดบนลานสำนัก (ตาราง isometric)
@export var pos: Vector2 = Vector2(48.5, 52.0)
## เด็ก (เกิดในสำนัก) ทำงานไม่ได้จนกว่าจะโต
@export var is_child: bool = false
@export var grow_day: int = 0
@export var spouse: String = ""
@export var lover: String = ""
## การติดชาสงบจิต 0..1
@export var tea_addiction: float = 0.0
## จำนวน tick ที่ว่างงานในช่วงทำงาน (แจ้งเตือนผู้เล่น)
@export var idle_ticks: int = 0
## ประจำการ: id อาคารที่ศิษย์ถูกมอบหมายไปประจำ ("" = ไม่ได้มอบหมาย ใช้ตารางงานเดิม) ดู BuildingDB.POSTS
@export var post: String = ""
## ความเครียด 0..100 (ถึง 100 = ธาตุไฟแตกซ่าน ดู StressSystem)
@export var stress: float = 0.0
## วันที่สเตตัสลดชั่วคราวจากธาตุไฟแตกซ่านหมดฤทธิ์ (0 = ไม่มี)
@export var debuff_until: int = 0
## วิชา/สายที่ตั้งใจฝึก ("" = เลือกสายที่เหมาะที่สุดอัตโนมัติ)
@export var train_focus: String = ""

# ══════════════════════════════════════════
# Helper Functions
# ══════════════════════════════════════════

## เติมค่าเริ่มต้นให้ข้อมูลจากเซฟรุ่นเก่า
func ensure_defaults() -> void:
	if element == "":
		element = CultivationSys.ELEMENT_COLORS.keys().pick_random()
	if age <= 0:
		age = randi_range(14, 25)
	if gender == "":
		gender = ["ชาย", "หญิง"].pick_random()
	if race == "":
		race = "มนุษย์"
	if portrait_seed == 0:
		portrait_seed = randi() % 1000000 + 1
	if background_story == "":
		background_story = BackgroundDB.generate_story(race)
	if stat_version < 2:
		_migrate_layered_stats()
	for eq in get_equipped_items() + carried_equipment: eq.migrate()
	for s in innate_skills:
		MasterySys.grant_background(self, s)
	PawnSys.ensure(self, null)

## แปลงเซฟเก่า (ค่าดิบ 10-30) เป็นค่ารากฐาน 1-10 และย้ายทักษะอาวุธไปเป็นความชำนาญ
func _migrate_layered_stats() -> void:
	var legacy_mastery = { "sword_arts": ["sword", "saber"], "unarmed_arts": ["fist"], "ranged_arts": ["hidden"] }
	for key in legacy_mastery:
		if ext_stats.has(key):
			for t in legacy_mastery[key]:
				mastery[t] = max(int(mastery.get(t, 0)), max(0, int(ext_stats[key]) - 10) * 3)
			ext_stats.erase(key)
			stat_sources.erase(key)
	for key in StatSys.STATS_DEF:
		var old = int(ext_stats.get(key, 12))
		ext_stats[key] = StatSys.clamp_potential(int(round(old / 4.0)))
		stat_sources[key] = [{ "src": "แปลงจากระบบค่าพลังเก่า (%d)" % old, "val": ext_stats[key] }]
	# ขั้นบำเพ็ญกลายเป็นตัวคูณ จึงล้างโบนัสคงที่ที่สะสมจากการอัปเลเวลแบบเก่า
	bonus_max_hp = 0
	bonus_attack = 0
	bonus_defense = 0
	bonus_speed = 0
	comprehension = get_stat("comprehension")
	aptitude_root = get_stat("aptitude")
	stat_version = 2

## ค่ารากฐาน (ชั้นที่ 1) ของสเตตัส
func get_stat(key: String) -> int:
	return ext_stats.get(key, 3)

## เพิ่ม/ลดค่ารากฐาน พร้อมบันทึกที่มา (ใช้แทนการแก้ ext_stats ตรงๆ)
func add_stat(key: String, amount: int, source: String) -> void:
	if amount == 0: return
	ext_stats[key] = StatSys.clamp_potential(ext_stats.get(key, 0) + amount)
	if not stat_sources.has(key):
		stat_sources[key] = []
	stat_sources[key].append({ "src": source, "val": amount })

## รายการที่มาของสเตตัส ถ้าผลรวมไม่ตรงกับค่าปัจจุบัน (เซฟเก่า/ถูกจำกัดขั้นต่ำ) จะเติมรายการปรับส่วนต่าง
func get_stat_breakdown(key: String) -> Array:
	var result: Array = stat_sources.get(key, []).duplicate()
	var total = 0
	for s in result: total += s.val
	var diff = ext_stats.get(key, 0) - total
	if diff != 0:
		result.append({ "src": "ไม่มีบันทึกที่มา (ข้อมูลเก่า/ปรับขั้นต่ำ)", "val": diff })
	return result

## ชื่อสถานะเป็นภาษาไทย
func get_status_text() -> String:
	var extra = ""
	for a in ailments:
		extra += " [%s]" % AilmentDB.get_ailment(a.id).get("name", a.id)
	if disabled: extra += " [พิการ]"
	return _base_status_text() + extra

func _base_status_text() -> String:
	match status:
		DiscipleStatus.IDLE, DiscipleStatus.TRAINING: return SectView.activity_text(self)
		DiscipleStatus.INJURED: return "บาดเจ็บ (พัก %d วัน) · %s" % [injury_days, SectView.activity_text(self)]
		DiscipleStatus.DEPARTED: return "ออกจากสำนักแล้ว"
		DiscipleStatus.MISSION:
			var target = WorldDB.get_node_data(mission_target).get("name", "?")
			match mission_phase:
				"going": return "เดินทางไป%s (อีก %d วัน)" % [target, mission_days_left]
				"working": return "เก็บวัตถุดิบที่%s (อีก %d วัน)" % [target, mission_days_left]
				"stationed": return "ประจำอยู่ที่%s" % target
				"returning": return "เดินทางกลับสำนัก (อีก %d วัน)" % mission_days_left
			if mission_type == "revenge":
				return "แอบหนีไปล้างแค้นที่%s" % target
			return "ทำภารกิจ"
	return "ว่าง"

## ศิษย์อยู่ในสำนักและพร้อมรับคำสั่ง (สติแตก/เด็ก = สั่งไม่ได้)
func is_available() -> bool:
	return (status == DiscipleStatus.IDLE or status == DiscipleStatus.TRAINING) and not is_child

## พร้อมออกรบ (พิการ/หมดสติ แล้วออกรบไม่ได้)
func can_fight() -> bool:
	return is_available() and not disabled

func has_ailment(id: String) -> bool:
	for a in ailments:
		if a.id == id: return true
	return false

func add_ailment(id: String) -> void:
	if not has_ailment(id):
		ailments.append({ "id": id, "days": 0 })

func remove_ailment(id: String) -> void:
	for i in range(ailments.size() - 1, -1, -1):
		if ailments[i].id == id: ailments.remove_at(i)

func add_fame(amount: int) -> void:
	fame += amount
	if title == "" and fame >= 100:
		title = FactionSys.generate_title(self)

## ชื่อพร้อมฉายา เช่น "หลินเฟิง 'จอมดาบหิมะ'"
func get_display_name() -> String:
	return disciple_name if title == "" else "%s '%s'" % [disciple_name, title]

## ชื่อสายพรสวรรค์ (ใช้แสดงผล)
func affinity_style_name() -> String:
	return SkillDB.TYPE_NAMES.get(affinity_style, affinity_style)

## ความจุวิชาสูงสุดตามค่าความจำ
func get_max_skills() -> int:
	return 2 + int(get_stat("memory") / 2.0)

# ── ค่าพลังในการต่อสู้: รากฐาน x ตัวคูณขั้นบำเพ็ญ + อุปกรณ์/บัฟ (ดู StatSys) ──

## ตัวคูณขั้นบำเพ็ญปัจจุบัน (ชั้นที่ 2)
func get_realm_multiplier() -> float:
	return RealmDB.multiplier(level)

## ค่าพลังต่อสู้แยก 3 ชั้น { "hp": {base, mult, gear, total}, "atk", "def", "spd" }
func get_combat_breakdown() -> Dictionary:
	var gear = {
		"hp": get_equipment_bonus("hp") + bonus_max_hp, "atk": get_equipment_bonus("atk") + bonus_attack,
		"def": get_equipment_bonus("def") + bonus_defense, "spd": get_equipment_bonus("spd") + bonus_speed,
	}
	var c = StatSys.derive_combat(ext_stats, get_realm_multiplier(), gear)
	# ธาตุไฟแตกซ่าน: พลังลดชั่วคราว
	if StressSystem.is_deranged(self):
		for k in c:
			c[k]["stress"] = StressSystem.DEBUFF_MULT
			c[k].total = max(1, int(c[k].total * StressSystem.DEBUFF_MULT))
	return c

func _cripple(v: int) -> int:
	return max(1, int(v * 0.5)) if disabled else v

func get_combat_max_hp() -> int:
	return _cripple(get_combat_breakdown().hp.total)

func get_combat_attack() -> int:
	return _cripple(get_combat_breakdown().atk.total)

func get_combat_defense() -> int:
	return _cripple(get_combat_breakdown().def.total)

func get_combat_speed() -> int:
	return _cripple(get_combat_breakdown().spd.total)

## วิชาโจมตีที่ให้โบนัสพลังรบสูงสุด (โบนัสวิชา x ระดับความชำนาญ) "" = ไม่มี
func get_best_attack_skill() -> String:
	var best = ""
	var best_score = 0.0
	for s in learned_skills:
		var info = SkillDB.get_skill(s)
		if info.is_empty() or info.type == "movement" or info.power <= 0: continue
		var score = StatSys.skill_bonus(info.power) * max(1, MasterySys.skill_level(self, s)) * MasterySys.fit_skill(self, s)
		if score > best_score:
			best_score = score
			best = s
	return best

## พลังรบรวม = (พลังโจมตี x2) + (HP / 5) + (ความเร็ว x1.5) + (โบนัสวิชา x ระดับความชำนาญ)
func get_power_rating() -> int:
	var skill = get_best_attack_skill()
	var bonus = StatSys.skill_bonus(SkillDB.get_skill(skill).power) * MasterySys.fit_skill(self, skill) if skill != "" else 0.0
	var lv = MasterySys.skill_level(self, skill) if skill != "" else 0
	return StatSys.combat_power(get_combat_attack(), get_combat_max_hp(), get_combat_speed(), bonus, lv)

# ── อุปกรณ์สวมใส่ ──

func get_equipped_items() -> Array[EquipmentData]:
	var result: Array[EquipmentData] = []
	for eq in [equipped_weapon, equipped_armor, equipped_accessory, equipped_artifact]:
		if eq != null: result.append(eq)
	return result

func get_equipment_bonus(stat: String) -> int:
	var total = 0
	for eq in get_equipped_items():
		total += eq.get("bonus_" + stat)
	return total

## รายการสกิลติดตัวจากของวิเศษ (id จาก EquipmentDB.PASSIVES)
func get_passives() -> Array[String]:
	var result: Array[String] = []
	for eq in get_equipped_items():
		if eq.passive_skill != "": result.append(eq.passive_skill)
	return result

func get_equipped(type: EquipmentData.EquipType) -> EquipmentData:
	match type:
		EquipmentData.EquipType.WEAPON: return equipped_weapon
		EquipmentData.EquipType.ARMOR: return equipped_armor
		EquipmentData.EquipType.ACCESSORY: return equipped_accessory
	return equipped_artifact

## สวมใส่อุปกรณ์ คืนค่าชิ้นเก่าที่ถอดออก (หรือ null)
func equip(eq: EquipmentData) -> EquipmentData:
	var old = get_equipped(eq.type)
	_set_slot(eq.type, eq)
	return old

func unequip(type: EquipmentData.EquipType) -> EquipmentData:
	var old = get_equipped(type)
	_set_slot(type, null)
	return old

func _set_slot(type: EquipmentData.EquipType, eq: EquipmentData) -> void:
	match type:
		EquipmentData.EquipType.WEAPON: equipped_weapon = eq
		EquipmentData.EquipType.ARMOR: equipped_armor = eq
		EquipmentData.EquipType.ACCESSORY: equipped_accessory = eq
		EquipmentData.EquipType.ARTIFACT: equipped_artifact = eq

## ตรวจสอบว่ามีนิสัยที่ระบุหรือไม่
func has_trait(trait_name: String) -> bool:
	return personality_traits.has(trait_name)

## ฟังก์ชันช่วยเหลือสำหรับบันทึกความจำ
func add_memory(day: int, text: String) -> void:
	memory_log.append({ "day": day, "text": text })
	if memory_log.size() > 20:
		memory_log.pop_front()

## ดึงค่า multiplier ตาม talent_tier
func get_talent_multiplier() -> float:
	match talent_tier:
		TalentTier.COMMON: return 1.0
		TalentTier.RARE: return 1.5
		TalentTier.LEGENDARY: return 2.0
	return 1.0

## รับ EXP และเช็คอัปเลเวล
func gain_experience(amount: int, current_day: int = 0) -> void:
	var info = CultivationSys.get_realm_info(level)
	var required_exp = CultivationSys.get_required_exp(level)
	
	if info.is_bottleneck and experience >= required_exp:
		# ติดคอขวดขั้นใหญ่ ไม่สามารถรับ EXP เพิ่มได้จนกว่าจะทะลวง
		return
		
	var exp_multiplier = 1.0 + get_stat("comprehension") * 0.1
	experience += int(amount * exp_multiplier)
	
	# ถ้าไม่ใช่คอขวดขั้นใหญ่ และ EXP พอ ให้อัปเลเวลอัตโนมัติ
	if experience >= required_exp and not info.is_bottleneck:
		level_up(current_day)

## ผู้เล่นสั่งทะลวงคอขวดขั้นใหญ่
func attempt_breakthrough(pill_bonus: float = 0.0, current_day: int = 0) -> bool:
	var required_exp = CultivationSys.get_required_exp(level)
	if experience < required_exp:
		return false
		
	var chance = CultivationSys.get_breakthrough_chance(level, get_stat("aptitude"), pill_bonus)
	var success = (randf() * 100.0) <= chance
	
	if success:
		level_up(current_day)
		add_memory(current_day, "ทะลวงคอขวดสำเร็จ! ก้าวสู่ขั้น " + realm_name)
		return true
	else:
		# ทะลวงพลาด (ธาตุไฟแตกซ่านเบาๆ) เสีย EXP 20%
		experience = int(experience * 0.8)
		mood = max(0, mood - 30)
		add_memory(current_day, "ทะลวงคอขวดล้มเหลว ลมปราณตีกลับ")
		return false

## ทะลวงคอขวดสำเร็จจากมินิเกม (ไม่ต้องสุ่ม)
func complete_breakthrough(current_day: int = 0) -> void:
	level_up(current_day)
	add_memory(current_day, "ทะลวงคอขวดสำเร็จ! ก้าวสู่ขั้น " + realm_name)

## ธาตุไฟแตกซ่าน (ทะลวงคอขวดล้มเหลวอย่างรุนแรง) คืนค่าข้อความอธิบายผลที่เกิดขึ้น
func suffer_qi_deviation(current_day: int = 0) -> String:
	var result = ""
	match randi() % 3:
		0:
			experience = int(experience * 0.6)
			result = "ลมปราณตีกลับ เสีย EXP 40%"
		1:
			var keys = StatSys.STATS_DEF.keys()
			keys.shuffle()
			var lost: Array[String] = []
			for k in keys.slice(0, 3):
				add_stat(k, -1, "ธาตุไฟแตกซ่าน (วันที่ %d)" % current_day)
				lost.append("%s -1" % StatSys.STATS_DEF[k].name)
			result = "เส้นลมปราณเสียหาย สเตตัสลดลงถาวร (%s)" % ", ".join(lost)
		2:
			status = DiscipleStatus.INJURED
			injury_days = randi_range(5, 10)
			experience = int(experience * 0.8)
			result = "บาดเจ็บสาหัส ต้องพักฟื้น %d วัน" % injury_days
	mood = max(0, mood - 40)
	add_memory(current_day, "ธาตุไฟแตกซ่าน: " + result)
	return result

## ฟังก์ชันอัปเลเวล (ใช้ภายใน)
func level_up(current_day: int = 0) -> void:
	var required_exp = CultivationSys.get_required_exp(level)
	experience -= required_exp
	level += 1
	
	# อัปเดตชื่อขั้นพลัง ค่าพลังต่อสู้เพิ่มขึ้นเองตามตัวคูณของขั้นใหม่ (RealmDB)
	var info = CultivationSys.get_realm_info(level)
	realm_name = info.name

	# ก้าวสู่ขั้นใหญ่ใหม่: ชื่อเสียง + ความสำเร็จในหอเกียรติยศ
	if info.minor_index == 1 and info.major_index >= 2:
		add_fame(10 * info.major_index)
		ArchiveSys.unlock_achievement("first_breakthrough")
		if info.major_index >= 3: ArchiveSys.unlock_achievement("golden_core")
		if info.major_index >= 4: ArchiveSys.unlock_achievement("nascent_soul")

	print("=> [ทะลวงพลัง] %s เลื่อนระดับเป็น %s (ตัวคูณ x%.2f)" % [disciple_name, realm_name, get_realm_multiplier()])
