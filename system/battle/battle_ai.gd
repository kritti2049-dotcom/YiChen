extends RefCounted
class_name BattleAI

## AI การต่อสู้บนกริด (Utility AI): ลองทุก (ช่องที่เดินไปได้ x ท่า x จุดเล็ง) ให้คะแนนแล้วเลือกสูงสุด
## ใช้ทั้งศัตรูและโหมด "ให้ AI คุม" ของฝ่ายเรา · smart 0..1 = ความฉลาด (ต่ำ = สุ่มจากตัวเลือกดีๆ ไม่ใช่ดีที่สุดเสมอ)
## คืน { cell: Vector2i, action: String ("" = ไม่ใช้ท่า), aim: Vector2i, defend: bool }

const KILL_BONUS = 40.0
const RISK_WEIGHT = 0.35

static func decide(st: BattleState, u: Dictionary, smart := 1.0) -> Dictionary:
	var reach = st.reachable(u)
	var home: Vector2i = u.cell
	var foes = st.foes_of(u)
	var options: Array = []
	var acts = BattleRules.actions(u).filter(func(a): return a.ok)
	# ถอยหนีเมื่อบาดเจ็บหนัก เฉพาะช่วงต้นศึกและยังมีเพื่อนสู้อยู่ (กันวิ่งไล่กันไม่จบ)
	var retreat = u.hp < u.max_hp * 0.3 and st.round_no < 8 and st.team_units(u.team).size() > 1
	for cell in reach:
		u.cell = cell
		var risk = _risk(st, u, cell, foes)
		var hurt = 1.5 if u.hp < u.max_hp * 0.3 else 1.0
		for a in acts:
			var sp: Dictionary = a.spec.duplicate()
			sp["name"] = a.name
			for aim in BattleRules.aim_options(st, u, sp):
				var score = _score_action(st, u, sp, aim)
				if score <= 0.0: continue
				options.append({ "cell": cell, "action": a.name, "aim": aim, "score": score - risk * RISK_WEIGHT * hurt })
		# ไม่ใช้ท่า: เดินเข้าหาศัตรู (หรือถอยถ้าบาดเจ็บหนัก) แล้วตั้งรับ
		var near = 99
		for f in foes: near = mini(near, BattleState.dist(cell, f.cell))
		# เดินเข้าหาศัตรูให้คะแนนมากกว่าความเสี่ยง (กันยืนเชิงกันจนศึกค้าง) ยิ่งศึกยืดเยื้อยิ่งบุก
		var aggro = 6.0 + st.round_no * 0.5
		var approach = near * 2.0 if retreat else -near * aggro
		options.append({ "cell": cell, "action": "", "aim": cell, "score": approach - risk * RISK_WEIGHT * 0.4 * hurt - 6.0, "defend": true })
	u.cell = home
	if options.is_empty(): return { "cell": home, "action": "", "aim": home, "defend": true }
	options.sort_custom(func(a, b): return a.score > b.score)
	var pick = 0
	if smart < 1.0:
		var top = mini(options.size(), 1 + int((1.0 - smart) * 4.0))
		pick = st.rng.randi_range(0, top - 1)
	return options[pick]

static func _score_action(st: BattleState, u: Dictionary, sp: Dictionary, aim: Vector2i) -> float:
	var cells = BattleRules.affected(st, u, sp, aim)
	var tgts = BattleRules.targets(st, u, sp, cells)
	if tgts.is_empty(): return 0.0
	var score = 0.0
	match sp.effect:
		"heal":
			for t in tgts:
				var missing = t.max_hp - t.hp
				if missing < t.max_hp * 0.35: continue
				score += minf(missing, t.max_hp * minf(0.5, 0.1 + sp.power / 300.0)) * 1.2
			return score
		"shield":
			return 15.0 if u.hp < u.max_hp * 0.6 and not st.foes_of(u).is_empty() else 0.0
		"swift":
			return 0.0
	for t in tgts:
		var dmg = BattleRules.expected_damage(st, u, t, sp)
		score += minf(dmg, t.hp)
		if dmg >= t.hp: score += KILL_BONUS
		if sp.effect in ["seal", "poison", "gu"] and not t.status.has(sp.effect): score += 6.0
	# ประหยัดปราณ: วิชาแรงต้องคุ้มค่า
	score -= sp.get("qi", 0) * 0.15
	return score

## ความเสี่ยงของการยืนที่ cell: ศัตรูที่เดิน+ตีถึงได้ในเทิร์นหน้า
static func _risk(st: BattleState, u: Dictionary, cell: Vector2i, foes: Array) -> float:
	var r = 0.0
	for f in foes:
		if BattleState.dist(f.cell, cell) <= f.move + 1:
			r += maxf(1.0, f.atk - u.def / 2.0)
	return r
