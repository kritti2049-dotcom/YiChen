extends RefCounted
class_name CityLayout

## สร้างผังเมืองแบบตาราง (สุ่มคงที่ตาม id เมือง: เข้าเมืองเดิมกี่ครั้งก็ได้ผังเดิม)
## - ถนนแนวนอน 3 สาย (เหนือ / ถนนหลัก / ใต้) + ถนนแนวตั้ง 3 สาย, ลานกลางเมืองตรงสี่แยก
## - แม่น้ำ (บางเมือง) พร้อมสะพาน, กำแพงเมืองและประตู (บางเมือง)
## - อาคารเรียงตามแปลงริมถนน ประตูหันลงถนน, อาคารลับ (สมาคมนักฆ่า/ร้านยาพิษ) ซ่อนปลายตรอกมืดฝั่งตะวันออก
## - ช่องว่างระหว่างอาคาร = ตรอกมืด (ALLEY) ใช้ซ่อนตัวตอนกลางคืน

enum T { GROUND, ROAD, PLAZA, WATER, WALL, ALLEY, BRIDGE }

const W = 48
const H = 34
const TILE = 32
const MAIN_Y = [16, 17, 18]
const NORTH_Y = [8, 9]
const SOUTH_Y = [29, 30]
const VERT_X = [[5, 6], [23, 24, 25], [41, 42]]
const RIVER_Y = [21, 22]
## แปลงอาคาร: base = แถวล่างของอาคาร (ประตูอยู่แถวถัดไปซึ่งเป็นถนน), xs = ช่วงที่วางได้
const LOTS = [
	{ "base": 7, "x0": 7, "x1": 22 }, { "base": 7, "x0": 26, "x1": 40 },
	{ "base": 15, "x0": 7, "x1": 18 }, { "base": 15, "x0": 30, "x1": 40 },
	{ "base": 28, "x0": 7, "x1": 22 }, { "base": 28, "x0": 26, "x1": 40 },
	{ "base": 7, "x0": 1, "x1": 4 }, { "base": 15, "x0": 1, "x1": 4 }, { "base": 28, "x0": 1, "x1": 4 },
]
## แปลงลับปลายตรอก (ฝั่งตะวันออก)
const HIDDEN_LOTS = [{ "base": 26, "x0": 43, "x1": 46 }, { "base": 13, "x0": 43, "x1": 46 }]

var city_id: String
var theme: Dictionary
var tiles := PackedByteArray()
var blocked := {} # Vector2i -> true (อาคาร ต้นไม้)
## [{ "kind", "name", "rect": Rect2i, "door": Vector2i }]
var buildings: Array = []
var trees: Array[Vector2i] = []
var lanterns: Array[Vector2i] = []
var spawn := Vector2i(2, 17)
## เส้นทางลาดตระเวนของยามกลางคืน [[จุด, จุด], ...]
var patrols: Array = []
var astar: AStarGrid2D
## Hierarchical Pathfinding (HPA*) บน astar
var hpa: HierPath

func _init(p_city_id: String) -> void:
	city_id = p_city_id
	theme = CityDB.get_theme(city_id)
	var info = CityDB.get_city(city_id)
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(city_id)
	tiles.resize(W * H)
	tiles.fill(T.GROUND)
	if CityDB.is_sect_node(city_id) and not CityDB.CITIES.has(city_id) and not CityDB.custom.has(city_id):
		_build_sect(rng)
	else:
		_lay_streets(info.get("river", false))
		if theme.walls: _lay_walls()
		_place_buildings(info.buildings, rng)
		_place_decor(rng)
		patrols = [
			[Vector2i(3, 17), Vector2i(45, 17)], [Vector2i(24, 10), Vector2i(24, 31)],
			[Vector2i(7, 8), Vector2i(40, 8)], [Vector2i(7, 29), Vector2i(40, 29)],
		]
	_setup_astar()

func at(c: Vector2i) -> int:
	if c.x < 0 or c.y < 0 or c.x >= W or c.y >= H: return T.WALL
	return tiles[c.y * W + c.x]

func _put(c: Vector2i, t: int) -> void:
	if c.x < 0 or c.y < 0 or c.x >= W or c.y >= H: return
	tiles[c.y * W + c.x] = t

func is_walkable(c: Vector2i) -> bool:
	var t = at(c)
	return not (t == T.WATER or t == T.WALL) and not blocked.has(c)

## ช่องที่มืดพอให้ซ่อนตัว (ตรอก หรือพื้นที่นอกถนนห่างจากโคมไฟ)
func is_shadow(c: Vector2i) -> bool:
	if at(c) == T.ALLEY: return true
	if at(c) == T.GROUND:
		for l in lanterns:
			if Vector2(l).distance_to(Vector2(c)) < 3.5: return false
		return true
	return false

# ── ถนน แม่น้ำ กำแพง ──

func _lay_streets(river: bool) -> void:
	for x in W:
		for y in MAIN_Y: _put(Vector2i(x, y), T.ROAD)
	for x in range(2, W - 2):
		for y in NORTH_Y + SOUTH_Y: _put(Vector2i(x, y), T.ROAD)
	for col in VERT_X:
		for x in col:
			for y in range(8, H if col.size() == 3 else 31):
				_put(Vector2i(x, y), T.ROAD)
	for x in range(19, 30):
		for y in range(15, 20): _put(Vector2i(x, y), T.PLAZA)
	if river:
		for x in W:
			for y in RIVER_Y:
				var on_road = false
				for col in VERT_X:
					if col.has(x): on_road = true
				_put(Vector2i(x, y), T.BRIDGE if on_road else T.WATER)

func _lay_walls() -> void:
	for x in W:
		for y in [0, H - 1]:
			if not (y == H - 1 and x in VERT_X[1]): _put(Vector2i(x, y), T.WALL)
	for y in H:
		for x in [0, W - 1]:
			if not y in MAIN_Y and at(Vector2i(x, y)) != T.WATER: _put(Vector2i(x, y), T.WALL)

# ── อาคาร ──

func _place_buildings(services: Array, rng: RandomNumberGenerator) -> void:
	var queue: Array = []
	var hidden: Array = []
	for kind in services:
		var b = CityDB.BUILDINGS[kind]
		if b.get("hidden", false): hidden.append(kind)
		elif b.get("landmark", false): _place_landmark(kind)
		else: queue.append(kind)
	# รอบแรก: อาคารบริการหาที่ว่างในแปลงตามลำดับ (ใกล้ใจกลางเมืองก่อน)
	for kind in queue:
		var size: Vector2i = CityDB.BUILDINGS[kind].size
		var placed = false
		for lot in LOTS:
			for x in range(lot.x0, lot.x1 - size.x + 2):
				var r = Rect2i(x, lot.base - size.y + 1, size.x, size.y)
				if _fits(r):
					_add_building(kind, r)
					placed = true
					break
			if placed: break
		if not placed: push_warning("CityLayout: วาง %s ใน %s ไม่ได้" % [kind, city_id])
	# รอบสอง: เติมบ้านเรือน/กระโจมให้เต็มแปลงที่เหลือ
	for lot in LOTS:
		var x = lot.x0
		while x <= lot.x1:
			var kind = theme.get("filler", "tent" if theme.ground == "snowgrass" else "house")
			var size = Vector2i(rng.randi_range(2, 3), rng.randi_range(2, 3))
			if x + size.x - 1 > lot.x1: break
			var r = Rect2i(x, lot.base - size.y + 1, size.x, size.y)
			if _fits(r):
				_add_building(kind, r)
				x += size.x + 1 # ช่องว่าง 1 ช่อง = ตรอกระหว่างอาคาร
			else:
				x += 1
	for i in hidden.size():
		var lot = HIDDEN_LOTS[i % HIDDEN_LOTS.size()]
		var size: Vector2i = CityDB.BUILDINGS[hidden[i]].size
		_add_building(hidden[i], Rect2i(lot.x0, lot.base - size.y + 1, size.x, size.y))
		# ตรอกมืดจากถนนข้างไปถึงประตู
		for x in range(41, lot.x0 + size.x):
			_put(Vector2i(x, lot.base + 1), T.ALLEY)
	# ถนนข้างฝั่งตะวันออกเป็นตรอกเปลี่ยว
	for y in range(19, 31):
		for x in VERT_X[2]:
			if at(Vector2i(x, y)) == T.ROAD: _put(Vector2i(x, y), T.ALLEY)
	# ช่องระหว่างอาคารกลายเป็นตรอก
	for b in buildings:
		var r: Rect2i = b.rect
		for y in range(r.position.y, r.end.y):
			for x in [r.position.x - 1, r.end.x]:
				var c = Vector2i(x, y)
				if at(c) == T.GROUND and not blocked.has(c): _put(c, T.ALLEY)

func _place_landmark(kind: String) -> void:
	var size: Vector2i = CityDB.BUILDINGS[kind].size
	var rect: Rect2i
	match kind:
		"arena": rect = Rect2i(8, 28 - size.y + 1, size.x, size.y)
		_: rect = Rect2i(24 - size.x / 2, 7 - size.y + 1, size.x, size.y)
	_add_building(kind, rect)

## ที่ว่างพอวางอาคาร และเว้นช่องซ้าย/ขวาไว้เป็นตรอก (ไม่ชิดอาคารอื่น)
func _fits(r: Rect2i) -> bool:
	if _occupied(r): return false
	for y in range(r.position.y, r.end.y):
		if blocked.has(Vector2i(r.position.x - 1, y)) or blocked.has(Vector2i(r.end.x, y)): return false
	return true

func _occupied(r: Rect2i) -> bool:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var c = Vector2i(x, y)
			if blocked.has(c) or at(c) != T.GROUND: return true
	return false

func _add_building(kind: String, r: Rect2i) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			blocked[Vector2i(x, y)] = true
			_put(Vector2i(x, y), T.GROUND)
	var door = Vector2i(r.position.x + r.size.x / 2, r.end.y)
	buildings.append({ "kind": kind, "name": CityDB.building_name(kind, city_id), "rect": r, "door": door })

# ══════════════════════════════════════════
# ผังสำนัก (ไม่ใช้แม่แบบเมือง): แต่ละสำนักต่างกันตามชนิด (CityDB.sect_profile) + สุ่มคงที่ตาม id
# ทางเข้าอยู่ฝั่งตะวันตกเสมอ (แถว MAIN_Y) ท้องพระโรงอยู่ปลายทางสายหลัก (อารามอยู่กลางระเบียงคด)
# ══════════════════════════════════════════

const SECT_TINTED = ["sect_hall", "sect_library", "sect_yard", "sect_dorm", "sect_pagoda", "sect_alchemy", "sect_forge", "sect_tower"]

var _sect_style := {}

func _road(c: Vector2i, t := T.ROAD) -> void:
	if c.x < 0 or c.y < 0 or c.x >= W or c.y >= H: return
	_put(c, T.BRIDGE if at(c) == T.WATER and t == T.ROAD else t)

func _road_rect(r: Rect2i, t := T.ROAD) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x): _road(Vector2i(x, y), t)

func _blob(center: Vector2, rx: float, ry: float, t: int) -> void:
	for y in range(int(center.y - ry) - 1, int(center.y + ry) + 2):
		for x in range(int(center.x - rx) - 1, int(center.x + rx) + 2):
			var d = Vector2((x - center.x) / rx, (y - center.y) / ry)
			if d.length() <= 1.0: _put(Vector2i(x, y), t)

func _build_sect(rng: RandomNumberGenerator) -> void:
	var p = CityDB.sect_profile(city_id)
	_sect_style = p
	theme = theme.duplicate()
	theme.ground = p.ground
	theme.tree = p.tree
	theme.walls = p.walls
	var kind: String = p.kind
	# 1) น้ำ/ภูมิประเทศ (ถนนที่ทับน้ำจะกลายเป็นสะพาน)
	match kind:
		"valley":
			for i in rng.randi_range(5, 8):
				_blob(Vector2(rng.randi_range(6, W - 6), rng.randi_range(4, H - 4)), rng.randf_range(2.5, 6.0), rng.randf_range(1.5, 3.5), T.WATER)
		"island":
			var shore = rng.randi_range(3, 5)
			for y in H:
				for x in W:
					if mini(mini(x, y), mini(W - 1 - x, H - 1 - y)) < shore + int(sin(x * 0.5 + y * 0.3) * 1.2): _put(Vector2i(x, y), T.WATER)
			_blob(Vector2(rng.randi_range(14, 30), rng.randi_range(22, 27)), 4.0, 2.0, T.WATER)
		"mountain", "manor":
			for i in rng.randi_range(1, 2 if kind == "mountain" else 3):
				_blob(Vector2(rng.randi_range(8, 34), [rng.randi_range(4, 6), rng.randi_range(22, 30)][i % 2]), rng.randf_range(2.5, 4.5), rng.randf_range(1.5, 2.5), T.WATER)
	# 2) ถนน: สายหลักตะวันตก->ท้องพระโรง, ถนนเหนือ/ใต้ตำแหน่งสุ่ม, ทางเชื่อมแนวตั้งสุ่ม
	var hall_x = 37 + rng.randi_range(-2, 2)
	var ny = rng.randi_range(8, 10)
	var sy = rng.randi_range(26, 29)
	_road_rect(Rect2i(0, MAIN_Y[0], hall_x, 3))
	var n0 = rng.randi_range(5, 12)
	var n1 = mini(hall_x - 2, rng.randi_range(28, 36))
	var s0 = rng.randi_range(5, 12)
	var s1 = rng.randi_range(28, W - 4)
	_road_rect(Rect2i(n0, ny, n1 - n0, 2))
	_road_rect(Rect2i(s0, sy, s1 - s0, 2))
	var xs: Array[int] = []
	for i in rng.randi_range(2, 3):
		var x = rng.randi_range(maxi(n0, s0) + 1, mini(n1, s1) - 3)
		if xs.any(func(o): return absi(o - x) < 6): continue
		xs.append(x)
	if xs.is_empty(): xs.append((n0 + n1) / 2)
	for x in xs: _road_rect(Rect2i(x, ny, 2, sy - ny + 2))
	match kind:
		"temple":
			# ระเบียงคดรอบลานกลาง ท้องพระโรงตั้งกลางด้านบน
			_road_rect(Rect2i(12, ny, 2, sy - ny + 2))
			_road_rect(Rect2i(34, ny, 2, sy - ny + 2))
			_road_rect(Rect2i(19, 12, 11, 11), T.PLAZA)
		"fortress":
			_road_rect(Rect2i(16, 11, 15, 13), T.PLAZA)
		"manor":
			_road_rect(Rect2i(xs[0] - 2, MAIN_Y[0] - 2, 6, 7), T.PLAZA)
	# ลานหน้าท้องพระโรง
	var hall_rect: Rect2i
	if kind == "temple":
		hall_rect = Rect2i(21, 8, 7, 4)
	else:
		_road_rect(Rect2i(hall_x - 1, 13, mini(W - 2, hall_x + 8) - (hall_x - 1), 9), T.PLAZA)
		hall_rect = Rect2i(hall_x + 1, 9, 6, 4)
	if p.walls: _lay_walls()
	# 3) อาคาร: ท้องพระโรงก่อน แล้วอาคารสำคัญตามสาย แล้วเรือนศิษย์
	for y in range(hall_rect.position.y, hall_rect.end.y):
		for x in range(hall_rect.position.x, hall_rect.end.x): _put(Vector2i(x, y), T.GROUND)
	_add_building("sect_hall", hall_rect)
	var lots = _sect_lots()
	var order: Array = ["sect_yard", "sect_library"] + p.extra
	for k in order: _place_in_lots(k, CityDB.BUILDINGS[k].size, lots, rng)
	for i in p.dorms:
		_place_in_lots("sect_dorm", Vector2i(rng.randi_range(2, 3), rng.randi_range(2, 3)), lots, rng)
	for b in buildings:
		if b.kind in SECT_TINTED:
			b["roof"] = p.roof
			b["wall"] = p.wall
	# 4) ตกแต่ง: ต้นไม้ตามชนิด โคมไฟริมทางหลัก ป้ายหิน (สุสาน)
	for x in range(4, hall_x, 5):
		for y in [MAIN_Y[0] - 1, MAIN_Y[2] + 1]:
			var c = Vector2i(x, y)
			if at(c) == T.GROUND and not blocked.has(c): lanterns.append(c)
	if kind == "tomb":
		for y in range(sy + 3, H - 1, 2):
			for x in range(8, 40, 3):
				var c = Vector2i(x, y)
				if at(c) == T.GROUND and not blocked.has(c):
					lanterns.append(c)
					blocked[c] = true
	var n_trees = { "mountain": 140, "valley": 150, "manor": 70, "temple": 60, "fortress": 20, "island": 60, "tomb": 40 }[kind]
	for i in n_trees:
		var c = Vector2i(rng.randi_range(1, W - 2), rng.randi_range(1, H - 2))
		if at(c) != T.GROUND or blocked.has(c): continue
		var near = false
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if at(c + d) in [T.ROAD, T.PLAZA, T.BRIDGE]: near = true
		if near: continue
		trees.append(c)
		blocked[c] = true
	# 5) เส้นทางลาดตระเวน (อยู่บนถนนเสมอ)
	patrols = [
		[Vector2i(3, MAIN_Y[1]), Vector2i(hall_x - 2, MAIN_Y[1])],
		[Vector2i(n0 + 1, ny), Vector2i(n1 - 2, ny)],
		[Vector2i(s0 + 1, sy + 1), Vector2i(s1 - 2, sy + 1)],
		[Vector2i(xs[0], ny + 2), Vector2i(xs[0], sy - 1)],
	]

## แปลงอาคารของผังสำนัก: แนวช่องพื้นที่อยู่เหนือถนน/ลานพอดี (ประตูอาคารจะเปิดลงถนนเสมอ)
func _sect_lots() -> Array:
	var lots: Array = []
	for y in range(3, H - 1):
		var x0 = -1
		for x in range(1, W):
			var ok = x < W - 1 and at(Vector2i(x, y)) in [T.ROAD, T.PLAZA, T.BRIDGE] and at(Vector2i(x, y - 1)) == T.GROUND
			if ok and x0 < 0: x0 = x
			elif not ok and x0 >= 0:
				if x - x0 >= 3: lots.append({ "base": y - 1, "x0": x0, "x1": x - 1 })
				x0 = -1
	return lots

func _place_in_lots(kind: String, size: Vector2i, lots: Array, rng: RandomNumberGenerator) -> bool:
	var order = range(lots.size())
	for i in range(order.size() - 1, 0, -1):
		var j = rng.randi_range(0, i)
		var tmp = order[i]
		order[i] = order[j]
		order[j] = tmp
	for li in order:
		var lot = lots[li]
		for x in range(lot.x0, lot.x1 - size.x + 2):
			var r = Rect2i(x, lot.base - size.y + 1, size.x, size.y)
			if r.position.y >= 1 and _fits(r):
				_add_building(kind, r)
				return true
	return false

# ── ของตกแต่ง ──

func _place_decor(rng: RandomNumberGenerator) -> void:
	for x in range(3, W - 3, 6):
		for y in [15, 19]:
			var c = Vector2i(x, y)
			if at(c) in [T.GROUND, T.PLAZA] and not blocked.has(c): lanterns.append(c)
	for i in 70:
		var c = Vector2i(rng.randi_range(1, W - 2), rng.randi_range(1, H - 2))
		if at(c) != T.GROUND or blocked.has(c): continue
		# ไม่ปลูกขวางหน้าประตูหรือติดถนน
		var near_road = false
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if at(c + d) in [T.ROAD, T.PLAZA, T.ALLEY, T.BRIDGE]: near_road = true
		if near_road: continue
		trees.append(c)
		blocked[c] = true

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
			# ต้นทุนช่อง: ถนน/ลาน/สะพานถูก หญ้าแพง ตรอกปานกลาง -> เดินตามถนนแทนลัดทุ่ง
			elif at(c) == T.GROUND: astar.set_point_weight_scale(c, 1.8)
			elif at(c) == T.ALLEY: astar.set_point_weight_scale(c, 1.2)
	hpa = HierPath.new(astar, W, H)

## เส้นทางเดิน (พิกัดโลก) จากตำแหน่งหนึ่งไปอีกตำแหน่ง
func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var a = world_to_cell(from)
	var b = world_to_cell(to)
	if not is_walkable(b): b = nearest_walkable(b)
	if not is_walkable(a): a = nearest_walkable(a)
	var result = PackedVector2Array()
	for p in hpa.find_path(a, b):
		result.append(cell_to_world(p))
	return result

## ไปถึงได้ไหม (เช็ค ID กลุ่มช่องที่เชื่อมกัน ไม่ต้องหาทาง)
func can_reach(from: Vector2, to: Vector2) -> bool:
	return hpa.reachable(world_to_cell(from), world_to_cell(to))

func nearest_walkable(c: Vector2i) -> Vector2i:
	for r in range(1, 6):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var n = c + Vector2i(dx, dy)
				if is_walkable(n): return n
	return spawn

## จุดสุ่มบนถนน (ให้ NPC เดินไปมา)
func random_street_cell(rng: RandomNumberGenerator) -> Vector2i:
	for i in 50:
		var c = Vector2i(rng.randi_range(1, W - 2), rng.randi_range(1, H - 2))
		if at(c) in [T.ROAD, T.PLAZA] and is_walkable(c): return c
	return spawn

func size_px() -> Vector2:
	return Vector2(W, H) * TILE

static func cell_to_world(c: Vector2i) -> Vector2:
	return Vector2(c) * TILE + Vector2(TILE, TILE) / 2.0

static func world_to_cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / TILE), floori(p.y / TILE))
