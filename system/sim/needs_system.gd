extends RefCounted
class_name NeedsSystem

## ความต้องการรายวัน (แทนระบบกิน/นอนรายคนแบบเดินไปทำทีละ tick)
## - อาหาร: ทุกคนกินวันละ 1 มื้อจากคลัง (สำรับปรุงสุกก่อน ไม่มีก็กินเสบียงดิบ) ไม่มีกิน = หิวลดลง ศูนย์ 3 วัน = สิ้นใจ
## - พักผ่อน: ที่นอนรวมของเรือนนอน (ศิษย์ที่ประจำเรือนนอนได้ที่ก่อน) ที่นอนไม่พอ = นอนกลางแจ้ง
## - ปราณ: ฟื้นเมื่อฝึก/ทำสมาธิ (ดู ProductionSys) ลดลงเมื่อไม่ได้ฝึก · ความบันเทิง: ศิษย์อิสระได้พักผ่อนหย่อนใจ

const FOOD_DECAY = 0.45

static func daily(sect: SectData, mgr: SectManager) -> void:
	var pawns = PawnSys.present(sect)
	var beds = BuildingDB.get_beds(sect)
	# ลำดับได้ที่นอน: ผู้ที่ต้องการพักผ่อนมากที่สุดหรือเครียดมากที่สุดได้เตียงก่อน
	var order = pawns.duplicate()
	order.sort_custom(func(a, b): return _bed_rank(sect, a) > _bed_rank(sect, b))
	for d in order:
		if d.needs.is_empty(): continue
		var cons = PawnSys.consumption(d) * BehaviorTraitDB.mult(d.btraits, "hunger")
		# กิน
		d.needs.food = max(0.0, d.needs.food - FOOD_DECAY * cons)
		if sect.meals > 0:
			sect.meals -= 1
			ProductionSys._stat(sect, "meals_eaten", 1)
			if sect.fine_meals > 0:
				sect.fine_meals -= 1
				PawnSys.add_thought(d, sect, "fine_meal")
			d.needs.food = min(1.0, d.needs.food + 0.8 * cons)
		elif sect.food >= 8:
			sect.food -= 8
			ProductionSys._stat(sect, "food_raw", 8)
			d.needs.food = min(1.0, d.needs.food + 0.7 * cons)
			if not BehaviorTraitDB.has_flag(d.btraits, "blood_cult"): PawnSys.add_thought(d, sect, "raw_food")
		# นอน
		if beds > 0:
			beds -= 1
			d.needs.rest = min(1.0, d.needs.rest + 0.6)
			if sect.get_building_level("dormitory") >= 3: PawnSys.add_thought(d, sect, "slept_well")
		else:
			d.needs.rest = clampf(d.needs.rest - 0.22 * BehaviorTraitDB.mult(d.btraits, "rest") + 0.12, 0.0, 1.0)
			PawnSys.add_thought(d, sect, "slept_outside")
		# ปราณ / ความบันเทิง
		if BuildingDB.post_type(sect, d) != "training_ground":
			d.needs.qi = max(0.0, d.needs.qi - 0.1 * cons)
		var joy_gain = 0.0 if d.post != "" else 0.18
		d.needs.joy = clampf(d.needs.joy - 0.07 * (0.5 if d.btraits.has("loner") else 1.0) + joy_gain, 0.0, 1.0)
		d.hunger = int(d.needs.food * 100)
		# อดอาหาร: ผ่านไป 3 วันที่อาหารเป็นศูนย์ = สิ้นใจ
		if d.needs.food <= 0.0:
			d.needs["starve"] = d.needs.get("starve", 0.0) + 1.0 / 3.0
			if d.needs.starve >= 0.99: HealthSystem.kill(sect, d, "อดอาหารจนสิ้นใจ", mgr)
		elif d.needs.has("starve"):
			d.needs.starve = max(0.0, d.needs.starve - 0.34)

static func _bed_rank(sect: SectData, d: DiscipleData) -> int:
	# คะแนนความต้องการเตียง: พักผ่อนเหลือน้อย + เครียดสูง
	return int((1.0 - d.needs.get("rest", 1.0)) * 100.0) + int(d.stress)
