extends RefCounted
class_name SandboxGen

## โหมดแซนด์บ็อกซ์ "โกลาหลยุทธภพ": สุ่มโลกใหม่ทั้งหมดจาก Seed แล้วแทนที่ข้อมูลใน WorldDB / FactionDB / CityDB
## - ภูมิภาค 9 แห่ง ชื่อสุ่ม (มณฑลใกล้ใจกลาง / ดินแดนชายขอบรอบนอก)
## - เมือง 12 แห่ง (เมืองหลวง 1) ร้านค้า ราคา และโรงประมูลสุ่ม
## - ขั้วอำนาจ 27 ฝ่าย ชื่อสุ่มใหม่หมด (เช่น พรรคกระบี่สวรรค์ ลัทธิมารหมาป่า) แบ่ง 5 ฝ่ายเหมือนโหมดเนื้อเรื่อง
##   (คงรหัส f_court / f_eunuchs / f_hawk ไว้ให้ระบบราชสำนักทำงานได้ แต่ชื่อเปลี่ยนตาม Seed)
## - พื้นที่ป่า/ดันเจี้ยนวางตามภูมิประเทศจริง ศัตรูและวัตถุดิบตามภูมิประเทศ
## ผลลัพธ์คงที่ต่อ Seed (โหลดเซฟแล้วได้โลกเดิม)

const SYL = ["หลง", "เฟิง", "อวิ๋น", "เสวี่ย", "หลิว", "จิน", "ไห่", "ซาน", "หยก", "ปิง", "เทียน", "หมิง", "เยว่", "ซิง", "หลาน", "อู่", "ชิง", "ฮวา", "เหยียน", "ชาง", "ไป๋", "เหอ", "หลิน", "ฉี", "ลั่ว", "เจียง", "หนิง", "ซู", "ถาน", "กุ้ย"]
const RIGHTEOUS_TYPES = ["สำนัก", "พรรค", "ตระกูล", "วัด", "หุบเขา", "สภา"]
const RIGHTEOUS_NOUNS = ["กระบี่สวรรค์", "เมฆาเหิน", "มังกรหยก", "หิมะพันปี", "ตะวันฉาย", "สายลมบูรพา", "ภูผาเหล็ก", "บัวทอง", "อินทรีเงิน", "ธาราใส", "พยัคฆ์ขาว", "ดาราประกาย", "ไผ่มรกต", "อัสนีม่วง"]
const DEMONIC_TYPES = ["ลัทธิ", "พรรคมาร", "นิกาย", "หอ"]
const DEMONIC_NOUNS = ["หมาป่ามาร", "โลหิตดำ", "เงาอเวจี", "อสรพิษเก้าหัว", "กะโหลกเพลิง", "จันทร์ทมิฬ", "ปีศาจหมื่นพิษ", "บัวนรก"]
const INDEPENDENT_TYPES = ["สมาคมการค้า", "ตระกูล", "หอ", "สำนักคุ้มภัย", "สุสาน"]
const INDEPENDENT_NOUNS = ["หมื่นทอง", "ศิลาเงิน", "ธารเหล็ก", "ร้อยบุปผา", "ลมกรด", "ใจกระบี่", "พันลี้"]
const FOREIGN_TYPES = ["ชนเผ่า", "อาณาจักร", "ราชวงศ์", "พันธมิตรโจรสลัด", "นิกาย"]
const FOREIGN_NOUNS = ["ทุ่งหญ้าเหล็ก", "ทรายแดง", "เต่าดำ", "วายุทะเล", "สุริยันเพลิง", "หิมะนิรันดร์", "หมาป่าขาว"]
const STYLES = ["sword", "palm", "internal", "poison", "hidden_weapon", "spear", "formation"]
const SHOP_MATS = ["spirit_grass", "iron_ore", "beast_hide", "blood_ginseng", "cold_iron", "spirit_stone", "wood", "stone", "beast_core", "snow_lotus", "star_metal"]
## ศัตรูและวัตถุดิบตามภูมิประเทศ (WorldGen.Biome)
const WILD_BY_BIOME = {
	WorldGen.Biome.GRASS: { "enemies": ["bandit_thug", "steppe_raider", "forest_wolf"], "gather": { "spirit_grass": [2, 6], "beast_hide": [1, 3] } },
	WorldGen.Biome.FOREST: { "enemies": ["forest_wolf", "bandit_thug", "blood_lotus_cultist"], "gather": { "spirit_grass": [3, 7], "wood": [3, 6] } },
	WorldGen.Biome.HILLS: { "enemies": ["mountain_bandit", "rock_ape"], "gather": { "iron_ore": [2, 5], "stone": [2, 5] } },
	WorldGen.Biome.MOUNTAIN: { "enemies": ["rock_ape", "rival_swordsman"], "gather": { "iron_ore": [3, 6], "cold_iron": [0, 2], "spirit_stone": [0, 1] } },
	WorldGen.Biome.SNOW: { "enemies": ["snow_wolf_king", "xuancheng_guard"], "gather": { "snow_lotus": [0, 1], "star_metal": [0, 1], "spirit_stone": [1, 2] } },
	WorldGen.Biome.SAND: { "enemies": ["sand_bandit", "pirate", "fire_cultist"], "gather": { "spirit_stone": [1, 3] } },
}
const DUNGEONS = [
	{ "name": "รังพรรคมาร", "enemies": ["demon_sect_disciple", "demon_elder"], "gather": { "blood_ginseng": [1, 3], "beast_core": [0, 2] } },
	{ "name": "ถ้ำผู้พิทักษ์ศิลา", "enemies": ["rock_ape", "xuancheng_guard"], "gather": { "star_metal": [0, 2], "cold_iron": [1, 3] } },
	{ "name": "ถ้ำโจรสลัด", "enemies": ["pirate", "pirate_captain"], "gather": { "spirit_stone": [1, 3], "dragon_scale": [0, 1] } },
	{ "name": "รังใยพิษ", "enemies": ["gu_serpent", "blood_spider"], "gather": { "blood_ginseng": [1, 3] } },
	{ "name": "คุกลับทหารหลวง", "enemies": ["hawk_guard", "bandit_thug"], "gather": { "cold_iron": [0, 2], "scripture_fragment": [0, 1] } },
]

static var _used_names := {}

static func apply(p_seed: int) -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(["sandbox", p_seed])
	_used_names = {}
	var biomes = WorldGen.noise_continent(p_seed)
	var land = _largest_land(biomes)
	var biome_at = func(c: Vector2i) -> int: return biomes[c.y * WorldGen.WIDTH + c.x]
	var taken: Array = []

	# ── ภูมิภาค ──
	var regions = {}
	var centers = _spread(land, 9, 10.0, rng, taken)
	var map_center = Vector2(WorldGen.WIDTH, WorldGen.HEIGHT) / 2.0
	for i in centers.size():
		var c: Vector2i = centers[i]
		var province = Vector2(c).distance_to(map_center) < 22.0
		var rname = ("มณฑล" if province else ["ดินแดน", "แคว้น", "เขตแดน"][rng.randi() % 3]) + _word(rng, 2)
		regions["rg%d" % i] = { "name": rname, "kind": "province" if province else "frontier", "center": c, "label": c + Vector2i(0, -3), "desc": "ภูมิภาคที่ถูกสุ่มขึ้นในโลกโกลาหลยุทธภพ", "palette": [] }
	taken.clear()
	WorldDB.REGIONS = regions
	var region_of = func(c: Vector2i) -> String:
		var best = ""
		var bd = INF
		for id in regions:
			var d = Vector2(c).distance_squared_to(Vector2(regions[id].center))
			if d < bd:
				bd = d
				best = id
		return best

	var nodes = { "sect": WorldDB.LORE_NODES.sect }
	# ── เมือง ──
	var city_cells = _spread(land.filter(func(c): return biome_at.call(c) in [WorldGen.Biome.GRASS, WorldGen.Biome.FOREST, WorldGen.Biome.SAND]), 12, 9.0, rng, taken)
	city_cells.sort_custom(func(a, b): return Vector2(a).distance_to(map_center) < Vector2(b).distance_to(map_center))
	var city_ids: Array = []
	for i in city_cells.size():
		var id = "sc%d" % i
		var capital = i == 0
		var mats = SHOP_MATS.duplicate()
		mats.shuffle()
		var auction = capital or rng.randf() < 0.4
		nodes[id] = {
			"name": ("นครหลวง" if capital else ["นคร", "เมือง", "เมืองท่า" if biome_at.call(city_cells[i]) == WorldGen.Biome.SAND else "เมือง"][rng.randi() % 3]) + _word(rng, 2),
			"type": WorldDB.NodeType.CITY, "region": region_of.call(city_cells[i]), "cell": city_cells[i],
			"desc": "เมืองหลวงแห่งโลกโกลาหล ศูนย์กลางอำนาจของราชสำนัก" if capital else "เมืองที่ถูกสุ่มขึ้นในโลกโกลาหลยุทธภพ",
			"shop": mats.slice(0, rng.randi_range(3, 6)), "price_mult": snappedf(rng.randf_range(0.9, 1.4), 0.05),
			"sell_rate": snappedf(rng.randf_range(0.5, 0.8), 0.05), "shop_rarity": 2 if capital else rng.randi_range(0, 2), "auction": auction, "lords": [],
		}
		city_ids.append(id)

	# ── ขั้วอำนาจ ──
	var factions = {}
	var plan = [
		["righteous", 8, RIGHTEOUS_TYPES, RIGHTEOUS_NOUNS, "ธรรมะ", [15000, 60000]],
		["demonic", 5, DEMONIC_TYPES, DEMONIC_NOUNS, "มาร", [10000, 55000]],
		["independent", 5, INDEPENDENT_TYPES, INDEPENDENT_NOUNS, "กลาง", [5000, 35000]],
		["foreign", 5, FOREIGN_TYPES, FOREIGN_NOUNS, "กลาง", [20000, 60000]],
	]
	var dynasty = _word(rng, 2)
	factions["f_court"] = _faction(rng, "ราชสำนัก" + dynasty, "กลาง", "eunuch", [50000, 70000], city_ids[0], "spear")
	factions["f_eunuchs"] = _faction(rng, "สภาขันทีเงา" + _word(rng, 1), "มาร", "eunuch", [35000, 50000], city_ids[0], "internal")
	factions["f_hawk"] = _faction(rng, "หน่วย" + ["เหยี่ยวทมิฬ", "พยัคฆ์ชาด", "อินทรีเลือด"][rng.randi() % 3], "มาร", "eunuch", [20000, 30000], city_ids[0], "sword")
	factions["f_spies"] = _faction(rng, "กรมสอดแนม" + _word(rng, 2), "กลาง", "eunuch", [6000, 12000], city_ids[0], "hidden_weapon")
	var idx = 0
	for p in plan:
		for i in p[1]:
			var fname = ""
			for tries in 20:
				fname = p[2][rng.randi() % p[2].size()] + p[3][rng.randi() % p[3].size()]
				if not _used_names.has(fname): break
			_used_names[fname] = true
			var align = p[4] if p[0] != "foreign" else ("มาร" if rng.randf() < 0.35 else "กลาง")
			# ขั้วอิสระบางส่วนตั้งสำนักงานใหญ่ในเมือง ที่เหลือมีฐานที่มั่นของตัวเอง
			var seat = city_ids[1 + rng.randi() % (city_ids.size() - 1)] if p[0] == "independent" and i < 2 else ""
			factions["s%d" % idx] = _faction(rng, fname, align, p[0], p[5], seat, STYLES[rng.randi() % STYLES.size()])
			idx += 1
	# 8 สำนักใหญ่: ฝ่ายธรรมะ 6 + อิสระ 2
	var righteous = factions.keys().filter(func(f): return factions[f].bloc == "righteous")
	var indep = factions.keys().filter(func(f): return factions[f].bloc == "independent")
	for f in righteous.slice(0, 6) + indep.slice(0, 2): factions[f].great = true
	# ความสัมพันธ์ตั้งต้น: มิตรในฝ่ายเดียวกัน ศัตรูข้ามฝ่ายแบบสุ่ม
	var ids = factions.keys()
	for f in ids:
		var same = ids.filter(func(o): return o != f and factions[o].bloc == factions[f].bloc)
		var other = ids.filter(func(o): return factions[o].bloc != factions[f].bloc)
		same.shuffle()
		other.shuffle()
		factions[f].allies = same.slice(0, rng.randi_range(0, 2))
		factions[f].enemies = other.slice(0, rng.randi_range(1, 3))

	# ── ฐานที่มั่นของขั้วอำนาจที่ไม่ได้อยู่ในเมือง ──
	var seat_ids = ids.filter(func(f): return factions[f].seat == "")
	var seat_cells = _spread(land.filter(func(c): return biome_at.call(c) in [WorldGen.Biome.HILLS, WorldGen.Biome.MOUNTAIN, WorldGen.Biome.FOREST, WorldGen.Biome.SNOW, WorldGen.Biome.GRASS]), seat_ids.size(), 5.0, rng, taken)
	for i in min(seat_ids.size(), seat_cells.size()):
		var f: String = seat_ids[i]
		var nid = "seat_" + f
		var place = ["ยอดเขา", "หุบเขา", "ป้อม", "วิหาร", "ค่าย"][rng.randi() % 5] + _word(rng, 2)
		nodes[nid] = { "name": place, "type": WorldDB.NodeType.GREAT_SECT if factions[f].great else WorldDB.NodeType.RIVAL_SECT,
			"region": region_of.call(seat_cells[i]), "cell": seat_cells[i], "faction": f, "desc": "ที่ตั้งของ%s" % factions[f].name }
		factions[f].seat = nid
	for f in ids:
		if factions[f].seat == "": factions[f].seat = city_ids[0]

	# ── พื้นที่ป่า / ดันเจี้ยน / แดนลับ ──
	var wild_cells = _spread(land, 14, 4.0, rng, taken)
	for i in wild_cells.size():
		var b: int = biome_at.call(wild_cells[i])
		var info = WILD_BY_BIOME.get(b, WILD_BY_BIOME[WorldGen.Biome.GRASS])
		nodes["sw%d" % i] = { "name": ["ป่า", "ทุ่ง", "ผา", "ลำธาร", "หุบ"][rng.randi() % 5] + _word(rng, 2), "type": WorldDB.NodeType.WILD,
			"region": region_of.call(wild_cells[i]), "cell": wild_cells[i], "desc": "พื้นที่รกร้างที่สัตว์อสูรและโจรซ่องสุม",
			"enemies": info.enemies, "gather": info.gather }
	var dungeon_cells = _spread(land, DUNGEONS.size(), 4.0, rng, taken)
	for i in dungeon_cells.size():
		var d = DUNGEONS[i]
		nodes["sd%d" % i] = { "name": d.name + _word(rng, 1), "type": WorldDB.NodeType.DUNGEON, "region": region_of.call(dungeon_cells[i]),
			"cell": dungeon_cells[i], "desc": "ดันเจี้ยนอันตราย มีสมบัติซ่อนอยู่", "enemies": d.enemies, "gather": d.gather }
	var realm_cell = _spread(land.filter(func(c): return biome_at.call(c) in [WorldGen.Biome.MOUNTAIN, WorldGen.Biome.HILLS, WorldGen.Biome.SNOW]), 1, 4.0, rng, taken)
	if realm_cell.is_empty(): realm_cell = _spread(land, 1, 2.0, rng, taken)
	nodes["secret_realm"] = { "name": "แดนลับบรรพกาล", "type": WorldDB.NodeType.SECRET_REALM, "region": region_of.call(realm_cell[0]), "cell": realm_cell[0],
		"desc": "แดนลับที่เปิดทุกๆ 100 วัน สำนักทั้งแผ่นดินจะส่งศิษย์หัวกะทิมาแย่งชิงสมบัติ" }

	# ── เจ้าเมือง: ขั้วอำนาจที่อยู่ใกล้ที่สุด 3 ฝ่าย (เมืองหลวง = ราชสำนัก) ──
	for cid in city_ids:
		if cid == city_ids[0]:
			nodes[cid].lords = ["f_court", "f_eunuchs"]
			continue
		var near = ids.filter(func(f): return nodes.has(factions[f].seat) and nodes[factions[f].seat].has("cell"))
		near.sort_custom(func(a, b): return Vector2(nodes[factions[a].seat].cell).distance_to(Vector2(nodes[cid].cell)) < Vector2(nodes[factions[b].seat].cell).distance_to(Vector2(nodes[cid].cell)))
		nodes[cid].lords = near.slice(0, 3)

	# ── จุดตั้งสำนักของผู้เล่น ──
	var sites = []
	var site_cells = _spread(land.filter(func(c): return biome_at.call(c) == WorldGen.Biome.GRASS), 5, 5.0, rng, taken)
	for i in site_cells.size():
		sites.append({ "id": "sb_site_%d" % i, "name": "ที่ราบ" + _word(rng, 2), "region": region_of.call(site_cells[i]), "cell": site_cells[i] })

	# ── ผังเมืองแบบเดินสำรวจ ──
	var custom = {}
	var demonic_seats = ids.filter(func(f): return factions[f].bloc == "demonic").map(func(f): return nodes.get(factions[f].seat, {}).get("cell", Vector2i(-99, -99)))
	for i in city_ids.size():
		var cid: String = city_ids[i]
		var c: Vector2i = nodes[cid].cell
		var b: int = biome_at.call(c)
		var theme = "capital" if i == 0 else ("desert" if b == WorldGen.Biome.SAND else ("south" if b == WorldGen.Biome.FOREST and rng.randf() < 0.5 else "trade"))
		var blds = ["palace", "arena", "market", "tavern", "auction", "intel_house", "clinic", "faction_hall", "assassin_guild"] if i == 0 else ["market", "tavern", "clinic"]
		if i > 0:
			if nodes[cid].auction: blds.append("auction")
			if ids.any(func(f): return factions[f].seat == cid) or rng.randf() < 0.3: blds.append("faction_hall")
			for dc in demonic_seats:
				if Vector2(dc).distance_to(Vector2(c)) < 18 and not blds.has("assassin_guild"):
					blds.append_array(["poison_shop", "assassin_guild"])
		custom[cid] = { "theme": theme, "river": rng.randf() < 0.4, "buildings": blds }

	var blocs = FactionDB.LORE_BLOCS.duplicate(true)
	var strongest = func(bloc: String) -> String:
		var best = ""
		for f in ids:
			if factions[f].bloc == bloc and (best == "" or factions[f].power > factions[best].power): best = f
		return best
	blocs.righteous.leader = strongest.call("righteous")
	blocs.righteous.name = "พันธมิตร" + factions[blocs.righteous.leader].name.trim_prefix("สำนัก").trim_prefix("พรรค")
	blocs.demonic.leader = strongest.call("demonic")
	blocs.demonic.name = "แนวร่วมมาร" + _word(rng, 1)
	blocs.eunuch.name = factions.f_eunuchs.name

	WorldDB.NODES = nodes
	WorldDB.START_SITES = sites
	FactionDB.FACTIONS = factions
	FactionDB.BLOCS = blocs
	CityDB.custom = custom

static func _faction(rng: RandomNumberGenerator, fname: String, align: String, bloc: String, power_range: Array, seat: String, style: String) -> Dictionary:
	_used_names[fname] = true
	var status = ["", "", "seal", "poison"][rng.randi() % 4] if align != "มาร" else ["poison", "gu", "seal"][rng.randi() % 3]
	var leader = NPCGenerator.SURNAMES[rng.randi() % NPCGenerator.SURNAMES.size()] + NPCGenerator.FIRST_NAMES[rng.randi() % NPCGenerator.FIRST_NAMES.size()]
	var descs = {
		"righteous": "สำนักฝ่ายธรรมะที่ปกป้องผู้อ่อนแอ (สุ่มขึ้นในโลกโกลาหล)", "demonic": "ฝ่ายมารผู้กระหายอำนาจ (สุ่มขึ้นในโลกโกลาหล)",
		"eunuch": "ขั้วอำนาจในราชสำนัก (สุ่มขึ้นในโลกโกลาหล)", "independent": "ขั้วอิสระที่รักษาผลประโยชน์ของตน (สุ่มขึ้นในโลกโกลาหล)",
		"foreign": "ชนเผ่าและอาณาจักรชายขอบ (สุ่มขึ้นในโลกโกลาหล)",
	}
	return {
		"name": fname, "align": align, "bloc": bloc, "great": false, "color": Color.from_hsv(rng.randf(), rng.randf_range(0.35, 0.8), rng.randf_range(0.55, 0.95)),
		"seat": seat, "power": rng.randi_range(power_range[0], power_range[1]), "style": style, "status_attack": status,
		"leader": leader, "desc": descs[bloc], "allies": [], "enemies": [],
	}

static func _word(rng: RandomNumberGenerator, n: int) -> String:
	var s = ""
	for i in n: s += SYL[rng.randi() % SYL.size()]
	return s

## แผ่นดินผืนใหญ่ที่สุด (ไม่รวมแหล่งน้ำ) ให้ทุกสถานที่เดินถึงกันได้
static func _largest_land(biomes: PackedByteArray) -> Array:
	var W = WorldGen.WIDTH
	var H = WorldGen.HEIGHT
	var seen := {}
	var best: Array = []
	for y in range(2, H - 2):
		for x in range(2, W - 2):
			var s = Vector2i(x, y)
			if seen.has(s) or biomes[y * W + x] <= WorldGen.Biome.WATER: continue
			var comp: Array = []
			var stack = [s]
			seen[s] = true
			while not stack.is_empty():
				var c: Vector2i = stack.pop_back()
				comp.append(c)
				for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var n: Vector2i = c + d
					if n.x < 2 or n.y < 2 or n.x >= W - 2 or n.y >= H - 2 or seen.has(n): continue
					if biomes[n.y * W + n.x] > WorldGen.Biome.WATER:
						seen[n] = true
						stack.append(n)
			if comp.size() > best.size(): best = comp
	best.sort()
	return best

## เลือกจุดกระจายห่างกันอย่างน้อย min_dist และห่างจากจุดที่ถูกใช้แล้ว (taken)
static func _spread(cells: Array, count: int, min_dist: float, rng: RandomNumberGenerator, taken: Array) -> Array:
	var result: Array = []
	if cells.is_empty(): return result
	for i in count * 40:
		if result.size() >= count: break
		var c: Vector2i = cells[rng.randi() % cells.size()]
		var ok = true
		for o in result + taken:
			if Vector2(c).distance_to(Vector2(o)) < min_dist:
				ok = false
				break
		if ok: result.append(c)
	taken.append_array(result)
	return result
