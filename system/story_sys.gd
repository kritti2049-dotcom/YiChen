extends RefCounted
class_name StorySys

## อีเวนต์ระดับโลกตามเนื้อเรื่อง "พิภพโลหิตชาด" (เฉพาะโหมดเนื้อเรื่อง)
## แต่ละบทเกิดตามวันในเกม เปลี่ยนพลัง/ความสัมพันธ์ของขั้วอำนาจจริง บางบทให้ผู้เล่นเลือกทางเดิน (pending_story)
## ผลของตัวเลือกเขียนไว้ใน _apply (ใช้ทั้งผลอัตโนมัติ "auto" และผลของแต่ละตัวเลือก)

const CHAPTERS = [
	{ "id": "prologue", "day": 3, "title": "บทนำ: แผ่นดินโลหิตชาด",
		"text": "แคว้นต้าเยี่ยครองจงหยวนภายใต้เงาของสิบขันที จักรพรรดิอ่อนแอ พันธมิตรยุทธภพสยบฟ้าแตกแยก พรรคมารอัสดงและลัทธิบัวโลหิตซ่องสุมกำลัง ส่วนราชวงศ์ที่ล่มสลายทั้งสามรอวันทวงแค้น... สำนักเล็กๆ ของท่านเพิ่งถือกำเนิดท่ามกลางพายุลูกนี้",
		"options": [] },
	{ "id": "register", "day": 25, "title": "ราชโองการจากนครเมฆาโลหิต",
		"text": "ขันทีจ้าวอิงส่งราชโองการ: สำนักยุทธ์ทุกแห่งต้องขึ้นทะเบียนกับราชสำนักและส่งรายชื่อศิษย์ให้หน่วยเหยี่ยวเงา ฝ่ายธรรมะต่างไม่พอใจ",
		"options": [
			{ "text": "ยอมขึ้นทะเบียน (ราชสำนัก +15, ฝ่ายธรรมะ -5)", "effect": "register_yes" },
			{ "text": "ปฏิเสธอย่างสุภาพ (ราชสำนัก -15, ฝ่ายธรรมะ +5)", "effect": "register_no" },
		] },
	{ "id": "blood_lotus", "day": 55, "title": "บัวโลหิตผลิบาน",
		"text": "ลัทธิบัวโลหิตบุกหุบเขาไผ่ม่วงของสภามังกรเร้น ชาวบ้านถูกจับไปเป็นเครื่องสังเวย สภามังกรเร้นร้องขอความช่วยเหลือจากทุกสำนัก",
		"auto": "lotus_attack",
		"options": [
			{ "text": "ส่งเสบียงและศิษย์ไปช่วย (เงิน 300, ฝ่ายธรรมะ +8, ชื่อเสียง +20, ลัทธิบัวโลหิต -25)", "effect": "lotus_help", "cost": 300 },
			{ "text": "ไม่เข้าไปยุ่ง", "effect": "" },
		] },
	{ "id": "cursed_sword", "day": 70, "title": "กระบี่มหาโชคมารปรากฏ",
		"text": "ศิษย์เก็บกระบี่ดำสนิทได้ที่ซากสนามรบเก่า ตัวกระบี่ซุบเลือดโบราณ ผู้ที่ถือมันเล่าว่าได้ยินเสียงกระซิบบอกให้ฆ่า... ข่าวลือว่านี่คือ 'กระบี่มหาโชคมาร' ที่ใครครอบครองจะถูกราชสำนัก หน่วยเหยี่ยวเงา และสำนักคู่แข่งทั้งยุทธภพตามล่า",
		"options": [
			{ "text": "เก็บกระบี่ไว้ในคลัง (พลังมหาศาล แต่ศัตรูจะยกทัพมาแย่งชิงเป็นระยะ)", "effect": "take_cursed_sword" },
			{ "text": "ฝังกระบี่ทิ้งในหุบเขาลึก", "effect": "" },
		] },
	{ "id": "north_war", "day": 85, "title": "ศึกชายแดนเหนือ",
		"text": "ข่านเตมูร์นำม้าศึกนับหมื่นบุกด่านเหนือ ตระกูลป้อมอัสนีและตระกูลหมิงตั้งรับสุดกำลัง ราชวงศ์เป่ยเหลียงลอบช่วยชนเผ่าทุ่งหญ้า",
		"auto": "north_war", "options": [] },
	{ "id": "royal_tournament", "day": 115, "title": "งานประลองยุทธ์หลวง",
		"text": "องค์จักรพรรดิประกาศจัดงานประลองยุทธ์หลวงที่นครเมฆาโลหิต ยอดฝีมือจากทั่วแผ่นดินมารวมตัว ผู้ชนะจะได้รับรางวัลและเกียรติยศสูงสุด",
		"options": [
			{ "text": "ส่งศิษย์ที่เก่งที่สุดลงประลอง", "effect": "tournament_join" },
			{ "text": "ไม่ส่ง (เฝ้าดูอยู่ห่างๆ)", "effect": "" },
		] },
	{ "id": "azure_dragon", "day": 150, "title": "เงามังกรครามปรากฏ",
		"text": "เรือรบไร้ธงโผล่จากม่านหมอกทะเลบูรพา สำนักไป่เซียวเปิดเผยว่าวังมังกรครามแห่งราชวงศ์ชางหลงยังอยู่ และมีข่าวลือว่าขันทีจ้าวอิงคือหมากของพวกมัน",
		"auto": "azure_reveal", "options": [] },
	{ "id": "sunset_march", "day": 200, "title": "พรรคมารอัสดงยกทัพขึ้นเหนือ",
		"text": "เย่หวังประกาศสงครามกับสำนักกระบี่เมฆาขาว พันธมิตรยุทธภพเรียกทุกสำนักร่วมรบ",
		"auto": "sunset_war",
		"options": [
			{ "text": "ร่วมรบกับพันธมิตร (ประกาศสงครามกับพรรคมารอัสดง, ฝ่ายธรรมะ +15)", "effect": "join_alliance" },
			{ "text": "วางตัวเป็นกลาง (พรรคมารอัสดง +10, ฝ่ายธรรมะ -5)", "effect": "stay_neutral" },
		] },
	{ "id": "old_dynasties", "day": 260, "title": "ราชวงศ์เก่าลุกฮือ",
		"text": "ป้อมหยกขาวของเป่ยเหลียงและนครใต้ดินเสวียนเฉินยกทัพพร้อมกัน กองทัพหลวงเสียหายหนัก แผ่นดินลุกเป็นไฟ",
		"auto": "dynasty_revolt", "options": [] },
	{ "id": "emperor_dies", "day": 330, "title": "จักรพรรดิสวรรคต",
		"text": "จักรพรรดิต้าเยี่ยสวรรคตอย่างปริศนา สิบขันทีเงาเตรียมตั้งหุ่นเชิดขึ้นครองบัลลังก์ ส่วนองค์ชายสี่หลิวเฟยลอบติดต่อสำนักยุทธ์ขอความช่วยเหลือ ทุกฝ่ายจับตามองว่าท่านจะยืนข้างใคร",
		"options": [
			{ "text": "สนับสนุนสิบขันที (ราชสำนัก +30, ฝ่ายธรรมะ -20)", "effect": "back_eunuchs" },
			{ "text": "ช่วยองค์ชายสี่ (สิบขันที -30, ฝ่ายธรรมะ +15, ชื่อเสียง +40)", "effect": "back_prince" },
			{ "text": "ไม่เลือกข้าง", "effect": "" },
		] },
	{ "id": "year_one", "day": 360, "title": "บทส่งท้ายปีแรก",
		"text": "หนึ่งปีผ่านไปในยุทธภพที่นองเลือด สำนักของท่านยังยืนหยัดอยู่ได้ ตำนานบทต่อไปรอให้ท่านเขียนเอง (ภาคต่อของเนื้อเรื่องเพิ่มเป็น Scenario ใหม่ได้ในอนาคต)",
		"options": [] },
]

static func daily(sect: SectData, day: int, log: Callable) -> void:
	if sect.world_mode != "story" or not sect.pending_story.is_empty(): return
	for ch in CHAPTERS:
		if sect.story_done.has(ch.id) or day < ch.day: continue
		sect.story_done.append(ch.id)
		log.call("[color=gold]【เนื้อเรื่อง】 %s[/color] — %s" % [ch.title, ch.text])
		if ch.has("auto"): log.call(_apply(sect, ch.auto))
		# บทนำ/บทที่มีตัวเลือก จะเด้งหน้าต่างให้ผู้เล่นอ่าน/เลือก
		sect.pending_story = { "id": ch.id }
		return

static func get_chapter(id: String) -> Dictionary:
	for ch in CHAPTERS:
		if ch.id == id: return ch
	return {}

## ผู้เล่นเลือกตัวเลือก index (บทที่ไม่มีตัวเลือก = รับทราบ)
static func choose(sect: SectData, index: int) -> String:
	var ch = get_chapter(sect.pending_story.get("id", ""))
	sect.pending_story = {}
	if ch.is_empty() or ch.options.is_empty() or index < 0: return ""
	var opt = ch.options[index]
	if sect.money < opt.get("cost", 0): return "เงินไม่พอ จึงทำตามที่เลือกไม่ได้"
	sect.money -= opt.get("cost", 0)
	var text = _apply(sect, opt.effect)
	sect.log_event(sect.current_day, "[color=gold]【เนื้อเรื่อง】 %s: เลือก '%s'[/color] %s" % [ch.title, opt.text, text])
	return text

static func _bloc_rel(sect: SectData, bloc: String, delta: int) -> void:
	for f in FactionDB.members_of(bloc): FactionSys.change_rel(sect, "player", f, delta)

static func _apply(sect: SectData, effect: String) -> String:
	var f = sect.factions
	match effect:
		"register_yes":
			_bloc_rel(sect, "eunuch", 15)
			_bloc_rel(sect, "righteous", -5)
			return "สำนักได้รับการรับรองจากราชสำนัก"
		"register_no":
			_bloc_rel(sect, "eunuch", -15)
			_bloc_rel(sect, "righteous", 5)
			return "หน่วยเหยี่ยวเงาเริ่มจับตาสำนักเรา"
		"lotus_attack":
			f.f_hidden_council.power = int(f.f_hidden_council.power * 0.7)
			f.f_blood_lotus.power = int(f.f_blood_lotus.power * 1.1)
			FactionSys.change_rel(sect, "f_blood_lotus", "f_hidden_council", -40)
			return "สภามังกรเร้นสูญเสียกำลังไปเกือบหนึ่งในสาม"
		"lotus_help":
			_bloc_rel(sect, "righteous", 8)
			FactionSys.change_rel(sect, "player", "f_blood_lotus", -25)
			f.f_hidden_council.power = int(f.f_hidden_council.power * 1.2)
			sect.prestige += 20
			ReputationSys.add_alignment(sect, 12)
			return "สภามังกรเร้นจดจำบุญคุณของสำนักเรา"
		"take_cursed_sword":
			sect.equipment_storage.append(EquipmentDB.make_cursed_sword())
			sect.prestige += 15
			ReputationSys.add_alignment(sect, -20)
			return "ได้ครอบครอง %s (ยุทธภพเริ่มหมายตาสำนักเรา)" % EquipmentDB.CURSED_SWORD
		"north_war":
			FactionSys.change_rel(sect, "f_steppe", "f_lei", -100)
			FactionSys.change_rel(sect, "f_steppe", "f_ming", -60)
			f.f_steppe.power = int(f.f_steppe.power * 1.1)
			f.f_lei.power = int(f.f_lei.power * 0.92)
			return "ชายแดนเหนือกลายเป็นสมรภูมิ (ตระกูลป้อมอัสนีอ่อนกำลัง)"
		"tournament_join":
			var best: DiscipleData = null
			for d in sect.get_active_disciples():
				if d.can_fight() and (best == null or d.get_power_rating() > best.get_power_rating()): best = d
			if best == null: return "ไม่มีศิษย์ที่พร้อมประลอง"
			var bar = StatSys.world_threat(sect.current_day) * 2.5
			var roll = best.get_power_rating() * randf_range(0.75, 1.3)
			if roll >= bar:
				sect.money += 2000
				sect.prestige += 60
				best.add_fame(100)
				return "%s คว้าแชมป์งานประลองยุทธ์หลวง! ได้รางวัล 2000 เงิน ชื่อเสียงสะเทือนแผ่นดิน" % best.disciple_name
			best.add_fame(25)
			sect.prestige += 10
			return "%s ผ่านเข้ารอบลึก แต่พ่ายให้ยอดฝีมือจากสำนักใหญ่ (พลังที่ต้องเอาชนะ ~%d)" % [best.disciple_name, bar]
		"azure_reveal":
			f.f_azure_dragon.power = int(f.f_azure_dragon.power * 1.15)
			for r in FactionDB.members_of("righteous"): FactionSys.change_rel(sect, r, "f_eunuchs", -20)
			return "ความไม่ไว้ใจระหว่างฝ่ายธรรมะกับสิบขันทีพุ่งสูงขึ้น"
		"sunset_war":
			FactionSys.change_rel(sect, "f_sunset", "f_baiyun", -100)
			f.f_sunset.power = int(f.f_sunset.power * 1.1)
			return "สงครามธรรมะ-อธรรมปะทุขึ้นทั่วแผ่นดิน"
		"join_alliance":
			if not f.f_sunset.war: FactionSys.declare_war(sect, "f_sunset")
			_bloc_rel(sect, "righteous", 15)
			ReputationSys.add_alignment(sect, 8)
			return "สำนักเราประกาศร่วมรบกับพันธมิตรยุทธภพ"
		"stay_neutral":
			FactionSys.change_rel(sect, "player", "f_sunset", 10)
			_bloc_rel(sect, "righteous", -5)
			return "พันธมิตรยุทธภพผิดหวังในตัวสำนักเรา"
		"dynasty_revolt":
			f.f_court.power = int(f.f_court.power * 0.85)
			FactionSys.change_rel(sect, "f_beiliang", "f_court", -100)
			FactionSys.change_rel(sect, "f_xuancheng", "f_court", -100)
			return "กองทัพหลวงสูญเสียหนัก"
		"back_eunuchs":
			EndingSys.note_throne(sect, "eunuch")
			_bloc_rel(sect, "eunuch", 30)
			_bloc_rel(sect, "righteous", -20)
			ReputationSys.add_alignment(sect, -10)
			return "สิบขันทีจดจำความภักดีของสำนักเรา"
		"back_prince":
			EndingSys.note_throne(sect, "prince")
			_bloc_rel(sect, "eunuch", -30)
			_bloc_rel(sect, "righteous", 15)
			sect.prestige += 40
			ReputationSys.add_alignment(sect, 12)
			return "องค์ชายสี่และสำนักศึกษาหลวงยกย่องสำนักเรา แต่หน่วยเหยี่ยวชาดเริ่มล่าตัว"
	return ""
