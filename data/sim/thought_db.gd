extends RefCounted
class_name ThoughtDB

## ความคิด (Thoughts) ที่ประกอบเป็นอารมณ์: อารมณ์เป้าหมาย = ค่าฐาน + ผลรวมของความคิดที่ยังไม่หมดอายุ
## days = อายุของความคิดแบบความทรงจำ (0 = ความคิดตามสถานการณ์ ถูกคำนวณใหม่ทุกครั้ง)
## stack = ซ้อนได้กี่ครั้ง (ซ้อนแล้วผลลดลงครึ่งหนึ่งต่อครั้ง)

const BASE_MOOD = 50.0

const THOUGHTS = {
	# ── ความต้องการ (ตามสถานการณ์) ──
	"hungry": { "name": "หิว", "value": -6, "days": 0 },
	"ravenous": { "name": "หิวโหยมาก", "value": -12, "days": 0 },
	"starving": { "name": "อดอยาก", "value": -22, "days": 0 },
	"tired": { "name": "ง่วงนอน", "value": -5, "days": 0 },
	"exhausted": { "name": "เหนื่อยล้าจนจะขาดใจ", "value": -12, "days": 0 },
	"qi_lacking": { "name": "ปราณพร่อง (ไม่ได้ฝึกตน)", "value": -5, "days": 0 },
	"bored": { "name": "เบื่อหน่าย", "value": -5, "days": 0 },
	"joyful": { "name": "สุขใจ", "value": 4, "days": 0 },
	"darkness": { "name": "อยู่ในความมืด", "value": -2, "days": 0 },
	"filthy": { "name": "อยู่ในที่สกปรก", "value": -3, "days": 0 },
	"fire_in_sect": { "name": "ไฟไหม้สำนัก!", "value": -4, "days": 0 },
	"in_pain": { "name": "เจ็บปวด", "value": -6, "days": 0 },
	"crippled": { "name": "พิการ", "value": -8, "days": 0 },
	"passion_work": { "name": "ได้ทำงานที่รัก", "value": 3, "days": 0 },
	"beautiful_room": { "name": "เรือนนอนสวยงาม", "value": 3, "days": 0 },
	"sect_glory": { "name": "ภูมิใจในสำนักที่รุ่งเรือง", "value": 3, "days": 0 },
	"sick": { "name": "ไม่สบาย", "value": -5, "days": 0 },
	"low_expectations": { "name": "ความคาดหวังต่ำ (สำนักยังเล็ก)", "value": 12, "days": 0 },
	"modest_expectations": { "name": "ความคาดหวังปานกลาง", "value": 6, "days": 0 },
	"high_expectations": { "name": "ความคาดหวังสูง (สำนักร่ำรวย)", "value": 0, "days": 0 },
	# ── ความทรงจำ (มีวันหมดอายุ) ──
	"fine_meal": { "name": "ได้กินอาหารชั้นเลิศ", "value": 4, "days": 0.5 },
	"raw_food": { "name": "จำใจกินเสบียงดิบ", "value": -3, "days": 0.5 },
	"slept_well": { "name": "หลับสบายในห้องดี", "value": 3, "days": 1 },
	"slept_outside": { "name": "นอนกลางแจ้ง", "value": -4, "days": 1 },
	"saw_corpse": { "name": "เห็นศพ", "value": -5, "days": 3, "stack": 3 },
	"friend_died": { "name": "สหายสนิทเสียชีวิต", "value": -15, "days": 10, "stack": 3 },
	"lover_died": { "name": "คนรักเสียชีวิต", "value": -25, "days": 20 },
	"insulted": { "name": "ถูกด่าทอ", "value": -5, "days": 2, "stack": 3 },
	"good_chat": { "name": "คุยกันถูกคอ", "value": 2, "days": 1, "stack": 3 },
	"wedding_guest": { "name": "ร่วมงานมงคลสมรส", "value": 8, "days": 3 },
	"married": { "name": "เพิ่งแต่งงาน", "value": 14, "days": 10 },
	"new_lover": { "name": "เพิ่งมีคนรัก", "value": 8, "days": 5 },
	"broke_up": { "name": "อกหัก", "value": -10, "days": 6 },
	"catharsis": { "name": "ได้ระบายความในใจ", "value": 18, "days": 2 },
	"calm_tea": { "name": "ดื่มชาสงบจิต", "value": 15, "days": 1 },
	"tea_withdrawal": { "name": "ขาดชาสงบจิต (เสพติด)", "value": -10, "days": 3 },
	"beaten": { "name": "ถูกทำร้ายร่างกาย", "value": -8, "days": 3, "stack": 2 },
	"won_battle": { "name": "ชนะศึก", "value": 5, "days": 3 },
	"lost_battle": { "name": "พ่ายแพ้ในศึก", "value": -6, "days": 3 },
	"arrested": { "name": "ถูกจับกุมคุมขัง", "value": -6, "days": 2 },
	"conflicting_cultivation": { "name": "ฝึกวิชาขัดธาตุ", "value": -4, "days": 1 },
	"raw_birth": { "name": "ได้ลูกน้อย", "value": 12, "days": 8 },
}

static func get_def(id: String) -> Dictionary:
	return THOUGHTS.get(id, { "name": id, "value": 0, "days": 0 })
