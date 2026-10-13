extends Node3D
class_name SectWalk3D

## โหมดเดินในสำนักแบบ HD-2D (แนว Octopath Traveller / Wandering Sword)
## - อาณาเขต 96x96 เป็นฉาก 3D: พื้นยกระดับ (MultiMesh ตามชนิดภูมิประเทศ) น้ำ หิน ป่า (สไปรต์ต้นไม้ โหลดเฉพาะรอบตัว)
## - ตึกเป็นอาคารจีน 3D ตามชนิด/ระดับ (ไซต์ก่อสร้างมีนั่งร้าน) กองไฟ/โคมมีแสงจริงยามค่ำ
## - ศิษย์/สัตว์/เจ้าสำนักเป็นสไปรต์พิกเซล billboard ทอดเงา · แสงเปลี่ยนตามช่วงเวลา (เช้า/เย็น/ค่ำ)
## - เดิน WASD/ลูกศร หรือคลิกพื้น · Shift วิ่ง · ล้อเมาส์ซูม · ยืนหน้าประตูตึกแล้วกด [E]
## ข้อมูลทั้งหมดอ่านจาก SectData (มุมมองผู้บริหาร SectView ยังเป็นตัวหลักของการวางผัง/สั่งงาน)

signal building_entered(uid: String)

const UNIT_H = 1.45
const TREE_R = 20
const ROOF_COLORS = {
	"main_hall": Color(0.55, 0.12, 0.1), "dormitory": Color(0.3, 0.28, 0.26), "scripture_pavilion": Color(0.2, 0.3, 0.5),
	"alchemy_lab": Color(0.2, 0.42, 0.3), "forging_pavilion": Color(0.25, 0.22, 0.22), "infirmary": Color(0.25, 0.45, 0.4),
	"sect_formation": Color(0.45, 0.3, 0.6), "lumber_camp": Color(0.42, 0.3, 0.18), "quarry": Color(0.4, 0.4, 0.42),
	"kitchen": Color(0.5, 0.3, 0.15), "watchtower": Color(0.35, 0.2, 0.15), "builders_hut": Color(0.45, 0.35, 0.2),
}
const TERRAIN_COLORS = [Color(0.4, 0.54, 0.28), Color(0.28, 0.4, 0.22), Color(0.45, 0.45, 0.47), Color(0.2, 0.4, 0.6), Color(0.52, 0.43, 0.3), Color(0.42, 0.3, 0.19)]

var sect: SectData
var disciple: DiscipleData
## ปิดการเดินชั่วคราว (เช่น เปิดหน้าต่าง UI ทับ)
var blocked := false

var _cam: Camera3D
var _env: Environment
var _sun: DirectionalLight3D
var _player: Node3D
var _player_sprite: Sprite3D
var _click_target = null
var _zoom := 1.0
var _attrs: CameraAttributesPractical
var _backdrop: Node3D
var _foliage: MultiMeshInstance3D
var _foliage_sig := ""
var _ground_mm: MultiMeshInstance3D
var _rock_mm: MultiMeshInstance3D
var _water_mm: MultiMeshInstance3D
var _terrain_copy := PackedByteArray()
var _trees := {} # Vector2i -> Sprite3D
var _tree_center := Vector2i(-999, -999)
var _structs := {} # uid -> { node, sig }
var _lights: Array[OmniLight3D] = []
var _walkers := {} # DiscipleData -> Node3D
var _animals := {} # id -> Sprite3D
var _prompt: Label
var _near_uid := ""
var _tod := -1
var _stream_t := 0.0
var _tex_cache := {}

# ══════════════════════════════════════════
# ตั้งค่า
# ══════════════════════════════════════════

func setup(p_sect: SectData, d: DiscipleData) -> void:
	sect = p_sect
	disciple = d
	_build_env()
	_build_terrain()
	_spawn_player()
	_build_ui()
	refresh()
	_stream_trees(true)

## เรียกเมื่อข้อมูลเปลี่ยน (ช่วงเวลา/วัน/สร้างตึก/ถางป่า)
func refresh() -> void:
	if sect == null: return
	if sect.terrain != _terrain_copy: _build_terrain()
	_sync_structures()
	_sync_walkers()
	if sect.time_phase != _tod: _apply_time()

static func wpos(cell: Vector2) -> Vector3:
	return Vector3(cell.x, 0.0, cell.y)

func _pixel_tex(base: Color, seed_v: int, size := 32, speck := 0.06) -> ImageTexture:
	var key = "%s|%d|%d|%f" % [base.to_html(), seed_v, size, speck]
	if _tex_cache.has(key): return _tex_cache[key]
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_v
	for y in size:
		for x in size:
			var n = rng.randf_range(-speck, speck)
			img.set_pixel(x, y, Color(base.r + n, base.g + n * 1.2, base.b + n * 0.6))
	for i in size:
		var p = Vector2i(rng.randi_range(0, size - 1), rng.randi_range(1, size - 1))
		img.set_pixel(p.x, p.y, base.lightened(0.15))
	var t = ImageTexture.create_from_image(img)
	_tex_cache[key] = t
	return t

func _mat(tex: Texture2D, tint := Color.WHITE) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_texture = tex
	m.albedo_color = tint
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.roughness = 1.0
	return m

func _flat(col: Color, emission := 0.0) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = col
	if col.a < 1.0: m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emission > 0.0:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.emission_enabled = true
		m.emission = Color(col.r, col.g, col.b)
		m.emission_energy_multiplier = emission
	return m

func _sprite(tex: Texture2D, height: float, pos: Vector3) -> Sprite3D:
	var s = Sprite3D.new()
	s.texture = tex
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.shaded = true
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.pixel_size = height / maxf(1.0, tex.get_height())
	s.offset = Vector2(0, tex.get_height() / 2.0)
	s.position = pos
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return s

# ══════════════════════════════════════════
# แสง / สภาพแวดล้อม
# ══════════════════════════════════════════

func _build_env() -> void:
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.glow_enabled = true
	_env.glow_intensity = 0.7
	_env.glow_bloom = 0.05
	_env.glow_hdr_threshold = 0.9
	_env.fog_enabled = true
	_env.ssao_enabled = true
	_env.adjustment_enabled = true
	_env.adjustment_saturation = 1.12
	var we = WorldEnvironment.new()
	we.environment = _env
	HD2D.post(_env)
	_attrs = CameraAttributesPractical.new()
	we.camera_attributes = _attrs
	add_child(we)
	_backdrop = HD2D.backdrop(self, Color(0.4, 0.52, 0.5))
	HD2D.vignette(self, 0, 0.5)
	_sun = DirectionalLight3D.new()
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 40.0
	add_child(_sun)
	_cam = Camera3D.new()
	_cam.fov = 36.0
	add_child(_cam)
	_cam.make_current()

## แสงตามช่วงเวลา: เช้าแดดใส · เย็นแสงส้มต่ำ · ค่ำจันทร์ฟ้าคราม + เปิดไฟกองไฟ/โคม
## ค่าแสงปัจจุบัน (ใช้ไล่แสงค่อยๆ เปลี่ยนระหว่างช่วงเวลา ไม่ให้ภาพกระตุก/ลายตา)
const LIGHT_PROPS = [["env", "background_color"], ["env", "ambient_light_color"], ["env", "ambient_light_energy"], ["env", "fog_light_color"], ["env", "fog_density"], ["sun", "light_color"], ["sun", "light_energy"], ["sun", "rotation_degrees"]]
var _light_tween: Tween

func _light_obj(k: String) -> Object:
	return _env if k == "env" else _sun

func _light_snapshot() -> Array:
	return LIGHT_PROPS.map(func(p): return _light_obj(p[0]).get(p[1]))

## ไล่จากค่า before ไปยังค่าปัจจุบัน (ที่เพิ่งตั้ง) ภายใน sec วินาที
func _fade_light_from(before: Array, sec := 4.0) -> void:
	var after = _light_snapshot()
	if _light_tween and _light_tween.is_valid(): _light_tween.kill()
	_light_tween = create_tween().set_parallel(true)
	for i in LIGHT_PROPS.size():
		var o = _light_obj(LIGHT_PROPS[i][0])
		o.set(LIGHT_PROPS[i][1], before[i])
		_light_tween.tween_property(o, LIGHT_PROPS[i][1], after[i], sec)

func _apply_time() -> void:
	var animate = _tod >= 0
	var before = _light_snapshot()
	_tod = sect.time_phase
	match _tod:
		0:
			_env.background_color = Color(0.62, 0.74, 0.86)
			_env.ambient_light_color = Color(0.75, 0.8, 0.88)
			_env.ambient_light_energy = 0.5
			_env.fog_light_color = Color(0.72, 0.8, 0.86)
			_env.fog_density = 0.006
			_sun.light_color = Color(1.0, 0.96, 0.88)
			_sun.light_energy = 1.2
			_sun.rotation_degrees = Vector3(-55, -35, 0)
		1:
			_env.background_color = Color(0.85, 0.55, 0.38)
			_env.ambient_light_color = Color(0.7, 0.55, 0.5)
			_env.ambient_light_energy = 0.55
			_env.fog_light_color = Color(0.8, 0.55, 0.4)
			_env.fog_density = 0.009
			_sun.light_color = Color(1.0, 0.7, 0.45)
			_sun.light_energy = 1.1
			_sun.rotation_degrees = Vector3(-22, -60, 0)
		_:
			_env.background_color = Color(0.03, 0.05, 0.08)
			_env.ambient_light_color = Color(0.32, 0.38, 0.52)
			_env.ambient_light_energy = 0.9
			_env.fog_light_color = Color(0.1, 0.13, 0.18)
			_env.fog_density = 0.02
			_sun.light_color = Color(0.62, 0.72, 1.0)
			_sun.light_energy = 0.65
			_sun.rotation_degrees = Vector3(-52, -28, 0)
	for l in _lights:
		if is_instance_valid(l): l.visible = _tod >= 1 or l.has_meta("fire")
	HD2D.apply_sky(_env, _tod)
	if animate: _fade_light_from(before)

# ══════════════════════════════════════════
# ภูมิประเทศ (MultiMesh ทั้งแผนที่)
# ══════════════════════════════════════════

func _build_terrain() -> void:
	_terrain_copy = sect.terrain.duplicate()
	var n = Territory.SIZE
	var ground_cells: Array = []
	var rock_cells: Array = []
	var water_cells: Array = []
	for y in n:
		for x in n:
			var t = sect.terrain[y * n + x]
			if t == Territory.T.WATER: water_cells.append(Vector2i(x, y))
			elif t == Territory.T.ROCK: rock_cells.append(Vector2i(x, y))
			else: ground_cells.append(Vector2i(x, y))
	if _ground_mm == null:
		_ground_mm = _make_mm(Vector3(1, 0.24, 1), _mat(_pixel_tex(Color(0.85, 0.85, 0.85), 1, 16, 0.08)), true)
		_rock_mm = _make_mm(Vector3(1, 0.9, 1), _mat(_pixel_tex(Color(0.52, 0.52, 0.55), 2, 16, 0.1)), false)
		var wm = StandardMaterial3D.new()
		wm.albedo_color = Color(0.22, 0.45, 0.68, 0.88)
		wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		wm.roughness = 0.08
		wm.metallic = 0.3
		wm.emission_enabled = true
		wm.emission = Color(0.05, 0.12, 0.2)
		_water_mm = _make_mm(Vector3(1, 0.06, 1), wm, false)
	_fill_mm(_ground_mm, ground_cells, -0.12, true)
	_fill_mm(_rock_mm, rock_cells, 0.2, false)
	_fill_mm(_water_mm, water_cells, -0.2, false)
	_tree_center = Vector2i(-999, -999)
	_foliage_sig = ""

func _make_mm(size: Vector3, mat: Material, colors: bool) -> MultiMeshInstance3D:
	var box = BoxMesh.new()
	box.size = size
	if colors and mat is StandardMaterial3D: mat.vertex_color_use_as_albedo = true
	box.material = mat
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colors
	mm.mesh = box
	var mi = MultiMeshInstance3D.new()
	mi.multimesh = mm
	add_child(mi)
	return mi

func _fill_mm(mi: MultiMeshInstance3D, cells: Array, y: float, colors: bool) -> void:
	var mm = mi.multimesh
	mm.instance_count = cells.size()
	for i in cells.size():
		var c: Vector2i = cells[i]
		var jitter = (hash(c) % 7) * 0.01 if colors else 0.0
		mm.set_instance_transform(i, Transform3D(Basis(), Vector3(c.x + 0.5, y + jitter, c.y + 0.5)))
		if colors:
			var t = sect.terrain[c.y * Territory.SIZE + c.x]
			var col: Color = TERRAIN_COLORS[t]
			mm.set_instance_color(i, col.darkened(float(hash(c) % 5) * 0.025))

## สไปรต์ต้นไม้เฉพาะช่องป่ารอบตัวผู้เล่น (โหลด/ลบตามระยะ กันฉากหนัก)
func _stream_trees(force := false) -> void:
	var pc = Vector2i(floori(_player.position.x), floori(_player.position.z))
	if not force and (pc - _tree_center).length() < 3: return
	_tree_center = pc
	var atlas = ArtGen.make_tree_atlas()
	for c in _trees.keys():
		if (c - pc).length() > TREE_R + 3 or Territory.at(sect, c) != Territory.T.FOREST:
			_trees[c].queue_free()
			_trees.erase(c)
	for y in range(pc.y - TREE_R, pc.y + TREE_R + 1):
		for x in range(pc.x - TREE_R, pc.x + TREE_R + 1):
			var c = Vector2i(x, y)
			if _trees.has(c) or (c - pc).length() > TREE_R or Territory.at(sect, c) != Territory.T.FOREST: continue
			var tex = AtlasTexture.new()
			tex.atlas = atlas
			tex.region = Rect2(64 * posmod(hash(c), 3), 0, 64, 64)
			var s = _sprite(tex, 2.6 + float(posmod(hash(c * 3), 5)) * 0.15, Vector3(c.x + 0.5, 0.0, c.y + 0.5))
			add_child(s)
			_trees[c] = s

# ══════════════════════════════════════════
# ตึก
# ══════════════════════════════════════════

func _sync_structures() -> void:
	var alive := {}
	for inst in sect.structures:
		var uid: String = inst.uid
		alive[uid] = true
		var sig = "%s|%d|%s|%s|%d" % [inst.type, int(inst.level), str(inst.cell), str(inst.site.is_empty()), int(float(inst.site.get("work", 0)) / maxf(1.0, float(inst.site.get("required", 1))) * 4)]
		if _structs.has(uid) and _structs[uid].sig == sig: continue
		if _structs.has(uid): _structs[uid].node.queue_free()
		var node = _make_structure(inst)
		add_child(node)
		_structs[uid] = { "node": node, "sig": sig }
	for uid in _structs.keys():
		if not alive.has(uid):
			_structs[uid].node.queue_free()
			_structs.erase(uid)
	_lights = _lights.filter(func(l): return is_instance_valid(l) and not l.is_queued_for_deletion())

func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var b = BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi

func _light(parent: Node3D, pos: Vector3, col: Color, energy: float, rng: float, fire := false) -> void:
	var l = OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.position = pos
	l.shadow_enabled = fire
	if fire: l.set_meta("fire", true)
	l.visible = sect.time_phase >= 1 or fire
	parent.add_child(l)
	_lights.append(l)

func _make_structure(inst: Dictionary) -> Node3D:
	var r: Rect2i = BuildingDB.rect_of(inst)
	var node = Node3D.new()
	var size = Vector2(r.size)
	node.position = Vector3(r.position.x + size.x / 2.0, 0, r.position.y + size.y / 2.0)
	var lv = int(inst.level)
	var wood = _mat(_pixel_tex(Color(0.45, 0.32, 0.2), 31, 16, 0.06))
	if lv <= 0:
		# ไซต์ก่อสร้าง: ฐานหิน + ผนังสูงตามความคืบหน้า + นั่งร้าน
		var prog = clampf(float(inst.site.get("work", 0)) / maxf(1.0, float(inst.site.get("required", 1))), 0.0, 1.0)
		_box(node, Vector3(size.x - 0.2, 0.1, size.y - 0.2), Vector3(0, 0.05, 0), _mat(_pixel_tex(Color(0.55, 0.52, 0.48), 32, 16, 0.05)))
		if prog > 0.05:
			_box(node, Vector3(size.x - 0.5, 1.5 * prog, size.y - 0.5), Vector3(0, 0.75 * prog, 0), _mat(_pixel_tex(Color(0.8, 0.74, 0.62), 33, 32, 0.04)))
		for sx in [-1, 1]:
			for sz in [-1, 1]:
				_box(node, Vector3(0.08, 2.0, 0.08), Vector3(sx * (size.x / 2.0 - 0.15), 1.0, sz * (size.y / 2.0 - 0.15)), wood)
		_box(node, Vector3(size.x - 0.2, 0.06, 0.08), Vector3(0, 1.3, size.y / 2.0 - 0.15), wood)
		return node
	match inst.type:
		"campfire":
			for k in 3:
				var lg = _box(node, Vector3(0.7, 0.12, 0.12), Vector3(0, 0.08, 0), wood)
				lg.rotation_degrees.y = k * 60
			var flame = MeshInstance3D.new()
			var sm = SphereMesh.new()
			sm.radius = 0.18 + lv * 0.03
			sm.height = 0.5 + lv * 0.06
			flame.mesh = sm
			flame.position = Vector3(0, 0.35, 0)
			flame.material_override = _flat(Color(1.0, 0.55, 0.18), 6.0)
			node.add_child(flame)
			_light(node, Vector3(0, 0.9, 0), Color(1.0, 0.6, 0.3), 2.2 + lv * 0.3, 6.0 + lv, true)
		"farm":
			# แปลงปลูก: แถวพืชสีเขียว
			for row in int(size.y * 2):
				_box(node, Vector3(size.x - 0.4, 0.18, 0.18), Vector3(0, 0.09, -size.y / 2.0 + 0.3 + row * 0.5), _mat(_pixel_tex(Color(0.35, 0.6, 0.25), 34, 16, 0.08)))
		"training_ground":
			_box(node, Vector3(size.x - 0.2, 0.08, size.y - 0.2), Vector3(0, 0.04, 0), _mat(_pixel_tex(Color(0.62, 0.58, 0.5), 35, 32, 0.05)))
			for k in 2:
				var dummy = Node3D.new()
				dummy.position = Vector3(-size.x / 4.0 + k * size.x / 2.0, 0, -size.y / 4.0)
				node.add_child(dummy)
				_box(dummy, Vector3(0.12, 1.1, 0.12), Vector3(0, 0.55, 0), wood)
				_box(dummy, Vector3(0.6, 0.1, 0.1), Vector3(0, 0.85, 0), wood)
		"watchtower":
			for sx in [-1, 1]:
				for sz in [-1, 1]:
					_box(node, Vector3(0.12, 3.2, 0.12), Vector3(sx * 0.4, 1.6, sz * 0.4), wood)
			_box(node, Vector3(1.2, 0.12, 1.2), Vector3(0, 2.6, 0), wood)
			_roof(node, Vector3(1.6, 0.7, 1.6), Vector3(0, 3.55, 0), ROOF_COLORS.watchtower)
			_light(node, Vector3(0, 2.9, 0.6), Color(1.0, 0.65, 0.35), 1.5, 6.0)
		_:
			var h = clampf(1.3 + lv * 0.15, 1.3, 2.6)
			var footprint = Vector3(size.x - 0.5, h, size.y - 0.5)
			_box(node, Vector3(size.x - 0.2, 0.15, size.y - 0.2), Vector3(0, 0.075, 0), _mat(_pixel_tex(Color(0.55, 0.52, 0.48), 36, 16, 0.05)))
			_box(node, footprint, Vector3(0, h / 2.0 + 0.15, 0), _mat(_pixel_tex(Color(0.84, 0.78, 0.66), 37 + hash(inst.type) % 5, 32, 0.04)))
			var red = _flat(Color(0.6, 0.12, 0.1))
			for sx in [-1, 1]:
				_box(node, Vector3(0.14, h, 0.14), Vector3(sx * (footprint.x / 2.0 - 0.05), h / 2.0 + 0.15, footprint.z / 2.0 + 0.04), red)
			_box(node, Vector3(0.6, 0.9, 0.04), Vector3(0, 0.6, footprint.z / 2.0 + 0.02), _flat(Color(0.22, 0.14, 0.1)))
			_roof(node, Vector3(size.x + 0.2, 0.9 + size.x * 0.08, size.y + 0.2), Vector3(0, h + 0.15 + (0.9 + size.x * 0.08) / 2.0, 0), ROOF_COLORS.get(inst.type, Color(0.3, 0.3, 0.32)))
			if inst.type == "main_hall" and lv >= 3:
				# ชั้นสอง
				_box(node, Vector3(footprint.x * 0.6, 0.9, footprint.z * 0.6), Vector3(0, h + 1.2, 0), _mat(_pixel_tex(Color(0.84, 0.78, 0.66), 38, 32, 0.04)))
				_roof(node, Vector3(size.x * 0.75, 0.8, size.y * 0.75), Vector3(0, h + 2.05, 0), ROOF_COLORS.main_hall)
			# โคมแดงหน้าตึก (สว่างยามเย็น/ค่ำ)
			var lan = MeshInstance3D.new()
			var sm = SphereMesh.new()
			sm.radius = 0.13
			sm.height = 0.28
			lan.mesh = sm
			lan.position = Vector3(footprint.x / 2.0 - 0.3, h - 0.1, footprint.z / 2.0 + 0.25)
			lan.material_override = _flat(Color(1.0, 0.3, 0.18), 3.0)
			node.add_child(lan)
			if inst.type in ["main_hall", "dormitory", "kitchen", "scripture_pavilion", "alchemy_lab", "infirmary"]:
				_light(node, lan.position + Vector3(0, 0, 0.3), Color(1.0, 0.55, 0.35), 1.4, 5.0)
	return node

func _roof(parent: Node3D, size: Vector3, pos: Vector3, col: Color) -> void:
	# หลังคาจั่ว: สันหลังคาวิ่งซ้าย-ขวา (หมุน PrismMesh 90°)
	var mi = MeshInstance3D.new()
	var pm = PrismMesh.new()
	pm.size = Vector3(size.z, size.y, size.x)
	mi.mesh = pm
	mi.rotation_degrees.y = 90
	mi.position = pos
	mi.material_override = _mat(_pixel_tex(col, int(col.r * 100), 16, 0.06))
	parent.add_child(mi)

# ══════════════════════════════════════════
# ศิษย์ / สัตว์ / ผู้เล่น
# ══════════════════════════════════════════

func _sync_walkers() -> void:
	var present := {}
	for d in sect.get_in_sect_disciples():
		if d == disciple: continue
		present[d] = true
		if not _walkers.has(d):
			var n = Node3D.new()
			n.position = wpos(d.pos)
			n.add_child(_sprite(HD2D.outlined(ArtGen.get_figure(d)), UNIT_H, Vector3.ZERO))
			var lbl = Label3D.new()
			lbl.name = "Label"
			lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			lbl.pixel_size = 0.0045
			lbl.font_size = 28
			lbl.outline_size = 8
			lbl.position = Vector3(0, UNIT_H + 0.25, 0)
			lbl.no_depth_test = false
			n.add_child(lbl)
			add_child(n)
			_walkers[d] = n
	for d in _walkers.keys():
		if not present.has(d):
			_walkers[d].queue_free()
			_walkers.erase(d)

func _spawn_player() -> void:
	_player = Node3D.new()
	_player_sprite = _sprite(HD2D.outlined(ArtGen.get_figure(disciple)), UNIT_H, Vector3.ZERO)
	_player.add_child(_player_sprite)
	var ring = MeshInstance3D.new()
	var tm = TorusMesh.new()
	tm.inner_radius = 0.32
	tm.outer_radius = 0.4
	tm.rings = 16
	ring.mesh = tm
	ring.scale = Vector3(1, 0.1, 1)
	ring.position = Vector3(0, 0.03, 0)
	ring.material_override = _flat(Color(1.0, 0.85, 0.3), 1.5)
	_player.add_child(ring)
	add_child(_player)
	# เริ่มที่ลานหน้าโถงหลัก
	var start = Vector2(Territory.HOME) + Vector2(0.5, 3.0)
	for inst in sect.instances("main_hall"):
		var r = BuildingDB.rect_of(inst)
		start = Vector2(r.position.x + r.size.x / 2.0, r.end.y + 1.0)
	if not _walkable(wpos(start)): start = Territory.gate_pos()
	_player.position = wpos(start)
	_update_camera(1.0)

func _build_ui() -> void:
	var layer = CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	_prompt = Label.new()
	_prompt.add_theme_font_size_override("font_size", 18)
	_prompt.add_theme_color_override("font_color", Color(1, 0.92, 0.6))
	_prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_prompt.add_theme_constant_override("outline_size", 6)
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt.position.y = -150
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(_prompt)

## เดินผ่านได้ไหม: ในอาณาเขต ไม่ใช่น้ำ/หิน/ป่า และไม่อยู่ในฐานตึกที่ตั้งอยู่ (ยกเว้นลาน/แปลง/กองไฟ)
func _walkable(p: Vector3) -> bool:
	var c = Vector2i(floori(p.x), floori(p.z))
	if not Territory.in_bounds(c): return false
	var t = Territory.at(sect, c)
	if t == Territory.T.WATER or t == Territory.T.ROCK or t == Territory.T.FOREST: return false
	for inst in sect.structures:
		if inst.type in ["farm", "training_ground", "campfire"]: continue
		var r = BuildingDB.rect_of(inst)
		var inner = Rect2(Vector2(r.position) + Vector2(0.15, 0.15), Vector2(r.size) - Vector2(0.3, 0.3))
		if inner.has_point(Vector2(p.x, p.z)): return false
	return true

func _process(delta: float) -> void:
	if sect == null: return
	_move_player(delta)
	_update_camera(delta)
	_stream_t -= delta
	if _stream_t <= 0.0:
		_stream_t = 0.4
		_stream_trees()
		_update_animals_list()
		_sync_foliage()
		refresh()
	_update_walkers(delta)
	_update_animals(delta)
	_update_prompt()
	_fade_occluders()
	var t = Time.get_ticks_msec() / 1000.0
	for i in _lights.size():
		var l = _lights[i]
		if is_instance_valid(l) and l.has_meta("fire"): l.light_energy = 2.4 + sin(t * 9.0 + i) * 0.25

func _move_player(delta: float) -> void:
	if blocked: return
	var dir = Vector3.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): dir.z -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): dir.z += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): dir.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): dir.x += 1
	if dir != Vector3.ZERO: _click_target = null
	elif _click_target != null:
		var to: Vector3 = _click_target - _player.position
		to.y = 0
		if to.length() < 0.15: _click_target = null
		else: dir = to.normalized()
	if dir == Vector3.ZERO:
		_player_sprite.position.y = 0.0
		return
	dir = dir.normalized()
	var spd = 3.2 * StatSys.walk_speed_mult(disciple) * (1.7 if Input.is_key_pressed(KEY_SHIFT) else 1.0)
	var step = dir * spd * delta
	var moved = false
	# เดินแยกแกน = ไถลตามกำแพงได้
	for axis in [Vector3(step.x, 0, 0), Vector3(0, 0, step.z)]:
		if axis == Vector3.ZERO: continue
		var np = _player.position + axis
		if _walkable(np + axis.normalized() * 0.25):
			_player.position = np
			moved = true
	if not moved: _click_target = null
	if absf(dir.x) > 0.1: _player_sprite.flip_h = dir.x < 0
	_player_sprite.position.y = absf(sin(Time.get_ticks_msec() / 1000.0 * 14.0)) * 0.06 if moved else 0.0

func _update_camera(delta: float) -> void:
	# มุมกล้องต่ำ (~28°) ใกล้ตัวละคร เห็นหน้าอาคาร แบบ HD-2D
	var target = _player.position + Vector3(0, 4.6, 8.6) * _zoom
	_cam.position = _cam.position.lerp(target, clampf(delta * 6.0, 0.0, 1.0)) if delta < 1.0 else target
	_cam.look_at(_player.position + Vector3(0, 1.0, 0))
	HD2D.tilt_shift(_attrs, _cam.position.distance_to(_player.position), 3.0 * _zoom, 5.0 * _zoom, 0.11)
	HD2D.update_backdrop(_backdrop, _player.position)

func _update_walkers(delta: float) -> void:
	var t = Time.get_ticks_msec() / 1000.0
	for d in _walkers:
		var n: Node3D = _walkers[d]
		var home = wpos(d.pos)
		var spr: Sprite3D = n.get_child(0)
		var target: Vector3
		if d.needs.get("travel", false):
			target = home
		else:
			target = n.get_meta("wt", home)
			var wait: float = n.get_meta("wait", 0.0)
			if target.distance_to(home) > 3.0: target = home
			if n.position.distance_to(target) < 0.08:
				wait -= delta
				if wait <= 0.0:
					target = home + Vector3(randf_range(-1.2, 1.2), 0, randf_range(-0.6, 0.6))
					wait = randf_range(0.8, 3.0)
			n.set_meta("wait", wait)
		n.set_meta("wt", target)
		var to = target - n.position
		var moving = to.length() > 0.08
		var spd = 2.4 if (to.length() > 4.0 or d.needs.get("travel", false)) else 0.9
		n.position = n.position.move_toward(target, spd * delta)
		if moving and absf(to.x) > 0.02: spr.flip_h = to.x < 0
		spr.position.y = absf(sin(t * 10.0)) * 0.05 if moving else 0.0
		var lbl: Label3D = n.get_node("Label")
		lbl.text = "%s\n%s" % [d.disciple_name, SectView.activity_text(d)]
		lbl.modulate = Color(1, 0.4, 0.35) if d.stress >= StressSystem.WARN_AT else Color(0.85, 0.95, 1)
		lbl.visible = n.position.distance_to(_player.position) < 5.0

func _update_animals_list() -> void:
	var alive := {}
	for a in sect.animals:
		alive[a.id] = true
		if not _animals.has(a.id):
			var h = { "cow": 1.0, "pig": 0.8, "chicken": 0.45, "wolf": 0.9 }.get(a.species, 0.8)
			var s = _sprite(HD2D.outlined(ArtGen.get_animal(a.species)), h, wpos(a.pos))
			add_child(s)
			_animals[a.id] = s
	for id in _animals.keys():
		if not alive.has(id):
			_animals[id].queue_free()
			_animals.erase(id)

func _update_animals(delta: float) -> void:
	var interval = maxf(0.25, AnimalSys.UPDATE_TICKS * GlobalGame.SECONDS_PER_PHASE / GlobalGame.TICKS_PER_PHASE / maxf(0.1, GlobalGame.get_speed()))
	for a in sect.animals:
		var s: Sprite3D = _animals.get(a.id)
		if s == null: continue
		var target = wpos(a.pos)
		if not s.has_meta("to") or s.get_meta("to") != target:
			s.set_meta("to", target)
			s.set_meta("vel", maxf(0.3, s.position.distance_to(target) / interval))
		var to = target - s.position
		if absf(to.x) > 0.02: s.flip_h = to.x > 0
		s.position = s.position.move_toward(target, float(s.get_meta("vel")) * delta)

## กอหญ้า/ดอกไม้ไหวตามลมบนช่องหญ้าที่ไม่มีตึก (สร้างใหม่เมื่อภูมิประเทศ/ตึกเปลี่ยน)
func _sync_foliage() -> void:
	var sig = "%d|%d" % [hash(_terrain_copy), sect.structures.size()]
	if sig == _foliage_sig: return
	_foliage_sig = sig
	if _foliage: _foliage.queue_free()
	var taken := {}
	for inst in sect.structures:
		var r = BuildingDB.rect_of(inst)
		for y in range(r.position.y - 1, r.end.y + 1):
			for x in range(r.position.x - 1, r.end.x + 1): taken[Vector2i(x, y)] = true
	var pts: Array = []
	var rng = RandomNumberGenerator.new()
	rng.seed = 4242
	for y in Territory.SIZE:
		for x in Territory.SIZE:
			var c = Vector2i(x, y)
			var t = Territory.at(sect, c)
			if taken.has(c) or not (t == Territory.T.GRASS or t == Territory.T.FOREST): continue
			for k in (2 if t == Territory.T.GRASS else 1):
				if rng.randf() < 0.75:
					pts.append(Vector3(x + rng.randf(), 0.0, y + rng.randf()))
	_foliage = HD2D.scatter_foliage(self, pts, Color(0.38, 0.58, 0.26), 0.22, 0.75)

## ต้นไม้ที่บังระหว่างกล้องกับผู้เล่นจะจางลง (แบบ HD-2D)
func _fade_occluders() -> void:
	var pp = _player.position
	for c in _trees:
		var s: Sprite3D = _trees[c]
		var dz = s.position.z - pp.z
		var fade = dz > 0.3 and dz < 9.0 * _zoom and absf(s.position.x - pp.x) < 2.6
		if fade != s.has_meta("faded"):
			if fade:
				s.set_meta("faded", true)
				s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
				s.transparent = true
				s.modulate.a = 0.3
			else:
				s.remove_meta("faded")
				s.modulate.a = 1.0
				s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD

## ประตูตึกที่ใกล้สุด (หน้าตึกฝั่งกล้อง) ในระยะ 1.6 ช่อง
func _update_prompt() -> void:
	_near_uid = ""
	var best = 1.6
	for inst in sect.structures:
		var r = BuildingDB.rect_of(inst)
		var door = Vector3(r.position.x + r.size.x / 2.0, 0, r.end.y + 0.3)
		if inst.type in ["farm", "training_ground", "campfire"]: door = Vector3(r.position.x + r.size.x / 2.0, 0, r.position.y + r.size.y / 2.0)
		var d = door.distance_to(_player.position)
		if d < best:
			best = d
			_near_uid = inst.uid
	if _near_uid == "" or blocked:
		_prompt.text = ""
	else:
		var inst = sect.instance(_near_uid)
		_prompt.text = "[E] " + (("เข้า " + BuildingDB.inst_name(inst)) if int(inst.level) > 0 else "%s (กำลังก่อสร้าง)" % BuildingDB.inst_name(inst))

func _unhandled_input(event: InputEvent) -> void:
	if blocked: return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_E, KEY_F]:
		if _near_uid != "":
			building_entered.emit(_near_uid)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				var o = _cam.project_ray_origin(event.position)
				var dvec = _cam.project_ray_normal(event.position)
				if absf(dvec.y) > 0.001:
					var p = o + dvec * (-o.y / dvec.y)
					_click_target = Vector3(p.x, 0, p.z)
				get_viewport().set_input_as_handled()
			MOUSE_BUTTON_WHEEL_UP: _zoom = clampf(_zoom / 1.1, 0.6, 2.2)
			MOUSE_BUTTON_WHEEL_DOWN: _zoom = clampf(_zoom * 1.1, 0.6, 2.2)
