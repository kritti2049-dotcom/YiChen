extends Node
class_name NPCGenerator

const SURNAMES = ["หวัง", "หลี่", "จาง", "หลิว", "เฉิน", "หยาง", "จ้าว", "หวง", "โจว", "อู๋", "หลิน", "เย่", "เซียว", "ฟาง", "ต้วน", "ซุน", "หม่า", "จู", "หู", "กัว"]
const FIRST_NAMES = ["ต้า", "ชิง", "เฟิง", "หลง", "หู่", "เทียน", "อวิ๋น", "ซาน", "ไห่", "หมิง", "เจี้ยน", "กัง", "หรง", "เหริน", "เล่ย", "ปิง", "เซียน", "ฮ่าว", "เจ๋อ", "ข่าย"]
const FEMALE_NAMES = ["อวี่", "หยิน", "เยว่", "ซิง", "ซู", "เสวี่ย", "ฮวา", "หลิง", "เหยียน", "เม่ย", "ฉิน", "หลัน", "จิง", "อิง", "ถิง", "ลี่", "หรู", "ซิน", "เหวิน", "เฟย"]

const TIER_NAMES = ["ธรรมดา", "หายาก", "ตำนาน"]

## โอกาสที่ NPC จะเกิดเป็น "จอมยุทธ์พเนจร" (ระดับสูงกว่าปกติ + มีวิชาขั้นสูงติดตัว)
const WANDERER_CHANCE = 0.08

## สร้าง NPC แบบสุ่ม
## tier: 0 = ทั่วไป, 1 = หายาก, 2 = ตำนาน
## level: ระดับเริ่มต้น (1-81)
static func generate_npc(tier: int = 0, level: int = 1) -> DiscipleData:
	var npc = DiscipleData.new()
	var is_wanderer = randf() < WANDERER_CHANCE
	if is_wanderer:
		level += randi_range(6, 12)

	# 1. ตัวตน: เพศ เผ่า ชื่อ รูปหน้า
	npc.gender = ["ชาย", "หญิง"].pick_random()
	npc.race = BackgroundDB.roll_race()
	var names = FEMALE_NAMES if npc.gender == "หญิง" else FIRST_NAMES
	npc.disciple_name = SURNAMES.pick_random() + names.pick_random()
	npc.portrait_seed = randi() % 1000000 + 1
	npc.element = CultivationSys.ELEMENT_COLORS.keys().pick_random()
	npc.age = randi_range(14, 25) + (randi_range(10, 30) if is_wanderer else 0)

	# 2. สุ่มค่ารากฐาน 28 ค่า (บันทึกที่มาทุกรายการ) คนธรรมดา 1-5, พรสวรรค์หายาก/ตำนาน +1/+2
	roll_base_stats(npc)
	if tier > 0:
		for key in StatSys.STATS_DEF:
			npc.add_stat(key, tier, "ระดับพรสวรรค์ (%s)" % TIER_NAMES[tier])
	var race_bonus: Dictionary = BackgroundDB.RACES[npc.race].bonus
	for key in race_bonus:
		npc.add_stat(key, race_bonus[key], "สายเลือด%s" % npc.race)

	# 3. สุ่ม Traits (120 แบบ) และใส่ผลของพรสวรรค์ลงค่ารากฐานจริง
	var num_traits = 1 + tier + (randi() % 2) # tier 0 ได้ 1-2, tier 2 ได้ 3-4 traits
	var all_traits = TraitDB.TRAITS.keys()
	all_traits.shuffle()
	var selected_traits = all_traits.slice(0, num_traits)
	npc.ext_traits.assign(selected_traits)
	# Copy Traits เก่าให้เข้ากัน (Personality traits ของเดิมเผื่อระบบเดิมเรียกใช้)
	npc.personality_traits.assign(selected_traits)
	for t in selected_traits:
		TraitDB.apply_trait_effects(npc, t)

	# 4. ขั้นบำเพ็ญ (ค่าพลังต่อสู้คูณตาม RealmDB เอง ไม่ต้องบวกโบนัสสะสม)
	npc.level = level
	npc.realm_name = CultivationSys.get_realm_info(level).name
	npc.experience = 0
	npc.stat_version = 2

	# ความเข้าใจและรากปราณ
	npc.comprehension = npc.get_stat("comprehension")
	npc.aptitude_root = npc.get_stat("aptitude")

	# 5. วิชาติดตัว (ยิ่งพรสวรรค์สูง/เป็นจอมยุทธ์ ยิ่งมีวิชาขั้นสูง) + ความชำนาญจากภูมิหลัง
	var skill_tiers: Array = []
	match tier:
		0: skill_tiers = [SkillDB.Tier.MORTAL] if randf() < 0.6 else []
		1: skill_tiers = [SkillDB.Tier.MORTAL, SkillDB.Tier.EARTH if randf() < 0.5 else SkillDB.Tier.MORTAL]
		2: skill_tiers = [SkillDB.Tier.EARTH, SkillDB.Tier.EARTH, SkillDB.Tier.HEAVEN if randf() < 0.4 else SkillDB.Tier.EARTH]
	if is_wanderer:
		skill_tiers.append(SkillDB.Tier.HEAVEN if randf() < 0.7 else SkillDB.Tier.IMMORTAL)
	for t in skill_tiers:
		var s = SkillDB.get_random_skill_by_tier(t)
		if s != "" and not npc.innate_skills.has(s):
			npc.innate_skills.append(s)
	npc.learned_skills.assign(npc.innate_skills)
	for s in npc.innate_skills:
		MasterySys.grant_background(npc, s)
		var t = MasterySys.skill_type(s)
		if t != "": npc.affinity_style = SkillDB.get_skill(s).type

	npc.background_story = BackgroundDB.generate_story(npc.race, is_wanderer)
	if is_wanderer:
		npc.ambition = "ค้นหาความหมายของวิถียุทธ์"

	npc.status = DiscipleData.DiscipleStatus.IDLE
	npc.hunger = 100
	npc.mood = 60
	# Component ของระบบจำลอง: ความต้องการ ทักษะงาน นิสัยพฤติกรรม ร่างกาย กายา วิถี ตารางงาน
	PawnSys.ensure(npc, null)

	return npc

## สุ่มค่ารากฐาน 28 ค่า (1-5) พร้อมบันทึกที่มา
static func roll_base_stats(d: DiscipleData) -> void:
	d.ext_stats = {}
	d.stat_sources = {}
	d.stat_version = 2
	for key in StatSys.STATS_DEF:
		d.add_stat(key, StatSys.roll_potential(), "รากฐานแต่กำเนิด (สุ่ม 1-5)")

## สุ่มลูกศิษย์ชุดแรกให้สำนัก (3 คน)
static func generate_starting_disciples() -> Array[DiscipleData]:
	var arr: Array[DiscipleData] = []
	arr.append(generate_npc(1, 5)) # ศิษย์พี่ (Rare, Level 5)
	arr.append(generate_npc(0, 2)) # ศิษย์น้อง (Common, Level 2)
	arr.append(generate_npc(0, 1)) # ศิษย์น้องใหม่ (Common, Level 1)
	return arr
