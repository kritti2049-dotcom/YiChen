extends RefCounted
class_name PrisonerSys

## นักโทษ: จับได้หลังชนะผู้บุกรุก -> ชักชวนเข้าสำนัก (ผู้คุม) / ปล่อยตัว / ประหาร

static func capture(sect: SectData, enemy: Dictionary, mgr: SectManager) -> void:
	var prisoner = {
		"name": NPCGenerator.SURNAMES.pick_random() + NPCGenerator.FIRST_NAMES.pick_random(),
		"enemy": enemy.get("id", "bandit_thug"), "faction": enemy.get("faction", ""), "title": enemy.get("name", "ผู้บุกรุก"),
		"recruit": 0.0,
	}
	sect.prisoners.append(prisoner)
	mgr.log_event("[color=#d0c080]จับ %s (%s) เป็นนักโทษ ขังไว้ที่ห้องขัง[/color]" % [prisoner.name, prisoner.title])

static func recruit_attempt(sect: SectData, warden: DiscipleData, index: int, mgr: SectManager) -> void:
	if index < 0 or index >= sect.prisoners.size(): return
	var p = sect.prisoners[index]
	p.recruit += 4.0 + PawnSys.skill_lv(warden, "social") * 1.2 + warden.get_stat("charisma") * 1.5
	PawnSys.learn(warden, "social", 10)
	if p.recruit < 100: return
	sect.prisoners.remove_at(index)
	var npc = NPCGenerator.generate_npc(0, randi_range(2, 6))
	npc.disciple_name = p.name
	PawnSys.ensure(npc, sect)
	npc.loyalty = 50
	npc.pos = Territory.gate_pos()
	sect.disciples.append(npc)
	mgr.log_event("[color=lime]%s ใช้วาทศิลป์ชักชวน %s (อดีต%s) เข้าร่วมสำนักสำเร็จ![/color]" % [warden.disciple_name, p.name, p.title], [warden])

static func release(sect: SectData, index: int, mgr: SectManager) -> String:
	var p = sect.prisoners[index]
	sect.prisoners.remove_at(index)
	if p.faction != "" and sect.factions.has(p.faction): FactionSys.change_rel(sect, "player", p.faction, 8)
	var text = "ปล่อยตัว %s กลับไป%s" % [p.name, (" (" + FactionSys.fname(p.faction) + " พอใจ)") if p.faction != "" else ""]
	mgr.log_event(text)
	return text

static func execute(sect: SectData, index: int, mgr: SectManager) -> String:
	var p = sect.prisoners[index]
	sect.prisoners.remove_at(index)
	ReputationSys.add_alignment(sect, -6)
	var text = "ประหาร %s ต่อหน้าศิษย์ทั้งสำนัก" % p.name
	mgr.log_event("[color=#c08080]%s[/color]" % text)
	return text
