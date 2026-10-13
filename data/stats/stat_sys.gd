extends Node
class_name StatSys

## ระบบค่าพลังแบบ 3 ชั้น (Layered Stats)
## 1) Base Potential (รากฐาน/พรสวรรค์): ค่าติดตัวแต่กำเนิด คนธรรมดาสุ่ม 1-5 (อัจฉริยะไปได้ถึง POTENTIAL_CAP)
## 2) Realm Multiplier (ตัวคูณระดับขั้น): ขั้นบำเพ็ญคูณค่าพลังต่อสู้ (ดู RealmDB) เช่น รวบรวมลมปราณ x1.0, สร้างรากฐาน x2.5
## 3) Equipment / Buff Bonus: ค่าบวกเพิ่มแบบคงที่จากอาวุธ ชุดเกราะ ของวิเศษ
## พลังรบรวม = (พลังโจมตี x2) + (HP / 5) + (ความเร็ว x1.5) + (โบนัสวิชา x ระดับความชำนาญ)

## 6 หมวดหลัก และ 28 ค่าพลังย่อย (ความชำนาญอาวุธแยกไปอยู่ MasterySys)
const CATEGORIES = {
	"Physical": "ร่างกาย",
	"Spiritual": "จิตวิญญาณ",
	"Mental": "สติปัญญา",
	"Social": "สังคมและการทูต",
	"Combat": "ศาสตร์การต่อสู้",
	"Crafting": "ทักษะวิชาชีพ"
}

const STATS_DEF = {
	# 1. Physical (ร่างกาย)
	"str": { "name": "ความแข็งแกร่ง", "cat": "Physical", "desc": "พลังโจมตี (x ตัวคูณขั้นบำเพ็ญ)" },
	"vit": { "name": "ความทนทาน", "cat": "Physical", "desc": "HP สูงสุดและพลังป้องกัน (x ตัวคูณขั้นบำเพ็ญ)" },
	"agi": { "name": "ความว่องไว", "cat": "Physical", "desc": "ความเร็วและลำดับเทิร์น (x ตัวคูณขั้นบำเพ็ญ)" },
	"regen": { "name": "การฟื้นฟู", "cat": "Physical", "desc": "ฟื้นตัวจากอาการบาดเจ็บเร็วขึ้น" },
	"immune": { "name": "ภูมิคุ้มกัน", "cat": "Physical", "desc": "โอกาสต้านทานพิษและโรคภัย" },

	# 2. Spiritual (จิตวิญญาณ)
	"aptitude": { "name": "รากวิญญาณ", "cat": "Spiritual", "desc": "โอกาสทะลวงคอขวดขั้นใหญ่" },
	"max_qi": { "name": "ปราณสูงสุด", "cat": "Spiritual", "desc": "พลังปราณสำหรับวิชาขั้นสูง" },
	"perception": { "name": "สัมผัสวิญญาณ", "cat": "Spiritual", "desc": "ความแม่นยำเวทและหลบหลีกเวท" },
	"breakthrough": { "name": "ทะลวงจุด", "cat": "Spiritual", "desc": "โอกาสรอดชีวิตเวลาธาตุไฟแตกซ่าน" },
	"magic_resist": { "name": "ต้านทานปราณ", "cat": "Spiritual", "desc": "ลดพลังโจมตีเวทมนตร์" },

	# 3. Mental (สติปัญญา)
	"comprehension": { "name": "ความเข้าใจ", "cat": "Mental", "desc": "ความเร็วในการรับ EXP และความชำนาญ" },
	"memory": { "name": "ความจำ", "cat": "Mental", "desc": "ขีดจำกัดจำนวนวิชาที่สามารถจำได้" },
	"focus": { "name": "สมาธิ", "cat": "Mental", "desc": "ความแม่นยำในการโจมตีจุดตาย (Critical)" },
	"willpower": { "name": "ปณิธาน", "cat": "Mental", "desc": "ต้านทานสถานะผิดปกติทางจิตใจ" },
	"wit": { "name": "ไหวพริบ", "cat": "Mental", "desc": "โอกาสเอาตัวรอดจากกับดักค่ายกล" },

	# 4. Social (สังคมและการทูต)
	"charisma": { "name": "เสน่ห์", "cat": "Social", "desc": "ทำให้ NPC หรือศิษย์คนอื่นชื่นชอบง่ายขึ้น" },
	"intimidation": { "name": "ความน่าเกรงขาม", "cat": "Social", "desc": "ใช้ข่มขวัญศัตรู หรือต่อรอง" },
	"leadership": { "name": "ภาวะผู้นำ", "cat": "Social", "desc": "บัฟสเตตัสให้เพื่อนในทีมเมื่อเป็นหัวหน้า" },
	"deception": { "name": "เล่ห์เหลี่ยม", "cat": "Social", "desc": "ความแนบเนียนเวลาขโมยของหรือลอบสังหาร" },
	"luck": { "name": "โชคชะตา", "cat": "Social", "desc": "โอกาสดรอปของแรร์ และหลีกเลี่ยงโชคร้าย" },

	# 5. Combat (ศาสตร์การต่อสู้ที่ไม่ผูกกับอาวุธ)
	"movement_arts": { "name": "วิชาตัวเบา", "cat": "Combat", "desc": "เสริมความเร็ว (x ตัวคูณขั้นบำเพ็ญ)" },
	"defense_arts": { "name": "ป้องกันตัว", "cat": "Combat", "desc": "เสริมพลังป้องกัน (x ตัวคูณขั้นบำเพ็ญ)" },

	# 6. Crafting (ทักษะวิชาชีพ)
	"alchemy": { "name": "ปรุงยา", "cat": "Crafting", "desc": "ความสำเร็จและคุณภาพในการหลอมโอสถ" },
	"forging": { "name": "หลอมศาสตรา", "cat": "Crafting", "desc": "โอกาสได้ของวิเศษระดับสูงจากการคราฟต์" },
	"formation": { "name": "ค่ายกล", "cat": "Crafting", "desc": "สร้างและทำลายค่ายกลป้องกันเมือง" },
	"cooking": { "name": "ทำอาหาร", "cat": "Crafting", "desc": "บัฟจากอาหารที่กินจะมีผลดีขึ้น" },
	"gathering": { "name": "เก็บรวบรวม", "cat": "Crafting", "desc": "ได้วัตถุดิบและสมุนไพรมากขึ้นตอนลงเขา" },
	"medicine": { "name": "การแพทย์", "cat": "Crafting", "desc": "ฝังเข็มรักษาเส้นชีพจรที่ขาดสะบั้นและถอนพิษกู่" }
}

## ช่วงค่ารากฐาน
const POTENTIAL_MIN = 1
const POTENTIAL_CAP = 10
## คำอธิบายระดับรากฐาน (index = ค่า 1-10)
const POTENTIAL_GRADES = ["", "ต่ำต้อย", "ธรรมดา", "ปานกลาง", "ดี", "โดดเด่น", "หายาก", "อัจฉริยะ", "อัจฉริยะ", "เหนือมนุษย์", "ฟ้าประทาน"]

## สุ่มรากฐาน 1 ค่าสำหรับคนธรรมดา (1-5 ค่ากลางอยู่ที่ 3)
static func roll_potential() -> int:
	return randi_range(1, 3) + randi_range(0, 2)

static func clamp_potential(v: int) -> int:
	return clampi(v, POTENTIAL_MIN, POTENTIAL_CAP)

static func grade_name(v: int) -> String:
	return POTENTIAL_GRADES[clampi(v, 1, POTENTIAL_CAP)]

# ══════════════════════════════════════════
# ค่าพลังต่อสู้ (ใช้ทั้งศิษย์และศัตรู ให้สเกลเดียวกันทั้งเกม)
# pot = { "str", "vit", "agi", "movement_arts", "defense_arts" } (ค่ารากฐาน)
# gear = { "hp", "atk", "def", "spd" } (ค่าบวกจากอุปกรณ์/บัฟ)
# ══════════════════════════════════════════

## ส่วนประกอบของค่าพลังต่อสู้แต่ละตัว แยกเป็น 3 ชั้น (ไว้แสดงที่มาของตัวเลข)
## คืนค่า { "hp": {base, mult, gear, total}, "atk": ..., "def": ..., "spd": ... }
static func derive_combat(pot: Dictionary, mult: float, gear: Dictionary) -> Dictionary:
	var bases = {
		"hp": 10.0 + pot.get("vit", 3) * 8.0,
		"atk": 1.0 + pot.get("str", 3),
		"def": pot.get("vit", 3) * 0.5 + pot.get("defense_arts", 3) * 0.5,
		"spd": pot.get("agi", 3) + pot.get("movement_arts", 3) * 0.5,
	}
	var result = {}
	for k in bases:
		var g: int = gear.get(k, 0)
		result[k] = { "base": bases[k], "mult": mult, "gear": g, "total": max(1, int(bases[k] * mult) + g) }
	return result

## พลังรบรวมแบบถ่วงน้ำหนัก
static func combat_power(atk: int, hp: int, spd: int, skill_bonus: float, mastery_level: int) -> int:
	return int(atk * 2.0 + hp / 5.0 + spd * 1.5 + skill_bonus * max(1, mastery_level))

## โบนัสของวิชา (ใช้ในสูตรพลังรบรวม) เช่น วิชาพลัง 10 = 1, พลัง 150 = 15
static func skill_bonus(skill_power: int) -> float:
	return skill_power / 10.0

## ความเสียหายเพิ่มเติมจากวิชา: สเกลตามพลังโจมตี (จึงยังมีความหมายแม้ขั้นบำเพ็ญจะสูงขึ้น)
static func skill_damage(atk: int, skill_power: int, mastery_level: int) -> int:
	return int(atk * skill_power / 40.0 * (1.0 + mastery_level * 0.08))

# ══════════════════════════════════════════
# ค่าพลังกับอวตารบนแผนที่ 2.5D (Physical Data Binding)
# ══════════════════════════════════════════

## ตัวคูณความเร็วเดิน: ความว่องไว + วิชาตัวเบา (รากฐาน 3/3 = x1.0, 10/10 = x1.7) ขั้นบำเพ็ญช่วยเล็กน้อย
static func walk_speed_mult(d: DiscipleData) -> float:
	var major = CultivationSys.get_realm_info(d.level).major_index
	var m = 0.7 + d.get_stat("agi") * 0.06 + d.get_stat("movement_arts") * 0.04 + max(0, major - 1) * 0.05
	return clampf(m * (0.6 if d.disabled else 1.0), 0.5, 2.5)

## รัศมีการมองเห็น (ช่อง) ในพื้นที่สำรวจ ใช้เปิดหมอก Fog of War: สัมผัสวิญญาณ 3 = 6 ช่อง, 10 = 10 ช่อง
static func sight_tiles(d: DiscipleData) -> float:
	return 4.0 + d.get_stat("perception") * 0.6

# ══════════════════════════════════════════
# สเกลภัยคุกคามของโลกตามวันเวลา (ใช้เทียบกับพลังรบรวมของศิษย์)
# ══════════════════════════════════════════

## พลังของภัยคุกคามทั่วไป (สัตว์อสูร/โจร/คู่แข่งในแดนลับ) ณ วันที่ day
static func world_threat(day: int) -> float:
	return 30.0 + day * 0.5 + day * day * 0.0015

## สร้างค่าพลังของศัตรูที่มีพลังรบรวมใกล้เคียง target_power (หาขั้นบำเพ็ญที่เหมาะสม)
## คืนค่า { level, max_hp, attack, defense, speed }
static func build_fighter(target_power: float, pot_avg: float = 3.5, gear_atk: int = 0) -> Dictionary:
	var pot = { "str": pot_avg, "vit": pot_avg, "agi": pot_avg, "movement_arts": pot_avg, "defense_arts": pot_avg }
	var best = {}
	for level in range(1, 82):
		var c = derive_combat(pot, RealmDB.multiplier(level), { "atk": gear_atk })
		best = { "level": level, "max_hp": c.hp.total, "attack": c.atk.total, "defense": c.def.total, "speed": c.spd.total }
		if combat_power(c.atk.total, c.hp.total, c.spd.total, 0, 0) >= target_power:
			break
	return best
