extends Node3D
class_name CityView3D

## ภาพ HD-2D ของฉากเดินในเมือง/สำนักอื่น (ตอนนี้ใช้กับสำนักอื่นที่เดินเข้าได้)
## ตรรกะเดิมของ CityScene (ชนกำแพง, NPC, ยามลาดตระเวน, จุดปฏิสัมพันธ์) ยังทำงานในโลก 2D ที่ซ่อนอยู่
## ฉากนี้สร้างภาพ 3D จาก CityLayout และ "สะท้อน" ตัวละคร 2D เป็นสไปรต์ billboard ตามตำแหน่งทุกเฟรม
## พิกัด: 1 ช่อง (CityLayout.TILE px) = 1 หน่วยโลก 3D · แกน y ของ 2D = แกน z ของ 3D (หน้าอาคารหันเข้าหากล้อง)

const UNIT_H = 1.45
const TILE_COLORS = [Color.WHITE, Color(0.6, 0.58, 0.54), Color(0.74, 0.7, 0.62), Color(0.2, 0.42, 0.62), Color(0.45, 0.42, 0.4), Color(0.4, 0.36, 0.3), Color(0.55, 0.4, 0.25)]

var scene: Node # CityScene
var layout: CityLayout
var zoom := 1.0
var _attrs: CameraAttributesPractical
var _backdrop: Node3D

var _cam: Camera3D
var _env: Environment
var _sun: DirectionalLight3D
var _lights: Array[OmniLight3D] = []
var _mirrors := {} # Node2D -> Node3D
var _tex_cache := {}
var _tod := -1

func setup(p_scene: Node, p_layout: CityLayout) -> void:
	scene = p_scene
	layout = p_layout
	_build_env()
	_build_ground()
	_build_buildings()
	_build_decor()
	_apply_time()
	GlobalGame.phase_changed.connect(func(_p): _apply_time())

static func to3(p: Vector2) -> Vector3:
	return Vector3(p.x / CityLayout.TILE, 0.0, p.y / CityLayout.TILE)

## จุดบนจอ (หน่วย UI) -> ตำแหน่งในโลก 2D ของ CityScene (ใช้คลิกเดิน)
func screen_to_world2d(sp: Vector2) -> Vector2:
	var o = _cam.project_ray_origin(sp)
	var d = _cam.project_ray_normal(sp)
	if absf(d.y) < 0.0001: return Vector2.ZERO
	var p = o + d * (-o.y / d.y)
	return Vector2(p.x, p.z) * CityLayout.TILE

func _pixel_tex(base: Color, seed_v: int, size := 32, speck := 0.06) -> ImageTexture:
	var key = "%s|%d|%d" % [base.to_html(), seed_v, size]
	if _tex_cache.has(key): return _tex_cache[key]
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_v
	for y in size:
		for x in size:
			var n = rng.randf_range(-speck, speck)
			img.set_pixel(x, y, Color(base.r + n, base.g + n * 1.2, base.b + n * 0.6))
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
	if emission > 0.0:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.emission_enabled = true
		m.emission = col
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

func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var b = BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi

# ══════════════════════════════════════════
# แสง
# ══════════════════════════════════════════

func _build_env() -> void:
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.glow_enabled = true
	_env.glow_intensity = 0.7
	_env.glow_hdr_threshold = 0.9
	_env.fog_enabled = true
	_env.ssao_enabled = true
	_env.adjustment_enabled = true
	_env.adjustment_saturation = 1.1
	var we = WorldEnvironment.new()
	we.environment = _env
	HD2D.post(_env)
	_attrs = CameraAttributesPractical.new()
	we.camera_attributes = _attrs
	add_child(we)
	_backdrop = HD2D.backdrop(self, layout.theme.tree.lerp(Color(0.45, 0.55, 0.6), 0.5))
	HD2D.vignette(self, 0, 0.5)
	_sun = DirectionalLight3D.new()
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 40.0
	add_child(_sun)
	_cam = Camera3D.new()
	_cam.fov = 36.0
	add_child(_cam)
	_cam.make_current()

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
	var sect = GlobalGame.current_sect
	_tod = sect.time_phase if sect != null else 0
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
			_env.ambient_light_energy = 0.85
			_env.fog_light_color = Color(0.1, 0.13, 0.18)
			_env.fog_density = 0.02
			_sun.light_color = Color(0.62, 0.72, 1.0)
			_sun.light_energy = 0.6
			_sun.rotation_degrees = Vector3(-52, -28, 0)
	if layout.theme.ground == "snowgrass":
		_env.fog_light_color = _env.fog_light_color.lerp(Color(0.85, 0.9, 1.0), 0.4)
	for l in _lights: l.visible = _tod >= 1
	HD2D.apply_sky(_env, _tod)
	if animate: _fade_light_from(before)

# ══════════════════════════════════════════
# พื้น / อาคาร / ของตกแต่ง
# ══════════════════════════════════════════

func _build_ground() -> void:
	var ground_col: Color = ArtGen.CITY_GROUNDS.get(layout.theme.ground, ArtGen.CITY_GROUNDS.grass).darkened(0.12)
	var flat: Array = []
	var walls: Array = []
	var water: Array = []
	for y in CityLayout.H:
		for x in CityLayout.W:
			var c = Vector2i(x, y)
			match layout.at(c):
				CityLayout.T.WALL: walls.append(c)
				CityLayout.T.WATER: water.append(c)
				_: flat.append(c)
	var gm = _mat(_pixel_tex(Color(0.85, 0.85, 0.85), 1, 16, 0.08))
	gm.vertex_color_use_as_albedo = true
	var mm = _make_mm(Vector3(1, 0.24, 1), gm, true)
	mm.multimesh.instance_count = flat.size()
	for i in flat.size():
		var c: Vector2i = flat[i]
		var t = layout.at(c)
		var raise = 0.02 if t in [CityLayout.T.ROAD, CityLayout.T.PLAZA, CityLayout.T.BRIDGE] else 0.0
		mm.multimesh.set_instance_transform(i, Transform3D(Basis(), Vector3(c.x + 0.5, -0.12 + raise, c.y + 0.5)))
		var col: Color = ground_col if t == CityLayout.T.GROUND else TILE_COLORS[t]
		mm.multimesh.set_instance_color(i, col.darkened(float(posmod(hash(c), 5)) * 0.025))
	var wm = _make_mm(Vector3(1, 1.6, 1), _mat(_pixel_tex(Color(0.55, 0.52, 0.5), 2, 16, 0.08)), false)
	wm.multimesh.instance_count = walls.size()
	for i in walls.size():
		wm.multimesh.set_instance_transform(i, Transform3D(Basis(), Vector3(walls[i].x + 0.5, 0.8, walls[i].y + 0.5)))
	var wat = StandardMaterial3D.new()
	wat.albedo_color = Color(0.22, 0.45, 0.68, 0.9)
	wat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wat.roughness = 0.08
	wat.metallic = 0.3
	var wa = _make_mm(Vector3(1, 0.06, 1), wat, false)
	wa.multimesh.instance_count = water.size()
	for i in water.size():
		wa.multimesh.set_instance_transform(i, Transform3D(Basis(), Vector3(water[i].x + 0.5, -0.2, water[i].y + 0.5)))
	# พื้นรอบนอกผัง
	var outside = MeshInstance3D.new()
	var pm = PlaneMesh.new()
	pm.size = Vector2(CityLayout.W + 60, CityLayout.H + 60)
	outside.mesh = pm
	outside.position = Vector3(CityLayout.W / 2.0, -0.26, CityLayout.H / 2.0)
	outside.material_override = _mat(_pixel_tex(ground_col.darkened(0.15), 3, 16, 0.06))
	add_child(outside)

func _make_mm(size: Vector3, mat: Material, colors: bool) -> MultiMeshInstance3D:
	var box = BoxMesh.new()
	box.size = size
	box.material = mat
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colors
	mm.mesh = box
	var mi = MultiMeshInstance3D.new()
	mi.multimesh = mm
	add_child(mi)
	return mi

func _build_buildings() -> void:
	for b in layout.buildings:
		var info: Dictionary = CityDB.BUILDINGS[b.kind]
		var r: Rect2i = b.rect
		var size = Vector2(r.size)
		var node = Node3D.new()
		node.position = Vector3(r.position.x + size.x / 2.0, 0, r.position.y + size.y / 2.0)
		add_child(node)
		var wall_col: Color = b.get("wall", info.wall)
		var roof_col: Color = b.get("roof", info.roof)
		if info.get("tent", false):
			var tent = MeshInstance3D.new()
			var cone = CylinderMesh.new()
			cone.top_radius = 0.05
			cone.bottom_radius = minf(size.x, size.y) / 2.0
			cone.height = 2.2
			cone.radial_segments = 8
			tent.mesh = cone
			tent.position = Vector3(0, 1.1, 0)
			tent.material_override = _mat(_pixel_tex(wall_col, 5, 16, 0.05))
			node.add_child(tent)
		else:
			var h = clampf(1.3 + size.y * 0.2, 1.3, 2.6)
			var fp = Vector3(size.x - 0.4, h, size.y - 0.4)
			_box(node, Vector3(size.x - 0.1, 0.14, size.y - 0.1), Vector3(0, 0.07, 0), _mat(_pixel_tex(Color(0.55, 0.52, 0.48), 6, 16, 0.05)))
			_box(node, fp, Vector3(0, h / 2.0 + 0.14, 0), _mat(_pixel_tex(wall_col, 7 + posmod(hash(b.kind), 5), 32, 0.04)))
			var red = _flat(Color(0.6, 0.12, 0.1))
			for sx in [-1, 1]:
				_box(node, Vector3(0.14, h, 0.14), Vector3(sx * (fp.x / 2.0 - 0.05), h / 2.0 + 0.14, fp.z / 2.0 + 0.04), red)
			_box(node, Vector3(0.7, 1.0, 0.04), Vector3(0, 0.64, fp.z / 2.0 + 0.02), _flat(Color(0.22, 0.14, 0.1)))
			var roof = MeshInstance3D.new()
			var pm = PrismMesh.new()
			var rh = 0.8 + size.x * 0.06
			pm.size = Vector3(size.y + 0.3, rh, size.x + 0.4)
			roof.mesh = pm
			roof.rotation_degrees.y = 90
			roof.position = Vector3(0, h + 0.14 + rh / 2.0, 0)
			roof.material_override = _mat(_pixel_tex(roof_col, 8 + posmod(hash(b.kind), 7), 16, 0.06))
			node.add_child(roof)
			if b.kind in ["palace", "sect_hall", "sect_pagoda", "temple"] and size.x >= 5:
				_box(node, Vector3(fp.x * 0.55, 0.9, fp.z * 0.55), Vector3(0, h + rh + 0.4, 0), _mat(_pixel_tex(wall_col, 9, 32, 0.04)))
				var r2 = MeshInstance3D.new()
				var p2 = PrismMesh.new()
				p2.size = Vector3(size.y * 0.7, 0.7, size.x * 0.7)
				r2.mesh = p2
				r2.rotation_degrees.y = 90
				r2.position = Vector3(0, h + rh + 1.2, 0)
				r2.material_override = roof.material_override
				node.add_child(r2)
		if info.service != "":
			var sign = Label3D.new()
			sign.text = b.name
			sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			sign.pixel_size = 0.006
			sign.font_size = 30
			sign.outline_size = 8
			sign.modulate = Color(1, 0.9, 0.55)
			sign.position = Vector3(0, 3.6, size.y / 2.0)
			node.add_child(sign)
			if b.kind != "sect_yard":
				var lan = MeshInstance3D.new()
				var sm = SphereMesh.new()
				sm.radius = 0.13
				sm.height = 0.28
				lan.mesh = sm
				lan.position = Vector3(size.x / 2.0 - 0.5, 1.3, size.y / 2.0 - 0.05)
				lan.material_override = _flat(Color(1.0, 0.3, 0.18), 3.0)
				node.add_child(lan)
				var l = OmniLight3D.new()
				l.light_color = Color(1.0, 0.55, 0.35)
				l.light_energy = 1.4
				l.omni_range = 5.0
				l.position = lan.position + Vector3(0, 0, 0.3)
				node.add_child(l)
				_lights.append(l)

func _build_decor() -> void:
	# กอหญ้า/ดอกไม้บนพื้นดินที่ไม่ใช่ทาง/อาคาร + ริมถนน
	var pts: Array = []
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(layout.city_id)
	for y in CityLayout.H:
		for x in CityLayout.W:
			var c = Vector2i(x, y)
			if layout.at(c) != CityLayout.T.GROUND or layout.blocked.has(c): continue
			for k in 2:
				if rng.randf() < 0.8: pts.append(Vector3(x + rng.randf(), 0.0, y + rng.randf()))
	var gcol: Color = ArtGen.CITY_GROUNDS.get(layout.theme.ground, Color(0.4, 0.58, 0.28)).darkened(0.15)
	HD2D.scatter_foliage(self, pts, gcol.lerp(Color(0.35, 0.55, 0.25), 0.5), 0.3, 0.75)
	var atlas = ArtGen.make_tree_atlas()
	var tint: Color = layout.theme.tree
	for c in layout.trees:
		var tex = AtlasTexture.new()
		tex.atlas = atlas
		tex.region = Rect2(64 * posmod(hash(c), 3), 0, 64, 64)
		var s = _sprite(tex, 2.4 + float(posmod(hash(c * 7), 4)) * 0.2, Vector3(c.x + 0.5, 0, c.y + 0.5))
		s.modulate = Color(1, 1, 1).lerp(tint.lightened(0.5), 0.5)
		add_child(s)
	for c in layout.lanterns:
		var post = Node3D.new()
		post.position = Vector3(c.x + 0.5, 0, c.y + 0.5)
		add_child(post)
		_box(post, Vector3(0.08, 1.4, 0.08), Vector3(0, 0.7, 0), _flat(Color(0.3, 0.2, 0.12)))
		var lan = MeshInstance3D.new()
		var sm = SphereMesh.new()
		sm.radius = 0.14
		sm.height = 0.3
		lan.mesh = sm
		lan.position = Vector3(0, 1.45, 0)
		lan.material_override = _flat(Color(1.0, 0.3, 0.15), 3.5)
		post.add_child(lan)
		var l = OmniLight3D.new()
		l.light_color = Color(1.0, 0.55, 0.3)
		l.light_energy = 1.3
		l.omni_range = 4.5
		l.position = Vector3(0, 1.5, 0)
		post.add_child(l)
		_lights.append(l)

# ══════════════════════════════════════════
# สะท้อนตัวละคร 2D -> สไปรต์ 3D + กล้องตามผู้เล่น
# ══════════════════════════════════════════

func _process(delta: float) -> void:
	if scene == null or not is_instance_valid(scene): return
	var world: Node2D = scene._world
	var seen := {}
	for n in world.get_children():
		if not (n is CityPlayer or n is CityNPC): continue
		seen[n] = true
		var m: Node3D = _mirrors.get(n)
		var spr2: Sprite2D = n._sprite
		if m == null:
			m = Node3D.new()
			m.add_child(_sprite(HD2D.outlined(spr2.texture), UNIT_H, Vector3.ZERO))
			m.set_meta("src", spr2.texture)
			if n is CityNPC:
				var lbl = Label3D.new()
				lbl.text = n.display_name
				lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				lbl.pixel_size = 0.0045
				lbl.font_size = 28
				lbl.outline_size = 8
				lbl.modulate = n._label.get_theme_color("font_color")
				lbl.position = Vector3(0, UNIT_H + 0.25, 0)
				m.add_child(lbl)
			add_child(m)
			_mirrors[n] = m
		m.position = to3(n.global_position)
		var s3: Sprite3D = m.get_child(0)
		if m.get_meta("src") != spr2.texture:
			m.set_meta("src", spr2.texture)
			s3.texture = HD2D.outlined(spr2.texture)
			s3.pixel_size = UNIT_H / maxf(1.0, spr2.texture.get_height())
			s3.offset = Vector2(0, spr2.texture.get_height() / 2.0)
		s3.flip_h = spr2.flip_h
		s3.modulate = spr2.modulate
		s3.position.y = -spr2.position.y / CityLayout.TILE
		m.visible = n.visible
	for n in _mirrors.keys():
		if not seen.has(n) or not is_instance_valid(n):
			_mirrors[n].queue_free()
			_mirrors.erase(n)
	if scene.player != null and is_instance_valid(scene.player):
		var pp = to3(scene.player.global_position)
		var target = pp + Vector3(0, 4.6, 8.6) * zoom
		_cam.position = _cam.position.lerp(target, clampf(delta * 6.0, 0.0, 1.0)) if _cam.position != Vector3.ZERO else target
		_cam.look_at(pp + Vector3(0, 1.0, 0))
		HD2D.tilt_shift(_attrs, _cam.position.distance_to(pp), 3.0 * zoom, 5.0 * zoom, 0.11)
		HD2D.update_backdrop(_backdrop, pp)
