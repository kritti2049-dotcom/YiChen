extends Node
class_name WorldDB

## แผนที่โลก "พิภพโลหิตชาด" อิงตามตำนาน: 5 มณฑลของแคว้นต้าเยี่ย + 6 ดินแดนชายขอบ
## ตำแหน่งมณฑล เมือง และที่ตั้งสำนักทุกแห่งตายตัว (cell = พิกัดช่องบนแผนที่ 100x70, ทิศเหนืออยู่บน)
## Seed ของแต่ละเซฟไม่สุ่มตำแหน่ง แต่สุ่ม ความสัมพันธ์ / เจ้าเมือง / ผลผลิต / เหตุการณ์ (ดู FactionSys.init_world)
## โหมดเนื้อเรื่องใช้ข้อมูล LORE_* ตายตัว / โหมดแซนด์บ็อกซ์ "โกลาหลยุทธภพ" แทนที่ REGIONS / NODES / START_SITES
## ด้วยข้อมูลที่สุ่มใหม่ทั้งหมด (ดู WorldMode และ SandboxGen) โค้ดอื่นอ่านผ่าน WorldDB.NODES เหมือนเดิม

enum NodeType { SECT, CITY, WILD, DUNGEON, SECRET_REALM, RIVAL_SECT, GREAT_SECT }

const TYPE_NAMES = ["สำนัก", "เมือง", "พื้นที่ป่า", "ดันเจี้ยน", "แดนลับ", "ฐานที่มั่น", "สำนักใหญ่"]
const TYPE_COLORS = [Color(1.0, 0.85, 0.4), Color(0.55, 0.8, 1.0), Color(0.45, 0.85, 0.45), Color(0.9, 0.35, 0.35), Color(0.8, 0.5, 1.0), Color(1.0, 0.5, 0.3), Color(1.0, 0.95, 0.75)]

## ภูมิภาค: kind = "province" (มณฑลของต้าเยี่ย) / "frontier" (ดินแดนชายขอบ)
## center = จุดศูนย์กลาง (ใช้แบ่งเขตแบบ Voronoi), label = ตำแหน่งป้ายชื่อบนแผนที่, palette = ลำดับภูมิประเทศตามความสูง [[เพดาน, Biome], ...]
const LORE_REGIONS = {
	"jingji": { "name": "มณฑลจิงจี", "kind": "province", "center": Vector2i(57, 31), "label": Vector2i(60, 38),
		"desc": "หัวใจของแคว้นต้าเยี่ย ที่ตั้งนครหลวงเมฆาโลหิตและรังของสิบขันทีเงา",
		"palette": [[-0.55, WorldGen.Biome.WATER], [0.25, WorldGen.Biome.GRASS], [0.42, WorldGen.Biome.FOREST], [1.0, WorldGen.Biome.HILLS]] },
	"jiangnan": { "name": "มณฑลเจียงหนาน", "kind": "province", "center": Vector2i(72, 46), "label": Vector2i(73, 54),
		"desc": "แดนใต้ผู้อุดมสมบูรณ์ ขุมทรัพย์ของแผ่นดิน ถิ่นของพ่อค้าและตระกูลหนานกง",
		"palette": [[-0.35, WorldGen.Biome.WATER], [0.25, WorldGen.Biome.GRASS], [1.0, WorldGen.Biome.FOREST]] },
	"shanxi": { "name": "มณฑลซานซี", "kind": "province", "center": Vector2i(57, 17), "label": Vector2i(55, 22),
		"desc": "แดนเหนือแห่งการทหารและปราการเหล็ก ยันชนเผ่าทุ่งหญ้า",
		"palette": [[-0.6, WorldGen.Biome.WATER], [0.05, WorldGen.Biome.GRASS], [0.3, WorldGen.Biome.HILLS], [1.0, WorldGen.Biome.MOUNTAIN]] },
	"shaanxi": { "name": "มณฑลส่านซี", "kind": "province", "center": Vector2i(36, 30), "label": Vector2i(37, 25),
		"desc": "แดนประจิม ประตูสู่เส้นทางสายไหมและดินแดนลี้ลับ",
		"palette": [[-0.6, WorldGen.Biome.WATER], [0.0, WorldGen.Biome.GRASS], [0.25, WorldGen.Biome.HILLS], [1.0, WorldGen.Biome.MOUNTAIN]] },
	"sichuan": { "name": "มณฑลเสฉวน", "kind": "province", "center": Vector2i(44, 47), "label": Vector2i(42, 41),
		"desc": "หุบเขาลับแลทางตะวันตกเฉียงใต้ ถิ่นของตระกูลถังและบู๊ตึง",
		"palette": [[-0.5, WorldGen.Biome.WATER], [-0.05, WorldGen.Biome.FOREST], [0.25, WorldGen.Biome.HILLS], [1.0, WorldGen.Biome.MOUNTAIN]] },
	"south_poison": { "name": "ดินแดนร้อยพิษแดนใต้", "kind": "frontier", "center": Vector2i(46, 61), "label": Vector2i(47, 66),
		"desc": "ป่าดงดิบชื้นแฉะที่ไอพิษคละคลุ้ง ฐานของกลุ่มร้อยเผ่าและพรรคมารอัสดง",
		"palette": [[-0.35, WorldGen.Biome.WATER], [0.4, WorldGen.Biome.FOREST], [1.0, WorldGen.Biome.HILLS]] },
	"hidden_dragon": { "name": "เทือกเขามังกรเร้น", "kind": "frontier", "center": Vector2i(23, 33), "label": Vector2i(21, 45),
		"desc": "เทือกเขาสูงชันปกคลุมด้วยหมอก สถานที่ศักดิ์สิทธิ์และอันตราย",
		"palette": [[-0.3, WorldGen.Biome.FOREST], [0.05, WorldGen.Biome.HILLS], [0.4, WorldGen.Biome.MOUNTAIN], [1.0, WorldGen.Biome.SNOW]] },
	"north_steppe": { "name": "ทุ่งหญ้าเยือกแข็งแดนอุดร", "kind": "frontier", "center": Vector2i(55, 6), "label": Vector2i(52, 3),
		"desc": "ทุ่งหญ้าไร้ขอบเขตใต้พายุหิมะ ถิ่นของข่านสงครามเตมูร์และป้อมหยกขาว",
		"palette": [[-0.6, WorldGen.Biome.WATER], [0.15, WorldGen.Biome.GRASS], [0.35, WorldGen.Biome.HILLS], [1.0, WorldGen.Biome.SNOW]] },
	"east_coast": { "name": "ชายฝั่งวายุคร่ำและทะเลบูรพา", "kind": "frontier", "center": Vector2i(84, 32), "label": Vector2i(92, 30),
		"desc": "ชายฝั่งไร้กฎหมาย รังของโจรสลัด และเกาะลี้ลับของวังมังกรคราม",
		"palette": [[-0.15, WorldGen.Biome.SAND], [0.35, WorldGen.Biome.GRASS], [1.0, WorldGen.Biome.FOREST]] },
	"west_waste": { "name": "ดินแดนรกร้างตะวันตก", "kind": "frontier", "center": Vector2i(9, 37), "label": Vector2i(8, 49),
		"desc": "ทะเลทรายอันแห้งแล้ง ที่ตั้งของโอเอซิสหมื่นดาราและเทือกเขาเพลิงอัสดง",
		"palette": [[-0.65, WorldGen.Biome.GRASS], [0.3, WorldGen.Biome.SAND], [0.5, WorldGen.Biome.HILLS], [1.0, WorldGen.Biome.MOUNTAIN]] },
	"nw_underground": { "name": "นครใต้ดินทิศพายัพ", "kind": "frontier", "center": Vector2i(11, 10), "label": Vector2i(10, 3),
		"desc": "ภูเขาหิมะนิรันดร์ที่ซ่อนนครศิลาของอดีตราชวงศ์เสวียนอู่",
		"palette": [[-0.3, WorldGen.Biome.HILLS], [0.15, WorldGen.Biome.MOUNTAIN], [1.0, WorldGen.Biome.SNOW]] },
}

## เกาะมังกรเร้น (ทะเลบูรพา) ศูนย์กลางและรัศมีของเกาะ
const ISLAND_CENTER = Vector2i(94, 40)
const ISLAND_RADIUS = Vector2(4.0, 5.0)

## แม่น้ำสายหลัก (วาดเป็นแหล่งน้ำตื้น ล่องเรือข้ามได้)
const RIVERS = [
	[Vector2i(30, 24), Vector2i(40, 26), Vector2i(48, 26), Vector2i(56, 25), Vector2i(66, 24), Vector2i(76, 22), Vector2i(87, 20)],
	[Vector2i(36, 44), Vector2i(44, 44), Vector2i(54, 45), Vector2i(64, 46), Vector2i(72, 47), Vector2i(80, 46), Vector2i(87, 45)],
]

## จุดตั้งสำนักของผู้เล่น (เลือกตอนสร้างตัวละคร)
const LORE_START_SITES = [
	{ "id": "site_jingji", "name": "เนินเขาริมแม่น้ำลั่ว", "region": "jingji", "cell": Vector2i(54, 37) },
	{ "id": "site_jiangnan", "name": "ริมทะเลสาบไท่หู", "region": "jiangnan", "cell": Vector2i(73, 40) },
	{ "id": "site_shanxi", "name": "หุบเขาลมเหนือ", "region": "shanxi", "cell": Vector2i(47, 19) },
	{ "id": "site_shaanxi", "name": "ที่ราบเชิงเขาฉินหลิง", "region": "shaanxi", "cell": Vector2i(39, 36) },
	{ "id": "site_sichuan", "name": "หุบเขาเมฆเขียว", "region": "sichuan", "cell": Vector2i(44, 51) },
]

## สถานที่สำคัญทั้งหมด
## เมือง: shop, price_mult, sell_rate, shop_rarity, auction, lords (ขั้วอำนาจที่อาจได้เป็นเจ้าเมือง สุ่มตาม Seed)
## ป่า/ดันเจี้ยน: enemies, gather (วัตถุดิบ [ต่ำสุด, สูงสุด] ต่อวัน ก่อนคูณผลผลิตตาม Seed)
## ฐานที่มั่น/สำนักใหญ่: faction (ดู FactionDB)
const LORE_NODES = {
	"sect": {
		"name": "สำนักของเรา", "type": NodeType.SECT, "region": "",
		"desc": "ที่มั่นของสำนัก ศิษย์ทุกคนออกเดินทางจากที่นี่",
	},
	# ══════════ มณฑลจิงจี ══════════
	"c_xueyun": {
		"name": "นครเมฆาโลหิต", "type": NodeType.CITY, "region": "jingji", "cell": Vector2i(58, 30),
		"desc": "เมืองหลวงของต้าเยี่ย ที่ประทับของจักรพรรดิ รังของสิบขันที และสถานที่จัดงานประลองยุทธ์หลวง",
		"shop": ["spirit_grass", "blood_ginseng", "iron_ore", "cold_iron", "beast_hide", "spirit_stone"],
		"price_mult": 1.3, "sell_rate": 0.65, "shop_rarity": 2, "auction": true, "lords": ["f_eunuchs", "f_court"],
	},
	"c_luoyang": {
		"name": "นครลั่วหยาง", "type": NodeType.CITY, "region": "jingji", "cell": Vector2i(52, 27),
		"desc": "ศูนย์กลางการค้าริมแม่น้ำลั่ว จอมยุทธ์ปะทะกันบ่อยครั้ง ที่ตั้งคฤหาสน์ตระกูลมู่",
		"shop": ["spirit_grass", "iron_ore", "beast_hide", "wood", "stone"],
		"price_mult": 1.0, "sell_rate": 0.6, "shop_rarity": 1, "auction": true, "lords": ["f_mu", "f_court"],
	},
	"c_kaifeng": {
		"name": "เมืองไคเฟิง", "type": NodeType.CITY, "region": "jingji", "cell": Vector2i(64, 34),
		"desc": "ศูนย์กลางของพรรคกระยาจกและจุดบรรจบเส้นทางการค้า",
		"shop": ["spirit_grass", "iron_ore", "beast_hide", "wood"],
		"price_mult": 0.9, "sell_rate": 0.5, "shop_rarity": 0, "auction": false, "lords": ["f_court", "f_beggar"],
	},
	"f_golden_luohan_seat": {
		"name": "อารามอรหันต์ซงซาน", "type": NodeType.GREAT_SECT, "region": "jingji", "cell": Vector2i(50, 32), "faction": "f_golden_luohan",
		"desc": "อารามศักดิ์สิทธิ์บนยอดเขาอานม้า แหล่งกำเนิดยอดวิชากายาที่แข็งแกร่งที่สุดในใต้หล้า",
	},
	"w_songshan_forest": {
		"name": "ป่าเชิงเขาซงซาน", "type": NodeType.WILD, "region": "jingji", "cell": Vector2i(54, 34),
		"desc": "ป่าเชิงเขาที่โจรป่าและหมาป่าชอบซุ่มดักทำร้ายผู้แสวงบุญ",
		"enemies": ["bandit_thug", "forest_wolf"], "gather": { "spirit_grass": [2, 6], "wood": [3, 6] },
	},
	"d_hawk_prison": {
		"name": "คุกลับหอคอยทมิฬ", "type": NodeType.DUNGEON, "region": "jingji", "cell": Vector2i(62, 28),
		"desc": "คุกลับของหน่วยเหยี่ยวชาด ว่ากันว่าคัมภีร์ของตระกูลที่ถูกกวาดล้างถูกเก็บไว้ที่นี่",
		"enemies": ["hawk_guard", "bandit_thug"], "gather": { "cold_iron": [0, 2], "scripture_fragment": [0, 1] },
	},
	# ══════════ มณฑลเจียงหนาน ══════════
	"c_jinling": {
		"name": "นครจินหลิง", "type": NodeType.CITY, "region": "jiangnan", "cell": Vector2i(70, 44),
		"desc": "นครเอกทางใต้ ร่ำรวยที่สุดในแผ่นดิน ที่ตั้งของสมาคมการค้าเฉินว่าน",
		"shop": ["spirit_grass", "blood_ginseng", "iron_ore", "cold_iron", "beast_hide", "spirit_stone", "wood"],
		"price_mult": 1.15, "sell_rate": 0.75, "shop_rarity": 2, "auction": true, "lords": ["f_chenwan", "f_court", "f_south_tiger"],
	},
	"c_suzhou": {
		"name": "เมืองซูโจว", "type": NodeType.CITY, "region": "jiangnan", "cell": Vector2i(77, 41),
		"desc": "เมืองท่าสายน้ำอันงดงาม ฐานที่มั่นของตระกูลหนานกง",
		"shop": ["spirit_grass", "blood_ginseng", "beast_hide"],
		"price_mult": 1.05, "sell_rate": 0.6, "shop_rarity": 1, "auction": false, "lords": ["f_nangong", "f_court"],
	},
	"c_hangzhou": {
		"name": "เมืองหางโจว", "type": NodeType.CITY, "region": "jiangnan", "cell": Vector2i(78, 50),
		"desc": "แหล่งกบดานของสมาคมลับและโจรปล้นเรือ ของเถื่อนหาซื้อได้ไม่ยาก",
		"shop": ["blood_ginseng", "cold_iron", "beast_core", "snow_lotus", "star_metal"],
		"price_mult": 1.4, "sell_rate": 0.8, "shop_rarity": 2, "auction": true, "lords": ["f_east_sea", "f_nangong", "f_court"],
	},
	"c_wuhan": {
		"name": "เมืองอู่ฮั่น", "type": NodeType.CITY, "region": "jiangnan", "cell": Vector2i(63, 47),
		"desc": "ศูนย์กลางการขนส่งทางน้ำของแม่น้ำแยงซีเกียง",
		"shop": ["spirit_grass", "iron_ore", "wood", "stone"],
		"price_mult": 0.95, "sell_rate": 0.55, "shop_rarity": 0, "auction": false, "lords": ["f_court", "f_chenwan"],
	},
	"f_south_tiger_seat": {
		"name": "คฤหาสน์พยัคฆ์คำรณ", "type": NodeType.RIVAL_SECT, "region": "jiangnan", "cell": Vector2i(67, 41), "faction": "f_south_tiger",
		"desc": "คฤหาสน์ชายป่าไผ่รอบนอกจินหลิง ของตระกูลที่แยกตัวจากหนานกง",
	},
	"w_yangtze_marsh": {
		"name": "บึงริมแยงซี", "type": NodeType.WILD, "region": "jiangnan", "cell": Vector2i(69, 50),
		"desc": "บึงกว้างริมแม่น้ำที่โจรปล้นเรือซ่องสุม อุดมด้วยสมุนไพร",
		"enemies": ["pirate", "bandit_thug"], "gather": { "spirit_grass": [3, 7], "blood_ginseng": [0, 1] },
	},
	# ══════════ มณฑลซานซี ══════════
	"c_beijing": {
		"name": "นครเป่ยจิง", "type": NodeType.CITY, "region": "shanxi", "cell": Vector2i(56, 17),
		"desc": "เมืองหน้าด่านทิศเหนือ ป้อมปราการทหารที่ใหญ่ที่สุด ที่ตั้งคฤหาสน์ทวนคุณธรรมของตระกูลหมิง",
		"shop": ["iron_ore", "cold_iron", "beast_hide", "stone"],
		"price_mult": 1.0, "sell_rate": 0.6, "shop_rarity": 1, "auction": false, "lords": ["f_lei", "f_court", "f_ming"],
	},
	"f_lei_seat": {
		"name": "ป้อมยอดเขาทมิฬ", "type": NodeType.GREAT_SECT, "region": "shanxi", "cell": Vector2i(52, 13), "faction": "f_lei",
		"desc": "ป้อมปราการเหล็กของตระกูลป้อมอัสนี ที่สายฟ้าฟาดลงมาไม่ขาดสาย",
	},
	"f_eagle_seat": {
		"name": "ค่ายอินทรีเหล็ก", "type": NodeType.RIVAL_SECT, "region": "shanxi", "cell": Vector2i(60, 14), "faction": "f_eagle",
		"desc": "ค่ายของสำนักคุ้มภัยอินทรีผยอง ผู้ยอมก้มหัวให้สิบขันทีเพื่อสัญญางานหลวง",
	},
	"f_iron_stream_seat": {
		"name": "หุบเขาเพลิงอัคนี", "type": NodeType.RIVAL_SECT, "region": "shanxi", "cell": Vector2i(62, 22), "faction": "f_iron_stream",
		"desc": "โรงแสงศัตราวุธของหอธารเหล็กไหล 'ศาสตรามิเลือกนาย'",
	},
	"w_black_iron": {
		"name": "ภูเขาเหล็กดำ", "type": NodeType.WILD, "region": "shanxi", "cell": Vector2i(49, 21),
		"desc": "ภูเขาที่อุดมด้วยสายแร่ มีลิงศิลาดุร้ายเฝ้าถ้ำ",
		"enemies": ["rock_ape", "mountain_bandit"], "gather": { "iron_ore": [3, 6], "cold_iron": [0, 2], "spirit_stone": [0, 1] },
	},
	# ══════════ มณฑลส่านซี ══════════
	"c_xian": {
		"name": "นครซีอาน", "type": NodeType.CITY, "region": "shaanxi", "cell": Vector2i(37, 31),
		"desc": "นครเอกทิศตะวันตก เมืองการค้าของคนต่างด้าว ที่ตั้งสำนักงานข่าวกรองของสำนักไป่เซียว",
		"shop": ["spirit_grass", "iron_ore", "beast_hide", "spirit_stone", "snow_lotus"],
		"price_mult": 1.1, "sell_rate": 0.65, "shop_rarity": 1, "auction": true, "lords": ["f_court", "f_baixiao", "f_seven_kill"],
	},
	"c_lanzhou": {
		"name": "เมืองหลานโจว", "type": NodeType.CITY, "region": "shaanxi", "cell": Vector2i(29, 23),
		"desc": "เมืองหน้าด่านสู่ทะเลทรายแดนรกร้างตะวันตก",
		"shop": ["beast_hide", "iron_ore", "spirit_stone"],
		"price_mult": 1.0, "sell_rate": 0.55, "shop_rarity": 0, "auction": false, "lords": ["f_court", "f_divine_temple"],
	},
	"c_huashan_town": {
		"name": "เมืองหัวซาน", "type": NodeType.CITY, "region": "shaanxi", "cell": Vector2i(43, 30),
		"desc": "เมืองเชิงเขาหัวซาน จุดแวะพักของผู้ขึ้นเขาไปยังสำนักหัวซานและกระบี่เมฆาขาว",
		"shop": ["spirit_grass", "iron_ore", "wood"],
		"price_mult": 0.95, "sell_rate": 0.5, "shop_rarity": 0, "auction": false, "lords": ["f_huashan", "f_baiyun"],
	},
	"f_baiyun_seat": {
		"name": "ยอดเขาจันทราขาว", "type": NodeType.GREAT_SECT, "region": "shaanxi", "cell": Vector2i(46, 26), "faction": "f_baiyun",
		"desc": "สำนักกระบี่เมฆาขาวบนยอดเขาท่ามกลางทะเลเมฆ เสาหลักธรรมะผู้นำพันธมิตรยุทธภพ",
	},
	"f_huashan_seat": {
		"name": "ยอดเขาหัวซาน", "type": NodeType.GREAT_SECT, "region": "shaanxi", "cell": Vector2i(41, 27), "faction": "f_huashan",
		"desc": "โตรกผาสูงชันที่บุปผาผลิบานท่ามกลางไอเย็นแฝงเจตจำนงสังหาร",
	},
	"f_qinmu_seat": {
		"name": "ยอดเขาไผ่เขียว", "type": NodeType.RIVAL_SECT, "region": "shaanxi", "cell": Vector2i(32, 37), "faction": "f_qinmu",
		"desc": "สำนักของสตรีผู้ถูกหักหลังโดยความรัก บุรุษแปลกหน้ายากจะย่างกรายเข้าถึง",
	},
	"f_seven_kill_seat": {
		"name": "อารามศิลาเงา", "type": NodeType.RIVAL_SECT, "region": "shaanxi", "cell": Vector2i(34, 33), "faction": "f_seven_kill",
		"desc": "สำนักดาบเล็กๆ ชานนครซีอานที่เน้นประสิทธิภาพการสังหารเหนือจารีต",
	},
	"w_bamboo_sea": {
		"name": "ป่าไผ่หมื่นลี้", "type": NodeType.WILD, "region": "shaanxi", "cell": Vector2i(35, 39),
		"desc": "ป่าไผ่กว้างไกลสุดลูกหูลูกตา โจรภูเขาซ่อนตัวอยู่ลึกๆ",
		"enemies": ["mountain_bandit", "forest_wolf"], "gather": { "wood": [4, 8], "spirit_grass": [1, 4] },
	},
	"w_silk_road": {
		"name": "เส้นทางสายไหม", "type": NodeType.WILD, "region": "shaanxi", "cell": Vector2i(23, 21),
		"desc": "เส้นทางคาราวานสู่แดนตะวันตก มีโจรทะเลทรายและนักดาบนอกรีตดักปล้น",
		"enemies": ["sand_bandit", "rival_swordsman"], "gather": { "spirit_stone": [0, 2], "iron_ore": [1, 3] },
	},
	# ══════════ มณฑลเสฉวน ══════════
	"c_chengdu": {
		"name": "เมืองเฉิงตู", "type": NodeType.CITY, "region": "sichuan", "cell": Vector2i(40, 46),
		"desc": "เมืองหลวงของเสฉวน ศูนย์การค้าสมุนไพรและอาวุธกลไก",
		"shop": ["spirit_grass", "blood_ginseng", "iron_ore", "beast_hide"],
		"price_mult": 1.0, "sell_rate": 0.6, "shop_rarity": 1, "auction": false, "lords": ["f_tang", "f_court"],
	},
	"c_wudang_town": {
		"name": "เมืองอู่ตังซาน", "type": NodeType.CITY, "region": "sichuan", "cell": Vector2i(47, 45),
		"desc": "เมืองเชิงเขาบู๊ตึง ผู้แสวงบุญเดินทางมาไม่ขาดสาย",
		"shop": ["spirit_grass", "wood", "stone"],
		"price_mult": 0.9, "sell_rate": 0.5, "shop_rarity": 0, "auction": false, "lords": ["f_wudang", "f_court"],
	},
	"c_dali": {
		"name": "เมืองต้าหลี่", "type": NodeType.CITY, "region": "sichuan", "cell": Vector2i(37, 53),
		"desc": "เมืองชายแดนวัฒนธรรมผสมผสาน ประตูสู่ดินแดนร้อยพิษ",
		"shop": ["spirit_grass", "blood_ginseng", "beast_hide", "snow_lotus"],
		"price_mult": 1.05, "sell_rate": 0.6, "shop_rarity": 1, "auction": false, "lords": ["f_court", "f_hundred_tribes", "f_tang"],
	},
	"f_wudang_seat": {
		"name": "ยอดเขาสัจธรรม", "type": NodeType.GREAT_SECT, "region": "sichuan", "cell": Vector2i(50, 42), "faction": "f_wudang",
		"desc": "วิหารหยกของบู๊ตึงที่พลังหยินหยางหมุนวนเป็นหนึ่งเดียว",
	},
	"f_tang_seat": {
		"name": "ป้อมศิลาตระกูลถัง", "type": NodeType.GREAT_SECT, "region": "sichuan", "cell": Vector2i(36, 47), "faction": "f_tang",
		"desc": "ป้อมหินสีดำในหุบเขาที่หมอกพิษปกคลุมทั้งปี จ้าวแห่งอาวุธลับและยาพิษ",
	},
	"w_sichuan_gorge": {
		"name": "หุบเขาเสฉวน", "type": NodeType.WILD, "region": "sichuan", "cell": Vector2i(44, 49),
		"desc": "หุบเขาลึกที่หมาป่าและลิงศิลาครอบครอง เต็มไปด้วยหญ้าวิญญาณ",
		"enemies": ["forest_wolf", "rock_ape"], "gather": { "spirit_grass": [3, 8], "beast_hide": [1, 3] },
	},
	# ══════════ ดินแดนร้อยพิษแดนใต้ ══════════
	"c_blood_moon": {
		"name": "เมืองจันทราโลหิต", "type": NodeType.CITY, "region": "south_poison", "cell": Vector2i(35, 60),
		"desc": "ตลาดมืดชายแดน ซื้อขายพิษและของเถื่อน ราคาแพงแต่รับซื้อในราคาสูง",
		"shop": ["blood_ginseng", "cold_iron", "beast_core", "snow_lotus", "star_metal"],
		"price_mult": 1.5, "sell_rate": 0.85, "shop_rarity": 2, "auction": true, "lords": ["f_sunset", "f_hundred_tribes", "f_blood_spider"],
	},
	"f_hundred_tribes_seat": {
		"name": "หุบเขาอสรพิษเร้นกาย", "type": NodeType.RIVAL_SECT, "region": "south_poison", "cell": Vector2i(43, 59), "faction": "f_hundred_tribes",
		"desc": "ศูนย์กลางของกลุ่มร้อยเผ่า ที่อยู่ของพญาอสรพิษผู้กุมอาคมกู่",
	},
	"f_sunset_seat": {
		"name": "นครหมื่นอสูร", "type": NodeType.RIVAL_SECT, "region": "south_poison", "cell": Vector2i(53, 62), "faction": "f_sunset",
		"desc": "เมืองร้างที่ถูกยึดเป็นฐานที่มั่นของพรรคมารอัสดง",
	},
	"f_blood_spider_seat": {
		"name": "ป่าหมอกอับแสง", "type": NodeType.RIVAL_SECT, "region": "south_poison", "cell": Vector2i(61, 64), "faction": "f_blood_spider",
		"desc": "ส่วนลึกที่มืดมิดที่สุดของดินแดนร้อยพิษ ที่ซ่อนของเผ่าแมงมุมโลหิต",
	},
	"d_demon_valley": {
		"name": "หุบเขาหมื่นอสูร", "type": NodeType.DUNGEON, "region": "south_poison", "cell": Vector2i(49, 57),
		"desc": "ทางเข้านครหมื่นอสูร อันตรายสูงแต่มีแก่นอสูรและโสมโลหิต",
		"enemies": ["demon_sect_disciple", "demon_elder"], "gather": { "blood_ginseng": [1, 3], "beast_core": [0, 2] },
	},
	"w_poison_jungle": {
		"name": "ป่าดงดิบร้อยพิษ", "type": NodeType.WILD, "region": "south_poison", "cell": Vector2i(40, 64),
		"desc": "ป่าทึบที่แสงตะวันส่องไม่ถึง อสรพิษกู่และนักรบชนเผ่าคอยล่าผู้บุกรุก",
		"enemies": ["poison_disciple", "gu_serpent"], "gather": { "blood_ginseng": [1, 2], "spirit_grass": [3, 6] },
	},
	"d_spider_nest": {
		"name": "รังแมงมุมโลหิต", "type": NodeType.DUNGEON, "region": "south_poison", "cell": Vector2i(57, 60),
		"desc": "รังใยพิษของเผ่าที่ถูกขับไล่ ซากศพผู้บุกรุกห้อยอยู่ทั่ว",
		"enemies": ["blood_spider", "gu_serpent"], "gather": { "blood_ginseng": [1, 3], "beast_core": [0, 1] },
	},
	# ══════════ เทือกเขามังกรเร้น ══════════
	"f_sword_grave_seat": {
		"name": "สุสานใจกระบี่", "type": NodeType.RIVAL_SECT, "region": "hidden_dragon", "cell": Vector2i(21, 29), "faction": "f_sword_grave",
		"desc": "หุบเขาไร้ร่องรอยที่ฝังซากศาสตราและเจตจำนงของยอดฝีมือในอดีต",
	},
	"f_medicine_seat": {
		"name": "หุบเขาหมื่นโอสถ", "type": NodeType.RIVAL_SECT, "region": "hidden_dragon", "cell": Vector2i(24, 39), "faction": "f_medicine",
		"desc": "หุบเขาลับของหมอเทวดา แม้พญามัจจุราชยังต้องรั้งรอหน้าปากทาง",
	},
	"f_qingxu_seat": {
		"name": "ยอดเขาเมฆาชาด", "type": NodeType.RIVAL_SECT, "region": "hidden_dragon", "cell": Vector2i(19, 35), "faction": "f_qingxu",
		"desc": "สำนักเต๋าผู้สืบทอดวิชาดูดาวและค่ายกลโบราณ",
	},
	"f_blood_lotus_seat": {
		"name": "ยอดบัวโลหิต", "type": NodeType.RIVAL_SECT, "region": "hidden_dragon", "cell": Vector2i(26, 26), "faction": "f_blood_lotus",
		"desc": "ฐานที่มั่นสุดสยองของลัทธิบัวโลหิต ยามบัวสีชาดผลิบาน ยุทธภพจักนองเลือด",
	},
	"f_hidden_council_seat": {
		"name": "หุบเขาไผ่ม่วง", "type": NodeType.RIVAL_SECT, "region": "hidden_dragon", "cell": Vector2i(28, 43), "faction": "f_hidden_council",
		"desc": "ที่รวมตัวของสำนักเล็กๆ ผู้เป็นโล่ด่านแรกขวางลัทธิบัวโลหิต",
	},
	"w_dragon_peaks": {
		"name": "หุบผามังกรเร้น", "type": NodeType.WILD, "region": "hidden_dragon", "cell": Vector2i(24, 32),
		"desc": "หุบผาในม่านหมอกนิรันดร์ สาวกลัทธิบัวโลหิตออกล่าเหยื่อ",
		"enemies": ["rock_ape", "blood_lotus_cultist"], "gather": { "spirit_grass": [2, 5], "snow_lotus": [0, 1], "spirit_stone": [0, 2] },
	},
	"secret_realm": {
		"name": "แดนลับบรรพกาล", "type": NodeType.SECRET_REALM, "region": "hidden_dragon", "cell": Vector2i(27, 47),
		"desc": "แดนลับที่เปิดทุกๆ 100 วัน สำนักทั้งแผ่นดินจะส่งศิษย์หัวกะทิมาแย่งชิงสมบัติ",
	},
	# ══════════ ทุ่งหญ้าเยือกแข็งแดนอุดร ══════════
	"c_karakorum": {
		"name": "คาราโครัม", "type": NodeType.CITY, "region": "north_steppe", "cell": Vector2i(63, 6),
		"desc": "นครกระโจมเคลื่อนที่ของข่านสงครามเตมูร์ ค้าขายหนังสัตว์และม้าศึก",
		"shop": ["beast_hide", "beast_core", "iron_ore"],
		"price_mult": 1.1, "sell_rate": 0.55, "shop_rarity": 1, "auction": false, "lords": ["f_steppe"],
	},
	"f_beiliang_seat": {
		"name": "ป้อมหยกขาว", "type": NodeType.RIVAL_SECT, "region": "north_steppe", "cell": Vector2i(39, 8), "faction": "f_beiliang",
		"desc": "ลมหายใจสุดท้ายของราชวงศ์เป่ยเหลียง ซ่อนอยู่ในหุบเขาที่ถูกลืมเลือน",
	},
	"w_wolf_steppe": {
		"name": "ทุ่งหญ้าหมาป่า", "type": NodeType.WILD, "region": "north_steppe", "cell": Vector2i(49, 8),
		"desc": "ทุ่งหญ้ากว้างใต้พายุหิมะ นักรบม้าออกล่าคาราวาน",
		"enemies": ["steppe_raider", "forest_wolf"], "gather": { "beast_hide": [2, 5], "beast_core": [0, 1] },
	},
	# ══════════ นครใต้ดินทิศพายัพ ══════════
	"f_xuancheng_seat": {
		"name": "เมืองใต้ดินเสวียน", "type": NodeType.RIVAL_SECT, "region": "nw_underground", "cell": Vector2i(11, 9), "faction": "f_xuancheng",
		"desc": "นครศิลาที่เจาะลึกลงไปในภูเขาหิมะ รังของผู้ถูกทอดทิ้งจากประวัติศาสตร์",
	},
	"w_snow_peak": {
		"name": "ยอดเขาเหมันต์นิรันดร์", "type": NodeType.WILD, "region": "nw_underground", "cell": Vector2i(19, 14),
		"desc": "ยอดเขาเหน็บหนาวที่ราชาหมาป่าหิมะครอบครอง แหล่งบัวหิมะและโลหะดารา",
		"enemies": ["snow_wolf_king", "rock_ape"], "gather": { "snow_lotus": [0, 1], "star_metal": [0, 1], "spirit_stone": [1, 3] },
	},
	"d_xuan_tunnels": {
		"name": "อุโมงค์ศิลาเสวียน", "type": NodeType.DUNGEON, "region": "nw_underground", "cell": Vector2i(15, 18),
		"desc": "อุโมงค์ทางเข้านครใต้ดิน มีผู้พิทักษ์ศิลาเฝ้าอยู่",
		"enemies": ["xuancheng_guard", "rock_ape"], "gather": { "star_metal": [0, 2], "cold_iron": [1, 3] },
	},
	# ══════════ ดินแดนรกร้างตะวันตก ══════════
	"c_oasis": {
		"name": "โอเอซิสหมื่นดารา", "type": NodeType.CITY, "region": "west_waste", "cell": Vector2i(9, 41),
		"desc": "สวรรค์กลางทะเลทราย ใต้หลังคาโดมทองของวิหารเทวะศักดิ์สิทธิ์",
		"shop": ["spirit_stone", "star_metal", "snow_lotus", "beast_hide"],
		"price_mult": 1.3, "sell_rate": 0.7, "shop_rarity": 2, "auction": true, "lords": ["f_divine_temple"],
	},
	"f_xuanyuan_seat": {
		"name": "วิหารเพลิงกัลป์", "type": NodeType.RIVAL_SECT, "region": "west_waste", "cell": Vector2i(6, 27), "faction": "f_xuanyuan",
		"desc": "วิหารของนิกายซวนหยวนบนเทือกเขาเพลิงอัสดง ผู้บูชาดวงสุริยา",
	},
	"w_sand_sea": {
		"name": "ทะเลทรายพายุทราย", "type": NodeType.WILD, "region": "west_waste", "cell": Vector2i(14, 46),
		"desc": "ผืนทรายร้อนระอุที่โจรทะเลทรายดักปล้นคาราวาน",
		"enemies": ["sand_bandit"], "gather": { "spirit_stone": [1, 3] },
	},
	"d_fire_crater": {
		"name": "ปล่องเพลิงอัสดง", "type": NodeType.DUNGEON, "region": "west_waste", "cell": Vector2i(4, 33),
		"desc": "ปล่องภูเขาไฟที่นักพรตเพลิงใช้หลอมตน แหล่งโลหะดารา",
		"enemies": ["fire_cultist", "sand_bandit"], "gather": { "star_metal": [0, 2], "spirit_stone": [1, 2] },
	},
	# ══════════ ชายฝั่งวายุคร่ำและทะเลบูรพา ══════════
	"c_storm_port": {
		"name": "ท่าเรือวายุคลั่ง", "type": NodeType.CITY, "region": "east_coast", "cell": Vector2i(84, 33),
		"desc": "ท่าเรือไร้กฎหมาย เงินตราคือพระเจ้า และสัญญาสลักโลหิตคือกฎเหล็ก",
		"shop": ["cold_iron", "beast_core", "spirit_stone", "dragon_scale"],
		"price_mult": 1.35, "sell_rate": 0.8, "shop_rarity": 2, "auction": true, "lords": ["f_east_sea"],
	},
	"f_east_sea_seat": {
		"name": "อ่าวจันทร์เสี้ยว", "type": NodeType.RIVAL_SECT, "region": "east_coast", "cell": Vector2i(84, 39), "faction": "f_east_sea",
		"desc": "แหล่งซ่องสุมของพันธมิตรทะเลบูรพา กลุ่มโจรสลัดเจียวอู๋ไห่และซาจิน",
	},
	"f_azure_dragon_seat": {
		"name": "เกาะมังกรเร้น", "type": NodeType.RIVAL_SECT, "region": "east_coast", "cell": Vector2i(94, 40), "faction": "f_azure_dragon",
		"desc": "ปราสาทศิลากลางม่านหมอกนิรันดร์ ที่ซ่อนของวังมังกรคราม (ต้องล่องเรือข้ามทะเล)",
	},
	"w_coral_reef": {
		"name": "แนวปะการังวายุ", "type": NodeType.WILD, "region": "east_coast", "cell": Vector2i(83, 26),
		"desc": "แนวหินโสโครกที่เรือสินค้าอับปางบ่อยครั้ง",
		"enemies": ["pirate"], "gather": { "spirit_stone": [1, 2], "cold_iron": [0, 2] },
	},
	"d_pirate_cove": {
		"name": "ถ้ำโจรสลัด", "type": NodeType.DUNGEON, "region": "east_coast", "cell": Vector2i(82, 46),
		"desc": "ถ้ำเก็บสมบัติของกัปตันโจรสลัดวายุคลั่ง",
		"enemies": ["pirate", "pirate_captain"], "gather": { "spirit_stone": [1, 3], "dragon_scale": [0, 1] },
	},
}

## ข้อมูลโลกที่ใช้งานอยู่ (โหมดเนื้อเรื่อง = LORE_*, โหมดแซนด์บ็อกซ์ = สุ่มโดย SandboxGen)
static var REGIONS: Dictionary = LORE_REGIONS
static var NODES: Dictionary = LORE_NODES
static var START_SITES: Array = LORE_START_SITES

const SECRET_REALM_INTERVAL = 100
const SECRET_REALM_OPEN_DAYS = 15
const SECRET_REALM_MAX_TEAM = 5

static func get_node_data(id: String) -> Dictionary:
	return NODES.get(id, {})

static func get_region_name(id: String) -> String:
	return REGIONS.get(id, {}).get("name", "")

static func get_start_site(id: String) -> Dictionary:
	for s in START_SITES:
		if s.id == id: return s
	return START_SITES[0]

## ขั้วอำนาจที่ตั้งสำนักใหญ่อยู่ในเมืองนี้ (เช่น ราชสำนักในนครเมฆาโลหิต)
static func get_city_hq(city_id: String) -> Array:
	return FactionDB.FACTIONS.keys().filter(func(f): return FactionDB.FACTIONS[f].seat == city_id)

# ── แดนลับ (เปิดตามช่วงเวลา) ──

static func is_secret_realm_open(day: int) -> bool:
	return day >= SECRET_REALM_INTERVAL and (day % SECRET_REALM_INTERVAL) < SECRET_REALM_OPEN_DAYS

static func days_until_secret_realm(day: int) -> int:
	if is_secret_realm_open(day): return 0
	return SECRET_REALM_INTERVAL - (day % SECRET_REALM_INTERVAL)

static func days_until_secret_realm_closes(day: int) -> int:
	return SECRET_REALM_OPEN_DAYS - (day % SECRET_REALM_INTERVAL)
