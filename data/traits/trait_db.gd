extends Node
class_name TraitDB

## ฐานข้อมูลพรสวรรค์/อุปนิสัย 120 แบบ (6 หมวด x 20)
## effects = ค่ารากฐานที่บวก/ลบจริงตอนสร้างตัวละคร (key จาก StatSys.STATS_DEF สเกล 1-10)
##           key ขึ้นต้นด้วย "m_" = EXP ความชำนาญอาวุธ (ดู MasterySys) เช่น "m_sword": 20
## desc = คำบรรยายลักษณะ (ผลลัพธ์ตัวเลขสร้างจาก effects อัตโนมัติ ดู get_effect_text)

const TRAITS = {
	# ── ร่างกาย (Physical) ──
	"ร่างกายเหล็กไหล": { "category": "Physical", "is_positive": true, "effects": { "vit": 3, "str": 1 }, "desc": "ผิวหนังแข็งแกร่งดุจเหล็กกล้า" },
	"กระดูกมังกร": { "category": "Physical", "is_positive": true, "effects": { "str": 2, "vit": 2 }, "desc": "โครงกระดูกหนาแน่นผิดมนุษย์" },
	"เลือดฟีนิกซ์": { "category": "Physical", "is_positive": true, "effects": { "regen": 3, "vit": 1 }, "desc": "บาดแผลสมานตัวเร็วอย่างน่าอัศจรรย์" },
	"ฟื้นฟูไร้สิ้นสุด": { "category": "Physical", "is_positive": true, "effects": { "regen": 3, "immune": 1 }, "desc": "ร่างกายฟื้นตัวได้แม้บาดเจ็บสาหัส" },
	"กำยำดั่งยักษ์": { "category": "Physical", "is_positive": true, "effects": { "str": 3, "agi": -1 }, "desc": "ร่างใหญ่ล่ำสัน แรงมากแต่ขยับช้า" },
	"ร่างกายอ่อนแอ": { "category": "Physical", "is_positive": false, "effects": { "str": -2, "vit": -2 }, "desc": "ป่วยออดแอดมาตั้งแต่เด็ก" },
	"กระดูกเปราะ": { "category": "Physical", "is_positive": false, "effects": { "vit": -2 }, "desc": "กระดูกหักง่ายเมื่อถูกโจมตีหนัก" },
	"โลหิตจาง": { "category": "Physical", "is_positive": false, "effects": { "regen": -2, "vit": -1 }, "desc": "ซีดเซียว เลือดลมไม่พอเลี้ยงกาย" },
	"ฟื้นฟูเชื่องช้า": { "category": "Physical", "is_positive": false, "effects": { "regen": -2 }, "desc": "แผลเล็กๆ ก็ใช้เวลาหายนาน" },
	"หอบเหนื่อยง่าย": { "category": "Physical", "is_positive": false, "effects": { "vit": -1, "agi": -1 }, "desc": "วิ่งไม่กี่ลี้ก็หายใจไม่ทัน" },
	"ทนทานยาพิษ": { "category": "Physical", "is_positive": true, "effects": { "immune": 3 }, "desc": "พิษทั่วไปทำอะไรไม่ได้" },
	"ต้านทานความเย็น": { "category": "Physical", "is_positive": true, "effects": { "immune": 2, "vit": 1 }, "desc": "ไม่สะทกสะท้านต่อลมหนาว" },
	"ต้านทานความร้อน": { "category": "Physical", "is_positive": true, "effects": { "immune": 2, "regen": 1 }, "desc": "ทนไอร้อนจากเตาหลอมได้นาน" },
	"ปอดเหล็ก": { "category": "Physical", "is_positive": true, "effects": { "vit": 2, "agi": 1 }, "desc": "ลมหายใจยาว อึดทนเป็นพิเศษ" },
	"สายตาเหยี่ยว": { "category": "Physical", "is_positive": true, "effects": { "perception": 2, "m_hidden": 30 }, "desc": "มองเห็นเป้าหมายไกลนับร้อยก้าว" },
	"หูทิพย์": { "category": "Physical", "is_positive": true, "effects": { "perception": 2 }, "desc": "ได้ยินเสียงฝีเท้าแผ่วเบาที่สุด" },
	"จมูกสุนัข": { "category": "Physical", "is_positive": true, "effects": { "gathering": 2, "perception": 1 }, "desc": "ดมกลิ่นสมุนไพรหายากได้จากระยะไกล" },
	"ร่างกายยืดหยุ่น": { "category": "Physical", "is_positive": true, "effects": { "agi": 2, "movement_arts": 1 }, "desc": "บิดตัวหลบได้ในท่าที่คนอื่นทำไม่ได้" },
	"หนักดั่งขุนเขา": { "category": "Physical", "is_positive": true, "effects": { "vit": 2, "defense_arts": 1, "agi": -1 }, "desc": "ยืนนิ่งราวภูผา ผลักไม่ไหว" },
	"เบาดั่งขนนก": { "category": "Physical", "is_positive": true, "effects": { "agi": 2, "movement_arts": 2, "vit": -1 }, "desc": "ตัวเบาจนเหยียบใบไม้ไม่ไหว" },

	# ── จิตวิญญาณ (Spiritual) ──
	"รากวิญญาณสวรรค์": { "category": "Spiritual", "is_positive": true, "effects": { "aptitude": 3, "breakthrough": 1 }, "desc": "รากวิญญาณระดับฟ้าประทาน หนึ่งในหมื่น" },
	"ปราณบริสุทธิ์": { "category": "Spiritual", "is_positive": true, "effects": { "max_qi": 3, "aptitude": 1 }, "desc": "ลมปราณใสสะอาดไร้มลทิน" },
	"สัมผัสเทพ": { "category": "Spiritual", "is_positive": true, "effects": { "perception": 3 }, "desc": "รับรู้ความเปลี่ยนแปลงของปราณรอบตัวได้ทันที" },
	"บุตรแห่งโชคชะตา": { "category": "Spiritual", "is_positive": true, "effects": { "luck": 3, "breakthrough": 1 }, "desc": "สวรรค์ดูเหมือนจะเข้าข้างอยู่เสมอ" },
	"จิตวิญญาณแข็งแกร่ง": { "category": "Spiritual", "is_positive": true, "effects": { "willpower": 2, "magic_resist": 2 }, "desc": "วิญญาณมั่นคง ไม่หวั่นไหวต่อมารภายใน" },
	"รากวิญญาณพิการ": { "category": "Spiritual", "is_positive": false, "effects": { "aptitude": -3 }, "desc": "รากวิญญาณบกพร่อง ฝึกตนยากกว่าคนอื่น" },
	"ปราณติดขัด": { "category": "Spiritual", "is_positive": false, "effects": { "max_qi": -2, "breakthrough": -1 }, "desc": "เส้นลมปราณอุดตันหลายจุด" },
	"สัมผัสมืดบอด": { "category": "Spiritual", "is_positive": false, "effects": { "perception": -2 }, "desc": "แทบสัมผัสปราณรอบตัวไม่ได้" },
	"ถูกสวรรค์ทอดทิ้ง": { "category": "Spiritual", "is_positive": false, "effects": { "luck": -2, "breakthrough": -2 }, "desc": "ทุกครั้งที่ทะลวงขั้น ฟ้าดินมักไม่เป็นใจ" },
	"จิตวิญญาณเปราะบาง": { "category": "Spiritual", "is_positive": false, "effects": { "willpower": -2, "magic_resist": -2 }, "desc": "ถูกมารภายในรบกวนได้ง่าย" },
	"สมาธิหยินหยาง": { "category": "Spiritual", "is_positive": true, "effects": { "max_qi": 2, "focus": 2 }, "desc": "ปราณหยินและหยางในกายสมดุลพอดี" },
	"ดึงดูดปราณ": { "category": "Spiritual", "is_positive": true, "effects": { "aptitude": 2 }, "desc": "ปราณฟ้าดินไหลเข้าหาตัวเองตามธรรมชาติ" },
	"สะท้อนเวท": { "category": "Spiritual", "is_positive": true, "effects": { "magic_resist": 3 }, "desc": "ปราณของศัตรูมักถูกปัดเบี่ยงออกไป" },
	"อายุขัยยืนยาว": { "category": "Spiritual", "is_positive": true, "effects": { "regen": 1, "vit": 1 }, "desc": "ตระกูลนี้อายุยืนกว่าคนทั่วไป" },
	"อายุขัยสั้น": { "category": "Spiritual", "is_positive": false, "effects": { "vit": -1, "regen": -1 }, "desc": "ไฟชีวิตลุกโชนแต่มอดเร็ว" },
	"ปราณอัคคี": { "category": "Spiritual", "is_positive": true, "effects": { "max_qi": 1, "str": 1 }, "desc": "ลมปราณร้อนแรงดุจเปลวเพลิง" },
	"ปราณวารี": { "category": "Spiritual", "is_positive": true, "effects": { "max_qi": 1, "regen": 1 }, "desc": "ลมปราณไหลเวียนนุ่มนวลดุจสายน้ำ" },
	"ปราณพฤกษา": { "category": "Spiritual", "is_positive": true, "effects": { "max_qi": 1, "alchemy": 1 }, "desc": "เข้ากันได้ดีกับสมุนไพรทุกชนิด" },
	"ปราณอัสนี": { "category": "Spiritual", "is_positive": true, "effects": { "max_qi": 1, "agi": 1 }, "desc": "ลมปราณแล่นเร็วดุจสายฟ้า" },
	"ปราณปฐพี": { "category": "Spiritual", "is_positive": true, "effects": { "max_qi": 1, "vit": 1 }, "desc": "ลมปราณหนักแน่นดุจผืนดิน" },

	# ── สติปัญญา (Mental) ──
	"อัจฉริยะ": { "category": "Mental", "is_positive": true, "effects": { "comprehension": 3, "memory": 1 }, "desc": "เรียนรู้ทุกอย่างได้ในพริบตา" },
	"ความจำตระการตา": { "category": "Mental", "is_positive": true, "effects": { "memory": 3 }, "desc": "อ่านคัมภีร์รอบเดียวก็จำได้ทั้งเล่ม" },
	"ใจนิ่งดั่งน้ำ": { "category": "Mental", "is_positive": true, "effects": { "focus": 2, "willpower": 1 }, "desc": "ไม่มีสิ่งใดทำให้จิตใจกระเพื่อม" },
	"ปณิธานเหล็กกล้า": { "category": "Mental", "is_positive": true, "effects": { "willpower": 3 }, "desc": "ตั้งใจสิ่งใดแล้วไม่มีวันถอย" },
	"ไหวพริบเป็นเลิศ": { "category": "Mental", "is_positive": true, "effects": { "wit": 3 }, "desc": "มองออกถึงกับดักก่อนจะก้าวเข้าไป" },
	"ปัญญาทึบ": { "category": "Mental", "is_positive": false, "effects": { "comprehension": -2 }, "desc": "ต้องอ่านคัมภีร์ซ้ำเป็นสิบรอบกว่าจะเข้าใจ" },
	"ขี้ลืม": { "category": "Mental", "is_positive": false, "effects": { "memory": -2 }, "desc": "ลืมกระบวนท่าที่เพิ่งเรียนไปเมื่อวาน" },
	"สมาธิสั้น": { "category": "Mental", "is_positive": false, "effects": { "focus": -2 }, "desc": "นั่งสมาธิได้ไม่ถึงเค่อ" },
	"จิตใจว้าวุ่น": { "category": "Mental", "is_positive": false, "effects": { "willpower": -2, "focus": -1 }, "desc": "ความคิดฟุ้งซ่านตลอดเวลา" },
	"ถูกหลอกง่าย": { "category": "Mental", "is_positive": false, "effects": { "wit": -2 }, "desc": "เชื่อคนง่าย มักตกหลุมพราง" },
	"กระหายความรู้": { "category": "Mental", "is_positive": true, "effects": { "comprehension": 2, "memory": 1 }, "desc": "ใช้เวลาว่างทั้งหมดอยู่ในหอตำรา" },
	"นักปราชญ์": { "category": "Mental", "is_positive": true, "effects": { "comprehension": 2, "wit": 2 }, "desc": "รอบรู้ทั้งตำราและวิถีโลก" },
	"บ้าคลั่ง": { "category": "Mental", "is_positive": false, "effects": { "willpower": -2, "str": 1 }, "desc": "อารมณ์แปรปรวน บางครั้งแรงขึ้นผิดคน" },
	"วิตกกังวล": { "category": "Mental", "is_positive": false, "effects": { "willpower": -2 }, "desc": "กังวลกับทุกเรื่องจนนอนไม่หลับ" },
	"คิดมาก": { "category": "Mental", "is_positive": false, "effects": { "focus": -1, "wit": 1 }, "desc": "คิดรอบคอบแต่ตัดสินใจช้า" },
	"ใจเด็ดเดี่ยว": { "category": "Mental", "is_positive": true, "effects": { "willpower": 2 }, "desc": "ตัดสินใจเร็วและไม่เสียใจภายหลัง" },
	"ไร้ความรู้สึก": { "category": "Mental", "is_positive": true, "effects": { "willpower": 2, "charisma": -1 }, "desc": "ไม่หวั่นไหวต่ออารมณ์ แต่คนรอบข้างไม่ค่อยชอบ" },
	"มองโลกแง่ดี": { "category": "Mental", "is_positive": true, "effects": { "willpower": 1, "luck": 1 }, "desc": "ยิ้มรับทุกความยากลำบาก" },
	"มองโลกแง่ร้าย": { "category": "Mental", "is_positive": false, "effects": { "luck": -1, "wit": 1 }, "desc": "คาดการณ์เรื่องร้ายไว้ก่อนเสมอ" },
	"ความนึกคิดซับซ้อน": { "category": "Mental", "is_positive": true, "effects": { "wit": 2, "formation": 1 }, "desc": "เข้าใจโครงสร้างค่ายกลได้โดยสัญชาตญาณ" },

	# ── สังคมและการทูต (Social) ──
	"เสน่ห์ล้นเหลือ": { "category": "Social", "is_positive": true, "effects": { "charisma": 3 }, "desc": "ใครพบเห็นก็อดชื่นชมไม่ได้" },
	"ผู้นำโดยกำเนิด": { "category": "Social", "is_positive": true, "effects": { "leadership": 3 }, "desc": "คนรอบข้างพร้อมทำตามคำสั่งโดยไม่ลังเล" },
	"วาทศิลป์": { "category": "Social", "is_positive": true, "effects": { "charisma": 2, "deception": 2 }, "desc": "พูดจนคนฟังคล้อยตามได้เสมอ" },
	"น่าเกรงขาม": { "category": "Social", "is_positive": true, "effects": { "intimidation": 3 }, "desc": "แค่จ้องมอง ศัตรูก็ถอยไปครึ่งก้าว" },
	"โชคดีติดตัว": { "category": "Social", "is_positive": true, "effects": { "luck": 3 }, "desc": "เดินไปไหนมักเจอของดีตกอยู่" },
	"หน้าตาอัปลักษณ์": { "category": "Social", "is_positive": false, "effects": { "charisma": -2 }, "desc": "ใบหน้ามีแผลเป็นน่ากลัว" },
	"ตามคนไม่ทัน": { "category": "Social", "is_positive": false, "effects": { "wit": -1, "deception": -1 }, "desc": "มักถูกคนอื่นหักหลังโดยไม่รู้ตัว" },
	"พูดไม่เก่ง": { "category": "Social", "is_positive": false, "effects": { "charisma": -2 }, "desc": "อ้ำอึ้งทุกครั้งที่ต้องพูดต่อหน้าคน" },
	"ขี้ขลาด": { "category": "Social", "is_positive": false, "effects": { "intimidation": -2, "willpower": -1 }, "desc": "เห็นศัตรูแล้วขาสั่น" },
	"โชคร้ายติดตัว": { "category": "Social", "is_positive": false, "effects": { "luck": -3 }, "desc": "เรื่องร้ายมักเกิดกับตัวเองก่อนใคร" },
	"ขี้อิจฉา": { "category": "Social", "is_positive": false, "effects": { "charisma": -1, "willpower": -1 }, "desc": "ทนเห็นคนอื่นได้ดีกว่าไม่ได้ (เสี่ยงทรยศสำนัก)" },
	"แค้นฝังหุ่น": { "category": "Social", "is_positive": false, "effects": { "charisma": -1, "intimidation": 1 }, "desc": "จดจำความแค้นไม่มีวันลืม" },
	"ใจบุญ": { "category": "Social", "is_positive": true, "effects": { "charisma": 1, "medicine": 2 }, "desc": "ช่วยเหลือผู้ตกยากเสมอ" },
	"โหดเหี้ยม": { "category": "Social", "is_positive": true, "effects": { "intimidation": 2, "charisma": -1 }, "desc": "ไม่ปรานีศัตรูแม้แต่น้อย" },
	"เจ้าชู้": { "category": "Social", "is_positive": true, "effects": { "charisma": 2, "focus": -1 }, "desc": "หว่านเสน่ห์ไปทั่วยุทธภพ" },
	"ซื่อสัตย์": { "category": "Social", "is_positive": true, "effects": { "leadership": 1, "deception": -1 }, "desc": "รักษาคำพูดยิ่งชีพ (ภักดีต่อสำนัก)" },
	"ทรยศง่าย": { "category": "Social", "is_positive": false, "effects": { "leadership": -2 }, "desc": "พร้อมเปลี่ยนข้างเมื่อได้ผลประโยชน์" },
	"มักใหญ่ใฝ่สูง": { "category": "Social", "is_positive": true, "effects": { "leadership": 1, "comprehension": 1 }, "desc": "ฝันจะยืนอยู่เหนือทุกคน" },
	"ถ่อมตัว": { "category": "Social", "is_positive": true, "effects": { "charisma": 1, "willpower": 1 }, "desc": "ไม่อวดตัว เป็นที่รักของศิษย์ร่วมสำนัก" },
	"หยิ่งยโส": { "category": "Social", "is_positive": false, "effects": { "charisma": -2, "intimidation": 1 }, "desc": "มองคนอื่นต่ำกว่าตัวเองเสมอ" },

	# ── เชี่ยวชาญต่อสู้ (Combat) ──
	"อัจฉริยะกระบี่": { "category": "Combat", "is_positive": true, "effects": { "m_sword": 60 }, "desc": "เกิดมาเพื่อจับกระบี่" },
	"หมัดหนัก": { "category": "Combat", "is_positive": true, "effects": { "m_fist": 50, "str": 1 }, "desc": "หมัดเดียวทำหินแตก" },
	"ตัวเบาดั่งลม": { "category": "Combat", "is_positive": true, "effects": { "movement_arts": 3, "agi": 1 }, "desc": "เคลื่อนไหวไร้เสียงดุจสายลม" },
	"แม่นยำดั่งจับวาง": { "category": "Combat", "is_positive": true, "effects": { "m_hidden": 50, "focus": 1 }, "desc": "ซัดอาวุธลับไม่เคยพลาดเป้า" },
	"สัญชาตญาณนักฆ่า": { "category": "Combat", "is_positive": true, "effects": { "focus": 2, "deception": 2 }, "desc": "มองเห็นจุดตายของศัตรูโดยสัญชาตญาณ" },
	"จับดาบไม่เป็น": { "category": "Combat", "is_positive": false, "effects": { "m_sword": -40 }, "desc": "ถือกระบี่ทีไรมักทำหล่น" },
	"หมัดเบาโหวง": { "category": "Combat", "is_positive": false, "effects": { "m_fist": -40 }, "desc": "ต่อยแรงแค่ไหนก็ไม่เจ็บ" },
	"เชื่องช้า": { "category": "Combat", "is_positive": false, "effects": { "agi": -2, "movement_arts": -1 }, "desc": "ตอบสนองช้ากว่าคนอื่นครึ่งจังหวะ" },
	"ตาเหล่": { "category": "Combat", "is_positive": false, "effects": { "m_hidden": -40 }, "desc": "เล็งทีไรก็ผิดเป้า" },
	"ตื่นสนามรบ": { "category": "Combat", "is_positive": false, "effects": { "willpower": -1, "defense_arts": -1 }, "desc": "ตื่นตระหนกเมื่อเห็นเลือด" },
	"คลั่งการต่อสู้": { "category": "Combat", "is_positive": true, "effects": { "str": 2, "m_fist": 20, "defense_arts": -1 }, "desc": "ยิ่งสู้ยิ่งฮึกเหิม ลืมป้องกันตัว" },
	"สุขุมในสมรภูมิ": { "category": "Combat", "is_positive": true, "effects": { "focus": 2, "defense_arts": 1 }, "desc": "ใจเย็นแม้อยู่ท่ามกลางคมดาบ" },
	"ชอบลอบกัด": { "category": "Combat", "is_positive": true, "effects": { "deception": 2, "m_hidden": 20 }, "desc": "ถนัดโจมตีจากเงามืด" },
	"เน้นตั้งรับ": { "category": "Combat", "is_positive": true, "effects": { "defense_arts": 3 }, "desc": "รอจังหวะศัตรูพลาดก่อนสวนกลับ" },
	"บุกทะลวง": { "category": "Combat", "is_positive": true, "effects": { "str": 1, "m_sword": 20, "m_fist": 20 }, "desc": "พุ่งเข้าหาศัตรูโดยไม่ลังเล" },
	"ไร้ความกลัว": { "category": "Combat", "is_positive": true, "effects": { "willpower": 2, "intimidation": 1 }, "desc": "ไม่เคยรู้จักคำว่ากลัว" },
	"กลัวเลือด": { "category": "Combat", "is_positive": false, "effects": { "m_sword": -20, "intimidation": -1 }, "desc": "เห็นเลือดแล้วหน้ามืด" },
	"จอมยุทธ์คุณธรรม": { "category": "Combat", "is_positive": true, "effects": { "leadership": 1, "m_sword": 20 }, "desc": "ใช้วิชาเพื่อปกป้องผู้อ่อนแอ" },
	"นักฆ่าเลือดเย็น": { "category": "Combat", "is_positive": true, "effects": { "focus": 2, "charisma": -1 }, "desc": "ฆ่าคนได้โดยไม่กะพริบตา" },
	"เชี่ยวชาญอาวุธยาว": { "category": "Combat", "is_positive": true, "effects": { "m_sword": 30, "defense_arts": 1 }, "desc": "ใช้ทวนและง้าวได้คล่องมือ" },

	# ── ทักษะวิชาชีพ (Crafting) ──
	"อัจฉริยะหลอมยา": { "category": "Crafting", "is_positive": true, "effects": { "alchemy": 3 }, "desc": "คุมไฟเตาหลอมได้แม่นยำราวกับเกิดมาพร้อมเตา" },
	"มือทองคำ": { "category": "Crafting", "is_positive": true, "effects": { "forging": 2, "alchemy": 2 }, "desc": "ทำอะไรก็ออกมาประณีต" },
	"ช่างตีเหล็กสวรรค์": { "category": "Crafting", "is_positive": true, "effects": { "forging": 3 }, "desc": "ฟังเสียงเหล็กก็รู้ว่าต้องตีอีกกี่ครั้ง" },
	"นักสร้างค่ายกล": { "category": "Crafting", "is_positive": true, "effects": { "formation": 3 }, "desc": "วางค่ายกลได้แม้มีแค่ก้อนหินไม่กี่ก้อน" },
	"ยอดกุ๊ก": { "category": "Crafting", "is_positive": true, "effects": { "cooking": 3, "medicine": 1 }, "desc": "อาหารที่ทำช่วยฟื้นฟูลมปราณ" },
	"ทำยาระเบิด": { "category": "Crafting", "is_positive": false, "effects": { "alchemy": -2 }, "desc": "เตาหลอมยาระเบิดเป็นประจำ" },
	"มือทำลาย": { "category": "Crafting", "is_positive": false, "effects": { "forging": -1, "alchemy": -1 }, "desc": "จับอะไรก็พัง" },
	"ตีเหล็กแตก": { "category": "Crafting", "is_positive": false, "effects": { "forging": -2 }, "desc": "ตีอาวุธทีไรมีรอยร้าวทุกครั้ง" },
	"หลงทิศค่ายกล": { "category": "Crafting", "is_positive": false, "effects": { "formation": -2 }, "desc": "เดินเข้าค่ายกลของตัวเองแล้วหาทางออกไม่เจอ" },
	"ทำอาหารเป็นพิษ": { "category": "Crafting", "is_positive": false, "effects": { "cooking": -2 }, "desc": "ใครกินอาหารฝีมือนี้เป็นต้องท้องเสีย" },
	"รักธรรมชาติ": { "category": "Crafting", "is_positive": true, "effects": { "gathering": 2, "alchemy": 1 }, "desc": "รู้จักพืชพรรณในป่าทุกชนิด" },
	"จอมขุดแร่": { "category": "Crafting", "is_positive": true, "effects": { "gathering": 2, "forging": 1 }, "desc": "ดูออกว่าหินก้อนไหนมีแร่ซ่อนอยู่" },
	"พ่อค้าหน้าเลือด": { "category": "Crafting", "is_positive": true, "effects": { "deception": 2, "charisma": -1 }, "desc": "ต่อราคาจนพ่อค้าร้องไห้" },
	"ชอบสะสมของ": { "category": "Crafting", "is_positive": true, "effects": { "gathering": 1, "luck": 1 }, "desc": "เก็บทุกอย่างที่ขวางทาง บางทีก็เจอของดี" },
	"นักเจรจาต่อรอง": { "category": "Crafting", "is_positive": true, "effects": { "charisma": 2, "wit": 1 }, "desc": "ปิดดีลได้เสมอ" },
	"เซียนสมุนไพร": { "category": "Crafting", "is_positive": true, "effects": { "alchemy": 2, "medicine": 2 }, "desc": "แยกแยะสมุนไพรวิญญาณได้ด้วยการดม" },
	"ช่างไม้ตาเพชร": { "category": "Crafting", "is_positive": true, "effects": { "forging": 2, "formation": 1 }, "desc": "สร้างโครงสร้างแม่นยำไม่มีผิดเพี้ยน" },
	"ประหยัดวัตถุดิบ": { "category": "Crafting", "is_positive": true, "effects": { "alchemy": 1, "forging": 1 }, "desc": "ใช้วัตถุดิบคุ้มค่าทุกเศษเสี้ยว" },
	"นักล่าอสูร": { "category": "Crafting", "is_positive": true, "effects": { "gathering": 1, "m_sword": 20 }, "desc": "ชำแหละสัตว์อสูรได้ชิ้นส่วนครบถ้วน" },
	"เชี่ยวชาญพิษ": { "category": "Crafting", "is_positive": true, "effects": { "medicine": 2, "immune": 1 }, "desc": "ปรุงและแก้พิษได้ทุกชนิด" },
}

static func get_trait(name: String) -> Dictionary:
	if TRAITS.has(name):
		return TRAITS[name]
	return {}

## key "m_xxx" = EXP ความชำนาญอาวุธสาย xxx
static func is_mastery_key(key: String) -> bool:
	return key.begins_with("m_")

## ข้อความผลลัพธ์ เช่น "ความแข็งแกร่ง +2, ความชำนาญกระบี่ +60 EXP"
static func get_effect_text(name: String) -> String:
	var parts: Array[String] = []
	var effects: Dictionary = get_trait(name).get("effects", {})
	for key in effects:
		if is_mastery_key(key):
			parts.append("ความชำนาญ%s %+d EXP" % [MasterySys.type_name(key.trim_prefix("m_")), effects[key]])
		else:
			parts.append("%s %+d" % [StatSys.STATS_DEF[key].name, effects[key]])
	return ", ".join(parts)

## ความแรงของผลพรสวรรค์ (ใช้ตั้งราคาตอนสร้างตัวละคร): รากฐาน 1 แต้ม = 1, ความชำนาญ 20 EXP = 1
static func get_net_value(name: String) -> float:
	var net = 0.0
	var effects: Dictionary = get_trait(name).get("effects", {})
	for key in effects:
		net += effects[key] / 20.0 if is_mastery_key(key) else float(effects[key])
	return net

## ใส่ผลของพรสวรรค์ลงในค่ารากฐาน/ความชำนาญของศิษย์ (บันทึกที่มาไว้ด้วย)
static func apply_trait_effects(d: DiscipleData, trait_name: String) -> void:
	var effects: Dictionary = get_trait(trait_name).get("effects", {})
	for key in effects:
		if is_mastery_key(key):
			var t = key.trim_prefix("m_")
			d.mastery[t] = MasterySys.get_exp(d, t) + effects[key]
		else:
			d.add_stat(key, effects[key], "พรสวรรค์ '%s'" % trait_name)
