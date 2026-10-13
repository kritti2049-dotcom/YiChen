extends RefCounted
class_name BehaviorTraitDB

## ลักษณะนิสัยด้านพฤติกรรม (แต่ละคนมี 2-3 อย่าง) แยกจากพรสวรรค์ค่าพลัง (TraitDB)
## kind: great (ดีมาก) / context (เชิงบริบท) / risky (เสี่ยง) / social (สังคม) / bad (ข้อเสีย)
## effects:
##   learn = ตัวคูณการเรียนรู้ทักษะ, no_decay = ทักษะไม่เสื่อม, work_speed = ตัวคูณความเร็วทำงาน
##   stress = ตัวคูณความเครียดที่เพิ่มต่อรอบ (ธาตุไฟแตกซ่านง่าย/ยาก), base_mood = ปรับค่าฐานอารมณ์
##   insult = โอกาสด่าทอตอนคุย, kind = ใจดี (พูดดี)
##   hunger = ตัวคูณความหิว, social = ตัวคูณการเข้าสังคม
##   violent = ชอบความรุนแรง (ชนะศึกอารมณ์ดีขึ้น วิวาทง่าย), blood_cult = ฝึกมารกินเลือด
## exclusive = นิสัยที่มีพร้อมกันไม่ได้

const TRAITS = {
	"fast_learner": { "name": "เรียนรู้ไว", "kind": "great", "desc": "ทักษะงานโตเร็ว และไม่เสื่อมแม้ไม่ได้ใช้", "effects": { "learn": 1.75, "no_decay": true } },
	"industrious": { "name": "ขยันไม่รู้เหนื่อย", "kind": "great", "desc": "ทำงานเร็วขึ้นมาก", "effects": { "work_speed": 1.35 }, "exclusive": ["lazy"] },
	"iron_will": { "name": "จิตใจเหล็ก", "kind": "great", "desc": "เครียดยาก ธาตุไฟแตกซ่านยากมาก", "effects": { "stress": 0.6 }, "exclusive": ["volatile"] },
	"cheerful": { "name": "ร่าเริงแจ่มใส", "kind": "great", "desc": "อารมณ์ดีเป็นทุนเดิม", "effects": { "base_mood": 8 }, "exclusive": ["gloomy"] },
	"blood_cultivator": { "name": "ฝึกมารกินเลือด", "kind": "context", "desc": "ทนความหิวได้ดีและไม่ขยะแขยงศพ แต่ขัดกับวิถีเจริญสติ", "effects": { "hunger": 0.7, "blood_cult": true } },
	"loner": { "name": "สันโดษ", "kind": "context", "desc": "ไม่ค่อยเข้าสังคม ไม่เบื่อง่ายเมื่ออยู่คนเดียว", "effects": { "social": 0.3 } },
	"workaholic": { "name": "บ้างาน", "kind": "risky", "desc": "ทำงานเร็วขึ้นแต่สะสมความเครียดไวกว่าปกติ", "effects": { "work_speed": 1.2, "stress": 1.3 } },
	"gourmand": { "name": "ตะกละ", "kind": "risky", "desc": "หิวบ่อย กินเสบียงมากกว่าคนอื่น", "effects": { "hunger": 1.4 } },
	"volatile": { "name": "อารมณ์อ่อนไหว", "kind": "risky", "desc": "เครียดง่าย ธาตุไฟแตกซ่านง่าย", "effects": { "stress": 1.5 }, "exclusive": ["iron_will"] },
	"abrasive": { "name": "ปากร้าย", "kind": "social", "desc": "ชอบพูดจาทิ่มแทง คนรอบข้างไม่ค่อยชอบ", "effects": { "insult": 0.25 }, "exclusive": ["kind"] },
	"kind": { "name": "ใจดี", "kind": "social", "desc": "ไม่เคยด่าใคร พูดจาให้กำลังใจคนอื่น", "effects": { "kind": true }, "exclusive": ["abrasive"] },
	"bloodlust": { "name": "รักความรุนแรง", "kind": "social", "desc": "ชอบการต่อสู้ วิวาทง่าย", "effects": { "violent": true, "insult": 0.08 } },
	"bigot": { "name": "หยิ่งยโสดูถูกคน", "kind": "social", "desc": "ดูถูกศิษย์ที่ด้อยกว่า สะสมความเกลียดชัง", "effects": { "insult": 0.15 } },
	"lazy": { "name": "ขี้เกียจ", "kind": "bad", "desc": "ทำงานช้า ชอบพักผ่อน", "effects": { "work_speed": 0.75 }, "exclusive": ["industrious"] },
	"gloomy": { "name": "มองโลกแง่ร้าย", "kind": "bad", "desc": "อารมณ์หม่นหมองเป็นทุนเดิม", "effects": { "base_mood": -8 }, "exclusive": ["cheerful"] },
	"sleepyhead": { "name": "ขี้เซา", "kind": "bad", "desc": "ง่วงเร็วกว่าคนอื่น", "effects": { "rest": 1.4 } },
}

static func get_trait(id: String) -> Dictionary:
	return TRAITS.get(id, {})

## ผลรวมแบบบวก (base_mood / insult)
static func sum(traits: Array, key: String) -> float:
	var total = 0.0
	for t in traits:
		total += float(TRAITS.get(t, {}).get("effects", {}).get(key, 0.0))
	return total

## ผลคูณ (learn / work_speed / hunger / social / rest / stress)
static func mult(traits: Array, key: String) -> float:
	var total = 1.0
	for t in traits:
		total *= float(TRAITS.get(t, {}).get("effects", {}).get(key, 1.0))
	return total

static func has_flag(traits: Array, key: String) -> bool:
	for t in traits:
		if TRAITS.get(t, {}).get("effects", {}).get(key, false) == true: return true
	return false

## สุ่มนิสัย 2-3 อย่างที่ไม่ขัดกัน
static func roll() -> Array[String]:
	var ids = TRAITS.keys()
	ids.shuffle()
	var count = randi_range(2, 3)
	var result: Array[String] = []
	for t in ids:
		if result.size() >= count: break
		var excl: Array = TRAITS[t].get("exclusive", [])
		if result.any(func(r): return excl.has(r) or TRAITS[r].get("exclusive", []).has(t)): continue
		result.append(t)
	return result
