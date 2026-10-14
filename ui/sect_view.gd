extends Node2D
class_name SectView

## อาณาเขตสำนักมุมมอง 2.5D (Isometric) บนพื้นที่กว้าง (Territory)
## - พื้นดิน/ป่า/หิน/น้ำ/แปลงเพาะปลูก = TileMapLayer แบบไอโซเมตริก (แอตลาสสร้างด้วยโค้ด) ต้นไม้เป็นอีกชั้นที่เรียงตามความลึก
## - ตึกเป็นอินสแตนซ์ (SectData.structures) หลายขนาด หลายหลัง วางตรงไหนก็ได้บนช่องหญ้า/ดิน
##   ไซต์ก่อสร้างมีนั่งร้าน + หลอดความคืบหน้า ไฟไหม้/แสงยามค่ำวาดตามข้อมูลจริง
## - ศิษย์เป็นภาพประกอบ: เดินวนรอบตึกที่ประจำ (ตำแหน่งจาก ProductionSys.place_disciples) ไม่คำนวณเส้นทาง
## - โหมดสร้าง/ย้ายตึก: เงาเขียว/แดงตามที่วางได้ · โหมดเดิน: บังคับเจ้าสำนักเดิน (CityPlayer) กด [E] ที่หน้าตึก

signal building_clicked(uid: String)
signal disciple_clicked(d: DiscipleData)
## เดินไปถึงหน้าตึกแล้วกด [E]
signal building_entered(uid: String)
## โหมดสร้าง/ย้าย: ข้อความผลลัพธ์ และเมื่อวางตึกใหม่สำเร็จ
signal layout_message(text: String, ok: bool)
signal building_placed(type: String)

const TW = 64.0
const TH = 32.0
const WALK_SPEED = 55.0

var sect: SectData
var _ground: TileMapLayer
var _trees: TileMapLayer
var _objects: Node2D
var _overlay: Node2D
var _daynight: DayNight
var _bodies := {} # uid -> StaticBody2D
var _lights := {} # uid -> PointLight2D
var _doors := {} # uid -> InteractableArea
var avatar: CityPlayer
var hud: InteractionHUD
var _nodes := {} # uid -> Node2D (ตัวตึก)
var _walkers := {} # DiscipleData -> Node2D
var _shown := PackedByteArray()
var _animal_sprites := {} # id -> Sprite2D
var _animal_timer := 0.0
var _site_timer := 0.0
var _had_sites := false
var _node_state := {} # uid -> สถานะที่วาดล่าสุด (วาดซ้ำเฉพาะเมื่อเปลี่ยน)

## โหมดวางผัง: "" = ปกติ · "build" = วางตึกใหม่ (build_type) · "move" = ยกตึกเดิมไปวางที่ใหม่ (carry)
var mode := ""
var build_type := ""
var carry := ""
var _hover := Vector2i(-99, -99)
## โหมดสั่งงาน (mode == "orders"): order_kind = chop|mine|hunt|cancel · ลากเมาส์เลือกกรอบ
var order_kind := ""
var _sel_a := Vector2i(-99, -99)
var _selecting := false

static func iso(cell: Vector2) -> Vector2:
	return Vector2((cell.x - cell.y) * TW / 2.0, (cell.x + cell.y) * TH / 2.0)

## พิกัดโลก -> พิกัดตารางแบบทศนิยม
static func grid_f(world: Vector2) -> Vector2:
	return Vector2((world.x / (TW / 2.0) + world.y / (TH / 2.0)) / 2.0, (world.y / (TH / 2.0) - world.x / (TW / 2.0)) / 2.0)

## จุดกึ่งกลางฐานของอินสแตนซ์ (พิกัดโลก)
static func center_of(inst: Dictionary) -> Vector2:
	return iso(Vector2(inst.cell) + Vector2(BuildingDB.BUILDINGS[inst.type].size) / 2.0)

func _ready() -> void:
	_daynight = DayNight.new()
	add_child(_daynight)
	_ground = TileMapLayer.new()
	_ground.name = "Ground"
	_ground.tile_set = _make_ground_tileset()
	# ศูนย์กลางช่องของ TileMapLayer แบบ diamond-down เลื่อนไปทางขวาครึ่งช่อง ชดเชยให้ตรงกับ iso()
	_ground.position = Vector2(-TW / 2.0, 0)
	add_child(_ground)
	_objects = Node2D.new()
	_objects.y_sort_enabled = true
	add_child(_objects)
	_trees = TileMapLayer.new()
	_trees.name = "Trees"
	_trees.y_sort_enabled = true
	_trees.tile_set = _make_tree_tileset()
	_trees.position = Vector2(-TW / 2.0, 0)
	_objects.add_child(_trees)
	_overlay = Node2D.new()
	_overlay.z_index = 200
	_overlay.draw.connect(_draw_layout)
	add_child(_overlay)

## TileSet พื้นไอโซเมตริก: 6 ช่องตาม Territory.T (ป่า/หิน/น้ำ เดินผ่านไม่ได้)
func _make_ground_tileset() -> TileSet:
	var ts = TileSet.new()
	ts.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	ts.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	ts.tile_size = Vector2i(int(TW), int(TH))
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	var src = TileSetAtlasSource.new()
	src.texture = ArtGen.make_territory_atlas()
	src.texture_region_size = Vector2i(int(TW), int(TH))
	for i in Territory.NAMES.size():
		src.create_tile(Vector2i(i, 0))
	ts.add_source(src, 0)
	var diamond = PackedVector2Array([Vector2(0, -TH / 2.0), Vector2(TW / 2.0, 0), Vector2(0, TH / 2.0), Vector2(-TW / 2.0, 0)])
	for t in [Territory.T.ROCK, Territory.T.WATER]:
		var td = src.get_tile_data(Vector2i(t, 0), 0)
		td.add_collision_polygon(0)
		td.set_collision_polygon_points(0, 0, diamond)
	return ts

## TileSet ต้นไม้: 3 แบบ สูง 64px โคนต้นอยู่ที่กึ่งกลางช่อง
func _make_tree_tileset() -> TileSet:
	var ts = TileSet.new()
	ts.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	ts.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	ts.tile_size = Vector2i(int(TW), int(TH))
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	var src = TileSetAtlasSource.new()
	src.texture = ArtGen.make_tree_atlas()
	src.texture_region_size = Vector2i(64, 64)
	var small = PackedVector2Array([Vector2(0, -6), Vector2(14, 0), Vector2(0, 6), Vector2(-14, 0)])
	for i in 3:
		src.create_tile(Vector2i(i, 0))
	ts.add_source(src, 0)
	for i in 3:
		var td = src.get_tile_data(Vector2i(i, 0), 0)
		td.texture_origin = Vector2i(0, -24)
		td.y_sort_origin = 8
		td.add_collision_polygon(0)
		td.set_collision_polygon_points(0, 0, small)
	return ts

func setup(p_sect: SectData) -> void:
	sect = p_sect
	_shown = PackedByteArray()
	ProductionSys.place_disciples(sect)
	_sync_terrain()
	_build_bounds()
	refresh()

## เรียกเมื่อข้อมูลเปลี่ยน (ช่วงเวลาเปลี่ยน, สร้างตึก, ถางป่า, มอบหมายงาน)
func refresh() -> void:
	if sect.terrain_dirty:
		sect.terrain_dirty = false
		_sync_terrain()
	_sync_structures()
	var night = is_night()
	for inst in sect.structures:
		var uid: String = inst.uid
		var key = "%d|%d|%d|%d|%s" % [int(inst.level), int(inst.site.get("work", -1)) / 2, BuildingDB.post_members(sect, uid).size(), 1 if night else 0, str(sect.fires.has(uid))]
		if _node_state.get(uid) != key:
			_node_state[uid] = key
			_nodes[uid].queue_redraw()
	_update_building_bodies()
	var present := {}
	for d in sect.get_in_sect_disciples():
		present[d] = true
		if not _walkers.has(d):
			_walkers[d] = _make_walker(d)
			_walkers[d].position = iso(d.pos)
	for d in _walkers.keys():
		if not present.has(d):
			_walkers[d].queue_free()
			_walkers.erase(d)
	_overlay.queue_redraw()

# ── ภูมิประเทศ ──

## อัปเดตเฉพาะช่องที่เปลี่ยนจากที่แสดงอยู่ (ครั้งแรกวาดทั้งแผนที่)
func _sync_terrain() -> void:
	var n = Territory.SIZE
	if sect.terrain.size() != n * n: return
	var full = _shown.size() != n * n
	if full: _shown.resize(n * n)
	for y in n:
		for x in n:
			var i = y * n + x
			var t = sect.terrain[i]
			if not full and _shown[i] == t: continue
			_shown[i] = t
			var c = Vector2i(x, y)
			_ground.set_cell(c, 0, Vector2i(t, 0))
			if t == Territory.T.FOREST:
				_trees.set_cell(c, 0, Vector2i(posmod(hash(c), 3), 0))
			else:
				_trees.erase_cell(c)

# ── ตึก ──

func _sync_structures() -> void:
	var alive := {}
	for inst in sect.structures:
		alive[inst.uid] = true
		if not _nodes.has(inst.uid):
			var node = Node2D.new()
			node.set_meta("uid", inst.uid)
			node.draw.connect(_draw_building.bind(node))
			_objects.add_child(node)
			_nodes[inst.uid] = node
			var light = DayNight.make_light(Color(1, 0.75, 0.42), 1.0, 0.9)
			node.add_child(light)
			_lights[inst.uid] = light
		_nodes[inst.uid].position = center_of(inst)
	for uid in _nodes.keys():
		if not alive.has(uid):
			_nodes[uid].queue_free()
			_nodes.erase(uid)
			_lights.erase(uid)
			if _bodies.has(uid):
				_bodies[uid].queue_free()
				_bodies.erase(uid)
			if _doors.has(uid):
				_doors[uid].queue_free()
				_doors.erase(uid)

func location_pos(loc: String) -> Vector2:
	if loc == "courtyard": return iso(Vector2(Territory.HOME) + Vector2(0.5, 3.5))
	if loc == "gate": return iso(Territory.gate_pos())
	var inst = sect.instance(loc)
	if not inst.is_empty(): return center_of(inst) + Vector2(0, 40)
	return iso(Vector2(Territory.HOME))

## ข้อความกิจกรรมเหนือหัวศิษย์ (จากตึกที่ประจำ)
static func activity_text(d: DiscipleData) -> String:
	if StressSystem.is_deranged(d): return "ธาตุไฟแตกซ่าน"
	if d.is_child: return "เด็กน้อยวิ่งเล่น"
	var sect = GlobalGame.current_sect
	var t = BuildingDB.post_type(sect, d) if sect != null else ""
	if sect != null and d.needs.get("ordered", -1) == sect.current_day: return "ทำตามคำสั่ง"
	if sect != null and ProductionSys.is_building(sect, d): return "กำลังก่อสร้าง"
	if t == "": return "ว่าง"
	return BuildingDB.WORK_NAMES.get(BuildingDB.POSTS[t].work, "ประจำการ")

# ── ศิษย์เดิน ──

func _make_walker(d: DiscipleData) -> Node2D:
	var w = Node2D.new()
	var aura = QiAura.create(d, 12.0)
	aura.name = "Aura"
	aura.position = Vector2(0, -16)
	aura.visible = false
	w.add_child(aura)
	var sprite = Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = ArtGen.get_figure(d)
	sprite.scale = Vector2(0.55, 0.55)
	sprite.offset = Vector2(0, -32)
	w.add_child(sprite)
	for info in [["Name", d.disciple_name, -46, Color(1, 0.95, 0.8)], ["Activity", "", -58, Color(0.7, 0.9, 1)]]:
		var l = Label.new()
		l.name = info[0]
		l.text = info[1]
		l.position = Vector2(-50, info[2])
		l.size = Vector2(100, 14)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 9)
		l.add_theme_color_override("font_color", info[3])
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		l.add_theme_constant_override("outline_size", 3)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		w.add_child(l)
	w.set_meta("disciple", d)
	_objects.add_child(w)
	return w

func _process(delta: float) -> void:
	if mode != "":
		var h = _cursor_origin(get_global_mouse_position())
		if mode == "orders":
			var g = grid_f(get_global_mouse_position())
			h = Vector2i(floori(g.x), floori(g.y))
		if h != _hover:
			_hover = h
			_overlay.queue_redraw()
	if sect == null: return
	# ไซต์ก่อสร้างคืบหน้าทุก tick: อัปเดตหลอด/ตึกที่เสร็จเป็นระยะ (ไม่ต้องรอข้ามวัน)
	_site_timer -= delta
	if _site_timer <= 0.0:
		_site_timer = 0.4
		var has = not sect.construction_sites().is_empty()
		if has or _had_sites: refresh()
		_had_sites = has
	if GlobalGame.paused: return # หยุดเวลา = ทุกคน/สัตว์หยุดนิ่ง
	_update_animals(delta)
	# ตึกที่มีภาพเคลื่อนไหว (กองไฟ ค่ายกล ไฟไหม้) วาดซ้ำทุกเฟรม
	for inst in sect.structures:
		if _nodes.has(inst.uid) and (inst.type in ["campfire", "sect_formation"] or sect.fires.has(inst.uid)):
			_nodes[inst.uid].queue_redraw()
	var t = Time.get_ticks_msec() / 1000.0
	for d in _walkers:
		var w: Node2D = _walkers[d]
		var home = iso(d.pos)
		var sprite: Sprite2D = w.get_node("Sprite")
		# เดินวนเล็กๆ รอบจุดประจำการ (ภาพประกอบ) ด้วยความเร็วคงที่ แล้วหยุดพักสั้นๆ
		var target: Vector2 = w.get_meta("wt", home)
		var wait: float = w.get_meta("wait", 0.0)
		if target.distance_to(home) > 90.0: target = home
		if w.position.distance_to(target) < 2.0:
			wait -= delta
			if wait <= 0.0:
				target = home + Vector2(randf_range(-40.0, 40.0), randf_range(-14.0, 14.0))
				wait = randf_range(0.8, 3.0)
		w.set_meta("wt", target)
		w.set_meta("wait", wait)
		# เดินไปสร้างไซต์: ตามตำแหน่งจริงของข้อมูลด้วยความเร็วที่พอดีกับรอบอัปเดต (เดินต่อเนื่อง)
		if d.needs.get("travel", false):
			var goal = iso(d.pos)
			var step_s = maxf(0.2, ProductionSys.CONSTRUCTION_STEP * GlobalGame.SECONDS_PER_PHASE / GlobalGame.TICKS_PER_PHASE / maxf(0.1, GlobalGame.get_speed()))
			var vel = maxf(20.0, w.position.distance_to(goal) / step_s * 1.2)
			w.set_meta("wt", goal)
			target = goal
			w.position = w.position.move_toward(goal, vel * delta)
			sprite.flip_h = goal.x < w.position.x
			sprite.position.y = -abs(sin(t * 10.0)) * 2.0 if w.position.distance_to(goal) > 2.0 else 0.0
			var act2: Label = w.get_node("Activity")
			act2.text = activity_text(d)
			continue
		var to = target - w.position
		var moving = to.length() > 2.0
		w.position = w.position.move_toward(target, (60.0 if to.length() > 160.0 else 26.0) * delta)
		if moving:
			sprite.flip_h = to.x < 0
			sprite.position.y = -abs(sin(t * 10.0)) * 2.0
		else:
			sprite.position.y = 0
		var act: Label = w.get_node("Activity")
		act.text = activity_text(d)
		act.add_theme_color_override("font_color", Color(1, 0.35, 0.3) if d.stress >= StressSystem.WARN_AT else (Color(1, 0.65, 0.35) if d.mood < 30 else Color(0.7, 0.9, 1)))
		(w.get_node("Aura") as Node2D).visible = BuildingDB.post_type(sect, d) == "training_ground"

## สัตว์: สร้าง/ลบสไปรต์ตามข้อมูล (ทุก 0.4 วิ) และเลื่อนเข้าหาตำแหน่งจริงทุกเฟรม
func _update_animals(delta: float) -> void:
	_animal_timer -= delta
	if _animal_timer <= 0.0:
		_animal_timer = 0.4
		var alive := {}
		for a in sect.animals:
			alive[a.id] = true
			if not _animal_sprites.has(a.id):
				var sp = Sprite2D.new()
				sp.texture = ArtGen.get_animal(a.species)
				var s = {"cow": 0.55, "chicken": 0.4, "wolf": 0.55, "pig": 0.5}.get(a.species, 0.5)
				sp.scale = Vector2(s, s)
				sp.offset = Vector2(0, -26)
				sp.position = iso(a.pos)
				_objects.add_child(sp)
				_animal_sprites[a.id] = sp
		for id in _animal_sprites.keys():
			if not alive.has(id):
				_animal_sprites[id].queue_free()
				_animal_sprites.erase(id)
	# ช่วงเวลาจริงระหว่างการคิดของสัตว์สองรอบ (ปรับตามความเร็วเกม) ใช้เลื่อนด้วยความเร็วคงที่ให้เดินต่อเนื่อง
	var interval = maxf(0.25, AnimalSys.UPDATE_TICKS * GlobalGame.SECONDS_PER_PHASE / GlobalGame.TICKS_PER_PHASE / maxf(0.1, GlobalGame.get_speed()))
	for a in sect.animals:
		var sp: Sprite2D = _animal_sprites.get(a.id)
		if sp == null: continue
		var target = iso(a.pos)
		if not sp.has_meta("to") or sp.get_meta("to") != target:
			sp.set_meta("to", target)
			sp.set_meta("vel", maxf(8.0, sp.position.distance_to(target) / interval))
		var to = target - sp.position
		if to.length() > 1.0: sp.flip_h = to.x > 0
		sp.position = sp.position.move_toward(target, float(sp.get_meta("vel")) * delta)
		# แอนิเมชันท่าทางตามพฤติกรรม (คุ้ยเขี่ย/ขุดดิน/เคี้ยวเอื้อง/แช่โคลน/ตกใจ)
		var t_anim = Time.get_ticks_msec() / 1000.0
		match a.state:
			"peck":
				sp.offset.y = -26.0 + abs(sin(t_anim * 14.0)) * 4.0 # ไก่ก้มจิกดิน
			"root":
				sp.offset.y = -26.0 + abs(sin(t_anim * 7.0)) * 3.0 # หมูขุดดินหารากไม้
			"chew_cud":
				sp.offset.y = -26.0 + sin(t_anim * 4.0) * 1.2 # วัวเคี้ยวเอื้องสบายใจ
			"wallow":
				sp.offset.y = -21.0 # หมูนอนแช่โคลน
			"startle":
				sp.offset.y = -26.0 - abs(sin(t_anim * 20.0)) * 5.0 # ไก่ตื่นตกใจ
			_:
				sp.offset.y = -26.0
		# สัตว์เลี้ยงสีอุ่นขึ้นเล็กน้อย หมาป่าที่ล่าอยู่แดงเรื่อ
		sp.modulate = Color(1, 0.95, 0.85) if a.tame else (Color(1, 0.8, 0.8) if a.state == "hunt" else Color.WHITE)

## วางภาพศิษย์ไว้ที่ตำแหน่งข้อมูลทันที (ไม่เดินไหลมา)
func snap_walker(d: DiscipleData) -> void:
	refresh()
	if _walkers.has(d):
		_walkers[d].position = iso(d.pos)
		_walkers[d].set_meta("wt", iso(d.pos))

func is_night() -> bool:
	return sect != null and sect.time_phase == 2

# ══════════════════════════════════════════
# โหมดเดิน (อวตารเจ้าสำนัก)
# ══════════════════════════════════════════

## ฐานตึก (กันเดินทะลุ) + ไฟหน้าต่าง + จุดปฏิสัมพันธ์หน้าประตู ตามระดับตึกปัจจุบัน
func _update_building_bodies() -> void:
	for inst in sect.structures:
		var uid: String = inst.uid
		var b = BuildingDB.BUILDINGS[inst.type]
		var lv = int(inst.level)
		var standing = (lv > 0 or not inst.site.is_empty()) and inst.type != "training_ground"
		var half = Vector2(b.size) * Vector2(TW, TH) / 4.0
		if standing and not _bodies.has(uid):
			var body = StaticBody2D.new()
			var shape = CollisionPolygon2D.new()
			shape.polygon = _diamond(Vector2.ZERO, (b.size.x + b.size.y) * TW / 4.0 * 0.9, (b.size.x + b.size.y) * TH / 4.0 * 0.9)
			body.add_child(shape)
			add_child(body)
			_bodies[uid] = body
		elif not standing and _bodies.has(uid):
			_bodies[uid].queue_free()
			_bodies.erase(uid)
		if _bodies.has(uid): _bodies[uid].position = center_of(inst)
		var height = 26.0 + min(lv, 8) * 4.0
		_lights[uid].position = Vector2(-TW * 0.45, -height * 0.5)
		_lights[uid].visible = lv > 0 and inst.type not in ["training_ground", "farm", "quarry", "lumber_camp"]
		if inst.type == "campfire":
			_lights[uid].position = Vector2(0, -10)
			_lights[uid].scale = Vector2(1.6 + lv * 0.5, 1.6 + lv * 0.5)
		if hud != null:
			var text = ("เข้า " + BuildingDB.inst_name(inst)) if lv > 0 else ("%s (กำลังก่อสร้าง)" % BuildingDB.inst_name(inst))
			if not _doors.has(uid):
				var a = InteractableArea.make("building", text, Vector2(70, 46), { "id": uid })
				add_child(a)
				hud.track(a)
				a.interacted.connect(func(area): building_entered.emit(area.payload.id))
				_doors[uid] = a
			_doors[uid].prompt_text = text
			_doors[uid].position = center_of(inst) + Vector2(0, (b.size.x + b.size.y) * TH / 4.0 + 6)

## ขอบอาณาเขต (เดินออกนอกแผ่นดินไม่ได้)
func _build_bounds() -> void:
	var n = Territory.SIZE
	var corners = [iso(Vector2(0, 0)), iso(Vector2(n, 0)), iso(Vector2(n, n)), iso(Vector2(0, n))]
	var body = StaticBody2D.new()
	for i in 4:
		var seg = CollisionShape2D.new()
		var s = SegmentShape2D.new()
		s.a = corners[i]
		s.b = corners[(i + 1) % 4]
		seg.shape = s
		body.add_child(seg)
	add_child(body)

## เปิด/ปิดโหมดเดิน คืนค่า true ถ้าเปิดอยู่หลังเรียก
func toggle_avatar(d: DiscipleData, p_hud: InteractionHUD) -> bool:
	if avatar != null:
		avatar.queue_free()
		avatar = null
		hud.player = null
		for a in _doors.values(): a.monitoring = false
		hud.refresh()
		return false
	hud = p_hud
	_update_building_bodies()
	for a in _doors.values(): a.monitoring = true
	avatar = CityPlayer.create(d, self)
	avatar.position = location_pos("courtyard") + Vector2(0, 20)
	_objects.add_child(avatar)
	hud.player = avatar
	(avatar.get_node("Camera") as Camera2D).make_current()
	return true

# ── อินเทอร์เฟซ layout ที่ CityPlayer ต้องใช้ ──

func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	return PackedVector2Array([from, to])

func is_shadow(_cell) -> bool:
	return false

func world_to_cell(p: Vector2) -> Vector2:
	return p

func size_px() -> Vector2:
	return Vector2(Territory.SIZE * TW, Territory.SIZE * TH)

func bounds() -> Rect2:
	var n = Territory.SIZE
	return Rect2(-n * TW / 2.0 - 80, -160, n * TW + 160, n * TH + 240)

# ══════════════════════════════════════════
# โหมดสร้าง/ย้ายตึก (Free-form Layout)
# ══════════════════════════════════════════

func begin_build(type: String) -> void:
	mode = "build"
	build_type = type
	carry = ""
	_overlay.queue_redraw()

func begin_move() -> void:
	mode = "move"
	build_type = ""
	carry = ""
	_overlay.queue_redraw()

func begin_orders(kind: String) -> void:
	mode = "orders"
	order_kind = kind
	_selecting = false
	build_type = ""
	carry = ""
	_overlay.queue_redraw()

func order_press(world_pos: Vector2) -> void:
	var g = grid_f(world_pos)
	_sel_a = Vector2i(floori(g.x), floori(g.y))
	_selecting = true
	_overlay.queue_redraw()

func _sel_rect(world_pos: Vector2) -> Rect2i:
	var g = grid_f(world_pos)
	var b = Vector2i(floori(g.x), floori(g.y))
	var lo = Vector2i(mini(_sel_a.x, b.x), mini(_sel_a.y, b.y))
	var hi = Vector2i(maxi(_sel_a.x, b.x), maxi(_sel_a.y, b.y))
	return Rect2i(lo, hi - lo + Vector2i(1, 1))

func order_release(world_pos: Vector2) -> void:
	if not _selecting: return
	_selecting = false
	var rect = _sel_rect(world_pos)
	if order_kind in ["hunt", "tame"] and rect.size == Vector2i(1, 1): rect = rect.grow(1)
	var n = 0
	if order_kind == "cancel":
		n = OrderSys.cancel_area(sect, rect)
		layout_message.emit("ยกเลิกคำสั่ง %d จุด" % n, n > 0)
	else:
		n = OrderSys.add_area(sect, order_kind, rect)
		var what = {"chop": "ต้นไม้", "mine": "ก้อนหิน", "hunt": "สัตว์", "tame": "สัตว์ป่า"}.get(order_kind, "เป้าหมาย")
		if n > 0: layout_message.emit("สั่ง%s %d %s (ศิษย์ว่างจะทยอยทำทุกวัน)" % [OrderSys.KINDS[order_kind].name, n, what], true)
		else: layout_message.emit("ไม่พบ%sในกรอบที่เลือก (หรือสั่งไว้แล้ว/คิวเต็ม)" % what, false)
	_overlay.queue_redraw()

func end_mode() -> void:
	mode = ""
	order_kind = ""
	_selecting = false
	build_type = ""
	carry = ""
	_overlay.queue_redraw()

## ยกเลิกสิ่งที่ถืออยู่ (ในโหมดย้าย: วางตึกคืน, โหมดสร้าง: ออกจากโหมด)
func cancel_action() -> void:
	if mode == "move" and carry != "":
		carry = ""
		_overlay.queue_redraw()
	else:
		end_mode()

## ชนิดตึก/ขนาดที่กำลังจะวาง (เงา)
func _ghost_type() -> String:
	if mode == "build": return build_type
	if mode == "move" and carry != "": return sect.instance(carry).get("type", "")
	return ""

## พิกัดโลก -> มุมซ้ายบนของฐานที่ศูนย์กลางอยู่ใต้เมาส์
func _cursor_origin(world_pos: Vector2) -> Vector2i:
	var type = _ghost_type()
	var size = BuildingDB.BUILDINGS[type].size if type != "" else Vector2i(2, 2)
	var g = grid_f(world_pos)
	return Vector2i(roundi(g.x - size.x / 2.0), roundi(g.y - size.y / 2.0))

func _inst_at(world_pos: Vector2) -> Dictionary:
	var g = grid_f(world_pos)
	for inst in sect.structures:
		var r = BuildingDB.rect_of(inst)
		if Rect2(Vector2(r.position), Vector2(r.size)).has_point(g): return inst
	# คลิกที่ตัวอาคารด้านบนฐาน
	for inst in sect.structures:
		var local = world_pos - center_of(inst)
		var b = BuildingDB.BUILDINGS[inst.type]
		var hw = (b.size.x + b.size.y) * TW / 4.0
		if abs(local.x) < hw * 0.9 and local.y < 0 and local.y > -90: return inst
	return {}

func layout_click(world_pos: Vector2) -> void:
	if mode == "build":
		var err = BuildingDB.place_new(sect, build_type, _cursor_origin(world_pos))
		if err != "":
			layout_message.emit("วางตรงนี้ไม่ได้: " + err, false)
			return
		var name = BuildingDB.BUILDINGS[build_type].name
		layout_message.emit("วาง%sแล้ว — ศิษย์เริ่มก่อสร้าง (วางต่อได้ · คลิกขวา/Esc เพื่อออก)" % name, true)
		building_placed.emit(build_type)
		ProductionSys.place_disciples(sect)
		refresh()
	elif mode == "move":
		if carry == "":
			var inst = _inst_at(world_pos)
			if inst.is_empty():
				layout_message.emit("คลิกตึกที่ต้องการย้ายก่อน", false)
				return
			if not inst.site.is_empty():
				layout_message.emit("%sกำลังก่อสร้าง ย้ายไม่ได้" % BuildingDB.inst_name(inst), false)
				return
			carry = inst.uid
			var cost = BuildingDB.move_cost(inst)
			layout_message.emit("ยก%sแล้ว — คลิกที่ว่างเพื่อวาง%s (คลิกขวา/Esc ยกเลิก)" % [BuildingDB.inst_name(inst), (" · ค่าย้าย %d" % cost) if cost > 0 else " · ย้ายฟรี"], true)
			_overlay.queue_redraw()
		else:
			var name = BuildingDB.inst_name(sect.instance(carry))
			var err = BuildingDB.move_structure(sect, carry, _cursor_origin(world_pos))
			if err != "":
				layout_message.emit("วาง%sตรงนี้ไม่ได้: %s" % [name, err], false)
				return
			carry = ""
			refresh()
			layout_message.emit("ย้าย%sเรียบร้อย" % name, true)

func _draw_orders() -> void:
	var o = _overlay
	var font = ThemeDB.fallback_font
	for ord in sect.orders:
		var col: Color = OrderSys.KINDS[ord.kind].color
		var p = OrderSys.target_pos(sect, ord)
		if ord.kind == "hunt":
			var c = iso(p)
			o.draw_arc(c + Vector2(0, -10), 14.0, 0.0, TAU, 20, col, 2.0)
			o.draw_line(c + Vector2(-18, -10), c + Vector2(18, -10), col, 1.5)
			o.draw_line(c + Vector2(0, -28), c + Vector2(0, 8), col, 1.5)
		else:
			var cell: Vector2i = ord.cell
			var poly = _cell_poly(Rect2i(cell, Vector2i(1, 1)))
			o.draw_colored_polygon(poly, Color(col.r, col.g, col.b, 0.28))
			o.draw_polyline(poly + PackedVector2Array([poly[0]]), col, 1.5)
			var mark = "🪓" if ord.kind == "chop" else "⛏"
			o.draw_string(font, iso(Vector2(cell) + Vector2(0.5, 0.5)) + Vector2(-7, -18), mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.9))
	if mode == "orders":
		var col2: Color = OrderSys.KINDS[order_kind].color if order_kind != "cancel" else Color(1, 0.3, 0.3)
		if _selecting:
			var g = grid_f(get_global_mouse_position())
			var b = Vector2i(floori(g.x), floori(g.y))
			var lo = Vector2i(mini(_sel_a.x, b.x), mini(_sel_a.y, b.y))
			var hi = Vector2i(maxi(_sel_a.x, b.x), maxi(_sel_a.y, b.y))
			var poly2 = _cell_poly(Rect2i(lo, hi - lo + Vector2i(1, 1)))
			o.draw_colored_polygon(poly2, Color(col2.r, col2.g, col2.b, 0.25))
			o.draw_polyline(poly2 + PackedVector2Array([poly2[0]]), col2, 2.5)
		else:
			var poly3 = _cell_poly(Rect2i(_hover, Vector2i(1, 1)))
			o.draw_polyline(poly3 + PackedVector2Array([poly3[0]]), col2, 2.0)

func _draw_layout() -> void:
	if sect == null: return
	_draw_orders()
	if mode == "" or mode == "orders": return
	var o = _overlay
	var center = _hover if _hover.x > -90 else Territory.HOME
	var r = 15
	var lo = Vector2i(maxi(0, center.x - r), maxi(0, center.y - r))
	var hi = Vector2i(mini(Territory.SIZE, center.x + r), mini(Territory.SIZE, center.y + r))
	for x in range(lo.x, hi.x + 1):
		o.draw_line(iso(Vector2(x, lo.y)), iso(Vector2(x, hi.y)), Color(1, 1, 1, 0.12), 1.0)
	for y in range(lo.y, hi.y + 1):
		o.draw_line(iso(Vector2(lo.x, y)), iso(Vector2(hi.x, y)), Color(1, 1, 1, 0.12), 1.0)
	# ช่องที่สร้างไม่ได้ (ป่า/หิน/น้ำ) ทาแดงจาง
	for x in range(lo.x, hi.x):
		for y in range(lo.y, hi.y):
			if not Territory.buildable(sect, Vector2i(x, y)):
				o.draw_colored_polygon(_cell_poly(Rect2i(x, y, 1, 1)), Color(0.9, 0.2, 0.15, 0.16))
	for inst in sect.structures:
		var col = Color(1, 0.9, 0.35, 0.95) if inst.uid == carry else Color(1, 1, 1, 0.4)
		var poly = _cell_poly(BuildingDB.rect_of(inst))
		o.draw_polyline(poly + PackedVector2Array([poly[0]]), col, 3.0 if inst.uid == carry else 1.2)
	var type = _ghost_type()
	if type != "":
		var ignore = carry if mode == "move" else ""
		var err = BuildingDB.can_place(sect, type, _hover, ignore)
		var ok = err == ""
		var size: Vector2i = BuildingDB.BUILDINGS[type].size
		o.draw_colored_polygon(_cell_poly(Rect2i(_hover, size)), Color(0.3, 1, 0.4, 0.45) if ok else Color(1, 0.25, 0.2, 0.5))
		var font = ThemeDB.fallback_font
		var text = BuildingDB.BUILDINGS[type].name + ("" if ok else " ✗ " + err)
		var tp = iso(Vector2(_hover) + Vector2(size) / 2.0) + Vector2(-60, -8)
		o.draw_string_outline(font, tp, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(0, 0, 0, 0.8))
		o.draw_string(font, tp, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1))

func _cell_poly(r: Rect2i) -> PackedVector2Array:
	var p = Vector2(r.position)
	var sz = Vector2(r.size)
	return PackedVector2Array([iso(p), iso(p + Vector2(sz.x, 0)), iso(p + sz), iso(p + Vector2(0, sz.y))])

# ── คลิก ──

func pick(world_pos: Vector2) -> void:
	for d in _walkers:
		var w: Node2D = _walkers[d]
		if w.visible and world_pos.distance_to(w.position + Vector2(0, -18)) < 16:
			disciple_clicked.emit(d)
			return
	var inst = _inst_at(world_pos)
	if not inst.is_empty(): building_clicked.emit(inst.uid)

# ══════════════════════════════════════════
# วาดตึก
# ══════════════════════════════════════════

func _diamond(center: Vector2, hw: float, hh: float) -> PackedVector2Array:
	return PackedVector2Array([center + Vector2(-hw, 0), center + Vector2(0, -hh), center + Vector2(hw, 0), center + Vector2(0, hh)])

func _draw_building(node: Node2D) -> void:
	var inst = sect.instance(node.get_meta("uid"))
	if inst.is_empty(): return
	var b = BuildingDB.BUILDINGS[inst.type]
	var lv = int(inst.level)
	var site: Dictionary = inst.site
	var font = ThemeDB.fallback_font
	var fw = (b.size.x + b.size.y) * TW / 4.0
	var fh = (b.size.x + b.size.y) * TH / 4.0
	var label = b.name
	var progress = 1.0
	if not site.is_empty():
		progress = clamp(site.work / site.required, 0.0, 1.0)
	# ฐานตึก
	if inst.type not in ["campfire", "farm"]:
		node.draw_colored_polygon(_diamond(Vector2.ZERO, fw, fh), Color(0.62, 0.58, 0.5, 0.9))
	var label_y = -40.0
	match inst.type:
		"training_ground":
			_draw_plaza(node, lv, fw, fh)
		"sect_formation":
			_draw_altar(node, lv, fw, fh)
			label_y = -64.0
		"campfire":
			_draw_campfire(node, lv)
			label_y = -48.0
		"farm":
			_draw_farm(node, lv, fw, fh)
			label_y = -22.0
		"watchtower":
			_draw_tower(node, lv)
			label_y = -92.0
		"lumber_camp":
			_draw_logs(node, fw, fh)
			_draw_box(node, 22.0 + lv * 2.0, b.roof, lv > 0, fw * 0.55, fh * 0.55)
			label_y = -64.0
		"quarry":
			_draw_rocks(node, fw, fh)
			label_y = -34.0
		_:
			var height = 26.0 + min(lv, 8) * 4.0
			if lv == 0: height = 26.0 * progress
			_draw_box(node, height, b.roof, lv > 0, fw * 0.8, fh * 0.8)
			label_y = -height - (36.0 if lv > 0 else 8.0)
	if not site.is_empty():
		# นั่งร้านไม้ + หลอดความคืบหน้า
		for x in [-fw * 0.7, -fw * 0.25, fw * 0.25, fw * 0.7]:
			node.draw_line(Vector2(x, 14 - abs(x) * 0.25), Vector2(x, -70), Color(0.6, 0.45, 0.25), 2.0)
		node.draw_line(Vector2(-fw * 0.75, -50), Vector2(fw * 0.75, -50), Color(0.6, 0.45, 0.25), 2.0)
		node.draw_rect(Rect2(-40, -96, 80, 8), Color(0.1, 0.08, 0.06))
		node.draw_rect(Rect2(-40, -96, 80 * progress, 8), Color(0.95, 0.75, 0.3))
		label = "%s (กำลังสร้าง %d%%)" % [b.name, int(progress * 100)]
		label_y = -104.0
	elif lv > 0:
		label = "%s Lv.%d" % [b.name, lv]
		var crew = BuildingDB.post_members(sect, inst.uid).size()
		var slots = BuildingDB.post_slots(sect, inst.uid)
		if slots > 0: label += "  [%d/%d]" % [crew, slots]
	_label(node, font, label, Vector2(0, label_y), Color(1, 0.95, 0.8))
	# ไฟไหม้
	if sect.fires.has(inst.uid):
		var t = Time.get_ticks_msec() / 1000.0
		var fi: float = sect.fires[inst.uid]
		for i in 5:
			var x = -fw * 0.5 + i * fw * 0.25
			var h = (18 + fi * 30) * (0.7 + 0.3 * sin(t * 9.0 + i * 1.7))
			node.draw_colored_polygon(PackedVector2Array([Vector2(x - 8, -20), Vector2(x, -20 - h), Vector2(x + 8, -20)]), Color(1, 0.45 + 0.2 * sin(t * 7 + i), 0.1, 0.85))
		_label(node, font, "ไฟไหม้! %d%%" % int(fi * 100), Vector2(0, label_y - 16), Color(1, 0.4, 0.3))

func _label(node: Node2D, font: Font, text: String, pos: Vector2, color: Color) -> void:
	var size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
	node.draw_string_outline(font, pos - Vector2(size.x / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, Color(0, 0, 0, 0.8))
	node.draw_string(font, pos - Vector2(size.x / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)

## กล่องตึก isometric + หลังคาจีนปลายงอน (hw/hh = ครึ่งความกว้าง/ลึกของตัวตึก)
func _draw_box(node: Node2D, h: float, roof: Color, finished: bool, hw: float, hh: float) -> void:
	var wall = Color(0.85, 0.8, 0.7)
	node.draw_colored_polygon(PackedVector2Array([Vector2(-hw, 0), Vector2(0, hh), Vector2(0, hh - h), Vector2(-hw, -h)]), wall.darkened(0.15))
	node.draw_colored_polygon(PackedVector2Array([Vector2(0, hh), Vector2(hw, 0), Vector2(hw, -h), Vector2(0, hh - h)]), wall.darkened(0.3))
	for x in [-hw, 0.0, hw]:
		var y = hh if x == 0.0 else 0.0
		node.draw_line(Vector2(x, y), Vector2(x, y - h), Color(0.6, 0.15, 0.12), 3.0)
	if not finished: return
	var glow = Color(1, 0.8, 0.35) if is_night() else Color(0.25, 0.18, 0.12)
	node.draw_colored_polygon(PackedVector2Array([Vector2(hw * 0.35, hh * 0.65), Vector2(hw * 0.6, hh * 0.4), Vector2(hw * 0.6, hh * 0.4 - h * 0.6), Vector2(hw * 0.35, hh * 0.65 - h * 0.6)]), Color(0.3, 0.15, 0.1))
	node.draw_colored_polygon(PackedVector2Array([Vector2(-hw * 0.7, hh * 0.3 - h * 0.35), Vector2(-hw * 0.4, hh * 0.6 - h * 0.35), Vector2(-hw * 0.4, hh * 0.6 - h * 0.7), Vector2(-hw * 0.7, hh * 0.3 - h * 0.7)]), glow)
	var top = -h
	var apex = Vector2(0, top - 30)
	var l = Vector2(-hw - 12, top + 2)
	var f = Vector2(0, top + hh + 10)
	var r = Vector2(hw + 12, top + 2)
	node.draw_colored_polygon(PackedVector2Array([l, f, apex]), roof)
	node.draw_colored_polygon(PackedVector2Array([f, r, apex]), roof.darkened(0.25))
	node.draw_line(apex, f, roof.lightened(0.25), 2.0)
	node.draw_line(l, l + Vector2(-8, -9), roof.darkened(0.3), 3.0)
	node.draw_line(r, r + Vector2(8, -9), roof.darkened(0.3), 3.0)
	node.draw_line(f, f + Vector2(0, 4), roof.darkened(0.3), 3.0)

func _draw_plaza(node: Node2D, lv: int, fw: float, fh: float) -> void:
	node.draw_colored_polygon(_diamond(Vector2.ZERO, fw * 0.95, fh * 0.95), Color(0.78, 0.74, 0.64))
	node.draw_colored_polygon(_diamond(Vector2.ZERO, fw * 0.6, fh * 0.6), Color(0.7, 0.66, 0.56))
	for i in clampi(lv + 1, 1, 4):
		var p = Vector2(-fw * 0.5 + i * fw * 0.3, -6 + (i % 2) * 10)
		node.draw_line(p, p + Vector2(0, -22), Color(0.45, 0.3, 0.18), 4.0)
		node.draw_line(p + Vector2(-8, -16), p + Vector2(8, -16), Color(0.45, 0.3, 0.18), 3.0)
		node.draw_circle(p + Vector2(0, -24), 4, Color(0.5, 0.35, 0.2))

func _draw_altar(node: Node2D, lv: int, fw: float, fh: float) -> void:
	var t = Time.get_ticks_msec() / 1000.0
	node.draw_colored_polygon(_diamond(Vector2.ZERO, fw * 0.7, fh * 0.7), Color(0.5, 0.48, 0.52))
	node.draw_rect(Rect2(-8, -40, 16, 40), Color(0.45, 0.42, 0.5))
	if lv > 0:
		node.draw_circle(Vector2(0, -46), 8 + sin(t * 3.0) * 1.5, Color(0.75, 0.55, 1.0, 0.8))
		node.draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.5))
		node.draw_arc(Vector2.ZERO, 50, t, t + PI * 1.5, 24, Color(0.75, 0.55, 1.0, 0.6), 2.0)
		node.draw_set_transform(Vector2.ZERO)

func _draw_campfire(node: Node2D, lv: int) -> void:
	var t = Time.get_ticks_msec() / 1000.0
	node.draw_colored_polygon(_diamond(Vector2.ZERO, 14, 7), Color(0.35, 0.3, 0.27))
	for a in [-0.5, 0.5, 0.0]:
		node.draw_line(Vector2(-10, 3) .rotated(a), Vector2(10, -3).rotated(a), Color(0.4, 0.27, 0.15), 3.0)
	if lv > 0:
		for i in 3:
			var h = (16 + lv * 3) * (0.7 + 0.3 * sin(t * 9.0 + i * 2.1))
			var x = (i - 1) * 5.0
			node.draw_colored_polygon(PackedVector2Array([Vector2(x - 5, -2), Vector2(x, -2 - h), Vector2(x + 5, -2)]), Color(1, 0.5 + 0.2 * sin(t * 6 + i), 0.12, 0.9))
		node.draw_circle(Vector2(0, -8), 4, Color(1, 0.9, 0.5, 0.7))

func _draw_farm(node: Node2D, lv: int, fw: float, fh: float) -> void:
	node.draw_colored_polygon(_diamond(Vector2.ZERO, fw, fh), Color(0.42, 0.33, 0.22, 0.9))
	var done = lv > 0
	for row in 5:
		var y = -fh * 0.7 + row * fh * 0.35
		var span = fw * (1.0 - abs(y) / fh) * 0.85
		node.draw_line(Vector2(-span, y), Vector2(span, y), Color(0.3, 0.22, 0.14), 3.0)
		if done:
			for k in 6:
				var x = -span + k * span * 0.4
				node.draw_circle(Vector2(x, y - 3), 3.2, Color(0.35, 0.72, 0.38))

func _draw_tower(node: Node2D, lv: int) -> void:
	node.draw_colored_polygon(_diamond(Vector2.ZERO, 16, 8), Color(0.4, 0.34, 0.28))
	for x in [-10, 10]:
		node.draw_line(Vector2(x, 2), Vector2(x * 0.6, -58), Color(0.45, 0.32, 0.2), 4.0)
	node.draw_rect(Rect2(-14, -66, 28, 12), Color(0.5, 0.36, 0.22))
	node.draw_colored_polygon(PackedVector2Array([Vector2(-18, -66), Vector2(0, -82), Vector2(18, -66)]), Color(0.45, 0.2, 0.15))

func _draw_logs(node: Node2D, fw: float, fh: float) -> void:
	for i in 4:
		var p = Vector2(-fw * 0.6 + i * 9, fh * 0.35 - i * 3)
		node.draw_line(p, p + Vector2(18, 7), Color(0.5, 0.35, 0.2), 5.0)
		node.draw_circle(p + Vector2(18, 7), 2.6, Color(0.78, 0.62, 0.4))

func _draw_rocks(node: Node2D, fw: float, fh: float) -> void:
	for i in 5:
		var p = Vector2(-fw * 0.5 + i * fw * 0.25, (i % 2) * fh * 0.35 - fh * 0.1)
		node.draw_colored_polygon(PackedVector2Array([p + Vector2(-9, 0), p + Vector2(-3, -12), p + Vector2(8, -9), p + Vector2(11, 0)]), Color(0.55, 0.53, 0.5))
		node.draw_line(p + Vector2(-3, -12), p + Vector2(1, 0), Color(0.4, 0.38, 0.36), 1.5)
