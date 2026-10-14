extends RefCounted
class_name CombatResult

## ผลหลังจบศึก (ใช้ร่วมกันทุกฉากต่อสู้): รางวัล ของดรอป EXP ชื่อเสียง ผลตามบริบท (ยึดพื้นที่/บุกสำนัก/ประลอง ฯลฯ)
## และฝั่งแพ้: บาดเจ็บ หมดสติ · ตายได้เฉพาะ "ศึกชี้เป็นตาย" (DEADLY_CONTEXTS หรือ context.deadly = true)
## allies = Array ของ Dictionary ที่มี ref (DiscipleData), hp, status (Dictionary)

const DEADLY_CONTEXTS = ["siege", "raid"]

static func is_deadly(ctx: Dictionary) -> bool:
	return ctx.get("deadly", false) or ctx.get("type", "") in DEADLY_CONTEXTS

## คืนข้อความสรุปผล และล้างตัวแปรศึกใน GlobalGame
static func finish(is_win: bool, allies: Array) -> String:
	var sect = GlobalGame.current_sect
	var text = _win(sect, allies) if is_win else _lose(sect, allies)
	# พิษกู่ที่ติดตัวกลับไป ต้องให้หมอรักษา
	for a in allies:
		if a.status.has("gu") and a.ref.status != DiscipleData.DiscipleStatus.DEPARTED:
			a.ref.add_ailment("gu_poison")
			sect.log_event(sect.current_day, "[color=red]%s ติดพิษกู่กลับมา! ต้องให้หมอถอนพิษภายใน 20 วัน[/color]" % a.ref.disciple_name)
	GlobalGame.combat_bonus_money = 0
	GlobalGame.combat_bonus_task = ""
	GlobalGame.combat_context = {}
	return text

static func _win(sect: SectData, allies: Array) -> String:
	var t_money = GlobalGame.combat_bonus_money
	var t_food = 0
	var t_exp = 0
	var luck = 0
	for a in allies: luck = maxi(luck, a.ref.get_stat("luck"))
	var drops = {}
	for e in GlobalGame.combat_enemies:
		t_money += e.get("reward_money", 0)
		t_food += e.get("reward_food", 0)
		t_exp += e.get("reward_exp", 0)
		var d = EnemyDB.roll_drops(e, luck)
		for m in d: drops[m] = drops.get(m, 0) + d[m]
	sect.money += t_money
	sect.food += t_food
	var ctx_type: String = GlobalGame.combat_context.get("type", "")
	if ctx_type == "field":
		# ของดรอปตกที่พื้นในพื้นที่สำรวจ (เดินเก็บเอง) และมอนสเตอร์ตัวนี้หายไปจากพื้นที่
		var fs = GlobalGame.field_state
		for m in drops: fs.pending_loot[m] = fs.pending_loot.get(m, 0) + drops[m]
		fs.defeated.append(fs.get("fighting", ""))
	else:
		sect.add_materials(drops)
	var alive = allies.filter(func(a): return a.hp > 0)
	for a in alive:
		a.ref.gain_experience(int(t_exp / float(maxi(1, alive.size()))), sect.current_day)
	if GlobalGame.combat_bonus_task != "":
		sect.completed_world_tasks.append(GlobalGame.combat_bonus_task)
	var summary = "ชนะการต่อสู้ ได้รับเงิน %d เสบียง %d และ EXP %d" % [t_money, t_food, t_exp]
	if not drops.is_empty():
		summary += ("\nของดรอปตกอยู่ที่พื้น (เดินไปเก็บ): " if ctx_type == "field" else "\nของดรอป: ") + MaterialDB.format_list(drops)
	for a in alive: PawnSys.add_thought(a.ref, sect, "won_battle")
	for a in alive:
		var t = SkillQuestSys.try_insight(sect, a.ref, MasterySys.train_type(a.ref), GlobalGame.sect_manager, 3.0)
		if t != "": summary += "\n" + RegEx.create_from_string("\\[/?[a-z]+[^\\]]*\\]").sub(t, "", true)
	if ctx_type == "raid":
		StorytellerSystem.raid_won(sect, GlobalGame.combat_enemies, alive.map(func(a): return a.ref), GlobalGame.combat_context.raid, GlobalGame.sect_manager)
	var ctx_text = _context_win(sect, alive)
	if ctx_text != "": summary += "\n" + ctx_text
	# ศิษย์ที่ล้มในศึกที่ชนะ: บาดเจ็บเล็กน้อย
	for a in allies:
		if a.hp <= 0: _injure(sect, a.ref, false)
	sect.log_event(sect.current_day, summary)
	return summary

static func _lose(sect: SectData, allies: Array) -> String:
	var ctx = GlobalGame.combat_context
	var fid: String = ctx.get("faction", "")
	var death_chance: float = 0.0
	if is_deadly(ctx): death_chance = BuildingDB.diff(sect.difficulty).death + (0.15 if fid != "" else 0.0)
	if ctx.get("type", "") == "field":
		# แพ้ในพื้นที่สำรวจ: ทีมถอยกลับแผนที่โลก
		GlobalGame.combat_return_scene = "res://scene/map/world_map.tscn"
		GlobalGame.field_state = {}
	if ctx.get("type", "") == "city_guard":
		var fine = int(maxi(0, sect.money) * 0.15)
		sect.money -= fine
		sect.active_contract = {}
		sect.log_event(sect.current_day, "[color=red]ทหารหลวงจับตัวได้ ต้องจ่ายค่าไถ่ %d เงิน และสัญญาลอบสังหาร (ถ้ามี) ถูกยกเลิก[/color]" % fine)
		FactionSys.change_rel(sect, "player", "f_court", -5)
	var hurt: Array[String] = []
	var dead: Array[String] = []
	var log_fn = func(t): sect.log_event(sect.current_day, t)
	for a in allies:
		if a.hp > 0: continue
		if randf() < death_chance:
			var killer = FactionDB.FACTIONS[fid].name if fid != "" else "ศัตรู"
			FactionSys.on_disciple_killed(sect, a.ref, fid, "ถูก%sสังหารในการต่อสู้" % killer, log_fn)
			HealthSystem.on_death(sect, a.ref)
			dead.append(a.ref.disciple_name)
			continue
		_injure(sect, a.ref, true)
		hurt.append(a.ref.disciple_name)
	if ctx.get("type", "") == "raid":
		StorytellerSystem.raid_lost(sect, [], ctx.raid, GlobalGame.sect_manager)
	var text = "ศิษย์พ่ายแพ้และล่าถอย"
	if not hurt.is_empty(): text += " (หมดสติ/บาดเจ็บ: %s)" % ", ".join(hurt)
	if not dead.is_empty(): text += " (เสียชีวิต: %s)" % ", ".join(dead)
	sect.log_event(sect.current_day, text)
	return text

## ล้มในศึก: หนัก (แพ้) = บาดแผลหลายจุด + อาการภายใน · เบา (ชนะ) = พักฟื้นสั้นๆ
static func _injure(sect: SectData, d: DiscipleData, heavy: bool) -> void:
	if heavy:
		for n in randi_range(1, 2): PawnSys.injure(d, randf_range(5, 14), "บาดเจ็บจากการต่อสู้")
		PawnSys.add_thought(d, sect, "lost_battle")
		StressSystem.add(d, 25.0)
		d.injury_days = randi_range(2, 5)
		d.add_ailment("meridian_damage" if randf() < 0.4 else "internal_injury")
	else:
		PawnSys.injure(d, randf_range(3, 8), "บาดเจ็บจากการต่อสู้")
	if d.status != DiscipleData.DiscipleStatus.MISSION:
		d.status = DiscipleData.DiscipleStatus.INJURED

## ผลพิเศษเมื่อชนะ ตามบริบทของการต่อสู้ (ยึดพื้นที่ / บุกตีสำนัก / ประลอง / ปราบปราม)
static func _context_win(sect: SectData, alive: Array) -> String:
	var ctx = GlobalGame.combat_context
	var fid: String = ctx.get("faction", "")
	var node_id: String = ctx.get("node", "")
	var fame = 5 + (10 if fid != "" else 0)
	for a in alive: a.ref.add_fame(fame)
	var text = ""
	match ctx.get("type", "hunt"):
		"claim":
			sect.node_owner[node_id] = "player"
			if fid != "": sect.factions[fid].relation -= 15
			text = "ยึดครอง%s สำเร็จ! (รายได้ +%d/วัน)" % [WorldDB.NODES[node_id].name, FactionSys.NODE_INCOME]
			if sect.count_owned_nodes() - 1 >= 5: ArchiveSys.unlock_achievement("conqueror")
			for extra in LandmarkSys.on_claim(sect, node_id): text += "\n" + extra
		"siege":
			text = FactionSys.on_siege_won(sect, fid)
			for a in alive: a.ref.add_fame(30)
		"arena":
			var fame_gain: int = ctx.get("fame", 20)
			for a in alive: a.ref.add_fame(fame_gain)
			sect.prestige += fame_gain / 2
			text = "ชนะการประลองยุทธ์หลวง! ชื่อเสียง +%d" % fame_gain
		"city_guard":
			FactionSys.change_rel(sect, "player", "f_court", -5)
			FactionSys.change_rel(sect, "player", "f_hawk", -10)
			text = "ฝ่าวงล้อมทหารยามหนีออกมาได้ แต่ราชสำนักเริ่มเพ่งเล็งสำนักเรา"
		"contract":
			var k = sect.active_contract
			if not k.is_empty():
				sect.active_contract = {}
				sect.money += k.reward
				sect.completed_world_tasks.append(k.key)
				sect.factions[k.faction].power = int(sect.factions[k.faction].power * 0.97)
				for ch in sect.champions.duplicate():
					if ch.name == k.target: sect.champions.erase(ch)
				text = "%s แห่ง%s ถูกสังหารกลางดึกที่%s (ค่าจ้าง %d)" % [k.target, FactionDB.FACTIONS[k.faction].name, WorldDB.NODES.get(node_id, {}).get("name", ""), k.reward]
		"roster_spar":
			text = RosterSys.on_spar_win(sect, ctx.get("roster_id", ""))
		"recruit_duel":
			if sect.get_active_disciples().size() < sect.get_max_disciples():
				var npc = NPCGenerator.generate_npc(1, maxi(1, int(ctx.get("recruit_level", 5)) - 2))
				npc.ambition = "ค้นหาความหมายของวิถียุทธ์"
				sect.disciples.append(npc)
				for s in npc.innate_skills: sect.add_library_skill(s)
				text = "จอมยุทธ์พเนจร %s ยอมรับความพ่ายแพ้และขอเข้าร่วมสำนัก (%s พลังรบ %d)" % [npc.disciple_name, npc.realm_name, npc.get_power_rating()]
			else:
				for a in alive: a.ref.add_fame(20)
				text = "ชนะจอมยุทธ์พเนจร แต่สำนักเต็มแล้ว ได้แค่ชื่อเสียง"
		"spar":
			sect.factions[fid].relation = mini(100, sect.factions[fid].relation + 5)
			sect.prestige += 10
			text = "ชนะการประลองกับ%s ชื่อเสียงสำนักเพิ่มขึ้น" % FactionDB.FACTIONS[fid].name
		_:
			# ดันเจี้ยน/ศัตรูระดับสูง มีโอกาสได้คัมภีร์สมบูรณ์
			var max_level = 0
			for e in GlobalGame.combat_enemies: max_level = maxi(max_level, e.get("level", 1))
			if max_level >= 6 and randf() < 0.15:
				var tier = SkillDB.Tier.HEAVEN if max_level >= 12 else SkillDB.Tier.EARTH
				var skill = SkillDB.get_random_skill_by_tier(tier)
				if sect.add_library_skill(skill):
					text = "พบคัมภีร์วิชา %s (ขั้น%s) ในซากศัตรู!" % [skill, SkillDB.TIER_NAMES[tier]]
	if text != "": sect.log_event(sect.current_day, "[color=gold]%s[/color]" % text)
	return text
