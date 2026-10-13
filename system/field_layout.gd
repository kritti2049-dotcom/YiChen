extends RefCounted
class_name FieldLayout

## พื้นที่สำรวจ (ป่า / ภูเขา / ทะเลทราย / หิมะ / ป่าดงดิบ / ชายฝั่ง / ถ้ำ) ของโหนด WILD/DUNGEON บนแผนที่โลก
## ธีมเลือกตามภูมิประเทศจริงของโหนดบนแผนที่โลก ผังสุ่มคงที่ต่อโหนด (เดินกลับมากี่ครั้งก็ผังเดิม)
## มีเส้นทางเดินหลักจากทางเข้าคดเคี้ยวผ่านทั้งแผนที่ สิ่งกีดขวาง (ต้นไม้/หิน/กระบองเพชร) และแหล่งน้ำ

enum T { GROUND, PATH, WATER, WALL }

const W = 52
const H = 38
const TILE = 32

## สีของแต่ละธีม: ground, path, water, wall, obstacle (สิ่งกีดขวาง), obstacle_kind
const THEMES = {
	"forest": { "name": "ป่าทึบ", "ground": Color(0.42, 0.56, 0.32), "path": Color(0.6, 0.52, 0.38), "water": Color(0.3, 0.48, 0.6), "wall": Color(0.3, 0.38, 0.25), "obstacle": Color(0.22, 0.4, 0.2), "kind": "tree", "density": 0.18 },
	"mountain": { "name": "ภูเขาหิน", "ground": Color(0.55, 0.53, 0.48), "path": Color(0.66, 0.62, 0.54), "water": Color(0.35, 0.5, 0.6), "wall": Color(0.38, 0.36, 0.34), "obstacle": Color(0.45, 0.43, 0.4), "kind": "rock", "density": 0.2 },
	"desert": { "name": "ทะเลทราย", "ground": Color(0.86, 0.76, 0.52), "path": Color(0.76, 0.66, 0.45), "water": Color(0.35, 0.6, 0.6), "wall": Color(0.7, 0.55, 0.38), "obstacle": Color(0.35, 0.6, 0.3), "kind": "cactus", "density": 0.08 },
	"snow": { "name": "ทุ่งหิมะ", "ground": Color(0.88, 0.9, 0.94), "path": Color(0.75, 0.78, 0.82), "water": Color(0.55, 0.7, 0.85), "wall": Color(0.62, 0.66, 0.72), "obstacle": Color(0.3, 0.42, 0.38), "kind": "pine", "density": 0.14 },
	"jungle": { "name": "ป่าดงดิบหมอกพิษ", "ground": Color(0.28, 0.42, 0.25), "path": Color(0.42, 0.36, 0.25), "water": Color(0.3, 0.42, 0.3), "wall": Color(0.18, 0.28, 0.15), "obstacle": Color(0.15, 0.35, 0.18), "kind": "tree", "density": 0.24 },
	"coast": { "name": "ชายฝั่ง", "ground": Color(0.85, 0.8, 0.62), "path": Color(0.72, 0.66, 0.5), "water": Color(0.25, 0.5, 0.7), "wall": Color(0.5, 0.48, 0.45), "obstacle": Color(0.5, 0.48, 0.45), "kind": "rock", "density": 0.08 },
	"cave": { "name": "ถ้ำมืด", "ground": Color(0.32, 0.29, 0.28), "path": Color(0.42, 0.38, 0.35), "water": Color(0.2, 0.3, 0.4), "wall": Color(0.15, 0.13, 0.13), "obstacle": Color(0.4, 0.36, 0.34), "kind": "rock", "density": 0.12 },
}

var node_id: String
var theme_id: String
var theme: Dictionary
var tiles := PackedByteArray()
var blocked := {} # Vector2i -> true (สิ่งกีดขวาง)
var obstacles: Array[Vector2i] = []
var entrance := Vector2i(2, H / 2)
var reachable := {}
var astar: AStarGrid2D
## Hierarchical Pathfinding (HPA*) บน astar
var hpa: HierPath

func _init(p_node_id: String, biome: int) -> void:
	node_id = p_node_id
	theme_id = pick_theme(p_node_id, biome)
	theme = THEMES[theme_id]
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(p_node_id)
	tiles.resize(W * H)
	tiles.fill(T.GROUND)
	_generate(rng)
	_flood()
	_setup_astar()

## ธีมของพื้นที่: ดันเจี้ยนเป็นถ้ำ (ยกเว้นทะเลทราย/ป่าดงดิบ) ที่เหลือตามภูมิประเทศบนแผนที่โลก
static func pick_theme(p_node_id: String, biome: int) -> String:
	var n = WorldDB.get_node_data(p_node_id)
	var region: String = n.get("region", "")
	if region == "south_poison": return "jungle"
	if n.get("type", -1) == WorldDB.NodeType.DUNGEON and biome != WorldGen.Biome.SAND: return "cave"
	match biome:
		WorldGen.Biome.SAND: return "coast" if region == "east_coast" else "desert"
		WorldGen.Biome.SNOW: return "snow"
		WorldGen.Biome.MOUNTAIN, WorldGen.Biome.HILLS: return "mountain"
	return "forest"

func at(c: Vector2i) -> int:
	if c.x < 0 or c.y < 0 or c.x >= W or c.y >= H: return T.WALL
	return tiles[c.y * W + c.x]

func _put(c: Vector2i, t: int) -> void:
	if c.x < 0 or c.y < 0 or c.x >= W or c.y >= H: return
	tiles[c.y * W + c.x] = t

func is_walkable(c: Vector2i) -> bool:
	return at(c) in [T.GROUND, T.PATH] and not blocked.has(c)

func _generate(rng: RandomNumberGenerator) -> void:
	var noise = FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = 0.09
	var water_noise = FastNoiseLite.new()
	water_noise.seed = rng.randi()
	water_noise.frequency = 0.06
	var cave = theme_id == "cave"
	for y in H:
		for x in W:
			var c = Vector2i(x, y)
			if x == 0 or y == 0 or x == W - 1 or y == H - 1:
				_put(c, T.WALL)
				continue
			var w = water_noise.get_noise_2d(x, y)
			if cave and noise.get_noise_2d(x * 1.3, y * 1.3) > 0.28:
				_put(c, T.WALL)
			elif w < (-0.42 if theme_id != "coast" else -0.15) and theme_id != "desert":
				_put(c, T.WATER)
			elif theme_id == "coast" and x > W - 9 + int(w * 3):
				_put(c, T.WATER)
	# สิ่งกีดขวาง
	for y in range(1, H - 1):
		for x in range(1, W - 1):
			var c = Vector2i(x, y)
			if at(c) == T.GROUND and rng.randf() < theme.density * (1.0 + noise.get_noise_2d(x, y)):
				blocked[c] = true
				obstacles.append(c)
	# เส้นทางหลักคดเคี้ยวจากทางเข้าผ่านจุดสุ่ม 6 จุด (กว้าง 2 ช่อง) ให้เดินถึงทั่วแผนที่
	for dy in range(-1, 2):
		for dx in range(0, 3):
			var e = entrance + Vector2i(dx, dy)
			_put(e, T.PATH)
			blocked.erase(e)
	var points = [entrance]
	for i in 6:
		points.append(Vector2i(rng.randi_range(6 + i * 7, 10 + i * 7), rng.randi_range(4, H - 5)))
	for i in range(1, points.size()):
		_carve(points[i - 1], points[i], rng)
	# ทางแยกย่อย
	for i in 4:
		var a: Vector2i = points[rng.randi_range(1, points.size() - 1)]
		_carve(a, Vector2i(clampi(a.x + rng.randi_range(-8, 8), 2, W - 3), clampi(a.y + rng.randi_range(-12, 12), 2, H - 3)), rng)

func _carve(a: Vector2i, b: Vector2i, rng: RandomNumberGenerator) -> void:
	var p = Vector2(a)
	var target = Vector2(b)
	var guard = 0
	while p.distance_to(target) > 1.0 and guard < 400:
		guard += 1
		var dir = (target - p).normalized()
		dir = dir.rotated(rng.randf_range(-0.6, 0.6))
		p += dir
		var c = Vector2i(roundi(p.x), roundi(p.y))
		for d in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN]:
			var cc = c + d
			if cc.x <= 0 or cc.y <= 0 or cc.x >= W - 1 or cc.y >= H - 1: continue
			_put(cc, T.PATH)
			blocked.erase(cc)
	obstacles = obstacles.filter(func(o): return blocked.has(o))

## ช่องที่เดินถึงได้จากทางเข้า (วางมอนสเตอร์/ทรัพยากรเฉพาะที่นี่)
func _flood() -> void:
	reachable = { entrance: true }
	var stack = [entrance]
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = c + d
			if not reachable.has(n) and is_walkable(n):
				reachable[n] = true
				stack.append(n)

func _setup_astar() -> void:
	astar = AStarGrid2D.new()
	astar.region = Rect2i(0, 0, W, H)
	astar.cell_size = Vector2(TILE, TILE)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	for y in H:
		for x in W:
			var c = Vector2i(x, y)
			if not is_walkable(c): astar.set_point_solid(c, true)
			elif at(c) == T.GROUND: astar.set_point_weight_scale(c, 1.6)
	hpa = HierPath.new(astar, W, H)

## จุดสุ่มที่เดินถึงได้ ห่างจากทางเข้าอย่างน้อย min_dist ช่อง
func random_spot(rng: RandomNumberGenerator, min_dist := 0.0) -> Vector2i:
	var cells = reachable.keys()
	for i in 80:
		var c: Vector2i = cells[rng.randi() % cells.size()]
		if Vector2(c).distance_to(Vector2(entrance)) >= min_dist: return c
	return cells[rng.randi() % cells.size()]

# ── อินเทอร์เฟซที่ CityPlayer / FieldMonster ใช้ ──

func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var a = world_to_cell(from)
	var b = world_to_cell(to)
	if not is_walkable(a) or not is_walkable(b): return PackedVector2Array([to])
	var result = PackedVector2Array()
	for p in hpa.find_path(a, b): result.append(cell_to_world(p))
	return result

func is_shadow(_c) -> bool:
	return false

func size_px() -> Vector2:
	return Vector2(W, H) * TILE

static func cell_to_world(c: Vector2i) -> Vector2:
	return Vector2(c) * TILE + Vector2(TILE, TILE) / 2.0

static func world_to_cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / TILE), floori(p.y / TILE))
