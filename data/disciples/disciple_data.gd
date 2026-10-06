extends Resource
class_name DiscipleData

## ข้อมูลลูกศิษย์แบบเจาะจงรายบุคคล (Instance เฉพาะตัวเวลาเล่นจริง)
## ลูกศิษย์ = unit ที่มี stat เพิ่มเติมด้าน cultivation, จิตใจ, อุปนิสัย และ AI

# ──────────────────────────────────────────
# 1) Combat — เชื่อมโยงกับ UnitData
# ──────────────────────────────────────────

## ข้อมูล unit พื้นฐาน (hp, atk, def, speed ฯลฯ)
@export var unit_data: UnitData

## ชื่อลูกศิษย์ (แสดงใน UI, แยกจาก unit_name เพราะอาจมีฉายา)
@export var disciple_name: String = "ลูกศิษย์ใหม่"

# ──────────────────────────────────────────
# 2) Cultivation — ระบบปลูกฝังพลังภายในและวิชา
# ──────────────────────────────────────────

@export var aptitude_root: int = 10
@export var comprehension: int = 10
@export var internal_energy_max: int = 50
@export_enum("sword", "palm", "poison", "internal", "formation", "hidden_weapon") var affinity_style: String = "sword"

## ข้อมูลอาจารย์ (ถ้ามี)
@export var master: DiscipleData
## รายชื่อวิชาที่เรียนรู้แล้ว (ใส่ชื่อวิชาเป็น String ไปก่อน)
@export var learned_skills: Array[String] = []

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

## Bonus Stats ที่ได้จากการอัปเลเวลหรือฝึกวิชา
@export var bonus_max_hp: int = 0
@export var bonus_attack: int = 0
@export var bonus_defense: int = 0
@export var bonus_speed: int = 0

# ══════════════════════════════════════════
# Helper Functions
# ══════════════════════════════════════════

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

## คำนวณ effective stat ทั่วไป
func get_effective_stat(stat_name: String) -> int:
	var base_value = get(stat_name)
	if base_value == null:
		push_warning("DiscipleData: ไม่พบ stat ชื่อ '%s'" % stat_name)
		return 0
	if base_value is int:
		return int(base_value * get_talent_multiplier())
	return base_value

## คำนวณ Combat Stat รวม (Base + Bonus + Equipment)
func get_combat_stat(stat_name: String) -> int:
	var base_val = 0
	if unit_data != null and stat_name in unit_data:
		base_val = unit_data.get(stat_name)
	
	var bonus_val = 0
	var bonus_name = "bonus_" + stat_name
	if bonus_name in self:
		bonus_val = get(bonus_name)
		
	var equip_bonus = 0
	var equips = [equipped_weapon, equipped_armor, equipped_accessory, equipped_artifact]
	for eq in equips:
		if eq != null:
			if stat_name == "max_hp": equip_bonus += eq.bonus_hp
			elif stat_name == "attack": equip_bonus += eq.bonus_atk
			elif stat_name == "defense": equip_bonus += eq.bonus_def
			elif stat_name == "speed": equip_bonus += eq.bonus_spd
		
	return int((base_val + bonus_val + equip_bonus) * get_talent_multiplier())

## รับ EXP และเช็คอัปเลเวล
func gain_experience(amount: int, current_day: int = 0) -> void:
	var info = CultivationSys.get_realm_info(level)
	var required_exp = CultivationSys.get_required_exp(level)
	
	if info.is_bottleneck and experience >= required_exp:
		# ติดคอขวดขั้นใหญ่ ไม่สามารถรับ EXP เพิ่มได้จนกว่าจะทะลวง
		return
		
	var exp_multiplier = 1.0 + (comprehension / 100.0)
	experience += int(amount * exp_multiplier)
	
	# ถ้าไม่ใช่คอขวดขั้นใหญ่ และ EXP พอ ให้อัปเลเวลอัตโนมัติ
	if experience >= required_exp and not info.is_bottleneck:
		level_up(current_day)

## ผู้เล่นสั่งทะลวงคอขวดขั้นใหญ่
func attempt_breakthrough(pill_bonus: float = 0.0, current_day: int = 0) -> bool:
	var required_exp = CultivationSys.get_required_exp(level)
	if experience < required_exp:
		return false
		
	var chance = CultivationSys.get_breakthrough_chance(level, aptitude_root, pill_bonus)
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

## ฟังก์ชันอัปเลเวล (ใช้ภายใน)
func level_up(current_day: int = 0) -> void:
	var required_exp = CultivationSys.get_required_exp(level)
	experience -= required_exp
	level += 1
	
	# อัปเดตชื่อขั้นพลังจากระบบ CultivationSys
	var info = CultivationSys.get_realm_info(level)
	realm_name = info.name
	
	# เพิ่มโบนัส stats ทวีคูณตาม Major Realm
	var major_mult = max(1, info.major_index)
	var stat_gain_multiplier = get_talent_multiplier() * (1.0 + (aptitude_root / 100.0)) * major_mult
	var add_hp = int(10 * stat_gain_multiplier)
	var add_atk = int(2 * stat_gain_multiplier)
	
	bonus_max_hp += add_hp
	bonus_attack += add_atk
	bonus_defense += int(1 * stat_gain_multiplier)
	bonus_speed += int(1 * stat_gain_multiplier)
	
	print("=> [ทะลวงพลัง] %s เลื่อนระดับเป็น %s (HP+%d, ATK+%d)" % [disciple_name, realm_name, add_hp, add_atk])
