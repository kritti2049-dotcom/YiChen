extends Node
class_name GameController

## Controller ของสถาปัตยกรรม MVC (Signal-based)
## - Model: ข้อมูลทั้งหมดอยู่ใน GlobalGame (Autoload = GameManager) -> SectData / DiscipleData
## - View: หน้าจอทำหน้าที่แค่แสดงผล และ "ยิง Signal คำสั่ง" (request_*) มาที่นี่ ห้ามแก้ข้อมูลเอง
## - Controller (ไฟล์นี้): ตรวจสอบเงื่อนไขทุกอย่างก่อนแก้ข้อมูล (ปุ่มที่กดผิดจังหวะจะไม่ทำให้เกมพัง)
##   แล้วยิง Signal ผลลัพธ์กลับไปให้ View วาดใหม่: sect_changed / disciple_changed / action_result
## ใช้งาน: GlobalGame.controller.request_upgrade_building.emit("main_hall")

# ── คำสั่งจาก View ──
signal request_upgrade_building(building_id: String)
signal request_recruit
signal request_research(tier: int)
signal request_diplomacy(action: String, faction_id: String)
signal request_pay_tribute
signal request_use_pill(d: DiscipleData, pill_id: String)
signal request_equip(d: DiscipleData, item: EquipmentData)
signal request_unequip(d: DiscipleData, slot: int)

# ── ผลลัพธ์กลับไปที่ View ──
## ข้อมูลสำนัก (เงิน วัสดุ อาคาร การเมือง) เปลี่ยน
signal sect_changed
## ข้อมูลศิษย์คนนี้เปลี่ยน (ค่าพลัง อุปกรณ์ ขั้นบำเพ็ญ)
signal disciple_changed(d: DiscipleData)
## ผลของคำสั่ง (ok = สำเร็จไหม, message = ข้อความแจ้งผู้เล่น)
signal action_result(ok: bool, message: String)

func _ready() -> void:
	request_upgrade_building.connect(_on_upgrade_building)
	request_recruit.connect(_on_recruit)
	request_research.connect(_on_research)
	request_diplomacy.connect(_on_diplomacy)
	request_pay_tribute.connect(_on_pay_tribute)
	request_use_pill.connect(_on_use_pill)
	request_equip.connect(_on_equip)
	request_unequip.connect(_on_unequip)

func _sect() -> SectData:
	return GlobalGame.current_sect

func _log(text: String) -> void:
	GlobalGame.sect_manager.log_event(text)

func _fail(message: String) -> void:
	action_result.emit(false, message)

func _done(message: String, log_it := true) -> void:
	if log_it: _log(message)
	GlobalGame.save_game()
	sect_changed.emit()
	action_result.emit(true, message)

# ══════════════════════════════════════════
# สำนัก
# ══════════════════════════════════════════

## อัปเกรดตึกหลัง uid (จ่ายวัสดุแล้วเป็นไซต์ก่อสร้าง ศิษย์ว่าง/ค่ายช่างช่วยกันสร้างรายวัน)
func _on_upgrade_building(uid: String) -> void:
	var sect = _sect()
	var inst = sect.instance(uid) if sect != null else {}
	if inst.is_empty():
		_fail("ไม่พบสิ่งปลูกสร้าง")
		return
	var lv = int(inst.level)
	if lv >= BuildingDB.BUILDINGS[inst.type].max_level:
		_fail("%s ระดับสูงสุดแล้ว" % BuildingDB.inst_name(inst))
		return
	if not inst.site.is_empty():
		_fail("%s กำลังก่อสร้างอยู่" % BuildingDB.inst_name(inst))
		return
	var cost = BuildingDB.get_upgrade_cost(inst.type, lv)
	if sect.money < cost.money or not sect.has_materials(cost.materials):
		_fail("วัสดุหรือเงินไม่พอ")
		return
	sect.money -= cost.money
	sect.consume_materials(cost.materials)
	sect.start_construction(uid)
	_done("เริ่มอัปเกรด%s เป็นระดับ %d — ศิษย์ว่างและค่ายช่างจะช่วยกันสร้างทุกวัน" % [BuildingDB.inst_name(inst), lv + 1])

func recruit_cost() -> int:
	return 150 + _sect().get_active_disciples().size() * 50

func _on_recruit() -> void:
	var sect = _sect()
	if sect == null: return
	var cost = recruit_cost()
	if sect.get_active_disciples().size() >= sect.get_max_disciples():
		_fail("ศิษย์เต็มแล้ว อัปเกรดโถงหลักก่อน")
		return
	if sect.money < cost:
		_fail("เงินไม่พอ (ต้องการ %d)" % cost)
		return
	sect.money -= cost
	var made = ApplicantSys.spawn(sect, 2, "มาตามประกาศรับสมัครของสำนัก")
	if made.is_empty():
		sect.money += cost
		_fail("ประตูสำนักมีผู้สมัครรอเต็มแล้ว (ตัดสินใจรับ/ปฏิเสธก่อน)")
		return
	_done("ประกาศรับสมัครศิษย์ มีผู้สมัครมาที่ประตูสำนัก %d คน (เมนู ประตูสำนัก)" % made.size())

func _on_research(tier: int) -> void:
	if _sect() == null: return
	var text = GlobalGame.sect_manager.start_research(tier)
	if _sect().research_skill == "":
		_fail(text)
		return
	_done("[หอตำรา] " + text)

# ══════════════════════════════════════════
# การเมืองยุทธภพ
# ══════════════════════════════════════════

func _on_diplomacy(action: String, fid: String) -> void:
	var sect = _sect()
	if sect == null or not sect.factions.has(fid):
		_fail("ไม่พบขั้วอำนาจนี้")
		return
	var f = sect.factions[fid]
	match action:
		"gift":
			if sect.money < FactionSys.gift_cost(sect, fid):
				_fail("เงินไม่พอ")
				return
			_done(FactionSys.gift(sect, fid))
		"war":
			if f.war:
				_fail("กำลังทำสงครามอยู่แล้ว")
				return
			_done(FactionSys.declare_war(sect, fid))
		"peace":
			if not f.war:
				_fail("ไม่ได้ทำสงครามกันอยู่")
				return
			if sect.money < FactionSys.peace_cost(sect, fid):
				_fail("เงินไม่พอ")
				return
			_done(FactionSys.make_peace(sect, fid))
		_:
			_fail("ไม่รู้จักคำสั่ง " + action)

func _on_pay_tribute() -> void:
	var sect = _sect()
	if sect == null or sect.pending_tribute.is_empty():
		_fail("ไม่มีการเรียกส่วย")
		return
	if sect.money < sect.pending_tribute.amount:
		_fail("เงินไม่พอจ่ายส่วย")
		return
	_done(FactionSys.pay_tribute(sect))

# ══════════════════════════════════════════
# ศิษย์
# ══════════════════════════════════════════

func _disciple_done(d: DiscipleData, message: String) -> void:
	_log(message)
	GlobalGame.save_game()
	disciple_changed.emit(d)
	sect_changed.emit()
	action_result.emit(true, message)

func _on_use_pill(d: DiscipleData, pill_id: String) -> void:
	var sect = _sect()
	if sect == null or d == null or not RecipeDB.PILLS.has(pill_id):
		_fail("ใช้ยาไม่ได้")
		return
	if d.status == DiscipleData.DiscipleStatus.MISSION:
		_fail("%s อยู่นอกสำนัก" % d.disciple_name)
		return
	var q = sect.take_best_pill(pill_id)
	if q < 0:
		_fail("ไม่มี%sในคลัง" % RecipeDB.PILLS[pill_id].name)
		return
	var text = ""
	var pill_label = "%s [%s]" % [RecipeDB.PILLS[pill_id].name, RecipeDB.PILL_QUALITY_NAMES[q]]
	match pill_id:
		"healing_pill":
			d.injury_days = max(0, d.injury_days - (3 + q * 3))
			if d.injury_days == 0 and d.status == DiscipleData.DiscipleStatus.INJURED:
				d.status = DiscipleData.DiscipleStatus.IDLE
			text = "บาดแผลทุเลาลง (เหลือพักฟื้น %d วัน)" % d.injury_days
		"qi_pill":
			var amount = 150 * (q + 1) * max(1, CultivationSys.get_realm_info(d.level).major_index)
			d.gain_experience(amount, sect.current_day)
			text = "ลมปราณพลุ่งพล่าน ได้รับ EXP %d" % amount
		"marrow_pill":
			# ชำระไขกระดูก: เพิ่มค่ารากฐานร่างกาย (หายากมาก จึงเพิ่มได้ทีละ 1 และไม่เกินเพดาน)
			var amount = 1 if q < 3 else 2
			for key in StatSys.STATS_DEF:
				if StatSys.STATS_DEF[key].cat == "Physical":
					d.add_stat(key, amount, pill_label)
			text = "กระดูกและไขกระดูกถูกชำระ ค่ารากฐานร่างกายทุกด้าน +%d" % amount
		"calm_tea":
			sect.add_pill(pill_id, q)
			text = MoodSystem.give_tea(sect, d, GlobalGame.sect_manager)
			disciple_changed.emit(d)
			action_result.emit(true, text)
			return
		_:
			text = "ยานี้ใช้กับการทะลวงคอขวด (ใช้ที่หน้าทะลวงคอขวด)"
			sect.add_pill(pill_id, q)
			_fail(text)
			return
	_disciple_done(d, "%s ใช้ %s: %s" % [d.disciple_name, pill_label, text])

func _on_equip(d: DiscipleData, item: EquipmentData) -> void:
	var sect = _sect()
	if sect == null or d == null or item == null:
		_fail("ข้อมูลไม่ถูกต้อง")
		return
	var from_carried = d.carried_equipment.has(item)
	var from_sect = sect.equipment_storage.has(item)
	if not from_carried and not from_sect:
		_fail("ไม่พบอุปกรณ์ในคลังหรือสัมภาระ")
		return
	if from_sect and d.status == DiscipleData.DiscipleStatus.MISSION and d.mission_phase in ["going", "returning", "working"] and not d.is_founder:
		_fail("%s กำลังเดินทางกลางป่า ไม่สามารถเบิกของจากสำนักใหญ่ได้" % d.disciple_name)
		return
	if from_carried:
		d.carried_equipment.erase(item)
	else:
		sect.equipment_storage.erase(item)
	var old = d.equip(item)
	if old:
		if from_carried:
			d.carried_equipment.append(old)
		else:
			sect.equipment_storage.append(old)
	_disciple_done(d, "%s สวมใส่ %s (พลังรบรวมเป็น %d)" % [d.disciple_name, item.item_name, d.get_power_rating()])

func _on_unequip(d: DiscipleData, slot: int) -> void:
	var sect = _sect()
	if sect == null or d == null: return
	var old = d.unequip(slot)
	if old == null:
		_fail("ช่องนี้ว่างอยู่แล้ว")
		return
	if d.status == DiscipleData.DiscipleStatus.MISSION and d.mission_phase in ["going", "returning", "working"] and not d.is_founder:
		d.carried_equipment.append(old)
	else:
		sect.equipment_storage.append(old)
	_disciple_done(d, "%s ถอด %s" % [d.disciple_name, old.item_name])
