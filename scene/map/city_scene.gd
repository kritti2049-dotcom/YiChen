extends Node2D

## ฉากเมืองแบบเดินสำรวจ (Interactive City Hub)
## - พื้นเมืองวาดด้วย TileMapLayer (ถนน ลาน แม่น้ำ กำแพง ตรอก) ผังต่างกันทุกเมือง (CityLayout + CityDB)
## - บังคับอวตาร (CityPlayer: CharacterBody2D) เดิน WASD / คลิกเดิน กล้องติดตาม
## - หน้าประตูอาคารและตัว NPC มี InteractableArea: เดินเข้าใกล้แล้วกด [E] (หรือคลิกปุ่ม) จึงเปิดหน้าต่างบริการ (CityServices)
## - แสงตามเวลา (DayNight) + PointLight2D ที่โคมไฟและหน้าต่างอาคาร
## - กลางวัน: ชาวเมือง นักเล่าข่าว สายลับ ผู้ว่าจ้างลับ จอมยุทธ์พเนจร เดินไปมา
## - กลางคืน: ทหารยามลาดตระเวน (กรวยสายตา + RayCast2D) ถ้าถูกจับได้ = ต่อสู้กับทหารหลวง
##   ถ้ารับสัญญาลอบสังหารไว้ เป้าหมายจะปรากฏที่ลานกลางเมือง ย่องไปให้ถึงตัวแล้วกด [F]

const CITIZEN_LINES = {
	"capital": ["ได้ยินว่าเหล่าขันทีกุมอำนาจในวังหลวงไว้หมดแล้ว", "งานประลองยุทธ์หลวงปีนี้คึกคักกว่าทุกปี", "อย่าออกนอกบ้านตอนกลางคืน หน่วยเหยี่ยวชาดจับคนไม่เลือกหน้า"],
	"trade": ["ราคาข้าวขึ้นอีกแล้ว...", "ขบวนคาราวานจากเจียงหนานเพิ่งมาถึง", "ศิษย์สำนักใหญ่ชอบมาดื่มที่โรงเตี๊ยมนั่น"],
	"jiangnan": ["ตระกูลหนานกงกับพยัคฆ์ใต้ยังไม่เลิกแค้นกัน", "เรือสินค้าแล่นขึ้นล่องแยงซีไม่ขาดสาย", "เงินทองในเจียงหนานไหลเหมือนสายน้ำ"],
	"frontier": ["ชนเผ่าทุ่งหญ้าบุกมาอีกแล้วที่ชายแดน", "ตระกูลหมิงคุ้มกันคาราวานไม่เคยพลาด", "ลมหนาวปีนี้มาเร็วผิดปกติ"],
	"south": ["อย่ากินอะไรที่คนแปลกหน้ายื่นให้", "ไอพิษในป่าลึกฆ่าคนได้ภายในคืนเดียว", "เผ่าแมงมุมโลหิตกลับมาแล้ว..."],
	"port": ["โจรสลัดเจียวอู๋ไห่ปล้นเรือหลวงอีกลำ", "ว่ากันว่ามีเกาะลึกลับซ่อนอยู่ในม่านหมอกทางตะวันออก", "สัญญาสลักโลหิตห้ามผิดคำเด็ดขาด"],
	"steppe": ["ข่านเตมูร์เคารพแต่ผู้แข็งแกร่ง", "ม้าศึกนับหมื่นพร้อมจะลงใต้", "คนจงหยวนทนหนาวไม่ไหวหรอก"],
	"sect": ["ศิษย์พี่บอกว่าห้ามเดินเข้าห้องฝึกลับ", "อาจารย์สั่งให้ซ้อมกระบวนท่าให้ครบพันรอบ", "ได้ยินว่าสำนักนอกต้องการแย่งคัมภีร์ของเรา"],
	"desert": ["น้ำในโอเอซิสมีค่ากว่าทองคำ", "นักพรตซวนหยวนกับวิหารเทวะปะทะกันอีกแล้ว", "พายุทรายกลืนคาราวานไปทั้งขบวน"],
}

var sect: SectData
var city_id: String
var city: Dictionary
var layout: CityLayout
var services: CityServices
var player: CityPlayer
var avatar: DiscipleData

var _world: Node2D
var _daynight: DayNight
var _hud: InteractionHUD
var _ui: Control
var _dialogue: Label
var _clock: Label
var _status: Label
var _window := {}
var _window_service := ""
var _window_title := ""
var _npcs: Array[CityNPC] = []
var _buildings: Array[CityBuilding] = []
var _night := false

## ภาพ HD-2D (ใช้กับสำนักอื่นที่เดินเข้าได้) — โลก 2D ยังทำงานเบื้องหลัง
var _view3d: CityView3D

func _ready() -> void:
	sect = GlobalGame.current_sect
	city_id = GlobalGame.selected_city_id
	city = WorldDB.get_node_data(city_id)
	var team = ExpeditionSys.get_stationed_at(sect, city_id) if sect else []
	if sect == null or city.is_empty() or team.is_empty():
		get_tree().change_scene_to_file.call_deferred("res://scene/map/world_map.tscn")
		return
	avatar = team[0]
	for d in team:
		if d.is_founder: avatar = d
	layout = CityLayout.new(city_id)
	services = CityServices.new(self, city_id, _say, _refresh_window)
	_build_ground()
	_world = Node2D.new()
	_world.y_sort_enabled = true
	add_child(_world)
	add_child(PathService.new())
	_build_ui()
	_build_city()
	_build_bounds()
	_spawn_player()
	_hud.player = player
	_daynight = DayNight.new()
	add_child(_daynight)
	# เดินในเมือง/สำนักอื่น: เวลาหยุดนิ่ง จะเปลี่ยนช่วงเวลาได้ด้วยปุ่ม "ข้ามเวลา [N]" เท่านั้น
	GlobalGame.clock_enabled = false
	GlobalGame.phase_changed.connect(func(_p): _update_time_of_day())
	_update_time_of_day(true)
	if CityDB.is_sect_node(city_id): _enable_3d()
	_say("%s: เดินด้วย WASD หรือคลิก · [E] ปฏิสัมพันธ์ · Shift วิ่ง · [N] ข้ามเวลา" % city.name)

## สำนักอื่น: แสดงผลแบบ HD-2D (ซ่อนภาพ 2D แต่ระบบชน/NPC/ยาม/จุดปฏิสัมพันธ์ 2D ยังทำงาน)
func _enable_3d() -> void:
	_view3d = CityView3D.new()
	add_child(_view3d)
	_view3d.setup(self, layout)
	_world.visible = false
	var ground = get_node_or_null("Ground")
	if ground: ground.visible = false

func _exit_tree() -> void:
	GlobalGame.clock_enabled = false

# ══════════════════════════════════════════
# สร้างฉาก
# ══════════════════════════════════════════

func _build_ground() -> void:
	var tileset = TileSet.new()
	tileset.tile_size = Vector2i(CityLayout.TILE, CityLayout.TILE)
	tileset.add_physics_layer()
	tileset.set_physics_layer_collision_layer(0, 1)
	var source = TileSetAtlasSource.new()
	source.texture = ArtGen.make_city_atlas(layout.theme.ground)
	source.texture_region_size = Vector2i(CityLayout.TILE, CityLayout.TILE)
	for i in 7: source.create_tile(Vector2i(i, 0))
	tileset.add_source(source, 0)
	# น้ำและกำแพงเดินผ่านไม่ได้ (physics polygon บน tile)
	var h = CityLayout.TILE / 2.0
	for t in [CityLayout.T.WATER, CityLayout.T.WALL]:
		var td = source.get_tile_data(Vector2i(t, 0), 0)
		td.add_collision_polygon(0)
		td.set_collision_polygon_points(0, 0, PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)]))
	var layer = TileMapLayer.new()
	layer.name = "Ground"
	layer.tile_set = tileset
	add_child(layer)
	for y in CityLayout.H:
		for x in CityLayout.W:
			layer.set_cell(Vector2i(x, y), 0, Vector2i(layout.at(Vector2i(x, y)), 0))

func _build_city() -> void:
	for b in layout.buildings:
		var node = CityBuilding.create(b)
		_world.add_child(node)
		_buildings.append(node)
		if CityDB.BUILDINGS[b.kind].service != "":
			_add_zone(CityLayout.cell_to_world(b.door) + Vector2(0, -6), Vector2(40, 30), "door", "เข้า " + b.name, { "service": CityDB.BUILDINGS[b.kind].service, "name": b.name })
	for c in layout.trees:
		_world.add_child(_make_tree(c))
	for c in layout.lanterns:
		_world.add_child(_make_lantern(c))
	_add_zone(CityLayout.cell_to_world(layout.spawn) + Vector2(-20, 0), Vector2(30, 90), "exit", "ออกจากเมือง")

func _make_tree(c: Vector2i) -> Node2D:
	var n = Node2D.new()
	n.position = CityLayout.cell_to_world(c) + Vector2(0, 12)
	var col: Color = layout.theme.tree
	n.draw.connect(func():
		n.draw_circle(Vector2(4, 2), 12, Color(0, 0, 0, 0.2))
		n.draw_rect(Rect2(-3, -16, 6, 16), Color(0.35, 0.24, 0.15))
		n.draw_circle(Vector2(0, -26), 15, col)
		n.draw_circle(Vector2(-7, -20), 10, col.darkened(0.1))
		n.draw_circle(Vector2(6, -32), 9, col.lightened(0.1)))
	var body = StaticBody2D.new()
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 8
	shape.shape = circle
	body.add_child(shape)
	n.add_child(body)
	return n

func _make_lantern(c: Vector2i) -> Node2D:
	var n = Node2D.new()
	n.position = CityLayout.cell_to_world(c)
	n.draw.connect(func():
		n.draw_line(Vector2(0, 0), Vector2(0, -34), Color(0.3, 0.2, 0.12), 3.0)
		n.draw_circle(Vector2(0, -36), 6, Color(0.9, 0.2, 0.12))
		n.draw_rect(Rect2(-6, -38, 12, 2), Color(1, 0.8, 0.3)))
	var light = DayNight.make_light()
	light.position = Vector2(0, -30)
	n.add_child(light)
	return n

## ขอบผัง: เดินออกนอกแผนที่ไม่ได้ (ออกจากเมืองทางจุด "ออกจากเมือง" เท่านั้น)
func _build_bounds() -> void:
	var r = Rect2(Vector2.ZERO, layout.size_px())
	var corners = [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	var body = StaticBody2D.new()
	body.collision_layer = 1
	for i in 4:
		var seg = CollisionShape2D.new()
		var s = SegmentShape2D.new()
		s.a = corners[i]
		s.b = corners[(i + 1) % 4]
		seg.shape = s
		body.add_child(seg)
	add_child(body)

func _spawn_player() -> void:
	player = CityPlayer.create(avatar, layout)
	var pos = CityLayout.cell_to_world(layout.spawn)
	if GlobalGame.city_return_id == city_id and GlobalGame.city_return_pos != Vector2.ZERO:
		pos = GlobalGame.city_return_pos
	GlobalGame.city_return_id = ""
	player.position = pos
	_world.add_child(player)

## จำตำแหน่งไว้ก่อนตัดเข้าฉากต่อสู้ (กลับมาแล้วยืนที่เดิม)
func remember_position() -> void:
	GlobalGame.city_return_id = city_id
	GlobalGame.city_return_pos = player.global_position

## จุดปฏิสัมพันธ์ (InteractableArea ล่องหน)
func _add_zone(center: Vector2, size: Vector2, action: String, text: String, payload := {}) -> InteractableArea:
	var a = InteractableArea.make(action, text, size, payload)
	a.position = center
	add_child(a)
	_hud.track(a)
	a.interacted.connect(_on_zone)
	return a

func _on_zone(a: InteractableArea) -> void:
	match a.action:
		"door": _open_service(a.payload.service, a.payload.name)
		"exit": _leave_city()

# ══════════════════════════════════════════
# NPC กลางวัน / ยามกลางคืน
# ══════════════════════════════════════════

func _clear_npcs() -> void:
	for n in _npcs:
		n.queue_free()
	_npcs.clear()

func _spawn_npc(role: String, npc_name: String, texture: Texture2D, cell: Vector2i, extra := {}, color := Color(0.95, 0.9, 0.8)) -> CityNPC:
	var n = CityNPC.create(role, npc_name, texture, layout, color)
	n.position = CityLayout.cell_to_world(cell)
	n.data = extra
	n.player = player
	_world.add_child(n)
	_npcs.append(n)
	_hud.track(n.area)
	n.area.interacted.connect(func(_a): _talk(n))
	return n

## ยามเดินตรวจตามเส้นทางลาดตระเวน: ไม่ไล่จับ ไม่โจมตี คุยได้ ท่าทีขึ้นกับชื่อเสียงสำนัก/ตัวเรา และความสัมพันธ์กับสำนักเจ้าถิ่น
func _spawn_sentries() -> void:
	var is_sect = CityDB.is_sect_node(city_id)
	var fid = services.sect_faction() if is_sect else ""
	var tex = ArtGen.get_townsfolk("guard", FactionDB.FACTIONS[fid].color if fid != "" else Color(0.65, 0.12, 0.1), "sword", true)
	for p in layout.patrols.slice(0, 3):
		var g = _spawn_npc("sentry", "ศิษย์เวรยาม" if is_sect else "ทหารยาม", tex, p[0], {}, Color(1, 0.7, 0.5))
		g.waypoints.assign([CityLayout.cell_to_world(p[0]), CityLayout.cell_to_world(p[1])])

func _talk_sentry(n: CityNPC) -> void:
	var rep = ReputationSys.score(sect) + avatar.fame
	var fid = services.sect_faction() if CityDB.is_sect_node(city_id) else ""
	var rel = sect.factions[fid].relation if fid != "" else 0
	var war = fid != "" and sect.factions[fid].war
	var line = ""
	if war or rel < -40:
		line = "สำนัก%s... ข้ารู้ว่าพวกเจ้าเป็นใคร เดินดูได้ แต่อย่าคิดก่อเรื่องในถิ่นเรา" % sect.sect_name
	elif rep >= 550 or rel >= 50:
		line = "คารวะท่าน%s แห่งสำนัก%s! ชื่อเสียงของท่านระบือไกล" % [avatar.disciple_name, sect.sect_name]
		var key = "sentry_tip:%s:%d" % [city_id, sect.current_day]
		if not sect.completed_world_tasks.has(key):
			sect.completed_world_tasks.append(key)
			var e = RosterSys.reveal_one(sect)
			if not e.is_empty(): line += "\nข้าได้ยินว่า %s ปรากฏตัวที่%s" % [e.name, RosterSys.node_name(e)]
	elif rep >= 150:
		line = "ช่วงนี้มีโจรป่าลงมาปล้นถึงชานเมือง ท่านเดินทางระวังตัวด้วย"
	else:
		line = "เจ้ามาจากไหน? สำนัก%s... ข้าไม่เคยได้ยินชื่อเลย" % sect.sect_name
	_say("%s: '%s'" % [n.display_name, line])

func _get_citizen_line(rng: RandomNumberGenerator, theme_key: String, index: int) -> String:
	if not WorldMode.is_sandbox():
		var lines: Array = CITIZEN_LINES.get(theme_key, CITIZEN_LINES.trade)
		return lines[index % lines.size()]
	
	var lords: Array = city.get("lords", [])
	var lord_name = FactionDB.FACTIONS[lords[0]].name if not lords.is_empty() and FactionDB.FACTIONS.has(lords[0]) else ""
	var demonic_factions = FactionDB.FACTIONS.keys().filter(func(f): return FactionDB.FACTIONS[f].align == "มาร")
	var demon_name = FactionDB.FACTIONS[demonic_factions[rng.randi() % demonic_factions.size()]].name if not demonic_factions.is_empty() else "พรรคมาร"
	var court_name = FactionDB.FACTIONS.get("f_court", {}).get("name", "ราชสำนัก")
	
	var pool = [
		"ราคาข้าวและวัตถุดิบช่วงนี้ผันผวน พ่อค้าจากต่างแดนเพิ่งมาถึง",
		"ได้ยินว่าโรงเตี๊ยมกลางเมืองมีจอมยุทธ์แวะเวียนมาประลองฝีมือกันทุกวัน",
		"ช่วงนี้ระวังตัวด้วย มีข่าวลือว่าคนของ%sแอบส่งสายลับมาป้วนเปี้ยน" % demon_name,
		"สินค้าในตลาดวันนี้คึกคักเป็นพิเศษ ใครมีแร่และสมุนไพรมาขายคงรวยเละ",
		"หากินในยุทธภพยุคนี้ไม่ง่ายเลย สำนักน้อยใหญ่ต่างแก่งแย่งชิงดีกัน"
	]
	if lord_name != "":
		pool.append("ได้ยินว่าคนของ%sกวดขันตรวจตรายามค่ำคืนเข้มงวดเป็นพิเศษ" % lord_name)
		pool.append("%sกำลังรับสมัครศิษย์รุ่นใหม่ จอมยุทธ์รุ่นเยาว์ต่างอยากเข้าร่วม" % lord_name)
	if theme_key == "capital":
		pool.append("ในเมืองหลวงช่วงนี้มีตัวแทนจากทุกสำนักเดินทางมาเข้าเฝ้า%s" % court_name)
		pool.append("งานประลองยุทธ์ปีนี้ ยอดฝีมือจากทั่วแผ่นดินเตรียมชิงชัยกันคับคั่ง")
		pool.append("ทหารยามตรวจตราเข้มงวด ใครไม่มีป้ายสำนักเข้าออกวังหลวงลำบากนัก")
	elif theme_key in ["desert", "south"]:
		pool.append("ไอพิษและสภาพแวดล้อมรอบนอกอันตรายนัก หากไม่มีโอสถดีๆ อย่าได้ย่างกรายเข้าไป")
		pool.append("สมุนไพรแปลกๆ ในตลาดแถบนี้มีสรรพคุณพิสดารไม่น้อย")
	elif theme_key == "port":
		pool.append("เรือสินค้าเพิ่งเข้าเทียบท่า คืนนี้โรงเตี๊ยมริมน้ำคงแน่นขนัด")
		pool.append("ลมทะเลช่วงนี้แรงนัก ได้ยินว่ามีโจรสลัดดักปล้นเรือสินค้าอยู่บ่อยครั้ง")
	
	return pool[rng.randi() % pool.size()]

func _spawn_day_npcs() -> void:
	_spawn_sentries()
	var rng = RandomNumberGenerator.new()
	rng.seed = hash([city_id, sect.current_day])
	var theme_key: String = CityDB.get_city(city_id).theme
	for i in 9:
		var robe = Color.from_hsv(rng.randf(), 0.35, rng.randf_range(0.35, 0.7))
		var citizen_line = _get_citizen_line(rng, theme_key, i)
		_spawn_npc("citizen", ["ชาวเมือง", "พ่อค้าเร่", "ชาวบ้าน", "บัณฑิต"][i % 4], ArtGen.get_townsfolk("cit%d_%d" % [i, rng.randi()], robe), layout.random_street_cell(rng),
			{ "line": citizen_line })
	_spawn_npc("gossip", "นักเล่าข่าว", ArtGen.get_townsfolk("gossip" + city_id, Color(0.5, 0.45, 0.35)), layout.random_street_cell(rng), {}, Color(0.7, 0.9, 1))
	# สายลับของขั้วอำนาจที่เป็นศัตรู/คู่แข่ง
	var hostile = sect.factions.keys().filter(func(f): return FactionSys.is_hostile(sect, f))
	var spy_f: String = hostile[rng.randi() % hostile.size()] if not hostile.is_empty() else FactionDB.FACTIONS.keys()[rng.randi() % FactionDB.FACTIONS.size()]
	_spawn_npc("spy", "ชายสวมหมวกไผ่", ArtGen.get_townsfolk("spy" + city_id, Color(0.25, 0.25, 0.3), "", true), layout.random_street_cell(rng), { "faction": spy_f }, Color(0.75, 0.75, 0.8))
	_spawn_npc("quest", "ผู้ว่าจ้างลับ", ArtGen.get_townsfolk("quest" + city_id, Color(0.55, 0.3, 0.2)), layout.random_street_cell(rng), {}, Color(1, 0.85, 0.4))
	# ตัวละครมีชื่อที่อยู่ในเมืองนี้ (ชวนเข้าสำนักได้)
	RosterSys.discover_at(sect, city_id)
	for e in RosterSys.at_node(sect, city_id):
		var robe = Color.from_hsv(float(hash(e.id) % 100) / 100.0, 0.5, 0.6)
		_spawn_npc("talent", e.title + " " + e.name, ArtGen.get_townsfolk("tal" + e.id, robe, "sword"), layout.random_street_cell(rng), { "id": e.id }, Color(1, 0.85, 0.4))
	_spawn_npc("wanderer", "จอมยุทธ์พเนจร", ArtGen.get_townsfolk("wand%d" % (sect.current_day / CityServices.REFRESH_DAYS), Color(0.2, 0.35, 0.45), "sword"), layout.random_street_cell(rng), {}, Color(0.6, 1, 0.7))

## ชุด NPC ยามค่ำ: ไม่มียาม ร้านปิด คนกลางคืนออกมา (คนเมา นักดนตรีพเนจร ขอทาน นักพนัน) + เป้าหมายสัญญาลอบสังหาร
const NIGHT_LINES = [
	"ดึกป่านนี้ยังไม่กลับบ้านอีกหรือท่าน... สุรายังเหลืออีกครึ่งไห",
	"ข้าเห็นเงาคนเหาะข้ามหลังคาเมื่อครู่ หรือข้าตาฝาดไปเอง",
	"บ่อนหลังตลาดยังเปิด แต่ระวังเถิด คนที่นั่นไม่ได้เล่นแค่ลูกเต๋า",
	"เพลงขลุ่ยนี้ข้าเรียนจากนักพรตบนเขา... ท่านอยากฟังอีกเพลงไหม",
	"ทานบุญสักอีแปะเถิดท่าน ข้าจะเล่าข่าวลือให้ฟังเป็นการตอบแทน",
]

func _spawn_night_npcs() -> void:
	_spawn_sentries()
	var rng = RandomNumberGenerator.new()
	rng.seed = hash([city_id, sect.current_day, "night"])
	var roles = ["คนเมา", "นักดนตรีพเนจร", "ขอทาน", "นักพนัน", "คนเดินทางยามค่ำ"]
	for i in 5:
		var robe = Color.from_hsv(rng.randf(), 0.25, rng.randf_range(0.25, 0.5))
		_spawn_npc("citizen", roles[i], ArtGen.get_townsfolk("night%d_%d" % [i, rng.randi()], robe), layout.random_street_cell(rng), { "line": NIGHT_LINES[i] }, Color(0.75, 0.8, 1))
	_spawn_npc("gossip", "นักเล่าข่าว", ArtGen.get_townsfolk("gossip" + city_id, Color(0.5, 0.45, 0.35)), layout.random_street_cell(rng), {}, Color(0.7, 0.9, 1))
	RosterSys.discover_at(sect, city_id)
	for e in RosterSys.at_node(sect, city_id):
		var robe = Color.from_hsv(float(hash(e.id) % 100) / 100.0, 0.5, 0.6)
		_spawn_npc("talent", e.title + " " + e.name, ArtGen.get_townsfolk("tal" + e.id, robe, "sword"), layout.random_street_cell(rng), { "id": e.id }, Color(1, 0.85, 0.4))
	# เป้าหมายลอบสังหาร (ออกมาเฉพาะกลางคืน)
	var k = sect.active_contract
	if not k.is_empty() and k.city == city_id:
		_spawn_npc("target", k.target, ArtGen.get_townsfolk("target" + k.target, FactionDB.FACTIONS[k.faction].color), layout.random_street_cell(rng), {}, Color(1, 0.35, 0.3))

func _update_time_of_day(force := false) -> void:
	var night_now = sect.time_phase == 2
	for b in _buildings:
		b.night = night_now
		b.queue_redraw()
	if night_now != _night or force:
		_night = night_now
		_clear_npcs()
		if _night: _spawn_night_npcs()
		else: _spawn_day_npcs()
		if _night: _say("ราตรีมาเยือน ร้านรวงปิด ผู้คนยามค่ำออกมาแทน · กด [N] พักแรมข้ามถึงเช้า")

# ══════════════════════════════════════════
# UI
# ══════════════════════════════════════════

func _build_ui() -> void:
	var layer = CanvasLayer.new()
	add_child(layer)
	_ui = Control.new()
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_ui)
	var top = PanelContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_ui.add_child(top)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	top.add_child(row)
	row.add_child(UIKit.button("< ออกจากเมือง", _leave_city))
	var title = UIKit.label("%s · %s" % [city.name, WorldDB.get_region_name(city.region)], 20, WuxiaTheme.BRONZE.lightened(0.2))
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(title)
	_clock = UIKit.label("", 16, Color(1, 0.85, 0.5))
	_clock.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(_clock)
	_status = UIKit.label("", 14, WuxiaTheme.PAPER_DIM)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.autowrap_mode = TextServer.AUTOWRAP_OFF
	_status.clip_text = true
	row.add_child(_status)
	row.add_child(UIKit.button("ทีม [I]", _open_team))
	row.add_child(UIKit.button("แผนที่ [M]", _open_map))
	row.add_child(UIKit.button("ข้ามเวลา [N]", skip_phase))
	# ปุ่ม [E] ของจุดปฏิสัมพันธ์ที่อยู่ใกล้ที่สุด
	_hud = InteractionHUD.new()
	_ui.add_child(_hud)
	var bottom = PanelContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -70
	_ui.add_child(bottom)
	_dialogue = UIKit.label("", 16)
	bottom.add_child(_dialogue)

func _say(text: String) -> void:
	if _dialogue: _dialogue.text = text

func _process(_delta: float) -> void:
	if _clock == null: return
	_clock.text = GlobalGame.get_clock_text() + " (เวลาหยุด)"
	_status.text = "เงิน %d · อวตาร: %s (พลังรบ %d)" % [sect.money, avatar.disciple_name, avatar.get_power_rating()]

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_N: skip_phase()
			KEY_I: _open_team()
			KEY_M: _open_map()
			KEY_ESCAPE: _close_window()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _window.is_empty():
		player.walk_to(_view3d.screen_to_world2d(event.position) if _view3d != null else get_global_mouse_position())
	elif event is InputEventMouseButton and event.pressed and _window.is_empty() and _view3d != null:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: _view3d.zoom = clampf(_view3d.zoom / 1.1, 0.6, 2.2)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN: _view3d.zoom = clampf(_view3d.zoom * 1.1, 0.6, 2.2)
	elif event is InputEventMouseButton and event.pressed and _window.is_empty():
		var cam: Camera2D = player.get_node("Camera")
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: cam.zoom = (cam.zoom * 1.1).clamp(Vector2(0.8, 0.8), Vector2(2.5, 2.5))
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN: cam.zoom = (cam.zoom / 1.1).clamp(Vector2(0.8, 0.8), Vector2(2.5, 2.5))

# ══════════════════════════════════════════
# ปฏิสัมพันธ์
# ══════════════════════════════════════════

func _open_service(service: String, title: String) -> void:
	_close_window()
	_window_service = service
	_window_title = title
	GlobalGame.paused = true
	_window = UIKit.open_window(_ui, title, Vector2(820, 520))
	_window.root.tree_exited.connect(func():
		_window = {}
		GlobalGame.paused = false
		_hud.blocked = false
		_hud.refresh())
	services.build(service, _window.content)
	_hud.blocked = true
	_hud.refresh()

func _refresh_window() -> void:
	if _window.is_empty() or not is_instance_valid(_window.root): return
	if _window_service == "":
		_close_window()
		return
	UIKit.clear(_window.content)
	services.build(_window_service, _window.content)

func _close_window() -> void:
	if not _window.is_empty() and is_instance_valid(_window.root):
		_window.root.queue_free()

## หน้าต่างบทสนทนากับ NPC
func _dialog(title: String, text: String, buttons: Array = [], size := Vector2(640, 300)) -> void:
	_close_window()
	_window_service = ""
	GlobalGame.paused = true
	_window = UIKit.open_window(_ui, title, size)
	_window.root.tree_exited.connect(func():
		_window = {}
		GlobalGame.paused = false
		_hud.blocked = false
		_hud.refresh())
	_window.content.add_child(UIKit.label(text, 17))
	var row = HFlowContainer.new()
	for b in buttons: row.add_child(b)
	_window.content.add_child(row)
	_hud.blocked = true
	_hud.refresh()

func _talk(n: CityNPC) -> void:
	var period = sect.current_day / CityServices.REFRESH_DAYS
	match n.role:
		"citizen":
			_say("%s: '%s'" % [n.display_name, n.data.get("line", "...")])
		"sentry":
			_talk_sentry(n)
		"gossip":
			var extra = ""
			var lm = LandmarkSys.reveal_one(sect) if randf() < 0.5 else {}
			if not lm.is_empty():
				extra = "\n\nนอกจากนั้น ข้าได้ยินว่ามี%s ที่%s — %s" % [LandmarkSys.kind_name(lm.kind), WorldDB.NODES[lm.node].name, lm.desc]
			else:
				var hint = RosterSys.reveal_one(sect)
				if not hint.is_empty():
					extra = "\n\nนอกจากนั้น ข้าได้ยินว่า%s %s อยู่ที่%s ลองไปหาดูสิ" % [hint.title, hint.name, RosterSys.node_name(hint)]
			_dialog("นักเล่าข่าว", "'ข่าวล่าสุดในยุทธภพ ฟังให้ดีนะ...'\n\n" + "\n".join(services.rumors(3)) + extra)
		"talent":
			_talk_talent(n)
		"spy":
			var fid: String = n.data.faction
			var cost = int(services.intel_cost(fid) * 0.6)
			_dialog("ชายสวมหมวกไผ่", "'ข้าเคยเป็นคนของ%s... ข้ารู้จุดอ่อนของพวกมันทุกอย่าง จ่าย %d แล้วข้าจะบอก'" % [FactionDB.FACTIONS[fid].name, cost], [
				UIKit.button("จ่าย %d" % cost, func():
					services.buy_intel(fid, cost)
					_close_window()
					_say("สายลับกระซิบความลับของ%s แล้วหายตัวไปในฝูงชน (ดูรายละเอียดในบันทึกเหตุการณ์)" % FactionDB.FACTIONS[fid].name), sect.money < cost),
				UIKit.button("ไม่สนใจ", _close_window)])
		"quest":
			_secret_quest(period)
		"wanderer":
			_wanderer_duel(period)
		"target":
			_assassinate(n)

## คุยกับตัวละครมีชื่อ: ถามไถ่ / ของกำนัล / ท้าประลอง / ชวนเข้าสำนัก (แสดงเหตุผลความเต็มใจ)
func _talk_talent(n: CityNPC, offer := 0) -> void:
	var e = RosterSys.get_entry(sect, n.data.get("id", ""))
	if e.is_empty() or e.status != "free":
		_say("%s: 'ข้าไม่อยู่ที่นี่แล้ว'" % n.display_name)
		return
	var w = RosterSys.willingness(sect, e, offer)
	var text = RosterSys.describe(e) + "\n\n── ความเต็มใจเข้าสำนัก: %d / ต้องการ %d ──" % [w.score, w.need]
	for l in w.lines:
		text += "\n  %+d  %s" % [l.value, l.text]
	var gcost = RosterSys.gift_cost(e)
	var buttons = [
		UIKit.button("ถามไถ่ (รู้จักกัน %d/%d)" % [e.insight, RosterSys.MAX_INSIGHT], func():
			var msg = RosterSys.chat(sect, e)
			_talk_talent(n, offer)
			_say(msg)),
		UIKit.button("มอบของกำนัล (%d)" % gcost, func():
			var msg = RosterSys.gift(sect, e)
			_talk_talent(n, offer)
			_say(msg), sect.money < gcost),
		UIKit.button("ท้าประลอง", func():
			var enemies: Array[Dictionary] = [RosterSys.spar_fighter(e)]
			services.start_combat(enemies, { "type": "roster_spar", "node": city_id, "faction": "", "roster_id": e.id }), services.fighters().is_empty()),
		UIKit.button("ชวนเข้าสำนัก" + (" (เสนอ %d)" % offer if offer > 0 else ""), func():
			var res = RosterSys.recruit(sect, e, GlobalGame.sect_manager, offer)
			if res.ok:
				_close_window()
				n.queue_free()
			else:
				_talk_talent(n, offer)
			_say(res.text)),
		UIKit.button("เสนอเงิน +%d" % e.cost, func(): _talk_talent(n, offer + int(e.cost)), sect.money < offer + int(e.cost)),
		UIKit.button("ไว้คราวหน้า", _close_window),
	]
	_dialog(e.name, text, buttons, Vector2(720, 480))

## เควสต์ลับ: ปราบยอดฝีมือนอกรีตที่ซ่อนตัวในเมือง (รางวัลสูง ทำได้รอบละครั้ง)
func _secret_quest(period: int) -> void:
	var key = "secret:%s:%d" % [city_id, period]
	if sect.completed_world_tasks.has(key):
		_say("ผู้ว่าจ้างลับ: 'งานของเราจบแล้ว รอบหน้าค่อยมาใหม่'")
		return
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(key)
	var pool = ["rival_elder", "demon_elder", "blood_spider", "pirate_captain", "fire_cultist"]
	var enemy_id: String = pool[rng.randi() % pool.size()]
	var e = EnemyDB.ENEMIES[enemy_id]
	var reward = 400 + e.level * 80
	_dialog("ผู้ว่าจ้างลับ", "'มี%sซ่อนตัวอยู่ในเมืองนี้ ทางการไม่กล้าแตะ ถ้าท่านกำจัดมันได้ ข้าจะให้ %d เงิน และคัมภีร์ชำรุดหนึ่งเล่ม'\n(พลังศัตรู ~%d · พลังรบอวตารของท่าน %d)" % [e.name, reward, EnemyDB.get_power(enemy_id), avatar.get_power_rating()], [
		UIKit.button("รับงาน (ต่อสู้ทันที)", func():
			var foe = EnemyDB.get_enemy(enemy_id)
			foe.drops["scripture_fragment"] = [1, 1]
			var enemies: Array[Dictionary] = [foe]
			services.start_combat(enemies, { "type": "bounty", "node": city_id, "faction": "" }, reward, key)),
		UIKit.button("ปฏิเสธ", _close_window)])

## จอมยุทธ์พเนจรท้าประลอง ชนะแล้วยอมเข้าสำนัก
func _wanderer_duel(period: int) -> void:
	var key = "duel:%s:%d" % [city_id, period]
	if sect.completed_world_tasks.has(key):
		_say("จอมยุทธ์พเนจร: 'ข้าแพ้ท่านแล้ว จะไปรอที่สำนักของท่าน'")
		return
	var power = StatSys.world_threat(sect.current_day) * 1.3
	var full = sect.get_active_disciples().size() >= sect.get_max_disciples()
	_dialog("จอมยุทธ์พเนจร", "'ข้าท่องยุทธภพมาสิบปี ไม่เคยเจอใครคู่ควร... ถ้าท่านชนะข้าได้ ข้าจะยอมเข้าสำนักของท่าน'\n(พลัง ~%d%s)" % [power, " · สำนักเต็มแล้ว ชนะได้แค่ชื่อเสียง" if full else ""], [
		UIKit.button("รับคำท้า", func():
			var foe = StatSys.build_fighter(power, 4.5)
			foe.merge({ "id": "wanderer_%d" % period, "name": "จอมยุทธ์พเนจร", "art": "human", "color": Color(0.2, 0.35, 0.45), "status_attack": "", "reward_money": 0, "reward_food": 0, "reward_exp": int(power * 3), "drops": {} })
			foe["hp"] = foe.max_hp
			var enemies: Array[Dictionary] = [foe]
			services.start_combat(enemies, { "type": "recruit_duel", "node": city_id, "faction": "", "recruit_level": foe.level }, 0, key)),
		UIKit.button("ไว้คราวหน้า", _close_window)])

## ลอบสังหาร: เป้าหมายกับองครักษ์ (ตามความเสี่ยงของสัญญา) สู้กันซึ่งๆ หน้าบนสนาม ชนะ = ได้ค่าจ้าง
func _assassinate(n: CityNPC) -> void:
	var k = sect.active_contract
	if k.is_empty(): return
	var power = StatSys.world_threat(sect.current_day) * (0.8 + k.risk * 0.25)
	var enemies: Array[Dictionary] = []
	var foe = StatSys.build_fighter(power * 1.3, 4.5)
	foe.merge({ "id": "target_" + k.target, "name": k.target, "art": "human", "color": FactionDB.FACTIONS[k.faction].color, "status_attack": "", "reward_money": 0, "reward_food": 0, "reward_exp": int(power * 2), "drops": {} }, true)
	enemies.append(foe)
	for i in mini(k.risk, 3):
		var g = StatSys.build_fighter(power * 0.8, 3.5)
		g.merge({ "id": "bodyguard%d" % i, "name": "องครักษ์", "art": "human", "color": Color(0.4, 0.3, 0.3), "status_attack": "", "reward_money": 30, "reward_food": 0, "reward_exp": int(power), "drops": {} }, true)
		enemies.append(g)
	for e in enemies: e["hp"] = e.max_hp
	_say("%s รู้ตัว! องครักษ์ชักอาวุธล้อมเข้ามา" % k.target)
	services.start_combat(enemies, { "type": "contract", "node": city_id, "faction": k.faction })

## ข้ามเวลาไปช่วงถัดไป (เช้า -> บ่าย -> ค่ำ -> เช้าวันใหม่) ระบบยังจำลองครบทุก tick
func skip_phase() -> void:
	if not _window.is_empty(): return
	var was_night = sect.time_phase == 2
	GlobalGame.advance_phase()
	_say(("พักแรมจนรุ่งสาง... เช้าวันที่ %d" % sect.current_day) if was_night else "เวลาผ่านไป... ตอนนี้เป็นช่วง%s" % ["เช้า", "บ่าย/เย็น", "ค่ำ"][sect.time_phase])
	_update_time_of_day()

## หน้าต่างทีม: ศิษย์ที่ประจำอยู่ที่นี่ ดูประวัติ/สลับตัวเดิน
func _open_team() -> void:
	if not _window.is_empty(): return
	var team = ExpeditionSys.get_stationed_at(sect, city_id)
	_dialog("ทีมที่อยู่ที่นี่ (%d คน)" % team.size(), "", [], Vector2(720, 460))
	var c: VBoxContainer = _window.content
	for d in team:
		var hurt = d.injury_days > 0
		var info = "%s · %s · พลังรบ %d · HP %d%s%s" % [d.disciple_name, d.realm_name, d.get_power_rating(), d.get_combat_max_hp(), " · บาดเจ็บ %d วัน" % d.injury_days if hurt else "", "  (ตัวที่เดินอยู่)" if d == avatar else ""]
		c.add_child(UIKit.row(info, [
			UIKit.button("ดูประวัติ", func():
				remember_position()
				GlobalGame.save_game()
				GlobalGame.selected_disciple = d
				GlobalGame.profile_return_scene = "res://scene/map/city_scene.tscn"
				get_tree().change_scene_to_file("res://scene/profile/disciple_profile.tscn")),
			UIKit.button("เดินด้วยคนนี้", func():
				avatar = d
				player.disciple = d
				player.speed_mult = StatSys.walk_speed_mult(d)
				player._sprite.texture = ArtGen.get_figure(d)
				_close_window(), d == avatar),
		]))

## แผนที่ผังเมือง/สำนัก: อาคารพร้อมชื่อ ตำแหน่งเรา และ NPC สำคัญ
func _open_map() -> void:
	if not _window.is_empty(): return
	_dialog("แผนที่ " + city.name, "", [UIKit.button("ไปแผนที่โลก", _leave_city)], Vector2(860, 620))
	var c: VBoxContainer = _window.content
	var S = 15.0
	var map = Control.new()
	map.custom_minimum_size = Vector2(CityLayout.W, CityLayout.H) * S
	var cols = [ArtGen.CITY_GROUNDS.get(layout.theme.ground, Color(0.5, 0.6, 0.4)), Color(0.62, 0.6, 0.56), Color(0.76, 0.72, 0.64), Color(0.3, 0.48, 0.62), Color(0.35, 0.33, 0.32), Color(0.45, 0.4, 0.34), Color(0.55, 0.4, 0.25)]
	map.draw.connect(func():
		for y in CityLayout.H:
			for x in CityLayout.W:
				map.draw_rect(Rect2(Vector2(x, y) * S, Vector2(S, S)), cols[layout.at(Vector2i(x, y))])
		var f = ThemeDB.fallback_font
		for b in layout.buildings:
			var r: Rect2i = b.rect
			map.draw_rect(Rect2(Vector2(r.position) * S, Vector2(r.size) * S), b.get("roof", CityDB.BUILDINGS[b.kind].roof))
			if CityDB.BUILDINGS[b.kind].service != "":
				map.draw_string_outline(f, Vector2(r.position.x, r.end.y) * S + Vector2(0, -4), b.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 4, Color.BLACK)
				map.draw_string(f, Vector2(r.position.x, r.end.y) * S + Vector2(0, -4), b.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 0.9, 0.6))
		for n in _npcs:
			if n.role in ["talent", "target", "quest", "wanderer"]:
				map.draw_circle(n.global_position / CityLayout.TILE * S, 4, Color(1, 0.85, 0.3) if n.role != "target" else Color(1, 0.3, 0.3))
		map.draw_circle(player.global_position / CityLayout.TILE * S, 6, Color(0.3, 0.8, 1))
		map.draw_arc(player.global_position / CityLayout.TILE * S, 9, 0, TAU, 20, Color.WHITE, 2.0))
	c.add_child(map)
	c.add_child(UIKit.label("● ฟ้า = ตัวเรา · ● ทอง = ยอดฝีมือ/ผู้ว่าจ้าง/จอมยุทธ์ · ● แดง = เป้าหมายสัญญา", 12, WuxiaTheme.PAPER_DIM))

func _leave_city() -> void:
	GlobalGame.save_game()
	get_tree().change_scene_to_file("res://scene/map/world_map.tscn")
