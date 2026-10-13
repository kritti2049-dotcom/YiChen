extends RefCounted
class_name WorldGen

## สร้างแผนที่โลก "พิภพโลหิตชาด" ตามตำนาน
## 1) แบ่งภูมิภาค (5 มณฑล + 6 ดินแดนชายขอบ) แบบ Voronoi จากจุดศูนย์กลางใน WorldDB.REGIONS (ขอบเขตบิดด้วย noise ให้ดูเป็นธรรมชาติ)
## 2) ภูมิประเทศของแต่ละภูมิภาคเลือกจากจานสี (palette) ของภูมิภาคนั้นตามความสูง (FastNoiseLite)
##    ทะเลบูรพาทางทิศตะวันออก ทะเลใต้ เกาะมังกรเร้น และแม่น้ำ 2 สายถูกวาดทับตายตัว
## 3) สถานที่สำคัญวางตามพิกัดใน WorldDB.NODES เสมอ (Seed ไม่เปลี่ยนตำแหน่ง แค่เปลี่ยนรายละเอียดภูมิประเทศเล็กน้อย)
## 4) AStarGrid2D หาเส้นทาง (ภูเขาเดินช้า แหล่งน้ำตื้นต้องล่องเรือ) -> จำนวนวันเดินทาง
## โหมดแซนด์บ็อกซ์: ทวีปสุ่มด้วย FastNoiseLite ทั้งหมด (noise_continent) ภูมิภาค/สถานที่สร้างโดย SandboxGen

enum Biome { DEEP, WATER, SAND, GRASS, FOREST, HILLS, MOUNTAIN, SNOW }

const BIOME_NAMES = ["ทะเลลึก", "แหล่งน้ำ (ล่องเรือ)", "ชายหาด/ทะเลทราย", "ทุ่งราบ", "ป่าไม้", "เนินเขา", "ภูเขา", "ยอดเขาหิมะ"]
## ต้นทุนการเดินต่อช่อง (0 = เดินไม่ได้) แหล่งน้ำตื้นข้ามได้ด้วยเรือแต่ช้า
const MOVE_COST = [0.0, 2.5, 1.2, 1.0, 1.6, 2.0, 3.0, 3.5]

const WIDTH = 100
const HEIGHT = 70
const TILE = 16
## ต้นทุนการเดินที่ทำได้ใน 1 วัน
const COST_PER_DAY = 10.0

var world_seed: int
var sect_site: String
var mode: String
var biomes := PackedByteArray()
var regions := PackedStringArray()
var poi := {} # node_id -> Vector2i
var astar: AStarGrid2D
var _route_cache := {}

static var _cached: WorldGen

## คืนค่าโลกของ seed และที่ตั้งสำนักนี้ (สร้างครั้งเดียวแล้วเก็บไว้)
static func get_world(p_seed: int, p_site: String = "") -> WorldGen:
	p_site = WorldDB.get_start_site(p_site).id
	if _cached == null or _cached.world_seed != p_seed or _cached.sect_site != p_site or _cached.mode != WorldMode.current:
		_cached = WorldGen.new(p_seed, p_site)
	return _cached

static func for_sect(sect: SectData) -> WorldGen:
	return get_world(sect.world_seed, sect.start_site)

static func clear_cache() -> void:
	_cached = null

func _init(p_seed: int, p_site: String) -> void:
	world_seed = p_seed
	sect_site = p_site
	mode = WorldMode.current
	if mode == "sandbox":
		_generate_sandbox_terrain()
	else:
		_generate_terrain()
	_place_pois()
	_setup_astar()

# ── ภูมิภาค ──

func _generate_terrain() -> void:
	var height_noise = FastNoiseLite.new()
	height_noise.seed = world_seed
	height_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	height_noise.frequency = 0.06
	height_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	height_noise.fractal_octaves = 4
	# ขอบเขตภูมิภาคและแนวชายฝั่งบิดด้วย noise ที่ตายตัว (ไม่ขึ้นกับ Seed) ให้แผนที่ทุกเซฟเป็นแผ่นดินเดียวกัน
	var warp = FastNoiseLite.new()
	warp.seed = 7
	warp.frequency = 0.08

	biomes.resize(WIDTH * HEIGHT)
	regions.resize(WIDTH * HEIGHT)
	for y in HEIGHT:
		for x in WIDTH:
			var i = y * WIDTH + x
			var wx = x + warp.get_noise_2d(x, y) * 4.0
			var wy = y + warp.get_noise_2d(x + 300, y) * 4.0
			var region = nearest_region(Vector2(wx, wy))
			regions[i] = region
			var h = height_noise.get_noise_2d(x, y) * 1.4
			biomes[i] = _palette_biome(WorldDB.REGIONS[region].palette, h)
			# ทะเลบูรพา (ทิศตะวันออก) และทะเลใต้
			var coast = 86.0 + warp.get_noise_2d(0, y * 2.0) * 3.0
			var south_coast = 67.0 + warp.get_noise_2d(x * 2.0, 0) * 1.5
			if x >= coast or y >= south_coast:
				var depth = max(x - coast, y - south_coast)
				biomes[i] = Biome.WATER if depth < 2.5 else Biome.DEEP
				regions[i] = "east_coast" if x >= coast else "south_poison"
			elif x >= coast - 1.5 and biomes[i] != Biome.WATER:
				biomes[i] = Biome.SAND
	_draw_island(height_noise)
	_draw_rivers()

## ทวีปสุ่ม (โหมดแซนด์บ็อกซ์): ความสูง + ความชื้นจาก noise ขอบแผนที่เป็นทะเล
static func noise_continent(p_seed: int) -> PackedByteArray:
	var height_noise = FastNoiseLite.new()
	height_noise.seed = p_seed
	height_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	height_noise.frequency = 0.035
	height_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	height_noise.fractal_octaves = 5
	var moist_noise = FastNoiseLite.new()
	moist_noise.seed = p_seed + 1
	moist_noise.frequency = 0.05
	var shape_noise = FastNoiseLite.new()
	shape_noise.seed = p_seed + 2
	shape_noise.frequency = 0.02
	var out = PackedByteArray()
	out.resize(WIDTH * HEIGHT)
	var center = Vector2(WIDTH, HEIGHT) / 2.0
	for y in HEIGHT:
		for x in WIDTH:
			var d = (Vector2(x, y) - center) / center
			var falloff = pow(d.length(), 2.2) * (0.85 + shape_noise.get_noise_2d(x, y) * 0.5)
			var h = height_noise.get_noise_2d(x, y) * 0.9 + 0.32 - falloff
			var m = moist_noise.get_noise_2d(x, y)
			var b = Biome.GRASS
			if h < -0.25: b = Biome.DEEP
			elif h < -0.05: b = Biome.WATER
			elif h < 0.02: b = Biome.SAND
			elif h < 0.32: b = (Biome.FOREST if m > 0.1 else (Biome.SAND if m < -0.45 else Biome.GRASS))
			elif h < 0.45: b = Biome.HILLS
			elif h < 0.58: b = Biome.MOUNTAIN
			else: b = Biome.SNOW
			out[y * WIDTH + x] = b
	return out

func _generate_sandbox_terrain() -> void:
	biomes = noise_continent(world_seed)
	regions.resize(WIDTH * HEIGHT)
	for y in HEIGHT:
		for x in WIDTH:
			regions[y * WIDTH + x] = nearest_region(Vector2(x, y))

func nearest_region(p: Vector2) -> String:
	var best = ""
	var best_d = INF
	for id in WorldDB.REGIONS:
		var d = p.distance_squared_to(Vector2(WorldDB.REGIONS[id].center))
		if d < best_d:
			best_d = d
			best = id
	return best

static func _palette_biome(palette: Array, h: float) -> int:
	for step in palette:
		if h <= step[0]: return step[1]
	return palette[-1][1]

## เกาะมังกรเร้น + ช่องแคบน้ำตื้นให้ล่องเรือไปถึง
func _draw_island(noise: FastNoiseLite) -> void:
	var c = Vector2(WorldDB.ISLAND_CENTER)
	var r = WorldDB.ISLAND_RADIUS
	for y in range(int(c.y - r.y - 3), int(c.y + r.y + 4)):
		for x in range(int(c.x - r.x - 3), mini(WIDTH, int(c.x + r.x + 4))):
			var d = Vector2((x - c.x) / r.x, (y - c.y) / r.y).length()
			var cell = Vector2i(x, y)
			if d <= 1.0:
				var h = noise.get_noise_2d(x, y) * 1.4 + (1.0 - d) * 0.5
				_paint(cell, Biome.SAND if d > 0.8 else (Biome.MOUNTAIN if h > 0.55 else Biome.FOREST), "east_coast")
			elif d <= 1.6 and biome_at(cell) == Biome.DEEP:
				_paint(cell, Biome.WATER, "east_coast")
	for x in range(84, int(c.x - r.x) + 1):
		for y in range(int(c.y) - 1, int(c.y) + 2):
			if biome_at(Vector2i(x, y)) == Biome.DEEP:
				_paint(Vector2i(x, y), Biome.WATER, "east_coast")

func _draw_rivers() -> void:
	for river in WorldDB.RIVERS:
		for i in range(1, river.size()):
			var a = Vector2(river[i - 1])
			var b = Vector2(river[i])
			var steps = int(ceil(a.distance_to(b)))
			for s in steps + 1:
				var p = a.lerp(b, s / float(max(1, steps)))
				var cell = Vector2i(roundi(p.x), roundi(p.y))
				if biome_at(cell) != Biome.DEEP:
					_paint(cell, Biome.WATER, region_at(cell))

func _paint(cell: Vector2i, biome: int, region: String) -> void:
	if cell.x < 0 or cell.y < 0 or cell.x >= WIDTH or cell.y >= HEIGHT: return
	biomes[cell.y * WIDTH + cell.x] = biome
	regions[cell.y * WIDTH + cell.x] = region

func biome_at(cell: Vector2i) -> int:
	if cell.x < 0 or cell.y < 0 or cell.x >= WIDTH or cell.y >= HEIGHT: return Biome.DEEP
	return biomes[cell.y * WIDTH + cell.x]

func region_at(cell: Vector2i) -> String:
	if cell.x < 0 or cell.y < 0 or cell.x >= WIDTH or cell.y >= HEIGHT: return ""
	return regions[cell.y * WIDTH + cell.x]

func is_walkable(cell: Vector2i) -> bool:
	return MOVE_COST[biome_at(cell)] > 0.0

# ── สถานที่สำคัญ (พิกัดตายตัว) ──

func _place_pois() -> void:
	for id in WorldDB.NODES:
		var cell: Vector2i = WorldDB.get_start_site(sect_site).cell if id == "sect" else WorldDB.NODES[id].cell
		poi[id] = cell
		# ที่ตั้งต้องเป็นแผ่นดิน: ถ้าตรงกับแหล่งน้ำ ให้ถมเป็นที่ราบ/ทราย
		var b = biome_at(cell)
		if b == Biome.WATER or b == Biome.DEEP:
			_paint(cell, Biome.SAND if region_at(cell) in ["west_waste", "east_coast"] else Biome.GRASS, region_at(cell))

func _setup_astar() -> void:
	astar = AStarGrid2D.new()
	astar.region = Rect2i(0, 0, WIDTH, HEIGHT)
	astar.cell_size = Vector2(1, 1)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	for y in HEIGHT:
		for x in WIDTH:
			var c = Vector2i(x, y)
			var cost = MOVE_COST[biome_at(c)]
			if cost <= 0.0:
				astar.set_point_solid(c, true)
			else:
				astar.set_point_weight_scale(c, cost)

func poi_world_pos(id: String) -> Vector2:
	return cell_to_world(Vector2(poi.get(id, Vector2i.ZERO)))

static func cell_to_world(cell: Vector2) -> Vector2:
	return cell * TILE + Vector2(TILE, TILE) / 2.0

## ภูมิภาคของสถานที่
func poi_region(id: String) -> String:
	var r: String = WorldDB.NODES.get(id, {}).get("region", "")
	return r if r != "" else region_at(poi.get(id, Vector2i.ZERO))

# ── เส้นทาง ──

## เส้นทางระหว่างสถานที่ { "points": PackedVector2Array (พิกัดช่อง), "days": int }
func get_route(from_id: String, to_id: String) -> Dictionary:
	var key = from_id + ">" + to_id
	if _route_cache.has(key): return _route_cache[key]
	var a: Vector2i = poi.get(from_id, Vector2i.ZERO)
	var b: Vector2i = poi.get(to_id, Vector2i.ZERO)
	var path = astar.get_id_path(a, b)
	var points = PackedVector2Array()
	var cost = 0.0
	for i in path.size():
		points.append(Vector2(path[i]))
		if i > 0:
			var step = Vector2(path[i]).distance_to(Vector2(path[i - 1]))
			cost += step * MOVE_COST[biome_at(path[i])]
	var result = { "points": points, "days": max(1, int(ceil(cost / COST_PER_DAY))) }
	_route_cache[key] = result
	return result

## ตำแหน่ง (พิกัดช่อง) บนเส้นทาง ตามความคืบหน้า progress 0-1
static func point_on_route(points: PackedVector2Array, progress: float) -> Vector2:
	if points.is_empty(): return Vector2.ZERO
	if points.size() == 1: return points[0]
	var total = 0.0
	for i in range(1, points.size()):
		total += points[i].distance_to(points[i - 1])
	var target = clamp(progress, 0.0, 1.0) * total
	for i in range(1, points.size()):
		var seg = points[i].distance_to(points[i - 1])
		if target <= seg:
			return points[i - 1].lerp(points[i], target / seg if seg > 0 else 1.0)
		target -= seg
	return points[-1]
