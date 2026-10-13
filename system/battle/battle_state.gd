extends RefCounted
class_name BattleState

## ข้อมูลศึกบนกริด (ไม่มีภาพ): สนาม ยูนิต ลำดับเทิร์น และเครื่องสุ่มของศึกเอง (seed เดิม = ผลเดิม)
## ยูนิตเป็น Dictionary (ดู BattleRules.make_ally / make_enemy) ฉากแสดงผลอ่านค่าจากที่นี่อย่างเดียว
## ลำดับเทิร์นแบบ CT: ทุกขีดยูนิตได้ CT เท่าความเร็ว ใครถึง CT_FULL ก่อนได้เล่นก่อน

## ขนาดสนามของศึกปัจจุบัน (ต่างกันตามแผนที่ ดู BattleRules.arena_size) มีศึกได้ทีละศึกจึงเก็บแบบ static
static var W := 12
static var H := 6
## รูปทรงสนาม: "rect" สี่เหลี่ยม / "circle" วงกลม (วงรีตามขนาดสนาม) ช่องนอกวงอยู่ใน void_cells = ไม่มีพื้น เดิน/เล็งไม่ได้
static var shape := "rect"
static var void_cells := {}
const CT_FULL = 100.0
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var units: Array = []
## ช่องที่เดินผ่านไม่ได้ { Vector2i: "rock" | "tree" | "water" }
var blocked := {}
## พื้นหญ้าสูง (หลบหลีกเพิ่ม) { Vector2i: true }
var grass := {}
var rng := RandomNumberGenerator.new()
var round_no := 0
var _turns := 0
var over := false
## 0 = ฝ่ายเราชนะ, 1 = ฝ่ายศัตรูชนะ, 2 = ฝ่ายเราหนีออกจากสนามหมด
var result := -1
var context := {}

func in_grid(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < W and c.y < H and not void_cells.has(c)

## ช่องนอกวง (สนามวงกลม): ระยะจากจุดศูนย์กลางแบบวงรีเกินขอบ
static func build_shape(p_shape: String) -> void:
	shape = p_shape
	void_cells = {}
	if shape != "circle": return
	var cx = (W - 1) / 2.0
	var cy = (H - 1) / 2.0
	var rx = W / 2.0
	var ry = H / 2.0
	for x in W:
		for y in H:
			var dx = (x - cx) / rx
			var dy = (y - cy) / ry
			if dx * dx + dy * dy > 1.08: void_cells[Vector2i(x, y)] = true

func passable(c: Vector2i) -> bool:
	return in_grid(c) and not blocked.has(c)

static func dist(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

func on_field(u: Dictionary) -> bool:
	return not u.down and not u.escaped

func unit_at(c: Vector2i) -> Dictionary:
	for u in units:
		if on_field(u) and u.cell == c: return u
	return {}

func team_units(team: int) -> Array:
	return units.filter(func(u): return u.team == team and on_field(u))

func foes_of(u: Dictionary) -> Array:
	return team_units(1 - u.team)

func by_id(id: int) -> Dictionary:
	for u in units:
		if u.id == id: return u
	return {}

## ช่องที่เดินไปได้ในเทิร์นนี้ { cell: ช่องก่อนหน้า } (BFS ระยะ move) ช่องติดศัตรู = หยุด (โซนควบคุม)
func reachable(u: Dictionary) -> Dictionary:
	var out := { u.cell: u.cell }
	if u.moved or u.status.has("seal"): return out
	var steps := { u.cell: 0 }
	var frontier: Array[Vector2i] = [u.cell]
	var limit: int = u.move + u.get("move_bonus", 0)
	while not frontier.is_empty():
		var c: Vector2i = frontier.pop_front()
		if steps[c] >= limit: continue
		if c != u.cell and _in_zoc(u, c): continue
		for d in DIRS:
			var n = c + d
			if steps.has(n) or not passable(n): continue
			var other = unit_at(n)
			if not other.is_empty(): continue
			steps[n] = steps[c] + 1
			out[n] = c
			frontier.append(n)
	return out

func _in_zoc(u: Dictionary, c: Vector2i) -> bool:
	for f in foes_of(u):
		if dist(f.cell, c) == 1: return true
	return false

## เส้นทางจากผลของ reachable ไปยัง cell (ไม่รวมจุดเริ่ม)
static func path_to(reach: Dictionary, start: Vector2i, cell: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	if not reach.has(cell): return path
	var c = cell
	while c != start:
		path.push_front(c)
		c = reach[c]
	return path

## มองเห็น/ยิงผ่านได้ไหม (สิ่งกีดขวางบัง ยูนิตไม่บัง)
func los(a: Vector2i, b: Vector2i) -> bool:
	var n = maxi(absi(b.x - a.x), absi(b.y - a.y))
	for i in range(1, n):
		var p = Vector2(a).lerp(Vector2(b), float(i) / n)
		var c = Vector2i(roundi(p.x), roundi(p.y))
		if c != a and c != b and blocked.has(c): return false
	return true

## ลำดับเทิร์นแบบรอบ: ทุกตัวได้ตาละ 1 ครั้งต่อรอบ เรียงตามความเร็ว (เร็วกว่า = ได้เล่นก่อน ไม่ได้เล่นถี่กว่า)
var _queue: Array = []

func _new_round() -> void:
	round_no += 1
	_queue = units.filter(on_field)
	# เท่ากันสุ่มด้วย ct (สุ่มตอนเริ่มศึก) ให้ลำดับไม่ตายตัว
	_queue.sort_custom(func(a, b): return a.spd > b.spd or (a.spd == b.spd and a.ct > b.ct))

## ยูนิตถัดไปที่ได้เล่น (ข้ามตัวที่ล้ม/หนีไปแล้วระหว่างรอบ)
func next_actor() -> Dictionary:
	for guard in 3:
		while not _queue.is_empty():
			var u: Dictionary = _queue.pop_front()
			if on_field(u):
				_turns += 1
				return u
		if units.filter(on_field).is_empty(): return {}
		_new_round()
	return {}

## ลำดับเทิร์นถัดไป n ตัว (ที่เหลือในรอบนี้ + รอบหน้า) ไม่เปลี่ยนสถานะจริง
func preview_order(n: int) -> Array:
	var out: Array = _queue.filter(on_field)
	var nxt = units.filter(on_field)
	nxt.sort_custom(func(a, b): return a.spd > b.spd or (a.spd == b.spd and a.ct > b.ct))
	while out.size() < n and not nxt.is_empty():
		out.append_array(nxt)
	return out.slice(0, n)

func check_end() -> bool:
	if over: return true
	var a = team_units(0)
	var e = team_units(1)
	if e.is_empty():
		over = true
		result = 0
	elif a.is_empty():
		over = true
		# มีคนหนีออกจากสนามได้ = ถอยทัพ (คนที่หนีไม่บาดเจ็บ) ไม่มีเลย = พ่ายแพ้
		result = 2 if units.any(func(u): return u.team == 0 and u.escaped) else 1
	return over
