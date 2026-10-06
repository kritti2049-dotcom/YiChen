extends Node
class_name SkillDB

## ฐานข้อมูลวิชาทั้ง 100 วิชา แบ่งเป็น 5 ระดับ (1-5)
## โหลดใช้งานด้วย SkillDB.get_skill("ชื่อวิชา")

enum Tier { MORTAL = 1, EARTH = 2, HEAVEN = 3, IMMORTAL = 4, DIVINE = 5 }

const SKILLS = {
	# ==========================================
	# ระดับ 1: ขั้นมนุษย์ (Mortal Tier) - 30 วิชา
	# ==========================================
	"หมัดคนตัดไม้": { "tier": Tier.MORTAL, "type": "palm", "desc": "วิชาหมัดพื้นฐานของชาวบ้าน", "power": 10 },
	"กระบี่ไม้ไผ่": { "tier": Tier.MORTAL, "type": "sword", "desc": "เพลงกระบี่สำหรับผู้เริ่มต้น", "power": 12 },
	"ก้าวลวงตา": { "tier": Tier.MORTAL, "type": "movement", "desc": "วิชาตัวเบาหลบหลีกพื้นฐาน", "power": 0 },
	"ปราณฟื้นฟู": { "tier": Tier.MORTAL, "type": "internal", "desc": "เดินลมปราณรักษาแผลเล็กน้อย", "power": 15 },
	"ดาบผ่าฟืน": { "tier": Tier.MORTAL, "type": "sword", "desc": "ฟันลงมาด้วยแรงกายล้วนๆ", "power": 15 },
	"ฝ่ามือทรายเหล็ก": { "tier": Tier.MORTAL, "type": "palm", "desc": "ฝ่ามือหยาบกระด้างที่ทุบหินแตก", "power": 14 },
	"เตะก้านกล้วย": { "tier": Tier.MORTAL, "type": "palm", "desc": "ลูกเตะตัดล่างที่รุนแรง", "power": 13 },
	"ปราณพื้นฐานสำนัก": { "tier": Tier.MORTAL, "type": "internal", "desc": "ลมปราณระดับต้นสำหรับศิษย์สายนอก", "power": 10 },
	"วิชาตัวเบาเหินน้ำ": { "tier": Tier.MORTAL, "type": "movement", "desc": "วิ่งบนผิวน้ำได้ระยะสั้นๆ", "power": 0 },
	"มีดสั้นบิน": { "tier": Tier.MORTAL, "type": "hidden_weapon", "desc": "ขว้างมีดสั้นออกไปอย่างแม่นยำ", "power": 11 },
	"หมัดพยัคฆ์คำราม": { "tier": Tier.MORTAL, "type": "palm", "desc": "ต่อยพร้อมส่งเสียงข่มขวัญศัตรู", "power": 16 },
	"เพลงกระบี่ใบหลิว": { "tier": Tier.MORTAL, "type": "sword", "desc": "เพลงกระบี่ที่พริ้วไหวแต่ไร้น้ำหนัก", "power": 11 },
	"โล่ปราณคุ้มกาย": { "tier": Tier.MORTAL, "type": "internal", "desc": "สร้างเกราะปราณบางๆ คลุมผิวหนัง", "power": 20 }, # defensive power
	"พิษงูเขียว": { "tier": Tier.MORTAL, "type": "poison", "desc": "เคลือบพิษอ่อนๆ บนอาวุธ", "power": 5 },
	"ฝ่ามือศิลา": { "tier": Tier.MORTAL, "type": "palm", "desc": "ฝ่ามือที่หนักแน่นดุจหินผา", "power": 15 },
	"เพลงดาบพายุหมุน": { "tier": Tier.MORTAL, "type": "sword", "desc": "หมุนตัวฟันรอบทิศทาง", "power": 14 },
	"เข็มอาบยาพิษ": { "tier": Tier.MORTAL, "type": "hidden_weapon", "desc": "ซัดเข็มพิษลอบทำร้าย", "power": 12 },
	"ค่ายกลสามเส้า": { "tier": Tier.MORTAL, "type": "formation", "desc": "ค่ายกลพื้นฐานใช้ 3 คนรุม 1", "power": 25 },
	"ปราณรวมศูนย์": { "tier": Tier.MORTAL, "type": "internal", "desc": "รวบรวมสมาธิเพิ่มแม่นยำ 1 เทิร์น", "power": 0 },
	"กระบี่ทะลวงใจ": { "tier": Tier.MORTAL, "type": "sword", "desc": "แทงตรงไปข้างหน้าอย่างรวดเร็ว", "power": 18 },
	"หมัดรัวดาวตก": { "tier": Tier.MORTAL, "type": "palm", "desc": "ต่อยรัว 3 หมัดซ้อน", "power": 15 },
	"ก้าวถอยหลังร้อยลี้": { "tier": Tier.MORTAL, "type": "movement", "desc": "วิชาหลบหนีฉุกเฉิน", "power": 0 },
	"เพลงดาบเสี้ยวจันทร์": { "tier": Tier.MORTAL, "type": "sword", "desc": "ฟันดาบเป็นรูปจันทร์เสี้ยว", "power": 16 },
	"ฝ่ามือวารี": { "tier": Tier.MORTAL, "type": "palm", "desc": "ใช้ความนุ่มนวลสยบความแข็งกร้าว", "power": 12 },
	"ลมหายใจเต่า": { "tier": Tier.MORTAL, "type": "internal", "desc": "กลั้นหายใจซ่อนเร้นรังสีอำมหิต", "power": 0 },
	"ผงพรางตา": { "tier": Tier.MORTAL, "type": "hidden_weapon", "desc": "ปาผงเข้าตาเพื่อหนีหรือสร้างจังหวะ", "power": 0 },
	"วิชาสกัดจุด": { "tier": Tier.MORTAL, "type": "palm", "desc": "จี้จุดให้ศัตรูขยับไม่ได้ชั่วขณะ", "power": 5 },
	"ปราณชำระกระดูก": { "tier": Tier.MORTAL, "type": "internal", "desc": "เสริมสร้างร่างกายให้ทนทานขึ้น", "power": 25 },
	"เพลงดาบทหารเลว": { "tier": Tier.MORTAL, "type": "sword", "desc": "ดาบที่เน้นฆ่าฟันในสนามรบ", "power": 17 },
	"หมัดเมา": { "tier": Tier.MORTAL, "type": "palm", "desc": "ท่วงท่าคาดเดายาก แต่ความแม่นยำต่ำ", "power": 19 },

	# ==========================================
	# ระดับ 2: ขั้นปฐพี (Earth Tier) - 30 วิชา
	# ==========================================
	"เพลงกระบี่ไร้เงา": { "tier": Tier.EARTH, "type": "sword", "desc": "กระบี่รวดเร็วจนมองไม่เห็นเงา", "power": 30 },
	"ปราณวารี": { "tier": Tier.EARTH, "type": "internal", "desc": "ลมปราณที่ลื่นไหล ฟื้นฟูบาดแผลต่อเนื่อง", "power": 35 },
	"ฝ่ามือทลายผา": { "tier": Tier.EARTH, "type": "palm", "desc": "ฝ่ามือที่อัดแน่นด้วยปราณ ทำลายชุดเกราะ", "power": 35 },
	"วิชาตัวเบาเหยียบเมฆ": { "tier": Tier.EARTH, "type": "movement", "desc": "กระโดดเหยียบอากาศกลางเวหา", "power": 0 },
	"ดาบอัคคีผลาญ": { "tier": Tier.EARTH, "type": "sword", "desc": "ฟันดาบพร้อมเปลวเพลิงไหม้ศัตรู", "power": 40 },
	"พิษแมงมุมมรณะ": { "tier": Tier.EARTH, "type": "poison", "desc": "พิษร้ายแรงที่กัดกร่อนลมปราณ", "power": 25 },
	"หมัดมังกรผงาด": { "tier": Tier.EARTH, "type": "palm", "desc": "ต่อยเสยขึ้นฟ้าพร้อมปราณมังกร", "power": 38 },
	"ค่ายกลกระบี่เจ็ดดาว": { "tier": Tier.EARTH, "type": "formation", "desc": "ค่ายกลประสาน 7 คน เพิ่มพลังโจมตีกลุ่ม", "power": 50 },
	"ปราณระฆังทอง": { "tier": Tier.EARTH, "type": "internal", "desc": "กางระฆังลมปราณป้องกันการโจมตีทุกทิศ", "power": 45 },
	"ดาวกระจายไร้เสียง": { "tier": Tier.EARTH, "type": "hidden_weapon", "desc": "ซัดอาวุธลับที่ไม่มีเสียงแหวกอากาศ", "power": 28 },
	"เพลงกระบี่หยาดพิรุณ": { "tier": Tier.EARTH, "type": "sword", "desc": "แทงรัวดั่งสายฝนโปรยปราย", "power": 32 },
	"ฝ่ามือสยบพยัคฆ์": { "tier": Tier.EARTH, "type": "palm", "desc": "กระบวนท่ากดทับศัตรูให้ติดพื้น", "power": 34 },
	"ก้าวย่างอัสนี": { "tier": Tier.EARTH, "type": "movement", "desc": "เคลื่อนที่ว่องไวดุจสายฟ้าฟาด", "power": 0 },
	"ดาบตัดปฐพี": { "tier": Tier.EARTH, "type": "sword", "desc": "ฟันลงพื้นสร้างคลื่นกระแทก", "power": 36 },
	"ปราณเหน็บหนาว": { "tier": Tier.EARTH, "type": "internal", "desc": "ลมปราณแช่แข็ง ลดความเร็วศัตรู", "power": 20 },
	"พิษคางคกน้ำแข็ง": { "tier": Tier.EARTH, "type": "poison", "desc": "พิษที่ทำให้เลือดแข็งตัวเรื้อรัง", "power": 30 },
	"หมัดทะลวงเกราะ": { "tier": Tier.EARTH, "type": "palm", "desc": "หมัดที่ส่งลมปราณระเบิดทะลุภายใน", "power": 42 },
	"ค่ายกลลวงตา": { "tier": Tier.EARTH, "type": "formation", "desc": "สร้างภาพลวงตาให้ศัตรูสับสน", "power": 0 },
	"ปราณเหล็กไหล": { "tier": Tier.EARTH, "type": "internal", "desc": "เปลี่ยนผิวหนังให้แข็งดุจเหล็กชั่วคราว", "power": 50 },
	"เข็มไร้เงาตามติด": { "tier": Tier.EARTH, "type": "hidden_weapon", "desc": "เข็มที่โค้งเลี้ยวตามเป้าหมายได้", "power": 35 },
	"กระบี่บินทะลวง": { "tier": Tier.EARTH, "type": "sword", "desc": "ซัดกระบี่ออกไปและเรียกกลับคืนได้", "power": 38 },
	"เพลงดาบพยัคฆ์ขาว": { "tier": Tier.EARTH, "type": "sword", "desc": "เน้นความดุดันและการเข้าประชิด", "power": 39 },
	"ฝ่ามือดูดดาว (ขั้นต้น)": { "tier": Tier.EARTH, "type": "internal", "desc": "ดูดซับลมปราณศัตรูมาเป็นของตนทีละน้อย", "power": 20 },
	"ก้าวข้ามมิติ": { "tier": Tier.EARTH, "type": "movement", "desc": "วาร์ประยะสั้นเพื่อหลบการโจมตีคริติคอล", "power": 0 },
	"ระเบิดปราณควัน": { "tier": Tier.EARTH, "type": "hidden_weapon", "desc": "ระเบิดควันทำลายทัศนวิสัย", "power": 10 },
	"วิชาสกัดจุดชีพจร": { "tier": Tier.EARTH, "type": "palm", "desc": "สกัดเส้นลมปราณศัตรูไม่ให้ใช้สกิลได้", "power": 15 },
	"ปราณมังกรเขียว": { "tier": Tier.EARTH, "type": "internal", "desc": "ฟื้นฟูอาการบาดเจ็บหนักและล้างพิษ", "power": 50 },
	"กระบี่ผ่าคลื่น": { "tier": Tier.EARTH, "type": "sword", "desc": "ฟันออกไปเป็นคลื่นลมปราณรูปดาบ", "power": 33 },
	"หมัดดาวเหนือ": { "tier": Tier.EARTH, "type": "palm", "desc": "โจมตีจุดตาย 7 จุดในพริบตา", "power": 45 },
	"ค่ายกลศิลาขังมาร": { "tier": Tier.EARTH, "type": "formation", "desc": "กักขังศัตรูไว้ในเขตแดนหิน", "power": 0 },

	# ==========================================
	# ระดับ 3: ขั้นนภา (Heaven Tier) - 20 วิชา
	# ==========================================
	"กระบี่เหินนภา": { "tier": Tier.HEAVEN, "type": "sword", "desc": "ขี่กระบี่บินร่อนกลางอากาศ โจมตีจากมุมสูง", "power": 65 },
	"ปราณสุริยัน": { "tier": Tier.HEAVEN, "type": "internal", "desc": "ลมปราณร้อนแรงดั่งดวงอาทิตย์ เผาผลาญศัตรูรอบตัว", "power": 70 },
	"ฝ่ามือยูไล": { "tier": Tier.HEAVEN, "type": "palm", "desc": "ฝ่ามือทองคำยักษ์ประทับจากฟากฟ้า", "power": 80 },
	"เก้าก้าวท่องสวรรค์": { "tier": Tier.HEAVEN, "type": "movement", "desc": "เคล็ดวิชาตัวเบาที่รวดเร็วดุจแสง", "power": 0 },
	"พิษไร้สีไร้กลิ่น": { "tier": Tier.HEAVEN, "type": "poison", "desc": "สุดยอดพิษที่แม้แต่ผู้ใช้ปราณก็จับไม่ได้", "power": 60 },
	"ค่ายกลกระบี่หมื่นเล่ม": { "tier": Tier.HEAVEN, "type": "formation", "desc": "สร้างเงากระบี่นับหมื่นจู่โจมเป็นพื้นที่", "power": 85 },
	"ดาบผ่าสวรรค์": { "tier": Tier.HEAVEN, "type": "sword", "desc": "ฟันรอยแยกมิติ สร้างความเสียหายทะลุเกราะ", "power": 75 },
	"ปราณจันทราน้ำแข็ง": { "tier": Tier.HEAVEN, "type": "internal", "desc": "แช่แข็งศัตรูทั้งสนามรบ", "power": 65 },
	"ฝ่ามือเปลี่ยนเส้นเอ็น": { "tier": Tier.HEAVEN, "type": "palm", "desc": "ทำลายฐานรากลมปราณศัตรูถาวร", "power": 70 },
	"เข็มทะลวงวิญญาณ": { "tier": Tier.HEAVEN, "type": "hidden_weapon", "desc": "โจมตีโดยตรงที่จิตวิญญาณ ไม่สนพลังป้องกันกายภาพ", "power": 80 },
	"เพลงกระบี่ไท่เก๊ก": { "tier": Tier.HEAVEN, "type": "sword", "desc": "สะท้อนการโจมตีทั้งหมดกลับไป 2 เท่า", "power": 50 },
	"ปราณเกราะเพชร": { "tier": Tier.HEAVEN, "type": "internal", "desc": "อมตะชั่วขณะจากการโจมตีทุกชนิด", "power": 100 },
	"หมัดทะลวงมิติ": { "tier": Tier.HEAVEN, "type": "palm", "desc": "ต่อยข้ามมิติ ไม่สามารถหลบหลีกได้", "power": 78 },
	"ค่ายกลแปดทิศ": { "tier": Tier.HEAVEN, "type": "formation", "desc": "บัฟสถานะทุกอย่างให้เพื่อนในสำนัก", "power": 0 },
	"ฝ่ามือดูดดาว (ขั้นสมบูรณ์)": { "tier": Tier.HEAVEN, "type": "internal", "desc": "ดูดพลังศัตรูมาเพิ่ม HP/MP ตนเองมหาศาล", "power": 60 },
	"ดาบสะบั้นกรรม": { "tier": Tier.HEAVEN, "type": "sword", "desc": "ยิ่งศัตรูฆ่าคนมาก ยิ่งโดนแรงขึ้น", "power": 85 },
	"พฤกษาคืนชีพ": { "tier": Tier.HEAVEN, "type": "internal", "desc": "ชุบชีวิตเพื่อนร่วมทีมที่เพิ่งตาย", "power": 0 },
	"พิษหมื่นพิษหลอมรวม": { "tier": Tier.HEAVEN, "type": "poison", "desc": "รวมพิษทั้งหมดระเบิดออกรอบตัว", "power": 75 },
	"ก้าวอัสนีไร้ขอบเขต": { "tier": Tier.HEAVEN, "type": "movement", "desc": "พุ่งชนศัตรูพร้อมสายฟ้า ทำความเสียหายขณะเคลื่อนที่", "power": 65 },
	"กระบี่จิตสั่งตาย": { "tier": Tier.HEAVEN, "type": "sword", "desc": "ล็อกเป้าหมายด้วยจิตวิญญาณ กระบี่จะตามล่าจนกว่าจะตาย", "power": 88 },

	# ==========================================
	# ระดับ 4: ขั้นเซียน (Immortal Tier) - 15 วิชา
	# ==========================================
	"เขตแดนกระบี่เทพ": { "tier": Tier.IMMORTAL, "type": "sword", "desc": "กางอาณาเขต (Domain) ที่เต็มไปด้วยปราณกระบี่", "power": 120 },
	"ปราณฟ้าดินหลอมรวม": { "tier": Tier.IMMORTAL, "type": "internal", "desc": "ยืมพลังบรรพกาล เพิ่มพลังทุกด้าน 500%", "power": 0 },
	"ดรรชนีสยบมาร": { "tier": Tier.IMMORTAL, "type": "palm", "desc": "นิ้วเดียวทำลายขุนเขา ลบศัตรูระดับต่ำกว่าออกจากแมพ", "power": 150 },
	"ค่ายกลประหารเซียน": { "tier": Tier.IMMORTAL, "type": "formation", "desc": "ค่ายกลระดับตำนานที่สังหารผู้ฝึกตนขั้นสูงได้", "power": 200 },
	"ดาบผ่าดารา": { "tier": Tier.IMMORTAL, "type": "sword", "desc": "ฟันแยกลวงดาว ทำความเสียหายวงกว้างมหาศาล", "power": 140 },
	"วิถีวัฏสงสาร": { "tier": Tier.IMMORTAL, "type": "internal", "desc": "เมื่อตายจะฟื้นคืนชีพพร้อมพลังที่มากกว่าเดิม", "power": 0 },
	"ฝ่ามือพลิกฟ้าพลิกดิน": { "tier": Tier.IMMORTAL, "type": "palm", "desc": "สลับสเตตัส HP ศัตรูกับตนเอง", "power": 0 },
	"วิชาตัวเบาท่องอวกาศ": { "tier": Tier.IMMORTAL, "type": "movement", "desc": "เคลื่อนที่ข้ามโซนแผนที่โลกในพริบตา", "power": 0 },
	"ทะเลพิษกัดกร่อนเซียน": { "tier": Tier.IMMORTAL, "type": "poison", "desc": "เปลี่ยนพื้นที่รอบๆ เป็นบึงพิษที่ไม่มีใครรักษาได้", "power": 130 },
	"กงล้อเวลา": { "tier": Tier.IMMORTAL, "type": "internal", "desc": "เร่งหรือย้อนเวลาเทิร์นในการต่อสู้", "power": 0 },
	"เนตรเทวะดับสูญ": { "tier": Tier.IMMORTAL, "type": "hidden_weapon", "desc": "โจมตีด้วยการมอง ลบวิชาของศัตรูทิ้ง", "power": 110 },
	"กระบี่หนึ่งเดียวเป็นศูนย์": { "tier": Tier.IMMORTAL, "type": "sword", "desc": "ทิ้งกระบวนท่าทั้งหมดเหลือเพียงการแทงที่ไม่มีใครรับได้", "power": 160 },
	"มังกรบรรพกาลจุติ": { "tier": Tier.IMMORTAL, "type": "palm", "desc": "อัญเชิญเงาดราก้อนมาโจมตีพร้อมกับตน", "power": 145 },
	"ปราณดาราจักร": { "tier": Tier.IMMORTAL, "type": "internal", "desc": "ดึงพลังจากหมู่ดาวมาฟื้นฟูและสร้างเกราะสะท้อน", "power": 130 },
	"ค่ายกลผนึกสวรรค์": { "tier": Tier.IMMORTAL, "type": "formation", "desc": "แช่แข็งเวลาและสกิลของศัตรูทั้งสนาม", "power": 0 },

	# ==========================================
	# ระดับ 5: ขั้นเทวะ (Divine Tier) - 5 วิชา (สุดยอดวิชาแห่งเกม)
	# ==========================================
	"บัญญัติพระเจ้าสร้างโลก": { "tier": Tier.DIVINE, "type": "internal", "desc": "ปรับเปลี่ยนกฎของสนามรบได้ตามใจชอบ", "power": 999 },
	"กระบี่ผ่าอนันต์": { "tier": Tier.DIVINE, "type": "sword", "desc": "ทำลายทุกสรรพสิ่ง ปฏิเสธการป้องกันและอมตะทุกรูปแบบ", "power": 999 },
	"ฝ่ามือลบหล้างตัวตน": { "tier": Tier.DIVINE, "type": "palm", "desc": "ลบเป้าหมายออกจากระบบจักรวาล (ลบ Data ศัตรู)", "power": 999 },
	"ค่ายกลเอกภพ": { "tier": Tier.DIVINE, "type": "formation", "desc": "สร้างมิติเอกเทศ กักขังและดูดกลืนพลังศัตรูทั้งเซิร์ฟ/แมพ", "power": 999 },
	"วิถีเซียนไร้ขอบเขต": { "tier": Tier.DIVINE, "type": "internal", "desc": "ผสานเป็นหนึ่งเดียวกับระบบเกม พลังทุกด้านคือ ∞", "power": 999 }
}

## ดึงข้อมูลวิชา
static func get_skill(skill_name: String) -> Dictionary:
	if SKILLS.has(skill_name):
		return SKILLS[skill_name]
	return {}

## สุ่มวิชาตามระดับ (Tier) เอาไว้ใช้เวลาดรอปหนังสือสกิล
static func get_random_skill_by_tier(target_tier: int) -> String:
	var pool = []
	for skill_name in SKILLS:
		if SKILLS[skill_name].tier == target_tier:
			pool.append(skill_name)
	
	if pool.size() > 0:
		return pool.pick_random()
	return ""
