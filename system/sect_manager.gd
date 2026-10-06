extends Node
class_name SectManager

## Autoload script: บริหารจัดการสำนัก และดูแลความเป็น Dynamic (AI/Living World)
## ต้องนำไปตั้งค่าเป็น Autoload (Project > Project Settings > Autoload)

signal day_passed(current_day: int)
signal sect_event_logged(event: Dictionary)
signal sect_resources_changed

var current_sect: SectData
var current_day: int = 1

## บทบาทของผู้เล่นในสำนักนี้ (0 = เจ้าสำนัก, 1 = ผู้อาวุโส, 2 = ศิษย์ทั่วไป, -1 = ไม่มี)
var player_role: int = 0

## เข้าสู่วันใหม่
func process_daily_update() -> void:
	if not current_sect: return
	
	current_day += 1
	var socializing_disciples = []
	
	for disciple in current_sect.disciples:
		if disciple.status == DiscipleData.DiscipleStatus.DEPARTED: continue
		
		# 1. จัดการความหิว (กินอาหารของสำนัก)
		if current_sect.food >= 10:
			current_sect.food -= 10
			disciple.hunger = min(100, disciple.hunger + 20)
		else:
			disciple.hunger = max(0, disciple.hunger - 30)
			disciple.mood = max(0, disciple.mood - 10)
			if disciple.hunger == 0:
				log_event("%s หิวโซจนแทบทนไม่ไหว" % disciple.disciple_name, [disciple])
		
		# 2. ตรวจสอบความจงรักภักดี / ทรยศ
		check_loyalty_and_defection(disciple)
		
		# ถ้าลาออกไปแล้ว ข้ามขั้นตอนอื่น
		if disciple.status == DiscipleData.DiscipleStatus.DEPARTED: continue
		
		# 3. การเรียนรู้วิชาจากอาจารย์ (Skill Inheritance)
		if disciple.master and randf() < 0.1: # โอกาส 10% ต่อวัน
			if disciple.master.learned_skills.size() > 0:
				var random_skill = disciple.master.learned_skills.pick_random()
				if not disciple.learned_skills.has(random_skill):
					disciple.learned_skills.append(random_skill)
					log_event("%s ได้เรียนรู้วิชา %s จากอาจารย์ %s" % [disciple.disciple_name, random_skill, disciple.master.disciple_name], [disciple, disciple.master])
		
		# 4. NPC Autonomy (ตัดสินใจเลือกกิจกรรมเมื่อว่าง)
		if disciple.status == DiscipleData.DiscipleStatus.IDLE:
			var best_activity = evaluate_activity_utility(disciple)
			# ดำเนินการตามกิจกรรมที่เลือก (ในแบบจำลองเบื้องต้น)
			if best_activity == "ฝึกฝน":
				disciple.mood = max(0, disciple.mood - 5)
				# TODO: เพิ่ม exp / stat
			elif best_activity == "พักผ่อน":
				disciple.mood = min(100, disciple.mood + 20)
			elif best_activity == "เข้าสังคม":
				socializing_disciples.append(disciple)
				
	# 5. จับคู่ NPC สำหรับการเข้าสังคม
	if socializing_disciples.size() >= 2:
		socializing_disciples.shuffle()
		for i in range(0, socializing_disciples.size() - 1, 2):
			resolve_npc_interaction(socializing_disciples[i], socializing_disciples[i+1])
			
	# 6. สุ่มเหตุการณ์รายวันของสำนัก (Random Life Events)
	if randf() < 0.05: # โอกาส 5% ที่จะมีเหตุการณ์พิเศษ
		trigger_random_sect_event()
		
	sect_resources_changed.emit()
	day_passed.emit(current_day)

## คำนวณ Utility Score ว่า AI ควรทำอะไรตอนว่าง
func evaluate_activity_utility(disciple: DiscipleData) -> String:
	var activities = {
		"ฝึกฝน": 50,
		"พักผ่อน": 50,
		"เข้าสังคม": 50
	}
	
	# น้ำหนักจากความหิว/อารมณ์
	if disciple.mood < 30: activities["พักผ่อน"] += 50
	if disciple.hunger < 40: activities["พักผ่อน"] += 20
	
	# น้ำหนักจากนิสัย
	if disciple.has_trait("ขยัน"): activities["ฝึกฝน"] += 30
	if disciple.has_trait("เกียจคร้าน"): activities["พักผ่อน"] += 30
	if disciple.has_trait("ขี้นินทา"): activities["เข้าสังคม"] += 30
	if disciple.has_trait("ทะเยอทะยาน"): activities["ฝึกฝน"] += 20
	if disciple.has_trait("เก็บตัว"): activities["เข้าสังคม"] -= 30
	
	# เพิ่ม randomness เล็กน้อย (0-20)
	for act in activities.keys():
		activities[act] += randi_range(0, 20)
		
	var best_act = "พักผ่อน"
	var max_score = -999
	for act in activities:
		if activities[act] > max_score:
			max_score = activities[act]
			best_act = act
			
	return best_act

## ประมวลผลเมื่อ NPC ตัดสินใจเข้าสังคมกัน
func resolve_npc_interaction(npc_a: DiscipleData, npc_b: DiscipleData) -> void:
	# คำนวณความเข้ากันได้เบื้องต้น
	var compatibility = 0
	if npc_a.has_trait("ซื่อสัตย์") and npc_b.has_trait("ซื่อสัตย์"): compatibility += 1
	if npc_a.has_trait("ขี้อิจฉา") or npc_b.has_trait("ขี้อิจฉา"): compatibility -= 1
	
	var success = (randf() < 0.5 + (compatibility * 0.1))
	
	if not npc_a.relationships.has(npc_b.disciple_name):
		npc_a.relationships[npc_b.disciple_name] = { "affinity": 0.0, "type": "คนรู้จัก" }
	if not npc_b.relationships.has(npc_a.disciple_name):
		npc_b.relationships[npc_a.disciple_name] = { "affinity": 0.0, "type": "คนรู้จัก" }
		
	if success:
		npc_a.relationships[npc_b.disciple_name].affinity += 10
		npc_b.relationships[npc_a.disciple_name].affinity += 10
		npc_a.add_memory(current_day, "คุยถูกคอกับ %s" % npc_b.disciple_name)
		npc_b.add_memory(current_day, "คุยถูกคอกับ %s" % npc_a.disciple_name)
		log_event("%s และ %s พูดคุยกันอย่างถูกคอ" % [npc_a.disciple_name, npc_b.disciple_name], [npc_a, npc_b])
	else:
		npc_a.relationships[npc_b.disciple_name].affinity -= 10
		npc_b.relationships[npc_a.disciple_name].affinity -= 10
		npc_a.add_memory(current_day, "ทะเลาะกับ %s" % npc_b.disciple_name)
		npc_b.add_memory(current_day, "ทะเลาะกับ %s" % npc_a.disciple_name)
		log_event("%s และ %s มีปากเสียงกันระหว่างสนทนา" % [npc_a.disciple_name, npc_b.disciple_name], [npc_a, npc_b])

## ตรวจสอบความภักดีและโอกาสทรยศ
func check_loyalty_and_defection(disciple: DiscipleData) -> void:
	if disciple.loyalty < 20 and disciple.mood < 30:
		# มีโอกาส 5% ต่อวันที่พารามิเตอร์ต่ำ จะเกิดเหตุการณ์
		if randf() < 0.05:
			disciple.status = DiscipleData.DiscipleStatus.DEPARTED
			var defection_text = ""
			if disciple.has_trait("ขี้อิจฉา") or disciple.ambition == "อยากตั้งสำนักเอง":
				# ทรยศแบบรุนแรง (ขโมยของ)
				var stolen_money = min(current_sect.money, 500)
				current_sect.money -= stolen_money
				defection_text = "%s ทรยศสำนัก! หลบหนีไปพร้อมกับเงิน %d" % [disciple.disciple_name, stolen_money]
			else:
				# ลาออกเงียบๆ
				defection_text = "%s ทนไม่ไหวกับสภาพของสำนัก และเก็บของจากไปเงียบๆ" % disciple.disciple_name
			
			log_event(defection_text, [disciple])

## บันทึกเหตุการณ์ลง SectData และส่ง Signal ไปยัง UI
func log_event(text: String, involved_ids: Array = []) -> void:
	if current_sect:
		current_sect.log_event(current_day, text, involved_ids)
	
	var event_data = {
		"day": current_day,
		"text": text,
		"involved_ids": involved_ids
	}
	sect_event_logged.emit(event_data)

## เหตุการณ์สุ่มระดับสำนัก
func trigger_random_sect_event() -> void:
	# สุ่มข่าวลือหรือเหตุการณ์ที่ไม่เจาะจงบุคคล (สามารถเพิ่ม Logic ได้ภายหลัง)
	var events = [
		"มีพ่อค้าพเนจรแวะมาที่หน้าสำนัก",
		"เกิดพายุฝนตกหนัก ทำให้เสบียงบางส่วนเสียหาย",
		"มีข่าวลือเรื่องยอดฝีมือลึกลับปรากฏตัวใกล้ๆ"
	]
	log_event(events.pick_random())

# ══════════════════════════════════════════
# Player Interaction Functions
# ══════════════════════════════════════════

func join_sect(sect: SectData, role: int) -> void:
	current_sect = sect
	player_role = role

func send_on_expedition(disciple: DiscipleData) -> void:
	if player_role != 0 and player_role != 1: return # เฉพาะเจ้าสำนัก/อาวุโส
	disciple.status = DiscipleData.DiscipleStatus.MISSION
	log_event("ผู้เล่นส่ง %s ออกไปทำภารกิจ" % disciple.disciple_name, [disciple])

func assign_training(disciple: DiscipleData, building: BuildingData = null) -> void:
	if player_role != 0 and player_role != 1: return
	disciple.status = DiscipleData.DiscipleStatus.TRAINING
	log_event("ผู้เล่นสั่งให้ %s ไปฝึกฝน" % disciple.disciple_name, [disciple])

func flirt_with(disciple: DiscipleData) -> void:
	# ระบบจีบแบบง่าย
	disciple.affection += 5
	log_event("ผู้เล่นพูดคุยเกี้ยวพาราสีกับ %s" % disciple.disciple_name, [disciple])
