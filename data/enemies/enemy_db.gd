extends Node
class_name EnemyDB

## ศัตรูทุกตัวใช้สเกลค่าพลังเดียวกับศิษย์ (StatSys): รากฐาน (pot) x ตัวคูณขั้นบำเพ็ญ (level) + อาวุธ (gear)
## pot = [ความแข็งแกร่ง, ความทนทาน, ความว่องไว] (1-10), gear = ค่าบวกพลังโจมตีจากอาวุธ/เขี้ยวเล็บ
## drops: { "material_id": [จำนวนต่ำสุด, จำนวนสูงสุด] } สุ่มดรอปเมื่อชนะ

const ENEMIES = {
	# ── ทั่วไป ──
	"bandit_thug": {
		"art": "human", "color": Color(0.4, 0.3, 0.2), "name": "โจรป่าลูกกระจ๊อก",
		"level": 1, "pot": [3, 3, 3], "gear": 1,
		"reward_money": 60, "reward_food": 20, "reward_exp": 60, "drops": { "iron_ore": [0, 3] },
	},
	"forest_wolf": {
		"art": "wolf", "color": Color(0.45, 0.55, 0.4), "name": "หมาป่าพฤกษาอสูร",
		"level": 2, "pot": [4, 3, 5], "gear": 1,
		"reward_money": 40, "reward_food": 100, "reward_exp": 90, "drops": { "beast_hide": [1, 3], "spirit_grass": [0, 3] },
	},
	"mountain_bandit": {
		"art": "human", "color": Color(0.35, 0.32, 0.3), "name": "โจรภูเขา",
		"level": 3, "pot": [4, 4, 3], "gear": 2,
		"reward_money": 110, "reward_food": 30, "reward_exp": 120, "drops": { "iron_ore": [1, 3], "wood": [2, 5] },
	},
	"rock_ape": {
		"art": "ape", "color": Color(0.5, 0.48, 0.45), "name": "ลิงศิลาเฝ้าถ้ำ",
		"level": 5, "pot": [5, 6, 2], "gear": 2,
		"reward_money": 120, "reward_food": 60, "reward_exp": 220, "drops": { "iron_ore": [2, 5], "cold_iron": [0, 1], "spirit_stone": [0, 1] },
	},
	"rival_swordsman": {
		"art": "human", "color": Color(0.15, 0.15, 0.2), "name": "ศิษย์สำนักเจ็ดสังหาร",
		"level": 8, "pot": [5, 4, 5], "gear": 3,
		"reward_money": 250, "reward_food": 20, "reward_exp": 380, "drops": { "cold_iron": [0, 2], "spirit_stone": [0, 2], "scripture_fragment": [0, 1] },
	},
	"rival_elder": {
		"art": "human", "color": Color(0.35, 0.3, 0.45), "name": "ผู้อาวุโสสำนักนอกรีต", "status_attack": "seal",
		"level": 15, "pot": [6, 6, 5], "gear": 6,
		"reward_money": 1000, "reward_food": 100, "reward_exp": 1300, "drops": { "beast_core": [0, 2], "star_metal": [0, 1], "spirit_stone": [1, 3], "scripture_fragment": [0, 2] },
	},
	# ── ฝ่ายมาร / ดินแดนร้อยพิษแดนใต้ ──
	"demon_sect_disciple": {
		"art": "human", "color": Color(0.5, 0.1, 0.12), "name": "ศิษย์พรรคมารอัสดง", "status_attack": "poison",
		"level": 6, "pot": [5, 4, 4], "gear": 2,
		"reward_money": 300, "reward_food": 50, "reward_exp": 300, "drops": { "blood_ginseng": [0, 2], "spirit_stone": [0, 2] },
	},
	"demon_elder": {
		"art": "human", "color": Color(0.3, 0.05, 0.1), "name": "ผู้อาวุโสพรรคมาร (ขั้นสร้างรากฐาน)", "status_attack": "gu",
		"level": 12, "pot": [6, 5, 5], "gear": 5,
		"reward_money": 900, "reward_food": 100, "reward_exp": 900, "drops": { "beast_core": [1, 2], "blood_ginseng": [1, 3], "scripture_fragment": [0, 1] },
	},
	"poison_disciple": {
		"art": "human", "color": Color(0.25, 0.45, 0.2), "name": "นักรบร้อยเผ่าแดนใต้", "status_attack": "gu",
		"level": 7, "pot": [4, 4, 6], "gear": 2,
		"reward_money": 220, "reward_food": 30, "reward_exp": 340, "drops": { "blood_ginseng": [0, 2], "spirit_grass": [2, 5] },
	},
	"gu_serpent": {
		"art": "wolf", "color": Color(0.3, 0.6, 0.25), "name": "อสรพิษกู่ดึกดำบรรพ์", "status_attack": "gu",
		"level": 10, "pot": [5, 6, 6], "gear": 4,
		"reward_money": 300, "reward_food": 80, "reward_exp": 650, "drops": { "beast_core": [0, 2], "blood_ginseng": [1, 2] },
	},
	"blood_spider": {
		"art": "human", "color": Color(0.45, 0.05, 0.15), "name": "นักฆ่าเผ่าแมงมุมโลหิต", "status_attack": "gu",
		"level": 11, "pot": [5, 4, 7], "gear": 5,
		"reward_money": 600, "reward_food": 20, "reward_exp": 800, "drops": { "blood_ginseng": [1, 2], "scripture_fragment": [0, 1] },
	},
	"blood_lotus_cultist": {
		"art": "human", "color": Color(0.75, 0.15, 0.3), "name": "สาวกลัทธิบัวโลหิต", "status_attack": "poison",
		"level": 8, "pot": [5, 4, 5], "gear": 3,
		"reward_money": 260, "reward_food": 20, "reward_exp": 420, "drops": { "blood_ginseng": [0, 2], "scripture_fragment": [0, 1] },
	},
	# ── ทุ่งหญ้าแดนอุดร / ภูเขาหิมะ ──
	"steppe_raider": {
		"art": "human", "color": Color(0.55, 0.42, 0.3), "name": "นักรบม้าทุ่งหญ้าอุดร",
		"level": 7, "pot": [6, 5, 4], "gear": 3,
		"reward_money": 240, "reward_food": 120, "reward_exp": 360, "drops": { "beast_hide": [1, 3], "iron_ore": [0, 2] },
	},
	"snow_wolf_king": {
		"art": "wolf", "color": Color(0.85, 0.88, 0.95), "name": "ราชาหมาป่าหิมะ", "status_attack": "seal",
		"level": 14, "pot": [6, 5, 7], "gear": 5,
		"reward_money": 600, "reward_food": 300, "reward_exp": 1200, "drops": { "beast_core": [1, 3], "snow_lotus": [0, 1], "star_metal": [0, 1] },
	},
	"xuancheng_guard": {
		"art": "ape", "color": Color(0.55, 0.6, 0.75), "name": "ผู้พิทักษ์นครใต้ดินเสวียน", "status_attack": "seal",
		"level": 17, "pot": [7, 7, 4], "gear": 7,
		"reward_money": 900, "reward_food": 50, "reward_exp": 1600, "drops": { "star_metal": [0, 2], "cold_iron": [1, 3], "scripture_fragment": [0, 2] },
	},
	# ── แดนรกร้างตะวันตก ──
	"sand_bandit": {
		"art": "human", "color": Color(0.75, 0.62, 0.38), "name": "โจรทะเลทราย",
		"level": 4, "pot": [4, 4, 5], "gear": 2,
		"reward_money": 160, "reward_food": 20, "reward_exp": 170, "drops": { "spirit_stone": [0, 1], "iron_ore": [0, 2] },
	},
	"fire_cultist": {
		"art": "human", "color": Color(0.85, 0.35, 0.1), "name": "นักพรตเพลิงนิกายซวนหยวน",
		"level": 10, "pot": [6, 4, 5], "gear": 4,
		"reward_money": 450, "reward_food": 20, "reward_exp": 700, "drops": { "star_metal": [0, 1], "spirit_stone": [1, 2], "scripture_fragment": [0, 1] },
	},
	# ── ทะเลบูรพา ──
	"pirate": {
		"art": "human", "color": Color(0.2, 0.3, 0.45), "name": "โจรสลัดพันธมิตรทะเลบูรพา",
		"level": 5, "pot": [5, 4, 4], "gear": 2,
		"reward_money": 260, "reward_food": 60, "reward_exp": 240, "drops": { "spirit_stone": [0, 2], "cold_iron": [0, 1] },
	},
	"pirate_captain": {
		"art": "human", "color": Color(0.1, 0.15, 0.3), "name": "กัปตันโจรสลัดวายุคลั่ง",
		"level": 12, "pot": [6, 6, 5], "gear": 6,
		"reward_money": 1100, "reward_food": 100, "reward_exp": 950, "drops": { "star_metal": [0, 1], "beast_core": [0, 1], "scripture_fragment": [0, 1] },
	},
	# ── ราชสำนัก ──
	"hawk_guard": {
		"art": "human", "color": Color(0.7, 0.12, 0.1), "name": "องครักษ์หน่วยเหยี่ยวชาด", "status_attack": "seal",
		"level": 13, "pot": [6, 5, 6], "gear": 6,
		"reward_money": 800, "reward_food": 30, "reward_exp": 1000, "drops": { "cold_iron": [1, 2], "spirit_stone": [1, 2] },
	},
}

static func get_enemy(id: String) -> Dictionary:
	if not ENEMIES.has(id): return {}
	var e = ENEMIES[id].duplicate(true)
	e["id"] = id
	var p: Array = e.pot
	var c = StatSys.derive_combat({ "str": p[0], "vit": p[1], "agi": p[2], "movement_arts": p[2], "defense_arts": p[1] }, RealmDB.multiplier(e.level), { "atk": e.get("gear", 0) })
	e["max_hp"] = c.hp.total
	e["attack"] = c.atk.total
	e["defense"] = c.def.total
	e["speed"] = c.spd.total
	e["hp"] = e["max_hp"] # เลือดปัจจุบัน
	return e

## พลังรบรวมของศัตรู (ไว้แสดงบนแผนที่)
static func get_power(id: String) -> int:
	var e = get_enemy(id)
	if e.is_empty(): return 0
	return StatSys.combat_power(e.attack, e.max_hp, e.speed, 0, 0)

## Texture ของศัตรู (วาดด้วยโค้ด ดู ArtGen)
static func get_texture(enemy: Dictionary) -> Texture2D:
	var color: Color = enemy.get("color", Color(0.4, 0.4, 0.4))
	match enemy.get("art", "human"):
		"wolf": return ArtGen.get_beast("wolf", color)
		"ape": return ArtGen.get_beast("ape", color)
	return ArtGen.get_human_enemy(enemy.get("id", "x"), color)

## สุ่มของดรอปจากศัตรู 1 ตัว (โชคชะตา 1-10 เพิ่มโอกาสได้ของเพิ่ม)
static func roll_drops(enemy: Dictionary, luck: int = 3) -> Dictionary:
	var result = {}
	var drops: Dictionary = enemy.get("drops", {})
	for mat in drops:
		var amount = randi_range(drops[mat][0], drops[mat][1])
		if amount > 0 and randf() < luck * 0.04:
			amount += 1
		if amount > 0:
			result[mat] = amount
	return result
