extends RefCounted
class_name HD2D

## ชุดเครื่องมือภาพ HD-2D ที่ใช้ร่วมกันทุกฉาก 3D (เดินในสำนัก / เมือง-สำนักอื่น / ฉากต่อสู้)
## - outlined(): เติมเส้นขอบเข้มรอบสไปรต์พิกเซล (ตัวละครเด่นจากพื้นแบบเกมต้นแบบ)
## - scatter_foliage(): กอหญ้า/ดอกไม้เป็นสไปรต์ MultiMesh ไหวตามลม (shader) วางได้นับพันกอโดยไม่หนัก
## - backdrop(): ภูเขาวาดซ้อนหลายชั้นไกลๆ + ท้องฟ้าไล่สี เลื่อนตามกล้องแบบพารัลแลกซ์
## - post(): ปรับโทนสี (LUT 1 มิติ) + มุมจอมืด (vignette) + ฟองแสงเรือง
## - tilt_shift(): ตั้งระยะชัดตื้นให้ช่วงกลางชัด ฉากหน้า/ฉากหลังเบลอ (แบบโมเดลจำลอง)
## ทุกภาพสร้างจากโค้ด เปลี่ยนเป็นไฟล์ภาพจริงได้ภายหลังโดยไม่ต้องแก้ฉาก

static var _cache := {}

# ══════════════════════════════════════════
# เส้นขอบสไปรต์
# ══════════════════════════════════════════

## คืนเท็กซ์เจอร์ที่มีเส้นขอบ 1 พิกเซล (สีเข้ม) รอบส่วนทึบ · แคชตามเท็กซ์เจอร์ต้นฉบับ
static func outlined(tex: Texture2D, col := Color(0.08, 0.06, 0.05, 1.0)) -> Texture2D:
	if tex == null: return tex
	var key = "ol:%d" % tex.get_instance_id()
	if _cache.has(key): return _cache[key]
	var src: Image = tex.get_image()
	if src == null: return tex
	if src.is_compressed(): src.decompress()
	src.convert(Image.FORMAT_RGBA8)
	var w = src.get_width() + 2
	var h = src.get_height() + 2
	var out = Image.create(w, h, false, Image.FORMAT_RGBA8)
	out.blit_rect(src, Rect2i(0, 0, src.get_width(), src.get_height()), Vector2i(1, 1))
	# หาขอบจากภาพต้นฉบับก่อน แล้วค่อยระบาย (กันเส้นขอบลามต่อกันเอง)
	var edges: Array[Vector2i] = []
	for y in h:
		for x in w:
			if out.get_pixel(x, y).a > 0.3: continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var p = Vector2i(x, y) + d
				if p.x >= 0 and p.y >= 0 and p.x < w and p.y < h and out.get_pixelv(p).a > 0.5:
					edges.append(Vector2i(x, y))
					break
	for e in edges: out.set_pixelv(e, col)
	var t = ImageTexture.create_from_image(out)
	_cache[key] = t
	return t

# ══════════════════════════════════════════
# กอหญ้า / ดอกไม้ไหวตามลม
# ══════════════════════════════════════════

const FOLIAGE_SHADER = """
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_burley;
uniform sampler2D tex : source_color, filter_nearest;
uniform float cols = 6.0;
uniform float sway = 0.07;
void vertex() {
	// ตั้งหันหาจอเฉพาะแกนนอน (billboard แกน Y) + ไหวตามลมเฉพาะปลายยอด
	vec3 right = normalize(vec3(INV_VIEW_MATRIX[0].x, 0.0, INV_VIEW_MATRIX[0].z));
	vec3 origin = MODEL_MATRIX[3].xyz;
	float s = length(MODEL_MATRIX[0].xyz);
	float tip = 1.0 - UV.y;
	float w = sin(TIME * 1.7 + origin.x * 0.9 + origin.z * 0.6) * sway * tip;
	vec3 world = origin + right * (VERTEX.x + w) * s + vec3(0.0, VERTEX.y * s, 0.0);
	VERTEX = (inverse(MODEL_MATRIX) * vec4(world, 1.0)).xyz;
	NORMAL = (inverse(MODEL_MATRIX) * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
	UV.x = (UV.x + floor(INSTANCE_CUSTOM.x * cols)) / cols;
	COLOR = vec4(INSTANCE_CUSTOM.y, INSTANCE_CUSTOM.y, INSTANCE_CUSTOM.y, 1.0);
}
void fragment() {
	vec4 c = texture(tex, UV);
	if (c.a < 0.5) discard;
	ALBEDO = c.rgb * COLOR.rgb;
	ROUGHNESS = 1.0;
}
"""

## แอตลาสกอหญ้า/ดอกไม้ 6 แบบ (แบบละ 16x16): หญ้าสูง 2 แบบ, ดอกเหลือง, ดอกชมพู, ดอกขาว, เฟิร์น
static func foliage_atlas(grass := Color(0.36, 0.58, 0.25)) -> ImageTexture:
	var key = "fol:" + grass.to_html()
	if _cache.has(key): return _cache[key]
	var img = Image.create(96, 16, false, Image.FORMAT_RGBA8)
	var rng = RandomNumberGenerator.new()
	rng.seed = 99
	for v in 6:
		var ox = v * 16
		var blades = 7 if v < 2 else 4
		for b in blades:
			var x = ox + rng.randi_range(2, 13)
			var hgt = rng.randi_range(6, 14) if v != 5 else rng.randi_range(5, 9)
			var col = grass.darkened(rng.randf_range(0.0, 0.3)) if rng.randf() < 0.7 else grass.lightened(0.15)
			var lean = rng.randi_range(-2, 2)
			for k in hgt:
				var px = x + int(lean * k / float(hgt))
				img.set_pixel(clampi(px, ox, ox + 15), 15 - k, col)
		match v:
			2, 3, 4:
				var fc = [Color(1.0, 0.85, 0.2), Color(1.0, 0.6, 0.75), Color(0.95, 0.95, 0.9)][v - 2]
				for f in 3:
					var cx = ox + rng.randi_range(3, 12)
					var cy = rng.randi_range(3, 8)
					for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
						img.set_pixel(clampi(cx + d.x, ox, ox + 15), clampi(cy + d.y, 0, 15), fc if d != Vector2i.ZERO else Color(1, 0.95, 0.5))
			5:
				for k in 5:
					img.set_pixel(ox + 4 + k * 2, 6 + (k % 2), grass.darkened(0.35))
	var t = ImageTexture.create_from_image(img)
	_cache[key] = t
	return t

## วางกอหญ้า/ดอกไม้หลายกอเป็น MultiMesh เดียว · points = Array[Vector3] · flowers = สัดส่วนดอกไม้ (0..1)
static func scatter_foliage(parent: Node3D, points: Array, grass := Color(0.36, 0.58, 0.25), flowers := 0.25, size := 0.55) -> MultiMeshInstance3D:
	var quad = QuadMesh.new()
	quad.size = Vector2(1, 1)
	quad.center_offset = Vector3(0, 0.5, 0)
	var mat = ShaderMaterial.new()
	var sh = Shader.new()
	sh.code = FOLIAGE_SHADER
	mat.shader = sh
	mat.set_shader_parameter("tex", foliage_atlas(grass))
	quad.material = mat
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = quad
	mm.instance_count = points.size()
	var rng = RandomNumberGenerator.new()
	rng.seed = points.size() * 7 + 3
	for i in points.size():
		var s = size * rng.randf_range(0.7, 1.3)
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(s, s, s)), points[i]))
		var v = rng.randi_range(0, 1)
		if rng.randf() < flowers: v = rng.randi_range(2, 4)
		elif rng.randf() < 0.15: v = 5
		mm.set_instance_custom_data(i, Color((v + 0.5) / 6.0, rng.randf_range(0.8, 1.1), 0, 0))
	var mi = MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

# ══════════════════════════════════════════
# ภูเขาฉากหลัง + ท้องฟ้า
# ══════════════════════════════════════════

## ภาพทิวเขาพิกเซล (โปร่งใสด้านบน) แบบภาพวาดจีน · layer 0 = ไกลสุด (ซีด) .. 2 = ใกล้ (เข้ม)
static func mountain_tex(layer: int, tint: Color) -> ImageTexture:
	var key = "mtn:%d:%s" % [layer, tint.to_html()]
	if _cache.has(key): return _cache[key]
	var w = 256
	var h = 96
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	var rng = RandomNumberGenerator.new()
	rng.seed = 501 + layer * 17
	var noise = FastNoiseLite.new()
	noise.seed = 77 + layer
	noise.frequency = 0.02 + layer * 0.01
	var base = tint.lerp(Color(0.8, 0.85, 0.9), 0.55 - layer * 0.22)
	for x in w:
		var ridge = int(h * (0.25 + 0.2 * layer) + noise.get_noise_1d(x) * h * (0.45 - layer * 0.08))
		ridge = clampi(ridge, 4, h - 6)
		for y in range(ridge, h):
			var shade = 1.0 - float(y - ridge) / h * 0.35
			var c = base * shade
			# เส้นสันเขาสว่าง (หิมะ/แสง) ตามแบบภาพพู่กัน
			if y - ridge < 2 and layer == 0: c = c.lightened(0.25)
			img.set_pixel(x, y, Color(c.r, c.g, c.b, 1.0))
	var t = ImageTexture.create_from_image(img)
	_cache[key] = t
	return t

## สร้างชั้นภูเขา 3 ชั้น (Node3D) ให้ผู้เรียกเลื่อนตามกล้องด้วย update_backdrop()
static func backdrop(parent: Node3D, tint := Color(0.42, 0.55, 0.5)) -> Node3D:
	var root = Node3D.new()
	root.name = "Backdrop"
	for layer in 3:
		var q = MeshInstance3D.new()
		var qm = QuadMesh.new()
		qm.size = Vector2(150 - layer * 30, 40 - layer * 9)
		q.mesh = qm
		var m = StandardMaterial3D.new()
		m.albedo_texture = mountain_tex(layer, tint)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.disable_receive_shadows = true
		q.material_override = m
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		q.set_meta("dist", [70.0, 52.0, 38.0][layer])
		q.set_meta("par", [0.85, 0.7, 0.5][layer])
		root.add_child(q)
	parent.add_child(root)
	return root

## วางชั้นภูเขาไว้หลังจุดที่มอง (เลื่อนช้ากว่ากล้อง = พารัลแลกซ์)
static func update_backdrop(root: Node3D, focus: Vector3) -> void:
	if root == null: return
	for q in root.get_children():
		var dist: float = q.get_meta("dist")
		var par: float = q.get_meta("par")
		q.position = Vector3(focus.x * par, (q.mesh as QuadMesh).size.y * 0.5 - 4.0, focus.z - dist)

## ท้องฟ้าไล่สี (ProceduralSkyMaterial) ตามช่วงเวลา: 0 เช้า · 1 เย็น · 2 ค่ำ
static func apply_sky(env: Environment, tod: int) -> void:
	var sky_mat = ProceduralSkyMaterial.new()
	match tod:
		0:
			sky_mat.sky_top_color = Color(0.36, 0.56, 0.82)
			sky_mat.sky_horizon_color = Color(0.82, 0.86, 0.84)
			sky_mat.ground_horizon_color = Color(0.7, 0.74, 0.7)
		1:
			sky_mat.sky_top_color = Color(0.35, 0.35, 0.6)
			sky_mat.sky_horizon_color = Color(1.0, 0.62, 0.38)
			sky_mat.ground_horizon_color = Color(0.7, 0.45, 0.3)
		_:
			sky_mat.sky_top_color = Color(0.02, 0.03, 0.08)
			sky_mat.sky_horizon_color = Color(0.1, 0.13, 0.22)
			sky_mat.ground_horizon_color = Color(0.05, 0.06, 0.1)
	sky_mat.ground_bottom_color = sky_mat.ground_horizon_color.darkened(0.4)
	sky_mat.sun_angle_max = 0.0
	var sky = Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.background_mode = Environment.BG_SKY

# ══════════════════════════════════════════
# โทนสี / มุมจอมืด / ระยะชัดตื้น
# ══════════════════════════════════════════

const VIGNETTE_SHADER = """
shader_type canvas_item;
uniform float strength = 0.55;
void fragment() {
	vec2 d = UV - vec2(0.5);
	float v = smoothstep(0.35, 0.85, length(d * vec2(1.0, 0.85)));
	COLOR = vec4(0.03, 0.02, 0.01, v * strength);
}
"""

## ปรับโทนสีภาพรวมแบบเกมต้นแบบ: เงาออกฟ้าคราม ไฮไลต์อุ่น + คอนทราสต์/ความอิ่มสี + เรืองแสงนุ่ม
static func post(env: Environment, warmth := 1.0) -> void:
	var g = Gradient.new()
	g.set_color(0, Color(0.02, 0.03, 0.07))
	g.set_color(1, Color(1.0, 0.97 - 0.03 * warmth, 0.88 - 0.06 * warmth))
	g.add_point(0.5, Color(0.5, 0.49, 0.46))
	var gt = GradientTexture1D.new()
	gt.gradient = g
	gt.width = 256
	env.adjustment_enabled = true
	env.adjustment_color_correction = gt
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.18
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_bloom = 0.12
	env.glow_hdr_threshold = 0.85
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.ssao_enabled = true
	env.ssao_intensity = 2.2

## มุมจอมืด (CanvasLayer ใต้ UI) คืน CanvasLayer
static func vignette(parent: Node, layer := 0, strength := 0.55) -> CanvasLayer:
	var cl = CanvasLayer.new()
	cl.layer = layer
	var rect = ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m = ShaderMaterial.new()
	var sh = Shader.new()
	sh.code = VIGNETTE_SHADER
	m.shader = sh
	m.set_shader_parameter("strength", strength)
	rect.material = m
	cl.add_child(rect)
	parent.add_child(cl)
	return cl

## ระยะชัดตื้นแบบโมเดลจำลอง: ชัดเฉพาะช่วงรอบระยะโฟกัส ฉากหน้าและฉากหลังเบลอ
static func tilt_shift(attrs: CameraAttributesPractical, focus_dist: float, near_gap := 3.5, far_gap := 4.0, amount := 0.12) -> void:
	attrs.dof_blur_near_enabled = true
	attrs.dof_blur_near_distance = maxf(0.5, focus_dist - near_gap)
	attrs.dof_blur_near_transition = 2.5
	attrs.dof_blur_far_enabled = true
	attrs.dof_blur_far_distance = focus_dist + far_gap
	attrs.dof_blur_far_transition = 9.0
	attrs.dof_blur_amount = amount
