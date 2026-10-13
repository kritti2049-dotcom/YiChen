extends Control
class_name MeridianMinigame

## มินิเกมทะลวงคอขวด: ต่อท่อลมปราณ (Puzzle)
## คลิกที่ช่องเพื่อหมุนเส้นลมปราณ ให้ปราณไหลจาก "ตันเถียน" (ซ้าย) ไปถึง "แกนกลาง" (ขวา) ก่อนหมดเวลา

signal finished(success: bool)

const N = 1
const E = 2
const S = 4
const W = 8
const DIRS = { N: Vector2i(0, -1), E: Vector2i(1, 0), S: Vector2i(0, 1), W: Vector2i(-1, 0) }
const OPPOSITE = { N: S, E: W, S: N, W: E }

var grid_size: int = 5
var time_left: float = 30.0
var qi_color: Color = Color(0.4, 0.8, 1.0)
var title: String = ""

var _tiles: Array = [] # [y][x] -> bitmask
var _start_row: int = 0
var _end_row: int = 0
var _connected := {}
var _running := true

var _board: Control
var _timer_label: Label
var _close_btn: Button

func setup(p_title: String, p_size: int, p_time: float, p_color: Color) -> void:
	title = p_title
	grid_size = p_size
	time_left = p_time
	qi_color = p_color

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_generate()

	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel = PanelContainer.new()
	center.add_child(panel)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)

	v.add_child(UIKit.label(title, 22, WuxiaTheme.BRONZE.lightened(0.2)))
	v.add_child(UIKit.label("คลิกช่องเพื่อหมุนเส้นลมปราณ ต่อจากตันเถียน (ซ้าย) ไปยังแกนกลาง (ขวา)", 15, WuxiaTheme.PAPER_DIM))
	_timer_label = UIKit.label("", 20)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_timer_label)

	var board_px = min(64 * grid_size, 460)
	_board = Control.new()
	_board.custom_minimum_size = Vector2(board_px + 80, board_px)
	_board.draw.connect(_draw_board)
	_board.gui_input.connect(_on_board_input)
	v.add_child(_board)

	_close_btn = UIKit.button("ยอมแพ้ (ธาตุไฟแตกซ่าน)", func(): _end(false))
	v.add_child(_close_btn)
	_update_connected()

# ── สร้างปริศนาที่แก้ได้แน่นอน ──

func _generate() -> void:
	_start_row = randi() % grid_size
	_end_row = randi() % grid_size
	var path = _random_path(Vector2i(0, _start_row), Vector2i(grid_size - 1, _end_row))
	_tiles = []
	for y in grid_size:
		var row = []
		for x in grid_size:
			row.append([N | S, N | E, N | E | S].pick_random())
		_tiles.append(row)
	# เส้นทางจริง
	for i in path.size():
		var p: Vector2i = path[i]
		var mask = 0
		mask |= W if i == 0 else _dir_between(p, path[i - 1])
		mask |= E if i == path.size() - 1 else _dir_between(p, path[i + 1])
		_tiles[p.y][p.x] = mask
	# สุ่มหมุนทุกช่อง
	for y in grid_size:
		for x in grid_size:
			for r in randi() % 4:
				_tiles[y][x] = _rotate(_tiles[y][x])
	_update_connected()
	if _is_solved():
		_tiles[path[0].y][path[0].x] = _rotate(_tiles[path[0].y][path[0].x])

## เดินสุ่มแบบไม่ทับทาง (DFS) จาก a ไป b
func _random_path(a: Vector2i, b: Vector2i) -> Array:
	var stack = [a]
	var visited = { a: true }
	while not stack.is_empty():
		var cur: Vector2i = stack[-1]
		if cur == b: return stack
		var options = []
		for d in DIRS.values():
			var n = cur + d
			if n.x >= 0 and n.y >= 0 and n.x < grid_size and n.y < grid_size and not visited.has(n):
				options.append(n)
		if options.is_empty():
			stack.pop_back()
			continue
		# เอนเอียงไปทางขวาเล็กน้อยให้เส้นทางไม่วนนานเกินไป
		options.shuffle()
		var nxt = options[0]
		if randf() < 0.4:
			for o in options:
				if o.x > cur.x: nxt = o
		visited[nxt] = true
		stack.append(nxt)
	return [a]

func _dir_between(from: Vector2i, to: Vector2i) -> int:
	for d in DIRS:
		if from + DIRS[d] == to: return d
	return 0

func _rotate(mask: int) -> int:
	return ((mask << 1) | (mask >> 3)) & 15

# ── ตรวจการไหลของปราณ ──

func _update_connected() -> void:
	_connected = {}
	var start = Vector2i(0, _start_row)
	if not (_tiles[start.y][start.x] & W): return
	var queue = [start]
	_connected[start] = true
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		var mask: int = _tiles[cur.y][cur.x]
		for d in DIRS:
			if not (mask & d): continue
			var n: Vector2i = cur + DIRS[d]
			if n.x < 0 or n.y < 0 or n.x >= grid_size or n.y >= grid_size: continue
			if _connected.has(n): continue
			if _tiles[n.y][n.x] & OPPOSITE[d]:
				_connected[n] = true
				queue.append(n)

func _is_solved() -> bool:
	var end = Vector2i(grid_size - 1, _end_row)
	return _connected.has(end) and (_tiles[end.y][end.x] & E)

func _process(delta: float) -> void:
	if not _running: return
	time_left -= delta
	_timer_label.text = "เวลาที่เหลือ: %.1f วินาที" % max(0.0, time_left)
	if time_left <= 5.0:
		_timer_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
	if time_left <= 0.0:
		_end(false)

func _cell_size() -> float:
	return (_board.size.y) / grid_size

func _on_board_input(event: InputEvent) -> void:
	if not _running: return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cs = _cell_size()
		var local = event.position - Vector2(40, 0)
		var cell = Vector2i(int(local.x / cs), int(local.y / cs))
		if local.x < 0 or cell.x < 0 or cell.y < 0 or cell.x >= grid_size or cell.y >= grid_size: return
		_tiles[cell.y][cell.x] = _rotate(_tiles[cell.y][cell.x])
		_update_connected()
		_board.queue_redraw()
		if _is_solved():
			_end(true)

func _end(success: bool) -> void:
	if not _running: return
	_running = false
	_board.queue_redraw()
	if success:
		_timer_label.text = "ลมปราณไหลเวียนครบวงจร! ทะลวงคอขวดสำเร็จ"
		_timer_label.add_theme_color_override("font_color", Color(0.5, 1, 0.6))
	else:
		_timer_label.text = "ลมปราณติดขัด... ธาตุไฟแตกซ่าน!"
		_timer_label.add_theme_color_override("font_color", Color(1, 0.35, 0.35))
		VFX.screen_shake(self, 10.0, 0.4)
	await get_tree().create_timer(1.2).timeout
	finished.emit(success)
	queue_free()

func _draw_board() -> void:
	var cs = _cell_size()
	var off = Vector2(40, 0)
	var dim_color = Color(0.45, 0.4, 0.35)
	for y in grid_size:
		for x in grid_size:
			var rect = Rect2(off + Vector2(x, y) * cs, Vector2(cs, cs))
			_board.draw_rect(rect.grow(-2), Color(0.12, 0.1, 0.08))
			var c = rect.get_center()
			var lit = _connected.has(Vector2i(x, y))
			var col = qi_color if lit else dim_color
			var mask: int = _tiles[y][x]
			for d in DIRS:
				if mask & d:
					_board.draw_line(c, c + Vector2(DIRS[d]) * cs / 2.0, col, cs * 0.18 if lit else cs * 0.12)
			_board.draw_circle(c, cs * 0.1, col)
	# ตันเถียน (จุดเริ่ม) และ แกนกลาง (เป้าหมาย)
	var start_c = off + Vector2(-cs * 0.3, (_start_row + 0.5) * cs)
	_board.draw_line(start_c, start_c + Vector2(cs * 0.3, 0), qi_color, cs * 0.18)
	_board.draw_circle(start_c, cs * 0.22, qi_color)
	var end_c = off + Vector2(grid_size * cs + cs * 0.3, (_end_row + 0.5) * cs)
	var solved = _is_solved()
	_board.draw_line(end_c - Vector2(cs * 0.3, 0), end_c, qi_color if solved else dim_color, cs * 0.18)
	_board.draw_circle(end_c, cs * 0.26, Color(1, 0.85, 0.3) if solved else Color(0.6, 0.5, 0.25))
