extends Node

## จำลองศึกบนกริดแบบไม่มีภาพ (AI ทั้งสองฝ่าย) เพื่อตรวจกติกาและปรับสมดุล
##   godot --headless --path . res://tools/battle_sim.tscn -- --n=500 --seed=1 --size=3 --power=1.0
## --n = จำนวนศึก · --size = คนต่อฝั่ง · --power = ตัวคูณพลังศัตรูเทียบฝ่ายเรา · --smart = ความฉลาด AI ฝ่ายเรา (0..1)
## --enemy-smart = ความฉลาด AI ศัตรู · --verbose = พิมพ์บันทึกศึกแรก

var opts := { "n": 300, "seed": 1, "size": 3, "power": 1.0, "smart": 1.0, "enemy_smart": 1.0, "verbose": false }

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--verbose":
			opts.verbose = true
			continue
		var kv = a.trim_prefix("--").replace("-", "_").split("=")
		if kv.size() == 2 and opts.has(kv[0]): opts[kv[0]] = float(kv[1]) if kv[0] in ["power", "smart", "enemy_smart"] else int(kv[1])
	GlobalGame.current_slot = 99
	seed(opts.seed)
	var wins = [0, 0, 0]
	var rounds_total = 0
	var turns_total = 0
	var think_ms = 0.0
	var think_n = 0
	var stuck = 0
	var t0 = Time.get_ticks_msec()
	for i in opts.n:
		var allies: Array = []
		for k in opts.size:
			var d = NPCGenerator.generate_npc(1, randi_range(4, 10))
			allies.append(d)
		var enemies: Array = []
		for k in opts.size:
			var ally: DiscipleData = allies[k]
			var e = StatSys.build_fighter(ally.get_power_rating() * opts.power, 4.0)
			e.merge({ "name": "ศัตรู%d" % k, "level": ally.level, "status_attack": ["", "", "poison", "seal"][randi() % 4] }, true)
			enemies.append(e)
		var st = BattleRules.setup(allies, enemies, opts.seed * 10000 + i, { "type": "hunt" })
		# ทีมกระจก: ศัตรูเป็นศิษย์สุ่มแบบเดียวกัน (สเตตัสคูณ power) เพื่อเทียบสมดุลอย่างแฟร์
		for u in st.units:
			if u.team != 1: continue
			var d2 = NPCGenerator.generate_npc(1, randi_range(4, 10))
			var mirror = BattleRules.make_ally(u.id, d2)
			mirror.team = 1
			mirror.facing = u.facing
			mirror.cell = u.cell
			mirror.ct = u.ct
			for k in ["hp", "max_hp", "atk", "def"]: mirror[k] = int(mirror[k] * opts.power)
			u.merge(mirror, true)
		var turns = 0
		while not st.over and turns < 400:
			var u = st.next_actor()
			if u.is_empty(): break
			turns += 1
			var s = BattleRules.start_turn(st, u)
			_print_events(i, s.events)
			if s.skip or st.over: continue
			var tt = Time.get_ticks_usec()
			var plan = BattleAI.decide(st, u, opts.smart if u.team == 0 else opts.enemy_smart)
			think_ms += (Time.get_ticks_usec() - tt) / 1000.0
			think_n += 1
			_print_events(i, BattleRules.do_move(st, u, plan.cell))
			if plan.action != "": _print_events(i, BattleRules.do_action(st, u, plan.action, plan.aim))
			elif plan.get("defend", false): _print_events(i, BattleRules.do_defend(st, u))
		if not st.over:
			stuck += 1
			if stuck <= 2:
				print("ค้าง: ", st.units.filter(st.on_field).map(func(x): return "%s t%d hp%d/%d qi%d cell%s skills%s" % [x.name, x.team, x.hp, x.max_hp, x.qi, x.cell, x.skills]))
		else: wins[st.result] += 1
		var n_units = st.units.size()
		rounds_total += int(turns / float(n_units))
		turns_total += turns
	var ms = Time.get_ticks_msec() - t0
	print("== จำลองศึก %d ครั้ง · %d vs %d · พลังศัตรู x%.2f ==" % [opts.n, opts.size, opts.size, opts.power])
	print("ฝ่ายเราชนะ %.1f%% · ศัตรูชนะ %.1f%% · หนี %.1f%% · ค้าง (เกิน 400 เทิร์น) %d" % [100.0 * wins[0] / opts.n, 100.0 * wins[1] / opts.n, 100.0 * wins[2] / opts.n, stuck])
	print("เฉลี่ย %.1f รอบต่อศึก (%.1f เทิร์น) · AI คิด %.2f ms/เทิร์น · รวม %d ms" % [float(rounds_total) / opts.n, float(turns_total) / opts.n, think_ms / maxi(1, think_n), ms])
	get_tree().quit()

func _print_events(i: int, ev: Array) -> void:
	if not opts.verbose or i > 0: return
	for e in ev:
		if e.t == "log": print("   ", e.text)
