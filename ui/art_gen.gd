extends RefCounted
class_name ArtGen

## สร้างกราฟิกด้วยโค้ด (ยังไม่มีไฟล์ภาพในโปรเจกต์):
## - รูปหน้าตัวละคร (Portrait) ตามเผ่า/เพศ/ธาตุ สุ่มจาก portrait_seed
## - ตัวละครจิ๋ว (Sprite) สำหรับแผนที่โลกและฉากต่อสู้
## - สัตว์อสูร, และ Tile atlas ของแผนที่
## ถ้าต้องการใช้รูปวาดจริง ให้ใส่ไฟล์ .png ไว้ที่ res://assets/portraits/<เผ่า>/<เพศ>/
## ระบบจะเลือกรูปจากโฟลเดอร์นั้นแทนรูปที่วาดด้วยโค้ดโดยอัตโนมัติ

const PORTRAIT_DIR = "res://assets/portraits/%s/%s/"

const SKIN_TONES = [Color(0.96, 0.85, 0.72), Color(0.91, 0.76, 0.6), Color(0.82, 0.64, 0.48)]
const HAIR_COLORS = [Color(0.08, 0.07, 0.07), Color(0.18, 0.12, 0.08), Color(0.3, 0.2, 0.14)]
const RACE_HAIR = {
	"เผ่าจิ้งจอก": [Color(0.75, 0.4, 0.15), Color(0.85, 0.85, 0.88)],
	"เผ่าอสูร": [Color(0.45, 0.08, 0.1), Color(0.12, 0.1, 0.2)],
	"เผ่าวิญญาณ": [Color(0.88, 0.92, 0.98), Color(0.6, 0.75, 0.9)],
}

## จานสีสำหรับปรับหน้าตาเอง (หน้าสร้างตัวละคร)
const HAIR_PALETTE = [Color(0.08, 0.07, 0.07), Color(0.3, 0.2, 0.14), Color(0.55, 0.3, 0.12), Color(0.88, 0.88, 0.9), Color(0.45, 0.08, 0.1), Color(0.2, 0.25, 0.45), Color(0.75, 0.4, 0.15), Color(0.6, 0.75, 0.9)]
const ROBE_PALETTE = [Color(0.25, 0.3, 0.45), Color(0.5, 0.15, 0.15), Color(0.2, 0.4, 0.25), Color(0.85, 0.85, 0.82), Color(0.15, 0.15, 0.18), Color(0.55, 0.4, 0.2), Color(0.45, 0.25, 0.5), Color(0.3, 0.5, 0.6)]
const HAIR_STYLE_NAMES = ["มวยผมสูง", "มวยผมรัดเกล้า", "ผมยาวปล่อยข้าง"]

static var _cache := {}

# ══════════════════════════════════════════
# Raster helpers (วาดลง Image โดยตรง)
# ══════════════════════════════════════════

static func _plot(img: Image, x: int, y: int, c: Color) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height(): return
	if c.a >= 0.999:
		img.set_pixel(x, y, c)
	else:
		var dst = img.get_pixel(x, y)
		var out = dst.lerp(Color(c, 1.0), c.a)
		out.a = max(dst.a, c.a)
		img.set_pixel(x, y, out)

static func ellipse(img: Image, center: Vector2, rx: float, ry: float, c: Color) -> void:
	for y in range(int(center.y - ry), int(center.y + ry) + 1):
		for x in range(int(center.x - rx), int(center.x + rx) + 1):
			var d = pow((x + 0.5 - center.x) / rx, 2) + pow((y + 0.5 - center.y) / ry, 2)
			if d <= 1.0:
				_plot(img, x, y, c)

static func rect(img: Image, r: Rect2, c: Color) -> void:
	for y in range(int(r.position.y), int(r.end.y)):
		for x in range(int(r.position.x), int(r.end.x)):
			_plot(img, x, y, c)

static func poly(img: Image, pts: PackedVector2Array, c: Color) -> void:
	var bounds = Rect2(pts[0], Vector2.ZERO)
	for p in pts: bounds = bounds.expand(p)
	for y in range(int(bounds.position.y), int(bounds.end.y) + 1):
		for x in range(int(bounds.position.x), int(bounds.end.x) + 1):
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), pts):
				_plot(img, x, y, c)

static func line(img: Image, a: Vector2, b: Vector2, width: float, c: Color) -> void:
	var steps = int(a.distance_to(b)) + 1
	for i in steps + 1:
		var p = a.lerp(b, float(i) / steps)
		ellipse(img, p, width / 2.0 + 0.3, width / 2.0 + 0.3, c)

static func _new_image(w: int, h: int, fill: Color = Color(0, 0, 0, 0)) -> Image:
	var img = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(fill)
	return img

# ══════════════════════════════════════════
# ลักษณะหน้าตาจาก seed
# ══════════════════════════════════════════

static func _looks(d: DiscipleData) -> Dictionary:
	var rng = RandomNumberGenerator.new()
	rng.seed = d.portrait_seed
	var skin: Color = SKIN_TONES[rng.randi() % SKIN_TONES.size()]
	if d.race == "เผ่าวิญญาณ": skin = Color(0.86, 0.9, 0.97)
	var hair_pool: Array = RACE_HAIR.get(d.race, HAIR_COLORS)
	var hair: Color = hair_pool[rng.randi() % hair_pool.size()]
	if d.race == "มนุษย์" and rng.randf() < 0.06: hair = Color(0.88, 0.88, 0.9) # ผมขาว
	var elem: Color = CultivationSys.ELEMENT_COLORS.get(d.element, Color(0.6, 0.6, 0.7))
	var robe = elem.darkened(0.45).lerp(Color(0.3, 0.3, 0.32), 0.3)
	var style = rng.randi() % 3
	# ค่าที่ผู้เล่นปรับเอง ทับค่าสุ่ม
	var ap: Dictionary = d.appearance
	if ap.has("hair_color"): hair = HAIR_PALETTE[int(ap.hair_color) % HAIR_PALETTE.size()]
	if ap.has("skin"): skin = SKIN_TONES[int(ap.skin) % SKIN_TONES.size()]
	if ap.has("robe"): robe = ROBE_PALETTE[int(ap.robe) % ROBE_PALETTE.size()]
	if ap.has("hair_style"): style = int(ap.hair_style) % 3
	return {
		"skin": skin, "hair": hair, "elem": elem,
		"robe": robe,
		"trim": elem.lightened(0.2),
		"female": d.gender == "หญิง", "race": d.race,
		"eye_gap": rng.randi_range(8, 10), "face_w": rng.randf_range(20.0, 23.0),
		"style": style,
	}

## ล้างรูปที่แคชไว้ของตัวละครนี้ (หลังเปลี่ยนหน้าตา)
static func invalidate(d: DiscipleData) -> void:
	for key in _cache.keys():
		if key is String and key.contains(":%d:" % d.portrait_seed):
			_cache.erase(key)

# ══════════════════════════════════════════
# Portrait 128x128
# ══════════════════════════════════════════

static func get_portrait(d: DiscipleData) -> Texture2D:
	var custom = _find_custom_portrait(d)
	if custom: return custom
	var key = "portrait:%d:%s:%s:%s:%s" % [d.portrait_seed, d.race, d.gender, d.element, str(d.appearance)]
	if not _cache.has(key):
		_cache[key] = ImageTexture.create_from_image(_draw_portrait(_looks(d)))
	return _cache[key]

static func _find_custom_portrait(d: DiscipleData) -> Texture2D:
	var dir = PORTRAIT_DIR % [d.race, d.gender]
	if not DirAccess.dir_exists_absolute(dir): return null
	var files: Array[String] = []
	for f in ResourceLoader.list_directory(dir):
		if f.get_extension().to_lower() in ["png", "jpg", "jpeg", "webp"]:
			files.append(f)
	if files.is_empty(): return null
	files.sort()
	return load(dir + files[d.portrait_seed % files.size()])

static func _draw_portrait(L: Dictionary) -> Image:
	var img = _new_image(128, 128, Color(0.9, 0.85, 0.72))
	# พื้นหลังกระดาษ + วงออร่าธาตุ
	ellipse(img, Vector2(64, 60), 54, 54, Color(L.elem, 0.18))
	ellipse(img, Vector2(64, 60), 44, 44, Color(L.elem, 0.12))
	var cx = 64.0
	var fw: float = L.face_w

	# ผมด้านหลัง (หญิง: ผมยาว)
	if L.female:
		ellipse(img, Vector2(cx, 70), fw + 9, 44, L.hair)
	if L.race == "เผ่าวิญญาณ":
		ellipse(img, Vector2(cx, 56), fw + 6, 31, Color(0.6, 0.85, 1.0, 0.35))

	# หูจิ้งจอก
	if L.race == "เผ่าจิ้งจอก":
		for s in [-1, 1]:
			poly(img, PackedVector2Array([Vector2(cx + s * 10, 34), Vector2(cx + s * 26, 6), Vector2(cx + s * 30, 36)]), L.hair)
			poly(img, PackedVector2Array([Vector2(cx + s * 15, 32), Vector2(cx + s * 25, 13), Vector2(cx + s * 27, 33)]), Color(0.95, 0.7, 0.7))

	# ลำตัว/ชุดคลุม
	poly(img, PackedVector2Array([Vector2(14, 128), Vector2(114, 128), Vector2(102, 96), Vector2(cx, 86), Vector2(26, 96)]), L.robe)
	rect(img, Rect2(cx - 8, 76, 16, 16), L.skin.darkened(0.08))
	# ปกเสื้อไขว้
	line(img, Vector2(cx - 14, 90), Vector2(cx + 6, 118), 4, L.trim)
	line(img, Vector2(cx + 14, 90), Vector2(cx - 2, 108), 4, L.trim.darkened(0.15))

	# ใบหน้า
	ellipse(img, Vector2(cx, 56), fw, 26, L.skin)
	ellipse(img, Vector2(cx - fw + 1, 58), 3, 5, L.skin.darkened(0.1)) # หู
	ellipse(img, Vector2(cx + fw - 1, 58), 3, 5, L.skin.darkened(0.1))

	# เขาอสูร
	if L.race == "เผ่าอสูร":
		for s in [-1, 1]:
			poly(img, PackedVector2Array([Vector2(cx + s * 8, 36), Vector2(cx + s * 20, 6), Vector2(cx + s * 16, 38)]), Color(0.85, 0.8, 0.7))

	# ผมด้านหน้า
	var style: int = L.style
	ellipse(img, Vector2(cx, 38), fw + 3, 15, L.hair)
	rect(img, Rect2(cx - fw - 3, 36, fw * 2 + 6, 6), L.hair)
	if L.female:
		# หน้าม้า + ปิ่นปักผม
		poly(img, PackedVector2Array([Vector2(cx - fw, 40), Vector2(cx - 4, 40), Vector2(cx - fw + 2, 54)]), L.hair)
		poly(img, PackedVector2Array([Vector2(cx + fw, 40), Vector2(cx + 4, 40), Vector2(cx + fw - 2, 54)]), L.hair)
		if style == 0:
			# ปิ่นปักผม
			line(img, Vector2(cx + 12, 26), Vector2(cx + 30, 18), 2, Color(0.9, 0.8, 0.4))
			ellipse(img, Vector2(cx + 30, 18), 3.5, 3.5, L.trim)
		elif style == 1:
			# มวยสูง + ริบบิ้น
			ellipse(img, Vector2(cx, 18), 10, 9, L.hair)
			rect(img, Rect2(cx - 11, 22, 22, 3), L.trim)
		else:
			# มวยคู่สองข้าง
			ellipse(img, Vector2(cx - 20, 24), 8, 8, L.hair)
			ellipse(img, Vector2(cx + 20, 24), 8, 8, L.hair)
			ellipse(img, Vector2(cx - 20, 24), 3, 3, L.trim)
			ellipse(img, Vector2(cx + 20, 24), 3, 3, L.trim)
	else:
		# มวยผม
		if style == 0:
			ellipse(img, Vector2(cx, 20), 9, 8, L.hair)
			rect(img, Rect2(cx - 10, 22, 20, 3), L.trim)
		elif style == 1:
			ellipse(img, Vector2(cx, 22), 7, 7, L.hair)
			line(img, Vector2(cx - 12, 20), Vector2(cx + 12, 24), 2, Color(0.85, 0.75, 0.45))
		else:
			rect(img, Rect2(cx - fw - 3, 40, 5, 22), L.hair) # ผมข้างยาว
			rect(img, Rect2(cx + fw - 2, 40, 5, 22), L.hair)

	# ตา คิ้ว จมูก ปาก
	var gap: int = L.eye_gap
	for s in [-1, 1]:
		var ex = cx + s * gap
		line(img, Vector2(ex - 5, 48 - (1 if L.female else 0)), Vector2(ex + 5, 47 + (0 if L.female else 1)), 2 if not L.female else 1.5, L.hair.darkened(0.2))
		ellipse(img, Vector2(ex, 55), 4.5, 2.6 if not L.female else 3.2, Color(0.97, 0.96, 0.94))
		ellipse(img, Vector2(ex, 55), 2.2, 2.4, Color(0.12, 0.1, 0.1) if L.race != "เผ่าอสูร" else Color(0.75, 0.15, 0.1))
		if L.female:
			line(img, Vector2(ex - 5, 52), Vector2(ex + 4, 52), 1, Color(0.1, 0.08, 0.08))
	ellipse(img, Vector2(cx, 63), 1.3, 1.3, L.skin.darkened(0.25))
	line(img, Vector2(cx - 4, 70), Vector2(cx + 4, 70), 1.5, Color(0.75, 0.35, 0.35) if L.female else Color(0.6, 0.35, 0.3))

	# กรอบหมึก
	for i in 3:
		img.fill_rect(Rect2i(0, i, 128, 1), Color(0.25, 0.17, 0.1))
		img.fill_rect(Rect2i(0, 127 - i, 128, 1), Color(0.25, 0.17, 0.1))
		img.fill_rect(Rect2i(i, 0, 1, 128), Color(0.25, 0.17, 0.1))
		img.fill_rect(Rect2i(127 - i, 0, 1, 128), Color(0.25, 0.17, 0.1))
	return img

# ══════════════════════════════════════════
# ตัวละครจิ๋ว 48x64 (แผนที่/ฉากต่อสู้)
# ══════════════════════════════════════════

static func get_figure(d: DiscipleData) -> Texture2D:
	var key = "fig:%d:%s:%s:%s:%s:%s" % [d.portrait_seed, d.race, d.gender, d.element, d.affinity_style, str(d.appearance)]
	if not _cache.has(key):
		var L = _looks(d)
		L["weapon"] = d.affinity_style
		_cache[key] = ImageTexture.create_from_image(_draw_figure(L))
	return _cache[key]

## ตัวละครมนุษย์ฝั่งศัตรู (โจร/พรรคมาร/สำนักคู่แข่ง)
static func get_human_enemy(id: String, robe: Color) -> Texture2D:
	var key = "enemy_h:" + id
	if not _cache.has(key):
		var rng = RandomNumberGenerator.new()
		rng.seed = hash(id)
		_cache[key] = ImageTexture.create_from_image(_draw_figure({
			"skin": SKIN_TONES[rng.randi() % 3], "hair": HAIR_COLORS[rng.randi() % 3], "elem": robe,
			"robe": robe, "trim": robe.lightened(0.3), "female": false, "race": "มนุษย์",
			"eye_gap": 4, "face_w": 11.0, "style": 0, "weapon": "sword", "mask": true,
		}))
	return _cache[key]

static func _draw_figure(L: Dictionary) -> Image:
	var img = _new_image(48, 64)
	var cx = 24.0
	# เงาบนพื้น
	ellipse(img, Vector2(cx, 61), 14, 3, Color(0, 0, 0, 0.3))
	if L.female:
		ellipse(img, Vector2(cx, 22), 12, 16, L.hair)
	# ขา
	rect(img, Rect2(17, 50, 5, 11), Color(0.15, 0.12, 0.1))
	rect(img, Rect2(26, 50, 5, 11), Color(0.15, 0.12, 0.1))
	# ชุดคลุม
	poly(img, PackedVector2Array([Vector2(10, 54), Vector2(38, 54), Vector2(32, 27), Vector2(16, 27)]), L.robe)
	line(img, Vector2(18, 28), Vector2(28, 44), 2, L.trim)
	rect(img, Rect2(15, 40, 18, 3), L.trim.darkened(0.2))
	# แขน
	line(img, Vector2(16, 30), Vector2(10, 44), 4, L.robe.darkened(0.1))
	line(img, Vector2(32, 30), Vector2(38, 42), 4, L.robe.darkened(0.1))
	ellipse(img, Vector2(10, 45), 2.5, 2.5, L.skin)
	ellipse(img, Vector2(38, 43), 2.5, 2.5, L.skin)
	# อาวุธ
	match L.get("weapon", ""):
		"sword":
			line(img, Vector2(38, 44), Vector2(46, 18), 2, Color(0.85, 0.88, 0.92))
			line(img, Vector2(35, 42), Vector2(41, 45), 2, Color(0.6, 0.45, 0.2))
		"hidden_weapon":
			ellipse(img, Vector2(41, 41), 3, 3, Color(0.7, 0.72, 0.75))
		"formation":
			line(img, Vector2(38, 44), Vector2(42, 20), 2, Color(0.55, 0.4, 0.25))
			ellipse(img, Vector2(42, 19), 3, 3, L.elem)
		"poison":
			ellipse(img, Vector2(40, 46), 3, 4, Color(0.3, 0.7, 0.3))
	# หัว
	if L.race == "เผ่าจิ้งจอก":
		poly(img, PackedVector2Array([Vector2(16, 12), Vector2(17, 1), Vector2(22, 9)]), L.hair)
		poly(img, PackedVector2Array([Vector2(32, 12), Vector2(31, 1), Vector2(26, 9)]), L.hair)
	ellipse(img, Vector2(cx, 17), 11, 11, L.skin)
	if L.race == "เผ่าอสูร":
		poly(img, PackedVector2Array([Vector2(18, 9), Vector2(15, 0), Vector2(21, 7)]), Color(0.85, 0.8, 0.7))
		poly(img, PackedVector2Array([Vector2(30, 9), Vector2(33, 0), Vector2(27, 7)]), Color(0.85, 0.8, 0.7))
	ellipse(img, Vector2(cx, 10), 12, 6, L.hair)
	if not L.female:
		ellipse(img, Vector2(cx, 4), 4, 4, L.hair)
	if L.get("mask", false):
		rect(img, Rect2(14, 18, 20, 7), Color(0.12, 0.1, 0.1))
	ellipse(img, Vector2(cx - 4, 17), 1.4, 1.6, Color(0.1, 0.08, 0.08))
	ellipse(img, Vector2(cx + 4, 17), 1.4, 1.6, Color(0.1, 0.08, 0.08))
	return img

## สัตว์อสูร: "wolf" หรือ "ape"
static func get_beast(kind: String, color: Color) -> Texture2D:
	var key = "beast:%s:%s" % [kind, color.to_html()]
	if _cache.has(key): return _cache[key]
	var img = _new_image(64, 64)
	var dark = color.darkened(0.35)
	ellipse(img, Vector2(32, 61), 24, 3, Color(0, 0, 0, 0.3))
	if kind == "ape":
		ellipse(img, Vector2(32, 38), 18, 20, color)
		ellipse(img, Vector2(32, 16), 11, 10, color)
		ellipse(img, Vector2(32, 19), 7, 5, color.lightened(0.3))
		line(img, Vector2(16, 30), Vector2(8, 56), 7, dark)
		line(img, Vector2(48, 30), Vector2(56, 56), 7, dark)
		rect(img, Rect2(22, 52, 7, 9), dark)
		rect(img, Rect2(35, 52, 7, 9), dark)
		ellipse(img, Vector2(28, 14), 1.8, 1.8, Color(0.9, 0.2, 0.1))
		ellipse(img, Vector2(36, 14), 1.8, 1.8, Color(0.9, 0.2, 0.1))
	else:
		# หมาป่าหันหน้าไปทางซ้าย
		poly(img, PackedVector2Array([Vector2(50, 34), Vector2(63, 22), Vector2(58, 38)]), dark) # หาง
		ellipse(img, Vector2(36, 38), 20, 11, color)
		for x in [22, 28, 42, 48]:
			rect(img, Rect2(x, 44, 4, 16), dark)
		ellipse(img, Vector2(15, 30), 10, 9, color)
		poly(img, PackedVector2Array([Vector2(8, 30), Vector2(0, 35), Vector2(10, 38)]), color) # ปาก
		poly(img, PackedVector2Array([Vector2(12, 23), Vector2(14, 12), Vector2(19, 22)]), dark)
		poly(img, PackedVector2Array([Vector2(18, 22), Vector2(22, 13), Vector2(24, 24)]), dark)
		ellipse(img, Vector2(12, 28), 1.6, 1.6, Color(1, 0.85, 0.2))
	_cache[key] = ImageTexture.create_from_image(img)
	return _cache[key]

# ══════════════════════════════════════════
# Tile atlas ของแผนที่โลก (ภาพพู่กันจีนโทนจาง)
# ══════════════════════════════════════════

const TILE = 16
const BIOME_COLORS = [
	Color(0.33, 0.42, 0.5),   # DEEP
	Color(0.47, 0.58, 0.63),  # WATER
	Color(0.85, 0.79, 0.62),  # SAND
	Color(0.74, 0.76, 0.57),  # GRASS
	Color(0.52, 0.6, 0.43),   # FOREST
	Color(0.66, 0.63, 0.5),   # HILLS
	Color(0.56, 0.54, 0.51),  # MOUNTAIN
	Color(0.92, 0.92, 0.94),  # SNOW
]
const VARIANTS = 2

## Atlas แนวนอน: biome * VARIANTS + variant
static func make_tile_atlas() -> ImageTexture:
	if _cache.has("atlas"): return _cache["atlas"]
	var img = _new_image(TILE * BIOME_COLORS.size() * VARIANTS, TILE)
	var rng = RandomNumberGenerator.new()
	rng.seed = 99
	for b in BIOME_COLORS.size():
		for v in VARIANTS:
			var ox = (b * VARIANTS + v) * TILE
			var base: Color = BIOME_COLORS[b]
			for y in TILE:
				for x in TILE:
					var n = rng.randf_range(-0.025, 0.025)
					img.set_pixel(ox + x, y, Color(base.r + n, base.g + n, base.b + n))
			var o = Vector2(ox, 0)
			match b:
				1: # คลื่นน้ำ
					line(img, o + Vector2(3, 5 + v * 5), o + Vector2(8, 5 + v * 5), 1, base.lightened(0.15))
				3: # หญ้า
					for i in 3:
						var p = o + Vector2(rng.randi_range(2, 13), rng.randi_range(3, 13))
						line(img, p, p + Vector2(1, -2), 1, base.darkened(0.15))
				4: # ต้นไม้
					for t in 2:
						var p = o + Vector2(4 + t * 7 + v * 2, 8 + t * 3 - v * 2)
						rect(img, Rect2(p.x - 0.5, p.y + 2, 1, 3), Color(0.3, 0.22, 0.15))
						ellipse(img, p, 3.2, 3.5, Color(0.27, 0.37, 0.24))
				5: # เนิน
					line(img, o + Vector2(2, 11), o + Vector2(7, 6), 1, base.darkened(0.2))
					line(img, o + Vector2(7, 6), o + Vector2(12, 11), 1, base.darkened(0.2))
				6: # ภูเขา
					poly(img, PackedVector2Array([o + Vector2(1, 15), o + Vector2(8, 2 + v), o + Vector2(15, 15)]), Color(0.3, 0.29, 0.28))
					poly(img, PackedVector2Array([o + Vector2(6, 5 + v), o + Vector2(8, 2 + v), o + Vector2(10, 5 + v)]), Color(0.85, 0.85, 0.87))
				7: # ภูเขาหิมะ
					poly(img, PackedVector2Array([o + Vector2(1, 15), o + Vector2(8, 3), o + Vector2(15, 15)]), Color(0.7, 0.72, 0.78))
					poly(img, PackedVector2Array([o + Vector2(5, 8), o + Vector2(8, 3), o + Vector2(11, 8)]), Color(1, 1, 1))
	_cache["atlas"] = ImageTexture.create_from_image(img)
	return _cache["atlas"]

# ══════════════════════════════════════════
# Tile atlas ของฉากเมืองเดินสำรวจ (32x32)
# ══════════════════════════════════════════

const CITY_TILE = 32
## พื้นหลักตามธีมเมือง (ดู CityDB.THEMES)
const CITY_GROUNDS = {
	"grass": Color(0.55, 0.64, 0.4), "dirt": Color(0.6, 0.53, 0.4), "sand": Color(0.86, 0.78, 0.58),
	"jungle": Color(0.3, 0.45, 0.28), "snowgrass": Color(0.78, 0.82, 0.8),
}

## Atlas แนวนอน 7 ช่อง ตาม CityLayout.T: พื้น, ถนน, ลาน, น้ำ, กำแพง, ตรอก, สะพาน
static func make_city_atlas(ground: String) -> ImageTexture:
	var key = "city_atlas:" + ground
	if _cache.has(key): return _cache[key]
	var T = CITY_TILE
	var img = _new_image(T * 7, T)
	var rng = RandomNumberGenerator.new()
	rng.seed = 7
	var colors = [CITY_GROUNDS.get(ground, CITY_GROUNDS.grass), Color(0.62, 0.6, 0.56), Color(0.76, 0.72, 0.64), Color(0.3, 0.48, 0.62), Color(0.45, 0.42, 0.4), Color(0.4, 0.36, 0.3), Color(0.55, 0.4, 0.25)]
	for i in colors.size():
		var ox = i * T
		var base: Color = colors[i]
		for y in T:
			for x in T:
				var n = rng.randf_range(-0.03, 0.03)
				img.set_pixel(ox + x, y, Color(base.r + n, base.g + n, base.b + n))
		var o = Vector2(ox, 0)
		match i:
			0:
				for k in 5:
					var p = o + Vector2(rng.randi_range(3, 28), rng.randi_range(4, 28))
					line(img, p, p + Vector2(1, -3), 1, base.darkened(0.18))
			1: # หินปูถนน
				for row in 4:
					for col in 2:
						var off = 8 if row % 2 else 0
						rect(img, Rect2(ox + col * 16 + off - 7, row * 8, 1, 8), base.darkened(0.2))
					rect(img, Rect2(ox, row * 8, T, 1), base.darkened(0.2))
			2: # ลานหินแผ่นใหญ่
				rect(img, Rect2(ox, 0, T, 1), base.darkened(0.15))
				rect(img, Rect2(ox, 0, 1, T), base.darkened(0.15))
			3: # คลื่นน้ำ
				line(img, o + Vector2(4, 9), o + Vector2(13, 9), 1, base.lightened(0.25))
				line(img, o + Vector2(17, 22), o + Vector2(27, 22), 1, base.lightened(0.25))
			4: # กำแพงอิฐ
				for row in 4:
					rect(img, Rect2(ox, row * 8 + 7, T, 1), base.darkened(0.3))
					rect(img, Rect2(ox + (8 if row % 2 else 0) + 12, row * 8, 1, 8), base.darkened(0.3))
				rect(img, Rect2(ox, 0, T, 3), base.lightened(0.2))
			6: # สะพานไม้
				for k in 4:
					rect(img, Rect2(ox, k * 8 + 7, T, 1), base.darkened(0.35))
				rect(img, Rect2(ox, 0, T, 2), Color(0.35, 0.22, 0.12))
				rect(img, Rect2(ox, T - 2, T, 2), Color(0.35, 0.22, 0.12))
	_cache[key] = ImageTexture.create_from_image(img)
	return _cache[key]

## ชาวเมือง/ยาม/บุคคลในเมือง (สุ่มหน้าตาจาก id)
static func get_townsfolk(id: String, robe: Color, weapon: String = "", masked := false) -> Texture2D:
	var key = "town:%s:%s:%s" % [id, robe.to_html(), weapon]
	if not _cache.has(key):
		var rng = RandomNumberGenerator.new()
		rng.seed = hash(id)
		var female = rng.randf() < 0.45
		_cache[key] = ImageTexture.create_from_image(_draw_figure({
			"skin": SKIN_TONES[rng.randi() % 3], "hair": HAIR_COLORS[rng.randi() % 3], "elem": robe,
			"robe": robe, "trim": robe.lightened(0.3), "female": female, "race": "มนุษย์",
			"eye_gap": 8, "face_w": 21.0, "style": rng.randi() % 3, "weapon": weapon, "mask": masked,
		}))
	return _cache[key]

# ══════════════════════════════════════════
# อาณาเขตสำนัก (ไอโซเมตริก 64x32): แอตลาสพื้น + ต้นไม้ + สัตว์เลี้ยง
# ══════════════════════════════════════════

const ISO_W = 64
const ISO_H = 32
## สีพื้นตาม Territory.T: หญ้า ป่า(พื้นป่า) หิน น้ำ ดิน แปลงเพาะปลูก
const TERRITORY_COLORS = [Color(0.5, 0.65, 0.36), Color(0.3, 0.48, 0.27), Color(0.55, 0.54, 0.52), Color(0.28, 0.5, 0.7), Color(0.55, 0.42, 0.3), Color(0.42, 0.34, 0.22)]

static func _in_diamond(x: int, y: int) -> bool:
	return absf(x + 0.5 - ISO_W / 2.0) / (ISO_W / 2.0) + absf(y + 0.5 - ISO_H / 2.0) / (ISO_H / 2.0) <= 1.0

## แอตลาสพื้นไอโซเมตริก 6 ช่อง (ช่องละ 64x32 ทรงข้าวหลามตัด) เรียงตาม Territory.T
static func make_territory_atlas() -> ImageTexture:
	if _cache.has("territory_atlas"): return _cache["territory_atlas"]
	var img = _new_image(ISO_W * TERRITORY_COLORS.size(), ISO_H)
	var rng = RandomNumberGenerator.new()
	rng.seed = 21
	for i in TERRITORY_COLORS.size():
		var base: Color = TERRITORY_COLORS[i]
		var ox = i * ISO_W
		for y in ISO_H:
			for x in ISO_W:
				if not _in_diamond(x, y): continue
				var n = rng.randf_range(-0.035, 0.035)
				img.set_pixel(ox + x, y, Color(base.r + n, base.g + n, base.b + n))
		# ลวดลายเล็กๆ
		for k in 7:
			var p = Vector2(ox + rng.randi_range(14, 50), rng.randi_range(8, 24))
			match i:
				0: line(img, p, p + Vector2(1, -3), 1, base.darkened(0.2))
				2: ellipse(img, p, 2.2, 1.4, base.darkened(0.18))
				3: line(img, p, p + Vector2(7, 0), 1, base.lightened(0.28))
				5:
					if k < 6: line(img, Vector2(ox + 12, 8 + k * 2), Vector2(ox + 52, 8 + k * 2), 1, base.darkened(0.25))
	var tex = ImageTexture.create_from_image(img)
	_cache["territory_atlas"] = tex
	return tex

## ต้นไม้ 3 แบบ ช่องละ 64x64 (โคนต้นอยู่กลางล่าง ตรงกับจุดกึ่งกลางช่องไอโซ) แบบสน/ใบกว้าง/พุ่ม
static func make_tree_atlas() -> ImageTexture:
	if _cache.has("tree_atlas"): return _cache["tree_atlas"]
	var img = _new_image(64 * 3, 64)
	for v in 3:
		var ox = v * 64
		ellipse(img, Vector2(ox + 32, 56), 14, 5, Color(0, 0, 0, 0.22))
		rect(img, Rect2(ox + 29, 40, 6, 17), Color(0.36, 0.25, 0.16))
		match v:
			0: # สน
				for k in 3:
					var w = 22 - k * 5
					poly(img, PackedVector2Array([Vector2(ox + 32, 6 + k * 10), Vector2(ox + 32 + w, 30 + k * 7), Vector2(ox + 32 - w, 30 + k * 7)]), Color(0.16, 0.36 + k * 0.05, 0.2))
			1: # ใบกว้าง
				ellipse(img, Vector2(ox + 32, 28), 20, 17, Color(0.2, 0.42, 0.2))
				ellipse(img, Vector2(ox + 25, 24), 12, 11, Color(0.27, 0.5, 0.25))
				ellipse(img, Vector2(ox + 40, 30), 10, 9, Color(0.18, 0.37, 0.18))
			2: # พุ่ม
				ellipse(img, Vector2(ox + 32, 38), 17, 14, Color(0.24, 0.45, 0.22))
				ellipse(img, Vector2(ox + 24, 34), 10, 9, Color(0.3, 0.52, 0.27))
				ellipse(img, Vector2(ox + 42, 36), 9, 8, Color(0.21, 0.4, 0.2))
	var tex = ImageTexture.create_from_image(img)
	_cache["tree_atlas"] = tex
	return tex

## สัตว์เลี้ยง/สัตว์ป่าในอาณาเขต (หันซ้าย 64x64): วัว หมู ไก่ หมาป่า
static func get_animal(kind: String) -> Texture2D:
	var key = "animal:" + kind
	if _cache.has(key): return _cache[key]
	if kind == "wolf":
		_cache[key] = get_beast("wolf", Color(0.55, 0.55, 0.58))
		return _cache[key]
	var img = _new_image(64, 64)
	ellipse(img, Vector2(32, 58), 20, 4, Color(0, 0, 0, 0.25))
	if kind == "cow":
		var hide = Color(0.93, 0.92, 0.9)
		var patch = Color(0.2, 0.17, 0.15)
		for x in [18, 24, 40, 46]:
			rect(img, Rect2(x, 42, 4, 15), hide.darkened(0.2))
		ellipse(img, Vector2(34, 36), 20, 11, hide)
		ellipse(img, Vector2(28, 33), 6, 5, patch)
		ellipse(img, Vector2(42, 38), 5, 4, patch)
		ellipse(img, Vector2(13, 30), 8, 7, hide)
		ellipse(img, Vector2(8, 33), 4, 3, Color(0.95, 0.7, 0.7))
		rect(img, Rect2(11, 20, 2, 5), Color(0.85, 0.8, 0.6))
		rect(img, Rect2(17, 20, 2, 5), Color(0.85, 0.8, 0.6))
		ellipse(img, Vector2(11, 28), 1.3, 1.3, Color(0.1, 0.1, 0.1))
		line(img, Vector2(53, 30), Vector2(58, 44), 2, hide.darkened(0.25))
	elif kind == "pig":
		var skin = Color(0.95, 0.7, 0.68)
		for x in [20, 26, 40, 46]:
			rect(img, Rect2(x, 44, 4, 13), skin.darkened(0.25))
		ellipse(img, Vector2(34, 38), 20, 11, skin)
		ellipse(img, Vector2(14, 36), 8, 7, skin)
		ellipse(img, Vector2(7, 38), 4, 3.5, skin.lightened(0.15))
		poly(img, PackedVector2Array([Vector2(13, 26), Vector2(19, 25), Vector2(17, 31)]), skin.darkened(0.2))
		ellipse(img, Vector2(12, 33), 1.3, 1.3, Color(0.1, 0.1, 0.1))
		line(img, Vector2(53, 34), Vector2(57, 30), 2, skin.darkened(0.2))
	else: # chicken
		var feather = Color(0.97, 0.95, 0.88)
		ellipse(img, Vector2(34, 42), 11, 9, feather)
		poly(img, PackedVector2Array([Vector2(44, 38), Vector2(56, 28), Vector2(52, 46)]), feather.darkened(0.15))
		ellipse(img, Vector2(22, 32), 6, 6, feather)
		poly(img, PackedVector2Array([Vector2(17, 31), Vector2(11, 34), Vector2(17, 36)]), Color(0.95, 0.65, 0.15))
		ellipse(img, Vector2(21, 24), 3, 3, Color(0.85, 0.15, 0.12))
		ellipse(img, Vector2(20, 31), 1.2, 1.2, Color(0.1, 0.1, 0.1))
		rect(img, Rect2(31, 50, 2, 8), Color(0.9, 0.6, 0.15))
		rect(img, Rect2(37, 50, 2, 8), Color(0.9, 0.6, 0.15))
	_cache[key] = ImageTexture.create_from_image(img)
	return _cache[key]
