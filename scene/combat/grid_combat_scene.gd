extends Node

## ฉากต่อสู้แบบ HD-2D (แนว Octopath Traveller / Wandering Sword): สนามเป็นฉาก 3D จริง ตัวละครเป็นสไปรต์พิกเซล 2D ตั้งหันหาจอ (billboard)
## - แท่นสนามยกระดับ 12x6 ช่อง เส้นกริดเรืองแสง ป่ายามค่ำ คบไฟส่องแสงจริง (OmniLight3D) แสงจันทร์ทอดเงา
## - WorldEnvironment: เรืองแสง (glow) หมอก ระยะชัดตื้นเบลอใกล้/ไกล (แบบโมเดลจำลอง) ละอองแสงลอย
## - UI / ตัวเลขดาเมจ / รอยฟัน อยู่บนชั้น 2D ทับฉาก (ตำแหน่งจาก Camera3D.unproject_position)
## ตรรกะทั้งหมดอยู่ที่ BattleRules/BattleState/BattleAI ฉากนี้แค่รับอินพุตและเล่นแอนิเมชันตาม "เหตุการณ์"
## ฝ่ายเรา: คลิกช่องสีฟ้า = เดิน · เลือกการ์ด แล้วคลิกช่องสีส้ม = ใช้ท่า (เห็นพื้นที่โดนสีแดง) · คลิกขวา/Esc = ยกเลิก · Space = จบเทิร์น

const UNIT_H = 1.75 # ความสูงตัวละคร (หน่วยโลก)
const TYPE_COLORS = {
	"sword": Color(0.45, 0.95, 0.55), "saber": Color(0.45, 0.95, 0.55), "spear": Color(0.45, 0.8, 1.0), "palm": Color(1.0, 0.6, 0.3),
	"fist": Color(1.0, 0.6, 0.3), "hidden_weapon": Color(0.9, 0.85, 0.4), "hidden": Color(0.9, 0.85, 0.4), "poison": Color(0.6, 1.0, 0.3),
	"formation": Color(1.0, 0.82, 0.3), "internal": Color(0.55, 0.7, 1.0), "movement": Color(1.0, 0.92, 0.6), "": Color(0.85, 0.85, 0.85),
}
const TYPE_GLYPH = { "sword": "ก", "saber": "ด", "spear": "ท", "palm": "ฝ", "fist": "ฝ", "hidden_weapon": "ล", "hidden": "ล", "poison": "พ", "formation": "ค", "internal": "ป", "movement": "บ", "": "ต" }

var st: BattleState
var views := {} # id -> Node3D (มีลูก Sprite3D ชื่อ Sprite)
var cur: Dictionary = {}
var mode := "busy" # idle | aim | busy | over
var sel_action := ""
var aim_cells: Array[Vector2i] = []
var reach := {}
var hover := Vector2i(-99, -99)
var auto_all := false
var speed := 1.0

var _world: Node3D
var _cam: Camera3D
var _cam_base: Vector3
## กล้องปรับได้ระหว่างศึก: ล้อเมาส์ซูม (0.55-1.5) · WASD/ลูกศร หรือลากเมาส์กลางเพื่อเลื่อน
var _cam_look := Vector3.ZERO
var _view_zoom := 1.0
var _pan := Vector3.ZERO
var _marks := {} # Vector2i -> MeshInstance3D
var _mats := {}
var _torch_lights: Array[OmniLight3D] = []
var _fx: Node2D
var _overlay: Control
var _bars := {} # id -> { bar, status }
var _order_box: HBoxContainer
var _aim_info: RichTextLabel
var _cards: HBoxContainer
var _log: RichTextLabel
var _auto_btn: Button
var _speed_btn: Button
var _portrait: TextureRect
var _card_name: Label
var _hp_bar: ProgressBar
var _qi_bar: ProgressBar
var _hp_text: Label
var _qi_text: Label
var _stats: Label
var _auto_one_btn: CheckBox
var _round_btns := {}
var _result: PanelContainer
var _result_label: Label
var _shake := 0.0

static func cell_pos(c: Vector2i) -> Vector3:
	return Vector3(c.x + 0.5, 0.0, c.y + 0.5)

func screen_of(p: Vector3) -> Vector2:
	return _cam.unproject_position(p)

func _unit_screen(id: int, h := UNIT_H) -> Vector2:
	if not views.has(id): return Vector2.ZERO
	return screen_of(views[id].global_position + Vector3(0, h, 0))

## เมาส์ -> ช่องกริด (ยิงรังสีจากกล้องลงระนาบพื้น y = 0)
func grid_of_mouse(mp = null) -> Vector2i:
	if mp == null: mp = get_viewport().get_mouse_position()
	var o = _cam.project_ray_origin(mp)
	var d = _cam.project_ray_normal(mp)
	if absf(d.y) < 0.0001: return Vector2i(-99, -99)
	var t = -o.y / d.y
	if t < 0: return Vector2i(-99, -99)
	var p = o + d * t
	return Vector2i(floori(p.x), floori(p.z))

# ══════════════════════════════════════════
# เริ่มศึก
# ══════════════════════════════════════════

func _ready() -> void:
	_build_world()
	_build_ui()
	var allies: Array = GlobalGame.combat_allies.duplicate()
	var enemies: Array = GlobalGame.combat_enemies.duplicate()
	st = BattleRules.setup(allies, enemies, randi(), GlobalGame.combat_context)
	_build_arena()
	for u in st.units: _make_unit_view(u)
	for c in st.blocked: _make_obstacle(c, st.blocked[c])
	_log_msg("[color=yellow]เริ่มศึก![/color] คลิกช่องสีฟ้าเพื่อเดิน · เลือกการ์ดวิชา (1-9) แล้วคลิกช่องสีส้ม")
	_next_turn.call_deferred()

# ══════════════════════════════════════════
# โลก 3D: แสง สภาพแวดล้อม พื้น ป่า คบไฟ
# ══════════════════════════════════════════

func _pixel_tex(base: Color, seed_v: int, size := 32, speck := 0.06) -> ImageTexture:
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_v
	for y in size:
		for x in size:
			var n = rng.randf_range(-speck, speck)
			img.set_pixel(x, y, Color(base.r + n, base.g + n * 1.2, base.b + n * 0.6))
	for i in size:
		var p = Vector2i(rng.randi_range(0, size - 1), rng.randi_range(1, size - 1))
		img.set_pixel(p.x, p.y, base.lightened(0.18))
		img.set_pixel(p.x, p.y - 1, base.lightened(0.1))
	return ImageTexture.create_from_image(img)

func _mat(tex: Texture2D, tint := Color.WHITE, uv := Vector3.ONE) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_texture = tex
	m.albedo_color = tint
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.uv1_scale = uv
	m.roughness = 1.0
	return m

func _flat_mat(col: Color, unshaded := true, emission := 0.0) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = col
	if col.a < 1.0: m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if unshaded: m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = Color(col.r, col.g, col.b)
		m.emission_energy_multiplier = emission
	return m

## ธีมฉากต่อสู้ (แนว Wandering Sword: จีนโบราณ ภาพคมกว่า Octopath — เบลอระยะไกลเล็กน้อย ไม่เบลอระยะใกล้)
## bamboo = ป่าไผ่ · snow = ภูเขาหิมะ · town = หน้าโรงเตี๊ยม/ถนนเมือง · courtyard = ลานสำนัก
var theme := "bamboo"
## 0 = กลางวัน, 1 = เย็น, 2 = กลางคืน (ตามช่วงเวลาในเกม)
var tod := 0

func _pick_theme() -> void:
	var ctx = GlobalGame.combat_context
	var ctype: String = ctx.get("type", "")
	var node_id: String = ctx.get("node", GlobalGame.field_node if ctype == "field" else "")
	var node: Dictionary = WorldDB.NODES.get(node_id, {})
	if ctype in ["raid", "siege", "spar"]: theme = "courtyard"
	elif ctype in ["city_guard", "arena", "roster_spar", "recruit_duel", "bounty"] or node.get("type", -1) == WorldDB.NodeType.CITY: theme = "town"
	elif node.get("region", "") in ["north_steppe", "shanxi", "shaanxi", "nw_underground"]: theme = "snow"
	else: theme = "bamboo"
	if ctx.has("theme"): theme = ctx.theme
	# ขนาดสนามต้องรู้ก่อนสร้างฉาก (BattleRules.setup คำนวณซ้ำได้ค่าเดิม)
	BattleRules.apply_arena_size(ctx, min(GlobalGame.combat_allies.size(), 6) + min(GlobalGame.combat_enemies.size(), 6))
	tod = GlobalGame.current_sect.time_phase if GlobalGame.current_sect != null else 0

func _sprite3d(tex: Texture2D, px: float, pos: Vector3, tint := Color.WHITE) -> Sprite3D:
	var s = Sprite3D.new()
	s.texture = tex
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.shaded = true
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.pixel_size = px
	s.offset = Vector2(0, tex.get_height() / 2.0)
	s.position = pos
	s.modulate = tint
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return s

## กอไผ่พิกเซล (ลำไผ่มีข้อ + ใบเรียว) สุ่มคงที่ตาม v
static func _bamboo_tex(v: int) -> ImageTexture:
	var img = ArtGen._new_image(48, 160)
	var rng = RandomNumberGenerator.new()
	rng.seed = 700 + v
	for k in rng.randi_range(3, 5):
		var x = rng.randi_range(6, 40)
		var top = rng.randi_range(4, 40)
		var col = Color(0.42, 0.62, 0.3).darkened(rng.randf_range(0.0, 0.3))
		ArtGen.rect(img, Rect2(x, top, 3, 160 - top), col)
		ArtGen.rect(img, Rect2(x, top, 1, 160 - top), col.lightened(0.2))
		var y = top + rng.randi_range(6, 14)
		while y < 158:
			ArtGen.rect(img, Rect2(x - 1, y, 5, 1), col.darkened(0.35))
			y += rng.randi_range(14, 22)
		for i in rng.randi_range(5, 9):
			var ly = rng.randi_range(top, 110)
			var dir = -1 if rng.randf() < 0.5 else 1
			var leaf = Color(0.3, 0.55, 0.25).lerp(Color(0.5, 0.7, 0.3), rng.randf())
			ArtGen.poly(img, PackedVector2Array([Vector2(x + 1, ly), Vector2(x + 1 + dir * rng.randi_range(9, 15), ly + rng.randi_range(2, 6)), Vector2(x + 1, ly + 3)]), leaf)
	return ImageTexture.create_from_image(img)

## สนพิกเซลคลุมหิมะ
static func _pine_tex(v: int) -> ImageTexture:
	var img = ArtGen._new_image(64, 96)
	var rng = RandomNumberGenerator.new()
	rng.seed = 900 + v
	ArtGen.rect(img, Rect2(29, 74, 6, 22), Color(0.33, 0.24, 0.17))
	for k in 4:
		var w = 28 - k * 6 + rng.randi_range(-2, 2)
		var y0 = 18 + k * 15
		var green = Color(0.13, 0.3, 0.22).lerp(Color(0.18, 0.38, 0.28), k / 3.0)
		ArtGen.poly(img, PackedVector2Array([Vector2(32, y0 - 16), Vector2(32 + w, y0 + 20), Vector2(32 - w, y0 + 20)]), green)
		ArtGen.poly(img, PackedVector2Array([Vector2(32, y0 - 16), Vector2(32 + w * 0.55, y0 + 4), Vector2(32 - w * 0.55, y0 + 4)]), Color(0.9, 0.93, 0.98))
	return ImageTexture.create_from_image(img)

## พื้นหินปูลาน (เส้นร่องตาราง)
func _stone_tex(base: Color, seed_v: int) -> ImageTexture:
	var t: ImageTexture = _pixel_tex(base, seed_v, 32, 0.05)
	var img = t.get_image()
	for i in 32:
		img.set_pixel(i, 0, base.darkened(0.25))
		img.set_pixel(0, i, base.darkened(0.25))
		img.set_pixel(i, 16, base.darkened(0.18))
		img.set_pixel(16 if i < 16 else 8, i, base.darkened(0.18))
	return ImageTexture.create_from_image(img)

func _build_world() -> void:
	_pick_theme()
	_world = Node3D.new()
	add_child(_world)
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 0.9
	env.fog_enabled = true
	env.ssao_enabled = true
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	# แสงตามเวลา: กลางวันสว่างใส · เย็นแสงส้มต่ำ · กลางคืนจันทร์ฟ้าคราม
	var sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	match tod:
		0:
			env.background_color = Color(0.62, 0.74, 0.86)
			env.ambient_light_color = Color(0.75, 0.8, 0.88)
			env.ambient_light_energy = 0.5
			env.fog_light_color = Color(0.72, 0.8, 0.86)
			env.fog_density = 0.006
			sun.light_color = Color(1.0, 0.96, 0.88)
			sun.light_energy = 1.4
			sun.rotation_degrees = Vector3(-55, -35, 0)
		1:
			env.background_color = Color(0.85, 0.55, 0.38)
			env.ambient_light_color = Color(0.7, 0.55, 0.5)
			env.ambient_light_energy = 0.55
			env.fog_light_color = Color(0.8, 0.55, 0.4)
			env.fog_density = 0.009
			sun.light_color = Color(1.0, 0.7, 0.45)
			sun.light_energy = 1.1
			sun.rotation_degrees = Vector3(-22, -60, 0)
		_:
			env.background_color = Color(0.03, 0.05, 0.08)
			env.ambient_light_color = Color(0.32, 0.38, 0.52)
			env.ambient_light_energy = 0.95
			env.fog_light_color = Color(0.1, 0.13, 0.18)
			env.fog_density = 0.025
			sun.light_color = Color(0.62, 0.72, 1.0)
			sun.light_energy = 0.7
			sun.rotation_degrees = Vector3(-52, -28, 0)
	if theme == "snow":
		env.fog_light_color = env.fog_light_color.lerp(Color(0.85, 0.9, 1.0), 0.5 if tod != 2 else 0.15)
		env.fog_density += 0.004
		env.ambient_light_energy *= 0.8
	if theme == "bamboo":
		env.fog_light_color = env.fog_light_color.lerp(Color(0.55, 0.75, 0.55), 0.35)
	var we = WorldEnvironment.new()
	we.environment = env
	# ภาพคมแบบ Wandering Sword: เบลอเฉพาะฉากไกลเล็กน้อย
	HD2D.post(env)
	HD2D.apply_sky(env, tod)
	var attrs = CameraAttributesPractical.new()
	we.camera_attributes = attrs
	_world.add_child(we)
	HD2D.vignette(self, 0, 0.5)
	_world.add_child(sun)
	_cam = Camera3D.new()
	_cam.fov = 38.0
	# สนามใหญ่กว่ามาตรฐาน 12x6 = ถอยกล้องออกให้เห็นครบ
	var zoom = maxf(1.0, maxf(BattleState.W / 12.0, BattleState.H / 6.0))
	_cam_base = Vector3(BattleState.W / 2.0, 0.0, BattleState.H / 2.0) + Vector3(0, 11.5, 9.0) * zoom
	_cam_look = Vector3(BattleState.W / 2.0, -0.4, BattleState.H / 2.0 + 0.7)
	_cam.position = _cam_base
	_world.add_child(_cam)
	_cam.look_at(Vector3(BattleState.W / 2.0, -0.4, BattleState.H / 2.0 + 0.7))
	HD2D.tilt_shift(attrs, _cam.position.distance_to(Vector3(BattleState.W / 2.0, 0, BattleState.H / 2.0)), 6.0, 5.0, 0.06)
	HD2D.update_backdrop(HD2D.backdrop(_world, Color(0.45, 0.5, 0.45) if theme != "snow" else Color(0.7, 0.75, 0.85)), Vector3(BattleState.W / 2.0, 0, -6.0))
	_cam.make_current()
	# พื้นรอบสนาม
	var ground_col = { "bamboo": Color(0.27, 0.36, 0.2), "snow": Color(0.78, 0.82, 0.88), "town": Color(0.45, 0.4, 0.34), "courtyard": Color(0.4, 0.38, 0.33) }[theme]
	var ground = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2(80, 80)
	ground.mesh = plane
	ground.position = Vector3(BattleState.W / 2.0, -0.18, BattleState.H / 2.0)
	ground.material_override = _mat(_pixel_tex(ground_col, 11, 32, 0.05), Color.WHITE, Vector3(80, 80, 1))
	_world.add_child(ground)
	match theme:
		"bamboo": _build_bamboo()
		"snow": _build_snow()
		"town": _build_town()
		"courtyard": _build_courtyard()
	if tod >= 1 and theme in ["bamboo", "snow"]:
		for x in [-0.6, BattleState.W + 0.6]: _make_torch(Vector3(x, 0, -0.4))
	_build_particles()
	_build_foliage()

## กอหญ้า/ดอกไม้รอบสนามและบนช่องหญ้าสูง (ไหวตามลม)
func _build_foliage() -> void:
	if theme in ["town", "courtyard"]: return
	var rng = RandomNumberGenerator.new()
	rng.seed = 7311
	var pts: Array = []
	for i in 900:
		var p = Vector3(rng.randf_range(-8, BattleState.W + 8), 0.0, rng.randf_range(-6, BattleState.H + 5))
		if p.x > -0.2 and p.x < BattleState.W + 0.2 and p.z > -0.2 and p.z < BattleState.H + 0.2: continue
		pts.append(p - Vector3(0, 0.18, 0))
	var col = Color(0.4, 0.6, 0.28) if theme == "bamboo" else Color(0.62, 0.66, 0.6)
	HD2D.scatter_foliage(_world, pts, col, 0.25 if theme == "bamboo" else 0.05, 0.7)

func _build_bamboo() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 4401
	var texs: Array = []
	for v in 4: texs.append(_bamboo_tex(v))
	for i in 170:
		var p = Vector3(rng.randf_range(-12, BattleState.W + 12), 0, rng.randf_range(-12, BattleState.H + 4))
		if p.x > -1.2 and p.x < BattleState.W + 1.2 and p.z > -1.2 and p.z < BattleState.H + 1.2: continue
		if p.z > BattleState.H + 1.0 and absf(p.x - BattleState.W / 2.0) < 9.0: continue
		_world.add_child(_sprite3d(texs[rng.randi() % texs.size()], rng.randf_range(0.03, 0.045), p, Color(0.92, 1, 0.9).darkened(rng.randf_range(0, 0.25))))
	for i in 8:
		_world.add_child(_rock(Vector3(rng.randf_range(-5, BattleState.W + 5), 0, rng.randf_range(-5, -1.5)), rng.randf_range(0.5, 1.0), rng))

func _build_snow() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 5502
	var texs: Array = []
	for v in 3: texs.append(_pine_tex(v))
	for i in 120:
		var p = Vector3(rng.randf_range(-12, BattleState.W + 12), 0, rng.randf_range(-12, BattleState.H + 4))
		if p.x > -1.2 and p.x < BattleState.W + 1.2 and p.z > -1.2 and p.z < BattleState.H + 1.2: continue
		if p.z > BattleState.H + 1.0 and absf(p.x - BattleState.W / 2.0) < 9.0: continue
		_world.add_child(_sprite3d(texs[rng.randi() % texs.size()], rng.randf_range(0.035, 0.055), p))
	# ทิวเขาหิมะไกลๆ
	for i in 7:
		var m = MeshInstance3D.new()
		var cone = CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = rng.randf_range(6, 10)
		cone.height = rng.randf_range(7, 12)
		cone.radial_segments = 6
		m.mesh = cone
		m.position = Vector3(rng.randf_range(-15, BattleState.W + 15), cone.height / 2.0 - 1.0, rng.randf_range(-30, -20))
		m.material_override = _mat(_pixel_tex(Color(0.78, 0.82, 0.9), rng.randi(), 16, 0.04))
		_world.add_child(m)
	for i in 10:
		_world.add_child(_rock(Vector3(rng.randf_range(-5, BattleState.W + 5), 0, rng.randf_range(-5, -1.5)), rng.randf_range(0.5, 1.1), rng))

## อาคารไม้จีน: ผนังปูน เสาแดง หลังคากระเบื้องจั่ว (PrismMesh) โคมแดงมีแสง
func _house(pos: Vector3, w: float, d: float, h: float, roof: Color, lantern := true) -> void:
	var wall = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = Vector3(w, h, d)
	wall.mesh = bm
	wall.position = pos + Vector3(0, h / 2.0, 0)
	wall.material_override = _mat(_pixel_tex(Color(0.82, 0.76, 0.64), int(pos.x * 7 + pos.z), 32, 0.04))
	_world.add_child(wall)
	for sx in [-1, 1]:
		var col = MeshInstance3D.new()
		var cm = CylinderMesh.new()
		cm.top_radius = 0.09
		cm.bottom_radius = 0.09
		cm.height = h
		col.mesh = cm
		col.position = pos + Vector3(sx * (w / 2.0 - 0.15), h / 2.0, d / 2.0 + 0.05)
		col.material_override = _flat_mat(Color(0.6, 0.12, 0.1), false)
		_world.add_child(col)
	var r = MeshInstance3D.new()
	var pm = PrismMesh.new()
	pm.size = Vector3(w + 0.8, 1.1, d + 0.8)
	r.mesh = pm
	r.position = pos + Vector3(0, h + 0.55, 0)
	r.material_override = _mat(_pixel_tex(roof, int(pos.x * 13), 16, 0.06))
	_world.add_child(r)
	if lantern:
		var lan = MeshInstance3D.new()
		var sm = SphereMesh.new()
		sm.radius = 0.16
		sm.height = 0.34
		lan.mesh = sm
		lan.position = pos + Vector3(w / 2.0 - 0.4, h - 0.4, d / 2.0 + 0.3)
		lan.material_override = _flat_mat(Color(1.0, 0.25, 0.15), true, 4.0)
		_world.add_child(lan)
		if tod >= 1:
			var light = OmniLight3D.new()
			light.light_color = Color(1.0, 0.45, 0.3)
			light.light_energy = 1.6
			light.omni_range = 5.5
			light.position = lan.position
			_world.add_child(light)
			_torch_lights.append(light)

func _build_town() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 6603
	# แถวอาคารหลังสนาม (โรงเตี๊ยม/ร้านค้า) และด้านข้าง
	var x = -6.0
	while x < BattleState.W + 6:
		var w = rng.randf_range(3.0, 4.5)
		_house(Vector3(x + w / 2.0, 0, -2.6 - rng.randf_range(0, 0.6)), w, 2.4, rng.randf_range(2.0, 2.8), [Color(0.25, 0.22, 0.24), Color(0.2, 0.28, 0.32), Color(0.35, 0.18, 0.15)][rng.randi() % 3])
		x += w + 0.4
	for side in [-1, 1]:
		_house(Vector3(BattleState.W / 2.0 + side * (BattleState.W / 2.0 + 6.5), 0, BattleState.H / 2.0 - 2), 3.0, 4.0, 2.4, Color(0.25, 0.22, 0.24))
	# ถังไม้/ไหเหล้าเรียงริมทาง
	for i in 8:
		var b = MeshInstance3D.new()
		var cm = CylinderMesh.new()
		cm.top_radius = 0.25
		cm.bottom_radius = 0.28
		cm.height = 0.6
		b.mesh = cm
		b.position = Vector3(rng.randf_range(-2, BattleState.W + 2), 0.3, rng.randf_range(-1.6, -1.0))
		b.material_override = _mat(_pixel_tex(Color(0.45, 0.32, 0.2), i, 16, 0.06))
		_world.add_child(b)

func _build_courtyard() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 7704
	# ท้องพระโรงด้านหลัง + กำแพงสองข้าง + ต้นสน/บ๊วย
	_house(Vector3(BattleState.W / 2.0, 0, -4.0), 9.0, 3.0, 3.2, Color(0.22, 0.25, 0.32))
	for side in [-1, 1]:
		_house(Vector3(BattleState.W / 2.0 + side * 6.5, 0, -3.2), 3.0, 2.4, 2.4, Color(0.22, 0.25, 0.32), false)
		var wall = MeshInstance3D.new()
		var bm = BoxMesh.new()
		bm.size = Vector3(0.5, 1.6, BattleState.H + 6)
		wall.mesh = bm
		wall.position = Vector3(BattleState.W / 2.0 + side * (BattleState.W / 2.0 + 2.5), 0.8, BattleState.H / 2.0 - 1)
		wall.material_override = _mat(_pixel_tex(Color(0.7, 0.3, 0.25), 70 + side, 32, 0.04))
		_world.add_child(wall)
	var atlas = ArtGen.make_tree_atlas()
	for i in 10:
		var tex = AtlasTexture.new()
		tex.atlas = atlas
		tex.region = Rect2(64 * (i % 3), 0, 64, 64)
		_world.add_child(_sprite3d(tex, 0.05, Vector3(rng.randf_range(-8, BattleState.W + 8), 0, rng.randf_range(-9, -6))))

## อนุภาคบรรยากาศ: หิมะตก (ภูเขาหิมะ) · ใบไผ่ปลิว (ป่าไผ่) · หิ่งห้อย/ฝุ่นแสง (กลางคืน/เมือง)
func _build_particles() -> void:
	var p = CPUParticles3D.new()
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	var q = QuadMesh.new()
	var qm: StandardMaterial3D
	match theme:
		"snow":
			p.amount = 260
			p.lifetime = 7.0
			p.emission_box_extents = Vector3(BattleState.W / 2.0 + 6, 0.5, BattleState.H / 2.0 + 6)
			p.position = Vector3(BattleState.W / 2.0, 7.0, BattleState.H / 2.0)
			p.gravity = Vector3(0.3, -1.0, 0)
			q.size = Vector2(0.06, 0.06)
			qm = _flat_mat(Color(1, 1, 1), true, 1.0)
		"bamboo":
			p.amount = 40
			p.lifetime = 8.0
			p.emission_box_extents = Vector3(BattleState.W / 2.0 + 4, 0.5, BattleState.H / 2.0 + 4)
			p.position = Vector3(BattleState.W / 2.0, 5.0, BattleState.H / 2.0)
			p.gravity = Vector3(0.4, -0.35, 0)
			p.angular_velocity_min = -90
			p.angular_velocity_max = 90
			q.size = Vector2(0.14, 0.05)
			qm = _flat_mat(Color(0.45, 0.68, 0.3), false)
		_:
			p.amount = 60 if tod == 2 else 25
			p.lifetime = 6.0
			p.emission_box_extents = Vector3(BattleState.W / 2.0 + 2, 1.2, BattleState.H / 2.0 + 2)
			p.position = Vector3(BattleState.W / 2.0, 1.4, BattleState.H / 2.0)
			p.direction = Vector3.UP
			p.spread = 180.0
			p.gravity = Vector3.ZERO
			p.initial_velocity_min = 0.05
			p.initial_velocity_max = 0.2
			q.size = Vector2(0.05, 0.05)
			qm = _flat_mat(Color(0.85, 1.0, 0.55) if tod == 2 else Color(1.0, 0.95, 0.8, 0.7), true, 4.0 if tod == 2 else 1.0)
	p.preprocess = p.lifetime
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	q.material = qm
	p.mesh = q
	_world.add_child(p)

func _rock(p: Vector3, size: float, rng: RandomNumberGenerator) -> MeshInstance3D:
	var m = MeshInstance3D.new()
	var sph = SphereMesh.new()
	sph.radial_segments = 7
	sph.rings = 3
	sph.radius = size * 0.6
	sph.height = size * 0.9
	m.mesh = sph
	m.position = p + Vector3(0, size * 0.2, 0)
	m.rotation_degrees = Vector3(0, rng.randf_range(0, 360), rng.randf_range(-8, 8))
	m.material_override = _mat(_pixel_tex(Color(0.38, 0.39, 0.42), rng.randi(), 16, 0.08))
	return m

func _make_torch(p: Vector3) -> void:
	var post = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.06
	cyl.bottom_radius = 0.08
	cyl.height = 1.6
	post.mesh = cyl
	post.position = p + Vector3(0, 0.8, 0)
	post.material_override = _flat_mat(Color(0.3, 0.2, 0.12), false)
	_world.add_child(post)
	var flame = MeshInstance3D.new()
	var sph = SphereMesh.new()
	sph.radius = 0.13
	sph.height = 0.32
	flame.mesh = sph
	flame.position = p + Vector3(0, 1.72, 0)
	flame.material_override = _flat_mat(Color(1.0, 0.6, 0.2), true, 6.0)
	_world.add_child(flame)
	var light = OmniLight3D.new()
	light.light_color = Color(1.0, 0.62, 0.32)
	light.light_energy = 2.4
	light.omni_range = 8.0
	light.shadow_enabled = true
	light.position = p + Vector3(0, 1.9, 0)
	_world.add_child(light)
	_torch_lights.append(light)

## แท่นสนาม: ช่องละ 1 กล่องเตี้ย (ลายหญ้าพิกเซล สลับเฉด) + เส้นกริดเรืองแสง + แผ่นไฮไลต์ต่อช่อง
func _build_arena() -> void:
	var tex_a: Texture2D
	var tex_b: Texture2D
	match theme:
		"snow":
			tex_a = _pixel_tex(Color(0.8, 0.84, 0.9), 21, 32, 0.04)
			tex_b = _pixel_tex(Color(0.76, 0.8, 0.87), 22, 32, 0.04)
		"town", "courtyard":
			tex_a = _stone_tex(Color(0.6, 0.57, 0.52), 21)
			tex_b = _stone_tex(Color(0.56, 0.53, 0.49), 22)
		_:
			tex_a = _pixel_tex(Color(0.36, 0.48, 0.24), 21)
			tex_b = _pixel_tex(Color(0.33, 0.45, 0.22), 22)
	var tex_tall = _pixel_tex(Color(0.22, 0.42, 0.16) if theme != "snow" else Color(0.6, 0.68, 0.72), 23, 32, 0.1)
	var side = _mat(_pixel_tex(Color(0.33, 0.27, 0.2) if theme != "snow" else Color(0.55, 0.55, 0.6), 24))
	var box = BoxMesh.new()
	box.size = Vector3(0.9, 0.18, 0.9)
	for x in BattleState.W:
		for y in BattleState.H:
			var c = Vector2i(x, y)
			if not st.in_grid(c): continue
			var mi = MeshInstance3D.new()
			mi.mesh = box
			mi.position = Vector3(x + 0.5, -0.09, y + 0.5)
			var tex = tex_tall if st.grass.has(c) else (tex_a if (x + y) % 2 == 0 else tex_b)
			mi.material_override = _mat(tex, Color(1.0, 0.95, 0.75) if not st.in_grid(c + Vector2i.LEFT) else Color.WHITE)
			_world.add_child(mi)
			# แผ่นไฮไลต์
			var mark = MeshInstance3D.new()
			var pm = PlaneMesh.new()
			pm.size = Vector2(0.86, 0.86)
			mark.mesh = pm
			mark.position = Vector3(x + 0.5, 0.012, y + 0.5)
			mark.visible = false
			mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_world.add_child(mark)
			_marks[c] = mark
	if BattleState.shape == "circle": _build_ring_rim(side)
	var tall: Array = []
	var trng = RandomNumberGenerator.new()
	trng.seed = 55
	for c in st.grass:
		for k in 4: tall.append(Vector3(c.x + trng.randf_range(0.1, 0.9), 0.0, c.y + trng.randf_range(0.1, 0.9)))
	if not tall.is_empty(): HD2D.scatter_foliage(_world, tall, Color(0.36, 0.56, 0.24) if theme != "snow" else Color(0.6, 0.65, 0.6), 0.1, 0.6)
	_mats = {
		"reach": _flat_mat(Color(0.08, 0.08, 0.14, 0.62), true),
		"aim": _flat_mat(Color(1.0, 0.6, 0.15, 0.42), true, 0.6),
		"area": _flat_mat(Color(1.0, 0.2, 0.12, 0.55), true, 1.2),
		"cur": _flat_mat(Color(1.0, 0.85, 0.3, 0.45), true, 1.0),
		"hover": _flat_mat(Color(0.3, 0.6, 1.0, 0.65), true, 1.2),
	}

## ขอบลานวงกลม: หินเตี้ยเรียงตามช่องนอกวงที่ติดกับสนาม
func _build_ring_rim(side_mat: Material) -> void:
	var stone = BoxMesh.new()
	stone.size = Vector3(0.8, 0.32, 0.8)
	var rim_mat = _mat(_stone_tex(Color(0.5, 0.47, 0.43) if theme != "snow" else Color(0.66, 0.68, 0.72), 31))
	var done := {}
	for x in range(-1, BattleState.W + 1):
		for y in range(-1, BattleState.H + 1):
			var c = Vector2i(x, y)
			if st.in_grid(c) or done.has(c): continue
			if not BattleState.DIRS.any(func(d): return st.in_grid(c + d)): continue
			done[c] = true
			var mi = MeshInstance3D.new()
			mi.mesh = stone
			mi.position = Vector3(x + 0.5, 0.0, y + 0.5)
			mi.material_override = rim_mat
			_world.add_child(mi)

func _make_unit_view(u: Dictionary) -> void:
	var node = Node3D.new()
	node.position = cell_pos(u.cell)
	var tex: Texture2D = HD2D.outlined(ArtGen.get_figure(u.ref) if u.ref is DiscipleData else EnemyDB.get_texture(u.ref))
	var s = Sprite3D.new()
	s.name = "Sprite"
	s.texture = tex
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.shaded = true
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.pixel_size = UNIT_H / maxf(1.0, tex.get_height())
	s.offset = Vector2(0, tex.get_height() / 2.0)
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	node.add_child(s)
	_world.add_child(node)
	views[u.id] = node
	# แถบ HP + สถานะ (ชั้น 2D ตามตำแหน่งบนจอ)
	var bar = ProgressBar.new()
	bar.show_percentage = false
	bar.size = Vector2(54, 6)
	bar.max_value = u.max_hp
	bar.value = u.hp
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill = StyleBoxFlat.new()
	fill.bg_color = Color(0.95, 0.55, 0.2) if u.team == 0 else Color(0.9, 0.25, 0.2)
	bar.add_theme_stylebox_override("fill", fill)
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.7)
	bar.add_theme_stylebox_override("background", bg)
	_overlay.add_child(bar)
	var stl = _lbl("", 10, Color(0.85, 0.65, 1))
	stl.size = Vector2(120, 14)
	stl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay.add_child(stl)
	_bars[u.id] = { "bar": bar, "status": stl }
	_face(u)

func _make_obstacle(c: Vector2i, kind: String) -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = c.x * 31 + c.y
	if kind == "tree":
		match theme:
			"bamboo": _world.add_child(_sprite3d(_bamboo_tex(absi(c.x * 3 + c.y) % 4), 0.018, cell_pos(c)))
			"snow": _world.add_child(_sprite3d(_pine_tex(absi(c.x + c.y) % 3), 0.026, cell_pos(c)))
			"town":
				# ในเมือง: กองลังไม้แทนต้นไม้
				var crate = MeshInstance3D.new()
				var bm = BoxMesh.new()
				bm.size = Vector3(0.7, 0.6, 0.7)
				crate.mesh = bm
				crate.position = cell_pos(c) + Vector3(0, 0.3, 0)
				crate.rotation_degrees.y = rng.randf_range(-20, 20)
				crate.material_override = _mat(_stone_tex(Color(0.5, 0.36, 0.22), c.x * 7 + c.y))
				_world.add_child(crate)
			_:
				var tex = AtlasTexture.new()
				tex.atlas = ArtGen.make_tree_atlas()
				tex.region = Rect2(64 * (absi(c.x + c.y) % 3), 0, 64, 64)
				_world.add_child(_sprite3d(tex, 0.03, cell_pos(c)))
	else:
		_world.add_child(_rock(cell_pos(c), 0.85, rng))

# ══════════════════════════════════════════
# UI (ชั้น 2D)
# ══════════════════════════════════════════

func _panel_style(alpha := 0.82) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.07, 0.06, alpha)
	sb.border_color = Color(0.6, 0.48, 0.28, 0.9)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb

func _lbl(text: String, size := 14, color := WuxiaTheme.PAPER) -> Label:
	var l = UIKit.label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 4)
	return l

func _build_ui() -> void:
	# ชั้นเอฟเฟกต์/แถบเลือด (อยู่ใต้ UI หลัก)
	var fx_layer = CanvasLayer.new()
	fx_layer.layer = 1
	add_child(fx_layer)
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_layer.add_child(_overlay)
	_fx = Node2D.new()
	fx_layer.add_child(_fx)

	var ui = CanvasLayer.new()
	ui.layer = 2
	add_child(ui)
	var root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)

	# ── ซ้ายบน: ข้อมูลสนามรบ ──
	var info = VBoxContainer.new()
	info.position = Vector2(14, 10)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(info)
	info.add_child(_lbl("ข้อมูลสนามรบ", 15, Color(0.95, 0.9, 0.8)))
	info.add_child(_lbl("เงื่อนไขชนะ", 13, WuxiaTheme.PAPER_DIM))
	info.add_child(_lbl("  ล้มศัตรูทั้งหมด", 14, Color(0.5, 1, 0.5)))
	info.add_child(_lbl("เงื่อนไขแพ้", 13, WuxiaTheme.PAPER_DIM))
	var lose = "  ฝ่ายเราล้มทั้งหมด" + ("  (ศึกชี้เป็นตาย: ศิษย์อาจเสียชีวิต)" if CombatResult.is_deadly(GlobalGame.combat_context) else "")
	info.add_child(_lbl(lose, 14, Color(1, 0.85, 0.35)))
	# บันทึกศึก: ซ้ายล่างเหนือกรอบตัวละคร
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.custom_minimum_size = Vector2(340, 104)
	_log.add_theme_font_size_override("normal_font_size", 12)
	_log.add_theme_font_size_override("bold_font_size", 12)
	_log.add_theme_stylebox_override("normal", _panel_style(0.5))
	_log.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_log.position = Vector2(12, -262)
	root.add_child(_log)

	# ── บนกลาง: ลำดับเทิร์น ──
	var order_panel = PanelContainer.new()
	order_panel.add_theme_stylebox_override("panel", _panel_style(0.6))
	order_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	order_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	order_panel.position.y = 10
	root.add_child(order_panel)
	_order_box = HBoxContainer.new()
	_order_box.add_theme_constant_override("separation", 8)
	order_panel.add_child(_order_box)

	# ── ขวาบน: ความเร็ว / AUTO ──
	var tr = HBoxContainer.new()
	tr.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tr.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	tr.position = Vector2(-14, 10)
	root.add_child(tr)
	_speed_btn = _round_button("x1", func():
		speed = { 1.0: 2.0, 2.0: 4.0, 4.0: 1.0 }[speed]
		_speed_btn.text = "x%d" % int(speed), 52)
	tr.add_child(_speed_btn)
	_auto_btn = _round_button("AUTO", func():
		auto_all = not auto_all
		_auto_btn.modulate = Color(1, 0.85, 0.4) if auto_all else Color.WHITE
		if auto_all and mode in ["idle", "aim"] and not cur.is_empty() and cur.team == 0: _run_ai_turn(), 52)
	_auto_btn.tooltip_text = "ให้ AI คุมทั้งทีม (กดอีกครั้งเพื่อสู้เอง)"
	tr.add_child(_auto_btn)

	# ── ซ้ายล่าง: กรอบตัวละครที่ถึงตา ──
	var card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", _panel_style(0.85))
	card.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	card.position = Vector2(12, -12)
	card.custom_minimum_size = Vector2(340, 130)
	root.add_child(card)
	var ch = HBoxContainer.new()
	card.add_child(ch)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(96, 96)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ch.add_child(_portrait)
	var cv = VBoxContainer.new()
	cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cv.add_theme_constant_override("separation", 2)
	ch.add_child(cv)
	_card_name = _lbl("", 16, Color(1, 0.95, 0.85))
	cv.add_child(_card_name)
	var hp_row = _bar_row("HP", Color(0.85, 0.3, 0.25))
	_hp_bar = hp_row[0]
	_hp_text = hp_row[1]
	cv.add_child(hp_row[2])
	var qi_row = _bar_row("ปราณ", Color(0.3, 0.55, 0.95))
	_qi_bar = qi_row[0]
	_qi_text = qi_row[1]
	cv.add_child(qi_row[2])
	_stats = _lbl("", 12, WuxiaTheme.PAPER_DIM)
	cv.add_child(_stats)
	_auto_one_btn = CheckBox.new()
	_auto_one_btn.text = "AI คุมตัวนี้"
	_auto_one_btn.add_theme_font_size_override("font_size", 12)
	_auto_one_btn.toggled.connect(func(on):
		if cur.is_empty() or cur.team != 0: return
		cur.auto = on
		if on and mode in ["idle", "aim"]: _run_ai_turn())
	cv.add_child(_auto_one_btn)

	# ── ล่างกลาง: ข้อความเล็ง + การ์ดวิชา ──
	var bottom = VBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.position.y = -12
	bottom.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(bottom)
	_aim_info = RichTextLabel.new()
	_aim_info.bbcode_enabled = true
	_aim_info.fit_content = true
	_aim_info.custom_minimum_size = Vector2(620, 0)
	_aim_info.add_theme_font_size_override("normal_font_size", 13)
	_aim_info.add_theme_color_override("font_outline_color", Color.BLACK)
	_aim_info.add_theme_constant_override("outline_size", 4)
	_aim_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(_aim_info)
	_cards = HBoxContainer.new()
	_cards.add_theme_constant_override("separation", 6)
	_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_child(_cards)

	# ── ขวาล่าง: ปุ่มกลม ──
	var rb = VBoxContainer.new()
	rb.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	rb.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	rb.grow_vertical = Control.GROW_DIRECTION_BEGIN
	rb.position = Vector2(-16, -16)
	root.add_child(rb)
	var rb1 = HBoxContainer.new()
	rb.add_child(rb1)
	_round_btns["defend"] = _round_button("ตั้งรับ", _on_defend, 66)
	_round_btns["end"] = _round_button("จบเทิร์น", _end_player_turn, 66)
	_round_btns["escape"] = _round_button("หนี", _on_escape, 66)
	_round_btns["escape"].tooltip_text = "หนีได้เมื่อยืนแถวซ้ายสุดของสนาม"
	rb1.add_child(_round_btns["defend"])
	rb1.add_child(_round_btns["end"])
	rb.add_child(_round_btns["escape"])
	_round_btns["escape"].size_flags_horizontal = Control.SIZE_SHRINK_END

	# ── ผลศึก ──
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	_result = PanelContainer.new()
	_result.add_theme_stylebox_override("panel", _panel_style(0.94))
	_result.custom_minimum_size = Vector2(560, 260)
	_result.hide()
	center.add_child(_result)
	var res_v = VBoxContainer.new()
	_result.add_child(res_v)
	_result_label = UIKit.label("", 18, WuxiaTheme.PAPER)
	_result_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	res_v.add_child(_result_label)
	res_v.add_child(UIKit.button("กลับ", func():
		GlobalGame.save_game()
		get_tree().change_scene_to_file(GlobalGame.combat_return_scene)))

func _bar_row(name: String, color: Color) -> Array:
	var row = HBoxContainer.new()
	var l = _lbl(name, 12, WuxiaTheme.PAPER_DIM)
	l.custom_minimum_size = Vector2(36, 0)
	row.add_child(l)
	var bar = ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(120, 10)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill = StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("fill", fill)
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.6)
	bar.add_theme_stylebox_override("background", bg)
	row.add_child(bar)
	var t = _lbl("", 12, WuxiaTheme.PAPER)
	t.custom_minimum_size = Vector2(70, 0)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(t)
	return [bar, t, row]

func _round_button(text: String, cb: Callable, size := 60) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(size, size)
	b.add_theme_font_size_override("font_size", 12)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var sb = StyleBoxFlat.new()
		sb.bg_color = { "normal": Color(0.12, 0.1, 0.08, 0.9), "hover": Color(0.25, 0.2, 0.12, 0.95), "pressed": Color(0.4, 0.3, 0.15), "disabled": Color(0.08, 0.08, 0.08, 0.6) }[state]
		sb.border_color = Color(0.75, 0.6, 0.35) if state != "disabled" else Color(0.3, 0.3, 0.3)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(size / 2)
		b.add_theme_stylebox_override(state, sb)
	b.pressed.connect(cb)
	return b

## การ์ดวิชา (แนวตั้ง): หมวด · ไอคอนสี · ชื่อ · ค่าปราณ · ปุ่มลัด · คูลดาวน์ทับ
func _make_card(a: Dictionary, idx: int) -> Button:
	var sp: Dictionary = a.spec
	var type: String = sp.get("type", "")
	var col: Color = TYPE_COLORS.get(type, TYPE_COLORS[""])
	var b = Button.new()
	b.custom_minimum_size = Vector2(92, 122)
	b.disabled = not a.ok or cur.acted
	b.tooltip_text = "%s\n%s · ระยะ %d · %s%s%s" % [a.name, SkillDB.TYPE_NAMES.get(type, "อาวุธ"), sp.range, _shape_name(sp), (" · " + sp.effect) if sp.effect != "" else "", ("\n" + a.why) if a.why != "" else ""]
	var selected = a.name == sel_action and mode == "aim"
	for state in ["normal", "hover", "pressed", "disabled"]:
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color(0.14, 0.12, 0.1, 0.92) if state != "hover" else Color(0.24, 0.2, 0.14, 0.95)
		if state == "disabled": sb.bg_color = Color(0.08, 0.08, 0.08, 0.85)
		sb.border_color = Color(1, 0.85, 0.4) if selected else (col.darkened(0.2) if state != "disabled" else Color(0.25, 0.25, 0.25))
		sb.set_border_width_all(3 if selected else 2)
		sb.set_corner_radius_all(6)
		b.add_theme_stylebox_override(state, sb)
	b.pressed.connect(_choose_action.bind(a.name))
	var v = VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 1)
	b.add_child(v)
	var cat = _lbl("ปกติ" if a.name == BattleRules.ATTACK else SkillDB.TYPE_NAMES.get(type, "วิชา").split("/")[0], 11, col)
	cat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(cat)
	var icon = Control.new()
	icon.custom_minimum_size = Vector2(0, 40)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.draw.connect(func():
		var c = Vector2(icon.size.x / 2.0, 20)
		icon.draw_circle(c, 18, col.darkened(0.55))
		icon.draw_arc(c, 18, 0, TAU, 28, col, 2.0)
		var f = ThemeDB.fallback_font
		icon.draw_string(f, c + Vector2(-9, 8), TYPE_GLYPH.get(type, "ต"), HORIZONTAL_ALIGNMENT_CENTER, 18, 20, col.lightened(0.3)))
	v.add_child(icon)
	var nm = UIKit.label(a.name, 11, WuxiaTheme.PAPER)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.custom_minimum_size = Vector2(86, 0)
	v.add_child(nm)
	var cost = _lbl(("ปราณ %d" % sp.qi) if a.name != BattleRules.ATTACK else "ฟื้นปราณ", 10, Color(0.6, 0.75, 1))
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(cost)
	var key = _lbl(str(idx + 1), 12, Color(1, 0.9, 0.6))
	key.position = Vector2(6, 2)
	b.add_child(key)
	var cd = int(cur.cd.get(a.name, 0))
	if cd > 0:
		var cl = _lbl(str(cd), 30, Color(1, 1, 1))
		cl.position = Vector2(36, 34)
		b.add_child(cl)
	return b

func _shape_name(sp: Dictionary) -> String:
	match sp.shape:
		"line": return "เส้นตรงยาว %d" % sp.size
		"circle": return "วงรัศมี %d" % sp.size
		"self_ring": return "รอบตัวรัศมี %d" % sp.size
	return "เป้าเดี่ยว" if sp.target != "self" else "ตัวเอง"

func _refresh_all() -> void:
	_update_marks()
	_update_order()
	_update_card()
	_update_aim_info()
	_update_cards()

func _update_order() -> void:
	for c in _order_box.get_children(): c.queue_free()
	var list: Array = [cur] if not cur.is_empty() else []
	list.append_array(st.preview_order(7))
	for i in list.size():
		var u: Dictionary = list[i]
		_order_box.add_child(_lbl(("▶ " if i == 0 else "") + u.name, 13, Color(0.7, 1, 0.7) if u.team == 0 else Color(1, 0.6, 0.55)))

func _update_card() -> void:
	if cur.is_empty(): return
	var u = cur
	_portrait.texture = ArtGen.get_portrait(u.ref) if u.ref is DiscipleData else EnemyDB.get_texture(u.ref)
	_card_name.text = u.name + ("  (ศัตรู)" if u.team == 1 else "")
	_card_name.add_theme_color_override("font_color", Color(1, 0.95, 0.85) if u.team == 0 else Color(1, 0.65, 0.6))
	_hp_bar.max_value = u.max_hp
	_hp_bar.value = u.hp
	_hp_text.text = "%d/%d" % [u.hp, u.max_hp]
	_qi_bar.max_value = u.max_qi
	_qi_bar.value = u.qi
	_qi_text.text = "%d/%d" % [u.qi, u.max_qi]
	var done = ("เดินแล้ว " if u.moved else "") + ("ใช้ท่าแล้ว" if u.acted else "")
	_stats.text = "โจมตี %d · ป้องกัน %d · ความเร็ว %d · เดิน %d%s" % [u.atk, u.def, u.spd, u.move + u.move_bonus, (" · " + done) if done != "" else ""]
	_auto_one_btn.visible = u.team == 0
	_auto_one_btn.set_pressed_no_signal(u.get("auto", false))

func _update_aim_info() -> void:
	var txt = ""
	if not cur.is_empty() and cur.team == 1: txt = "[center][color=#f99]ตาของ %s[/color][/center]" % cur.name
	elif mode == "idle" and not cur.is_empty():
		txt = "[center]ตาของคุณ — คลิกช่องสีฟ้าเพื่อเดิน · เลือกการ์ดวิชา (1-%d) แล้วคลิกช่องสีส้ม · Enter จบเทิร์น · ล้อเมาส์ซูม · WASD เลื่อนกล้อง[/center]" % mini(9, cur.skills.size() + 1)
	elif mode == "aim":
		var sp = BattleRules.spec(cur, sel_action)
		sp["name"] = sel_action
		txt = "[center][color=#fc6]%s[/color] — ระยะ %d · %s · คลิกช่องสีส้ม (คลิกขวา = ยกเลิก)" % [sel_action, sp.range, _shape_name(sp)]
		if aim_cells.has(hover):
			var parts: Array[String] = []
			for t in BattleRules.targets(st, cur, sp, BattleRules.affected(st, cur, sp, hover)):
				if sp.effect == "heal": parts.append("%s +ฟื้นฟู" % t.name)
				else: parts.append("%s ~%d (หลบ %d%%)" % [t.name, int(BattleRules.base_damage(cur, t, sp)), int(BattleRules.dodge_chance(st, cur, t) * 100)])
			if not parts.is_empty(): txt += "\nคาดว่า: " + ", ".join(parts)
		txt += "[/center]"
	_aim_info.text = txt

func _update_cards() -> void:
	for c in _cards.get_children(): c.queue_free()
	var player_turn = not cur.is_empty() and cur.team == 0 and mode in ["idle", "aim"]
	for k in _round_btns: _round_btns[k].disabled = not player_turn
	if not player_turn: return
	_round_btns["defend"].disabled = cur.acted
	_round_btns["escape"].disabled = not BattleRules.can_escape(cur)
	var acts = BattleRules.actions(cur)
	for i in mini(9, acts.size()):
		_cards.add_child(_make_card(acts[i], i))

func _log_msg(t: String) -> void:
	_log.append_text(t + "\n")

## ไฮไลต์ช่อง: เดินได้ (ฟ้า) · ระยะท่า (ส้ม) · พื้นที่โดน (แดง) · ตัวที่ถึงตา (ทอง) · เมาส์ชี้ (ขาว)
func _update_marks() -> void:
	if st == null or _mats.is_empty(): return
	var state := {}
	if mode == "idle" and not cur.is_empty():
		for c in reach:
			if c != cur.cell: state[c] = "reach"
	if mode == "aim":
		for c in aim_cells: state[c] = "aim"
		if aim_cells.has(hover):
			var sp = BattleRules.spec(cur, sel_action)
			for c in BattleRules.affected(st, cur, sp, hover): state[c] = "area"
	if not cur.is_empty() and not state.has(cur.cell): state[cur.cell] = "cur"
	if st.in_grid(hover) and mode in ["idle", "aim"] and not state.has(hover): state[hover] = "hover"
	for c in _marks:
		var m: MeshInstance3D = _marks[c]
		if state.has(c):
			m.visible = true
			m.material_override = _mats[state[c]]
		else:
			m.visible = false

func _process(delta: float) -> void:
	if st == null: return
	var h = grid_of_mouse()
	if h != hover:
		hover = h
		_update_marks()
		if mode == "aim": _update_aim_info()
	var t = Time.get_ticks_msec() / 1000.0
	for i in _torch_lights.size():
		_torch_lights[i].light_energy = 2.4 + sin(t * 9.0 + i * 2.1) * 0.25 + sin(t * 23.0 + i) * 0.12
	# แถบเลือด/สถานะลอยเหนือหัว
	for id in _bars:
		var u = st.by_id(id)
		var b = _bars[id]
		b.bar.visible = not u.down and not u.escaped
		b.bar.position = _unit_screen(id, UNIT_H + 0.18) - Vector2(27, 8)
		b.status.position = _unit_screen(id, -0.05) - Vector2(60, -2)
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta)
		var k = 0.08 * (_shake / 0.2)
		_cam.position = _cam_pos() + Vector3(randf_range(-k, k), randf_range(-k, k), 0)
	else:
		_cam.position = _cam_pos()
	_pan_keys(delta)

# ══════════════════════════════════════════
# จังหวะเทิร์น
# ══════════════════════════════════════════

func _next_turn() -> void:
	if st.over:
		_finish()
		return
	cur = st.next_actor()
	if cur.is_empty():
		_finish()
		return
	mode = "busy"
	_refresh_all()
	var s = BattleRules.start_turn(st, cur)
	await _play(s.events)
	if st.over:
		_finish()
		return
	if s.skip:
		await _wait(0.4)
		_next_turn.call_deferred()
		return
	if cur.team == 1 or cur.auto or auto_all:
		_run_ai_turn()
	else:
		_begin_player()

func _begin_player() -> void:
	var fresh = mode == "busy" and not cur.moved and not cur.acted
	mode = "idle"
	sel_action = ""
	reach = st.reachable(cur)
	_refresh_all()
	if fresh: _banner("ตาของคุณ: %s" % cur.name)

## ป้ายใหญ่กลางจอ (บอกว่าถึงตาเราแล้ว)
func _banner(text: String) -> void:
	var l = _lbl(text, 30, Color(1, 0.9, 0.5))
	l.set_anchors_preset(Control.PRESET_CENTER)
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.position.y -= 120
	_overlay.add_child(l)
	var tw = l.create_tween()
	tw.tween_interval(0.8)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)

func _run_ai_turn() -> void:
	mode = "busy"
	_refresh_all()
	await _wait(0.35)
	var plan = BattleAI.decide(st, cur, 1.0 if cur.team == 0 else _enemy_smart())
	if not cur.moved: await _play(BattleRules.do_move(st, cur, plan.cell))
	if not cur.acted:
		if plan.action != "": await _play(BattleRules.do_action(st, cur, plan.action, plan.aim))
		elif plan.get("defend", false): await _play(BattleRules.do_defend(st, cur))
	await _wait(0.25)
	_next_turn.call_deferred()

func _enemy_smart() -> float:
	var diff = GlobalGame.current_sect.difficulty if GlobalGame.current_sect != null else 1
	return [0.6, 0.8, 1.0, 1.0][clampi(diff, 0, 3)]

func _end_player_turn() -> void:
	if mode == "busy" or mode == "over" or cur.is_empty() or cur.team != 0: return
	mode = "busy"
	_refresh_all()
	_next_turn.call_deferred()

func _on_defend() -> void:
	if mode not in ["idle", "aim"] or cur.acted: return
	mode = "busy"
	await _play(BattleRules.do_defend(st, cur))
	mode = "idle"
	_end_player_turn()

func _on_escape() -> void:
	if mode not in ["idle", "aim"] or not BattleRules.can_escape(cur): return
	mode = "busy"
	await _play(BattleRules.do_escape(st, cur))
	_after_player_step()

## หลังเดิน/ใช้ท่า: ครบทั้งสองอย่าง = จบเทิร์นอัตโนมัติ
func _after_player_step() -> void:
	if st.over:
		_finish()
		return
	if cur.down or cur.escaped or (cur.moved and cur.acted):
		mode = "idle"
		_end_player_turn()
		return
	_begin_player()

# ══════════════════════════════════════════
# อินพุต
# ══════════════════════════════════════════

## ตำแหน่งกล้อง: ซูมตามแนวสายตา (มุมเดิม) + เลื่อนแนวราบ
func _cam_pos() -> Vector3:
	return _cam_look + (_cam_base - _cam_look) * _view_zoom + _pan

func _pan_keys(delta: float) -> void:
	var d = Vector3.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): d.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): d.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): d.z -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): d.z += 1
	if d != Vector3.ZERO: _move_pan(d.normalized() * 9.0 * _view_zoom * delta)

func _move_pan(d: Vector3) -> void:
	_pan = (_pan + d).clamp(Vector3(-BattleState.W / 2.0, 0, -BattleState.H / 2.0 - 2), Vector3(BattleState.W / 2.0, 0, BattleState.H / 2.0 + 2))

func _unhandled_input(event: InputEvent) -> void:
	# กล้อง: ใช้ได้ตลอด (แม้ตาศัตรู)
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_view_zoom = clampf(_view_zoom * (0.9 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1), 0.55, 1.5)
		return
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
		_move_pan(Vector3(-event.relative.x, 0, -event.relative.y) * 0.02 * _view_zoom)
		return
	if mode not in ["idle", "aim"]: return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT: _cancel_aim()
		elif event.button_index == MOUSE_BUTTON_LEFT: _click(grid_of_mouse(event.position))
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE: _cancel_aim()
		elif event.keycode in [KEY_ENTER, KEY_KP_ENTER]: _end_player_turn()
		elif event.keycode >= KEY_1 and event.keycode <= KEY_9:
			var acts = BattleRules.actions(cur)
			var i = event.keycode - KEY_1
			if i < acts.size() and acts[i].ok: _choose_action(acts[i].name)

func _cancel_aim() -> void:
	if mode == "aim": _begin_player()

func _click(c: Vector2i) -> void:
	if mode == "idle":
		if reach.has(c) and c != cur.cell and not cur.moved:
			mode = "busy"
			await _play(BattleRules.do_move(st, cur, c))
			_after_player_step()
	elif mode == "aim":
		if aim_cells.has(c):
			mode = "busy"
			await _play(BattleRules.do_action(st, cur, sel_action, c))
			_after_player_step()

func _choose_action(name: String) -> void:
	if mode not in ["idle", "aim"] or cur.acted: return
	var sp = BattleRules.spec(cur, name)
	sel_action = name
	if sp.target == "self" or sp.shape == "self_ring":
		mode = "busy"
		await _play(BattleRules.do_action(st, cur, name, cur.cell))
		_after_player_step()
		return
	aim_cells = BattleRules.aim_options(st, cur, sp)
	mode = "aim"
	_refresh_all()

# ══════════════════════════════════════════
# เล่นเหตุการณ์ (แอนิเมชัน)
# ══════════════════════════════════════════

func _wait(sec: float) -> void:
	await get_tree().create_timer(sec / speed).timeout

func _play(events: Array) -> void:
	for e in events:
		var id: int = e.get("id", -1)
		var v: Node3D = views.get(id)
		var u = st.by_id(id)
		match e.t:
			"log": _log_msg(e.text)
			"move":
				for c in e.path:
					var tw = create_tween()
					tw.tween_property(v, "position", cell_pos(c), 0.16 / speed)
					_face(u)
					var sp: Sprite3D = v.get_node("Sprite")
					var hop = create_tween()
					hop.tween_property(sp, "position:y", 0.12, 0.08 / speed)
					hop.tween_property(sp, "position:y", 0.0, 0.08 / speed)
					await tw.finished
			"face": _face(u)
			"act": await _fx_action(u, e)
			"hit":
				_float(id, ("%d!" % e.dmg) if e.crit else str(e.dmg), Color(1, 0.6, 0.2) if e.crit else Color.WHITE, 30 if e.crit else 24)
				if e.get("note", "") != "": _float(id, e.note, Color(1, 0.85, 0.5), 13, -24)
				_flash(v)
				_update_bar(u)
				await _wait(0.12)
			"miss": _float(id, "หลบ!", Color(0.7, 0.85, 1), 18)
			"heal":
				_float(id, "+%d" % e.amt, Color(0.5, 1, 0.5), 22)
				_update_bar(u)
			"shield": _float(id, "โล่ +%d" % e.amt, Color(0.6, 0.85, 1), 18)
			"status": _float(id, e.st + "!", Color(0.85, 0.6, 1), 16, -26)
			"skip": _float(id, "สกัดจุด!", Color(0.85, 0.6, 1), 18)
			"knock":
				var tw = create_tween()
				tw.tween_property(v, "position", cell_pos(e.to), 0.12 / speed)
				if e.collide:
					VFX.burst(_fx, _unit_screen(id, 0.6), Color(0.8, 0.7, 0.5), 18)
					_shake = 0.15
				await tw.finished
			"down":
				var sp: Sprite3D = v.get_node("Sprite")
				var tw = create_tween()
				tw.tween_property(sp, "modulate", Color(0.35, 0.35, 0.4, 0.75), 0.4 / speed)
				tw.parallel().tween_property(sp, "scale:y", 0.5, 0.4 / speed)
			"escape":
				var tw = create_tween()
				tw.tween_property(v, "position", v.position + Vector3(-1.5, 0, 0), 0.4 / speed)
				tw.tween_callback(func(): v.visible = false)
		_update_status(u)
	_refresh_all()

## หันซ้าย/ขวา (สไปรต์มองด้านข้าง): ทิศขึ้น/ลงคงด้านเดิม
func _face(u: Dictionary) -> void:
	if u.is_empty() or not views.has(u.id): return
	if u.facing.x == 0: return
	(views[u.id].get_node("Sprite") as Sprite3D).flip_h = u.facing.x < 0

func _update_bar(u: Dictionary) -> void:
	if u.is_empty() or not _bars.has(u.id): return
	_bars[u.id].bar.value = u.hp

func _update_status(u: Dictionary) -> void:
	if u.is_empty() or not _bars.has(u.id): return
	var parts: Array[String] = []
	for s in u.status:
		parts.append(BattleRules.STATUS_NAMES.get(s, s) + (" %d" % u.status[s] if u.status[s] is int else ""))
	if u.defending: parts.append("ตั้งรับ")
	if u.shield_hp > 0: parts.append("โล่ %d" % u.shield_hp)
	_bars[u.id].status.text = " ".join(parts)

func _float(id: int, text: String, color: Color, size := 22, dy := 0.0) -> void:
	if not views.has(id): return
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02))
	l.add_theme_constant_override("outline_size", 5)
	l.size = Vector2(160, 30)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = _unit_screen(id, UNIT_H + 0.3) + Vector2(-80 + randf_range(-8, 8), -30 + dy)
	_fx.add_child(l)
	var tw = l.create_tween()
	tw.tween_property(l, "position:y", l.position.y - 36, 0.8 / speed)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.8 / speed).set_delay(0.3 / speed)
	tw.tween_callback(l.queue_free)

func _flash(v: Node3D) -> void:
	var sp: Sprite3D = v.get_node("Sprite")
	var tw = create_tween()
	tw.tween_property(sp, "modulate", Color(2.0, 0.6, 0.6), 0.05)
	tw.tween_property(sp, "modulate", Color.WHITE, 0.18)

## รอยฟันรูป X สีส้มสว่าง (วาดบนชั้น 2D ตรงตำแหน่งเป้าบนจอ)
func _slash_x(p: Vector2, color: Color, big := false) -> void:
	var r = 46.0 if big else 30.0
	for k in 2:
		var line = Line2D.new()
		line.width = 9.0 if big else 6.0
		var g = Gradient.new()
		g.set_color(0, Color(color.r, color.g, color.b, 0.0))
		g.add_point(0.5, Color(1, 0.95, 0.75))
		g.set_color(g.get_point_count() - 1, Color(color.r, color.g, color.b, 0.0))
		line.gradient = g
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		var d = Vector2(r, -r * 0.8) if k == 0 else Vector2(r, r * 0.8)
		line.points = PackedVector2Array([p - d, p + d])
		_fx.add_child(line)
		var tw = line.create_tween()
		tw.tween_property(line, "modulate:a", 0.0, 0.35 / speed).set_delay(0.08 / speed)
		tw.tween_callback(line.queue_free)

## เอฟเฟกต์ท่า: ประชิด = พุ่งเข้าแล้วฟัน X · ระยะไกล = กระสุนบิน · พื้นที่ = แผ่นแสงเรืองบนช่องที่โดน
func _fx_action(u: Dictionary, e: Dictionary) -> void:
	var v: Node3D = views[u.id]
	var color: Color = TYPE_COLORS.get(e.type, u.color).lerp(Color(1, 0.6, 0.2), 0.5)
	var cells: Array = e.cells
	var is_skill = e.name != BattleRules.ATTACK
	if is_skill: _float(u.id, e.name, Color(0.7, 0.92, 1), 15, -44)
	var aim3 = cell_pos(e.aim)
	match e.type:
		"hidden_weapon", "internal":
			if e.aim != u.cell:
				var from = _unit_screen(u.id, UNIT_H * 0.6)
				var to = screen_of(aim3 + Vector3(0, UNIT_H * 0.6, 0))
				for i in (3 if e.type == "hidden_weapon" else 1):
					var bolt = Polygon2D.new()
					bolt.polygon = PackedVector2Array([Vector2(-12, -3), Vector2(12, 0), Vector2(-12, 3)]) if e.type == "hidden_weapon" else PackedVector2Array([Vector2(-14, -10), Vector2(14, 0), Vector2(-14, 10)])
					bolt.color = color.lightened(0.4)
					bolt.position = from + Vector2(0, i * 6)
					bolt.rotation = (to - from).angle()
					_fx.add_child(bolt)
					var tw = create_tween()
					tw.tween_property(bolt, "position", to + Vector2(0, i * 6), (0.2 + i * 0.04) / speed)
					tw.tween_callback(bolt.queue_free)
				await _wait(0.28)
		"poison", "formation":
			for c in cells:
				var mi = MeshInstance3D.new()
				var pm = PlaneMesh.new()
				pm.size = Vector2(0.96, 0.96)
				mi.mesh = pm
				var m = _flat_mat(Color(0.5, 0.95, 0.3, 0.7) if e.type == "poison" else Color(1, 0.85, 0.35, 0.7), true, 3.0)
				mi.material_override = m
				mi.position = cell_pos(c) + Vector3(0, 0.03, 0)
				_world.add_child(mi)
				var tw = create_tween()
				tw.tween_property(m, "albedo_color:a", 0.0, 0.6 / speed)
				tw.tween_callback(mi.queue_free)
			await _wait(0.35)
		_:
			if e.aim != u.cell:
				var home = v.position
				var tw = create_tween()
				tw.tween_property(v, "position", home.lerp(aim3, 0.5), 0.1 / speed)
				tw.tween_property(v, "position", home, 0.16 / speed)
				for c in cells: _slash_x(screen_of(cell_pos(c) + Vector3(0, UNIT_H * 0.55, 0)), color, is_skill)
				await tw.finished
	if is_skill and not e.targets.is_empty(): _shake = 0.2
	for tid in e.targets:
		if views.has(tid): VFX.burst(_fx, _unit_screen(tid, UNIT_H * 0.55), color, 20)

# ══════════════════════════════════════════
# จบศึก
# ══════════════════════════════════════════

func _finish() -> void:
	if mode == "over": return
	mode = "over"
	cur = {}
	_refresh_all()
	var win = st.result == 0
	var allies = st.units.filter(func(u): return u.team == 0)
	var text = CombatResult.finish(win, allies)
	var head = "ได้รับชัยชนะ!" if win else ("ถอยทัพออกจากสนาม" if st.result == 2 else "พ่ายแพ้...")
	_result_label.add_theme_color_override("font_color", Color(0.6, 1, 0.6) if win else Color(1, 0.55, 0.5))
	_result_label.text = head + "\n" + text
	_log_msg(("[color=green]%s[/color]" if win else "[color=red]%s[/color]") % text)
	_result.show()
