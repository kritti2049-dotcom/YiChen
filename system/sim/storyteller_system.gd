extends RefCounted
class_name StorytellerSystem

## เจตจำนงสวรรค์ (AI Storyteller)
## 1) ความมั่งคั่ง = ของในคลัง 100% + อาคาร/อุปกรณ์ที่ติดตั้งแล้ว 50% + ศิษย์ (ค่าคงที่ต่อหัว ไม่ว่าเก่งหรือพิการ)
## 2) คะแนนภัย = f(ความมั่งคั่ง) แบบเส้นโค้งชะลอตัว x ตัวคูณปรับตัว x ผู้กำกับ (ไม่เกิน Hard Cap)
##    ตัวคูณปรับตัว: ไม่สูญเสียนาน -> สูงขึ้น, เพิ่งเสียคนสำคัญ -> ลดลง เปิดช่วงให้ฟื้นตัว
## 3) ใช้คะแนนซื้อศัตรู (ราคาต่อชนิด) จนคะแนนหมด
## 4) เหตุการณ์ผสม: ภัย (บุก โรคระบาด สัตว์อสูรอาละวาด สัตว์อสูรใต้ดิน ไฟไหม้) / โอกาส (คนพเนจรขอเข้าสำนัก กองคาราวาน แร่วิญญาณ)
## หมายเหตุ: "จำนวนศิษย์" มีผลแค่ความถี่ของคนขอเข้าสำนัก ไม่ผูกกับขนาดภัย
## 5) สเกลยุทธภพ: ครอบครอง "กระบี่มหาโชคมาร" / เงินทะลุ 100,000 / ชื่อเสียงระบือ = ถูกหมายตา
##    หน่วยเหยี่ยวเงา/สำนักคู่แข่ง/กองโจรจัดทัพมาบุกเป็นพิเศษ (targeted_raid) ผู้เล่นรับมือด้วยค่ายกล + ศิษย์ประจำค่ายกล

static func wealth_breakdown(sect: SectData) -> Dictionary:
	var items = sect.money + int(sect.food * 0.3) + sect.meals * 12
	for m in sect.materials: items += MaterialDB.get_price(m) * sect.materials[m]
	for k in sect.pills: items += 60 * sect.pills[k]
	for eq in sect.equipment_storage: items += eq.get_value()
	items += AnimalSys.livestock_value(sect)
	var installed = 0.0
	for inst in sect.structures:
		for i in int(inst.level):
			var c = BuildingDB.get_upgrade_cost(inst.type, i)
			installed += c.money + c.materials.get("wood", 0) * 2 + c.materials.get("stone", 0) * 2
	var pawns = PawnSys.present(sect).size()
	for d in sect.get_active_disciples():
		for eq in d.get_equipped_items(): installed += eq.get_value()
	return { "items": items, "installed": installed * 0.5, "pawns": pawns * StorytellerDB.PAWN_VALUE, "total": items + installed * 0.5 + pawns * StorytellerDB.PAWN_VALUE }

## เส้นโค้งชะลอตัว: ความมั่งคั่ง 2,600 ≈ 90, 20,000 ≈ 320, 100,000 ≈ 870
static func curve(wealth: float) -> float:
	return 12.0 * pow(max(wealth, 100.0) / 100.0, 0.62)

static func threat_points(sect: SectData) -> float:
	var t = StorytellerDB.get_teller(sect.storyteller)
	var w = wealth_breakdown(sect).total * t.wealth_weight
	var adapt = sect.adaptation if sect.storyteller != "chaos" else lerpf(1.0, sect.adaptation, 0.3)
	return min(StorytellerDB.HARD_CAP, curve(w) * adapt * t.threat_mult * BuildingDB.diff(sect.difficulty).invasion * early_ramp(sect))

## ช่วงตั้งตัว: 50 วันแรกภัยเบากว่าปกติ (เริ่มที่ 40%) ให้สำนักใหม่มีเวลาสร้างแนวป้องกัน
static func early_ramp(sect: SectData) -> float:
	return clampf(0.4 + sect.current_day / 50.0 * 0.6, 0.4, 1.0)

## ยุทธภพหมายตาเมื่อเงินถึงเท่านี้ / ชื่อเสียงรวมของศิษย์ถึงเท่านี้ / บารมีสำนักถึงเท่านี้
const WEALTH_LURE = 100000
const FAME_LURE = 2000
const PRESTIGE_LURE = 300
## ระยะห่างขั้นต่ำระหว่างการถูกบุกเพราะถูกหมายตา (วัน)
const TARGETED_COOLDOWN = 30

static func owns_cursed_sword(sect: SectData) -> bool:
	for eq in sect.equipment_storage:
		if eq.item_name == EquipmentDB.CURSED_SWORD: return true
	for d in sect.get_active_disciples():
		for eq in d.get_equipped_items():
			if eq.item_name == EquipmentDB.CURSED_SWORD: return true
	return false

static func total_fame(sect: SectData) -> int:
	var n = 0
	for d in sect.get_active_disciples(): n += d.fame
	return n

## ชื่อเสียงขจรขจาย: แยกที่มาเพื่อแสดงใน UI { "sword": bool, "wealth": int, "fame": int, "prestige": int, "score": int }
static func notoriety(sect: SectData) -> Dictionary:
	var sword = owns_cursed_sword(sect)
	var fame = total_fame(sect)
	var score = fame * 0.5 + sect.prestige * 5 + sect.money / 200.0 + (1000 if sword else 0)
	return { "sword": sword, "wealth": sect.money, "fame": fame, "prestige": sect.prestige, "score": int(score), "tier": ReputationSys.tier_name(sect) }

## เหตุผลที่ยุทธภพหมายตาสำนักตอนนี้ ("" = ยังไม่ถูกหมายตา)
static func lure_reason(sect: SectData) -> String:
	if owns_cursed_sword(sect): return "sword"
	if sect.money >= WEALTH_LURE: return "wealth"
	if total_fame(sect) >= FAME_LURE or sect.prestige >= PRESTIGE_LURE: return "fame"
	return ""

const LURE_TEXT = {
	"sword": "ครอบครอง %s (หน่วยเหยี่ยวเงาและสำนักคู่แข่งตามล่า)" % EquipmentDB.CURSED_SWORD,
	"wealth": "ทรัพย์สินทะลุ %d (กองโจรและหน่วยเหยี่ยวเงาหมายตา)" % WEALTH_LURE,
	"fame": "ชื่อเสียงระบือยุทธภพ (สำนักคู่แข่งยกทัพมาท้าทาย)",
}

## ฝ่ายศัตรูที่แข็งแกร่งที่สุดที่ไม่ถูกกับเรา ("" = ไม่มี)
static func _strongest_hostile(sect: SectData) -> String:
	var best = ""
	for fid in sect.factions:
		var f = sect.factions[fid]
		if f.relation >= 0 or not FactionDB.FACTIONS.has(fid): continue
		if best == "" or f.power > sect.factions[best].power: best = fid
	return best

## ทัพบุกเพราะถูกหมายตา (ข้ามช่วงห่างของผู้กำกับ มีระยะพัก TARGETED_COOLDOWN วัน)
static func targeted_raid(sect: SectData, mgr: SectManager, reason: String) -> void:
	var points = max(threat_points(sect), 150.0) * (1.6 if reason == "sword" else 1.25)
	var fid = ""
	var pool: Array = StorytellerDB.RAID_POOL
	var who = ""
	match reason:
		"sword":
			fid = "f_hawk" if sect.factions.has("f_hawk") and randf() < 0.6 else _strongest_hostile(sect)
			pool = StorytellerDB.RAID_POOL.filter(func(e): return e.tag in ["hawk", "cult"])
			who = "หน่วยเหยี่ยวเงาและสำนักคู่แข่งที่ตามล่า%s" % EquipmentDB.CURSED_SWORD
		"wealth":
			pool = StorytellerDB.RAID_POOL.filter(func(e): return e.tag in ["bandit", "hawk"])
			who = "กองโจรและหน่วยเหยี่ยวเงาที่หมายตาทรัพย์สำนัก"
		_:
			fid = _strongest_hostile(sect)
			pool = StorytellerDB.RAID_POOL.filter(func(e): return e.tag in ["cult", "hawk", "dragon"])
			who = "สำนักคู่แข่งที่มาท้าทายชื่อเสียงสำนัก"
	var enemies = buy_enemies(points, pool)
	if fid != "": who = FactionSys.fname(fid) + (" (ตามล่า%s)" % EquipmentDB.CURSED_SWORD if reason == "sword" else " (ท้าทายชื่อเสียงสำนัก)")
	sect.pending_event = { "type": "raid", "enemies": enemies, "faction": fid, "points": int(points), "who": who, "targeted": reason, "deadline": sect.total_ticks + 90 }
	sect.last_raid_day = sect.current_day
	sect.last_targeted_day = sect.current_day
	sect.sim_stats["raids"] = sect.sim_stats.get("raids", 0) + 1
	sect.sim_stats["targeted_raids"] = sect.sim_stats.get("targeted_raids", 0) + 1
	mgr.log_event("[color=red]ยุทธภพหมายตาสำนัก! %s บุกสำนัก (%d ตน คะแนนภัย %d) เพราะ %s[/color]" % [who, enemies.size(), int(points), LURE_TEXT.get(reason, "")])

static func daily(sect: SectData, mgr: SectManager) -> void:
	var day = sect.current_day
	sect.sim_stats["wealth"] = int(wealth_breakdown(sect).total)
	# ตัวคูณปรับตัว: สงบสุขไม่มีใครบาดเจ็บสาหัส = ค่อยๆ เพิ่ม
	var hurt = PawnSys.present(sect).any(func(d): return d.status == DiscipleData.DiscipleStatus.INJURED)
	sect.adaptation = clampf(sect.adaptation + (-0.02 if hurt else 0.012), 0.4, 1.6)
	var lure = lure_reason(sect)
	if lure != "" and sect.pending_event.is_empty() and day - sect.last_targeted_day >= TARGETED_COOLDOWN and day >= 12:
		targeted_raid(sect, mgr, lure)
		return
	if day < sect.next_event_day: return
	var t = StorytellerDB.get_teller(sect.storyteller)
	sect.next_event_day = day + randi_range(t.gap[0], t.gap[1])
	_fire_event(sect, mgr, _pick_event(sect))

static func _pick_event(sect: SectData) -> String:
	var pawns = PawnSys.present(sect).size()
	var weights = {
		"raid": 45.0 if sect.current_day >= 12 else 0.0,
		"plague": 7.0, "beasts": 10.0, "fire": 4.0,
		"underground": sect.tremor * 15.0,
		# ความถี่ของคนขอเข้าสำนัก (ยิ่งศิษย์น้อยยิ่งบ่อย) ไม่เกี่ยวกับขนาดภัย
		"wanderer": 16.0 * max(0.15, 1.0 - pawns / 12.0),
		"caravan": 12.0 if sect.caravan.is_empty() else 0.0, "spirit_ore": 8.0,
	}
	var total = 0.0
	for k in weights: total += weights[k]
	var roll = randf() * total
	for k in weights:
		roll -= weights[k]
		if roll <= 0: return k
	return "raid"

## ซื้อศัตรูด้วยคะแนนภัย
static func buy_enemies(points: float, pool: Array) -> Array[String]:
	var result: Array[String] = []
	var left = points
	var avail = pool.filter(func(e): return e.min_threat <= points)
	while result.size() < StorytellerDB.MAX_RAIDERS:
		var affordable = avail.filter(func(e): return e.cost <= left)
		if affordable.is_empty(): break
		# ชอบซื้อตัวแพงที่สุดที่ซื้อไหวเป็นแกนหลัก แล้วเติมตัวเสริม
		affordable.sort_custom(func(a, b): return a.cost > b.cost)
		var pick = affordable[0] if result.is_empty() or randf() < 0.4 else affordable[randi() % affordable.size()]
		result.append(pick.enemy)
		left -= pick.cost
	if result.is_empty(): result.append(pool[0].enemy)
	return result

static func _fire_event(sect: SectData, mgr: SectManager, kind: String) -> void:
	var t = StorytellerDB.get_teller(sect.storyteller)
	var points = threat_points(sect) * (1.0 + randf_range(-t.threat_jitter, t.threat_jitter))
	if t.big_after > 0 and sect.current_day - sect.last_raid_day > t.big_after: points *= 1.4
	sect.sim_stats["events"] = sect.sim_stats.get("events", 0) + 1
	match kind:
		"raid", "underground":
			var pool = StorytellerDB.UNDERGROUND_POOL if kind == "underground" else StorytellerDB.RAID_POOL
			if kind == "underground": points = max(points * 0.6, sect.tremor * 120.0)
			var enemies = buy_enemies(points, pool)
			var fid = ""
			var at_war = sect.factions.keys().filter(func(f): return sect.factions[f].war)
			if kind == "raid" and not at_war.is_empty() and randf() < 0.5: fid = at_war[randi() % at_war.size()]
			var who = FactionSys.fname(fid) if fid != "" else ("สัตว์อสูรใต้ดิน (จากการขุดเหมืองลึก)" if kind == "underground" else EnemyDB.ENEMIES[enemies[0]].name)
			sect.pending_event = { "type": "raid", "enemies": enemies, "faction": fid, "points": int(points), "who": who, "deadline": sect.total_ticks + 90 }
			sect.last_raid_day = sect.current_day
			if kind == "underground": sect.tremor = 0.0
			sect.sim_stats["raids"] = sect.sim_stats.get("raids", 0) + 1
			mgr.log_event("[color=red]เจตจำนงสวรรค์: %s บุกสำนัก! (%d ตน คะแนนภัย %d)[/color]" % [who, enemies.size(), int(points)])
		"plague":
			var sick: Array[String] = []
			for d in PawnSys.present(sect):
				if randf() < 0.45 and d.get_stat("immune") < 7:
					d.add_ailment("fever")
					sick.append(d.disciple_name)
			mgr.log_event("[color=orange]โรคไข้ป่าระบาดในสำนัก! ป่วย: %s (ให้หมอรักษา)[/color]" % (", ".join(sick) if not sick.is_empty() else "ไม่มีใครติด"))
		"beasts":
			var guards = PawnSys.present(sect).filter(func(d): return BuildingDB.post_type(sect, d) in ["sect_formation", "watchtower"] and d.can_fight())
			var defense = 0
			for g in guards: defense += g.get_power_rating()
			if defense >= points * 0.5:
				for g in guards: PawnSys.add_thought(g, sect, "won_battle")
				mgr.log_event("[color=lime]ฝูงสัตว์อสูรอาละวาดรอบสำนัก แต่ยามเฝ้าประตูขับไล่ไปได้[/color]")
			else:
				var victims = PawnSys.present(sect).filter(func(d): return not d.is_child)
				victims.shuffle()
				var names: Array[String] = []
				for v in victims.slice(0, 2):
					names.append("%s (%s)" % [v.disciple_name, PawnSys.injure(v, randf_range(6, 16), "ถูกสัตว์อสูรขย้ำ")])
					HealthSystem.check_death(sect, v, mgr)
				sect.food = int(sect.food * 0.85)
				mgr.log_event("[color=red]ฝูงสัตว์อสูรอาละวาดกลางดึก! บาดเจ็บ: %s (ให้ศิษย์ประจำหอยาม/ค่ายกลเพื่อป้องกัน)[/color]" % ", ".join(names))
		"fire":
			var built = sect.structures.filter(func(i): return int(i.level) > 0 and i.type != "campfire")
			if built.is_empty(): return
			var b: Dictionary = built[randi() % built.size()]
			sect.fires[b.uid] = 0.25
			mgr.log_event("[color=red]ฟ้าผ่าลงที่%s เกิดไฟไหม้! (ศิษย์ในสำนักช่วยกันดับไฟ ยิ่งมีคนว่างยิ่งดับเร็ว)[/color]" % BuildingDB.inst_name(b))
		"wanderer":
			var made = ApplicantSys.spawn(sect, 1, "คนพเนจรผ่านมาขอพักพิง")
			if not made.is_empty(): mgr.log_event("[color=lime]มีคนพเนจรมาขอเข้าสำนัก: %s (ดูที่เมนู ประตูสำนัก)[/color]" % made[0].npc.disciple_name)
		"caravan":
			var stock = []
			var mats = MaterialDB.MATERIALS.keys().filter(func(m): return m != "scripture_fragment" or randf() < 0.3)
			mats.shuffle()
			for m in mats.slice(0, 5): stock.append({ "mat": m, "amount": randi_range(3, 15) })
			sect.caravan = { "until": sect.current_day + 3, "stock": stock }
			mgr.log_event("[color=gold]กองคาราวานพ่อค้ามาตั้งร้านหน้าสำนัก 3 วัน (ซื้อขายได้ที่เมนู กองคาราวาน, คิดค่าธรรมเนียม 20%%)[/color]")
		"spirit_ore":
			var n = randi_range(4, 8)
			sect.add_material("spirit_stone", n)
			sect.add_material("star_metal", 1)
			mgr.log_event("[color=gold]พบแร่วิญญาณใกล้สำนัก! ผลึกวิญญาณ %d ก้อนและโลหะดารา 1 ก้อนเข้าคลัง (ความมั่งคั่งพุ่ง = ภัยครั้งหน้าแรงขึ้น)[/color]" % n)

# ══════════════════════════════════════════
# ศัตรูบุก: ต่อสู้เอง หรือ ตั้งรับอัตโนมัติ
# ══════════════════════════════════════════

static func raid_enemies(sect: SectData) -> Array[Dictionary]:
	var ev = sect.pending_event
	var result: Array[Dictionary] = []
	if ev.get("faction", "") != "":
		result = FactionSys.make_enemies(sect, ev.faction, ev.enemies.size(), ev.enemies.size() >= 3)
	else:
		for id in ev.enemies: result.append(EnemyDB.get_enemy(id))
	return result

static func defenders(sect: SectData) -> Array[DiscipleData]:
	# คำนวณพลังรบครั้งเดียวต่อคน (get_power_rating แพง ห้ามเรียกซ้ำในตัวเปรียบเทียบ)
	var pairs: Array = []
	for d in PawnSys.present(sect):
		if d.can_fight(): pairs.append([d.get_power_rating(), d])
	pairs.sort_custom(func(a, b): return a[0] > b[0])
	var result: Array[DiscipleData] = []
	for p in pairs: result.append(p[1])
	return result

## ตั้งรับอัตโนมัติ: ค่ายกล + พลังศิษย์ (ยามเต็มแรง คนอื่นครึ่งเดียว) เทียบพลังผู้บุก
static func auto_defend(sect: SectData, mgr: SectManager) -> void:
	var ev = sect.pending_event
	sect.pending_event = {}
	var enemies = raid_enemies_from(sect, ev)
	var attack = 0
	for e in enemies: attack += StatSys.combat_power(e.attack, e.max_hp, e.speed, 0, 0)
	attack = int(attack * BuildingDB.diff(sect.difficulty).enemy)
	var formation = BuildingDB.get_formation_defense(sect)
	var defense = formation
	var fighters = defenders(sect)
	var posted = 0
	for d in fighters:
		var on_post = BuildingDB.post_type(sect, d) in ["sect_formation", "watchtower"]
		if on_post: posted += 1
		defense += int(d.get_power_rating() * (1.0 if on_post else 0.7))
	mgr.log_event("[color=orange]ตั้งรับ %s อัตโนมัติ (พลังบุก %d / พลังป้องกัน %d: ค่ายกล %d · ศิษย์ประจำค่ายกล %d)[/color]" % [ev.who, attack, defense, formation, posted])
	if defense * randf_range(0.85, 1.15) >= attack:
		raid_won(sect, enemies, fighters, ev, mgr)
	else:
		raid_lost(sect, fighters.slice(0, 3), ev, mgr)

static func raid_enemies_from(sect: SectData, ev: Dictionary) -> Array[Dictionary]:
	var keep = sect.pending_event
	sect.pending_event = ev
	var result = raid_enemies(sect)
	sect.pending_event = keep
	return result

static func raid_won(sect: SectData, enemies: Array, fighters: Array, ev: Dictionary, mgr: SectManager) -> void:
	var loot = 60 + sect.current_day + int(ev.get("points", 0) * 0.5)
	sect.money += loot
	sect.prestige += 5
	ReputationSys.add_alignment(sect, 1)
	for d in fighters:
		d.add_fame(3)
		PawnSys.add_thought(d, sect, "won_battle")
	if ev.get("faction", "") != "": sect.factions[ev.faction].power = int(sect.factions[ev.faction].power * 0.95)
	mgr.log_event("[color=green]ขับไล่ %s สำเร็จ! ได้รับเงิน %d[/color]" % [ev.get("who", "ผู้บุกรุก"), loot])
	if not enemies.is_empty() and randf() < 0.35:
		var e = enemies[randi() % enemies.size()]
		if e.get("art", "human") == "human": PrisonerSys.capture(sect, e, mgr)

static func raid_lost(sect: SectData, hurt: Array, ev: Dictionary, mgr: SectManager) -> void:
	EndingSys.note_raider(sect, ev.get("who", "ผู้บุกรุก"))
	var lost_money = int(max(0, sect.money) * 0.2)
	var lost_food = int(max(0, sect.food) * 0.3)
	sect.money -= lost_money
	sect.food -= lost_food
	sect.meals = int(sect.meals * 0.6)
	var names: Array[String] = []
	for d in hurt:
		names.append("%s (%s)" % [d.disciple_name, PawnSys.injure(d, randf_range(4, 11), "บาดเจ็บจาก%s" % ev.get("who", "ผู้บุกรุก"))])
		PawnSys.add_thought(d, sect, "lost_battle")
		StressSystem.add(d, 25.0)
		if randf() < BuildingDB.diff(sect.difficulty).death:
			HealthSystem.kill(sect, d, "ถูก%sสังหารระหว่างบุกสำนัก" % ev.get("who", "ผู้บุกรุก"), mgr, ev.get("faction", ""))
		else:
			HealthSystem.check_death(sect, d, mgr)
	sect.adaptation = max(0.4, sect.adaptation - 0.08)
	mgr.log_event("[color=red]ป้องกันไม่สำเร็จ! ถูกปล้นเงิน %d เสบียง %d บาดเจ็บ: %s[/color]" % [lost_money, lost_food, ", ".join(names) if not names.is_empty() else "-"])
