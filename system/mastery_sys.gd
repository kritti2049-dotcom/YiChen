extends RefCounted
class_name MasterySys

## ระบบความชำนาญอาวุธ (Weapon Proficiency) แยกออกจากสเตตัสรวม เก็บเป็น EXP ต่อสายใน DiscipleData.mastery
## - ทุกคนเริ่มที่ 0 (วิชาที่ติดตัวมาก่อนเข้าสำนักให้โบนัสภูมิหลัง +10)
## - ยิ่งใช้วิชาสายนั้นในการต่อสู้ / โจมตีด้วยอาวุธสายนั้น / ศึกษาคัมภีร์สายนั้น ยิ่งชำนาญ
## - ระดับความชำนาญ = floor(sqrt(EXP / 10)) สูงสุด 10
## - ความชำนาญไม่ถึงเกณฑ์จะเรียนวิชาขั้นสูงไม่ได้ (ปฐพี 2, นภา 4, เซียน 6, เทวะ 9)
## - ระดับความชำนาญเป็นตัวคูณโบนัสวิชาในสูตรพลังรบรวม (StatSys.combat_power)

const TYPES = {
	"saber": { "name": "ดาบ", "color": Color(0.9, 0.55, 0.35) },
	"sword": { "name": "กระบี่", "color": Color(0.6, 0.85, 1.0) },
	"spear": { "name": "ทวน", "color": Color(0.95, 0.8, 0.4) },
	"fist": { "name": "หมัด/ฝ่ามือ", "color": Color(0.95, 0.5, 0.45) },
	"hidden": { "name": "อาวุธลับ", "color": Color(0.7, 0.7, 0.8) },
	"poison": { "name": "พิษ", "color": Color(0.5, 0.9, 0.4) },
}

const MAX_LEVEL = 10
const RANK_NAMES = ["ไม่เคยฝึก", "เริ่มฝึก", "พอใช้ได้", "ชำนาญ", "เชี่ยวชาญ", "แตกฉาน", "ยอดฝีมือ", "ปรมาจารย์", "สุดยอดปรมาจารย์", "ไร้เทียมทาน", "บรรลุวิถี"]
## ระดับความชำนาญขั้นต่ำที่ต้องมีเพื่อเรียนวิชาแต่ละขั้น (index = SkillDB.Tier)
const REQUIRED_LEVEL = [0, 0, 2, 4, 6, 9]

## EXP ความชำนาญที่ได้จากกิจกรรมต่างๆ
const BACKGROUND_EXP = 10
const GAIN_SKILL_USE = 4
const GAIN_BASIC_ATTACK = 1
const GAIN_STUDY = 6
const GAIN_TRAINING = 3

## ชื่ออาวุธ -> สายความชำนาญ (ดู EquipmentDB.BASES)
const WEAPON_PREFIX = { "กระบี่": "sword", "ดาบ": "saber", "ทวน": "spear", "พัด": "hidden", "เข็ม": "hidden", "สนับมือ": "fist", "กรงเล็บ": "fist" }

static func level_from_exp(xp: int) -> int:
	return mini(MAX_LEVEL, int(sqrt(max(0, xp) / 10.0)))

static func exp_for_level(lv: int) -> int:
	return lv * lv * 10

static func type_name(type: String) -> String:
	return TYPES.get(type, {}).get("name", "ไม่ใช้อาวุธ")

## สายความชำนาญของวิชา ("" = วิชาที่ไม่ผูกกับอาวุธ เช่น ปราณ ตัวเบา ค่ายกล)
static func skill_type(skill_name: String) -> String:
	match SkillDB.get_skill(skill_name).get("type", ""):
		"sword": return "saber" if skill_name.contains("ดาบ") else "sword"
		"spear": return "spear"
		"palm": return "fist"
		"hidden_weapon": return "hidden"
		"poison": return "poison"
	return ""

## สายความชำนาญของอาวุธที่ถืออยู่ (มือเปล่า = หมัด)
static func weapon_type(eq: EquipmentData) -> String:
	if eq == null: return "fist"
	for prefix in WEAPON_PREFIX:
		if eq.item_name.begins_with(prefix): return WEAPON_PREFIX[prefix]
	return ""

static func get_exp(d: DiscipleData, type: String) -> int:
	return int(d.mastery.get(type, 0))

static func get_level(d: DiscipleData, type: String) -> int:
	return level_from_exp(get_exp(d, type))

## ระดับความชำนาญที่ใช้กับวิชานี้ (วิชาที่ไม่ผูกกับอาวุธนับเป็นระดับ 1)
static func skill_level(d: DiscipleData, skill_name: String) -> int:
	var t = skill_type(skill_name)
	return 1 if t == "" else get_level(d, t)

## เพิ่ม EXP ความชำนาญ (ความเข้าใจสูงเรียนรู้เร็วขึ้น) คืนค่า true ถ้าเลื่อนระดับ
static func gain(d: DiscipleData, type: String, amount: int) -> bool:
	if type == "" or amount <= 0: return false
	var before = get_level(d, type)
	var bonus = 1.0 + d.get_stat("comprehension") * 0.05
	d.mastery[type] = get_exp(d, type) + max(1, int(amount * bonus))
	return get_level(d, type) > before

static func required_level(skill_name: String) -> int:
	if skill_type(skill_name) == "": return 0
	return REQUIRED_LEVEL[clampi(int(SkillDB.get_skill(skill_name).get("tier", 1)), 0, 5)]

static func can_learn(d: DiscipleData, skill_name: String) -> bool:
	return skill_level(d, skill_name) >= required_level(skill_name)

## เหตุผลที่ยังเรียนวิชานี้ไม่ได้ ("" = เรียนได้)
static func block_reason(d: DiscipleData, skill_name: String) -> String:
	if can_learn(d, skill_name): return ""
	var t = skill_type(skill_name)
	return "ต้องการความชำนาญ%s ระดับ %d (%s) ตอนนี้ระดับ %d" % [type_name(t), required_level(skill_name), RANK_NAMES[required_level(skill_name)], get_level(d, t)]

## วิชาที่ติดตัวมาก่อน (ภูมิหลัง): ให้ EXP พื้นฐาน +10 และอย่างน้อยถึงเกณฑ์ของวิชานั้น
static func grant_background(d: DiscipleData, skill_name: String) -> void:
	var t = skill_type(skill_name)
	if t == "": return
	var need = max(BACKGROUND_EXP, exp_for_level(required_level(skill_name)))
	d.mastery[t] = max(get_exp(d, t), need)

## สายที่ชำนาญที่สุด ("" = ยังไม่เคยฝึกสายใด)
static func best_type(d: DiscipleData) -> String:
	var best = ""
	var best_exp = 0
	for t in TYPES:
		if get_exp(d, t) > best_exp:
			best_exp = get_exp(d, t)
			best = t
	return best

# ══════════════════════════════════════════
# พรสวรรค์ ↔ วิชา (Aptitude Matching)
# ══════════════════════════════════════════
## สายพรสวรรค์ของศิษย์ (DiscipleData.affinity_style) -> สายความชำนาญที่ "เข้ากัน"
## ฝึกสายที่เข้ากัน = เต็มที่ x1.5 / สายที่ไม่เข้ากัน = x0.35 (EXP และพลังจากวิชาแทบไม่ขึ้น)
const STYLE_TYPES = {
	"sword": ["sword", "saber"], "palm": ["fist"], "poison": ["poison"], "hidden_weapon": ["hidden"],
	"internal": [], "formation": [],
}
const FIT_MATCH = 1.5
const FIT_NEUTRAL = 0.7
const FIT_MISMATCH = 0.35

## ความเข้ากันของศิษย์กับสายความชำนาญ ("" = วิชาไม่ผูกอาวุธ ไม่คิดความเข้ากัน)
static func fit(d: DiscipleData, type: String) -> float:
	if type == "": return 1.0
	var matches: Array = STYLE_TYPES.get(d.affinity_style, [])
	var f = FIT_MATCH if type in matches else (FIT_NEUTRAL if matches.is_empty() else FIT_MISMATCH)
	for s in d.innate_skills:
		if skill_type(s) == type:
			f += 0.15
			break
	return f

## ความเข้ากันกับวิชา (วิชาปราณ/ค่ายกล ฯลฯ เทียบกับสายพรสวรรค์โดยตรง)
static func fit_skill(d: DiscipleData, skill_name: String) -> float:
	var t = skill_type(skill_name)
	if t != "": return fit(d, t)
	var kind: String = SkillDB.get_skill(skill_name).get("type", "")
	return FIT_MATCH if kind != "" and kind == d.affinity_style else 1.0

static func fit_label(f: float) -> String:
	if f >= 1.4: return "เหมาะมาก"
	if f >= 0.9: return "พอใช้"
	if f >= 0.6: return "ค่อนข้างไม่เหมาะ"
	return "ไม่เหมาะ"

static func fit_color(f: float) -> Color:
	if f >= 1.4: return Color(0.55, 1.0, 0.6)
	if f >= 0.9: return Color(1.0, 0.9, 0.55)
	return Color(1.0, 0.5, 0.45)

## สายที่ศิษย์จะฝึกเมื่อประจำลานฝึก: ที่ผู้เล่นตั้งไว้ (train_focus) หรือเลือกสายที่เข้ากันที่สุดอัตโนมัติ
static func train_type(d: DiscipleData) -> String:
	if d.train_focus != "" and TYPES.has(d.train_focus): return d.train_focus
	var wt = weapon_type(d.equipped_weapon)
	var best = ""
	var best_score = -1.0
	for t in TYPES:
		var score = fit(d, t) * 100.0 + get_exp(d, t) * 0.01 + (5.0 if t == wt else 0.0)
		if score > best_score:
			best_score = score
			best = t
	return best
