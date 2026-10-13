extends RefCounted
class_name AnimalSys

## ระบบนิเวศสัตว์ในอาณาเขต: วัว ไก่ หมาป่า (ข้อมูลที่ AnimalDB) สุ่มเกิด แต่ละชนิดมี behavior ต่างกัน
## - วัว/ไก่: กินหญ้า เดินเป็นฝูง ชอบอยู่ใกล้ "กองไฟ" ถ้าอยู่ใกล้ไฟครบ tame_days วัน = กลายเป็นสัตว์เลี้ยง (ให้นม/ไข่ทุกวัน นับเป็นทรัพย์สิน)
## - หมาป่า: ออกล่าเป็นฝูงยามค่ำ เลือกเหยื่ออ่อนแอที่อยู่ไกลไฟ กลัวไฟ/หอยามเว้นแต่หิวจัด ถูกศิษย์ที่ประจำหอยาม/ค่ายกลไล่หรือฆ่า
## การคิดทำทุก UPDATE_TICKS tick (ไม่ใช่ทุก tick) ด้วยการให้คะแนนการกระทำ (utility) ตำแหน่งเป็นพิกัดช่องทศนิยม
## สัตว์เก็บใน SectData.animals [{ id, species, pos, target, hp, hunger, tame, fire_days, group, state, age }]

const UPDATE_TICKS = 20
const MAX_ANIMALS = 150
const GRAZE_REGROW_DAYS = 3
const MAX_WOLVES = 8

# ══════════════════════════════════════════
# แหล่งไฟ / ยาม
# ══════════════════════════════════════════

## รัศมีไฟของกองไฟระดับ lv (ช่อง)
static func fire_radius(lv: int) -> float:
	return 3.0 + 2.0 * lv

## แหล่งไฟทั้งหมด [{ pos, radius }] (เฉพาะกองไฟที่สร้างเสร็จ)
static func fire_sources(sect: SectData) -> Array:
	var out: Array = []
	for inst in sect.instances("campfire"):
		if int(inst.level) > 0:
			out.append({ "pos": Vector2(inst.cell) + Vector2(0.5, 0.5), "radius": fire_radius(int(inst.level)) })
	return out

## จุดเฝ้ายาม [{ pos, radius, power }] หอยาม/ค่ายกลที่มีศิษย์ประจำ (รัศมีไล่สัตว์ร้าย)
static func guard_posts(sect: SectData) -> Array:
	var out: Array = []
	for type in ["watchtower", "sect_formation"]:
		for inst in sect.instances(type):
			if int(inst.level) <= 0: continue
			var crew = ProductionSys.workers(sect, inst)
			if crew.is_empty(): continue
			var power = 0.0
			for d in crew: power += d.get_power_rating()
			var size = BuildingDB.BUILDINGS[type].size
			out.append({ "pos": Vector2(inst.cell) + Vector2(size) / 2.0, "radius": 8.0 + 2.0 * int(inst.level), "power": power, "crew": crew })
	return out

static func _near_fire(fires: Array, p: Vector2, extra := 0.0) -> bool:
	for f in fires:
		if f.pos.distance_to(p) <= f.radius + extra: return true
	return false

static func _nearest(list: Array, p: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var bd = INF
	for e in list:
		var d = e.pos.distance_to(p)
		if d < bd:
			bd = d
			best = e
	return best

# ══════════════════════════════════════════
# สร้าง / นับ
# ══════════════════════════════════════════

## เริ่มเกมใหม่: มีฝูงวัว/ไก่ป่ากระจายอยู่รอบสำนัก (เซฟเก่าค่อยๆ มีเองจากการสุ่มเกิดรายวัน)
static func init_world(sect: SectData) -> void:
	if not sect.animals.is_empty() or sect.current_day > 2 or sect.terrain.size() != Territory.SIZE * Territory.SIZE: return
	var rng_state = randi()
	seed(sect.world_seed ^ 0x51A)
	for i in 3:
		var p = _random_cell(sect, Territory.T.GRASS, 10.0, 24.0)
		if p.x >= 0:
			var g = sect.next_animal_id
			for k in randi_range(3, 5): make(sect, "cow", Vector2(p) + Vector2(randf_range(-2, 2), randf_range(-2, 2)), g)
	for i in 2:
		var p = _random_cell(sect, Territory.T.GRASS, 10.0, 26.0)
		if p.x >= 0:
			var g = sect.next_animal_id
			for k in randi_range(2, 4): make(sect, "pig", Vector2(p) + Vector2(randf_range(-2, 2), randf_range(-2, 2)), g)
	for i in 3:
		var p = _random_cell(sect, Territory.T.GRASS, 8.0, 22.0)
		if p.x >= 0:
			var g = sect.next_animal_id
			for k in randi_range(3, 6): make(sect, "chicken", Vector2(p) + Vector2(randf_range(-2, 2), randf_range(-2, 2)), g)
	seed(rng_state)

## เลื่อนจุดเกิดที่ตกบนน้ำ/หิน (หรือช่องที่เดินไม่ได้) ไปช่องที่เดินได้ใกล้ที่สุด
static func _nearest_walkable(sect: SectData, sp: Dictionary, pos: Vector2) -> Vector2:
	if _walkable(sect, sp, pos): return pos
	for r in range(1, 12):
		for k in 16:
			var p = pos + Vector2.from_angle(TAU * k / 16.0) * r
			if _walkable(sect, sp, p): return p
	return pos

static func make(sect: SectData, species: String, pos: Vector2, group: int) -> Dictionary:
	pos = _nearest_walkable(sect, AnimalDB.SPECIES[species], pos)
	var a = { "id": sect.next_animal_id, "species": species, "pos": pos, "target": pos, "hp": AnimalDB.SPECIES[species].hp, "hunger": randf_range(0.1, 0.4), "tame": false, "fire_days": 0.0, "group": group, "state": "wander", "age": 0 }
	sect.next_animal_id += 1
	sect.animals.append(a)
	return a

static func count(sect: SectData, species: String, only_tame := false) -> int:
	var n = 0
	for a in sect.animals:
		if a.species == species and (not only_tame or a.tame): n += 1
	return n

## มูลค่าสัตว์เลี้ยงที่นับเป็นทรัพย์สิน (กระทบความมั่งคั่งของ storyteller)
static func livestock_value(sect: SectData) -> int:
	var v = 0
	for a in sect.animals:
		if a.tame: v += int(AnimalDB.SPECIES[a.species].value)
	return v

## สัตว์เลี้ยงชนิดนี้ที่อยู่ใกล้ตึก inst ในรัศมี radius (ใช้ให้โบนัสแปลงเกษตร)
static func livestock_near(sect: SectData, inst: Dictionary, species: String, radius := 10.0) -> int:
	var c = Vector2(inst.cell) + Vector2(BuildingDB.BUILDINGS[inst.type].size) / 2.0
	var n = 0
	for a in sect.animals:
		if a.species == species and a.tame and a.pos.distance_to(c) <= radius: n += 1
	return n

static func _walkable(sect: SectData, sp: Dictionary, p: Vector2) -> bool:
	var t = Territory.at(sect, Vector2i(int(floor(p.x)), int(floor(p.y))))
	if t == Territory.T.WATER or t == Territory.T.ROCK: return false
	if t == Territory.T.FOREST and not sp.forest: return false
	return true

# ══════════════════════════════════════════
# รอบคิด (ทุก UPDATE_TICKS tick)
# ══════════════════════════════════════════

static func tick(sect: SectData, mgr: SectManager) -> void:
	if sect.animals.is_empty(): return
	var fires = fire_sources(sect)
	var guards = guard_posts(sect)
	var wolves: Array = []
	var prey: Array = []
	for a in sect.animals:
		if a.species == "wolf": wolves.append(a)
		else: prey.append(a)
	var dead: Array = []
	for a in sect.animals:
		var sp = AnimalDB.SPECIES[a.species]
		a.age += 1
		if sp.get("predator", false):
			_think_wolf(sect, a, sp, prey, fires, guards, mgr, dead)
		else:
			_think_prey(sect, a, sp, wolves, fires, mgr)
		_step(sect, a, sp)
		if a.hp <= 0.0 and not dead.has(a): dead.append(a)
	for a in dead: sect.animals.erase(a)

## เหยื่อ (วัว/ไก่/หมู): หนีหมาป่า > พฤติกรรมเฉพาะตามชนิด (คุ้ยเขี่ย/ขุดดิน/เคี้ยวเอื้อง) > หาไฟยามค่ำ (ชอบแสงอุ่น) > เดินตามฝูง
static func _think_prey(sect: SectData, a: Dictionary, sp: Dictionary, wolves: Array, fires: Array, mgr: SectManager) -> void:
	a.hunger = minf(1.0, a.hunger + 0.012)
	if a.hunger >= 1.0: a.hp -= 0.5

	# 1) หนีหมาป่า (สัญชาตญาณเอาชีวิตรอดอันดับหนึ่ง)
	var w = _nearest(wolves, a.pos)
	if not w.is_empty() and w.pos.distance_to(a.pos) < sp.flee:
		a.state = "flee"
		var away = (a.pos - w.pos).normalized()
		a.target = a.pos + away * 6.0
		return

	# 2) ไก่ป่า: ตกใจวิ่งหนีเวลาศิษย์เดินเฉียดใกล้ (สัตว์ป่ายังไม่เชื่อง)
	if a.species == "chicken" and not a.tame:
		for d in sect.get_in_sect_disciples():
			if d.pos.distance_to(a.pos) < 2.5:
				a.state = "startle"
				var away_p = (a.pos - d.pos).normalized()
				a.target = a.pos + away_p * 4.5
				return

	# 3) ความชอบแสง/ไฟ: สัตว์ชอบแสงและความอบอุ่นยามค่ำ (ไม่ได้แปลว่าเชื่อง!)
	var f = _nearest(fires.map(func(x): return { "pos": x.pos, "radius": x.radius }), a.pos)
	var is_night = sect.time_phase == 2
	var fire_score = 0.0
	if not f.is_empty():
		var dist = f.pos.distance_to(a.pos)
		# กลางคืนหรือสัตว์ที่ชอบไฟจะเข้าใกล้กองไฟเพื่อความอบอุ่นและป้องกันตัว
		var night_bonus = 2.0 if is_night else 0.5
		fire_score = sp.fire_affinity * night_bonus * (1.0 - a.hunger * 0.4)
		if dist <= f.radius:
			fire_score *= 0.2 # ถึงกองไฟแล้ว ผิงไฟสบายใจ

	# 4) พฤติกรรมเฉพาะตามชนิดสัตว์
	var roll = randf()
	if is_night and fire_score > 0.4 and not f.is_empty():
		a.state = "seek_fire"
		if a.pos.distance_to(a.target) < 0.6 or randf() < 0.25:
			a.target = f.pos + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * (f.radius * 0.7)
		return

	match a.species:
		"chicken":
			# ไก่: คุ้ยเขี่ยหาหนอน/เมล็ดพืช (40%) > เดินกระพือปีก (35%) > กินหญ้า (25%)
			if a.hunger > 0.25 and roll < 0.45:
				a.state = "peck"
				a.hunger = maxf(0.0, a.hunger - 0.08)
				a.target = a.pos
			elif a.hunger > 0.4 and roll < 0.7:
				a.state = "graze"
				_graze(sect, a, sp)
			else:
				a.state = "wander"
				if a.pos.distance_to(a.target) < 0.5 or randf() < 0.2:
					a.target = _herd_target(sect, a, 3.5)

		"pig":
			# หมู: ขุดดินหารากไม้/เห็ด (35%) > นอนเกลือกโคลน (25%) > กินอาหาร (25%) > เดินเล่น
			var cell = Vector2i(floori(a.pos.x), floori(a.pos.y))
			var t = Territory.at(sect, cell)
			if (t == Territory.T.DIRT or t == Territory.T.FIELD) and roll < 0.3:
				a.state = "wallow" # นอนแช่โคลน/ดินแฉะ
				a.target = a.pos
			elif roll < 0.65:
				a.state = "root" # ขุดดินหากิน
				a.hunger = maxf(0.0, a.hunger - 0.06)
				if a.pos.distance_to(a.target) < 0.5 or randf() < 0.3:
					a.target = a.pos + Vector2(randf_range(-2, 2), randf_range(-2, 2))
			else:
				a.state = "wander"
				if a.pos.distance_to(a.target) < 0.6 or randf() < 0.15:
					a.target = _herd_target(sect, a, 4.0)

		"cow":
			# วัว: กินหญ้า (40%) > ยืนเคี้ยวเอื้องนิ่งๆ (35%) > เดินตามฝูง (25%)
			if a.hunger > 0.35 and roll < 0.5:
				a.state = "graze"
				_graze(sect, a, sp)
			elif roll < 0.8:
				a.state = "chew_cud" # ยืนเคี้ยวเอื้องนิ่งๆ พักผ่อน
				a.hunger = maxf(0.0, a.hunger - 0.03)
				a.target = a.pos
			else:
				a.state = "wander"
				if a.pos.distance_to(a.target) < 0.6 or randf() < 0.12:
					a.target = _herd_target(sect, a, 6.0)

		_:
			# สัตว์ทั่วไป
			if a.hunger > 0.4:
				a.state = "graze"
				_graze(sect, a, sp)
			else:
				a.state = "wander"
				if a.pos.distance_to(a.target) < 0.6 or randf() < 0.15:
					a.target = _herd_target(sect, a, 4.0)

## กินหญ้าที่ช่องปัจจุบัน (หญ้าถูกกินแล้วงอกใหม่ใน GRAZE_REGROW_DAYS วัน) หมดหญ้า = ย้ายไปช่องใกล้ๆ
static func _graze(sect: SectData, a: Dictionary, sp: Dictionary) -> void:
	var c = Vector2i(int(floor(a.pos.x)), int(floor(a.pos.y)))
	var key = Territory.idx(c)
	var t = Territory.at(sect, c)
	var eaten_day = sect.grazed.get(key, -99)
	if (t == Territory.T.GRASS or t == Territory.T.DIRT) and sect.current_day - eaten_day >= GRAZE_REGROW_DAYS:
		a.hunger = maxf(0.0, a.hunger - sp.graze)
		if randf() < 0.25: sect.grazed[key] = sect.current_day
	else:
		a.target = a.pos + Vector2(randf_range(-3, 3), randf_range(-3, 3))

static func _herd_target(sect: SectData, a: Dictionary, max_dist := 5.0) -> Vector2:
	# เกาะกลุ่ม: ถ้าห่างเพื่อนในฝูงเกิน max_dist ช่อง ให้เดินเข้าหาเพื่อนที่ใกล้ที่สุด
	var mate: Dictionary = {}
	var bd = INF
	for o in sect.animals:
		if o != a and o.group == a.group and o.species == a.species:
			var d = o.pos.distance_to(a.pos)
			if d < bd:
				bd = d
				mate = o
	if not mate.is_empty() and bd > max_dist: return mate.pos
	return a.pos + Vector2(randf_range(-3, 3), randf_range(-3, 3))

## หมาป่า: หิวถึงออกล่า เลือกเหยื่อที่ไกลไฟและใกล้ที่สุด กลัวไฟ/ยามเว้นแต่หิวจัด
static func _think_wolf(sect: SectData, a: Dictionary, sp: Dictionary, prey: Array, fires: Array, guards: Array, mgr: SectManager, dead: Array) -> void:
	a.hunger = minf(1.0, a.hunger + 0.012)
	if a.hunger >= 1.0: a.hp -= 1.5
	var desperate = a.hunger > 0.75
	# กลัวไฟ/หอยาม
	if not desperate:
		for f in fires:
			if f.pos.distance_to(a.pos) < f.radius + 3.0:
				a.state = "flee_fire"
				a.target = a.pos + (a.pos - f.pos).normalized() * 8.0
				return
		for g in guards:
			if g.pos.distance_to(a.pos) < g.radius:
				a.state = "flee_guard"
				a.target = a.pos + (a.pos - g.pos).normalized() * 8.0
				return
	if a.hunger < 0.45 and not desperate:
		a.state = "wander"
		if a.pos.distance_to(a.target) < 0.6 or randf() < 0.1:
			a.target = a.pos + Vector2(randf_range(-6, 6), randf_range(-6, 6))
		return
	# ล่า: เหยื่อที่ใกล้ที่สุด (บวกคะแนนลบถ้าอยู่ใกล้ไฟ ไก่น่ากินกว่าวัว)
	var best: Dictionary = {}
	var best_score = INF
	for p in prey:
		if p.hp <= 0.0: continue # ถูกฆ่าไปแล้วในรอบนี้
		var d = p.pos.distance_to(a.pos)
		if d > 28.0: continue
		var s = d + (12.0 if _near_fire(fires, p.pos) and not desperate else 0.0) + (0.0 if p.species == "chicken" else 4.0)
		if s < best_score:
			best_score = s
			best = p
	if best.is_empty():
		a.state = "wander"
		a.target = a.pos + Vector2(randf_range(-8, 8), randf_range(-8, 8))
		return
	a.state = "hunt"
	a.target = best.pos
	if a.pos.distance_to(best.pos) <= 1.0:
		best.hp = 0.0
		if not dead.has(best): dead.append(best)
		a.hunger = 0.0
		a.state = "feast"
		sect.sim_stats["prey_lost"] = sect.sim_stats.get("prey_lost", 0) + 1
		if best.tame and sect.sim_stats.get("wolf_log_day", -1) != sect.current_day:
			sect.sim_stats["wolf_log_day"] = sect.current_day
			mgr.log_event("[color=orange]หมาป่าฆ่า%sที่เป็นสัตว์เลี้ยงของสำนักไปหนึ่งตัว! (ตั้งกองไฟ/หอยามให้ครอบคลุมคอก)[/color]" % AnimalDB.SPECIES[best.species].name)
	# หิวจัดอาจกัดศิษย์ที่อยู่ใกล้ (ศิษย์ประจำตึกใกล้ป่า)
	if desperate and randf() < 0.008:
		for d in sect.get_in_sect_disciples():
			if d.pos.distance_to(a.pos) < 2.5:
				var res = PawnSys.injure(d, randf_range(5, 10), "ถูกหมาป่ากัด")
				mgr.log_event("[color=red]%s ถูกหมาป่าที่หิวจัดกัด (%s)[/color]" % [d.disciple_name, res], [d])
				break

## ขยับไปหา target ตามความเร็ว (ช่องที่ไม่ผ่านได้ = เลือกเป้าใหม่)
static func _step(sect: SectData, a: Dictionary, sp: Dictionary) -> void:
	if a.state in ["peck", "chew_cud", "wallow"]:
		return # อยู่กับที่เพื่อทำกิจกรรม
	var to: Vector2 = a.target - a.pos
	var speed = sp.speed * (1.8 if a.state == "startle" else (1.5 if a.state in ["flee", "flee_fire", "flee_guard"] else (1.25 if a.state == "hunt" else 1.0)))
	if to.length() < 0.05: return
	var np: Vector2 = a.pos + to.normalized() * minf(speed, to.length())
	np.x = clampf(np.x, 1.0, Territory.SIZE - 1.5)
	np.y = clampf(np.y, 1.0, Territory.SIZE - 1.5)
	if _walkable(sect, sp, np):
		a.pos = np
	else:
		a.target = a.pos + Vector2(randf_range(-3, 3), randf_range(-3, 3))

# ══════════════════════════════════════════
# รายวัน: ผลผลิต ขยายพันธุ์ สุ่มเกิด ยามไล่หมาป่า
# ══════════════════════════════════════════

static func daily(sect: SectData, mgr: SectManager) -> void:
	var milk = 0
	var eggs = 0
	for a in sect.animals:
		var sp = AnimalDB.SPECIES[a.species]
		if not _walkable(sect, sp, a.pos): a.pos = _nearest_walkable(sect, sp, a.pos) # เซฟเก่าที่สัตว์ตกน้ำ
		if not a.tame: continue
		if a.hunger < 0.85:
			if a.species == "cow": milk += sp.produce_food
			elif a.species == "chicken": eggs += sp.produce_food
	if milk + eggs > 0:
		sect.food += int(ceil((milk + eggs) * 0.5))
		ProductionSys._stat(sect, "food_livestock", milk + eggs)
	_breed(sect, mgr)
	_guards_hunt(sect, mgr)
	_spawn(sect)
	# หญ้าที่งอกคืนแล้วลบออกจากบัญชี (กันโตไม่หยุด)
	if sect.grazed.size() > 400:
		for k in sect.grazed.keys():
			if sect.current_day - sect.grazed[k] >= GRAZE_REGROW_DAYS: sect.grazed.erase(k)

## สัตว์เลี้ยงใกล้ไฟมีโอกาสออกลูก
static func _breed(sect: SectData, mgr: SectManager) -> void:
	if sect.animals.size() >= MAX_ANIMALS: return
	var fire_levels = 0
	for inst in sect.instances("campfire"): fire_levels += int(inst.level)
	for sp_id in ["cow", "chicken", "pig"]:
		var tame = sect.animals.filter(func(a): return a.species == sp_id and a.tame)
		# ความจุคอก: ทุกระดับกองไฟรองรับสัตว์เลี้ยงเพิ่ม (วัว 4 / ไก่ 6)
		var cap = ({"cow": 4, "pig": 4}.get(sp_id, 6)) * (1 + fire_levels)
		if tame.size() < 2 or tame.size() >= cap: continue
		if randf() < 0.04 * minf(tame.size(), 6):
			var mom: Dictionary = tame[randi() % tame.size()]
			var baby = make(sect, sp_id, mom.pos + Vector2(randf_range(-1, 1), randf_range(-1, 1)), mom.group)
			baby.tame = true
			baby.state = "tame"

## ยาม (หอยาม/ค่ายกล) ไล่หรือฆ่าหมาป่าในรัศมี
static func _guards_hunt(sect: SectData, mgr: SectManager) -> void:
	for g in guard_posts(sect):
		for w in sect.animals.filter(func(a): return a.species == "wolf" and a.pos.distance_to(g.pos) <= g.radius + 2.0):
			var chance = clampf(0.1 + g.power / 400.0, 0.1, 0.8)
			if randf() < chance:
				w.hp = 0.0
				sect.animals.erase(w)
				sect.add_material("beast_hide", 1)
				sect.prestige += 1
				ProductionSys._stat(sect, "wolves_killed", 1)
				for d in g.crew: d.add_fame(1)
				mgr.log_event("ศิษย์ที่เฝ้ายามสังหารหมาป่าที่เข้ามาใกล้สำนัก ได้หนังหมาป่า 1 ผืน")

## สุ่มเกิดสัตว์ป่า: วัว/ไก่เป็นฝูงบนหญ้าไกลจากสำนัก · หมาป่าเป็นฝูงที่ชายป่า (ตามจำนวนเหยื่อ)
static func _spawn(sect: SectData) -> void:
	if sect.animals.size() >= MAX_ANIMALS: return
	for sp_id in ["cow", "chicken", "pig"]:
		var sp = AnimalDB.SPECIES[sp_id]
		if count(sect, sp_id) < sp.spawn_target and randf() < 0.4:
			var p = _random_cell(sect, Territory.T.GRASS, 12.0, 30.0)
			if p.x < 0: continue
			var group = sect.next_animal_id
			var n = randi_range(sp.herd[0], sp.herd[1])
			for i in n: make(sect, sp_id, Vector2(p) + Vector2(randf_range(-2, 2), randf_range(-2, 2)), group)
	var prey = count(sect, "cow") + count(sect, "chicken") + count(sect, "pig")
	var max_wolves = mini(MAX_WOLVES, 1 + prey / 7)
	if count(sect, "wolf") < max_wolves and sect.current_day >= 6 and randf() < 0.3:
		var p = _random_cell(sect, Territory.T.FOREST, 26.0, 44.0)
		if p.x >= 0:
			var sp = AnimalDB.SPECIES["wolf"]
			var group = sect.next_animal_id
			for i in randi_range(sp.pack[0], sp.pack[1]):
				var w = make(sect, "wolf", Vector2(p) + Vector2(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5)), group)
				w.hunger = randf_range(0.5, 0.9)

## สุ่มช่องภูมิประเทศ t ที่ห่างจาก HOME ระหว่าง rmin..rmax (คืน (-1,-1) ถ้าหาไม่ได้)
static func _random_cell(sect: SectData, t: int, rmin: float, rmax: float) -> Vector2i:
	for i in 30:
		var ang = randf() * TAU
		var r = randf_range(rmin, rmax)
		var c = Territory.HOME + Vector2i(int(cos(ang) * r), int(sin(ang) * r))
		if Territory.in_bounds(c) and Territory.at(sect, c) == t: return c
	return Vector2i(-1, -1)

## สรุปข้อความสั้นๆ ให้ UI
static func summary(sect: SectData) -> String:
	return "วัว %d (เลี้ยง %d) · หมู %d · ไก่ %d (เลี้ยง %d) · หมาป่า %d" % [count(sect, "cow"), count(sect, "cow", true), count(sect, "pig"), count(sect, "chicken"), count(sect, "chicken", true), count(sect, "wolf")]
