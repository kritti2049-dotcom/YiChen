extends RefCounted
class_name SocialSystem

## SocialSystem (ตรวจเป็นช่วงๆ ไม่ใช่ทุกเฟรม)
## - ศิษย์ที่อยู่ใกล้กันสนทนา: ค่าความเห็น (Opinion) ขึ้นลงตามนิสัย (ใจดี/ปากร้าย/หยิ่งยโส) และวิถีที่ต่างกัน
## - ต่างวิถี = โต้วาทะ ผู้แพ้ลดความมั่นใจ ถึงศูนย์ = เปลี่ยนความเชื่อ
## - ด้านบวก: คนรัก -> งานมงคลสมรส (บัฟอารมณ์ทั้งสำนัก) -> มีลูก (สืบทอดกายาจากพ่อแม่)
## - ด้านลบ: ความเกลียดชังสะสมจนวิวาท (คนใจร้อนที่มีแขนกลมารอาจฆ่าคู่กรณี)

const INTERVAL = 30
const CHAT_RANGE = 1.6
const CHILD_GROW_DAYS = 60

static func run(sect: SectData, mgr: SectManager) -> void:
	var pawns = PawnSys.present(sect).filter(func(d): return not d.needs.is_empty())
	for i in pawns.size():
		var a: DiscipleData = pawns[i]
		if randf() > 0.3 * BehaviorTraitDB.mult(a.btraits, "social"): continue
		for j in range(i + 1, pawns.size()):
			var b: DiscipleData = pawns[j]
			# พบกันได้เมื่ออยู่ตึกเดียวกัน/ว่างทั้งคู่ (นานๆ ครั้งข้ามกลุ่มได้)
			if a.post != b.post and randf() > 0.12: continue
			_interact(sect, a, b, mgr)
			break

static func _interact(sect: SectData, a: DiscipleData, b: DiscipleData, mgr: SectManager) -> void:
	a.needs.joy = min(1.0, a.needs.joy + 0.04)
	b.needs.joy = min(1.0, b.needs.joy + 0.04)
	# ด่าทอ (ปากร้าย / หยิ่งยโส / รักความรุนแรง)
	for pair in [[a, b], [b, a]]:
		if randf() < BehaviorTraitDB.sum(pair[0].btraits, "insult"):
			PawnSys.change_opinion(pair[1], pair[0], -8)
			PawnSys.add_thought(pair[1], sect, "insulted", null, pair[0].disciple_name)
			if randf() < 0.3: mgr.log_event("%s พูดจาทิ่มแทง %s" % [pair[0].disciple_name, pair[1].disciple_name], [pair[0], pair[1]])
			_maybe_fight(sect, pair[1], pair[0], mgr)
			return
	var kind = BehaviorTraitDB.has_flag(a.btraits, "kind") or BehaviorTraitDB.has_flag(b.btraits, "kind")
	var delta = randf_range(-2.0, 5.0) + (3.0 if kind else 0.0)
	PawnSys.change_opinion(a, b, delta)
	PawnSys.change_opinion(b, a, delta)
	if delta > 3.5:
		PawnSys.add_thought(a, sect, "good_chat", null, b.disciple_name)
		PawnSys.add_thought(b, sect, "good_chat", null, a.disciple_name)
	_maybe_romance(sect, a, b, mgr)
	_maybe_fight(sect, a, b, mgr)
	_maybe_fight(sect, b, a, mgr)

static func _maybe_romance(sect: SectData, a: DiscipleData, b: DiscipleData, mgr: SectManager) -> void:
	if a.is_child or b.is_child or a.lover != "" or b.lover != "" or a.spouse != "" or b.spouse != "": return
	if PawnSys.opinion(a, b) < 55 or PawnSys.opinion(b, a) < 55 or randf() > 0.06: return
	a.lover = b.disciple_name
	b.lover = a.disciple_name
	a.relationships[b.disciple_name].type = "คู่รัก"
	b.relationships[a.disciple_name].type = "คู่รัก"
	PawnSys.add_thought(a, sect, "new_lover", null, b.disciple_name)
	PawnSys.add_thought(b, sect, "new_lover", null, a.disciple_name)
	mgr.log_event("[color=pink]%s และ %s ตกลงคบหากันเป็นคู่รัก[/color]" % [a.disciple_name, b.disciple_name], [a, b])

## ความเกลียดชังสะสม -> วิวาท
static func _maybe_fight(sect: SectData, a: DiscipleData, b: DiscipleData, mgr: SectManager) -> void:
	if PawnSys.opinion(a, b) > -40 or a.is_child or b.is_child: return
	var chance = 0.04 + (0.08 if BehaviorTraitDB.has_flag(a.btraits, "violent") else 0.0) + (0.04 if a.btraits.has("abrasive") else 0.0)
	if randf() > chance: return
	sect.sim_stats["fights"] = sect.sim_stats.get("fights", 0) + 1
	var p1 = PawnSys.injure(b, randf_range(2, 7), "วิวาทกับ " + a.disciple_name)
	PawnSys.injure(a, randf_range(1, 5), "วิวาทกับ " + b.disciple_name)
	mgr.log_event("[color=orange]%s และ %s ทะเลาะวิวาทจนลงไม้ลงมือ (%s บาดเจ็บ: %s)[/color]" % [a.disciple_name, b.disciple_name, b.disciple_name, p1], [a, b])
	PawnSys.add_thought(b, sect, "beaten", null, a.disciple_name)
	PawnSys.change_opinion(b, a, -10)
	HealthSystem.check_death(sect, b, mgr)

## รายวัน: งานมงคลสมรส การให้กำเนิด และเด็กเติบโต
static func daily(sect: SectData, mgr: SectManager) -> void:
	var pawns = PawnSys.present(sect)
	for a in pawns:
		if a.lover != "" and a.spouse == "":
			var b = PawnSys.find(sect, a.lover)
			if b == null:
				a.lover = ""
				continue
			if a.disciple_name < b.disciple_name and PawnSys.opinion(a, b) >= 75 and PawnSys.opinion(b, a) >= 75 and randf() < 0.06:
				_wedding(sect, a, b, mgr)
		if a.spouse != "" and a.disciple_name < a.spouse:
			var s = PawnSys.find(sect, a.spouse)
			if s != null and randf() < 0.012 and sect.get_active_disciples().size() < sect.get_max_disciples() and sect.food > 50:
				_birth(sect, a, s, mgr)
		if a.is_child and sect.current_day >= a.grow_day:
			a.is_child = false
			a.age = 14
			a.level = max(a.level, 1)
			a.realm_name = CultivationSys.get_realm_info(a.level).name
			mgr.log_event("[color=lime]%s เติบโตเป็นศิษย์เต็มตัวแล้ว (ฝึกด้วยโอสถเร่งโต)[/color]" % a.disciple_name, [a])

static func _wedding(sect: SectData, a: DiscipleData, b: DiscipleData, mgr: SectManager) -> void:
	a.spouse = b.disciple_name
	b.spouse = a.disciple_name
	a.relationships[b.disciple_name].type = "คู่ครอง"
	b.relationships[a.disciple_name].type = "คู่ครอง"
	PawnSys.add_thought(a, sect, "married", null, b.disciple_name)
	PawnSys.add_thought(b, sect, "married", null, a.disciple_name)
	for o in PawnSys.present(sect):
		if o != a and o != b:
			PawnSys.add_thought(o, sect, "wedding_guest")
			o.needs.joy = min(1.0, o.needs.joy + 0.3)
	mgr.log_event("[color=gold]งานมงคลสมรสของ %s และ %s! ทั้งสำนักร่วมเฉลิมฉลอง[/color]" % [a.disciple_name, b.disciple_name], [a, b])

static func _birth(sect: SectData, a: DiscipleData, b: DiscipleData, mgr: SectManager) -> void:
	var c = NPCGenerator.generate_npc(0, 0)
	c.disciple_name = a.disciple_name.substr(0, min(3, a.disciple_name.length())) + NPCGenerator.FIRST_NAMES.pick_random()
	c.level = 0
	c.realm_name = CultivationSys.get_realm_info(0).name
	c.age = 0
	c.is_child = true
	c.grow_day = sect.current_day + CHILD_GROW_DAYS
	c.innate_skills.clear()
	c.learned_skills.clear()
	PawnSys.ensure(c, sect)
	c.pos = a.pos
	c.relationships[a.disciple_name] = { "affinity": 60.0, "type": "พ่อแม่" }
	c.relationships[b.disciple_name] = { "affinity": 60.0, "type": "พ่อแม่" }
	sect.disciples.append(c)
	sect.sim_stats["births"] = sect.sim_stats.get("births", 0) + 1
	PawnSys.add_thought(a, sect, "raw_birth")
	PawnSys.add_thought(b, sect, "raw_birth")
	mgr.log_event("[color=pink]%s และ %s ให้กำเนิดบุตร %s[/color]" % [a.disciple_name, b.disciple_name, c.disciple_name], [a, b])
