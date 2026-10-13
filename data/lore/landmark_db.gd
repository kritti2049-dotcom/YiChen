extends RefCounted
class_name LandmarkDB

## จุดสำคัญบนแผนที่โลก (Landmarks): เป้าหมายเฉพาะที่ทำให้ต้องออกไปนอกสำนัก
## - ore      = เส้นแร่หายาก ยึดครองถิ่นแล้วได้แร่เข้าคลังทุกวัน (rate = หน่วยต่อวัน คูณผลผลิตของถิ่น)
## - scripture = คัมภีร์วิชาลับ ยึดครองถิ่นแล้วได้วิชาเข้าหอตำรา (tier/type กำหนดวิชา สุ่มคงที่ต่อโลก)
## - relic    = ของวิเศษตำนาน ได้เมื่อยึดถิ่น หรือกวาดแดนลับ (get = "realm")
## ผู้เล่นต้อง "รู้" ก่อนจึงเห็นบนแผนที่: ข่าวลือจากนักเล่าข่าว, ส่งศิษย์ไปเยือนถิ่นนั้น, หรือเริ่มเกมด้วยข่าว 2 จุด

const LORE = [
	{ "id": "lm_black_iron", "node": "w_black_iron", "kind": "ore", "name": "เส้นแร่เหล็กเย็นภูเขาเหล็กดำ", "mat": "cold_iron", "rate": 2.0,
		"desc": "เส้นแร่เหล็กเย็นที่หลอมอาวุธชั้นเยี่ยมได้ ราชสำนักหมายตามานานแล้ว" },
	{ "id": "lm_snow_star", "node": "w_snow_peak", "kind": "ore", "name": "ตะกอนโลหะดาราบนยอดเขาหิมะ", "mat": "star_metal", "rate": 0.5,
		"desc": "โลหะดาราที่ตกจากฟ้าและสะสมใต้หิมะนิรันดร์ หายากที่สุดในแผ่นดิน" },
	{ "id": "lm_fire_crater", "node": "d_fire_crater", "kind": "ore", "name": "ผลึกวิญญาณในปล่องเพลิง", "mat": "spirit_stone", "rate": 1.5,
		"desc": "ผลึกวิญญาณที่เกิดจากไฟใต้พิภพ เสริมปราณและใช้ตั้งค่ายกล" },
	{ "id": "lm_scroll_tunnel", "node": "d_xuan_tunnels", "kind": "scripture", "name": "ศิลาจารึกเสวียนอู่", "tier": 4, "type": "",
		"desc": "คัมภีร์ที่อดีตราชวงศ์เสวียนอู่ซ่อนไว้ในนครใต้ดิน" },
	{ "id": "lm_scroll_spider", "node": "d_spider_nest", "kind": "scripture", "name": "ตำราพิษโลหิตของเผ่าแมงมุม", "tier": 3, "type": "poison",
		"desc": "สูตรพิษที่ถ่ายทอดกันในเผ่าแมงมุมโลหิตมาหลายชั่วอายุ" },
	{ "id": "lm_scroll_peaks", "node": "w_dragon_peaks", "kind": "scripture", "name": "ศิลาจารึกกระบี่มังกรเร้น", "tier": 3, "type": "sword",
		"desc": "รอยกระบี่บนหน้าผาที่ยอดฝีมือในอดีตทิ้งไว้ ผู้เข้าใจจะได้วิชา" },
	{ "id": "lm_scroll_prison", "node": "d_hawk_prison", "kind": "scripture", "name": "ตำราลับของหน่วยเหยี่ยว", "tier": 3, "type": "hidden_weapon",
		"desc": "ตำราอาวุธลับและการลอบสังหารที่ยึดมาจากนักโทษการเมือง" },
	{ "id": "lm_scroll_cove", "node": "d_pirate_cove", "kind": "scripture", "name": "ตำราฝ่ามือคลื่นยักษ์", "tier": 2, "type": "palm",
		"desc": "วิชาฝ่ามือของเจ้าโจรสลัดเก่า ซ่อนอยู่ในห้องใต้ถ้ำ" },
	{ "id": "lm_relic_realm", "node": "secret_realm", "kind": "relic", "get": "realm", "name": "ตราประทับสวรรค์บรรพกาล", "slot": "artifact",
		"desc": "ของวิเศษศักดิ์สิทธิ์ในแดนลับ มอบแก่ผู้กวาดคู่แข่งครบทุกคน" },
	{ "id": "lm_relic_demon", "node": "d_demon_valley", "kind": "relic", "name": "เกราะมารโบราณ", "slot": "armor",
		"desc": "เกราะที่จอมมารยุคก่อนทิ้งไว้ในหุบเขาหมื่นอสูร" },
]

## ชุดชื่อสำหรับโหมดแซนด์บ็อกซ์ (สุ่มจาก seed)
const SAND_ORES = [
	{ "mat": "cold_iron", "rate": 2.0, "name": "เส้นแร่เหล็กเย็น" },
	{ "mat": "star_metal", "rate": 0.5, "name": "ตะกอนโลหะดารา" },
	{ "mat": "spirit_stone", "rate": 1.5, "name": "ผลึกวิญญาณ" },
]
const SAND_STYLES = ["sword", "palm", "poison", "hidden_weapon", "internal", "formation"]
