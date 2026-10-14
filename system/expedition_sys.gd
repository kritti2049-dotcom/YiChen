extends Node
class_name ExpeditionSys

## ระบบส่งศิษย์ออกเดินทางบนแผนที่โลก (เดินทางทีละวันตามเส้นทาง)
## ใช้ข้อมูล mission_* ใน DiscipleData และเส้นทางบนบกจาก WorldGen (ตาม seed ของสำนัก)

## จำนวนวันที่ศิษย์อยู่เก็บวัตถุดิบ ณ จุดหมาย
const GATHER_WORK_DAYS = 3

## ส่งศิษย์ออกเดินทาง คืนค่าจำนวนวันเดินทาง
static func dispatch(sect: SectData, d: DiscipleData, mission_type: String, target_id: String) -> int:
	var route = get_route(sect, target_id)
	d.status = DiscipleData.DiscipleStatus.MISSION
	d.mission_type = mission_type
	d.mission_target = target_id
	d.mission_phase = "going"
	d.mission_total_days = max(1, route.days)
	d.mission_days_left = d.mission_total_days
	d.carried_materials = {}
	d.carried_equipment.clear()
	d.carried_skills.clear()
	return d.mission_total_days

## เรียกศิษย์ที่ประจำอยู่ต่างแดนกลับสำนัก
static func recall(sect: SectData, d: DiscipleData) -> void:
	if d.status == DiscipleData.DiscipleStatus.MISSION and d.mission_phase == "stationed":
		_start_return(sect, d)

## เส้นทางจากสำนักไปยังสถานที่ { "points", "days" }
static func get_route(sect: SectData, target_id: String) -> Dictionary:
	return WorldGen.for_sect(sect).get_route("sect", target_id)

## ศิษย์ที่ประจำอยู่ที่โหนดนี้ (ใช้เช็คว่าเข้าเมืองได้ไหม)
static func get_stationed_at(sect: SectData, node_id: String) -> Array[DiscipleData]:
	var result: Array[DiscipleData] = []
	for d in sect.disciples:
		if d.status == DiscipleData.DiscipleStatus.MISSION and d.mission_target == node_id and d.mission_phase in ["stationed", "working"]:
			result.append(d)
	return result

## ตำแหน่งบนแผนที่ (พิกัดช่อง) ของศิษย์ที่กำลังทำภารกิจ
## day_fraction (0-1) = เวลาที่ผ่านไปของวันปัจจุบัน ใช้ให้ตัวละครเดินต่อเนื่องแบบเรียลไทม์
static func get_map_position(sect: SectData, d: DiscipleData, day_fraction: float = 0.0) -> Vector2:
	var points: PackedVector2Array = get_route(sect, d.mission_target).points
	var total = float(max(1, d.mission_total_days))
	var progress = 1.0
	if d.mission_phase == "going":
		progress = (total - d.mission_days_left + day_fraction) / total
	elif d.mission_phase == "returning":
		progress = (d.mission_days_left - day_fraction) / total
	return WorldGen.point_on_route(points, progress)

## ศิษย์กำลังเคลื่อนที่อยู่หรือไม่ (ไว้ทำแอนิเมชันเดิน)
static func is_moving(d: DiscipleData) -> bool:
	return d.status == DiscipleData.DiscipleStatus.MISSION and d.mission_phase in ["going", "returning"]

## ประมวลผลการเดินทาง 1 วันของทุกคน คืนค่ารายการข้อความ log
static func process_day(sect: SectData, day: int) -> Array[String]:
	var logs: Array[String] = []
	var realm_team: Array[DiscipleData] = []
	for d in sect.disciples:
		if d.status != DiscipleData.DiscipleStatus.MISSION: continue
		if d.mission_phase == "working" and d.mission_type == "gather":
			# พื้นที่ที่ยึดครองไว้ เก็บของได้มากขึ้น
			if sect.node_owner.get(d.mission_target, "") == "player": _gather_one_day(sect, d)
		var target_name = WorldDB.get_node_data(d.mission_target).get("name", "?")
		match d.mission_phase:
			"going":
				d.mission_days_left -= 1
				if d.mission_days_left <= 0:
					match d.mission_type:
						"gather":
							d.mission_phase = "working"
							d.mission_days_left = GATHER_WORK_DAYS
							logs.append("%s เดินทางถึง%s และเริ่มเก็บวัตถุดิบ" % [d.disciple_name, target_name])
							_check_ambush(sect, d, logs)
						"revenge":
							if FactionSys.resolve_revenge(sect, d, func(t): logs.append(t)):
								_start_return(sect, d)
						"station":
							d.mission_phase = "stationed"
							logs.append("%s เดินทางถึง%s พร้อมรับคำสั่ง (เข้าเมืองได้แล้ว)" % [d.disciple_name, target_name])
						"secret_realm":
							realm_team.append(d)
						"meditate":
							d.mission_phase = "working"
							d.mission_days_left = SkillQuestSys.MEDITATE_DAYS
							logs.append("%s เดินทางถึง%s เริ่มนั่งสมาธิพินิจร่องรอยวิชา (%d วัน)" % [d.disciple_name, target_name, SkillQuestSys.MEDITATE_DAYS])
						"apprentice":
							d.mission_phase = "working"
							d.mission_days_left = SkillQuestSys.APPRENTICE_DAYS
							logs.append("%s เดินทางถึง%s ฝากตัวเป็นศิษย์เรียนวิชา (%d วัน)" % [d.disciple_name, target_name, SkillQuestSys.APPRENTICE_DAYS])
			"working":
				match d.mission_type:
					"meditate": SkillQuestSys.meditate_day(sect, d, logs)
					"apprentice": SkillQuestSys.apprentice_day(sect, d)
					_: _gather_one_day(sect, d)
				d.mission_days_left -= 1
				if d.mission_days_left <= 0:
					_start_return(sect, d)
					match d.mission_type:
						"meditate": logs.append(SkillQuestSys.meditate_finish(sect, d))
						"apprentice": logs.append(SkillQuestSys.apprentice_finish(sect, d))
						_: logs.append("%s เก็บวัตถุดิบที่%sเสร็จแล้ว กำลังเดินทางกลับ" % [d.disciple_name, target_name])
			"returning":
				d.mission_days_left -= 1
				if d.mission_days_left <= 0:
					logs.append(_arrive_home(sect, d))
	if not realm_team.is_empty():
		logs.append_array(resolve_secret_realm(sect, realm_team, day))
	return logs

## เก็บของในพื้นที่ของสำนักที่เป็นศัตรู มีโอกาสถูกซุ่มโจมตี
static func _check_ambush(sect: SectData, d: DiscipleData, logs: Array[String]) -> void:
	var owner: String = sect.node_owner.get(d.mission_target, "")
	if not FactionSys.is_hostile(sect, owner) or randf() > 0.35: return
	var fname = FactionDB.FACTIONS[owner].name
	var enemy = FactionSys.squad_power(sect, owner) * randf_range(0.6, 1.3)
	if d.get_power_rating() * randf_range(0.8, 1.2) >= enemy:
		d.add_fame(10)
		logs.append("%s ถูกศิษย์%sซุ่มโจมตี แต่ตีโต้จนแตกพ่ายไป!" % [d.disciple_name, fname])
		return
	if randf() < BuildingDB.diff(sect.difficulty).death:
		FactionSys.on_disciple_killed(sect, d, owner, "ถูก%sซุ่มสังหารที่%s" % [fname, WorldDB.NODES[d.mission_target].name], func(t): logs.append(t))
		return
	d.add_ailment("meridian_damage" if randf() < 0.5 else "internal_injury")
	d.injury_days = max(d.injury_days, 4)
	logs.append("[color=red]%s ถูกศิษย์%sซุ่มโจมตีจนบาดเจ็บ ต้องรีบกลับสำนัก[/color]" % [d.disciple_name, fname])
	_start_return(sect, d)

static func _gather_one_day(sect: SectData, d: DiscipleData) -> void:
	var gather: Dictionary = WorldDB.get_node_data(d.mission_target).get("gather", {})
	var mult = (1.0 + d.get_stat("gathering") * 0.05) * sect.get_node_yield(d.mission_target)
	for mat in gather:
		var amount = int(randi_range(gather[mat][0], gather[mat][1]) * mult)
		if randf() < d.get_stat("luck") * 0.03:
			amount += 1
		if amount > 0:
			d.carried_materials[mat] = d.carried_materials.get(mat, 0) + amount

static func _start_return(sect: SectData, d: DiscipleData) -> void:
	d.mission_phase = "returning"
	d.mission_total_days = max(1, get_route(sect, d.mission_target).days)
	d.mission_days_left = d.mission_total_days

static func _arrive_home(sect: SectData, d: DiscipleData) -> String:
	var loot: Array[String] = []
	if not d.carried_materials.is_empty():
		sect.add_materials(d.carried_materials)
		loot.append(MaterialDB.format_list(d.carried_materials))
	for eq in d.carried_equipment:
		sect.equipment_storage.append(eq)
		loot.append("%s [%s]" % [eq.item_name, eq.get_rarity_name()])
	for s in d.carried_skills:
		sect.add_library_skill(s)
		loot.append("คัมภีร์ " + s)
	d.carried_materials = {}
	d.carried_equipment.clear()
	d.carried_skills.clear()
	d.mission_type = ""
	d.mission_phase = ""
	d.mission_target = ""
	if d.injury_days > 0:
		d.status = DiscipleData.DiscipleStatus.INJURED
	else:
		d.status = DiscipleData.DiscipleStatus.IDLE
	if loot.is_empty():
		return "%s กลับถึงสำนักแล้ว (มือเปล่า)" % d.disciple_name
	return "%s กลับถึงสำนัก พร้อมของ: %s" % [d.disciple_name, ", ".join(loot)]

## บุกแดนลับ: ทีมของเราแย่งชิงสมบัติกับสำนักคู่แข่ง 3 สำนัก
static func resolve_secret_realm(sect: SectData, team: Array[DiscipleData], day: int) -> Array[String]:
	var logs: Array[String] = []
	var names = ", ".join(team.map(func(d): return d.disciple_name))
	if not WorldDB.is_secret_realm_open(day):
		logs.append("ทีม [%s] มาถึงแดนลับช้าเกินไป ทางเข้าปิดลงแล้ว..." % names)
		for d in team: _start_return(sect, d)
		return logs

	sect.last_secret_realm_cycle = int(day / float(WorldDB.SECRET_REALM_INTERVAL))
	var team_power = 0
	for d in team: team_power += d.get_power_rating()

	logs.append("[color=violet]ทีม [%s] ก้าวเข้าสู่แดนลับบรรพกาล! (พลังรวม %d)[/color]" % [names, team_power])
	var rivals = FactionDB.FACTIONS.keys().map(func(f): return FactionDB.FACTIONS[f].name)
	rivals.shuffle()
	var wins = 0
	for rival in rivals.slice(0, 3):
		var rival_power = int(StatSys.world_threat(day) * 2.0 * randf_range(0.6, 1.4))
		var our_roll = team_power * randf_range(0.8, 1.2)
		if our_roll >= rival_power:
			wins += 1
			logs.append("  - ปะทะกับ%s (พลัง %d) ... [color=green]ชนะ![/color]" % [rival, rival_power])
		else:
			var hurt: DiscipleData = team.pick_random()
			hurt.injury_days = max(hurt.injury_days, randi_range(3, 8))
			logs.append("  - ปะทะกับ%s (พลัง %d) ... [color=red]พ่ายแพ้[/color] %s บาดเจ็บ" % [rival, rival_power, hurt.disciple_name])

	# แจกสมบัติตามจำนวนครั้งที่ชนะ
	var carrier: DiscipleData = team[0]
	var mats = { "spirit_stone": randi_range(2, 5) }
	if wins >= 1:
		carrier.carried_equipment.append(EquipmentDB.generate_random(0.5, EquipmentData.Rarity.RARE))
		mats["beast_core"] = randi_range(1, 3)
		mats["snow_lotus"] = randi_range(0, 2)
	if wins >= 2:
		var skill_tier = SkillDB.Tier.IMMORTAL if randf() < 0.2 else SkillDB.Tier.HEAVEN
		carrier.carried_skills.append(SkillDB.get_random_skill_by_tier(skill_tier))
		mats["star_metal"] = randi_range(0, 2)
	if wins >= 3:
		carrier.carried_equipment.append(EquipmentDB.generate_random(1.0, EquipmentData.Rarity.EPIC))
		mats["dragon_scale"] = 1
	for m in mats:
		if mats[m] > 0:
			carrier.carried_materials[m] = carrier.carried_materials.get(m, 0) + mats[m]

	for d in team: d.add_fame(10 + wins * 10)
	if wins >= 1: carrier.carried_materials["scripture_fragment"] = carrier.carried_materials.get("scripture_fragment", 0) + wins
	if wins >= 3:
		ArchiveSys.unlock_achievement("secret_realm_sweep")
		for extra in LandmarkSys.on_realm(sect, team[0].mission_target): logs.append("[color=violet]%s[/color]" % extra)
	var verdict = ["แย่งชิงสมบัติได้เพียงเล็กน้อย", "ได้สมบัติพอสมควร", "ได้สมบัติล้ำค่า!", "กวาดสมบัติแดนลับเกือบทั้งหมด! ชื่อเสียงสำนักขจรไกล"][wins]
	logs.append("[color=violet]ผลแดนลับ: ชนะ %d/3 ครั้ง - %s ทีมกำลังเดินทางกลับ[/color]" % [wins, verdict])
	for d in team: _start_return(sect, d)
	return logs
