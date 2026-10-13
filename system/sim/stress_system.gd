extends RefCounted
class_name StressSystem

## ความเครียด (Stress) -> "ธาตุไฟแตกซ่าน" (Qi Deviation)
## ความเครียด 0..100 เพิ่มจากงานหนัก/อดนอน/แพ้ศึก ลดเมื่อนอน/พักผ่อน/ประจำเรือนนอน/ดื่มชาสงบจิต
## ถึง 100 = ธาตุไฟแตกซ่าน สุ่ม 1 ใน 3: บาดเจ็บ / สเตตัสลดชั่วคราว / นอนสลบ 3 วัน แล้วความเครียดเหลือ 40
## ผู้เล่นแก้ด้วยการมอบหมายไปประจำ [เรือนนอน] หรือป้อนยา (ชาสงบจิต) ไม่มีพฤติกรรมวุ่นวายแบบสติแตก

const MAX_STRESS = 100.0
const WARN_AT = 80.0
const AFTER_BREAK = 40.0
const DEBUFF_DAYS = 5
const DEBUFF_MULT = 0.75
const FAINT_DAYS = 3

## ความเครียดที่เพิ่ม/ลดต่อวัน ตามประเภทตึกที่ประจำ: งานหนัก + / งานเบา + น้อย / เรือนนอน − มาก (นอนหลับทุกคืน −7)
const HEAVY = ["training_ground", "forging_pavilion", "quarry", "lumber_camp", "sect_formation", "watchtower", "builders_hut"]
const MEDIUM = ["alchemy_lab", "scripture_pavilion", "infirmary", "farm", "kitchen", "main_hall"]
const HEAVY_PER_DAY = 9.0
const MEDIUM_PER_DAY = 5.0
const SLEEP_RECOVER = 7.0
const DORM_BONUS = 6.0

static func daily_run(sect: SectData, mgr: SectManager) -> void:
	for d in PawnSys.present(sect):
		if d.is_child or d.needs.is_empty(): continue
		var t = BuildingDB.post_type(sect, d)
		var delta = 0.0
		if t in HEAVY: delta = HEAVY_PER_DAY
		elif t in MEDIUM: delta = MEDIUM_PER_DAY
		if delta > 0: delta *= BehaviorTraitDB.mult(d.btraits, "stress")
		if d.needs.rest < 0.2: delta += 8.0
		if d.needs.food < 0.2: delta += 6.0
		if d.mood < 30: delta += 3.0
		# นอนหลับ: มีที่นอนฟื้นเต็มที่ นอนกลางแจ้งฟื้นครึ่งเดียว
		delta -= SLEEP_RECOVER * (1.0 if d.needs.rest >= 0.6 else 0.4)
		if d.needs.rest >= 0.6 and sect.get_building_level("dormitory") > 0:
			delta -= 2.0 * sect.get_building_level("dormitory")
		var before = d.stress
		d.stress = clampf(d.stress + delta, 0.0, MAX_STRESS)
		if d.stress >= WARN_AT and before < WARN_AT and d.stress < MAX_STRESS:
			mgr.log_event("[color=orange]%s เครียดจัด (%d%%) ใกล้ธาตุไฟแตกซ่าน! สั่งนอนพักที่เรือนนอนหรือให้ชาสงบจิต[/color]" % [d.disciple_name, int(d.stress)], [d])
		if d.stress >= MAX_STRESS: qi_deviation(sect, d, mgr)

## ความเครียดเพิ่มทันที (แพ้ศึก ฯลฯ)
static func add(d: DiscipleData, amount: float) -> void:
	d.stress = clampf(d.stress + amount, 0.0, MAX_STRESS)

static func relieve(d: DiscipleData, amount: float) -> void:
	d.stress = clampf(d.stress - amount, 0.0, MAX_STRESS)

## เหตุผลที่เครียด (ใช้แสดงใน UI)
static func status_text(d: DiscipleData) -> String:
	if is_deranged(d): return "ธาตุไฟแตกซ่าน (สเตตัสลด)"
	if d.stress >= WARN_AT: return "เครียดจัด"
	if d.stress >= 50: return "เครียด"
	return "ปกติ"

## สเตตัสลดชั่วคราวจากธาตุไฟแตกซ่านอยู่หรือไม่
static func is_deranged(d: DiscipleData) -> bool:
	return d.debuff_until > 0 and GlobalGame.current_sect != null and GlobalGame.current_sect.current_day < d.debuff_until

## ธาตุไฟแตกซ่าน: บาดเจ็บ / สเตตัสลดชั่วคราว / นอนสลบ 3 วัน
static func qi_deviation(sect: SectData, d: DiscipleData, mgr: SectManager) -> void:
	sect.sim_stats["breaks"] = sect.sim_stats.get("breaks", 0) + 1
	d.stress = AFTER_BREAK
	var kind = ["injury", "debuff", "faint"][randi() % 3]
	match kind:
		"injury":
			d.status = DiscipleData.DiscipleStatus.INJURED
			d.injury_days = maxi(d.injury_days, randi_range(5, 10))
			mgr.log_event("[color=red]%s ธาตุไฟแตกซ่าน! ลมปราณตีกลับจนบาดเจ็บ (พักฟื้น %d วัน)[/color]" % [d.disciple_name, d.injury_days], [d])
		"debuff":
			d.debuff_until = sect.current_day + DEBUFF_DAYS
			mgr.log_event("[color=orange]%s ธาตุไฟแตกซ่าน! ลมปราณปั่นป่วน พลังลดลง 25%% นาน %d วัน[/color]" % [d.disciple_name, DEBUFF_DAYS], [d])
		"faint":
			d.status = DiscipleData.DiscipleStatus.INJURED
			d.injury_days = maxi(d.injury_days, FAINT_DAYS)
			mgr.log_event("[color=red]%s ธาตุไฟแตกซ่านจนสลบไปเป็นเวลา %d วัน![/color]" % [d.disciple_name, FAINT_DAYS], [d])
	d.add_memory(sect.current_day, "ธาตุไฟแตกซ่านเพราะเครียดสะสม")

## วันใหม่: อาการสเตตัสลดหมดฤทธิ์
static func daily(sect: SectData, mgr: SectManager) -> void:
	for d in sect.get_active_disciples():
		if d.debuff_until > 0 and sect.current_day >= d.debuff_until:
			d.debuff_until = 0
			mgr.log_event("%s ลมปราณกลับสู่ปกติแล้ว" % d.disciple_name, [d])
