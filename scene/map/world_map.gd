extends Node2D

## แผนที่โลก "พิภพโลหิตชาด": 5 มณฑล + 6 ดินแดนชายขอบ วาดลง TileMapLayer (ดู WorldGen)
## สถานที่และสำนักต่างๆ อยู่ตามพิกัดในตำนาน วงสีรอบสถานที่ = ขั้วอำนาจที่ครอบครอง
## ศิษย์ที่ออกเดินทางเป็นตัวละครจิ๋วเดินไปตามเส้นทางแบบเรียลไทม์


var sect: SectData
var sect_manager: SectManager
var world: WorldGen
var selected_id: String = ""
## ศิษย์ที่ถูกติ๊กเลือกไว้สำหรับส่งออกไป
var _picked: Array[DiscipleData] = []

var _dragging := false
var _drag_moved := 0.0
## DiscipleData -> Node2D (ตัวละครจิ๋วบนแผนที่)
var _travelers := {}

func _ready() -> void:
	sect = GlobalGame.current_sect
	if sect == null:
		get_tree().change_scene_to_file.call_deferred("res://scene/test_sect.tscn")
		return
	sect_manager = GlobalGame.sect_manager
	GlobalGame.clock_enabled = true
	GlobalGame.day_changed.connect(func(_d): _refresh())
	world = WorldGen.for_sect(sect)

	_build_tilemap()
	%Overlay.draw.connect(_draw_overlay)
	var cam: Camera2D = %Camera
	cam.limit_left = 0
	cam.limit_top = -60
	cam.limit_right = WorldGen.WIDTH * WorldGen.TILE + 360
	cam.limit_bottom = WorldGen.HEIGHT * WorldGen.TILE
	cam.position = world.poi_world_pos("sect")

	%BackButton.pressed.connect(_on_back_button_pressed)
	%PlayButton.pressed.connect(func(): GlobalGame.paused = not GlobalGame.paused)
	%SpeedButton.pressed.connect(GlobalGame.cycle_speed)
	%SeedLabel.text = "Seed: %d" % sect.world_seed
	_refresh()
	_on_location_clicked("sect")

# ── วาดภูมิประเทศลง TileMapLayer ──

func _build_tilemap() -> void:
	var tileset = TileSet.new()
	tileset.tile_size = Vector2i(WorldGen.TILE, WorldGen.TILE)
	var source = TileSetAtlasSource.new()
	source.texture = ArtGen.make_tile_atlas()
	source.texture_region_size = Vector2i(WorldGen.TILE, WorldGen.TILE)
	for i in ArtGen.BIOME_COLORS.size() * ArtGen.VARIANTS:
		source.create_tile(Vector2i(i, 0))
	tileset.add_source(source, 0)
	var layer: TileMapLayer = %Terrain
	layer.tile_set = tileset
	for y in WorldGen.HEIGHT:
		for x in WorldGen.WIDTH:
			var cell = Vector2i(x, y)
			var variant = abs(hash(Vector3i(x, y, world.world_seed))) % ArtGen.VARIANTS
			layer.set_cell(cell, 0, Vector2i(world.biome_at(cell) * ArtGen.VARIANTS + variant, 0))

# ── เวลาเรียลไทม์ ──

func _exit_tree() -> void:
	GlobalGame.clock_enabled = false

## เวลาเดินจากนาฬิกากลาง (GlobalGame) เหมือนหน้าสำนัก
func _process(_delta: float) -> void:
	%PlayButton.text = "เดินเวลา" if GlobalGame.paused else "หยุดเวลา"
	%SpeedButton.text = "ความเร็ว x%d" % GlobalGame.get_speed()
	%DayLabel.text = "%s  |  เงิน %d" % [GlobalGame.get_clock_text(), sect.money]
	_update_travelers()
	%Overlay.queue_redraw()

func _update_travelers() -> void:
	var frac = GlobalGame.get_day_fraction()
	var t = Time.get_ticks_msec() / 1000.0
	var stack := {}
	for d in sect.disciples:
		if d.status != DiscipleData.DiscipleStatus.MISSION:
			continue
		if not _travelers.has(d):
			_travelers[d] = _make_traveler(d)
		var node: Node2D = _travelers[d]
		var moving = ExpeditionSys.is_moving(d)
		var pos = WorldGen.cell_to_world(ExpeditionSys.get_map_position(sect, d, frac if moving else 0.0))
		# ศิษย์หลายคนอยู่จุดเดียวกัน ให้ยืนเรียงกัน
		var key = Vector2i(pos / 6.0)
		var n = stack.get(key, 0)
		stack[key] = n + 1
		pos += Vector2(n * 10, 0)
		var sprite: Sprite2D = node.get_node("Sprite")
		if pos.x < node.position.x - 0.01: sprite.flip_h = true
		elif pos.x > node.position.x + 0.01: sprite.flip_h = false
		node.position = pos
		# เดินกระเด้งเบาๆ ตอนเวลากำลังเดิน
		sprite.position.y = -12 - (abs(sin(t * 9.0 + n)) * 2.5 if moving and not GlobalGame.paused else 0.0)
	for d in _travelers.keys():
		if d.status != DiscipleData.DiscipleStatus.MISSION:
			_travelers[d].queue_free()
			_travelers.erase(d)

func _make_traveler(d: DiscipleData) -> Node2D:
	var node = Node2D.new()
	var sprite = Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = ArtGen.get_figure(d)
	sprite.scale = Vector2(0.5, 0.5)
	node.add_child(sprite)
	var label = Label.new()
	label.text = d.disciple_name
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", Color(0.1, 0.06, 0.03))
	label.add_theme_color_override("font_outline_color", Color(0.95, 0.9, 0.8))
	label.add_theme_constant_override("outline_size", 3)
	label.position = Vector2(-20, -40)
	node.add_child(label)
	%Travelers.add_child(node)
	return node

# ── วาดสถานที่และเส้นทาง ──

func _draw_overlay() -> void:
	var o: Node2D = %Overlay
	var font = ThemeDB.fallback_font
	var t = Time.get_ticks_msec() / 1000.0

	# เส้นทางที่ศิษย์กำลังเดิน + เส้นทางตัวอย่างไปยังสถานที่ที่เลือก
	var drawn := {}
	for d in sect.disciples:
		if d.status == DiscipleData.DiscipleStatus.MISSION and not drawn.has(d.mission_target):
			drawn[d.mission_target] = true
			_draw_route(o, d.mission_target, Color(0.55, 0.15, 0.1, 0.55))
	if selected_id != "" and selected_id != "sect" and not selected_id.begins_with("site:") and not drawn.has(selected_id):
		_draw_route(o, selected_id, Color(0.2, 0.15, 0.1, 0.45))

	# ชื่อภูมิภาค (5 มณฑล 6 ดินแดนชายขอบ)
	for rid in WorldDB.REGIONS:
		var r = WorldDB.REGIONS[rid]
		var rp = WorldGen.cell_to_world(Vector2(r.label))
		var rs = font.get_string_size(r.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
		var rcol = Color(0.45, 0.12, 0.08, 0.55) if r.kind == "province" else Color(0.1, 0.2, 0.35, 0.55)
		o.draw_string_outline(font, rp - Vector2(rs.x / 2.0, 0), r.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 5, Color(0.95, 0.9, 0.78, 0.5))
		o.draw_string(font, rp - Vector2(rs.x / 2.0, 0), r.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, rcol)

	for id in WorldDB.NODES:
		var n = WorldDB.NODES[id]
		var p = world.poi_world_pos(id)
		var col: Color = WorldDB.TYPE_COLORS[n.type]
		var ink = Color(0.15, 0.1, 0.06)
		var closed = n.type == WorldDB.NodeType.SECRET_REALM and not WorldDB.is_secret_realm_open(sect.current_day)
		if closed: col = Color(0.45, 0.42, 0.45)
		# อาณาเขต: วงสีของสำนักที่ยึดครอง
		var owner: String = sect.node_owner.get(id, "")
		if owner != "":
			var oc: Color = Color(1, 0.85, 0.3) if owner == "player" else FactionDB.FACTIONS[owner].color
			o.draw_circle(p, 24, Color(oc, 0.18))
			o.draw_arc(p, 24, 0, TAU, 32, Color(oc, 0.8), 2.0)
		if id == selected_id:
			o.draw_arc(p, 15, 0, TAU, 32, Color(0.75, 0.1, 0.1), 2.5)
		match n.type:
			WorldDB.NodeType.SECT, WorldDB.NodeType.RIVAL_SECT, WorldDB.NodeType.GREAT_SECT:
				# ศาลาหลังคาโค้ง (สีตามขั้วอำนาจเจ้าของ)
				if n.has("faction"): col = FactionDB.FACTIONS[n.faction].color
				o.draw_rect(Rect2(p + Vector2(-7, -3), Vector2(14, 10)), col)
				o.draw_colored_polygon(PackedVector2Array([p + Vector2(-11, -2), p + Vector2(0, -11), p + Vector2(11, -2)]), ink)
				o.draw_rect(Rect2(p + Vector2(-2, 2), Vector2(4, 5)), ink)
			WorldDB.NodeType.CITY:
				# กำแพงเมืองและประตู
				o.draw_rect(Rect2(p + Vector2(-10, -7), Vector2(20, 14)), col)
				o.draw_rect(Rect2(p + Vector2(-10, -7), Vector2(20, 14)), ink, false, 1.5)
				for i in 4:
					o.draw_rect(Rect2(p + Vector2(-10 + i * 6, -10), Vector2(3, 3)), ink)
				o.draw_rect(Rect2(p + Vector2(-3, 0), Vector2(6, 7)), ink)
				# ธงของขั้วอำนาจที่ตั้งสำนักงานใหญ่ในเมือง
				var hq = WorldDB.get_city_hq(id)
				for i in hq.size():
					o.draw_circle(p + Vector2(-10 + i * 5, -14), 2.2, FactionDB.FACTIONS[hq[i]].color)
			WorldDB.NodeType.WILD:
				o.draw_circle(p + Vector2(0, -3), 7, col.darkened(0.2))
				o.draw_rect(Rect2(p + Vector2(-1.5, 3), Vector2(3, 5)), ink)
			WorldDB.NodeType.DUNGEON:
				o.draw_circle(p, 9, ink)
				o.draw_circle(p + Vector2(0, 2), 5, col)
			WorldDB.NodeType.SECRET_REALM:
				var r = 9.0 + (0.0 if closed else sin(t * 3.0) * 2.0)
				if not closed:
					o.draw_circle(p, r + 6, Color(col, 0.25))
				o.draw_circle(p, r, col)
				o.draw_arc(p, r * 0.55, t * 2.0, t * 2.0 + PI * 1.4, 16, Color(1, 1, 1, 0.8), 2.0)
		# จุดสำคัญที่รู้แล้ว: เพชรสีตามชนิด (เหลือง/ฟ้า/ม่วง) ยังไม่ได้ = เต็ม ได้แล้ว = โปร่ง
		var mk = 0
		for l in LandmarkSys.at_node(sect, id):
			var mp = p + Vector2(13 + mk * 9, -13)
			var mc = LandmarkSys.kind_color(l.kind)
			var pts = PackedVector2Array([mp + Vector2(0, -5), mp + Vector2(4, 0), mp + Vector2(0, 5), mp + Vector2(-4, 0)])
			if l.claimed or (l.kind == "ore" and sect.node_owner.get(id, "") == "player"):
				o.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), mc, 1.5)
			else:
				o.draw_colored_polygon(pts, mc)
			mk += 1
		var label = n.name
		var fs = 11 if n.type in [WorldDB.NodeType.CITY, WorldDB.NodeType.SECT, WorldDB.NodeType.GREAT_SECT] else 9
		var size = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var lp = p + Vector2(-size.x / 2.0, 22)
		o.draw_string_outline(font, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0.95, 0.9, 0.78))
		o.draw_string(font, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)

	# จุดตั้งสำนักทางเลือก (Start Sites)
	for s in WorldDB.START_SITES:
		if s.id == sect.start_site:
			continue
		var sp = WorldGen.cell_to_world(Vector2(s.cell))
		var site_col = Color(0.85, 0.72, 0.3)
		o.draw_circle(sp, 13, Color(site_col, 0.2))
		o.draw_arc(sp, 13, 0, TAU, 24, site_col, 1.5)
		o.draw_rect(Rect2(sp + Vector2(-6, -3), Vector2(12, 8)), site_col)
		o.draw_colored_polygon(PackedVector2Array([sp + Vector2(-9, -2), sp + Vector2(0, -10), sp + Vector2(9, -2)]), ink)
		if selected_id == "site:" + s.id:
			o.draw_arc(sp, 17, 0, TAU, 32, Color(0.85, 0.2, 0.2), 2.5)
		var s_label = "[ที่ตั้ง] " + s.name
		var s_size = font.get_string_size(s_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9)
		var s_lp = sp + Vector2(-s_size.x / 2.0, 20)
		o.draw_string_outline(font, s_lp, s_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, 3, Color(0.95, 0.9, 0.78))
		o.draw_string(font, s_lp, s_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.25, 0.15, 0.05))

func _draw_route(o: Node2D, target_id: String, color: Color) -> void:
	var pts = PackedVector2Array()
	for c in ExpeditionSys.get_route(sect, target_id).points:
		pts.append(WorldGen.cell_to_world(c))
	if pts.size() >= 2:
		o.draw_polyline(pts, color, 2.0)

# ── กล้อง: ลากเพื่อเลื่อน / ล้อเมาส์เพื่อซูม / คลิกเลือกสถานที่ ──

func _unhandled_input(event: InputEvent) -> void:
	var cam: Camera2D = %Camera
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			cam.zoom = (cam.zoom * 1.1).clamp(Vector2(0.7, 0.7), Vector2(3.5, 3.5))
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			cam.zoom = (cam.zoom / 1.1).clamp(Vector2(0.7, 0.7), Vector2(3.5, 3.5))
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_dragging = true
				_drag_moved = 0.0
			else:
				_dragging = false
				if _drag_moved < 6.0:
					_select_at(get_global_mouse_position())
	elif event is InputEventMouseMotion and _dragging:
		cam.position -= event.relative / cam.zoom
		_drag_moved += event.relative.length()

func _select_at(world_pos: Vector2) -> void:
	var best = ""
	var best_d = 20.0
	for id in WorldDB.NODES:
		var dist = world.poi_world_pos(id).distance_to(world_pos)
		if dist < best_d:
			best_d = dist
			best = id
	for s in WorldDB.START_SITES:
		if s.id == sect.start_site:
			continue
		var dist = WorldGen.cell_to_world(Vector2(s.cell)).distance_to(world_pos)
		if dist < best_d:
			best_d = dist
			best = "site:" + s.id
	if best != "":
		_on_location_clicked(best)

# ── แผงข้อมูลสถานที่ ──

func _refresh() -> void:
	%DayLabel.text = "วันที่ %d  |  เงิน %d" % [sect.current_day, sect.money]
	if selected_id != "":
		_show_info(selected_id)

func _on_location_clicked(id: String) -> void:
	selected_id = id
	_picked.clear()
	_show_info(id)

func _show_info(id: String) -> void:
	var c: VBoxContainer = %InfoContent
	UIKit.clear(c)
	if id.begins_with("site:"):
		_show_site_info(id.trim_prefix("site:"))
		return
	var n = WorldDB.NODES[id]
	c.add_child(UIKit.label(n.name, 22, WorldDB.TYPE_COLORS[n.type]))
	var region = world.poi_region(id)
	c.add_child(UIKit.label("[%s] %s · ภูมิประเทศ: %s" % [WorldDB.TYPE_NAMES[n.type], WorldDB.get_region_name(region), WorldGen.BIOME_NAMES[world.biome_at(world.poi[id])]], 14, WuxiaTheme.PAPER_DIM))
	c.add_child(UIKit.label(n.desc, 15))
	var route = ExpeditionSys.get_route(sect, id)
	if id != "sect":
		c.add_child(UIKit.label("ระยะเดินทางจากสำนัก: %d วัน (%d ช่อง)" % [route.days, route.points.size()], 15, WuxiaTheme.BRONZE))

	var owner: String = sect.node_owner.get(id, "")
	if owner != "" and id != "sect":
		var owner_name = "สำนักเรา" if owner == "player" else FactionDB.FACTIONS[owner].name
		var rel = "" if owner == "player" else " (ความสัมพันธ์ %+d%s)" % [sect.factions[owner].relation, ", กำลังทำสงคราม" if sect.factions[owner].war else ""]
		c.add_child(UIKit.label("ผู้ครอบครอง: %s%s" % [owner_name, rel], 14, Color(1, 0.85, 0.4) if owner == "player" else FactionDB.FACTIONS[owner].color))
	if sect.city_lords.has(id):
		var lord = sect.city_lords[id]
		c.add_child(UIKit.label("เจ้าเมือง: %s (คนของ%s) · ความรุ่งเรือง x%.2f · ราคาสินค้า x%.2f" % [lord.name, FactionDB.FACTIONS[lord.faction].name, sect.get_node_yield(id), n.get("price_mult", 1.0) * sect.get_city_price_factor(id)], 14, WuxiaTheme.BRONZE))
	if n.has("enemies"):
		var names = n.enemies.map(func(e): return "%s (พลัง ~%d)" % [EnemyDB.ENEMIES[e].name, EnemyDB.get_power(e)])
		c.add_child(UIKit.label("ศัตรู: " + ", ".join(names), 14, Color(1, 0.55, 0.5)))
	if n.has("gather"):
		c.add_child(UIKit.label("วัตถุดิบ: %s · ผลผลิต x%.2f (สุ่มตาม Seed/เหตุการณ์)" % [", ".join(n.gather.keys().map(func(m): return MaterialDB.get_material_name(m))), sect.get_node_yield(id)], 14, Color(0.55, 0.9, 0.55)))

	# จุดสำคัญ (แร่/คัมภีร์/ของวิเศษ) ที่ผู้เล่นรู้แล้ว และตัวละครมีชื่อที่รู้ที่อยู่
	var marks = LandmarkSys.at_node(sect, id)
	var folks = RosterSys.at_node(sect, id).filter(func(e): return e.known)
	if not marks.is_empty() or not folks.is_empty():
		c.add_child(UIKit.section("สิ่งที่น่าสนใจ"))
		for l in marks:
			c.add_child(UIKit.label("◆ %s: %s — %s" % [LandmarkSys.kind_name(l.kind), l.name, LandmarkSys.status_text(sect, l)], 14, LandmarkSys.kind_color(l.kind)))
		for e in folks:
			c.add_child(UIKit.label("◇ %s %s (ความรู้สึก %+d) — เดินเข้าไปคุยเพื่อชวนเข้าสำนัก" % [e.title, e.name, e.opinion], 14, Color(1, 0.85, 0.4)))

	# ศิษย์ที่อยู่ ณ ที่นี้
	var here = ExpeditionSys.get_stationed_at(sect, id)
	if not here.is_empty():
		c.add_child(UIKit.section("ศิษย์ที่อยู่ที่นี่"))
		for d in here:
			c.add_child(UIKit.row(d.disciple_name + " - " + d.get_status_text(), [
				UIKit.button("เรียกกลับ", func():
					ExpeditionSys.recall(sect, d)
					_refresh(), d.mission_phase != "stationed")
			]))

	match n.type:
		WorldDB.NodeType.SECT:
			var cur_site = WorldDB.get_start_site(sect.start_site)
			c.add_child(UIKit.label("ที่ตั้งปัจจุบัน: %s (%s)" % [cur_site.name, WorldDB.get_region_name(cur_site.region)], 14, Color(1, 0.85, 0.4)))
			_add_travelers_summary(c)
			c.add_child(UIKit.section("ย้ายชัยภูมิที่ตั้งสำนัก"))
			c.add_child(UIKit.label("เลือกจุดตั้งสำนักอื่นเพื่อย้ายที่ตั้งสำนัก เส้นทางและการเดินทางจะอัปเดตทันที:", 13, WuxiaTheme.PAPER_DIM))
			for s in WorldDB.START_SITES:
				if s.id == sect.start_site:
					continue
				var target_id: String = s.id
				var rname = WorldDB.get_region_name(s.region)
				c.add_child(UIKit.row("%s (%s)" % [s.name, rname], [
					UIKit.button("ย้ายมาที่นี่", func(): _relocate_sect(target_id))
				]))
		WorldDB.NodeType.CITY:
			c.add_child(UIKit.button("เข้าสู่เมือง", func(): _enter_city(id), here.is_empty()))
			if here.is_empty():
				c.add_child(UIKit.label("ต้องส่งศิษย์ไปประจำที่เมืองก่อน จึงจะซื้อขาย/รับภารกิจ/ประมูลได้", 13, WuxiaTheme.PAPER_DIM))
			_add_picker(c, 3)
			c.add_child(UIKit.button("ส่งไปประจำที่เมือง (%d วัน)" % route.days, func(): _dispatch("station", id)))
			for fid in WorldDB.get_city_hq(id):
				_add_faction_section(c, fid, id)
		WorldDB.NodeType.WILD, WorldDB.NodeType.DUNGEON:
			_add_picker(c, 4)
			c.add_child(UIKit.button("ลงพื้นที่สำรวจ (บังคับศิษย์คนแรกเดินเอง ชนมอนสเตอร์ = ต่อสู้)", func(): _enter_field(id)))
			if owner != "player":
				var guard = "ผู้พิทักษ์ของ" + FactionDB.FACTIONS[owner].name if owner != "" else "สัตว์อสูรเจ้าถิ่น"
				c.add_child(UIKit.button("ยึดครองพื้นที่ (สู้กับ%s)" % guard, func(): _start_combat(id, "claim")))
			c.add_child(UIKit.button("ออกเก็บวัตถุดิบ (ไป %d + เก็บ %d + กลับ %d วัน)" % [route.days, ExpeditionSys.GATHER_WORK_DAYS, route.days], func(): _dispatch("gather", id)))
		WorldDB.NodeType.RIVAL_SECT, WorldDB.NodeType.GREAT_SECT:
			var fid_s: String = n.get("faction", "")
			var hostile_s = fid_s != "" and (sect.factions[fid_s].war or sect.factions[fid_s].relation < -40)
			c.add_child(UIKit.button("เดินเข้าสำนัก" + (" (ลอบเข้า — ถิ่นศัตรู)" if hostile_s else ""), func(): _enter_city(id), here.is_empty()))
			if here.is_empty():
				c.add_child(UIKit.label("ต้องส่งศิษย์ไปเยือน/ประจำที่สำนักนี้ก่อน จึงจะเดินเข้าไปคุยกับผู้คน ดูหอคัมภีร์ และซื้อตัวคนได้", 13, WuxiaTheme.PAPER_DIM))
			_add_picker(c, 4)
			c.add_child(UIKit.button("ส่งไปเยือน/ประจำที่สำนัก (%d วัน)" % route.days, func(): _dispatch("station", id)))
			_add_faction_section(c, fid_s, id)
		WorldDB.NodeType.SECRET_REALM:
			var day = sect.current_day
			var cycle = int(day / float(WorldDB.SECRET_REALM_INTERVAL))
			if not WorldDB.is_secret_realm_open(day):
				c.add_child(UIKit.label("ทางเข้าปิดสนิท จะเปิดอีกครั้งในอีก %d วัน" % WorldDB.days_until_secret_realm(day), 16, Color(0.8, 0.6, 1)))
			elif sect.last_secret_realm_cycle == cycle:
				c.add_child(UIKit.label("สำนักเราส่งทีมเข้าแดนลับรอบนี้ไปแล้ว", 16, Color(0.8, 0.6, 1)))
			else:
				c.add_child(UIKit.label("แดนลับเปิดอยู่! ปิดในอีก %d วัน\nต้องเดินทางให้ถึงก่อนปิด (ใช้ %d วัน)" % [WorldDB.days_until_secret_realm_closes(day), route.days], 16, Color(0.8, 0.6, 1)))
				_add_picker(c, WorldDB.SECRET_REALM_MAX_TEAM)
				c.add_child(UIKit.button("ส่งทีมหัวกะทิบุกแดนลับ", func(): _dispatch("secret_realm", id), route.days >= WorldDB.days_until_secret_realm_closes(day)))

## ข้อมูลขั้วอำนาจ + ปุ่มประลอง / บุกตี / ของกำนัล (ใช้ทั้งฐานที่มั่นและสำนักงานใหญ่ในเมือง)
func _add_faction_section(c: VBoxContainer, fid: String, node_id: String) -> void:
	var info = FactionDB.FACTIONS[fid]
	var f = sect.factions[fid]
	c.add_child(UIKit.section(info.name))
	c.add_child(UIKit.label("ฝ่าย: %s · แนวทาง%s%s" % [FactionDB.bloc_name(info.bloc), info.align, " · หนึ่งใน 8 สำนักใหญ่ (มีสิทธิ์โหวต)" if info.great else ""], 14, FactionDB.BLOCS[info.bloc].color))
	c.add_child(UIKit.label("%s%s" % [info.desc, ("\nประมุข/บุคคลสำคัญ: " + info.leader) if info.leader != "" else ""], 13, WuxiaTheme.PAPER_DIM))
	c.add_child(UIKit.label("พลังสำนัก %d · ศิษย์ทั่วไปพลังราว %d · อาณาเขต %d แห่ง · ความสัมพันธ์กับเรา %+d%s" % [f.power, FactionSys.squad_power(sect, fid), sect.node_owner.values().count(fid), f.relation, " (สงคราม!)" if f.war else ""], 14, FactionDB.ALIGN_COLORS[info.align]))
	var friends: Array[String] = []
	var foes: Array[String] = []
	for other in FactionDB.FACTIONS:
		if other == fid: continue
		var r = FactionSys.get_rel(sect, fid, other)
		if r >= 45: friends.append(FactionDB.FACTIONS[other].name)
		elif r <= -45: foes.append(FactionDB.FACTIONS[other].name)
	if not friends.is_empty(): c.add_child(UIKit.label("มิตร: " + ", ".join(friends.slice(0, 4)), 13, Color(0.6, 0.95, 0.6)))
	if not foes.is_empty(): c.add_child(UIKit.label("ศัตรู: " + ", ".join(foes.slice(0, 4)), 13, Color(1, 0.55, 0.5)))
	var row = HFlowContainer.new()
	row.add_child(UIKit.button("ประลองฉันมิตร", func(): _start_combat(node_id, "spar", fid), FactionSys.is_hostile(sect, fid)))
	row.add_child(UIKit.button("บุกตี (ต้องทำสงคราม)", func(): _start_combat(node_id, "siege", fid), not f.war))
	row.add_child(UIKit.button("ของกำนัล (%d)" % FactionSys.gift_cost(sect, fid), func():
		sect_manager.log_event(FactionSys.gift(sect, fid))
		_refresh(), sect.money < FactionSys.gift_cost(sect, fid)))
	c.add_child(row)

func _add_travelers_summary(c: VBoxContainer) -> void:
	c.add_child(UIKit.section("ศิษย์ที่อยู่นอกสำนัก"))
	var any = false
	for d in sect.disciples:
		if d.status == DiscipleData.DiscipleStatus.MISSION:
			any = true
			c.add_child(UIKit.label("%s: %s" % [d.disciple_name, d.get_status_text()], 14))
	if not any:
		c.add_child(UIKit.label("ทุกคนอยู่ในสำนัก", 14, WuxiaTheme.PAPER_DIM))

## รายการติ๊กเลือกศิษย์ที่ว่างอยู่ในสำนัก
func _add_picker(c: VBoxContainer, max_count: int) -> void:
	c.add_child(UIKit.section("เลือกศิษย์ (สูงสุด %d คน)" % max_count))
	var any = false
	var available = sect.disciples.filter(func(d): return d.is_available())
	available.sort_custom(func(a, b):
		if a.is_founder != b.is_founder: return a.is_founder
		return a.get_power_rating() > b.get_power_rating())
	for d in available:
		any = true
		var cb = CheckBox.new()
		var tag = "★ [เจ้าสำนัก / ผู้เล่น] " if d.is_founder else ""
		cb.text = "%s%s [%s] พลัง %d" % [tag, d.disciple_name, d.realm_name, d.get_power_rating()]
		if d.is_founder:
			cb.add_theme_color_override("font_color", Color(1, 0.88, 0.45))
		cb.button_pressed = _picked.has(d)
		cb.toggled.connect(func(on):
			if on and not _picked.has(d):
				if _picked.size() >= max_count:
					cb.set_pressed_no_signal(false)
					return
				_picked.append(d)
			elif not on:
				_picked.erase(d))
		c.add_child(cb)
	if not any:
		c.add_child(UIKit.label("ไม่มีศิษย์ที่ว่างอยู่ในสำนัก", 14, Color(1, 0.6, 0.5)))

func _dispatch(mission_type: String, target_id: String) -> void:
	if _picked.is_empty():
		_flash_message("ยังไม่ได้เลือกศิษย์!")
		return
	var names: Array[String] = []
	var days = 0
	for d in _picked:
		days = ExpeditionSys.dispatch(sect, d, mission_type, target_id)
		names.append(d.disciple_name)
	var verb = { "gather": "ออกเก็บวัตถุดิบที่", "station": "ไปประจำที่", "secret_realm": "บุก" }[mission_type]
	sect_manager.log_event("ส่ง %s %s%s (เดินทาง %d วัน)" % [", ".join(names), verb, WorldDB.NODES[target_id].name, days])
	_picked.clear()
	GlobalGame.save_game()
	GlobalGame.paused = false
	_refresh()

## type: hunt (ปราบปราม), claim (ยึดพื้นที่), spar (ประลอง), siege (บุกตีสำนัก)
func _start_combat(node_id: String, type: String = "hunt", target_faction: String = "") -> void:
	var fighters = _picked.filter(func(d): return not d.disabled)
	if fighters.is_empty():
		_flash_message("ยังไม่ได้เลือกศิษย์! (ศิษย์พิการออกรบไม่ได้)")
		return
	var n = WorldDB.NODES[node_id]
	var fid: String = target_faction if target_faction != "" else n.get("faction", "")
	var owner: String = sect.node_owner.get(node_id, "")
	GlobalGame.combat_allies.assign(fighters)
	GlobalGame.combat_enemies.clear()
	if type in ["spar", "siege"]:
		GlobalGame.combat_enemies.assign(FactionSys.make_enemies(sect, fid, 2 if type == "spar" else 3, type == "siege"))
	elif type == "claim" and owner != "" and owner != "player":
		fid = owner
		GlobalGame.combat_enemies.assign(FactionSys.make_enemies(sect, owner, 2, false))
	else:
		var pool: Array = n.enemies
		for i in randi_range(1, 3):
			GlobalGame.combat_enemies.append(EnemyDB.get_enemy(pool.pick_random()))
	GlobalGame.combat_context = { "type": type, "node": node_id, "faction": fid if fid != "" else owner }
	GlobalGame.combat_return_scene = "res://scene/map/world_map.tscn"
	GlobalGame.combat_bonus_money = 0
	GlobalGame.combat_bonus_task = ""
	GlobalGame.save_game()
	get_tree().change_scene_to_file(GlobalGame.COMBAT_SCENE)

## ลงพื้นที่สำรวจแบบเดินเอง (Overworld Encounters)
func _enter_field(id: String) -> void:
	var fighters = _picked.filter(func(d): return d.can_fight())
	if fighters.is_empty():
		var founder = sect.get_founder()
		if founder != null and founder.is_available() and founder.can_fight():
			fighters = [founder]
		else:
			_flash_message("ยังไม่ได้เลือกศิษย์! (ต้องมีศิษย์พร้อมรบอย่างน้อย 1 คน)")
			return
	# ให้เจ้าสำนัก (ตัวละครผู้เล่น) เป็นผู้นำแถวเสมอถ้าอยู่ในทีม
	for i in fighters.size():
		if fighters[i].is_founder:
			var f = fighters[i]
			fighters.remove_at(i)
			fighters.insert(0, f)
			break
	GlobalGame.field_node = id
	GlobalGame.field_team.assign(fighters)
	GlobalGame.field_state = {}
	GlobalGame.save_game()
	get_tree().change_scene_to_file("res://scene/map/field_scene.tscn")

func _enter_city(id: String) -> void:
	GlobalGame.selected_city_id = id
	GlobalGame.save_game()
	get_tree().change_scene_to_file("res://scene/map/city_scene.tscn")

func _flash_message(text: String) -> void:
	var l = UIKit.label(text, 18, Color(1, 0.5, 0.4))
	%InfoContent.add_child(l)
	%InfoContent.move_child(l, 0)
	get_tree().create_timer(2.0).timeout.connect(func(): if is_instance_valid(l): l.queue_free())

func _on_back_button_pressed() -> void:
	GlobalGame.save_game()
	get_tree().change_scene_to_file("res://scene/test_sect.tscn")

## แสดงข้อมูลจุดตั้งสำนักทางเลือก
func _show_site_info(site_id: String) -> void:
	var c: VBoxContainer = %InfoContent
	UIKit.clear(c)
	var s = WorldDB.get_start_site(site_id)
	c.add_child(UIKit.label(s.name, 22, Color(1.0, 0.85, 0.4)))
	var region_name = WorldDB.get_region_name(s.region)
	var cell_pos: Vector2i = s.cell
	var biome_name = WorldGen.BIOME_NAMES[world.biome_at(cell_pos)]
	c.add_child(UIKit.label("[จุดตั้งสำนักทางเลือก] %s · ภูมิประเทศ: %s" % [region_name, biome_name], 14, WuxiaTheme.PAPER_DIM))
	c.add_child(UIKit.label("ชัยภูมิยอดเขาและแหล่งน้ำธรรมชาติที่เหมาะสมแก่การตั้งสำนัก สามารถย้ายฐานที่มั่นของสำนักเรามายังจุดนี้ได้", 15))
	var route_to_site = world.astar.get_id_path(world.poi["sect"], cell_pos)
	c.add_child(UIKit.label("ระยะทางจากที่ตั้งเดิม: %d ช่อง" % route_to_site.size(), 14, WuxiaTheme.BRONZE))
	c.add_child(UIKit.section("ย้ายฐานที่มั่นสำนัก"))
	c.add_child(UIKit.label("เมื่อย้ายแล้ว แผนที่และเส้นทางเดินทางทั้งหมดจะอ้างอิงจากชัยภูมินี้ทันที", 13, WuxiaTheme.PAPER_DIM))
	c.add_child(UIKit.button("ย้ายสำนักมาที่นี่", func(): _relocate_sect(site_id)))

## ย้ายที่ตั้งสำนักแบบ Dynamic
func _relocate_sect(new_site_id: String) -> void:
	if sect.start_site == new_site_id:
		return
	var old_site = WorldDB.get_start_site(sect.start_site)
	var new_site = WorldDB.get_start_site(new_site_id)
	sect.start_site = new_site_id
	WorldGen.clear_cache()
	world = WorldGen.for_sect(sect)
	_build_tilemap()

	var cam: Camera2D = %Camera
	cam.position = world.poi_world_pos("sect")

	for d in _travelers.keys():
		if is_instance_valid(_travelers[d]):
			_travelers[d].queue_free()
	_travelers.clear()

	selected_id = "sect"
	_picked.clear()
	_refresh()
	%Overlay.queue_redraw()
	GlobalGame.save_game()
	if sect_manager != null:
		sect_manager.log_event("สำนักย้ายฐานที่มั่นจาก %s ไปยัง %s สำเร็จ!" % [old_site.name, new_site.name])
	_flash_message("ย้ายที่ตั้งสำนักมายัง %s สำเร็จ!" % new_site.name)
