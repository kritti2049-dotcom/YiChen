extends RefCounted
class_name StorytellerDB

## เจตจำนงสวรรค์ (AI Storyteller): ผู้กำกับเรื่องราว 3 แบบ ให้ผู้เล่นเลือกตอนเริ่ม
## gap = ช่วงห่างระหว่างเหตุการณ์ (วัน), threat_mult = ตัวคูณภัย, threat_jitter = ความผันผวนของภัย
## big_after = ฟ้าเมตตา: ถ้าสงบนานเกินกี่วัน ภัยครั้งถัดไปแรงขึ้น

const STORYTELLERS = {
	"wrath": { "name": "สวรรค์พิโรธ", "style": "ความยากไต่เป็นระบบ", "desc": "ภัยมาสม่ำเสมอและแรงขึ้นเรื่อยๆ ลงโทษการสะสมความมั่งคั่ง",
		"gap": [4, 6], "threat_mult": 1.0, "threat_jitter": 0.1, "wealth_weight": 1.15, "big_after": 0 },
	"mercy": { "name": "ฟ้าเมตตา", "style": "สงบนาน ระเบิดหนัก", "desc": "เว้นช่วงนานล่อให้ประมาท แล้วภัยใหญ่จะมาเยือน",
		"gap": [9, 15], "threat_mult": 1.0, "threat_jitter": 0.15, "wealth_weight": 1.0, "big_after": 12 },
	"chaos": { "name": "ลิขิตฟ้าผันผวน", "style": "สุ่มล้วน", "desc": "ไม่สนความยาก บางครั้งโหดสุดขั้ว บางครั้งว่างเปล่า",
		"gap": [1, 14], "threat_mult": 1.0, "threat_jitter": 0.85, "wealth_weight": 0.6, "big_after": 0 },
}

## ราคาศัตรูในหน่วยคะแนนภัย (ใช้ซื้อศัตรูจนคะแนนหมด) min_threat = ปรากฏได้เมื่อคะแนนภัยถึง
const RAID_POOL = [
	{ "enemy": "bandit_thug", "cost": 40, "min_threat": 0, "tag": "bandit" },
	{ "enemy": "mountain_bandit", "cost": 55, "min_threat": 0, "tag": "bandit" },
	{ "enemy": "forest_wolf", "cost": 45, "min_threat": 0, "tag": "beast" },
	{ "enemy": "rock_ape", "cost": 70, "min_threat": 150, "tag": "beast" },
	{ "enemy": "hawk_guard", "cost": 90, "min_threat": 250, "tag": "hawk" },
	{ "enemy": "blood_lotus_cultist", "cost": 110, "min_threat": 300, "tag": "cult" },
	{ "enemy": "demon_elder", "cost": 220, "min_threat": 600, "tag": "cult" },
	{ "enemy": "rival_elder", "cost": 260, "min_threat": 800, "tag": "cult" },
	{ "enemy": "pirate_captain", "cost": 300, "min_threat": 1000, "tag": "dragon" },
	{ "enemy": "xuancheng_guard", "cost": 420, "min_threat": 1600, "tag": "dragon" },
]
## สัตว์อสูรใต้ดิน (ปลุกจากการขุดเหมืองลึก)
const UNDERGROUND_POOL = [
	{ "enemy": "gu_serpent", "cost": 120, "min_threat": 0, "tag": "underground" },
	{ "enemy": "rock_ape", "cost": 70, "min_threat": 0, "tag": "underground" },
]

const HARD_CAP = 10000.0
const PAWN_VALUE = 420
const MAX_RAIDERS = 8

static func get_teller(id: String) -> Dictionary:
	return STORYTELLERS.get(id, STORYTELLERS.wrath)
