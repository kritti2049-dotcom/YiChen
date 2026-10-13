extends VBoxContainer
class_name RealmTree

## ผังขั้นบำเพ็ญ (Realm Tree) แบบแผนผังต้นไม้ อ่านลำดับขั้นทั้งหมดจาก RealmDB
## - ลำต้น = ขั้นใหญ่ (ล่างสุดคือคนธรรมดา บนสุดคือเซียนสวรรค์) กิ่ง = ขั้นย่อย 1-9 (ขั้น 9 = คอขวด)
## - โหนดที่ผ่านแล้วสว่างตามสีของขั้น, โหนดปัจจุบันมีกรอบเรืองแสง + วงแหวน TextureProgressBar แสดง % ลมปราณ
## - ส่วนหัวบอกเป้าหมายระยะสั้น (ต้องสะสมลมปราณอีกเท่าไหร่) และพลังรบเมื่อถึงขั้นใหญ่ถัดไป
## เป็น View ล้วนๆ: อ่าน DiscipleData และรีเฟรชเมื่อ GameController ยิง disciple_changed

const ROW_H = 74.0
const TRUNK_X = 46.0
const MINOR_X0 = 250.0
const MINOR_GAP = 50.0
const PAD_TOP = 30.0
const RING_SIZE = 44

var d: DiscipleData
var _canvas: Control
var _scroll: ScrollContainer
var _header: VBoxContainer
var _ring: TextureProgressBar

static var _ring_tex: Array[Texture2D] = []

static func create(disciple: DiscipleData) -> RealmTree:
	var t = RealmTree.new()
	t.d = disciple
	return t

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_header = VBoxContainer.new()
	add_child(_header)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.custom_minimum_size = Vector2(0, 320)
	add_child(_scroll)
	_canvas = Control.new()
	_canvas.custom_minimum_size = Vector2(MINOR_X0 + MINOR_GAP * 9 + 20, PAD_TOP * 2 + ROW_H * (RealmDB.major_count() - 1))
	_canvas.draw.connect(_draw_tree)
	_scroll.add_child(_canvas)
	GlobalGame.controller.disciple_changed.connect(_on_disciple_changed)
	refresh()

func _on_disciple_changed(changed: DiscipleData) -> void:
	if changed == d: refresh()

func _process(_delta: float) -> void:
	_canvas.queue_redraw() # ให้กรอบเรืองแสงของโหนดปัจจุบันกะพริบ

func refresh() -> void:
	_build_header()
	_build_nodes()
	# เลื่อนให้เห็นขั้นปัจจุบัน
	await get_tree().process_frame
	_scroll.scroll_vertical = int(_row_y(RealmDB.split(d.level)[0]) - _scroll.size.y / 2.0)

# ── ตำแหน่ง ──

func _row_y(major: int) -> float:
	return PAD_TOP + (RealmDB.major_count() - 1 - major) * ROW_H

func _major_pos(major: int) -> Vector2:
	return Vector2(TRUNK_X, _row_y(major))

func _minor_pos(major: int, minor: int) -> Vector2:
	return Vector2(MINOR_X0 + (minor - 1) * MINOR_GAP, _row_y(major))

## สถานะของเลเวล: -1 = ผ่านแล้ว, 0 = ปัจจุบัน, 1 = ยังไม่ถึง
func _state(level: int) -> int:
	return -1 if level < d.level else (0 if level == d.level else 1)

# ── ส่วนหัว: เป้าหมายระยะสั้น ──

func _build_header() -> void:
	UIKit.clear(_header)
	var info = CultivationSys.get_realm_info(d.level)
	var req = CultivationSys.get_required_exp(d.level)
	var pct = clampf(d.experience / float(max(1, req)), 0.0, 1.0)
	var col: Color = RealmDB.get_major(info.major_index).color
	_header.add_child(UIKit.label("%s — %s (ตัวคูณค่าพลังต่อสู้ x%.2f)" % [d.disciple_name, d.realm_name, d.get_realm_multiplier()], 18, col))
	if info.is_bottleneck and d.experience >= req:
		var chance = CultivationSys.get_breakthrough_chance(d.level, d.get_stat("aptitude"))
		_header.add_child(UIKit.label("ลมปราณเต็มแล้ว! ติดคอขวด ต้องทะลวงที่หน้า [ทะลวงคอขวด] (โอกาสพื้นฐาน %d%%)%s" % [int(chance), " — ต้องรับทัณฑ์สวรรค์!" if CultivationSys.has_tribulation(d.level) else ""], 15, Color(1, 0.55, 0.45)))
	elif d.level >= RealmDB.max_level():
		_header.add_child(UIKit.label("บรรลุขั้นสูงสุดแล้ว", 15, Color(1, 0.9, 0.6)))
	else:
		_header.add_child(UIKit.label("ลมปราณ %d / %d (%d%%) — ต้องสะสมลมปราณอีก %d จึงจะถึง %s" % [d.experience, req, int(pct * 100), req - d.experience, CultivationSys.get_realm_info(d.level + 1).name], 15, WuxiaTheme.PAPER))
	var next_major = info.major_index + 1
	if next_major < RealmDB.major_count():
		var nm = RealmDB.get_major(next_major)
		var levels_left = RealmDB.first_level(next_major) - d.level
		var projected = _projected_power(RealmDB.first_level(next_major))
		var life = "อมตะ" if nm.lifespan < 0 else "%d ปี" % nm.lifespan
		_header.add_child(UIKit.label("ขั้นใหญ่ถัดไป: %s (อีก %d ขั้นย่อย) · ตัวคูณ x%.1f · อายุขัย %s · พลังรบรวมจะเป็นราว %d (ตอนนี้ %d)" % [nm.name, levels_left, nm.mult, life, projected, d.get_power_rating()], 14, nm.color))
	_header.add_child(UIKit.label("โหนดสว่าง = ผ่านแล้ว · กรอบเรืองแสง = ขั้นปัจจุบัน (วงแหวน = ลมปราณที่รวบรวมได้) · สี่เหลี่ยม = คอขวดขั้นใหญ่ · ชี้ที่โหนดเพื่อดูรายละเอียด", 12, WuxiaTheme.PAPER_DIM))

## พลังรบรวมโดยประมาณเมื่อถึงเลเวลเป้าหมาย (ค่ารากฐานและอุปกรณ์เท่าเดิม)
func _projected_power(level: int) -> int:
	var c = StatSys.derive_combat(d.ext_stats, RealmDB.multiplier(level), {
		"hp": d.get_equipment_bonus("hp"), "atk": d.get_equipment_bonus("atk"), "spd": d.get_equipment_bonus("spd") })
	var skill = d.get_best_attack_skill()
	var bonus = StatSys.skill_bonus(SkillDB.get_skill(skill).power) if skill != "" else 0.0
	return StatSys.combat_power(c.atk.total, c.hp.total, c.spd.total, bonus, MasterySys.skill_level(d, skill) if skill != "" else 0)

# ── โหนด (Control ใสๆ ไว้แสดง tooltip) + วงแหวนความคืบหน้า ──

func _build_nodes() -> void:
	for c in _canvas.get_children(): c.queue_free()
	for major in RealmDB.major_count():
		var m = RealmDB.get_major(major)
		var first = RealmDB.first_level(major) if major > 0 else 0
		var life = "อมตะ" if m.lifespan < 0 else "%d ปี" % m.lifespan
		_add_hotspot(_major_pos(major), 24, "%s\n%s\nตัวคูณค่าพลังต่อสู้ x%.1f · อายุขัย %s" % [m.name, m.desc, m.mult, life])
		if major == 0: continue
		for minor in range(1, 10):
			var lv = first + minor - 1
			var info = CultivationSys.get_realm_info(lv)
			_add_hotspot(_minor_pos(major, minor), 14, "%s\nตัวคูณ x%.2f · ลมปราณที่ต้องใช้ %d" % [info.name, RealmDB.multiplier(lv), CultivationSys.get_required_exp(lv)])
	# วงแหวน % ลมปราณรอบโหนดปัจจุบัน
	var s = RealmDB.split(d.level)
	var pos = _major_pos(0) if s[0] == 0 else _minor_pos(s[0], s[1])
	_ring = TextureProgressBar.new()
	_ring.fill_mode = TextureProgressBar.FILL_CLOCKWISE
	_ring.texture_under = _ring_texture(false)
	_ring.texture_progress = _ring_texture(true)
	_ring.tint_progress = RealmDB.get_major(s[0]).color.lerp(Color.WHITE, 0.3)
	_ring.max_value = max(1, CultivationSys.get_required_exp(d.level))
	_ring.value = min(d.experience, _ring.max_value)
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.position = pos - Vector2(RING_SIZE, RING_SIZE) / 2.0
	_canvas.add_child(_ring)

func _add_hotspot(center: Vector2, radius: float, tip: String) -> void:
	var h = Control.new()
	h.position = center - Vector2(radius, radius)
	h.size = Vector2(radius, radius) * 2.0
	h.tooltip_text = tip
	h.mouse_filter = Control.MOUSE_FILTER_PASS
	_canvas.add_child(h)

## วงแหวนสำหรับ TextureProgressBar (วาดด้วยโค้ด: progress = สีขาวให้ tint ได้, under = เทาจาง)
static func _ring_texture(progress: bool) -> Texture2D:
	if _ring_tex.size() == 2: return _ring_tex[1 if progress else 0]
	for p in [false, true]:
		var img = Image.create(RING_SIZE, RING_SIZE, false, Image.FORMAT_RGBA8)
		var c = Vector2(RING_SIZE, RING_SIZE) / 2.0
		for y in RING_SIZE:
			for x in RING_SIZE:
				var dist = Vector2(x + 0.5, y + 0.5).distance_to(c)
				var a = clampf(1.0 - absf(dist - 18.5) / 3.0, 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, a) if p else Color(0.3, 0.27, 0.22, a * 0.8))
		_ring_tex.append(ImageTexture.create_from_image(img))
	return _ring_tex[1 if progress else 0]

# ── วาดเส้นเชื่อมและโหนด ──

func _draw_tree() -> void:
	var font = ThemeDB.fallback_font
	var t = Time.get_ticks_msec() / 1000.0
	var glow = 0.55 + sin(t * 4.0) * 0.35
	var dim = Color(0.35, 0.32, 0.28)
	var count = RealmDB.major_count()
	# ลำต้น: เชื่อมขั้นใหญ่ทั้งหมด
	for major in range(count - 1):
		var reached = d.level >= RealmDB.first_level(major + 1)
		var col: Color = RealmDB.get_major(major + 1).color if reached else dim
		_canvas.draw_line(_major_pos(major), _major_pos(major + 1), col, 5.0 if reached else 3.0)
	for major in count:
		var m = RealmDB.get_major(major)
		var mcol: Color = m.color
		var first = RealmDB.first_level(major) if major > 0 else 0
		var reached = major == 0 or d.level >= first
		var p = _major_pos(major)
		# กิ่ง: ขั้นย่อย 1-9
		if major > 0:
			for minor in range(1, 10):
				var lv = first + minor - 1
				var a = _major_pos(major) if minor == 1 else _minor_pos(major, minor - 1)
				var b = _minor_pos(major, minor)
				var st = _state(lv)
				_canvas.draw_line(a, b, mcol if st <= 0 else dim, 3.0 if st <= 0 else 1.5)
			for minor in range(1, 10):
				var lv = first + minor - 1
				var st = _state(lv)
				var c = _minor_pos(major, minor)
				var fill: Color = mcol if st < 0 else (mcol.lerp(Color.WHITE, 0.4) if st == 0 else Color(0.18, 0.16, 0.13))
				if minor == 9:
					var r = Rect2(c - Vector2(11, 11), Vector2(22, 22))
					_canvas.draw_rect(r, fill)
					_canvas.draw_rect(r, mcol if st <= 0 else dim, false, 2.0)
				else:
					_canvas.draw_circle(c, 11.0, fill)
					_canvas.draw_arc(c, 11.0, 0, TAU, 24, mcol if st <= 0 else dim, 2.0)
				if st == 0:
					_canvas.draw_arc(c, 26.0, 0, TAU, 40, Color(mcol.lerp(Color.WHITE, 0.5), glow), 3.0)
					_canvas.draw_arc(c, 30.0, 0, TAU, 40, Color(mcol, glow * 0.4), 4.0)
				_canvas.draw_string(font, c + Vector2(-4, 4), str(minor), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.1, 0.08, 0.05) if st <= 0 else Color(0.5, 0.47, 0.42))
		# โหนดขั้นใหญ่
		_canvas.draw_circle(p, 20.0, mcol if reached else Color(0.2, 0.18, 0.15))
		_canvas.draw_arc(p, 20.0, 0, TAU, 32, mcol.lightened(0.3) if reached else dim, 3.0)
		if major == 0 and d.level <= 0:
			_canvas.draw_arc(p, 30.0, 0, TAU, 40, Color(1, 1, 1, glow), 3.0)
		var text_col: Color = mcol if reached else Color(0.5, 0.47, 0.42)
		_canvas.draw_string(font, p + Vector2(30, -4), m.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, text_col)
		_canvas.draw_string(font, p + Vector2(30, 14), "x%s · อายุขัย %s" % [str(m.mult), "อมตะ" if m.lifespan < 0 else str(m.lifespan)], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(text_col, 0.8))
