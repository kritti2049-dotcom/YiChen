extends Control

var sect_manager: SectManager
var test_sect: SectData

var d1: DiscipleData
var d2: DiscipleData
var d3: DiscipleData

func _ready() -> void:
	setup_sect()
	
	# ผูกปุ่ม UI กับฟังก์ชันต่างๆ
	if has_node("Margin/VBox/BottomBar/BtnNextDay"):
		$Margin/VBox/BottomBar/BtnNextDay.pressed.connect(_on_next_day_pressed)
		$Margin/VBox/BottomBar/BtnBack.pressed.connect(func(): get_tree().change_scene_to_file("res://scene/main_menu.tscn"))
		
		var btn_train = $Margin/VBox/MainContent/BuildingsPanel/BtnTrain
		btn_train.pressed.connect(_on_btn_train_pressed)
		var btn_hunt = $Margin/VBox/MainContent/BuildingsPanel/BtnHunt
		btn_hunt.pressed.connect(_on_btn_hunt_pressed)
		var btn_breakthrough = $Margin/VBox/MainContent/BuildingsPanel/BtnBreakthrough
		btn_breakthrough.pressed.connect(_on_btn_breakthrough_pressed)
		var btn_library = $Margin/VBox/MainContent/BuildingsPanel/BtnLibrary
		btn_library.pressed.connect(_on_btn_library_pressed)
	
	update_ui()

func setup_sect() -> void:
	test_sect = SectData.new()
	test_sect.sect_name = "สำนักกิเลนทะยาน"
	test_sect.money = 1000
	test_sect.food = 100
	
	var base_unit = UnitData.new()
	base_unit.max_hp = 100
	base_unit.attack = 10
	base_unit.defense = 5

	d1 = DiscipleData.new()
	d1.disciple_name = "หวังต้า"
	d1.unit_data = base_unit
	d1.comprehension = 20
	d1.personality_traits.assign(["ขยัน", "ทะเยอทะยาน"])
	d1.status = DiscipleData.DiscipleStatus.IDLE
	d1.hunger = 80
	
	d2 = DiscipleData.new()
	d2.disciple_name = "หลี่เสี่ยว"
	d2.unit_data = base_unit
	d2.comprehension = 5
	d2.personality_traits.assign(["เกียจคร้าน", "ขี้นินทา"])
	d2.status = DiscipleData.DiscipleStatus.IDLE
	d2.hunger = 90
	
	d3 = DiscipleData.new()
	d3.disciple_name = "อาจารย์ลุง"
	d3.unit_data = base_unit
	d3.level = 5
	d3.realm_name = "รวบรวมลมปราณ ขั้น 5"
	d3.personality_traits.assign(["เก็บตัว"])
	d3.learned_skills.assign(["เพลงกระบี่ไร้เงา", "ปราณวารี"])
	d3.status = DiscipleData.DiscipleStatus.IDLE
	
	d1.master = d3
	test_sect.disciples.append_array([d1, d2, d3])
	
	sect_manager = SectManager.new()
	add_child(sect_manager)
	sect_manager.join_sect(test_sect, 0)
	
	sect_manager.sect_event_logged.connect(_on_sect_event_logged)

func update_ui() -> void:
	$Margin/VBox/TopBar/DayLabel.text = "วันที่: %d" % sect_manager.current_day
	$Margin/VBox/TopBar/MoneyLabel.text = "เงิน: %d" % test_sect.money
	$Margin/VBox/TopBar/FoodLabel.text = "อาหาร: %d" % test_sect.food
	
	var disciple_text = ""
	for d in test_sect.disciples:
		var status_str = "[color=gray]ว่าง (Idle)[/color]"
		if d.status == DiscipleData.DiscipleStatus.TRAINING:
			status_str = "[color=orange]ฝึกซ้อมอยู่ลานฝึก[/color]"
		elif d.status == DiscipleData.DiscipleStatus.MISSION:
			status_str = "[color=green]ลงเขาทำภารกิจ[/color]"
			
		var info = CultivationSys.get_realm_info(d.level)
		d.realm_name = info.name
		var req_exp = CultivationSys.get_required_exp(d.level)
		var exp_str = "EXP: %d / %d" % [d.experience, req_exp]
		if info.is_bottleneck and d.experience >= req_exp:
			exp_str = "[color=red]ติดคอขวดขั้นใหญ่! (พร้อมทะลวง)[/color]"
		
		disciple_text += "[b]%s[/b] (ขั้น: %s)\n" % [d.disciple_name, d.realm_name]
		disciple_text += "  - %s\n" % exp_str
		disciple_text += "  - ความหิว: %d/100\n" % d.hunger
		disciple_text += "  - สถานะ: %s\n\n" % status_str
		
	$Margin/VBox/MainContent/DisciplesPanel/DiscipleList.text = disciple_text

func _on_next_day_pressed() -> void:
	# คำนวณผลลัพธ์ของกิจกรรมที่ศิษย์ทำค้างไว้ในวันนั้น
	var report = ""
	var total_earned_money = 0
	var total_earned_food = 0
	
	for d in test_sect.disciples:
		if d.status == DiscipleData.DiscipleStatus.TRAINING:
			d.gain_experience(80, sect_manager.current_day)
			d.hunger -= 10
			report += "- %s ได้ EXP จากการฝึกซ้อม\n" % d.disciple_name
		elif d.status == DiscipleData.DiscipleStatus.MISSION:
			var m_gained = randi_range(50, 150)
			var f_gained = randi_range(20, 50)
			total_earned_money += m_gained
			total_earned_food += f_gained
			d.hunger -= 20
			d.gain_experience(20, sect_manager.current_day)
			report += "- %s หาเงินได้ %d และอาหาร %d\n" % [d.disciple_name, m_gained, f_gained]
			
		# ตัดสินใจว่าจะให้ทำต่อ หรือกลับมาว่าง (ในที่นี้ให้กลับมาว่างก่อน จะได้สั่งใหม่ได้)
		d.status = DiscipleData.DiscipleStatus.IDLE

	test_sect.money += total_earned_money
	test_sect.food += total_earned_food
	
	if report != "":
		_add_log_entry("[ผลลัพธ์กิจกรรมวันนี้]\n" + report.strip_edges())

	# ให้ระบบ AI สำนักทำการคำนวณรายวัน (ลดความหิว สุ่มเหตุการณ์)
	sect_manager.process_daily_update()
	update_ui()

func _on_btn_train_pressed() -> void:
	var count = 0
	for d in test_sect.disciples:
		if d.status == DiscipleData.DiscipleStatus.IDLE:
			d.status = DiscipleData.DiscipleStatus.TRAINING
			count += 1
	if count > 0:
		_add_log_entry("สั่งให้ศิษย์ %d คน ไปที่ลานฝึกซ้อม" % count)
	else:
		_add_log_entry("ไม่มีศิษย์ที่ว่างอยู่เลย!")
	update_ui()

func _on_btn_hunt_pressed() -> void:
	var count = 0
	for d in test_sect.disciples:
		if d.status == DiscipleData.DiscipleStatus.IDLE:
			d.status = DiscipleData.DiscipleStatus.MISSION
			count += 1
	if count > 0:
		_add_log_entry("สั่งให้ศิษย์ %d คน ไปหอภารกิจและลงเขา" % count)
	else:
		_add_log_entry("ไม่มีศิษย์ที่ว่างอยู่เลย!")
	update_ui()

func _on_sect_event_logged(event: Dictionary) -> void:
	var msg = "[color=yellow][วันที่ %d][/color] %s" % [event.day, event.text]
	_add_log_entry(msg)

func _add_log_entry(msg: String) -> void:
	$Margin/VBox/MainContent/LogsPanel/EventLog.text += msg + "\n\n"

func _on_btn_breakthrough_pressed() -> void:
	var attempt_count = 0
	var success_count = 0
	
	for d in test_sect.disciples:
		var info = CultivationSys.get_realm_info(d.level)
		var req_exp = CultivationSys.get_required_exp(d.level)
		
		# เช็คว่าติดคอขวดและ EXP เต็มแล้วหรือยัง
		if info.is_bottleneck and d.experience >= req_exp:
			attempt_count += 1
			_add_log_entry("ศิษย์ [b]%s[/b] กำลังนั่งสมาธิทะลวงคอขวดเข้าสู่ %s..." % [d.disciple_name, CultivationSys.get_realm_info(d.level + 1).name])
			
			var success = d.attempt_breakthrough(0.0, sect_manager.current_day)
			if success:
				success_count += 1
				_add_log_entry("[color=green]สำเร็จ! %s ทะลวงคอขวดได้สำเร็จ![/color]" % d.disciple_name)
			else:
				_add_log_entry("[color=red]ล้มเหลว! %s ธาตุไฟแตกซ่าน ลมปราณตีกลับ เสีย EXP 20%%![/color]" % d.disciple_name)
				
	if attempt_count == 0:
		_add_log_entry("ตอนนี้ยังไม่มีศิษย์คนไหนที่พร้อมทะลวงคอขวดขั้นใหญ่ (EXP ยังไม่เต็ม หรือยังไม่ถึงระดับ 9)")
		
	update_ui()

func _on_btn_library_pressed() -> void:
	# สุ่มวิชาใหม่ให้ศิษย์ที่ว่างเรียน
	var count = 0
	for d in test_sect.disciples:
		if d.status == DiscipleData.DiscipleStatus.IDLE:
			# สุ่มวิชาระดับมนุษย์ (1) หรือ ปฐพี (2)
			var tier = randi_range(1, 2)
			var new_skill = SkillDB.get_random_skill_by_tier(tier)
			if new_skill != "" and not d.learned_skills.has(new_skill):
				d.learned_skills.append(new_skill)
				_add_log_entry("[color=cyan]%s ได้เข้าไปอ่านตำราและสำเร็จวิชาใหม่: %s[/color]" % [d.disciple_name, new_skill])
				count += 1
				
	if count == 0:
		_add_log_entry("ไม่มีศิษย์ที่ว่างสำหรับเข้าหอตำรา หรือศิษย์ว่างแต่สุ่มไม่ได้วิชาใหม่")
	update_ui()
