extends RefCounted
class_name OrderSys

## คำสั่งงานทั่วแผนที่ (Designations): ผู้เล่นลากเลือกต้นไม้/หิน/สัตว์บนฉากได้ทุกที่ ไม่ต้องผูกกับตึก
## - chop = ตัดต้นไม้ (ช่อง FOREST -> GRASS ได้ไม้) · mine = ทุบหิน (ROCK -> DIRT ได้หิน) · hunt = ล่า/เชือดสัตว์ (ได้เนื้อ หนัง ค่าหัว)
## - แรงงานคือศิษย์ที่ว่าง (ไม่ได้ประจำตึก) ทำตามคิวทุกวัน คนละ ~2 งาน/วัน ตามความเร็วทำงาน · ศิษย์ที่ทำงานนี้จะไปยืนที่เป้าหมาย (ภาพประกอบ)
## - ตึกค่ายตัดไม้/เหมืองยังทำงานของมันตามปกติ (ผลผลิตรายตึก) คำสั่งนี้คือแรงงานเสริมเฉพาะจุด

const MAX_ORDERS = 150
const KINDS = {
	"chop": { "name": "ตัดไม้", "skill": "construction", "color": Color(0.35, 0.9, 0.35) },
	"mine": { "name": "ทุบหิน", "skill": "mining", "color": Color(0.7, 0.8, 1.0) },
	"hunt": { "name": "ล่าสัตว์", "skill": "melee", "color": Color(1.0, 0.5, 0.3) },
	"tame": { "name": "จับมาเลี้ยง", "skill": "farming", "color": Color(0.4, 0.9, 0.6) },
}
const WOOD_PER_TREE = 4
const STONE_PER_ROCK = 5

static func has_order(sect: SectData, kind: String, cell: Vector2i, animal := -1) -> bool:
	for o in sect.orders:
		if o.kind != kind: continue
		if animal >= 0:
			if int(o.get("animal", -1)) == animal: return true
		elif o.get("cell", Vector2i(-1, -1)) == cell: return true
	return false

static func animal_by_id(sect: SectData, id: int) -> Dictionary:
	for a in sect.animals:
		if a.id == id: return a
	return {}

## สั่งงานทั้งกรอบ (หน่วยเป็นช่อง) คืนจำนวนคำสั่งที่เพิ่มได้
static func add_area(sect: SectData, kind: String, rect: Rect2i) -> int:
	var n = 0
	if kind in ["hunt", "tame"]:
		for a in sect.animals:
			if rect.has_point(Vector2i(a.pos)) and not has_order(sect, kind, Vector2i.ZERO, int(a.id)):
				if kind == "tame" and (a.tame or AnimalDB.SPECIES[a.species].get("predator", false)):
					continue
				if sect.orders.size() >= MAX_ORDERS: break
				sect.orders.append({ "kind": kind, "cell": Vector2i(a.pos), "animal": int(a.id) })
				n += 1
		return n
	var want = Territory.T.FOREST if kind == "chop" else Territory.T.ROCK
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			var c = Vector2i(x, y)
			if Territory.at(sect, c) != want or has_order(sect, kind, c): continue
			if sect.orders.size() >= MAX_ORDERS: return n
			sect.orders.append({ "kind": kind, "cell": c })
			n += 1
	return n

## ยกเลิกคำสั่งในกรอบ คืนจำนวนที่ยกเลิก
static func cancel_area(sect: SectData, rect: Rect2i) -> int:
	var keep: Array[Dictionary] = []
	var removed = 0
	for o in sect.orders:
		var c: Vector2i = o.cell
		if o.kind in ["hunt", "tame"]:
			var a = animal_by_id(sect, int(o.get("animal", -1)))
			if not a.is_empty(): c = Vector2i(a.pos)
		if rect.has_point(c): removed += 1
		else: keep.append(o)
	sect.orders = keep
	return removed

static func count(sect: SectData, kind := "") -> int:
	if kind == "": return sect.orders.size()
	var n = 0
	for o in sect.orders:
		if o.kind == kind: n += 1
	return n

## แรงงานว่างที่รับคำสั่งได้
static func free_workers(sect: SectData) -> Array[DiscipleData]:
	var out: Array[DiscipleData] = []
	for d in ProductionSys.able(sect):
		if d.post == "": out.append(d)
	return out

## ตำแหน่งปัจจุบันของเป้าหมาย (พิกัดช่องแบบทศนิยม)
static func target_pos(sect: SectData, o: Dictionary) -> Vector2:
	if o.kind in ["hunt", "tame"]:
		var a = animal_by_id(sect, int(o.get("animal", -1)))
		if not a.is_empty(): return a.pos
	return Vector2(o.cell) + Vector2(0.5, 0.5)

## เป้าหมายยังอยู่ไหม (ต้นไม้ถูกตัดไปแล้ว/สัตว์ตายแล้ว/เชื่องแล้ว = ทิ้งคำสั่ง)
static func _valid(sect: SectData, o: Dictionary) -> bool:
	match o.kind:
		"chop": return Territory.at(sect, o.cell) == Territory.T.FOREST
		"mine": return Territory.at(sect, o.cell) == Territory.T.ROCK
		"hunt": return not animal_by_id(sect, int(o.get("animal", -1))).is_empty()
		"tame":
			var a = animal_by_id(sect, int(o.get("animal", -1)))
			return not a.is_empty() and not a.tame
	return false

static func daily(sect: SectData, mgr: SectManager) -> void:
	if sect.orders.is_empty(): return
	var keep: Array[Dictionary] = []
	for o in sect.orders:
		if _valid(sect, o): keep.append(o)
	sect.orders = keep
	if sect.orders.is_empty(): return
	var workers = free_workers(sect)
	if sect.order_draft:
		for d in ProductionSys.able(sect):
			if d.post != "": workers.append(d)
	if workers.is_empty() and sect.current_day % 7 == 0:
		mgr.log_event("[color=orange]มีคำสั่งงาน %d จุดแต่ไม่มีศิษย์ว่าง — ถอดศิษย์ออกจากตึกบางคน (เมนูมอบหมาย) ให้มาทำงานตามคำสั่ง[/color]" % sect.orders.size())
	var done = 0
	var wood = 0
	var stone = 0
	var meat = 0
	var idx = 0
	for d in workers:
		if idx >= sect.orders.size(): break
		var units = clampi(roundi(PawnSys.work_speed(d, "construction") * 2.4), 1, 4)
		d.needs["ordered"] = sect.current_day
		for u in units:
			if idx >= sect.orders.size(): break
			var o: Dictionary = sect.orders[idx]
			idx += 1
			d.pos = target_pos(sect, o) + Vector2(0.6, 0.6)
			match o.kind:
				"chop":
					Territory.set_at(sect, o.cell, Territory.T.GRASS)
					sect.terrain_dirty = true
					wood += WOOD_PER_TREE
					PawnSys.learn(d, "construction", 6.0)
				"mine":
					Territory.set_at(sect, o.cell, Territory.T.DIRT)
					sect.terrain_dirty = true
					stone += STONE_PER_ROCK
					PawnSys.learn(d, "mining", 8.0)
				"hunt":
					meat += _hunt(sect, mgr, d, o)
				"tame":
					_tame(sect, mgr, d, o)
			o["done"] = true
			done += 1
	if done == 0: return
	if wood > 0: sect.add_material("wood", wood)
	if stone > 0: sect.add_material("stone", stone)
	if meat > 0: sect.food += meat
	var rest: Array[Dictionary] = []
	for o in sect.orders:
		if not o.get("done", false): rest.append(o)
	sect.orders = rest
	ProductionSys._stat(sect, "orders_done", done)
	var parts: Array[String] = []
	if wood > 0: parts.append("ไม้ %d" % wood)
	if stone > 0: parts.append("หิน %d" % stone)
	if meat > 0: parts.append("เนื้อ %d" % meat)
	if sect.current_day % 2 == 0:
		mgr.log_event("[color=#c8e090]งานตามคำสั่งเสร็จ %d จุด (%s) เหลือในคิว %d[/color]" % [done, ", ".join(parts), sect.orders.size()])

## ล่าสัตว์ 1 ตัว คืนปริมาณเนื้อที่ได้ (หมาป่าสู้กลับ อาจบาดเจ็บ)
static func _hunt(sect: SectData, mgr: SectManager, d: DiscipleData, o: Dictionary) -> int:
	var a = animal_by_id(sect, int(o.get("animal", -1)))
	if a.is_empty(): return 0
	var sp = AnimalDB.SPECIES[a.species]
	if sp.get("predator", false):
		var power = d.get_power_rating()
		var risk = clampf(0.45 - power / 3000.0, 0.08, 0.45)
		if randf() < risk:
			var res = PawnSys.injure(d, randf_range(6, 14), "ถูกหมาป่ากัด")
			mgr.log_event("[color=red]%s ถูกหมาป่าสู้กลับระหว่างล่า (%s)[/color]" % [d.disciple_name, res], [d])
	sect.animals.erase(a)
	var meat = int(sp.get("meat", 0))
	if int(sp.get("hide", 0)) > 0: sect.add_material("beast_hide", int(sp.hide))
	if int(sp.get("bounty", 0)) > 0:
		sect.money += int(sp.bounty)
		ProductionSys._stat(sect, "wolves_killed", 1)
	ProductionSys._stat(sect, "animals_hunted", 1)
	return meat

## ฝึก/จับสัตว์ 1 ตัวให้เชื่อง (ต้องเป็นสัตว์กินพืช/เหยื่อ)
static func _tame(sect: SectData, mgr: SectManager, d: DiscipleData, o: Dictionary) -> void:
	var a = animal_by_id(sect, int(o.get("animal", -1)))
	if a.is_empty() or a.tame: return
	var sp = AnimalDB.SPECIES[a.species]
	if sp.get("predator", false):
		mgr.log_event("[color=red]%s พยายามฝึกหมาป่าแต่ถูกแว้งกัด! สัตว์ร้ายไม่ยอมเชื่อง[/color]" % d.disciple_name, [d])
		return
	if sect.food >= 1:
		sect.food -= 1
	var skill = PawnSys.work_speed(d, "farming")
	var chance = clampf(0.5 + skill * 0.3, 0.45, 0.95)
	if randf() < chance:
		a.tame = true
		a.state = "tame"
		PawnSys.learn(d, "farming", 10.0)
		mgr.log_event("[color=#c8e090]%s ให้อาหารและฝึก %s สำเร็จ กลายเป็นสัตว์เลี้ยงของสำนัก (ให้นม/ไข่)[/color]" % [d.disciple_name, sp.name], [d])
	else:
		mgr.log_event("%s พยายามล่อจับ %s แต่สัตว์ตื่นหนีไป (จะพยายามใหม่ในคิวถัดไป)" % [d.disciple_name, sp.name], [d])
