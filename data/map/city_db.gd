extends RefCounted
class_name CityDB

## ข้อมูลผังเมืองแบบเดินสำรวจได้ (Interactive City Hubs)
## แต่ละเมืองใน WorldDB มีธีม (พื้น/กำแพง/ต้นไม้) และรายการอาคารที่ต่างกัน
## เช่น นครเมฆาโลหิตมีวังหลวงและลานประลองขนาดใหญ่ เมืองทางเสฉวน/ตลาดมืดมีสมาคมนักฆ่าและร้านยาพิษซ่อนในตรอก
## ผังจริงสร้างโดย CityLayout (คงที่ต่อเมือง เดินกลับมากี่ครั้งก็เหมือนเดิม)

## อาคาร: service = หน้าต่างที่เปิดเมื่อเข้าประตู (ดู CityServices), size = ขนาดฐาน (ช่อง), hidden = ซ่อนอยู่ปลายตรอกมืด
const BUILDINGS = {
	"market": { "name": "ตลาดการค้า", "service": "market", "size": Vector2i(5, 3), "wall": Color(0.75, 0.62, 0.45), "roof": Color(0.55, 0.2, 0.15) },
	"tavern": { "name": "โรงเตี๊ยม", "service": "tavern", "size": Vector2i(5, 4), "wall": Color(0.7, 0.55, 0.38), "roof": Color(0.3, 0.25, 0.22) },
	"auction": { "name": "โรงประมูลของวิเศษ", "service": "auction", "size": Vector2i(5, 4), "wall": Color(0.85, 0.75, 0.55), "roof": Color(0.55, 0.15, 0.4) },
	"clinic": { "name": "โรงหมอ", "service": "clinic", "size": Vector2i(4, 3), "wall": Color(0.85, 0.85, 0.78), "roof": Color(0.2, 0.45, 0.3) },
	"intel_house": { "name": "หอข่าวสาร", "service": "intel", "size": Vector2i(4, 4), "wall": Color(0.8, 0.6, 0.65), "roof": Color(0.6, 0.25, 0.45) },
	"faction_hall": { "name": "สำนักงานใหญ่", "service": "faction", "size": Vector2i(6, 4), "wall": Color(0.82, 0.78, 0.7), "roof": Color(0.25, 0.3, 0.45) },
	"poison_shop": { "name": "ร้านยาพิษลับ", "service": "poison", "size": Vector2i(3, 3), "wall": Color(0.35, 0.4, 0.3), "roof": Color(0.15, 0.25, 0.15), "hidden": true },
	"assassin_guild": { "name": "สมาคมนักฆ่า", "service": "assassin", "size": Vector2i(4, 3), "wall": Color(0.3, 0.27, 0.3), "roof": Color(0.12, 0.1, 0.12), "hidden": true },
	"arena": { "name": "ลานประลองยุทธ์หลวง", "service": "arena", "size": Vector2i(8, 5), "wall": Color(0.75, 0.7, 0.6), "roof": Color(0.6, 0.15, 0.1), "landmark": true },
	"palace": { "name": "พระราชวังเมฆาโลหิต", "service": "palace", "size": Vector2i(12, 6), "wall": Color(0.75, 0.2, 0.18), "roof": Color(0.95, 0.75, 0.2), "landmark": true },
	"temple": { "name": "วิหารโดมทอง", "service": "faction", "size": Vector2i(8, 5), "wall": Color(0.95, 0.88, 0.65), "roof": Color(1.0, 0.8, 0.25), "landmark": true },
	"tent_hall": { "name": "กระโจมข่าน", "service": "faction", "size": Vector2i(7, 5), "wall": Color(0.8, 0.72, 0.6), "roof": Color(0.6, 0.35, 0.2), "landmark": true, "tent": true },
	"dock": { "name": "ท่าเรือสินค้า", "service": "market", "size": Vector2i(6, 3), "wall": Color(0.5, 0.4, 0.3), "roof": Color(0.3, 0.35, 0.45) },
	"sect_hall": { "name": "ท้องพระโรงสำนัก", "service": "faction", "size": Vector2i(6, 4), "wall": Color(0.82, 0.78, 0.7), "roof": Color(0.25, 0.3, 0.45) },
	"sect_library": { "name": "หอคัมภีร์", "service": "scripture", "size": Vector2i(5, 4), "wall": Color(0.75, 0.7, 0.6), "roof": Color(0.2, 0.3, 0.5) },
	"sect_yard": { "name": "ลานฝึกยุทธ์", "service": "sparring", "size": Vector2i(6, 3), "wall": Color(0.7, 0.62, 0.5), "roof": Color(0.55, 0.2, 0.15) },
	"sect_dorm": { "name": "เรือนศิษย์", "service": "", "size": Vector2i(3, 3), "wall": Color(0.78, 0.72, 0.6), "roof": Color(0.35, 0.3, 0.28) },
	"sect_pagoda": { "name": "เจดีย์บรรพชน", "service": "", "size": Vector2i(3, 3), "wall": Color(0.85, 0.82, 0.72), "roof": Color(0.3, 0.32, 0.4) },
	"sect_bell": { "name": "หอระฆัง", "service": "", "size": Vector2i(3, 2), "wall": Color(0.7, 0.45, 0.3), "roof": Color(0.75, 0.55, 0.2) },
	"sect_alchemy": { "name": "หอโอสถ", "service": "clinic", "size": Vector2i(4, 3), "wall": Color(0.78, 0.8, 0.7), "roof": Color(0.25, 0.45, 0.32) },
	"sect_forge": { "name": "โรงตีอาวุธ", "service": "market", "size": Vector2i(4, 3), "wall": Color(0.5, 0.45, 0.42), "roof": Color(0.25, 0.22, 0.22) },
	"sect_poison_garden": { "name": "สวนสมุนไพรพิษ", "service": "poison", "size": Vector2i(4, 3), "wall": Color(0.4, 0.45, 0.32), "roof": Color(0.2, 0.32, 0.18) },
	"sect_altar": { "name": "แท่นบูชาโลหิต", "service": "", "size": Vector2i(3, 2), "wall": Color(0.35, 0.15, 0.15), "roof": Color(0.6, 0.08, 0.1) },
	"sect_sword_tomb": { "name": "สุสานกระบี่", "service": "", "size": Vector2i(4, 2), "wall": Color(0.55, 0.55, 0.58), "roof": Color(0.35, 0.37, 0.42) },
	"sect_tower": { "name": "หอสังเกตการณ์", "service": "", "size": Vector2i(2, 2), "wall": Color(0.55, 0.45, 0.35), "roof": Color(0.3, 0.2, 0.15) },
	"house": { "name": "บ้านเรือน", "service": "", "size": Vector2i(3, 3), "wall": Color(0.78, 0.7, 0.58), "roof": Color(0.35, 0.3, 0.28) },
	"tent": { "name": "กระโจม", "service": "", "size": Vector2i(3, 3), "wall": Color(0.85, 0.8, 0.7), "roof": Color(0.6, 0.45, 0.3), "tent": true },
}

## ธีมเมือง: ground = พื้นหลัก, walls = มีกำแพงเมือง, river = มีแม่น้ำผ่าน, tree = สีต้นไม้
const THEMES = {
	"capital": { "ground": "grass", "walls": true, "tree": Color(0.25, 0.45, 0.25) },
	"trade": { "ground": "grass", "walls": true, "tree": Color(0.28, 0.5, 0.28) },
	"jiangnan": { "ground": "grass", "walls": true, "tree": Color(0.3, 0.55, 0.35) },
	"frontier": { "ground": "dirt", "walls": true, "tree": Color(0.3, 0.42, 0.28) },
	"south": { "ground": "jungle", "walls": false, "tree": Color(0.15, 0.4, 0.2) },
	"port": { "ground": "sand", "walls": false, "tree": Color(0.35, 0.55, 0.3) },
	"steppe": { "ground": "snowgrass", "walls": false, "tree": Color(0.35, 0.45, 0.4) },
	"desert": { "ground": "sand", "walls": true, "tree": Color(0.4, 0.6, 0.25) },
	"sect": { "ground": "grass", "walls": true, "tree": Color(0.25, 0.5, 0.3), "filler": "sect_dorm" },
}

## ผังของแต่ละเมือง: theme, buildings (บริการที่มี นอกจากบ้านเรือน), river
const CITIES = {
	"c_xueyun": { "theme": "capital", "river": true, "buildings": ["palace", "arena", "market", "tavern", "auction", "intel_house", "clinic", "faction_hall", "assassin_guild"] },
	"c_luoyang": { "theme": "trade", "river": true, "buildings": ["market", "tavern", "auction", "clinic", "faction_hall"] },
	"c_kaifeng": { "theme": "trade", "river": false, "buildings": ["market", "tavern", "clinic", "faction_hall"] },
	"c_jinling": { "theme": "jiangnan", "river": true, "buildings": ["market", "tavern", "auction", "clinic", "faction_hall", "intel_house"] },
	"c_suzhou": { "theme": "jiangnan", "river": true, "buildings": ["market", "tavern", "clinic", "faction_hall"] },
	"c_hangzhou": { "theme": "port", "river": true, "buildings": ["dock", "tavern", "auction", "poison_shop", "assassin_guild"] },
	"c_wuhan": { "theme": "jiangnan", "river": true, "buildings": ["dock", "market", "tavern", "clinic"] },
	"c_beijing": { "theme": "frontier", "river": false, "buildings": ["market", "tavern", "clinic", "faction_hall"] },
	"c_xian": { "theme": "frontier", "river": false, "buildings": ["market", "tavern", "auction", "intel_house", "clinic", "faction_hall", "assassin_guild"] },
	"c_lanzhou": { "theme": "desert", "river": true, "buildings": ["market", "tavern", "clinic"] },
	"c_huashan_town": { "theme": "trade", "river": false, "buildings": ["market", "tavern", "clinic"] },
	"c_chengdu": { "theme": "trade", "river": true, "buildings": ["market", "tavern", "clinic", "poison_shop", "assassin_guild"] },
	"c_wudang_town": { "theme": "trade", "river": false, "buildings": ["market", "tavern", "clinic"] },
	"c_dali": { "theme": "south", "river": false, "buildings": ["market", "tavern", "clinic", "poison_shop", "assassin_guild"] },
	"c_blood_moon": { "theme": "south", "river": false, "buildings": ["market", "tavern", "auction", "poison_shop", "assassin_guild"] },
	"c_karakorum": { "theme": "steppe", "river": false, "buildings": ["tent_hall", "market", "tavern", "clinic"] },
	"c_oasis": { "theme": "desert", "river": false, "buildings": ["temple", "market", "tavern", "auction", "clinic"] },
	"c_storm_port": { "theme": "port", "river": false, "buildings": ["dock", "tavern", "auction", "assassin_guild", "poison_shop"] },
}

## ผังเมืองของโหมดแซนด์บ็อกซ์ (สร้างโดย SandboxGen)
static var custom: Dictionary = {}

static func get_city(city_id: String) -> Dictionary:
	if custom.has(city_id): return custom[city_id]
	if not CITIES.has(city_id) and is_sect_node(city_id):
		return { "theme": "sect", "river": false, "buildings": ["sect_hall", "sect_library", "sect_yard"] }
	return CITIES.get(city_id, { "theme": "trade", "river": false, "buildings": ["market", "tavern", "clinic"] })

## ลักษณะเฉพาะของแต่ละสำนัก (ใช้สร้างผังที่ไม่ซ้ำกัน): ชนิดผัง พื้น สีต้นไม้ สีหลังคา (สีประจำสำนัก) และอาคารพิเศษตามสายวิชา/แนวทาง
## kind: mountain (ยอดเขา ขั้นบันได สระน้ำ) · temple (อาราม ระเบียงคดรอบลานกลาง) · fortress (ป้อม/ค่าย กำแพงหนา ลานกว้าง)
##       valley (หุบเขา/ป่าพิษ บึงน้ำ สะพาน) · island (เกาะ/อ่าว น้ำล้อมรอบ ทราย) · manor (คฤหาสน์ สวนสระ) · tomb (สุสาน แนวป้ายหิน)
static func sect_profile(node_id: String) -> Dictionary:
	var node: Dictionary = WorldDB.NODES.get(node_id, {})
	var f: Dictionary = FactionDB.FACTIONS.get(node.get("faction", ""), {})
	var name: String = node.get("name", "")
	var region: String = node.get("region", "")
	var style: String = f.get("style", "sword")
	var align: String = f.get("align", "กลาง")
	var kind = "mountain"
	if name.contains("อาราม") or name.contains("วิหาร") or name.contains("วัด"): kind = "temple"
	elif name.contains("ป้อม") or name.contains("ค่าย") or name.contains("เมือง") or name.contains("นคร"): kind = "fortress"
	elif name.contains("เกาะ") or name.contains("อ่าว"): kind = "island"
	elif name.contains("คฤหาสน์"): kind = "manor"
	elif name.contains("สุสาน"): kind = "tomb"
	elif name.contains("หุบเขา") or name.contains("ป่า") or region == "south_poison": kind = "valley"
	var ground = "grass"
	match region:
		"south_poison": ground = "jungle"
		"north_steppe": ground = "snowgrass"
		"west_waste", "nw_underground": ground = "sand" if kind != "fortress" else "dirt"
		"east_coast": ground = "sand"
		"shanxi": ground = "dirt"
	var tree = { "mountain": Color(0.3, 0.55, 0.32), "temple": Color(0.85, 0.55, 0.62), "fortress": Color(0.32, 0.42, 0.3),
		"valley": Color(0.18, 0.38, 0.2), "island": Color(0.35, 0.58, 0.3), "manor": Color(0.4, 0.6, 0.35), "tomb": Color(0.3, 0.33, 0.3) }[kind]
	if align == "มาร": tree = tree.lerp(Color(0.35, 0.15, 0.2), 0.45)
	var extra: Array = []
	match style:
		"sword": extra.append("sect_sword_tomb")
		"palm": extra.append("sect_bell")
		"poison": extra.append("sect_poison_garden")
		"internal": extra.append("sect_alchemy")
		"formation": extra.append("sect_pagoda")
		"spear", "hidden_weapon": extra.append("sect_forge")
	if align == "มาร": extra.append("sect_altar")
	if node.get("type", -1) == WorldDB.NodeType.GREAT_SECT: extra.append_array(["sect_pagoda", "sect_alchemy"])
	if kind == "fortress": extra.append_array(["sect_tower", "sect_tower"])
	var uniq: Array = []
	for e in extra:
		if not uniq.has(e) or e == "sect_tower": uniq.append(e)
	var col: Color = f.get("color", Color(0.3, 0.35, 0.5))
	return {
		"kind": kind, "ground": ground, "tree": tree, "walls": kind in ["fortress", "temple", "manor"],
		"roof": col.darkened(0.35).lerp(Color(0.3, 0.25, 0.22), 0.25), "wall": Color(0.82, 0.78, 0.7).lerp(col, 0.15),
		"extra": uniq, "dorms": 7 if node.get("type", -1) == WorldDB.NodeType.GREAT_SECT else 4,
	}

## node ชนิดสำนักคู่แข่ง/สำนักใหญ่ที่เดินเข้าได้ (ใช้ผังสำนักอัตโนมัติ)
static func is_sect_node(node_id: String) -> bool:
	var t = WorldDB.NODES.get(node_id, {}).get("type", -1)
	return t == WorldDB.NodeType.RIVAL_SECT or t == WorldDB.NodeType.GREAT_SECT

static func get_theme(city_id: String) -> Dictionary:
	return THEMES[get_city(city_id).theme]

## ชื่ออาคารที่แสดงในเมือง (อาคารสำนักงานใหญ่ใช้ชื่อขั้วอำนาจที่ตั้งอยู่ในเมือง)
static func building_name(kind: String, city_id: String) -> String:
	var hq = WorldDB.get_city_hq(city_id)
	var cdata = WorldDB.get_node_data(city_id)
	var cname: String = cdata.get("name", "")
	var short_cname = cname.trim_prefix("นครหลวง").trim_prefix("นคร").trim_prefix("เมืองท่า").trim_prefix("เมือง")

	if kind.begins_with("sect_") and not hq.is_empty() and kind != "sect_dorm":
		return "%s (%s)" % [BUILDINGS[kind].name, FactionDB.FACTIONS[hq[0]].name]
	match kind:
		"faction_hall", "temple", "tent_hall":
			if not hq.is_empty():
				return "%s (%s)" % [BUILDINGS[kind].name, FactionDB.FACTIONS[hq[0]].name] if kind != "faction_hall" else "สำนักงานใหญ่" + FactionDB.FACTIONS[hq[0]].name
			elif WorldMode.is_sandbox():
				if kind == "tent_hall": return "กระโจมบัญชาการ"
				if kind == "temple": return "วิหารยุทธภพ"
		"intel_house":
			if not hq.is_empty():
				return "หอข่าวสาร (" + FactionDB.FACTIONS[hq[0]].name + ")"
			for f in ["f_baixiao", "f_hundred_flowers", "f_zhengci"]:
				if hq.has(f): return FactionDB.FACTIONS[f].name
		"assassin_guild":
			if not hq.is_empty():
				return "สมาคมนักฆ่า (" + FactionDB.FACTIONS[hq[0]].name + ")"
			if hq.has("f_assassin"): return "หอหมื่นสังหาร (ทางเข้าลับ)"
		"palace":
			if WorldMode.is_sandbox():
				var court_info = FactionDB.FACTIONS.get("f_court", {})
				var court_name: String = court_info.get("name", "")
				if court_name != "":
					return "พระราชวังหลวง (%s)" % court_name
				return "พระราชวังหลวง" + short_cname
			return "พระราชวังเมฆาโลหิต"
		"arena":
			if WorldMode.is_sandbox():
				return "ลานประลองยุทธ์" + short_cname
			return "ลานประลองยุทธ์หลวง"
	return BUILDINGS[kind].name
