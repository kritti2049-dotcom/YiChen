extends RefCounted
class_name WorkDB

## ทักษะงาน (Skills) ของศิษย์ — ผลผลิตของตึกคำนวณจากทักษะของศิษย์ที่ประจำ (ดู ProductionSys / BuildingDB.POSTS)
## ทักษะงานโตจากการทำงานจริง (0-20) และมีความหลงใหล (Passion) 0/1/2 ต่อทักษะ

## ทักษะงาน: stat = ค่ารากฐานที่ใช้ตั้งระดับเริ่มต้น
const SKILLS = {
	"melee": { "name": "ต่อสู้ระยะประชิด", "stat": "str" },
	"shooting": { "name": "อาวุธลับ/ยิงไกล", "stat": "agi" },
	"construction": { "name": "ก่อสร้าง", "stat": "str" },
	"mining": { "name": "ขุดเหมือง", "stat": "vit" },
	"plants": { "name": "เพาะปลูก", "stat": "gathering" },
	"cooking": { "name": "ทำอาหาร", "stat": "cooking" },
	"alchemy": { "name": "หลอมยา", "stat": "alchemy" },
	"medicine": { "name": "แพทย์", "stat": "medicine" },
	"crafting": { "name": "ตีอาวุธ", "stat": "forging" },
	"intellect": { "name": "วิจัยคัมภีร์", "stat": "comprehension" },
	"social": { "name": "เจรจา", "stat": "charisma" },
	"martial": { "name": "ฝึกยุทธ์", "stat": "aptitude" },
}
const MAX_SKILL = 20.0
const PASSION_NAMES = ["", "ชอบ", "หลงใหล"]
## ตัวคูณการเรียนรู้ตามความหลงใหล (ไม่ชอบ / ชอบ / หลงใหล)
const PASSION_LEARN = [0.35, 1.0, 1.5]
## XP ที่ต้องใช้ต่อ 1 ระดับ
const XP_PER_LEVEL = 100.0
