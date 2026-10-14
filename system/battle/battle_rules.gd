extends RefCounted
class_name BattleRules

## กติกาการต่อสู้บนกริด (ไม่มี Node/ภาพ): สร้างยูนิต จัดสนาม เดิน ใช้ท่า คำนวณดาเมจ สถานะผิดปกติ
## ทุกการกระทำคืน "เหตุการณ์" (Array of Dictionary) ให้ฉากเล่นแอนิเมชันตาม → ทดสอบแบบไม่มีจอได้ (tools/battle_sim.gd)
## เหตุการณ์: move{id,path} · face{id,dir} · act{id,name,type,cells} · hit{id,dmg,crit,mult_text} · miss{id}
##           heal{id,amt} · shield{id,amt} · status{id,st} · knock{id,to,collide} · down{id} · log{text} · skip{id} · escape{id}

const STATUS_NAMES = { "seal": "สกัดจุด", "poison": "พิษ", "gu": "พิษกู่" }
const ATTACK = "โจมตี"
const QI_ON_ATTACK = 8
const QI_ON_DEFEND = 15
const QI_PER_TURN = 4

# ══════════════════════════════════════════
# สร้างยูนิต / จัดสนาม
# ══════════════════════════════════════════

static func _base_unit(id: int, team: int) -> Dictionary:
	return {
		"id": id, "team": team, "cell": Vector2i.ZERO, "facing": Vector2i(1, 0) if team == 0 else Vector2i(-1, 0),
		"ct": 0.0, "cd": {}, "status": {}, "shield_hp": 0, "defending": false, "dodge_bonus": 0.0, "move_bonus": 0,
		"down": false, "escaped": false, "moved": false, "acted": false, "auto": false, "last_stand_used": false,
	}

static func make_ally(id: int, d: DiscipleData) -> Dictionary:
	var u = _base_unit(id, 0)
	var hp = d.get_combat_max_hp()
	var skills: Array[String] = []
	for s in d.learned_skills:
		if not SkillDB.battle_spec(s).is_empty(): skills.append(s)
	u.merge({
		"name": d.disciple_name, "ref": d, "hp": hp, "max_hp": hp, "atk": d.get_combat_attack(), "def": d.get_combat_defense(),
		"spd": d.get_combat_speed(), "passives": d.get_passives(), "skills": skills, "level": d.level,
		"max_qi": 30 + d.level * 3, "qi": 0, "move": 3 + (1 if skills.any(func(s): return SkillDB.get_skill(s).type == "movement") else 0),
		"color": CultivationSys.get_aura_color(d.element, d.level), "status_attack": "",
		"weapon_type": MasterySys.weapon_type(d.equipped_weapon),
	}, true)
	u.qi = int(u.max_qi * 0.5)
	return u

static func make_enemy(id: int, e: Dictionary, mult: float) -> Dictionary:
	var u = _base_unit(id, 1)
	var hp = int(e.get("max_hp", 100) * mult)
	var lv = int(e.get("level", 1))
	u.merge({
		"name": e.get("name", "ศัตรู"), "ref": e, "hp": hp, "max_hp": hp, "atk": int(e.get("attack", 10) * mult),
		"def": int(e.get("defense", 5) * mult), "spd": e.get("speed", 10), "passives": [], "skills": [], "level": lv,
		"max_qi": 30 + lv * 3, "qi": 0, "move": 3, "color": Color(0.9, 0.3, 0.3), "status_attack": e.get("status_attack", ""),
		"weapon_type": "",
	}, true)
	return u

## ขนาดสนามตามภูมิประเทศ (กว้าง x ลึก)
const ARENA_BY_CONTEXT = {
	"arena": Vector2i(9, 7), "spar": Vector2i(9, 6), "roster_spar": Vector2i(9, 6), "recruit_duel": Vector2i(8, 5),
	"raid": Vector2i(13, 8), "siege": Vector2i(14, 8),
	"city_guard": Vector2i(14, 5), "bounty": Vector2i(14, 5),
}
const ARENA_BY_REGION = {
	"north_steppe": Vector2i(16, 7), "west_waste": Vector2i(15, 6),
	"shaanxi": Vector2i(13, 6), "shanxi": Vector2i(13, 7),
	"sichuan": Vector2i(10, 6), "south_poison": Vector2i(10, 7),
	"jiangnan": Vector2i(12, 6), "east_coast": Vector2i(13, 5), "jingji": Vector2i(12, 6),
	"hidden_dragon": Vector2i(11, 7), "nw_underground": Vector2i(9, 5),
}
const ARENA_DEFAULT = Vector2i(12, 6)
## บริบทที่เป็นลานวงกลมเสมอ (เวทีประลอง/ประลองฝีมือ) และขนาดเมื่อเป็นวงกลม (ให้ด้านกว้าง/ลึกใกล้กันขึ้น)
const CIRCLE_CONTEXTS = { "arena": Vector2i(11, 8), "spar": Vector2i(10, 7), "roster_spar": Vector2i(10, 7), "recruit_duel": Vector2i(9, 7) }
## ประเภทจุดบนแผนที่ที่สุ่มเป็นลานวงกลมได้ (ต่อจุด คงที่): แดนลับ = วงกลมเสมอ, ป่า/ถ้ำ = บางจุดเป็นลานโล่งกลางป่า/โถงถ้ำ
const CIRCLE_CHANCE = { "secret": 1.0, "wild": 0.3, "dungeon": 0.4 }
const ARENA_MIN = Vector2i(11, 7)
const ARENA_MAX = Vector2i(24, 11)
## ขยายสนามทุกแบบ (กว้าง x1.35, ลึก +2 แถว) ให้มีที่เดินอ้อม/ตีหลัง/ใช้วิชาพื้นที่
const WIDEN_X = 1.35
const WIDEN_Y = 2

## ขนาดสนามของศึกนี้: บริบท (ลานประลอง/บุกสำนัก/ตรอกเมือง) > ประเภทจุดบนแผนที่ (เมือง/ถ้ำ/แดนลับ) > ภูมิภาค
## แต่ละจุดบนแผนที่ต่างกันเล็กน้อยอีกชั้น (คงที่ต่อจุด) และศึกคนเยอะสนามกว้างขึ้น
static func arena_size(ctx: Dictionary, unit_count: int) -> Vector2i:
	var ctype: String = ctx.get("type", "")
	var node_id: String = ctx.get("node", GlobalGame.field_node if ctype == "field" else "")
	var node: Dictionary = WorldDB.NODES.get(node_id, {})
	var size = ARENA_DEFAULT
	var vary = node_id != ""
	if ctx.has("arena_size"):
		size = ctx.arena_size
		vary = false
	elif ARENA_BY_CONTEXT.has(ctype):
		size = ARENA_BY_CONTEXT[ctype]
		vary = false
	elif node.get("type", -1) == WorldDB.NodeType.CITY: size = Vector2i(14, 5)
	elif node.get("type", -1) == WorldDB.NodeType.DUNGEON: size = Vector2i(9, 5)
	elif node.get("type", -1) == WorldDB.NodeType.SECRET_REALM: size = Vector2i(10, 6)
	elif node.get("type", -1) in [WorldDB.NodeType.RIVAL_SECT, WorldDB.NodeType.GREAT_SECT]: size = Vector2i(13, 8)
	else: size = ARENA_BY_REGION.get(node.get("region", ""), ARENA_DEFAULT)
	if vary:
		var h = absi(hash(node_id))
		size += Vector2i(h % 3 - 1, (h / 3) % 3 - 1)
	if unit_count > 8: size.x += 2
	size = Vector2i(roundi(size.x * WIDEN_X), size.y + WIDEN_Y)
	return size.clamp(ARENA_MIN, ARENA_MAX)

## รูปทรงสนาม (คงที่ต่อบริบท/จุดบนแผนที่ ไม่ใช้ตัวสุ่มของศึก)
static func arena_shape(ctx: Dictionary) -> String:
	if ctx.has("arena_shape"): return ctx.arena_shape
	var ctype: String = ctx.get("type", "")
	if CIRCLE_CONTEXTS.has(ctype): return "circle"
	if ARENA_BY_CONTEXT.has(ctype): return "rect"
	var node_id: String = ctx.get("node", GlobalGame.field_node if ctype == "field" else "")
	var node: Dictionary = WorldDB.NODES.get(node_id, {})
	var kind = { WorldDB.NodeType.SECRET_REALM: "secret", WorldDB.NodeType.WILD: "wild", WorldDB.NodeType.DUNGEON: "dungeon" }.get(node.get("type", -1), "")
	if kind == "": return "rect"
	return "circle" if (absi(hash(node_id + "#shape")) % 100) < CIRCLE_CHANCE[kind] * 100 else "rect"

static func apply_arena_size(ctx: Dictionary, unit_count: int) -> Vector2i:
	var shape = arena_shape(ctx)
	var s = arena_size(ctx, unit_count)
	if shape == "circle":
		var ctype: String = ctx.get("type", "")
		if CIRCLE_CONTEXTS.has(ctype): s = Vector2i(roundi(CIRCLE_CONTEXTS[ctype].x * WIDEN_X), CIRCLE_CONTEXTS[ctype].y + WIDEN_Y)
		# วงกลมเสียช่องตามมุม: ลึกอย่างน้อย 7 และไม่แบนเกิน
		s.y = clampi(maxi(s.y + 1, 7), ARENA_MIN.y, ARENA_MAX.y)
		s.x = clampi(mini(s.x, s.y * 2), ARENA_MIN.x, ARENA_MAX.x)
		if unit_count > 8: s.x = mini(s.x + 2, ARENA_MAX.x)
	BattleState.W = s.x
	BattleState.H = s.y
	BattleState.build_shape(shape)
	return s

## จัดสนาม: สิ่งกีดขวางตามบริบท (ซ้ำได้ตาม seed) ฝ่ายเรายืนคอลัมน์ซ้าย ศัตรูคอลัมน์ขวา
static func setup(allies: Array, enemies: Array, seed_v: int, ctx: Dictionary) -> BattleState:
	apply_arena_size(ctx, min(allies.size(), 6) + min(enemies.size(), 6))
	var st = BattleState.new()
	st.rng.seed = seed_v
	st.context = ctx
	var mult: float = BuildingDB.diff(GlobalGame.current_sect.difficulty).enemy if GlobalGame.current_sect != null else 1.0
	var id = 0
	for d in allies.slice(0, 6):
		st.units.append(make_ally(id, d))
		id += 1
	for e in enemies.slice(0, 6):
		st.units.append(make_enemy(id, e, mult))
		id += 1
	_place_obstacles(st, ctx)
	_place_team(st, 0, [0, 1])
	_place_team(st, 1, [BattleState.W - 1, BattleState.W - 2])
	for u in st.units: u.ct = st.rng.randf_range(0.0, 30.0)
	return st

static func _place_obstacles(st: BattleState, ctx: Dictionary) -> void:
	var kind = "tree"
	var n = st.rng.randi_range(2, 5)
	match ctx.get("type", ""):
		"raid", "siege", "spar", "arena": kind = "rock"; n = st.rng.randi_range(1, 3)
		"city_guard": kind = "rock"
	# สนามใหญ่ = สิ่งกีดขวาง/หญ้าสูงมากขึ้นตามพื้นที่ (เทียบสนามมาตรฐาน 12x6)
	var area_k = float(BattleState.W * BattleState.H) / 72.0
	n = roundi(n * area_k)
	for i in n:
		var c = Vector2i(st.rng.randi_range(3, BattleState.W - 4), st.rng.randi_range(0, BattleState.H - 1))
		if not st.in_grid(c): continue
		st.blocked[c] = kind if st.rng.randf() < 0.7 else ("rock" if kind == "tree" else "tree")
	for i in roundi(st.rng.randi_range(3, 7) * area_k):
		var c = Vector2i(st.rng.randi_range(1, BattleState.W - 2), st.rng.randi_range(0, BattleState.H - 1))
		if st.in_grid(c) and not st.blocked.has(c): st.grass[c] = true

## ยืนเรียงจากขอบฝั่งตัวเองเข้าหากลาง (คอลัมน์ที่ใกล้ขอบก่อน ในคอลัมน์เดียวกันเริ่มจากแถวกลาง)
## สนามวงกลมขอบโค้ง คอลัมน์ริมมีช่องน้อย จึงเลือกจากช่องที่อยู่ในวงจริง
static func _place_team(st: BattleState, team: int, _cols: Array) -> void:
	var list = st.units.filter(func(u): return u.team == team)
	var cy = (BattleState.H - 1) / 2.0
	var cells: Array[Vector2i] = []
	for x in BattleState.W:
		for y in BattleState.H:
			if st.in_grid(Vector2i(x, y)): cells.append(Vector2i(x, y))
	# สนามกว้าง: ทีมเริ่มขยับเข้ามาจากขอบ ให้ระยะห่างสองฝ่ายใกล้เคียงสนามมาตรฐาน (ยังถอยไปขอบซ้ายเพื่อหนีได้)
	var inset = clampi((BattleState.W - 12) / 2, 0, 4)
	var home = inset if team == 0 else BattleState.W - 1 - inset
	cells.sort_custom(func(a, b):
		var ka = absi(a.x - home) * 2 + (1 if (team == 0 and a.x > home) or (team == 1 and a.x < home) else 0)
		var kb = absi(b.x - home) * 2 + (1 if (team == 0 and b.x > home) or (team == 1 and b.x < home) else 0)
		if ka != kb: return ka < kb
		return absf(a.y - cy) < absf(b.y - cy))
	for i in mini(list.size(), cells.size()):
		st.blocked.erase(cells[i])
		st.grass.erase(cells[i])
		list[i].cell = cells[i]

# ══════════════════════════════════════════
# ท่า (โจมตีปกติ + วิชา)
# ══════════════════════════════════════════

## สเปกของท่า: "โจมตี" = ตีประชิดด้วยอาวุธ (ฟื้นปราณ) หรือชื่อวิชา
static func spec(u: Dictionary, action: String) -> Dictionary:
	if action == ATTACK:
		return { "range": 1, "shape": "single", "size": 0, "target": "enemy", "mult": 0.0, "effect": u.status_attack, "qi": 0, "cd": 0, "type": u.weapon_type, "power": 0, "tier": 0 }
	return SkillDB.battle_spec(action)

## ท่าทั้งหมดของยูนิต พร้อมเหตุผลถ้าใช้ไม่ได้ [{ name, spec, ok, why }]
static func actions(u: Dictionary) -> Array:
	var out: Array = [{ "name": ATTACK, "spec": spec(u, ATTACK), "ok": true, "why": "" }]
	for s in u.skills:
		var sp = spec(u, s)
		var why = ""
		if int(u.cd.get(s, 0)) > 0: why = "พักวิชา %d เทิร์น" % u.cd[s]
		elif u.qi < sp.qi: why = "ปราณไม่พอ (%d/%d)" % [u.qi, sp.qi]
		out.append({ "name": s, "spec": sp, "ok": why == "", "why": why })
	return out

## ตัวเลือกการเล็ง: single/circle = ช่องเป้า · line = ช่องติดตัวใน 4 ทิศ · self/self_ring = ช่องตัวเอง
static func aim_options(st: BattleState, u: Dictionary, sp: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if sp.target == "self" or sp.shape == "self_ring":
		out.append(u.cell)
		return out
	if sp.shape == "line":
		for d in BattleState.DIRS:
			if st.in_grid(u.cell + d): out.append(u.cell + d)
		return out
	var r: int = sp.range
	for x in range(u.cell.x - r, u.cell.x + r + 1):
		for y in range(u.cell.y - r, u.cell.y + r + 1):
			var c = Vector2i(x, y)
			if not st.in_grid(c) or BattleState.dist(c, u.cell) > r: continue
			if sp.target == "ally" or sp.shape == "circle" or c != u.cell:
				if r <= 1 or st.los(u.cell, c): out.append(c)
	return out

## ช่องที่โดนผลเมื่อเล็ง aim
static func affected(st: BattleState, u: Dictionary, sp: Dictionary, aim: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	match sp.shape:
		"line":
			var d = aim - u.cell
			for k in range(1, int(sp.size) + 1):
				var c = u.cell + d * k
				if not st.passable(c): break
				out.append(c)
		"circle":
			for x in range(aim.x - sp.size, aim.x + sp.size + 1):
				for y in range(aim.y - sp.size, aim.y + sp.size + 1):
					var c = Vector2i(x, y)
					if st.in_grid(c) and BattleState.dist(c, aim) <= sp.size: out.append(c)
		"self_ring":
			for x in range(u.cell.x - sp.size, u.cell.x + sp.size + 1):
				for y in range(u.cell.y - sp.size, u.cell.y + sp.size + 1):
					var c = Vector2i(x, y)
					if st.in_grid(c) and c != u.cell and BattleState.dist(c, u.cell) <= sp.size: out.append(c)
		_:
			out.append(aim)
	return out

## ยูนิตที่โดนจริง (ตามฝ่ายเป้าหมายของท่า)
static func targets(st: BattleState, u: Dictionary, sp: Dictionary, cells: Array[Vector2i]) -> Array:
	var out: Array = []
	if sp.target == "self": return [u]
	for c in cells:
		var t = st.unit_at(c)
		if t.is_empty(): continue
		if sp.target == "ally" and t.team == u.team: out.append(t)
		elif sp.target == "enemy" and t.team != u.team: out.append(t)
	return out

# ══════════════════════════════════════════
# ดาเมจ
# ══════════════════════════════════════════

## ตัวคูณตามตำแหน่ง: ตีหน้า 1.0 · ข้าง 1.25 · หลัง 1.5 (เทียบกับทิศที่เป้าหมายหันอยู่)
static func position_mult(a: Dictionary, d: Dictionary) -> float:
	var to_attacker = Vector2(a.cell - d.cell).normalized()
	var dot = to_attacker.dot(Vector2(d.facing))
	if dot > 0.5: return 1.0
	if dot < -0.5: return 1.5
	return 1.25

static func dodge_chance(st: BattleState, a: Dictionary, d: Dictionary) -> float:
	var ratio = (float(d.spd) - a.spd) / maxf(1.0, a.spd)
	var c = 0.05 + ratio * 0.2 + d.dodge_bonus + (0.1 if st.grass.has(d.cell) else 0.0)
	if d.status.has("seal"): c = 0.0
	return clampf(c, 0.0, 0.45)

## ดาเมจที่คาดหวัง (ไม่สุ่ม) ใช้ทั้งคำนวณจริงและให้ AI ประเมิน
static func base_damage(a: Dictionary, d: Dictionary, sp: Dictionary) -> float:
	var bonus = 0.0
	if sp.power > 0:
		var lv = MasterySys.skill_level(a.ref, sp.name) if a.ref is DiscipleData and sp.has("name") else int(a.level / 3)
		bonus = StatSys.skill_damage(a.atk, int(sp.power), lv) * float(sp.mult)
	var dmg = maxf(1.0, a.atk + bonus - d.def / 2.0)
	dmg *= position_mult(a, d)
	if d.defending: dmg *= 0.67
	if d.passives.has("guard"): dmg *= 0.85
	return dmg

static func expected_damage(st: BattleState, a: Dictionary, d: Dictionary, sp: Dictionary) -> float:
	return base_damage(a, d, sp) * (1.0 - dodge_chance(st, a, d))

# ══════════════════════════════════════════
# จังหวะเทิร์น
# ══════════════════════════════════════════

## ต้นเทิร์น: ลดคูลดาวน์ ฟื้นปราณ ล้างการตั้งรับ พิษกัดกิน สกัดจุด (skip = ข้ามเทิร์นนี้)
static func start_turn(st: BattleState, u: Dictionary) -> Dictionary:
	var ev: Array = []
	u.moved = false
	u.acted = false
	u.defending = false
	u.dodge_bonus = 0.0
	u.move_bonus = 0
	for s in u.cd.keys():
		u.cd[s] = int(u.cd[s]) - 1
		if u.cd[s] <= 0: u.cd.erase(s)
	u.qi = mini(u.max_qi, u.qi + QI_PER_TURN)
	if u.passives.has("regen") and u.hp < u.max_hp:
		var h = int(u.max_hp * 0.1)
		u.hp = mini(u.max_hp, u.hp + h)
		ev.append({ "t": "heal", "id": u.id, "amt": h })
	for s in ["poison", "gu"]:
		if u.status.has(s) and u.hp > 0:
			var dmg = maxi(1, int(u.max_hp * (0.06 if s == "poison" else 0.04)))
			u.hp = maxi(1 if s == "gu" else 0, u.hp - dmg)
			ev.append({ "t": "hit", "id": u.id, "dmg": dmg, "crit": false, "note": STATUS_NAMES[s] })
			if s == "poison":
				u.status.poison -= 1
				if u.status.poison <= 0: u.status.erase("poison")
	if u.hp <= 0:
		_down(st, u, ev)
		return { "events": ev, "skip": true }
	if u.status.has("seal"):
		u.status.seal -= 1
		if u.status.seal <= 0: u.status.erase("seal")
		ev.append({ "t": "skip", "id": u.id })
		ev.append({ "t": "log", "text": "[color=violet]%s ถูกสกัดจุด ขยับไม่ได้![/color]" % u.name })
		return { "events": ev, "skip": true }
	return { "events": ev, "skip": false }

static func do_move(st: BattleState, u: Dictionary, cell: Vector2i) -> Array:
	var reach = st.reachable(u)
	if cell == u.cell or not reach.has(cell): return []
	var path = BattleState.path_to(reach, u.cell, cell)
	if path.size() >= 1:
		var last_from = path[path.size() - 2] if path.size() >= 2 else u.cell
		u.facing = path[-1] - last_from
	u.cell = cell
	u.moved = true
	return [{ "t": "move", "id": u.id, "path": path }]

static func do_defend(st: BattleState, u: Dictionary) -> Array:
	u.defending = true
	u.acted = true
	u.moved = true
	u.qi = mini(u.max_qi, u.qi + QI_ON_DEFEND)
	return [{ "t": "log", "text": "%s ตั้งรับ (ลดความเสียหาย ฟื้นปราณ)" % u.name }, { "t": "status", "id": u.id, "st": "ตั้งรับ" }]

## หนี: ยืนอยู่ขอบซ้ายสุดของสนาม (ฝั่งเรา) เท่านั้น
static func can_escape(u: Dictionary) -> bool:
	return u.team == 0 and u.cell.x == 0

static func do_escape(st: BattleState, u: Dictionary) -> Array:
	if not can_escape(u): return []
	u.escaped = true
	u.acted = true
	u.moved = true
	st.check_end()
	return [{ "t": "escape", "id": u.id }, { "t": "log", "text": "[color=gray]%s หลบหนีออกจากสนาม[/color]" % u.name }]

## ใช้ท่า action เล็งที่ aim
static func do_action(st: BattleState, u: Dictionary, action: String, aim: Vector2i) -> Array:
	var ev: Array = []
	var sp = spec(u, action)
	if sp.is_empty(): return ev
	sp["name"] = action
	if not aim_options(st, u, sp).has(aim): return ev
	if action != ATTACK:
		if u.qi < sp.qi or int(u.cd.get(action, 0)) > 0: return ev
		u.qi -= sp.qi
		if sp.cd > 0: u.cd[action] = sp.cd
	else:
		u.qi = mini(u.max_qi, u.qi + QI_ON_ATTACK)
	u.acted = true
	if aim != u.cell:
		var d = aim - u.cell
		u.facing = Vector2i(signi(d.x), 0) if absi(d.x) >= absi(d.y) else Vector2i(0, signi(d.y))
		ev.append({ "t": "face", "id": u.id, "dir": u.facing })
	var cells = affected(st, u, sp, aim)
	var tgts = targets(st, u, sp, cells)
	ev.append({ "t": "act", "id": u.id, "name": action, "type": sp.type, "cells": cells, "aim": aim, "targets": tgts.map(func(t): return t.id) })
	if action != ATTACK:
		ev.append({ "t": "log", "text": "[color=cyan]%s ใช้วิชา [b]%s[/b][/color]" % [u.name, action] })
	_gain_mastery(u, MasterySys.skill_type(action) if action != ATTACK else u.weapon_type, MasterySys.GAIN_SKILL_USE if action != ATTACK else MasterySys.GAIN_BASIC_ATTACK, ev)
	match sp.effect:
		"heal":
			for t in tgts:
				var h = int(t.max_hp * minf(0.5, 0.1 + sp.power / 300.0))
				t.hp = mini(t.max_hp, t.hp + h)
				ev.append({ "t": "heal", "id": t.id, "amt": h })
			return ev
		"shield":
			var amt = int(u.max_hp * 0.12 + sp.power * 0.4)
			u.shield_hp += amt
			ev.append({ "t": "shield", "id": u.id, "amt": amt })
			return ev
		"swift":
			u.move_bonus = 2
			u.moved = false
			u.dodge_bonus = 0.2
			ev.append({ "t": "status", "id": u.id, "st": "ตัวเบา" })
			return ev
	for t in tgts: _hit(st, u, t, sp, ev)
	st.check_end()
	return ev

static func _hit(st: BattleState, a: Dictionary, d: Dictionary, sp: Dictionary, ev: Array) -> void:
	if st.rng.randf() < dodge_chance(st, a, d):
		ev.append({ "t": "miss", "id": d.id })
		ev.append({ "t": "log", "text": "%s หลบ%sได้" % [d.name, sp.get("name", "")] })
		return
	var dmg = base_damage(a, d, sp) * st.rng.randf_range(0.9, 1.1)
	var crit = false
	if a.passives.has("crit") and st.rng.randf() < 0.25:
		dmg *= 2.0
		crit = true
	var pm = position_mult(a, d)
	var note = "หลัง!" if pm >= 1.5 else ("ข้าง" if pm > 1.0 else "")
	var dealt = int(dmg)
	if d.shield_hp > 0:
		var absorb = mini(d.shield_hp, dealt)
		d.shield_hp -= absorb
		dealt -= absorb
		if absorb > 0: note += " โล่ -%d" % absorb
	d.hp = maxi(0, d.hp - dealt)
	ev.append({ "t": "hit", "id": d.id, "dmg": dealt, "crit": crit, "note": note.strip_edges() })
	ev.append({ "t": "log", "text": "[color=%s]%s[/color] → %s เสียหาย [b]%d[/b]%s" % ["#8f8" if a.team == 0 else "#f88", a.name, d.name, dealt, (" (%s)" % note.strip_edges()) if note.strip_edges() != "" else ""] })
	if a.passives.has("lifesteal") and dealt > 0:
		var h = int(dealt * 0.2)
		a.hp = mini(a.max_hp, a.hp + h)
		ev.append({ "t": "heal", "id": a.id, "amt": h })
	if d.hp > 0 and d.passives.has("last_stand") and not d.last_stand_used and d.hp < d.max_hp * 0.25:
		d.last_stand_used = true
		d.shield_hp += int(d.max_hp * 0.3)
		ev.append({ "t": "shield", "id": d.id, "amt": int(d.max_hp * 0.3) })
	if d.hp <= 0:
		_down(st, d, ev)
		return
	match sp.effect:
		"knockback": _knockback(st, a, d, ev)
		"seal":
			if st.rng.randf() < 0.7: _status(d, "seal", ev)
		"poison", "gu": _status(d, sp.effect, ev)
		"":
			pass
		_:
			# สถานะจากศัตรู (status_attack) ติด 30%
			if STATUS_NAMES.has(sp.effect) and st.rng.randf() < 0.3: _status(d, sp.effect, ev)

static func _knockback(st: BattleState, a: Dictionary, d: Dictionary, ev: Array) -> void:
	var dir = d.cell - a.cell
	dir = Vector2i(signi(dir.x), 0) if absi(dir.x) >= absi(dir.y) else Vector2i(0, signi(dir.y))
	var to = d.cell + dir
	if st.passable(to) and st.unit_at(to).is_empty():
		d.cell = to
		ev.append({ "t": "knock", "id": d.id, "to": to, "collide": false })
	else:
		# ชนสิ่งกีดขวาง/คน: เจ็บเพิ่ม
		var extra = maxi(1, int(a.atk * 0.3))
		d.hp = maxi(0, d.hp - extra)
		ev.append({ "t": "knock", "id": d.id, "to": d.cell, "collide": true })
		ev.append({ "t": "hit", "id": d.id, "dmg": extra, "crit": false, "note": "กระแทก" })
		if d.hp <= 0: _down(st, d, ev)

static func _status(u: Dictionary, s: String, ev: Array) -> void:
	match s:
		"seal": u.status["seal"] = 2
		"poison": u.status["poison"] = 3
		"gu": u.status["gu"] = true
	ev.append({ "t": "status", "id": u.id, "st": STATUS_NAMES[s] })
	ev.append({ "t": "log", "text": "[color=violet]%s ติดสถานะ %s[/color]" % [u.name, STATUS_NAMES[s]] })

static func _down(st: BattleState, u: Dictionary, ev: Array) -> void:
	if u.down: return
	u.down = true
	ev.append({ "t": "down", "id": u.id })
	ev.append({ "t": "log", "text": "[color=%s]%s ล้มลง![/color]" % ["#f88" if u.team == 0 else "#8f8", u.name] })
	st.check_end()

static func _gain_mastery(u: Dictionary, type: String, amount: int, ev: Array) -> void:
	if not (u.ref is DiscipleData) or type == "": return
	if MasterySys.gain(u.ref, type, amount):
		var lv = MasterySys.get_level(u.ref, type)
		ev.append({ "t": "log", "text": "[color=gold]%s ชำนาญ%sขึ้น! ระดับ %d (%s)[/color]" % [u.name, MasterySys.type_name(type), lv, MasterySys.RANK_NAMES[lv]] })
