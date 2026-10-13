extends RefCounted
class_name WorldMode

## โหมดของโลก
## - "story"   = พิภพโลหิตชาด (Story / Scenario Mode): แผนที่ตามตำนาน ขั้วอำนาจจริง อีเวนต์ตามเนื้อเรื่อง (StorySys)
## - "sandbox" = โกลาหลยุทธภพ (Procedural Sandbox Mode): ทวีป ชื่อสำนัก ที่ตั้ง ทรัพยากร ความสัมพันธ์ สุ่มใหม่ตาม Seed
## เรียก activate(sect) ทุกครั้งที่โหลด/สร้างสำนัก เพื่อสลับข้อมูลใน WorldDB / FactionDB / CityDB

const MODES = {
	"story": { "name": "พิภพโลหิตชาด (เนื้อเรื่อง)", "desc": "เล่นตามตำนาน: 5 มณฑล 6 ดินแดนชายขอบ ขั้วอำนาจจริง (สิบขันทีเงา เมฆาขาว วังมังกรคราม...) และอีเวนต์ระดับโลกตามเนื้อเรื่อง" },
	"sandbox": { "name": "โกลาหลยุทธภพ (แซนด์บ็อกซ์)", "desc": "สุ่มโลกใหม่ 100% ตาม Seed: ทวีปรูปร่างใหม่ ชื่อสำนักคู่แข่งใหม่หมด ทรัพยากรและความสัมพันธ์สุ่ม เล่นได้ไม่รู้จบ" },
}

static var current := "story"
static var _key := ""

static func is_sandbox() -> bool:
	return current == "sandbox"

static func activate(sect: SectData) -> void:
	var key = "%s:%d" % [sect.world_mode, sect.world_seed]
	if key == _key: return
	_key = key
	current = sect.world_mode
	if current == "sandbox":
		SandboxGen.apply(sect.world_seed)
	else:
		WorldDB.REGIONS = WorldDB.LORE_REGIONS
		WorldDB.NODES = WorldDB.LORE_NODES
		WorldDB.START_SITES = WorldDB.LORE_START_SITES
		FactionDB.FACTIONS = FactionDB.LORE_FACTIONS
		FactionDB.BLOCS = FactionDB.LORE_BLOCS
		CityDB.custom = {}
