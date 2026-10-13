extends RefCounted
class_name Territory

## อาณาเขตของสำนัก: แผนที่ช่อง SIZE x SIZE (ไอโซเมตริก) เริ่มเป็นป่ากว้าง มีหญ้า หิน น้ำ ต้นไม้
## สร้างจาก world_seed ด้วย FastNoiseLite (ซ้ำได้) เก็บใน SectData.terrain (1 ไบต์ต่อช่อง) แล้วเปลี่ยนตามการถางป่า/ทำเกษตร
## ผู้เล่นสร้างตึกได้เฉพาะช่องหญ้า/ดิน (GRASS, DIRT) · ถางป่า (FOREST -> GRASS) ได้ไม้ · เหมืองหินต้องติดช่อง ROCK

const SIZE = 96
const HOME = Vector2i(48, 48)
## รัศมีลานเริ่มต้นที่ถางไว้แล้วรอบ HOME
const START_CLEAR = 8

enum T { GRASS, FOREST, ROCK, WATER, DIRT, FIELD }

const NAMES = ["หญ้า", "ป่า", "หิน", "น้ำ", "ดิน", "แปลงเพาะปลูก"]

static func idx(c: Vector2i) -> int:
	return c.y * SIZE + c.x

static func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < SIZE and c.y < SIZE

static func at(sect: SectData, c: Vector2i) -> int:
	if not in_bounds(c) or sect.terrain.size() != SIZE * SIZE: return T.WATER
	return sect.terrain[idx(c)]

static func set_at(sect: SectData, c: Vector2i, t: int) -> void:
	if in_bounds(c) and sect.terrain.size() == SIZE * SIZE: sect.terrain[idx(c)] = t

## จุดที่คนใหม่มาถึง (ทางเข้าสำนัก) พิกัดช่อง
static func gate_pos() -> Vector2:
	return Vector2(HOME) + Vector2(9.5, 0.5)

## วางตึกได้ไหม (หญ้า/ดิน เท่านั้น)
static func buildable(sect: SectData, c: Vector2i) -> bool:
	var t = at(sect, c)
	return t == T.GRASS or t == T.DIRT

## สร้างภูมิประเทศ (เรียกครั้งเดียวต่อเซฟ) และตั้งต้นสำนัก: โถงหลักกับกองไฟกลางลานที่ถางไว้
static func init_world(sect: SectData) -> void:
	if sect.terrain.size() == SIZE * SIZE or sect.world_seed == 0: return
	sect.terrain.resize(SIZE * SIZE)
	var height = FastNoiseLite.new()
	height.seed = sect.world_seed ^ 0x2F1
	height.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	height.frequency = 0.045
	height.fractal_type = FastNoiseLite.FRACTAL_FBM
	var wood = FastNoiseLite.new()
	wood.seed = sect.world_seed ^ 0x6C3
	wood.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	wood.frequency = 0.09
	var rock = FastNoiseLite.new()
	rock.seed = sect.world_seed ^ 0x9D7
	rock.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	rock.frequency = 0.07
	rock.fractal_type = FastNoiseLite.FRACTAL_FBM
	for y in SIZE:
		for x in SIZE:
			var c = Vector2i(x, y)
			var h = height.get_noise_2d(x, y)
			var edge = minf(minf(x, y), minf(SIZE - 1 - x, SIZE - 1 - y))
			var t = T.GRASS
			if h < -0.38 or edge < 1: t = T.WATER
			elif rock.get_noise_2d(x, y) > 0.34: t = T.ROCK
			elif wood.get_noise_2d(x, y) > -0.12 or h > 0.28: t = T.FOREST
			sect.terrain[idx(c)] = t
	var shore: Array[int] = []
	for y in range(1, SIZE - 1):
		for x in range(1, SIZE - 1):
			if sect.terrain[idx(Vector2i(x, y))] != T.FOREST: continue
			var near_water = false
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					if at(sect, Vector2i(x + dx, y + dy)) == T.WATER: near_water = true
			if near_water: shore.append(idx(Vector2i(x, y)))
	for i in shore: sect.terrain[i] = T.GRASS
	#ลานเริ่มต้นรอบ HOME: ถางเป็นหญ้า + มีหินให้ตั้งเหมืองใกล้ๆ
	for dy in range(-START_CLEAR, START_CLEAR + 1):
		for dx in range(-START_CLEAR, START_CLEAR + 1):
			if Vector2(dx, dy).length() <= START_CLEAR: sect.terrain[idx(HOME + Vector2i(dx, dy))] = T.GRASS
	for dy in range(-1, 3):
		for dx in range(-1, 3):
			var rc = HOME + Vector2i(START_CLEAR + 4 + dx, -START_CLEAR + 1 + dy)
			if in_bounds(rc): sect.terrain[idx(rc)] = T.ROCK
	# ทางสู่ลานเริ่มต้น: ถางเป็นหญ้าเส้นทางไปขอบ (ไม่ใช่น้ำ)
	for step in range(START_CLEAR, START_CLEAR + 5):
		var pc = HOME + Vector2i(step, 0)
		if at(sect, pc) == T.WATER or at(sect, pc) == T.FOREST: sect.terrain[idx(pc)] = T.GRASS
	if sect.structures.is_empty():
		_starter(sect)

static func _starter(sect: SectData) -> void:
	sect.add_structure("main_hall", HOME - Vector2i(1, 1), 1)
	sect.add_structure("campfire", HOME + Vector2i(4, 3), 1)

## ช่องที่ติดกัน (4 ทิศ) กับประเภทภูมิประเทศ t
static func touches(sect: SectData, rect: Rect2i, t: int) -> bool:
	for x in range(rect.position.x - 1, rect.end.x + 1):
		for y in range(rect.position.y - 1, rect.end.y + 1):
			var c = Vector2i(x, y)
			if rect.has_point(c): continue
			if at(sect, c) == t: return true
	return false

## ช่องป่าในรัศมี r จากจุด (ใช้ถางป่า) เรียงจากใกล้ไปไกล
static func forest_near(sect: SectData, center: Vector2i, r: int, limit: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for rr in range(1, r + 1):
		for x in range(center.x - rr, center.x + rr + 1):
			for y in range(center.y - rr, center.y + rr + 1):
				if maxi(absi(x - center.x), absi(y - center.y)) != rr: continue
				var c = Vector2i(x, y)
				if at(sect, c) == T.FOREST:
					out.append(c)
					if out.size() >= limit: return out
	return out
