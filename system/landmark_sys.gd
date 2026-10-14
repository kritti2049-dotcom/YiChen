extends RefCounted
class_name LandmarkSys

## จุดสำคัญบนแผนที่โลก (ดู LandmarkDB): แร่/คัมภีร์/ของวิเศษ ที่ต้องออกไปค้นหาและยึดครอง
## เก็บใน SectData.landmarks เป็น Dictionary ต่อจุด { id, node, kind, name, desc, known, claimed, ... }
## ค้นพบ: ข่าวลือ (reveal_one) / เยือนถิ่น (discover_at) / ข่าวตอนเริ่มเกม · ได้รับ: ยึดครองถิ่น (on_claim) หรือกวาดแดนลับ (on_realm)

static func init_world(sect: SectData) -> void:
	if not sect.landmarks.is_empty() or sect.world_seed == 0: return
	var rng = RandomNumberGenerator.new()
	rng.seed = hash([sect.world_seed, 11])
	if sect.world_mode == "story":
		for l in LandmarkDB.LORE:
			if WorldDB.NODES.has(l.node): sect.landmarks.append(_finish(l.duplicate(), rng))
	else:
		_sandbox(sect, rng)
	# ข่าวตอนเริ่ม: รู้จุดแร่ 1 และคัมภีร์ 1 จุด
	var got_ore = false
	var got_scroll = false
	for l in sect.landmarks:
		if l.kind == "ore" and not got_ore:
			l.known = true
			got_ore = true
		elif l.kind == "scripture" and not got_scroll:
			l.known = true
			got_scroll = true

static func _sandbox(sect: SectData, rng: RandomNumberGenerator) -> void:
	var nodes: Array = []
	for id in WorldDB.NODES:
		var t = WorldDB.NODES[id].type
		if t == WorldDB.NodeType.WILD or t == WorldDB.NodeType.DUNGEON or t == WorldDB.NodeType.SECRET_REALM: nodes.append(id)
	nodes.sort()
	for i in range(nodes.size() - 1, 0, -1):
		var j = rng.randi_range(0, i)
		var tmp = nodes[i]
		nodes[i] = nodes[j]
		nodes[j] = tmp
	var n = 0
	for i in 3:
		if n >= nodes.size(): break
		var o = LandmarkDB.SAND_ORES[i % LandmarkDB.SAND_ORES.size()]
		var nm: String = WorldDB.NODES[nodes[n]].name
		sect.landmarks.append(_finish({ "id": "lm_s%d" % n, "node": nodes[n], "kind": "ore", "name": "%s ที่%s" % [o.name, nm], "mat": o.mat, "rate": o.rate, "desc": "เส้นแร่หายากที่ซ่อนอยู่ใกล้%s" % nm }, rng))
		n += 1
	for i in 4:
		if n >= nodes.size(): break
		var style: String = LandmarkDB.SAND_STYLES[rng.randi() % LandmarkDB.SAND_STYLES.size()]
		var nm2: String = WorldDB.NODES[nodes[n]].name
		sect.landmarks.append(_finish({ "id": "lm_s%d" % n, "node": nodes[n], "kind": "scripture", "name": "ศิลาจารึกลับที่%s" % nm2, "tier": 2 + i % 3, "type": style, "desc": "คัมภีร์วิชาลับที่ถูกทิ้งไว้ที่%s" % nm2 }, rng))
		n += 1
	if n < nodes.size():
		var nm3: String = WorldDB.NODES[nodes[n]].name
		sect.landmarks.append(_finish({ "id": "lm_s%d" % n, "node": nodes[n], "kind": "relic", "slot": "artifact", "name": "ของวิเศษโบราณที่%s" % nm3, "desc": "ของวิเศษระดับตำนานที่ถูกผนึกไว้" }, rng))

static func _finish(l: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	l["known"] = false
	l["claimed"] = false
	l["acc"] = 0.0
	if l.kind == "scripture":
		var skill = SkillDB.get_random_skill_by_tier_and_type(int(l.tier), l.get("type", "")) if l.get("type", "") != "" else SkillDB.get_random_skill_by_tier(int(l.tier))
		l["skill"] = skill
	return l

# ── ค้นหา ──

static func at_node(sect: SectData, node_id: String, known_only := true) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for l in sect.landmarks:
		if l.node == node_id and (l.known or not known_only): out.append(l)
	return out

static func discover_at(sect: SectData, node_id: String) -> void:
	for l in at_node(sect, node_id, false): l.known = true

## เปิดเผยจุดที่ยังไม่รู้ 1 จุด (ข่าวลือ) คืน landmark หรือ {}
static func reveal_one(sect: SectData) -> Dictionary:
	var pool = sect.landmarks.filter(func(l): return not l.known)
	if pool.is_empty(): return {}
	var l: Dictionary = pool[randi() % pool.size()]
	l.known = true
	return l

static func kind_name(kind: String) -> String:
	return { "ore": "เส้นแร่", "scripture": "คัมภีร์ลับ", "relic": "ของวิเศษ", "stele": "ศิลาจารึก" }.get(kind, kind)

static func kind_color(kind: String) -> Color:
	return { "ore": Color(1, 0.6, 0.2), "scripture": Color(0.4, 0.7, 1), "relic": Color(0.85, 0.5, 1), "stele": Color(0.9, 0.9, 0.6) }.get(kind, Color.WHITE)

## ข้อความสถานะบนแผงข้อมูลของ node
static func status_text(sect: SectData, l: Dictionary) -> String:
	if l.kind == "ore":
		if sect.node_owner.get(l.node, "") == "player": return "กำลังขุด +%.1f %s/วัน" % [l.rate * sect.get_node_yield(l.node), MaterialDB.get_material_name(l.mat)]
		return "ยึดครองถิ่นนี้เพื่อขุดแร่ (%s %.1f/วัน)" % [MaterialDB.get_material_name(l.mat), l.rate]
	if l.kind == "stele": return "ส่งศิษย์ไปนั่งสมาธิ %d วัน ลุ้นตรัสรู้วิชาขั้น%s (เสี่ยงธาตุไฟ)" % [SkillQuestSys.MEDITATE_DAYS, SkillDB.TIER_NAMES[clampi(int(l.tier), 1, 5)]]
	if l.claimed: return "ได้มาแล้ว"
	if l.kind == "scripture": return "ยึดครองถิ่นนี้เพื่อได้คัมภีร์ (วิชาขั้น%s)" % SkillDB.TIER_NAMES[clampi(int(l.tier), 1, 5)]
	return "ได้เมื่อ%s" % ("กวาดคู่แข่งครบในแดนลับ" if l.get("get", "") == "realm" else "ยึดครองถิ่นนี้")

# ── ได้รับ ──

## ยึดครองถิ่น node_id สำเร็จ (คืนข้อความรางวัล)
static func on_claim(sect: SectData, node_id: String) -> Array[String]:
	var out: Array[String] = []
	for l in at_node(sect, node_id, false):
		l.known = true
		if l.kind == "ore": l.claimed = true
		elif not l.claimed and l.get("get", "claim") != "realm":
			var t = _grant(sect, l)
			if t != "": out.append(t)
	return out

## กวาดแดนลับสำเร็จ
static func on_realm(sect: SectData, node_id: String) -> Array[String]:
	var out: Array[String] = []
	for l in at_node(sect, node_id, false):
		if l.get("get", "") == "realm" and not l.claimed:
			var t = _grant(sect, l)
			if t != "": out.append(t)
	return out

static func _grant(sect: SectData, l: Dictionary) -> String:
	l.claimed = true
	l.known = true
	if l.kind == "scripture":
		sect.add_library_skill(l.skill)
		return "ได้คัมภีร์ \"%s\" วิชา %s เข้าหอตำรา!" % [l.name, l.skill]
	if l.kind == "relic":
		var eq = EquipmentDB.generate(EquipmentData.EquipType.ARTIFACT if l.get("slot", "") == "artifact" else EquipmentData.EquipType.ARMOR, EquipmentData.Rarity.LEGENDARY)
		eq.item_name = l.name
		sect.equipment_storage.append(eq)
		return "ได้ของวิเศษตำนาน \"%s\" (%s)" % [l.name, eq.get_stat_text().replace("\n", " ")]
	return ""

## รายวัน: เส้นแร่ที่เรายึดไว้ให้แร่เข้าคลัง
static func daily(sect: SectData, mgr: SectManager) -> void:
	for l in sect.landmarks:
		if l.kind != "ore" or not l.claimed or sect.node_owner.get(l.node, "") != "player": continue
		l.acc += l.rate * sect.get_node_yield(l.node)
		var n = int(l.acc)
		if n >= 1:
			l.acc -= n
			sect.add_material(l.mat, n)
			sect.sim_stats["ore_mined"] = sect.sim_stats.get("ore_mined", 0) + n
	if sect.current_day % 10 == 0:
		var total = 0
		for l in sect.landmarks:
			if l.kind == "ore" and l.claimed and sect.node_owner.get(l.node, "") == "player": total += 1
		if total > 0: mgr.log_event("เหมืองแร่หายาก %d แห่งส่งแร่เข้าคลังสำนัก" % total)
