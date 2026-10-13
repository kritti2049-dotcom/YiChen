extends RefCounted
class_name HierPath

## Hierarchical Pathfinding (HPA*)
## - แบ่งแผนที่เป็นภูมิภาค (cluster) ขนาด CLUSTER x CLUSTER ช่อง
## - จุดเชื่อมต่อ (entrance) อยู่ตามขอบภูมิภาคที่เดินผ่านถึงกันได้ ระหว่างจุดในภูมิภาคเดียวกันเก็บต้นทุนเดินภายใน (Dijkstra จำกัดในภูมิภาค)
## - ระดับบน: A* บนกราฟจุดเชื่อมต่อ (เล็กมาก) / ระดับล่าง: AStarGrid2D เฉพาะช่วงสั้นๆ ระหว่างจุดเชื่อมต่อ
## - เก็บ ID กลุ่มช่องที่เชื่อมกัน: ตอบ "ไปถึงได้ไหม" ทันทีโดยไม่ต้องหาทาง
## - กำแพง/ประตูเปลี่ยน: invalidate(cell) สร้างกราฟใหม่เฉพาะภูมิภาคนั้นและเพื่อนบ้าน
## ต้นทุนช่องมาจาก weight ของ AStarGrid2D (ถนนถูก หญ้า/โคลนแพง) จึงเดินตามถนนแทนลัดทุ่ง
## แผนที่ที่เล็กกว่า HPA_MIN_CELLS ใช้ AStarGrid2D (native C++) ตรงๆ: วัดแล้วเร็วกว่า HPA* ที่เขียนด้วย GDScript
## ราว 80 เท่าแม้บนแผนที่ 120x90 จึงเปิดระดับบนเฉพาะแผนที่ขนาดมหึมา (โลกเปิดในอนาคต)
## ทุกขนาดแผนที่ยังได้ประโยชน์จาก ID กลุ่มช่อง (เป้าหมายที่ไปไม่ถึงตอบ "ไม่มีทาง" ทันที ไม่ต้องให้ A* ค้นทั้งแผนที่)
## + แคชเส้นทาง + คิวจำกัดคำขอต่อเฟรม (PathService)

const CLUSTER = 12
const HPA_MIN_CELLS = 250000

var W: int
var H: int
var astar: AStarGrid2D
var cols: int
var rows: int
var component := PackedInt32Array()
## จุดเชื่อมต่อ: id -> { "cell": Vector2i, "cluster": int }
var nodes := {}
## ต้นทุนระหว่างจุด: id -> { id: cost }
var edges := {}
var _next_id := 0
## ใช้กราฟระดับบนจริงไหม (false = native A* + ID กลุ่มช่อง)
var hierarchical := false
var _cache := {}

func _init(p_astar: AStarGrid2D, w: int, h: int, force_hierarchy := false) -> void:
	astar = p_astar
	W = w
	H = h
	cols = int(ceil(W / float(CLUSTER)))
	rows = int(ceil(H / float(CLUSTER)))
	_build_components()
	hierarchical = force_hierarchy or W * H >= HPA_MIN_CELLS
	if not hierarchical: return
	for cy in rows:
		for cx in cols:
			_build_cluster_borders(cx, cy)
	for ci in cols * rows:
		_build_intra(ci)

func walkable(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < W and c.y < H and not astar.is_point_solid(c)

func cost_of(c: Vector2i) -> float:
	return astar.get_point_weight_scale(c)

func cluster_of(c: Vector2i) -> int:
	return int(c.x / CLUSTER) + int(c.y / CLUSTER) * cols

func cluster_rect(ci: int) -> Rect2i:
	var cx = ci % cols
	var cy = int(ci / cols)
	return Rect2i(cx * CLUSTER, cy * CLUSTER, min(CLUSTER, W - cx * CLUSTER), min(CLUSTER, H - cy * CLUSTER))

## ID กลุ่มช่องที่เชื่อมถึงกัน (-1 = เดินไม่ได้)
func _build_components() -> void:
	component.resize(W * H)
	component.fill(-1)
	var cid = 0
	for y in H:
		for x in W:
			var s = Vector2i(x, y)
			if component[y * W + x] != -1 or not walkable(s): continue
			var stack = [s]
			component[y * W + x] = cid
			while not stack.is_empty():
				var c: Vector2i = stack.pop_back()
				for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var n: Vector2i = c + d
					if walkable(n) and component[n.y * W + n.x] == -1:
						component[n.y * W + n.x] = cid
						stack.append(n)
			cid += 1

func reachable(a: Vector2i, b: Vector2i) -> bool:
	if not walkable(a) or not walkable(b): return false
	return component[a.y * W + a.x] == component[b.y * W + b.x]

# ── จุดเชื่อมต่อ ──

func _add_node(cell: Vector2i) -> int:
	for id in nodes:
		if nodes[id].cell == cell: return id
	var id = _next_id
	_next_id += 1
	nodes[id] = { "cell": cell, "cluster": cluster_of(cell) }
	edges[id] = {}
	return id

func _link(a: int, b: int, c: float) -> void:
	edges[a][b] = c
	edges[b][a] = c

## จุดเชื่อมต่อบนขอบขวาและขอบล่างของภูมิภาค (cx, cy): ช่วงที่เดินได้ทั้งสองฝั่ง 1 ช่วง = 1 คู่จุดตรงกลางช่วง
func _build_cluster_borders(cx: int, cy: int) -> void:
	var r = cluster_rect(cx + cy * cols)
	if cx + 1 < cols:
		var x = r.end.x - 1
		_scan_border(range(r.position.y, r.end.y).map(func(y): return [Vector2i(x, y), Vector2i(x + 1, y)]))
	if cy + 1 < rows:
		var y = r.end.y - 1
		_scan_border(range(r.position.x, r.end.x).map(func(x): return [Vector2i(x, y), Vector2i(x, y + 1)]))

func _scan_border(pairs: Array) -> void:
	var run: Array = []
	for p in pairs + [null]:
		if p != null and walkable(p[0]) and walkable(p[1]):
			run.append(p)
			continue
		if not run.is_empty():
			var mid = run[run.size() / 2]
			_link(_add_node(mid[0]), _add_node(mid[1]), (cost_of(mid[0]) + cost_of(mid[1])) / 2.0)
			run.clear()

## Dijkstra จำกัดภายในภูมิภาค คืน { cell: cost }
func _dijkstra(start: Vector2i, rect: Rect2i) -> Dictionary:
	var dist = { start: 0.0 }
	var open = [[0.0, start]]
	while not open.is_empty():
		var best = 0
		for i in open.size():
			if open[i][0] < open[best][0]: best = i
		var cur = open[best]
		open.remove_at(best)
		var c: Vector2i = cur[1]
		if cur[0] > dist.get(c, INF): continue
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN, Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
			var n: Vector2i = c + d
			if not rect.has_point(n) or not walkable(n): continue
			if d.x != 0 and d.y != 0 and (not walkable(c + Vector2i(d.x, 0)) or not walkable(c + Vector2i(0, d.y))): continue
			var nd = cur[0] + cost_of(n) * (1.41421 if d.x != 0 and d.y != 0 else 1.0)
			if nd < dist.get(n, INF):
				dist[n] = nd
				open.append([nd, n])
	return dist

## ต้นทุนเดินภายในภูมิภาคระหว่างจุดเชื่อมต่อทุกคู่
func _build_intra(ci: int) -> void:
	var rect = cluster_rect(ci)
	var ids = nodes.keys().filter(func(id): return nodes[id].cluster == ci)
	for a in ids:
		var dist = _dijkstra(nodes[a].cell, rect)
		for b in ids:
			if a != b and dist.has(nodes[b].cell): _link(a, b, dist[nodes[b].cell])

## กำแพง/ประตูเปลี่ยนที่ cell: สร้างกราฟใหม่เฉพาะภูมิภาคนั้นและเพื่อนบ้าน
func invalidate(cell: Vector2i) -> void:
	_cache.clear()
	_build_components()
	if not hierarchical: return
	var ci = cluster_of(cell)
	var affected = [ci]
	var cx = ci % cols
	var cy = int(ci / cols)
	for d in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
		var nx = cx + d.x
		var ny = cy + d.y
		if nx >= 0 and ny >= 0 and nx < cols and ny < rows: affected.append(nx + ny * cols)
	for id in nodes.keys():
		if nodes[id].cluster in affected:
			for other in edges[id]: edges[other].erase(id)
			edges.erase(id)
			nodes.erase(id)
	for a in affected:
		_build_cluster_borders(a % cols, int(a / cols))
		if a % cols > 0: _build_cluster_borders(a % cols - 1, int(a / cols))
		if int(a / cols) > 0: _build_cluster_borders(a % cols, int(a / cols) - 1)
	for a in affected: _build_intra(a)

# ── หาเส้นทาง ──

func find_path(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not reachable(a, b): return out
	var key = Vector4i(a.x, a.y, b.x, b.y)
	if _cache.has(key): return _cache[key]
	# แผนที่เล็ก / ระยะใกล้ / ภูมิภาคเดียวกัน = A* ระดับล่างโดยตรง
	if not hierarchical or cluster_of(a) == cluster_of(b) or Vector2(a).distance_to(Vector2(b)) < CLUSTER:
		out.assign(astar.get_id_path(a, b))
		return out
	# ใส่จุดเริ่ม/จุดหมายชั่วคราวเข้ากราฟระดับบน
	var start_links = _links_to_cluster_nodes(a)
	var goal_links = _links_to_cluster_nodes(b)
	var abstract = _abstract_astar(a, b, start_links, goal_links)
	if abstract.is_empty():
		out.assign(astar.get_id_path(a, b))
		return out
	# ระดับล่าง: ต่อเส้นทางสั้นๆ ระหว่างจุดเชื่อมต่อ
	var points = [a] + abstract + [b]
	for i in range(1, points.size()):
		var seg = astar.get_id_path(points[i - 1], points[i])
		for j in seg.size():
			if out.is_empty() or out[-1] != seg[j]: out.append(seg[j])
	if _cache.size() > 64: _cache.clear()
	_cache[key] = out
	return out

func _links_to_cluster_nodes(c: Vector2i) -> Dictionary:
	var ci = cluster_of(c)
	var dist = _dijkstra(c, cluster_rect(ci))
	var links = {}
	for id in nodes:
		if nodes[id].cluster == ci and dist.has(nodes[id].cell): links[id] = dist[nodes[id].cell]
	return links

## A* บนกราฟจุดเชื่อมต่อ คืนลำดับช่องของจุดเชื่อมต่อที่ต้องผ่าน
func _abstract_astar(a: Vector2i, b: Vector2i, start_links: Dictionary, goal_links: Dictionary) -> Array:
	var g = {}
	var came = {}
	var open = []
	for id in start_links:
		g[id] = start_links[id]
		open.append(id)
	var best_goal = -1
	var best_cost = INF
	while not open.is_empty():
		var bi = 0
		for i in open.size():
			if g[open[i]] + Vector2(nodes[open[i]].cell).distance_to(Vector2(b)) < g[open[bi]] + Vector2(nodes[open[bi]].cell).distance_to(Vector2(b)): bi = i
		var cur = open[bi]
		open.remove_at(bi)
		if goal_links.has(cur) and g[cur] + goal_links[cur] < best_cost:
			best_cost = g[cur] + goal_links[cur]
			best_goal = cur
		if g[cur] >= best_cost: continue
		for n in edges[cur]:
			var ng = g[cur] + edges[cur][n]
			if ng < g.get(n, INF):
				g[n] = ng
				came[n] = cur
				if not open.has(n): open.append(n)
	if best_goal == -1: return []
	var seq = []
	var c = best_goal
	while true:
		seq.push_front(nodes[c].cell)
		if not came.has(c): break
		c = came[c]
	return seq
