extends RefCounted
class_name RosterSys

## ตัวละครมีชื่อ (Roster): คนจริงที่อยู่ตามเมือง/สำนักบนแผนที่โลก เดินเข้าไปคุย ผูกสัมพันธ์ ท้าประลอง แล้วชวนเข้าสำนักได้
## - สร้างตอนเริ่มโลก (init_world, ซ้ำได้ตาม world_seed) เก็บใน SectData.roster เป็น Dictionary ต่อคน
## - ความเต็มใจ = ผลรวมเหตุผลที่ "อธิบายได้" (ชื่อเสียง, ความสัมพันธ์, แนวทางสำนัก, สังกัดเดิม, ข้อเสนอ) ต้องถึง NEED จึงสำเร็จ
## - ตัวตนเต็ม (DiscipleData) สร้างเมื่อจำเป็นด้วย seed ของ entry เพื่อให้ได้หน้าตา/ค่าพลังเดิมทุกครั้ง

const NEED = 45
const GIFT_BASE = 100
const MAX_INSIGHT = 3

static var _cache := {}

# ══════════════════════════════════════════
# สร้างโลก
# ══════════════════════════════════════════

static func init_world(sect: SectData) -> void:
	if not sect.roster.is_empty() or sect.world_seed == 0: return
	var rng = RandomNumberGenerator.new()
	rng.seed = hash([sect.world_seed, 7])
	var n = 0
	if sect.world_mode == "story":
		for l in RosterDB.LEGENDS:
			if not WorldDB.NODES.has(l.node): continue
			if l.faction != "" and not FactionDB.FACTIONS.has(l.faction): continue
			sect.roster.append(_finish(sect, rng, n, l.duplicate()))
			n += 1
	for id in WorldDB.NODES:
		var node = WorldDB.NODES[id]
		match node.type:
			WorldDB.NodeType.CITY:
				for i in 2:
					var kind: String = RosterDB.KINDS.keys()[rng.randi() % RosterDB.KINDS.size()]
					sect.roster.append(_finish(sect, rng, n, _kind_entry(rng, kind, id)))
					n += 1
			WorldDB.NodeType.RIVAL_SECT, WorldDB.NodeType.GREAT_SECT:
				var fid: String = node.get("faction", "")
				if fid == "" or not FactionDB.FACTIONS.has(fid): continue
				for i in (2 if node.type == WorldDB.NodeType.GREAT_SECT else 1):
					sect.roster.append(_finish(sect, rng, n, _disciple_entry(rng, id, fid)))
					n += 1

static func _name(rng: RandomNumberGenerator, female: bool) -> String:
	var first = NPCGenerator.FEMALE_NAMES if female else NPCGenerator.FIRST_NAMES
	return NPCGenerator.SURNAMES[rng.randi() % NPCGenerator.SURNAMES.size()] + first[rng.randi() % first.size()]

static func _kind_entry(rng: RandomNumberGenerator, kind: String, node: String) -> Dictionary:
	var k = RosterDB.KINDS[kind]
	var tier = 2 if rng.randf() < 0.08 else (1 if rng.randf() < 0.4 else 0)
	return {
		"kind": kind, "name": _name(rng, rng.randf() < 0.4), "title": k.title, "node": node, "faction": "",
		"tier": tier, "level": 3 + tier * 4 + rng.randi_range(0, 4), "style": k.styles[rng.randi() % k.styles.size()],
		"wants": k.wants[rng.randi() % k.wants.size()], "expect": [60, 220, 650][tier] + rng.randi_range(0, 80), "bio": k.bio,
	}

static func _disciple_entry(rng: RandomNumberGenerator, node: String, fid: String) -> Dictionary:
	var f = FactionDB.FACTIONS[fid]
	var tier = 2 if rng.randf() < 0.12 else 1
	var evil = f.align == "มาร"
	return {
		"kind": "disciple", "name": _name(rng, fid in ["f_qinmu", "f_hundred_flowers"] or rng.randf() < 0.3),
		"title": "%s แห่ง%s" % [RosterDB.DISCIPLE_TITLES[rng.randi() % RosterDB.DISCIPLE_TITLES.size()], f.name],
		"node": node, "faction": fid, "tier": tier, "level": 6 + tier * 4 + rng.randi_range(0, 4), "style": f.style,
		"wants": (["มาร", "ชื่อเสียง"] if evil else ["ธรรมะ", "ชื่อเสียง"]) if f.align != "กลาง" else ["ชื่อเสียง", "ศึกประลอง"],
		"expect": [0, 350, 900][tier] + rng.randi_range(0, 150),
		"bio": "ศิษย์ที่ดีที่สุดของ%s การชวนตัวมาถือเป็นการซื้อตัว สำนักเดิมจะไม่พอใจ" % f.name,
	}

## เติมฟิลด์ที่ทุก entry ต้องมี
static func _finish(sect: SectData, rng: RandomNumberGenerator, n: int, e: Dictionary) -> Dictionary:
	e["id"] = e.get("id", "r_%d" % n)
	e["kind"] = e.get("kind", "legend")
	e["seed"] = rng.randi() % 1000000 + 1
	e["element"] = e.get("element", CultivationSys.ELEMENT_COLORS.keys()[rng.randi() % 6])
	e["cost"] = 200 + int(e.tier) * 400 + int(e.level) * 30
	e["opinion"] = 0
	e["insight"] = 0
	e["known"] = false
	e["status"] = "free"
	e["sparred"] = false
	e["last_chat"] = -99
	e["last_gift"] = -99
	var skill = SkillDB.get_random_skill_by_tier_and_type(int(e.tier) + 1, e.style)
	e["skill"] = skill
	e["fame"] = int(e.tier) * 60 + rng.randi_range(0, 40)
	return e

# ══════════════════════════════════════════
# ค้นหา / ตัวตน
# ══════════════════════════════════════════

static func get_entry(sect: SectData, id: String) -> Dictionary:
	for e in sect.roster:
		if e.id == id: return e
	return {}

## คนที่ยังอิสระอยู่ที่ node นี้
static func at_node(sect: SectData, node_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in sect.roster:
		if e.node == node_id and e.status == "free": out.append(e)
	return out

## สร้างตัวตนเต็มของ entry (ค่าเดิมทุกครั้งด้วย seed)
static func build(e: Dictionary) -> DiscipleData:
	var ck = "%s:%s" % [e.id, e.seed]
	if _cache.has(ck): return _cache[ck]
	seed(e.seed)
	var npc = NPCGenerator.generate_npc(int(e.tier), int(e.level))
	randomize()
	npc.disciple_name = e.name
	npc.title = e.get("title", "")
	npc.affinity_style = e.style
	npc.element = e.element
	npc.level = int(e.level)
	npc.realm_name = CultivationSys.get_realm_info(npc.level).name
	npc.fame = int(e.get("fame", 0))
	npc.background_story = e.get("bio", npc.background_story)
	npc.ambition = "ติดตามผู้ที่คู่ควร"
	if e.get("skill", "") != "":
		npc.innate_skills.assign([e.skill])
		if not npc.learned_skills.has(e.skill): npc.learned_skills.append(e.skill)
		MasterySys.grant_background(npc, e.skill)
	_cache[ck] = npc
	return npc

static func power(e: Dictionary) -> int:
	return build(e).get_power_rating()

static func node_name(e: Dictionary) -> String:
	return WorldDB.NODES.get(e.node, {}).get("name", "ไม่ทราบที่")

## เปิดเผยที่อยู่ของคนที่ยังไม่รู้จัก 1 คน (ข่าวลือ/สายลับ) คืน entry หรือ {}
static func reveal_one(sect: SectData) -> Dictionary:
	var pool = sect.roster.filter(func(e): return e.status == "free" and not e.known)
	if pool.is_empty(): return {}
	var e: Dictionary = pool[randi() % pool.size()]
	e.known = true
	return e

static func discover_at(sect: SectData, node_id: String) -> void:
	for e in at_node(sect, node_id): e.known = true

# ══════════════════════════════════════════
# ความเต็มใจ (อธิบายได้)
# ══════════════════════════════════════════

## คืน { score, need, lines: [{ text, value }] } offer = เงินที่เสนอเพิ่ม
static func willingness(sect: SectData, e: Dictionary, offer := 0) -> Dictionary:
	var lines: Array = []
	var rep = ReputationSys.score(sect)
	var expect = maxi(1, int(e.expect))
	var fame_v = clampf((float(rep) / expect - 1.0) * 40.0, -40.0, 30.0)
	lines.append({ "text": "ชื่อเสียงสำนัก %d เทียบความคาดหวัง %d" % [rep, expect], "value": int(fame_v) })
	lines.append({ "text": "ความรู้สึกที่มีต่อเรา", "value": clampi(int(e.opinion), -30, 25) })
	var wants: Array = e.wants
	if "ธรรมะ" in wants:
		if sect.alignment >= 25: lines.append({ "text": "ชอบแนวทางธรรมะของสำนัก", "value": 12 })
		elif sect.alignment <= -25: lines.append({ "text": "รังเกียจแนวทางมารของสำนัก", "value": -25 })
	if "มาร" in wants:
		if sect.alignment <= -25: lines.append({ "text": "ถูกใจแนวทางที่ไม่ถือกฎของสำนัก", "value": 12 })
		elif sect.alignment >= 25: lines.append({ "text": "ไม่ชอบแนวทางธรรมะที่เคร่งครัด", "value": -25 })
	if "ศึกประลอง" in wants:
		lines.append({ "text": "ต้องการพิสูจน์ฝีมือ" + (" (ท่านเคยชนะเขาแล้ว)" if e.sparred else " (ยังไม่เคยประลอง)"), "value": 15 if e.sparred else -10 })
	if e.faction != "" and sect.factions.has(e.faction):
		var rel: int = sect.factions[e.faction].relation
		lines.append({ "text": "ความสัมพันธ์กับ%s (สังกัดเดิม)" % FactionSys.fname(e.faction), "value": clampi(int(rel * 0.2), -15, 15) })
		lines.append({ "text": "ต้องทิ้งสังกัดเดิม", "value": -10 })
	if offer > 0:
		lines.append({ "text": "เงินที่เสนอ %d" % offer, "value": mini(30, int(20.0 * offer / maxi(1, int(e.cost)))) })
	var total = 0
	for l in lines: total += l.value
	# ประตูชื่อเสียง: ยอดฝีมือไม่ยอมเข้าสำนักที่ชื่อเสียงต่ำกว่า 60% ของที่คาดหวัง ไม่ว่าจะให้ของกำนัลเท่าไร
	var gated = rep < expect * 0.6
	if gated:
		lines.append({ "text": "สำนักยังไม่มีชื่อพอให้เขาเสียหน้าตามมา (ต้องมีชื่อเสียง ≥ %d)" % int(expect * 0.6), "value": -100 })
		total -= 100
	return { "score": total, "need": NEED, "lines": lines, "gated": gated }

## ข้อความอธิบายตัวตน ตามระดับความรู้จัก (insight 0..3 เพิ่มเมื่อคุยกันแต่ละวัน)
static func describe(e: Dictionary) -> String:
	var parts: Array[String] = ["%s %s · อยู่ที่%s" % [e.title, e.name, node_name(e)]]
	if e.faction != "": parts.append("สังกัด: " + FactionSys.fname(e.faction))
	parts.append(e.bio)
	var npc = build(e)
	if e.insight >= 1:
		parts.append("%s · สาย%s ธาตุ%s · พลังรบ ~%d" % [npc.realm_name, npc.affinity_style_name(), npc.element, power(e)])
	else:
		parts.append("(ยังไม่รู้จักกันดีพอ — ลองชวนคุยหลายๆ วัน)")
	if e.insight >= 2: parts.append("ใส่ใจเรื่อง: " + ", ".join(e.wants))
	if e.insight >= 3 and e.get("skill", "") != "": parts.append("วิชาประจำตัว: " + e.skill)
	return "\n".join(parts)

# ══════════════════════════════════════════
# การกระทำ
# ══════════════════════════════════════════

static func chat(sect: SectData, e: Dictionary) -> String:
	if e.last_chat == sect.current_day: return "วันนี้คุยกันไปแล้ว พรุ่งนี้ค่อยมาใหม่"
	e.last_chat = sect.current_day
	e.insight = mini(MAX_INSIGHT, int(e.insight) + 1)
	e.opinion = int(e.opinion) + 3
	return "%s เปิดใจพูดคุยกับท่านมากขึ้น (รู้จักกันระดับ %d/%d)" % [e.name, e.insight, MAX_INSIGHT]

static func gift_cost(e: Dictionary) -> int:
	return GIFT_BASE * (int(e.tier) + 1)

static func gift(sect: SectData, e: Dictionary) -> String:
	var cost = gift_cost(e)
	if sect.money < cost: return "เงินไม่พอ (ต้องการ %d)" % cost
	if e.last_gift == sect.current_day: return "วันนี้ให้ของกำนัลไปแล้ว"
	sect.money -= cost
	e.last_gift = sect.current_day
	var gain = 8 + (6 if "ของกำนัล" in e.wants else 0)
	e.opinion = int(e.opinion) + gain
	return "%s รับของกำนัลอย่างพอใจ (ความรู้สึก +%d)" % [e.name, gain]

## ศัตรูสำหรับประลองทดสอบ (พลังประมาณ 90% ของตัวจริง จะได้ไม่ฆ่ากัน)
static func spar_fighter(e: Dictionary) -> Dictionary:
	var foe = StatSys.build_fighter(power(e) * 0.9, 4.0)
	foe.merge({ "id": "roster_" + e.id, "name": e.name, "art": "human", "color": Color(1, 0.85, 0.4), "status_attack": "", "reward_money": 0, "reward_food": 0, "reward_exp": 40 + int(e.tier) * 60, "drops": {} })
	foe["hp"] = foe.max_hp
	return foe

static func on_spar_win(sect: SectData, id: String) -> String:
	var e = get_entry(sect, id)
	if e.is_empty(): return ""
	e.sparred = true
	e.opinion = int(e.opinion) + 15
	return "%s ยอมรับในฝีมือของท่าน (ความรู้สึก +15)" % e.name

## ชวนเข้าสำนัก: สำเร็จเมื่อคะแนนความเต็มใจ ≥ NEED คืนข้อความผล
static func recruit(sect: SectData, e: Dictionary, mgr: SectManager, offer := 0) -> Dictionary:
	if sect.get_active_disciples().size() >= sect.get_max_disciples():
		return { "ok": false, "text": "สำนักเต็มแล้ว (อัปเกรดโถงหลักก่อน)" }
	if sect.money < offer: return { "ok": false, "text": "เงินไม่พอสำหรับข้อเสนอ" }
	var w = willingness(sect, e, offer)
	if w.score < w.need:
		e.opinion = int(e.opinion) - 2
		return { "ok": false, "text": "%s ปฏิเสธ — ยังไม่น่าไว้ใจพอ (คะแนน %d / ต้องการ %d)" % [e.name, w.score, w.need] }
	sect.money -= offer
	e.status = "recruited"
	var npc = build(e)
	_cache.erase("%s:%s" % [e.id, e.seed])
	PawnSys.ensure(npc, sect)
	npc.pos = Territory.gate_pos()
	npc.loyalty = clampf(55.0 + int(e.opinion) * 0.6, 40.0, 100.0)
	sect.disciples.append(npc)
	for s in npc.innate_skills: sect.add_library_skill(s)
	if e.faction != "" and sect.factions.has(e.faction):
		FactionSys.change_rel(sect, "player", e.faction, -8)
	var text = "%s (%s) ตกลงเข้าร่วมสำนัก! (%s · พลังรบ %d)" % [npc.disciple_name, e.title, npc.realm_name, npc.get_power_rating()]
	mgr.log_event("[color=gold]%s[/color]" % text)
	return { "ok": true, "text": text }
