extends RefCounted
class_name FactionSys

## การเมืองยุทธภพ (4X) บนแผนที่ตามตำนานพิภพโลหิตชาด
## - Seed Scrambler: ตำแหน่งตายตัว แต่ Seed สุ่ม ความสัมพันธ์ / เจ้าเมือง / ผลผลิต / พลังเริ่มต้น / เหตุการณ์
## - Faction AI: แต่ละฝ่าย (ธรรมะ / มาร / สิบขันทีเงา / อิสระ / ชายขอบ) เดินหมากบนแผนที่ด้วยนิสัยของตัวเอง
## - การทูตกับสำนักเรา: ของกำนัล / ประกาศสงคราม / สงบศึก / ส่วยสิบขันที
## - ประชุมยุทธภพทุก CONFERENCE_INTERVAL วัน: 8 สำนักใหญ่ของพันธมิตรโหวตเลือก "จ้าวยุทธภพ"
## - ทำเนียบยุทธภพ (จัดอันดับยอดฝีมือ) ฉายา และบุญคุณความแค้น

const CONFERENCE_INTERVAL = 120
const NODE_INCOME = 15
const LEADER_INCOME = 100
## เหตุการณ์ระหว่างขั้วอำนาจ (สุ่มตาม Seed) ทุกกี่วัน
const EVENT_INTERVAL = 8
## สิบขันทีเรียกส่วยทุกกี่วัน และให้เวลาจ่ายกี่วัน
const TRIBUTE_INTERVAL = 45
const TRIBUTE_DAYS = 10

## นิสัยของ AI แต่ละฝ่าย: interval = เดินหมากทุกกี่วัน (ที่ความยากปานกลาง), aggression = โอกาสเลือกโจมตี
const BLOC_AI = {
	"righteous": { "interval": 6, "offset": 1, "aggression": 0.45 },
	"demonic": { "interval": 4, "offset": 2, "aggression": 0.75 },
	"eunuch": { "interval": 5, "offset": 3, "aggression": 0.3 },
	"independent": { "interval": 9, "offset": 4, "aggression": 0.25 },
	"foreign": { "interval": 7, "offset": 5, "aggression": 0.5 },
}

## สุ่มแบบกำหนดผลตาม Seed ของโลก (โลกเดียวกัน = ประวัติศาสตร์เริ่มต้นเหมือนกัน)
static func _rng(sect: SectData, salt: int) -> RandomNumberGenerator:
	var rng = RandomNumberGenerator.new()
	rng.seed = hash([sect.world_seed, salt])
	return rng

## ผู้นำของฝ่ายขันที (โหมดเนื้อเรื่อง = จ้าวอิง, แซนด์บ็อกซ์ = ชื่อสุ่ม)
static func eunuch_leader() -> String:
	return "ขันที" + FactionDB.FACTIONS.get("f_eunuchs", {}).get("leader", "ผู้กุมอำนาจ")

## ชื่อเมืองหลวง (ที่ราชสำนักตั้งอยู่)
static func capital_name() -> String:
	return WorldDB.NODES.get(FactionDB.FACTIONS.get("f_court", {}).get("seat", ""), {}).get("name", "เมืองหลวง")

static func fname(fid: String) -> String:
	if fid == "player": return "สำนักเรา"
	return FactionDB.FACTIONS.get(fid, {}).get("name", "?")

static func _node_name(node_id: String) -> String:
	return WorldDB.NODES.get(node_id, {}).get("name", "?")

static func _region_tag(sect: SectData, node_id: String) -> String:
	return "[%s] " % WorldDB.get_region_name(WorldGen.for_sect(sect).poi_region(node_id))

# ══════════════════════════════════════════
# เริ่มต้นโลก (Seed Scrambler)
# ══════════════════════════════════════════

static func init_world(sect: SectData) -> void:
	var dm = BuildingDB.diff(sect.difficulty)
	var rng = _rng(sect, 1)
	for id in FactionDB.FACTIONS:
		var f = FactionDB.FACTIONS[id]
		if not sect.factions.has(id):
			sect.factions[id] = {
				"power": int(f.power * rng.randf_range(0.8, 1.2) * (0.8 + 0.2 * dm.faction_growth)),
				"relation": FactionDB.START_RELATION[f.align] + rng.randi_range(-15, 15),
				"war": false,
			}
		if WorldDB.NODES.has(f.seat) and WorldDB.NODES[f.seat].type != WorldDB.NodeType.CITY:
			sect.node_owner[f.seat] = id
	sect.node_owner["sect"] = "player"

	var fresh = sect.faction_rel.is_empty()
	if fresh:
		# ความสัมพันธ์ระหว่างขั้วอำนาจ: ตามตำนาน +- สุ่มตาม Seed
		var ids = FactionDB.FACTIONS.keys()
		for i in ids.size():
			for j in range(i + 1, ids.size()):
				sect.faction_rel[rel_key(ids[i], ids[j])] = clampi(FactionDB.lore_relation(ids[i], ids[j]) + rng.randi_range(-20, 20), -100, 100)

	# เจ้าเมือง: สุ่มจากขั้วอำนาจที่มีอิทธิพลในเมืองนั้น
	for city in WorldDB.NODES:
		var n = WorldDB.NODES[city]
		if n.type != WorldDB.NodeType.CITY or sect.city_lords.has(city): continue
		var lord: String = n.lords[rng.randi() % n.lords.size()]
		sect.city_lords[city] = { "name": _random_name(rng, lord), "faction": lord }
		if not sect.node_owner.has(city) or sect.node_owner[city] != "player":
			sect.node_owner[city] = lord

	# ผลผลิตของแต่ละพื้นที่
	for id in WorldDB.NODES:
		var t = WorldDB.NODES[id].type
		if t in [WorldDB.NodeType.WILD, WorldDB.NodeType.DUNGEON, WorldDB.NodeType.CITY] and not sect.node_yield.has(id):
			sect.node_yield[id] = snappedf(rng.randf_range(0.6, 1.6), 0.05)

	if fresh:
		# อาณาเขตเริ่มต้น: พื้นที่ป่า/ดันเจี้ยนใกล้ฐานที่มั่นมีโอกาสอยู่ใต้อิทธิพลของสำนักนั้น
		var world = WorldGen.for_sect(sect)
		for id in WorldDB.NODES:
			if not WorldDB.NODES[id].type in [WorldDB.NodeType.WILD, WorldDB.NodeType.DUNGEON]: continue
			var best = ""
			var best_d = 9.0
			for fid in FactionDB.FACTIONS:
				var seat: String = FactionDB.FACTIONS[fid].seat
				var dist = Vector2(world.poi[seat]).distance_to(Vector2(world.poi[id]))
				if dist < best_d:
					best_d = dist
					best = fid
			if best != "" and rng.randf() < 0.55:
				sect.node_owner[id] = best

	if sect.champions.is_empty():
		for id in FactionDB.FACTIONS:
			var n = 2 if FactionDB.FACTIONS[id].great or FactionDB.FACTIONS[id].power >= 40000 else 1
			for i in n:
				sect.champions.append(_make_champion(sect, id, rng, i == 0))

static func _random_name(rng: RandomNumberGenerator, fid: String) -> String:
	var female = rng.randf() < (0.9 if fid in ["f_qinmu", "f_hundred_flowers"] else 0.3)
	var first = NPCGenerator.FEMALE_NAMES if female else NPCGenerator.FIRST_NAMES
	if fid == "f_golden_luohan": return "หลวงจีน" + first[rng.randi() % first.size()]
	return NPCGenerator.SURNAMES[rng.randi() % NPCGenerator.SURNAMES.size()] + first[rng.randi() % first.size()]

## ยอดฝีมือของขั้วอำนาจ (คนแรกของแต่ละสำนักคือประมุขในตำนาน ถ้ามี)
static func _make_champion(sect: SectData, fid: String, rng: RandomNumberGenerator, is_leader: bool) -> Dictionary:
	var f = FactionDB.FACTIONS[fid]
	var champ_name = f.leader if is_leader and f.leader != "" else _random_name(rng, fid)
	var power = int(sect.factions[fid].power * (rng.randf_range(0.3, 0.45) if is_leader else rng.randf_range(0.12, 0.25)))
	return {
		"name": champ_name, "faction": fid, "power": power, "fame": rng.randi_range(150, 700) if is_leader else rng.randi_range(60, 300),
		"title": _title_from(f.style, CultivationSys.ELEMENT_COLORS.keys()[rng.randi() % 6], f.align == "มาร"),
	}

# ══════════════════════════════════════════
# ความสัมพันธ์ระหว่างขั้วอำนาจ
# ══════════════════════════════════════════

static func rel_key(a: String, b: String) -> String:
	return a + "|" + b if a < b else b + "|" + a

static func get_rel(sect: SectData, a: String, b: String) -> int:
	if a == b: return 100
	if a == "player": return sect.factions[b].relation
	if b == "player": return sect.factions[a].relation
	return sect.faction_rel.get(rel_key(a, b), FactionDB.lore_relation(a, b))

static func change_rel(sect: SectData, a: String, b: String, delta: int) -> void:
	if a == b or a == "" or b == "": return
	if a == "player" or b == "player":
		var other = b if a == "player" else a
		sect.factions[other].relation = clampi(sect.factions[other].relation + delta, -100, 100)
		return
	sect.faction_rel[rel_key(a, b)] = clampi(get_rel(sect, a, b) + delta, -100, 100)

## กำลังของหน่วยรบทั่วไป (ศิษย์ธรรมดา) ของขั้วอำนาจนี้ ในสเกลพลังรบรวม
static func squad_power(sect: SectData, fid: String) -> float:
	if not sect.factions.has(fid): return StatSys.world_threat(sect.current_day)
	return 15.0 + sect.factions[fid].power * 0.0008

# ══════════════════════════════════════════
# จำลองโลกรายวัน
# ══════════════════════════════════════════

static func daily(sect: SectData, day: int, log: Callable) -> void:
	var dm = BuildingDB.diff(sect.difficulty)
	for id in sect.factions:
		var f = sect.factions[id]
		f.power = int(f.power * (1.0 + 0.0004 * dm.faction_growth)) + randi_range(0, 2)
		# สำนักที่บอบช้ำหนักค่อยๆ ฟื้นกำลัง (รับศิษย์ใหม่ / รวบรวมพันธมิตร)
		var base_power: int = FactionDB.FACTIONS[id].power
		if f.power < base_power * 0.8:
			f.power += int(base_power * 0.002)
		# ความสัมพันธ์กับสำนักเราค่อยๆ คืนสู่ค่าตั้งต้น (ยกเว้นตอนทำสงคราม)
		var base = FactionDB.START_RELATION[FactionDB.FACTIONS[id].align]
		if not f.war and day % 5 == 0 and f.relation != base:
			f.relation += sign(base - f.relation)
		# ความสัมพันธ์แย่มาก -> ประกาศสงครามเอง
		if not f.war and f.relation <= -60 and randf() < 0.15:
			f.war = true
			log.call("[color=red]%s ประกาศสงครามกับสำนักเรา![/color]" % fname(id))
	for c in sect.champions:
		c.power = int(c.power * (1.0 + 0.0004 * dm.faction_growth))
		c.fame += randi_range(0, 2)

	# AI ของแต่ละฝ่ายเดินหมาก (ยิ่งยาก ยิ่งเดินถี่)
	var pace = dm.expand_days / 20.0
	for bloc in BLOC_AI:
		var interval = max(2, int(round(BLOC_AI[bloc].interval * pace)))
		if (day + BLOC_AI[bloc].offset) % interval == 0:
			_bloc_turn(sect, bloc, day, log)
	if day % EVENT_INTERVAL == 0:
		_world_event(sect, day, log)
	_process_tribute(sect, day, log)

	if day % CONFERENCE_INTERVAL == 0:
		hold_conference(sect, log)
	elif day % CONFERENCE_INTERVAL == CONFERENCE_INTERVAL - 10:
		log.call("[color=gold]อีก 10 วันจะมีการประชุมพันธมิตรยุทธภพ เพื่อเลือกจ้าวยุทธภพคนใหม่ (ชื่อเสียงสำนักเรา: %d)[/color]" % get_prestige(sect))

	# รายได้จากพื้นที่ที่ยึดครอง + ตำแหน่งจ้าวยุทธภพ
	var owned = sect.count_owned_nodes() - 1
	if owned > 0: sect.money += owned * NODE_INCOME
	if sect.wulin_leader == "player": sect.money += LEADER_INCOME

	process_feuds(sect, log)
	if day % 7 == 0:
		var ranks = get_rankings(sect)
		if not ranks.is_empty() and ranks[0].ours:
			ArchiveSys.unlock_achievement("top_ranked")
	if day >= 100: ArchiveSys.unlock_achievement("survive_100")
	if day >= 365: ArchiveSys.unlock_achievement("survive_365")

# ══════════════════════════════════════════
# Faction AI
# ══════════════════════════════════════════

## เลือกสมาชิกของฝ่ายที่จะลงมือ (ถ่วงน้ำหนักตามพลัง ผู้นำฝ่ายมีโอกาสมากกว่า)
static func _pick_actor(sect: SectData, bloc: String, rng: RandomNumberGenerator) -> String:
	var members = FactionDB.members_of(bloc)
	var total = 0.0
	for m in members:
		total += sect.factions[m].power * (2.0 if FactionDB.BLOCS[bloc].leader == m else 1.0)
	var roll = rng.randf() * total
	for m in members:
		roll -= sect.factions[m].power * (2.0 if FactionDB.BLOCS[bloc].leader == m else 1.0)
		if roll <= 0: return m
	return members[-1]

## AI ไม่โง่: เลือกบุกเฉพาะเจ้าของที่พอจะสู้ไหว
static func _beatable(sect: SectData, actor: String, owner: String) -> bool:
	return owner == "player" or sect.factions[owner].power < sect.factions[actor].power * 1.3

## พื้นที่ (ป่า/ดันเจี้ยน) ที่ใกล้ฐานของ fid ที่สุดซึ่งเข้าเงื่อนไข filter (สุ่มจาก 3 อันดับแรก)
static func _nearest_target(sect: SectData, fid: String, filter: Callable, rng: RandomNumberGenerator) -> String:
	var world = WorldGen.for_sect(sect)
	var seat: Vector2i = world.poi.get(FactionDB.FACTIONS[fid].seat, Vector2i.ZERO)
	var cands: Array = []
	for id in WorldDB.NODES:
		if not WorldDB.NODES[id].type in [WorldDB.NodeType.WILD, WorldDB.NodeType.DUNGEON]: continue
		var owner: String = sect.node_owner.get(id, "")
		if owner == fid or not filter.call(owner): continue
		if owner != "" and not _beatable(sect, fid, owner): continue
		cands.append([Vector2(seat).distance_to(Vector2(world.poi[id])), id])
	if cands.is_empty(): return ""
	cands.sort_custom(func(a, b): return a[0] < b[0])
	return cands[rng.randi() % mini(3, cands.size())][1]

static func _bloc_turn(sect: SectData, bloc: String, day: int, log: Callable) -> void:
	var rng = _rng(sect, day * 37 + bloc.hash())
	var actor = _pick_actor(sect, bloc, rng)
	var aggressive = rng.randf() < BLOC_AI[bloc].aggression
	match bloc:
		"righteous": _righteous_turn(sect, actor, aggressive, rng, log)
		"demonic": _demonic_turn(sect, actor, aggressive, rng, log)
		"eunuch": _eunuch_turn(sect, actor, aggressive, rng, log)
		_: _frontier_turn(sect, actor, aggressive, rng, log)

## ฝ่ายธรรมะ: ยกทัพปราบมาร / ปกป้องพื้นที่ / ประชุมพันธมิตร
static func _righteous_turn(sect: SectData, actor: String, aggressive: bool, rng: RandomNumberGenerator, log: Callable) -> void:
	if aggressive:
		var target = _nearest_target(sect, actor, func(o): return o != "" and o != "player" and (FactionDB.FACTIONS[o].bloc == "demonic" or get_rel(sect, actor, o) <= -50), rng)
		if target != "":
			_attack_node(sect, actor, target, "ยกทัพปราบมารบุก", log)
			return
	if rng.randf() < 0.5:
		var target = _nearest_target(sect, actor, func(o): return o == "", rng)
		if target != "":
			sect.node_owner[target] = actor
			log.call("[color=#b8b0a0]%s%s ส่งศิษย์ไปพิทักษ์%s[/color]" % [_region_tag(sect, target), fname(actor), _node_name(target)])
			return
	var members = FactionDB.members_of("righteous")
	var other: String = members[rng.randi() % members.size()]
	if other != actor:
		change_rel(sect, actor, other, 8)
		log.call("[color=#b8b0a0][พันธมิตรยุทธภพ] %s และ %s ร่วมประชุมกระชับไมตรี[/color]" % [fname(actor), fname(other)])

## ฝ่ายมาร: ปล้นสะดมพื้นที่ / ลอบสังหารยอดฝีมือฝ่ายธรรมะ / ขยายอาณาเขต
static func _demonic_turn(sect: SectData, actor: String, aggressive: bool, rng: RandomNumberGenerator, log: Callable) -> void:
	if aggressive:
		var hates_player = is_hostile(sect, actor)
		var target = _nearest_target(sect, actor, func(o): return o != "" and (o != "player" or hates_player) and (o == "player" or FactionDB.FACTIONS[o].bloc != "demonic" or get_rel(sect, actor, o) <= -50), rng)
		if target != "":
			_attack_node(sect, actor, target, "บุกปล้นสะดม", log)
			return
	if rng.randf() < 0.4:
		var victims = sect.champions.filter(func(c): return FactionDB.FACTIONS[c.faction].bloc == "righteous")
		if not victims.is_empty():
			var c: Dictionary = victims[rng.randi() % victims.size()]
			var killed = rng.randf() < 0.3
			if killed:
				sect.champions.erase(c)
				sect.champions.append(_make_champion(sect, c.faction, rng, false))
			else:
				c.power = int(c.power * 0.8)
			change_rel(sect, actor, c.faction, -20)
			log.call("[color=#d07070][ยุทธภพ] นักฆ่าของ%s ลอบทำร้าย %s แห่ง%s%s[/color]" % [fname(actor), c.name, fname(c.faction), " จนสิ้นชีพ!" if killed else " บาดเจ็บสาหัส"])
			return
	var target = _nearest_target(sect, actor, func(o): return o == "", rng)
	if target != "":
		sect.node_owner[target] = actor
		log.call("[color=#d07070]%s%s แผ่อิทธิพลเข้ายึด%s[/color]" % [_region_tag(sect, target), fname(actor), _node_name(target)])

## สิบขันทีเงา: ยุแยงพันธมิตร / ส่งเสบียงให้ฝ่ายมาร / ยึดตำแหน่งเจ้าเมือง / กวาดล้างผู้ขัดขืน
static func _eunuch_turn(sect: SectData, actor: String, aggressive: bool, rng: RandomNumberGenerator, log: Callable) -> void:
	var roll = rng.randf()
	if aggressive:
		# กวาดล้าง: หน่วยเหยี่ยวบุกพื้นที่ของผู้ที่เป็นปฏิปักษ์กับสิบขันที
		var target = _nearest_target(sect, "f_hawk", func(o): return o != "" and (o == "player" and is_hostile(sect, "f_eunuchs") or o != "player" and get_rel(sect, "f_eunuchs", o) <= -40), rng)
		if target != "":
			_attack_node(sect, "f_hawk", target, "ได้รับราชโองการลับให้กวาดล้าง", log)
			return
	if roll < 0.35:
		var righteous = FactionDB.members_of("righteous")
		var a: String = righteous[rng.randi() % righteous.size()]
		var b: String = righteous[rng.randi() % righteous.size()]
		if a != b:
			change_rel(sect, a, b, -15)
			log.call("[color=#b090d0][ราชสำนัก] สายลับของสิบขันทีปล่อยข่าวลือยุแยง %s กับ %s จนบาดหมางกัน[/color]" % [fname(a), fname(b)])
			return
	if roll < 0.6:
		var demons = FactionDB.members_of("demonic")
		var d: String = demons[rng.randi() % demons.size()]
		var amount = int(sect.factions[actor].power * 0.03)
		sect.factions[actor].power -= amount
		sect.factions[d].power += amount
		change_rel(sect, actor, d, 5)
		log.call("[color=#b090d0][ราชสำนัก] มีข่าวลือว่าสิบขันทีแอบส่งเสบียงและเงินทุนให้%s เพื่อบั่นทอนฝ่ายธรรมะ[/color]" % fname(d))
		return
	# ยึดตำแหน่งเจ้าเมือง: เปลี่ยนตัวเจ้าเมืองเป็นคนของฝ่ายราชสำนัก
	var cities = sect.city_lords.keys().filter(func(c): return sect.node_owner.get(c, "") != "player" and FactionDB.FACTIONS[sect.city_lords[c].faction].bloc != "eunuch")
	if cities.is_empty(): return
	var city: String = cities[rng.randi() % cities.size()]
	var old: String = sect.city_lords[city].faction
	if sect.factions[actor].power * rng.randf_range(0.6, 1.3) > sect.factions[old].power * rng.randf_range(0.6, 1.3):
		var newcomer: String = ["f_court", "f_eunuchs"][rng.randi() % 2]
		sect.city_lords[city] = { "name": _random_name(rng, newcomer), "faction": newcomer }
		sect.node_owner[city] = newcomer
		change_rel(sect, newcomer, old, -20)
		log.call("[color=#b090d0]%sราชโองการปลด%s ออกจากตำแหน่งเจ้าเมือง%s แต่งตั้ง %s คนของ%s แทน[/color]" % [_region_tag(sect, city), fname(old), _node_name(city), sect.city_lords[city].name, fname(newcomer)])
	else:
		change_rel(sect, actor, old, -10)
		log.call("[color=#b090d0]%s%s ขัดขืนราชโองการปลดเจ้าเมือง%s สำเร็จ[/color]" % [_region_tag(sect, city), fname(old), _node_name(city)])

## ขั้วอิสระ/แคว้นชายขอบ: ศึกชายแดนกับศัตรูเก่า หรือค่อยๆ ขยายอาณาเขต
static func _frontier_turn(sect: SectData, actor: String, aggressive: bool, rng: RandomNumberGenerator, log: Callable) -> void:
	if aggressive:
		var target = _nearest_target(sect, actor, func(o): return o != "" and (o == "player" and is_hostile(sect, actor) or o != "player" and get_rel(sect, actor, o) <= -40), rng)
		if target != "":
			_attack_node(sect, actor, target, "ยกทัพข้ามชายแดนบุก", log)
			return
	var target = _nearest_target(sect, actor, func(o): return o == "", rng)
	if target != "":
		sect.node_owner[target] = actor
		log.call("[color=#a0b8c0]%s%s ขยายอิทธิพลเข้าครอบครอง%s[/color]" % [_region_tag(sect, target), fname(actor), _node_name(target)])

## บุกยึดพื้นที่: เทียบพลังผู้บุกกับเจ้าของ (เจ้าของได้เปรียบการตั้งรับ)
static func _attack_node(sect: SectData, attacker: String, node_id: String, verb: String, log: Callable) -> void:
	var owner: String = sect.node_owner.get(node_id, "")
	var tag = _region_tag(sect, node_id)
	if owner == "player":
		# พื้นที่ของสำนักเรา: ศิษย์ที่ประจำอยู่ช่วยป้องกัน
		var guard = 0.0
		for d in ExpeditionSys.get_stationed_at(sect, node_id): guard += d.get_power_rating()
		var raid = squad_power(sect, attacker) * 2.0 * randf_range(0.7, 1.3) * BuildingDB.diff(sect.difficulty).invasion
		if guard >= raid:
			sect.prestige += 5
			log.call("[color=green]%s%s %s%s แต่ศิษย์ของเราที่ประจำอยู่ตีโต้กลับไปได้! (พลังบุก %d / ป้องกัน %d)[/color]" % [tag, fname(attacker), verb, _node_name(node_id), raid, guard])
		else:
			sect.node_owner[node_id] = attacker
			log.call("[color=red]%s%s %s%s ยึดพื้นที่ไปจากสำนักเรา! (พลังบุก %d)[/color]" % [tag, fname(attacker), verb, _node_name(node_id), raid])
		return
	var atk = sect.factions[attacker].power * randf_range(0.7, 1.3)
	var dfn = sect.factions[owner].power * randf_range(0.7, 1.3) * 1.15 if owner != "" else 0.0
	change_rel(sect, attacker, owner, -10)
	if atk > dfn:
		sect.node_owner[node_id] = attacker
		sect.factions[attacker].power = int(sect.factions[attacker].power * 0.98)
		if owner != "": sect.factions[owner].power = int(sect.factions[owner].power * 0.96)
		log.call("[color=#d0a070]%s%s %s%s ยึดมาจาก%s สำเร็จ[/color]" % [tag, fname(attacker), verb, _node_name(node_id), fname(owner) if owner != "" else "เจ้าถิ่น"])
	else:
		sect.factions[attacker].power = int(sect.factions[attacker].power * 0.98)
		log.call("[color=#a0a0a0]%s%s %s%s แต่ถูก%sตีแตกพ่ายกลับไป[/color]" % [tag, fname(attacker), verb, _node_name(node_id), fname(owner)])

# ══════════════════════════════════════════
# เหตุการณ์ระหว่างขั้วอำนาจ (สุ่มตาม Seed)
# ══════════════════════════════════════════

static func _world_event(sect: SectData, day: int, log: Callable) -> void:
	var rng = _rng(sect, day * 101 + 7)
	var ids = FactionDB.FACTIONS.keys()
	var a: String = ids[rng.randi() % ids.size()]
	var b: String = ids[rng.randi() % ids.size()]
	var regions = WorldDB.REGIONS.keys()
	var region: String = regions[rng.randi() % regions.size()]
	var rname = WorldDB.get_region_name(region)
	match rng.randi() % 7:
		0:
			if a == b or get_rel(sect, a, b) > -30: return
			for f in [a, b]: sect.factions[f].power = int(sect.factions[f].power * rng.randf_range(0.94, 0.98))
			change_rel(sect, a, b, -10)
			log.call("[color=orange][ยุทธภพ] ศึกปะทะระหว่าง%s กับ%s ทั้งสองฝ่ายสูญเสียหนัก[/color]" % [fname(a), fname(b)])
		1:
			if a == b: return
			change_rel(sect, a, b, 25)
			log.call("[color=#a0d0a0][ยุทธภพ] %s และ%s ลงนามสัญญาไมตรี (ความสัมพันธ์ %+d)[/color]" % [fname(a), fname(b), get_rel(sect, a, b)])
		2:
			if a == b or get_rel(sect, a, b) < 30: return
			change_rel(sect, a, b, -45)
			log.call("[color=orange][ยุทธภพ] %s หักหลังพันธมิตรเก่าอย่าง%s! ความแค้นปะทุขึ้นทันที[/color]" % [fname(a), fname(b)])
		3:
			for f in ids:
				if WorldGen.for_sect(sect).poi_region(FactionDB.FACTIONS[f].seat) == region:
					sect.factions[f].power = int(sect.factions[f].power * 0.95)
			_scale_yields(sect, region, 0.8)
			log.call("[color=orange][%s] โรคระบาดแพร่กระจาย ขั้วอำนาจในภูมิภาคอ่อนกำลังลง ผลผลิตลดลง[/color]" % rname)
		4:
			_scale_yields(sect, region, 1.25)
			log.call("[color=lime][%s] ฟ้าดินเป็นใจ ปีนี้สมุนไพรและแร่ธาตุอุดมสมบูรณ์ ผลผลิตในภูมิภาคเพิ่มขึ้น[/color]" % rname)
		5:
			var c = _make_champion(sect, a, rng, false)
			c.power = int(c.power * 1.5)
			sect.champions.append(c)
			log.call("[color=#c0b0ff][ยุทธภพ] ยอดฝีมือหน้าใหม่ '%s' %s แห่ง%s ปรากฏตัว สะเทือนทั่วยุทธภพ[/color]" % [c.title, c.name, fname(a)])
		6:
			if sect.champions.is_empty(): return
			var best: Dictionary = sect.champions[0]
			for c in sect.champions:
				if c.power > best.power: best = c
			best.fame += 50
			log.call("[color=gold][ยุทธภพ] งานประลองยุทธ์หลวงที่%s: %s '%s' แห่ง%s คว้าชัยชนะ[/color]" % [capital_name(), best.name, best.title, fname(best.faction)])

static func _scale_yields(sect: SectData, region: String, factor: float) -> void:
	var world = WorldGen.for_sect(sect)
	for id in sect.node_yield:
		if world.poi_region(id) == region:
			sect.node_yield[id] = clampf(snappedf(sect.node_yield[id] * factor, 0.05), 0.4, 2.0)

# ══════════════════════════════════════════
# ส่วยสิบขันที
# ══════════════════════════════════════════

static func _process_tribute(sect: SectData, day: int, log: Callable) -> void:
	var t = sect.pending_tribute
	if not t.is_empty():
		if day >= t.deadline:
			sect.pending_tribute = {}
			for m in FactionDB.members_of("eunuch"): change_rel(sect, "player", m, -15)
			log.call("[color=red]สำนักเราเพิกเฉยต่อการเรียกส่วยของสิบขันทีเงา ราชสำนักไม่พอใจอย่างยิ่ง (ความสัมพันธ์ฝ่ายราชสำนัก -15)[/color]")
		return
	if day % TRIBUTE_INTERVAL == 0 and day > 0 and not sect.factions.f_eunuchs.war:
		sect.pending_tribute = { "amount": 200 + day * 2, "deadline": day + TRIBUTE_DAYS }
		log.call("[color=#c090ff]%sส่งราชโองการเรียกส่วย %d เงิน ให้จ่ายภายใน %d วัน (จ่ายได้ที่หน้าการเมืองยุทธภพ)[/color]" % [eunuch_leader(), sect.pending_tribute.amount, TRIBUTE_DAYS])

static func pay_tribute(sect: SectData) -> String:
	var t = sect.pending_tribute
	if t.is_empty(): return "ไม่มีการเรียกส่วย"
	if sect.money < t.amount: return "เงินไม่พอ (ต้องการ %d)" % t.amount
	sect.money -= t.amount
	sect.pending_tribute = {}
	for m in FactionDB.members_of("eunuch"): change_rel(sect, "player", m, 8)
	for m in FactionDB.members_of("righteous"): change_rel(sect, "player", m, -2)
	return "จ่ายส่วย %d เงินให้สิบขันที ราชสำนักพอใจ (ฝ่ายธรรมะบางส่วนมองว่าสำนักเราประจบขันที)" % t.amount

# ══════════════════════════════════════════
# การทูตของสำนักเรา
# ══════════════════════════════════════════

static func gift_cost(sect: SectData, fid: String) -> int:
	return 300 + max(0, -sect.factions[fid].relation) * 10

static func gift(sect: SectData, fid: String) -> String:
	var cost = gift_cost(sect, fid)
	if sect.money < cost: return "เงินไม่พอ (ต้องการ %d)" % cost
	sect.money -= cost
	var f = sect.factions[fid]
	f.relation = min(100, f.relation + 12)
	return "ส่งของกำนัลมูลค่า %d ให้%s ความสัมพันธ์เป็น %d" % [cost, fname(fid), f.relation]

## ประกาศสงคราม: ฝ่ายต่างๆ มองการกระทำนี้ตามความสัมพันธ์ที่มีกับเป้าหมาย
static func declare_war(sect: SectData, fid: String) -> String:
	var f = sect.factions[fid]
	f.war = true
	f.relation = min(f.relation, -80)
	for other in sect.factions:
		if other == fid: continue
		var r = get_rel(sect, other, fid)
		if r >= 40: change_rel(sect, "player", other, -10)
		elif r <= -40: change_rel(sect, "player", other, 5)
	return "[color=red]สำนักเราประกาศสงครามกับ%s! (พันธมิตรของเป้าหมายไม่พอใจ ศัตรูของเป้าหมายชื่นชม)[/color]" % fname(fid)

static func peace_cost(sect: SectData, fid: String) -> int:
	return 800 + int(sect.factions[fid].power / 20.0)

static func make_peace(sect: SectData, fid: String) -> String:
	var cost = peace_cost(sect, fid)
	if sect.money < cost: return "เงินไม่พอ (ต้องการ %d)" % cost
	sect.money -= cost
	sect.factions[fid].war = false
	sect.factions[fid].relation = max(sect.factions[fid].relation, -30)
	return "สงบศึกกับ%s แล้ว (จ่ายค่าปฏิกรรม %d)" % [fname(fid), cost]

## สำนักที่เป็นศัตรู (กำลังทำสงคราม หรือความสัมพันธ์ต่ำมาก)
static func is_hostile(sect: SectData, fid: String) -> bool:
	if fid == "" or fid == "player" or not sect.factions.has(fid): return false
	return sect.factions[fid].war or sect.factions[fid].relation <= -40

## สรุปดุลอำนาจของแต่ละฝ่าย [{ bloc, name, power, nodes, members }]
static func bloc_summary(sect: SectData) -> Array:
	var result: Array = []
	for bloc in FactionDB.BLOCS:
		var members = FactionDB.members_of(bloc)
		var power = 0
		var nodes = 0
		for m in members:
			power += sect.factions[m].power
			nodes += sect.node_owner.values().count(m)
		result.append({ "bloc": bloc, "name": FactionDB.bloc_name(bloc), "power": power, "nodes": nodes, "members": members })
	return result

# ══════════════════════════════════════════
# ประชุมพันธมิตรยุทธภพ: โหวตเลือกจ้าวยุทธภพ
# ══════════════════════════════════════════

static func get_prestige(sect: SectData) -> int:
	var total = sect.prestige + (sect.count_owned_nodes() - 1) * 20
	for d in sect.get_active_disciples():
		var per = float(d.fame) + d.get_power_rating() / 5.0
		total += int(minf(per, 60.0 + sqrt(maxf(0.0, per - 60.0)) * 4.0))
	return total

static func _align_affinity(a: String, b: String) -> int:
	if a == b: return 30
	if a == "กลาง" or b == "กลาง": return 0
	return -40

## คืนค่า { "votes": { candidate: count }, "winner": candidate, "ballots": { voter: candidate } }
static func tally_votes(sect: SectData) -> Dictionary:
	var greats = FactionDB.great_sects()
	var prestige = get_prestige(sect)
	var votes = { "player": 0 }
	var ballots = {}
	for voter in greats:
		var va = FactionDB.FACTIONS[voter].align
		var rel = sect.factions[voter].relation
		var best = ""
		var best_score = -INF
		if not sect.factions[voter].war:
			best = "player"
			best_score = rel + prestige / 30.0
		for cand in greats:
			if cand == voter: continue
			var score = _align_affinity(va, FactionDB.FACTIONS[cand].align) + sect.factions[cand].power / 2000.0 + get_rel(sect, voter, cand) * 0.3
			if score > best_score:
				best_score = score
				best = cand
		ballots[voter] = best
		votes[best] = votes.get(best, 0) + 1
	var winner = "player"
	for c in votes:
		if votes[c] > votes[winner]: winner = c
	return { "votes": votes, "winner": winner, "ballots": ballots }

static func hold_conference(sect: SectData, log: Callable) -> void:
	var result = tally_votes(sect)
	sect.wulin_leader = result.winner
	EndingSys.note_conference(sect)
	var lines: Array[String] = []
	for c in result.votes:
		lines.append("%s %d เสียง" % [fname(c), result.votes[c]])
	log.call("[color=gold]=== ประชุมพันธมิตรยุทธภพ === ผลโหวต: %s[/color]" % ", ".join(lines))
	if result.winner == "player":
		log.call("[color=gold]สำนัก%s ได้รับเลือกเป็นจ้าวยุทธภพ! ทั่วทั้งแผ่นดินต่างยอมรับ (รายได้ +%d/วัน)[/color]" % [sect.sect_name, LEADER_INCOME])
		ArchiveSys.unlock_achievement("wulin_leader")
		for fid in sect.factions:
			if FactionDB.FACTIONS[fid].align == "ธรรมะ": sect.factions[fid].relation += 10
			if FactionDB.FACTIONS[fid].bloc == "eunuch": sect.factions[fid].relation -= 10
	else:
		log.call("[color=gold]%s ได้รับเลือกเป็นจ้าวยุทธภพ[/color]" % fname(result.winner))

# ══════════════════════════════════════════
# ทำเนียบยุทธภพ & ฉายา
# ══════════════════════════════════════════

const TITLE_STYLE = {
	"sword": ["ดาบ", "กระบี่"], "palm": ["หมัด", "ฝ่ามือ"], "internal": ["ปราณ", "ลมปราณ"], "spear": ["ทวน"],
	"poison": ["พิษ", "พิษร้าย"], "formation": ["ค่ายกล"], "hidden_weapon": ["เข็ม", "อาวุธลับ"], "movement": ["เงา"],
}
const TITLE_ELEMENT = {
	"ไฟ": ["อัคคี", "เพลิงผลาญ"], "น้ำ": ["วารี", "หิมะ"], "ไม้": ["พฤกษา", "ไผ่เขียว"],
	"ทอง": ["ทองคำ", "สุวรรณ"], "ดิน": ["ปฐพี", "ขุนเขา"], "สายฟ้า": ["อัสนี", "สายฟ้า"],
}
const TITLE_DIRECTIONS = ["บูรพา", "ประจิม", "ทักษิณ", "อุดร"]

static func _title_from(style: String, element: String, evil: bool) -> String:
	if evil and randf() < 0.5:
		return ["มาร", "ปีศาจ"].pick_random() + TITLE_DIRECTIONS.pick_random()
	var prefix = (["ปีศาจ", "มาร"] if evil else ["จอม", "เทพ", "ราชัน", "เซียน"]).pick_random()
	return prefix + TITLE_STYLE.get(style, ["ยุทธ์"]).pick_random() + TITLE_ELEMENT.get(element, TITLE_DIRECTIONS).pick_random()

## ฉายาของศิษย์ ตามสายวิชาถนัด ธาตุ และนิสัย (เช่น "จอมดาบหิมะ", "มารบูรพา")
static func generate_title(d: DiscipleData) -> String:
	var evil = d.affinity_style == "poison"
	for t in ["โหดเหี้ยม", "นักฆ่าเลือดเย็น", "บ้าคลั่ง"]:
		if d.ext_traits.has(t): evil = true
	return _title_from(d.affinity_style, d.element, evil)

## รายชื่อทำเนียบยุทธภพ เรียงตาม (พลัง + ชื่อเสียง)
static func get_rankings(sect: SectData) -> Array:
	var list: Array = []
	for d in sect.get_active_disciples():
		list.append({ "name": d.disciple_name, "title": d.title, "sect": sect.sect_name, "power": d.get_power_rating(), "fame": d.fame, "ours": true })
	for c in sect.champions:
		list.append({ "name": c.name, "title": c.title, "sect": fname(c.faction), "power": c.power, "fame": c.fame, "ours": false })
	list.sort_custom(func(a, b): return a.power + a.fame > b.power + b.fame)
	return list

# ══════════════════════════════════════════
# สมาชิกของขั้วอำนาจอื่น (ศัตรูในฉากต่อสู้)
# ══════════════════════════════════════════

const RANK_NAMES = {
	"righteous": ["ศิษย์", "ผู้อาวุโส"], "demonic": ["สาวก", "ผู้อาวุโส"], "eunuch": ["องครักษ์", "ขุนพล"],
	"independent": ["สมาชิก", "ยอดฝีมือ"], "foreign": ["นักรบ", "แม่ทัพ"],
}

static func make_enemies(sect: SectData, fid: String, count: int, with_elite: bool) -> Array[Dictionary]:
	var f = FactionDB.FACTIONS[fid]
	var sq = squad_power(sect, fid)
	var ranks: Array = RANK_NAMES[f.bloc]
	var result: Array[Dictionary] = []
	for i in count:
		var elite = with_elite and i == 0
		var m = 5.0 if elite else 1.0
		var e = StatSys.build_fighter(sq * m * randf_range(0.85, 1.15), 4.5 if elite else 3.5)
		e.merge({
			"id": "f_%s_%d" % [fid, 1 if elite else 0], "faction": fid,
			"name": ranks[1 if elite else 0] + f.name,
			"art": "human", "color": f.color, "status_attack": f.status_attack,
			"reward_money": int(sq * 3 * m), "reward_food": 20, "reward_exp": int(60 + sq * 4 * m),
			"drops": { "scripture_fragment": [0, 2 if elite else 1], "spirit_stone": [0, 2] },
		})
		# ซื้อความลับมาแล้ว = รู้จุดอ่อน
		if sect.intel.get(fid, 0) > sect.current_day:
			e.attack = int(e.attack * 0.9)
			e.defense = int(e.defense * 0.75)
			e.name += " (รู้จุดอ่อน)"
		e["hp"] = e.max_hp
		result.append(e)
	return result

## ชนะการบุกตีสำนัก: พลังสำนักลด, ได้คัมภีร์ประจำสำนัก, ชื่อเสียง
static func on_siege_won(sect: SectData, fid: String) -> String:
	var f = sect.factions[fid]
	var info = FactionDB.FACTIONS[fid]
	f.power = int(f.power * 0.85)
	f.relation = max(-100, f.relation - 25)
	var tier = SkillDB.Tier.HEAVEN if f.power > 40000 else (SkillDB.Tier.EARTH if f.power > 15000 else SkillDB.Tier.MORTAL)
	var skill = SkillDB.get_random_skill_by_tier_and_type(tier, info.style)
	sect.add_library_skill(skill)
	sect.prestige += 30
	EndingSys.note_siege(sect)
	if f.power < info.power * 0.5:
		ArchiveSys.unlock_achievement("sect_destroyer")
	for other in sect.factions:
		if other == fid: continue
		var r = get_rel(sect, other, fid)
		if r <= -40: change_rel(sect, "player", other, 5)
		elif r >= 40: change_rel(sect, "player", other, -5)
	return "ตีแตก%s! พลังสำนักลดเหลือ %d และยึดคัมภีร์ %s มาได้" % [info.name, f.power, skill]

# ══════════════════════════════════════════
# บุญคุณความแค้น (Blood Feuds)
# ══════════════════════════════════════════

## ศิษย์ถูกฆ่า: บันทึกการตาย แล้วให้สหายที่สนิทกันผูกใจเจ็บกับสำนักคนร้าย
static func on_disciple_killed(sect: SectData, victim: DiscipleData, fid: String, cause: String, log: Callable) -> void:
	victim.status = DiscipleData.DiscipleStatus.DEPARTED
	victim.death_cause = cause
	log.call("[color=red]%s เสียชีวิต (%s)[/color]" % [victim.get_display_name(), cause])
	if fid == "" or not sect.factions.has(fid): return
	sect.factions[fid].relation = max(-100, sect.factions[fid].relation - 20)
	for d in sect.get_active_disciples():
		if d == victim: continue
		var aff: float = d.relationships.get(victim.disciple_name, {}).get("affinity", 0.0)
		var bond = aff >= 10 or d.master == victim or victim.master == d
		if bond or randf() < 0.25:
			d.feud_target = fid
			d.feud_for = victim.disciple_name
			d.feud_intensity = clampi(40 + int(aff), 20, 100)
			d.add_memory(sect.current_day, "สาบานจะล้างแค้นให้ %s" % victim.disciple_name)
			log.call("[color=orange]%s กำหมัดแน่น สาบานว่าจะล้างแค้นให้ %s ด้วยโลหิตของ%s![/color]" % [d.disciple_name, victim.disciple_name, fname(fid)])

## ศิษย์ที่ผูกใจเจ็บมีโอกาสแอบหนีลงเขาไปล้างแค้นเอง
static func process_feuds(sect: SectData, log: Callable) -> void:
	for d in sect.disciples:
		if d.feud_target == "" or not d.can_fight(): continue
		var chance = d.feud_intensity / 1500.0
		for t in ["แค้นฝังหุ่น", "บ้าคลั่ง", "ใจเด็ดเดี่ยว"]:
			if d.ext_traits.has(t): chance += 0.03
		if d.loyalty > 80: chance *= 0.7
		if randf() < chance:
			var seat = FactionDB.FACTIONS[d.feud_target].seat
			ExpeditionSys.dispatch(sect, d, "revenge", seat)
			log.call("[color=red]%s แอบหนีลงเขากลางดึก มุ่งหน้าไป%s เพื่อล้างแค้นให้ %s![/color]" % [d.disciple_name, _node_name(seat), d.feud_for])

## ศิษย์ไปถึงสำนักศัตรู: ดวลเดี่ยวเพื่อล้างแค้น คืนค่า true ถ้ายังมีชีวิต
static func resolve_revenge(sect: SectData, d: DiscipleData, log: Callable) -> bool:
	var fid = d.feud_target
	if fid == "" or not sect.factions.has(fid): return true
	var faction_name = fname(fid)
	var enemy_power = squad_power(sect, fid) * 2.5 * randf_range(0.6, 1.3)
	var mine = d.get_power_rating() * randf_range(0.8, 1.3)
	if mine >= enemy_power:
		d.add_fame(40)
		sect.factions[fid].power = int(sect.factions[fid].power * 0.97)
		sect.factions[fid].relation -= 10
		log.call("[color=gold]%s บุกเดี่ยวเข้า%s ล้างแค้นให้ %s สำเร็จ! ชื่อเสียงขจรไกล[/color]" % [d.disciple_name, faction_name, d.feud_for])
		d.feud_target = ""
		d.feud_intensity = 0
		ArchiveSys.unlock_achievement("feud_avenged")
		return true
	if randf() < 0.4 + BuildingDB.diff(sect.difficulty).death:
		on_disciple_killed(sect, d, fid, "ถูกสังหารขณะล้างแค้นที่" + faction_name, log)
		return false
	d.add_ailment("meridian_damage")
	d.injury_days = max(d.injury_days, 5)
	d.feud_intensity -= 25
	if d.feud_intensity <= 0: d.feud_target = ""
	log.call("[color=red]%s ล้างแค้นไม่สำเร็จ ถูกศิษย์%sรุมจนเส้นชีพจรขาด ต้องหนีกลับมา[/color]" % [d.disciple_name, faction_name])
	return true
