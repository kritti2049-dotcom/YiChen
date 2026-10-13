extends Node
class_name FactionDB

## ขั้วอำนาจทั้งหมดในพิภพโลหิตชาด (อิงตามตำนาน)
## align = แนวทาง (ธรรมะ / กลาง / มาร) ใช้คิดความสัมพันธ์กับสำนักเรา
## bloc = ฝ่ายที่มี AI เดินหมากบนแผนที่ 4X ของตัวเอง (ดู BLOCS และ FactionSys)
## great = หนึ่งใน 8 สำนักใหญ่ของพันธมิตรยุทธภพที่มีสิทธิ์โหวตเลือกจ้าวยุทธภพ
## seat = โหนดที่ตั้ง (WorldDB.NODES) ถ้าเป็นเมือง = ตั้งสำนักงานใหญ่อยู่ในเมืองนั้น
## power = กำลังรวมของทั้งสำนัก (สเกลเดียวกับพลังรบรวม: ศิษย์ใหม่ ~20, เจ้าสำนักใหญ่ 10,000+)
## style = สายวิชาหลัก (ใช้สุ่มคัมภีร์ประจำสำนัก), status_attack = สถานะผิดปกติที่ศิษย์สำนักนี้ชอบใช้
## leader = ประมุข/บุคคลสำคัญในตำนาน (ใช้เป็นยอดฝีมืออันดับหนึ่งของสำนักในทำเนียบยุทธภพ)
## allies / enemies = ความสัมพันธ์ตั้งต้นตามตำนาน (Seed จะสุ่มเพิ่ม/ลดจากค่านี้)

const LORE_BLOCS = {
	"righteous": { "name": "พันธมิตรยุทธภพสยบฟ้า", "leader": "f_baiyun", "color": Color(0.95, 0.85, 0.45),
		"desc": "ฝ่ายธรรมะ: ปกป้องอาณาเขต ยกทัพปราบมาร ยกย่องผู้ที่ต่อสู้กับฝ่ายมาร" },
	"demonic": { "name": "ฝ่ายมาร", "leader": "f_sunset", "color": Color(0.85, 0.2, 0.25),
		"desc": "ฝ่ายอธรรม: ขยายอาณาเขตอย่างดุดัน ปล้นสะดม ลอบสังหารยอดฝีมือ แพร่พิษกู่" },
	"eunuch": { "name": "สิบขันทีเงา", "leader": "f_eunuchs", "color": Color(0.6, 0.35, 0.75),
		"desc": "ราชสำนักภายใต้เงาขันที: ยุแยงพันธมิตร ส่งเสบียงให้ฝ่ายมาร ยึดตำแหน่งเจ้าเมือง เรียกส่วย" },
	"independent": { "name": "ขั้วอิสระแห่งจงหยวน", "leader": "", "color": Color(0.7, 0.7, 0.65),
		"desc": "ตระกูลและสำนักที่ไม่ยอมขึ้นกับใคร รักษาผลประโยชน์ของตน" },
	"foreign": { "name": "แคว้นชายขอบและราชวงศ์เก่า", "leader": "", "color": Color(0.45, 0.75, 0.85),
		"desc": "ชนเผ่า โจรสลัด และราชวงศ์ที่ล่มสลาย รอวันบุกจงหยวน" },
}

const LORE_FACTIONS = {
	# ══════════ พันธมิตรยุทธภพสยบฟ้า (ฝ่ายธรรมะ) ══════════
	"f_baiyun": { "name": "สำนักกระบี่เมฆาขาว", "align": "ธรรมะ", "bloc": "righteous", "great": true, "color": Color(0.92, 0.95, 1.0),
		"seat": "f_baiyun_seat", "power": 60000, "style": "sword", "status_attack": "", "leader": "ตงฟางเจวี๋ย",
		"desc": "สำนักอันดับหนึ่งและแกนนำพันธมิตร เพลงกระบี่รวดเร็วดุจสายลมผ่านเมฆา",
		"allies": ["f_wudang", "f_mu", "f_huashan", "f_qinmu"], "enemies": ["f_sunset", "f_blood_lotus", "f_east_sea", "f_eunuchs"] },
	"f_wudang": { "name": "สำนักบู๊ตึง", "align": "ธรรมะ", "bloc": "righteous", "great": true, "color": Color(0.55, 0.75, 0.95),
		"seat": "f_wudang_seat", "power": 50000, "style": "sword", "status_attack": "seal", "leader": "จางซานเมิ่ง",
		"desc": "ป้อมปราการสุดท้ายแห่งสติปัญญา หยินหยางหมุนวนเป็นหนึ่งเดียว",
		"allies": ["f_baiyun"], "enemies": ["f_blood_lotus", "f_hundred_tribes", "f_eunuchs"] },
	"f_golden_luohan": { "name": "วัดอรหันต์ทองคำ", "align": "ธรรมะ", "bloc": "righteous", "great": true, "color": Color(0.95, 0.72, 0.25),
		"seat": "f_golden_luohan_seat", "power": 55000, "style": "palm", "status_attack": "seal", "leader": "ซือคง",
		"desc": "แหล่งกำเนิดยอดวิชากายา แตกเป็นสาย 'เมตตาธรรม' และ 'วัชระพิโรธ'",
		"allies": ["f_medicine"], "enemies": ["f_sunset", "f_blood_lotus"] },
	"f_lei": { "name": "ตระกูลป้อมอัสนี", "align": "ธรรมะ", "bloc": "righteous", "great": true, "color": Color(0.75, 0.6, 1.0),
		"seat": "f_lei_seat", "power": 45000, "style": "sword", "status_attack": "", "leader": "เหลยกัง",
		"desc": "ป้อมเหล็กชายแดนเหนือ วรยุทธ์ดุดันดุจสายฟ้า ปกป้องจงหยวนจากชนเผ่าทุ่งหญ้า",
		"allies": ["f_ming", "f_court", "f_eagle"], "enemies": ["f_steppe", "f_eunuchs"] },
	"f_beggar": { "name": "พรรคกระยาจก", "align": "ธรรมะ", "bloc": "righteous", "great": true, "color": Color(0.7, 0.55, 0.35),
		"seat": "c_kaifeng", "power": 40000, "style": "palm", "status_attack": "", "leader": "หงจิ่วกง",
		"desc": "เครือข่ายที่แทรกซึมทุกตรอกซอกซอย ไม้เท้าหยกเขียวชี้เป็นตาย",
		"allies": ["f_south_tiger"], "enemies": ["f_eunuchs", "f_hawk"] },
	"f_huashan": { "name": "สำนักหัวซาน", "align": "ธรรมะ", "bloc": "righteous", "great": true, "color": Color(0.55, 0.85, 0.5),
		"seat": "f_huashan_seat", "power": 38000, "style": "sword", "status_attack": "", "leader": "เย่หัว",
		"desc": "เพลงกระบี่งดงามดุจร่ายรำ แต่คือศาสตร์แห่งการปลิดชีพ",
		"allies": ["f_baiyun", "f_chenwan"], "enemies": ["f_sunset"] },
	"f_mu": { "name": "ตระกูลมู่", "align": "ธรรมะ", "bloc": "righteous", "great": false, "color": Color(0.85, 0.95, 0.85),
		"seat": "c_luoyang", "power": 20000, "style": "sword", "status_attack": "", "leader": "ประมุขมู่",
		"desc": "ตระกูลขุนนางนักรบผู้กุมเศรษฐกิจครึ่งหนึ่งของจงหยวน รากแก้วของเมฆาขาว",
		"allies": ["f_baiyun", "f_qinmu"], "enemies": ["f_sunset"] },
	"f_ming": { "name": "ตระกูลหมิง", "align": "ธรรมะ", "bloc": "righteous", "great": false, "color": Color(0.95, 0.5, 0.3),
		"seat": "c_beijing", "power": 18000, "style": "spear", "status_attack": "", "leader": "",
		"desc": "สำนักคุ้มภัยอันดับหนึ่ง ด้ามทวนตั้งตรงดุจคุณธรรม",
		"allies": ["f_lei"], "enemies": ["f_eagle", "f_steppe", "f_hawk"] },
	"f_qinmu": { "name": "สำนักฉินมู่", "align": "ธรรมะ", "bloc": "righteous", "great": false, "color": Color(0.5, 0.9, 0.65),
		"seat": "f_qinmu_seat", "power": 12000, "style": "sword", "status_attack": "", "leader": "จื่อซิน",
		"desc": "สตรีผู้ถูกหักหลังโดยความรัก เสียงพิณและคมกระบี่สอดประสาน",
		"allies": ["f_baiyun", "f_mu"], "enemies": ["f_hundred_flowers"] },
	"f_qingxu": { "name": "สำนักชิงซวี", "align": "ธรรมะ", "bloc": "righteous", "great": false, "color": Color(0.8, 0.55, 0.85),
		"seat": "f_qingxu_seat", "power": 15000, "style": "formation", "status_attack": "", "leader": "",
		"desc": "สำนักเต๋าผู้อ่านโองการสวรรค์ผ่านหมู่ดาราและค่ายกลโบราณ",
		"allies": ["f_sword_grave", "f_hidden_council", "f_academy"], "enemies": ["f_blood_lotus", "f_tianming"] },
	"f_hidden_council": { "name": "สภามังกรเร้น", "align": "ธรรมะ", "bloc": "righteous", "great": false, "color": Color(0.6, 0.45, 0.8),
		"seat": "f_hidden_council_seat", "power": 8000, "style": "formation", "status_attack": "", "leader": "",
		"desc": "สำนักเล็กๆ ที่รวมตัวเป็นโล่มนุษย์ขวางลัทธิบัวโลหิต",
		"allies": ["f_qingxu", "f_medicine"], "enemies": ["f_blood_lotus"] },
	"f_medicine": { "name": "หุบเขาหมื่นโอสถ", "align": "ธรรมะ", "bloc": "righteous", "great": false, "color": Color(0.45, 0.95, 0.6),
		"seat": "f_medicine_seat", "power": 10000, "style": "internal", "status_attack": "", "leader": "มู่ชุนเฟิง",
		"desc": "หมอเทวดาผู้เยียวยา ผู้เดียวที่ปรุงยาแก้พิษร้ายของลัทธิบัวโลหิตได้",
		"allies": ["f_sword_grave", "f_golden_luohan", "f_tang", "f_hidden_council"], "enemies": ["f_blood_lotus"] },
	"f_academy": { "name": "สำนักศึกษาหลวง", "align": "ธรรมะ", "bloc": "righteous", "great": false, "color": Color(0.9, 0.88, 0.7),
		"seat": "c_xueyun", "power": 6000, "style": "formation", "status_attack": "seal", "leader": "เหลินจิง",
		"desc": "ปราชญ์ผู้ถือพู่กันที่น่าเกรงขามยิ่งกว่าขุนศึก เขื่อนกั้นความฉ้อฉลของขันที",
		"allies": ["f_qingxu"], "enemies": ["f_eunuchs", "f_tianming"] },
	# ══════════ ฝ่ายมาร ══════════
	"f_sunset": { "name": "พรรคมารอัสดง", "align": "มาร", "bloc": "demonic", "great": false, "color": Color(0.7, 0.1, 0.12),
		"seat": "f_sunset_seat", "power": 55000, "style": "internal", "status_attack": "poison", "leader": "เย่หวัง",
		"desc": "ที่พักพิงของวีรชนที่ถูกโลกคุณธรรมจอมปลอมทอดทิ้ง เลือดจะล้างเลือด",
		"allies": ["f_blood_spider"], "enemies": ["f_baiyun", "f_golden_luohan", "f_blood_lotus", "f_tang", "f_huashan"] },
	"f_blood_lotus": { "name": "ลัทธิบัวโลหิต", "align": "มาร", "bloc": "demonic", "great": false, "color": Color(0.85, 0.15, 0.4),
		"seat": "f_blood_lotus_seat", "power": 40000, "style": "poison", "status_attack": "poison", "leader": "หลี่เฮิ่นสุ่ย",
		"desc": "ผุดจากเถ้าถ่านตระกูลที่ถูกทรยศ มุ่งชำระล้างโลกด้วยความตาย",
		"allies": ["f_beiliang"], "enemies": ["f_court", "f_eunuchs", "f_wudang", "f_golden_luohan", "f_medicine", "f_sunset", "f_qingxu", "f_hidden_council"] },
	"f_blood_spider": { "name": "เผ่าแมงมุมโลหิต", "align": "มาร", "bloc": "demonic", "great": false, "color": Color(0.5, 0.05, 0.2),
		"seat": "f_blood_spider_seat", "power": 15000, "style": "poison", "status_attack": "gu", "leader": "",
		"desc": "เผ่าที่ถูกขับไล่ไปเน่าตายในป่าลึก บัดนี้คืบคลานกลับมาพร้อมความแค้น",
		"allies": ["f_sunset", "f_eunuchs"], "enemies": ["f_hundred_tribes"] },
	"f_seven_kill": { "name": "สำนักเจ็ดสังหาร", "align": "มาร", "bloc": "demonic", "great": false, "color": Color(0.3, 0.3, 0.4),
		"seat": "f_seven_kill_seat", "power": 9000, "style": "sword", "status_attack": "", "leader": "ตู้ชาง",
		"desc": "ประกายดาบเจ็ดสายสว่างวาบก่อนวิญญาณหลุดจากร่าง",
		"allies": [], "enemies": ["f_eunuchs", "f_hawk"] },
	# ══════════ สิบขันทีเงา (ราชสำนัก) ══════════
	"f_eunuchs": { "name": "สิบขันทีเงา", "align": "มาร", "bloc": "eunuch", "great": false, "color": Color(0.55, 0.3, 0.7),
		"seat": "c_xueyun", "power": 50000, "style": "internal", "status_attack": "seal", "leader": "จ้าวอิง",
		"desc": "ขันทีผู้กางปีกทอดเงาปกคลุมบัลลังก์ ชักใยราชสำนักต้าเยี่ยทั้งหมด",
		"allies": ["f_hawk", "f_assassin", "f_eagle", "f_tianming", "f_chenwan", "f_court"], "enemies": ["f_academy", "f_beggar", "f_baiyun", "f_seven_kill"] },
	"f_court": { "name": "ราชสำนักต้าเยี่ย", "align": "กลาง", "bloc": "eunuch", "great": false, "color": Color(0.95, 0.8, 0.2),
		"seat": "c_xueyun", "power": 70000, "style": "spear", "status_attack": "", "leader": "องค์ชายรองต้าจิง",
		"desc": "มหาอำนาจที่ปกครองจงหยวน จักรพรรดิอ่อนแอ เหล่ามังกรและหงส์ต้องเลือกข้าง",
		"allies": ["f_lei", "f_iron_stream", "f_eunuchs"], "enemies": ["f_beiliang", "f_azure_dragon", "f_xuancheng", "f_steppe", "f_hundred_tribes", "f_blood_lotus"] },
	"f_hawk": { "name": "หน่วยเหยี่ยวแห่งราชสำนัก", "align": "มาร", "bloc": "eunuch", "great": false, "color": Color(0.75, 0.15, 0.1),
		"seat": "c_xueyun", "power": 30000, "style": "sword", "status_attack": "seal", "leader": "",
		"desc": "คมดาบในแขนเสื้อขันที เหยี่ยวเงาทำลายจากภายใน เหยี่ยวชาดกวาดล้างทั้งตระกูล",
		"allies": ["f_eunuchs"], "enemies": ["f_seven_kill", "f_beggar"] },
	"f_tianming": { "name": "หอลิขิตฟ้า", "align": "กลาง", "bloc": "eunuch", "great": false, "color": Color(0.5, 0.6, 0.95),
		"seat": "c_xueyun", "power": 12000, "style": "formation", "status_attack": "", "leader": "เถี่ยซินอู่",
		"desc": "หอพยากรณ์ดาราที่ชี้นำฤกษ์ยามให้เหล่าขันที",
		"allies": ["f_eunuchs", "f_zhengci"], "enemies": ["f_qingxu", "f_academy"] },
	"f_assassin": { "name": "หอหมื่นสังหาร", "align": "มาร", "bloc": "eunuch", "great": false, "color": Color(0.25, 0.2, 0.25),
		"seat": "c_xueyun", "power": 25000, "style": "hidden_weapon", "status_attack": "poison", "leader": "เสินซา",
		"desc": "ไม่เลือกฝ่าย ไม่ถามเหตุผล ไม่เคยพลาดเป้า ขอเพียงราคาคู่ควรกับชีวิต",
		"allies": ["f_eunuchs", "f_chenwan"], "enemies": [] },
	"f_eagle": { "name": "สำนักคุ้มภัยอินทรีผยอง", "align": "กลาง", "bloc": "eunuch", "great": false, "color": Color(0.6, 0.5, 0.4),
		"seat": "f_eagle_seat", "power": 10000, "style": "spear", "status_attack": "", "leader": "เถี่ยอี้",
		"desc": "ระเบียบวินัยดุจทหาร ยอมจ่ายสินบนขันทีเพื่อชิงงานหลวงจากตระกูลหมิง",
		"allies": ["f_eunuchs", "f_lei", "f_south_tiger"], "enemies": ["f_ming", "f_steppe"] },
	"f_chenwan": { "name": "สมาคมการค้าเฉินว่าน", "align": "กลาง", "bloc": "eunuch", "great": false, "color": Color(1.0, 0.85, 0.35),
		"seat": "c_jinling", "power": 8000, "style": "hidden_weapon", "status_attack": "", "leader": "เฉินฟู่",
		"desc": "เสียงลูกคิดครั้งเดียวอาจล่มตระกูลขุนนาง เป็นแหล่งฟอกเงินของสิบขันที",
		"allies": ["f_eunuchs", "f_hundred_flowers", "f_huashan"], "enemies": ["f_east_sea"] },
	# ══════════ ขั้วอิสระแห่งจงหยวน ══════════
	"f_tang": { "name": "ตระกูลถังแห่งเสฉวน", "align": "กลาง", "bloc": "independent", "great": true, "color": Color(0.35, 0.6, 0.3),
		"seat": "f_tang_seat", "power": 35000, "style": "hidden_weapon", "status_attack": "poison", "leader": "",
		"desc": "จ้าวแห่งอาวุธลับและยาพิษ การตั้งตัวเป็นศัตรูคือก้าวเข้าสู่ห้วงนิทราที่ไม่มีวันตื่น",
		"allies": ["f_medicine", "f_xuanyuan"], "enemies": ["f_sunset"] },
	"f_nangong": { "name": "ตระกูลหนานกง", "align": "ธรรมะ", "bloc": "independent", "great": true, "color": Color(0.6, 0.8, 0.95),
		"seat": "c_suzhou", "power": 36000, "style": "sword", "status_attack": "", "leader": "หนานกงเลี่ย",
		"desc": "ผู้พิทักษ์ความมั่งคั่งและศิลปะแห่งกระบี่คู่ ปราการด่านแรกต่อคุณไสยแดนใต้",
		"allies": [], "enemies": ["f_south_tiger", "f_hundred_tribes"] },
	"f_baixiao": { "name": "สำนักไป่เซียว", "align": "กลาง", "bloc": "independent", "great": false, "color": Color(0.85, 0.85, 0.85),
		"seat": "c_xian", "power": 7000, "style": "movement", "status_attack": "", "leader": "ไต้มู่ไป่",
		"desc": "ดวงตาที่บันทึกทุกหยาดเลือดเป็นทำเนียบยุทธภพ กฎเหล็กคือความเป็นกลาง",
		"allies": ["f_hundred_flowers", "f_zhengci"], "enemies": [] },
	"f_zhengci": { "name": "หอเจิ้งฉือ", "align": "กลาง", "bloc": "independent", "great": false, "color": Color(0.85, 0.7, 0.9),
		"seat": "c_xueyun", "power": 6000, "style": "sword", "status_attack": "", "leader": "เซี่ยอี้",
		"desc": "ที่ซึ่งตัวอักษรหนักกว่าดาบ และทำนองเพลงสยบพายุได้",
		"allies": ["f_baixiao", "f_hundred_flowers", "f_tianming"], "enemies": [] },
	"f_hundred_flowers": { "name": "ตำหนักร้อยบุปผา", "align": "กลาง", "bloc": "independent", "great": false, "color": Color(1.0, 0.55, 0.75),
		"seat": "c_xueyun", "power": 5000, "style": "hidden_weapon", "status_attack": "poison", "leader": "",
		"desc": "ความงามคือหน้าฉาก ความลับคืออาวุธร้ายแรงที่สุดในใต้หล้า",
		"allies": ["f_baixiao", "f_chenwan", "f_zhengci"], "enemies": ["f_qinmu"] },
	"f_sword_grave": { "name": "สุสานใจกระบี่", "align": "กลาง", "bloc": "independent", "great": false, "color": Color(0.7, 0.75, 0.8),
		"seat": "f_sword_grave_seat", "power": 20000, "style": "sword", "status_attack": "", "leader": "เจี้ยนจ่ง",
		"desc": "ผู้เฝ้าสุสานที่หยั่งถึงจิตวิญญาณของเหล็ก วางตัวเป็นกลางอย่างเคร่งครัด",
		"allies": ["f_iron_stream", "f_medicine", "f_qingxu"], "enemies": [] },
	"f_iron_stream": { "name": "หอธารเหล็กไหล", "align": "กลาง", "bloc": "independent", "great": false, "color": Color(0.4, 0.5, 0.9),
		"seat": "f_iron_stream_seat", "power": 14000, "style": "sword", "status_attack": "", "leader": "โอวหยางกัง",
		"desc": "ผู้ผลิตอาวุธให้กองทัพหลวง 'ศาสตรามิเลือกนาย ผู้ถือครองคือผู้กำหนด'",
		"allies": ["f_sword_grave", "f_court", "f_eagle"], "enemies": [] },
	"f_south_tiger": { "name": "ตระกูลพยัคฆ์ใต้", "align": "กลาง", "bloc": "independent", "great": false, "color": Color(0.95, 0.6, 0.2),
		"seat": "f_south_tiger_seat", "power": 9000, "style": "palm", "status_attack": "", "leader": "หู่จิง",
		"desc": "กิ่งก้านที่แยกจากหนานกง ยืนหยัดด้วยกรงเล็บและวิถีหมัด",
		"allies": ["f_eagle", "f_beggar"], "enemies": ["f_nangong"] },
	# ══════════ แคว้นชายขอบและราชวงศ์เก่า ══════════
	"f_beiliang": { "name": "ราชวงศ์เป่ยเหลียงที่เหลือรอด", "align": "กลาง", "bloc": "foreign", "great": false, "color": Color(0.85, 0.95, 1.0),
		"seat": "f_beiliang_seat", "power": 25000, "style": "spear", "status_attack": "", "leader": "เสวี่ยหนานสุน",
		"desc": "ลมหายใจสุดท้ายของอาณาจักรที่ถูกหักหลัง รอวันเพลิงเหมันต์ลุกโชน",
		"allies": ["f_steppe", "f_blood_lotus"], "enemies": ["f_court", "f_eunuchs", "f_xuancheng", "f_xuanyuan"] },
	"f_steppe": { "name": "ชนเผ่าทุ่งหญ้าเยือกแข็ง", "align": "กลาง", "bloc": "foreign", "great": false, "color": Color(0.7, 0.6, 0.45),
		"seat": "c_karakorum", "power": 60000, "style": "sword", "status_attack": "", "leader": "ข่านเตมูร์",
		"desc": "นักรบบนหลังม้าที่เคารพเพียงผู้แข็งแกร่งกว่า ต้องการเหยียบกำแพงจงหยวน",
		"allies": ["f_beiliang"], "enemies": ["f_lei", "f_ming", "f_eagle", "f_court"] },
	"f_hundred_tribes": { "name": "กลุ่มร้อยเผ่าแดนใต้", "align": "กลาง", "bloc": "foreign", "great": false, "color": Color(0.3, 0.7, 0.35),
		"seat": "f_hundred_tribes_seat", "power": 30000, "style": "poison", "status_attack": "gu", "leader": "เซิ่งกูเทียนหมู่",
		"desc": "กฎแห่งพงไพรคือสัจธรรม อาคมกู่คือลมหายใจ",
		"allies": [], "enemies": ["f_court", "f_nangong", "f_blood_spider"] },
	"f_east_sea": { "name": "พันธมิตรทะเลบูรพา", "align": "มาร", "bloc": "foreign", "great": false, "color": Color(0.2, 0.45, 0.7),
		"seat": "f_east_sea_seat", "power": 28000, "style": "sword", "status_attack": "", "leader": "เจียวอู๋ไห่",
		"desc": "เงินตราคือพระเจ้า สัญญาสลักโลหิตคือกฎเหล็กเพียงหนึ่งเดียว",
		"allies": ["f_azure_dragon"], "enemies": ["f_baiyun", "f_chenwan", "f_court"] },
	"f_xuanyuan": { "name": "นิกายซวนหยวน", "align": "กลาง", "bloc": "foreign", "great": false, "color": Color(1.0, 0.45, 0.15),
		"seat": "f_xuanyuan_seat", "power": 32000, "style": "internal", "status_attack": "", "leader": "เฟิ่งเทียน",
		"desc": "ผู้บูชาดวงสุริยา เชื่อว่าเปลวเพลิงคือพลังบริสุทธิ์ที่ชำระล้างโลก",
		"allies": ["f_tang"], "enemies": ["f_divine_temple", "f_beiliang"] },
	"f_divine_temple": { "name": "วิหารเทวะศักดิ์สิทธิ์", "align": "กลาง", "bloc": "foreign", "great": false, "color": Color(1.0, 0.9, 0.5),
		"seat": "c_oasis", "power": 30000, "style": "palm", "status_attack": "", "leader": "เกาเหยียน",
		"desc": "ศรัทธาที่ถูกบิดเบือนเป็นเครื่องมือสู่ความมั่งคั่งใต้โดมทองกลางทะเลทราย",
		"allies": [], "enemies": ["f_xuanyuan", "f_xuancheng"] },
	"f_azure_dragon": { "name": "วังมังกรคราม", "align": "กลาง", "bloc": "foreign", "great": false, "color": Color(0.2, 0.75, 0.85),
		"seat": "f_azure_dragon_seat", "power": 45000, "style": "internal", "status_attack": "seal", "leader": "หลงเย่ว์ซิน",
		"desc": "อดีตราชวงศ์ชางหลงที่จำศีลรอวันกลืนกินทุกบัลลังก์ในจงหยวน",
		"allies": ["f_east_sea"], "enemies": ["f_court", "f_beiliang", "f_xuancheng"] },
	"f_xuancheng": { "name": "เมืองเร้นเสวียนเฉิน", "align": "มาร", "bloc": "foreign", "great": false, "color": Color(0.4, 0.45, 0.6),
		"seat": "f_xuancheng_seat", "power": 35000, "style": "palm", "status_attack": "seal", "leader": "กุยฉางเซิง",
		"desc": "เศษซากราชวงศ์เสวียนอู่ใต้ภูเขาหิมะ รอสัญญาณให้เต่าดำผงาด",
		"allies": [], "enemies": ["f_court", "f_beiliang", "f_azure_dragon", "f_divine_temple", "f_xuanyuan"] },
}

## ขั้วอำนาจที่ใช้งานอยู่ (โหมดเนื้อเรื่อง = LORE_*, โหมดแซนด์บ็อกซ์ = สุ่มชื่อ/ที่ตั้ง/ความสัมพันธ์ใหม่ทั้งหมด)
static var BLOCS: Dictionary = LORE_BLOCS
static var FACTIONS: Dictionary = LORE_FACTIONS

const ALIGN_COLORS = { "ธรรมะ": Color(0.95, 0.85, 0.5), "กลาง": Color(0.7, 0.7, 0.7), "มาร": Color(0.9, 0.3, 0.3) }

## ค่าความสัมพันธ์เริ่มต้นกับสำนักเรา (สำนักเราเริ่มเป็นฝ่ายธรรมะเล็กๆ)
const START_RELATION = { "ธรรมะ": 10, "กลาง": 0, "มาร": -30 }

static func get_faction(id: String) -> Dictionary:
	return FACTIONS.get(id, {})

static func faction_at_seat(node_id: String) -> String:
	for id in FACTIONS:
		if FACTIONS[id].seat == node_id: return id
	return ""

static func great_sects() -> Array:
	return FACTIONS.keys().filter(func(id): return FACTIONS[id].great)

static func members_of(bloc: String) -> Array:
	return FACTIONS.keys().filter(func(id): return FACTIONS[id].bloc == bloc)

static func bloc_name(bloc: String) -> String:
	return BLOCS.get(bloc, {}).get("name", "")

## ความสัมพันธ์ตั้งต้นระหว่างสองขั้วอำนาจตามตำนาน (ก่อนสุ่มตาม Seed)
static func lore_relation(a: String, b: String) -> int:
	var fa = FACTIONS[a]
	var fb = FACTIONS[b]
	if fa.allies.has(b) or fb.allies.has(a): return 50
	if fa.enemies.has(b) or fb.enemies.has(a): return -60
	if fa.bloc == fb.bloc: return 25
	if (fa.align == "ธรรมะ" and fb.align == "มาร") or (fa.align == "มาร" and fb.align == "ธรรมะ"): return -35
	return 0

## ประเทศ/ฝ่ายที่เป็นที่ตั้งเมือง (ใช้ตอนที่เมืองไม่มีเจ้าเมือง)
static func default_city_lord() -> String:
	return "f_court"
