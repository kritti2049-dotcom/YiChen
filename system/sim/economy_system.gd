extends RefCounted
class_name EconomySystem

## เศรษฐกิจและจุดระบายทรัพยากร (Money Sinks) กันเงินเฟ้อและการกักตุน
## - ของเสื่อมตามเวลา: เสบียงดิบ 1%/วัน, อาหารปรุงสุก 5%/วัน
## - ค่าซ่อมบำรุงตึก: เงิน 2 ต่อระดับตึกต่อวัน
## - ไฟไหม้ลุกลามรายวันจนถึงขีดสุด = ตึกเสียหาย (ลดระดับ) ศิษย์ช่วยกันดับ: ศิษย์ว่างดับได้ดีกว่าศิษย์ที่ประจำงาน

const UPKEEP_PER_LEVEL = 2
const FIRE_GROWTH = 0.3
const FIRE_FIGHT_FREE = 0.12
const FIRE_FIGHT_BUSY = 0.04

static func daily(sect: SectData, mgr: SectManager) -> void:
	_tips(sect, mgr)
	# เสบียงล้นคลังเน่าเร็ว (เกิน 300 เสียวันละ 3%) และพ่อค้าซื้อส่วนเกินเกิน 25 ต่อศิษย์ในราคา 0.4/หน่วย
	var keep = 300
	if sect.food > keep:
		sect.food -= int((sect.food - keep) * 0.03)
		var pawns_n = maxi(1, sect.get_active_disciples().size())
		var surplus = sect.food - (200 + 25 * pawns_n)
		if surplus >= 50:
			sect.food -= surplus
			var gain = int(surplus * 0.4)
			sect.money += gain
			ProductionSys._stat(sect, "food_sold", surplus)
			if sect.current_day % 5 == 0: mgr.log_event("[color=#b0b0b0]ขายเสบียงส่วนเกิน %d ได้เงิน %d[/color]" % [surplus, gain])
	sect.food = int(sect.food * 0.99)
	var spoiled_meals = int(ceil(sect.meals * 0.05)) if sect.meals > 0 else 0
	sect.meals -= spoiled_meals
	sect.fine_meals = min(sect.fine_meals, sect.meals)
	var levels = 0
	for inst in sect.structures: levels += int(inst.level)
	sect.money -= levels * UPKEEP_PER_LEVEL
	if sect.money < 0:
		# ติดหนี้: ศิษย์เสียศรัทธา หนี้ไม่เกิน -500 (เจ้าหนี้ยึดของแทน)
		sect.money = maxi(sect.money, -500)
		for d in sect.get_active_disciples(): d.loyalty = maxf(0.0, d.loyalty - 1.5)
		if sect.current_day % 3 == 0: mgr.log_event("[color=red]คลังเงินติดลบ! ศิษย์เริ่มหมดศรัทธา — หารายได้หรือเลิกซ่อมตึกที่ไม่จำเป็น[/color]")
	if sect.current_day % 7 == 0:
		mgr.log_event("[color=#b0b0b0]สรุปสัปดาห์: ค่าซ่อมบำรุงตึก %d/วัน[/color]" % (levels * UPKEEP_PER_LEVEL))
	sect.tremor = max(0.0, sect.tremor - 0.05)
	if ProductionSys.food_shortage(sect):
		mgr.log_event("[color=orange]เสบียงใกล้หมด! ศิษย์อิสระจะออกหาของป่าช่วย — มอบหมายคนเข้าแปลงเกษตร/โรงครัวเพิ่ม[/color]")
	fire_daily(sect, mgr)

## ไฟลุกลามรายวัน
static func fire_daily(sect: SectData, mgr: SectManager) -> void:
	if sect.fires.is_empty(): return
	var fight = 0.0
	for d in ProductionSys.able(sect): fight += FIRE_FIGHT_FREE if d.post == "" else FIRE_FIGHT_BUSY
	var share = fight / sect.fires.size()
	for uid in sect.fires.keys():
		var inst = sect.instance(uid)
		if inst.is_empty():
			sect.fires.erase(uid)
			continue
		sect.fires[uid] += FIRE_GROWTH - share
		if sect.fires[uid] <= 0.0:
			sect.fires.erase(uid)
			mgr.log_event("[color=lime]ดับไฟที่%sได้สำเร็จ[/color]" % BuildingDB.inst_name(inst))
			continue
		if sect.fires[uid] < 1.0: continue
		sect.fires[uid] = 0.45
		inst.level = int(inst.level) - 1
		mgr.log_event("[color=red]ไฟเผา%sจนเสียหาย! ระดับลดลงเหลือ %d[/color]" % [BuildingDB.inst_name(inst), inst.level])
		if int(inst.level) <= 0 and inst.site.is_empty():
			sect.fires.erase(uid)
			sect.remove_structure(uid)
			sect.terrain_dirty = true
			continue
		# ลามไปตึกข้างเคียง
		if randf() < 0.3:
			var others = sect.structures.filter(func(o): return o.uid != uid and int(o.level) > 0 and not sect.fires.has(o.uid))
			if not others.is_empty():
				var o: Dictionary = others[randi() % others.size()]
				sect.fires[o.uid] = 0.2
				mgr.log_event("[color=red]ไฟลามไปถึง%s![/color]" % BuildingDB.inst_name(o))

## คำแนะนำช่วงต้นเกม (เป้าหมายแรกๆ) บอกทีละอย่างเมื่อยังไม่ทำ
static func _tips(sect: SectData, mgr: SectManager) -> void:
	var tip := ""
	match sect.current_day:
		1: tip = "เป้าหมายแรก: ① วางแปลงเกษตรและเรือนนอน (เมนู สร้างตึก / วางผัง) ② มอบหมายศิษย์เข้าตึก ③ ลากสั่งตัดไม้/ทุบหินได้ทุกที่ (เมนู สั่งงานบนแผนที่)"
		3:
			if sect.instances("farm").is_empty(): tip = "เสบียงจะหมดถ้าไม่มีแปลงเกษตร — สร้างแปลงเกษตรแล้วมอบหมายศิษย์เข้าทำงาน"
		6:
			if sect.instances("dormitory").is_empty(): tip = "ศิษย์นอนกลางแจ้งจะล้าสะสม — สร้างเรือนนอน"
		10: tip = "เมื่อชื่อเสียงสูงขึ้นจะมีผู้สมัครมาที่ประตู และโจรจะหมายตาทรัพย์ — สร้างหอยาม/ค่ายกลไว้ก่อน"
	if tip != "": mgr.log_event("[color=#ffe9a8]คำแนะนำ: %s[/color]" % tip)
