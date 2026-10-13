extends Node2D

## พื้นที่สำรวจแบบเดินเอง (Overworld) ของโหนดป่า/ดันเจี้ยนบนแผนที่โลก
## - บังคับศิษย์หัวหน้าทีม (CityPlayer) เดินสำรวจ ความเร็วเดินมาจากความว่องไว + ตัวเบา
## - หมอก Fog of War: เปิดรอบตัวตามค่าสัมผัสวิญญาณ (StatSys.sight_tiles) ตอนกลางคืนมองเห็นแคบลง
## - มอนสเตอร์ (FieldMonster) เห็นแล้ววิ่งไล่ ชนแล้วแช่แข็งฉาก -> เก็บสถานะใน GlobalGame.field_state -> ฉากต่อสู้
## - ชนะ = กลับมายืนที่เดิม ของดรอปตกที่พื้น (เดินชนเพื่อเก็บ), แพ้ = ทีมบาดเจ็บถอยกลับแผนที่โลก
## - แหล่งสมุนไพร/แร่ (InteractableArea) กด [E] เก็บ, ทางออกที่ทางเข้า

var sect: SectData
var node_id: String
var node: Dictionary
var layout: FieldLayout
var player: CityPlayer
var team: Array[DiscipleData] = []
var state: Dictionary

var _world: Node2D
var _hud: InteractionHUD
var _daynight: DayNight
var _fog_img: Image
var _fog_tex: ImageTexture
var _fog: Sprite2D
var _last_cell := Vector2i(-99, -99)
var _info: Label
var _log: Label
var _frozen := false

func _ready() -> void:
	sect = GlobalGame.current_sect
	node_id = GlobalGame.field_node
	node = WorldDB.get_node_data(node_id)
	team.assign(GlobalGame.field_team.filter(func(d): return d.can_fight()))
	if sect == null or node.is_empty() or team.is_empty():
		get_tree().change_scene_to_file.call_deferred("res://scene/map/world_map.tscn")
		return
	# ให้เจ้าสำนัก (ตัวละครผู้เล่น) เป็นผู้นำทีมเสมอ
	for i in team.size():
		if team[i].is_founder:
			var f = team[i]
			team.remove_at(i)
			team.insert(0, f)
			break
	LandmarkSys.discover_at(sect, node_id)
	var world_gen = WorldGen.for_sect(sect)
	layout = FieldLayout.new(node_id, world_gen.biome_at(world_gen.poi[node_id]))
	_load_state()
	_build_ground()
	_world = Node2D.new()
	_world.y_sort_enabled = true
	add_child(_world)
	add_child(PathService.new())
	_build_ui()
	_build_obstacles()
	_spawn_player()
	_spawn_monsters()
	_spawn_resources()
	_spawn_loot()
	_build_fog()
	_daynight = DayNight.new()
	_daynight.darkness = 0.45 if layout.theme_id == "cave" else 0.0
	add_child(_daynight)
	# คบเพลิงติดตัว (สว่างในถ้ำ/กลางคืน)
	var torch = DayNight.make_light(Color(1, 0.8, 0.55), 2.4, 1.0)
	torch.position = Vector2(0, -20)
	player.add_child(torch)
	GlobalGame.clock_enabled = true
	GlobalGame.paused = false

func _exit_tree() -> void:
	GlobalGame.clock_enabled = false

## สถานะพื้นที่ (คงอยู่ระหว่างตัดเข้าฉากต่อสู้): มอนสเตอร์ที่ปราบแล้ว ของที่เก็บแล้ว หมอกที่เปิดแล้ว ของดรอปบนพื้น
func _load_state() -> void:
	state = GlobalGame.field_state
	if state.get("node", "") != node_id or state.get("day", -1) != sect.current_day / 3:
		state = { "node": node_id, "day": sect.current_day / 3, "defeated": [], "gathered": [], "fog": PackedByteArray(), "loot": [], "pos": Vector2.ZERO, "pending_loot": {} }
		GlobalGame.field_state = state

# ══════════════════════════════════════════
# สร้างฉาก
# ══════════════════════════════════════════

func _build_ground() -> void:
	var th = layout.theme
	var T = FieldLayout.TILE
	var img = Image.create_empty(T * 4, T, false, Image.FORMAT_RGBA8)
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(layout.theme_id)
	var cols = [th.ground, th.path, th.water, th.wall]
	for i in 4:
		var base: Color = cols[i]
		for y in T:
			for x in T:
				var n = rng.randf_range(-0.035, 0.035)
				img.set_pixel(i * T + x, y, Color(base.r + n, base.g + n, base.b + n))
		match i:
			0:
				for k in 4:
					var p = Vector2(i * T + rng.randi_range(3, 28), rng.randi_range(4, 28))
					ArtGen.line(img, p, p + Vector2(1, -3), 1, base.darkened(0.15))
			2:
				ArtGen.line(img, Vector2(i * T + 4, 10), Vector2(i * T + 14, 10), 1, base.lightened(0.25))
				ArtGen.line(img, Vector2(i * T + 16, 22), Vector2(i * T + 27, 22), 1, base.lightened(0.25))
			3:
				ArtGen.rect(img, Rect2(i * T, 0, T, 4), base.lightened(0.12))
	var tileset = TileSet.new()
	tileset.tile_size = Vector2i(T, T)
	tileset.add_physics_layer()
	tileset.set_physics_layer_collision_layer(0, 1)
	var src = TileSetAtlasSource.new()
	src.texture = ImageTexture.create_from_image(img)
	src.texture_region_size = Vector2i(T, T)
	for i in 4: src.create_tile(Vector2i(i, 0))
	tileset.add_source(src, 0)
	var h = T / 2.0
	for t in [FieldLayout.T.WATER, FieldLayout.T.WALL]:
		var td = src.get_tile_data(Vector2i(t, 0), 0)
		td.add_collision_polygon(0)
		td.set_collision_polygon_points(0, 0, PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)]))
	var layer = TileMapLayer.new()
	layer.tile_set = tileset
	add_child(layer)
	for y in FieldLayout.H:
		for x in FieldLayout.W:
			layer.set_cell(Vector2i(x, y), 0, Vector2i(layout.at(Vector2i(x, y)), 0))

func _build_obstacles() -> void:
	var col: Color = layout.theme.obstacle
	var kind: String = layout.theme.kind
	for c in layout.obstacles:
		var n = Node2D.new()
		n.position = FieldLayout.cell_to_world(c) + Vector2(0, 12)
		var s = hash(c) % 5
		n.draw.connect(_draw_obstacle.bind(n, kind, col, s))
		var body = StaticBody2D.new()
		var shape = CollisionShape2D.new()
		var circle = CircleShape2D.new()
		circle.radius = 11
		shape.shape = circle
		shape.position = Vector2(0, -6)
		body.add_child(shape)
		n.add_child(body)
		_world.add_child(n)
	# ทางออก
	var exit_area = InteractableArea.make("exit", "กลับแผนที่โลก", Vector2(60, 90))
	exit_area.position = FieldLayout.cell_to_world(layout.entrance) + Vector2(-16, 0)
	add_child(exit_area)
	_hud.track(exit_area)
	exit_area.interacted.connect(func(_a): _leave())

## วาดสิ่งกีดขวางตามธีม (ต้นไม้ / สน / กระบองเพชร / หิน)
func _draw_obstacle(n: Node2D, kind: String, col: Color, s: int) -> void:
	match kind:
		"tree":
			n.draw_rect(Rect2(-3, -14, 6, 14), Color(0.35, 0.24, 0.15))
			n.draw_circle(Vector2(0, -24), 14 + s, col)
			n.draw_circle(Vector2(-6, -18), 9, col.darkened(0.12))
		"pine":
			n.draw_rect(Rect2(-2, -10, 4, 10), Color(0.35, 0.24, 0.15))
			n.draw_colored_polygon(PackedVector2Array([Vector2(-13, -8), Vector2(0, -40 - s), Vector2(13, -8)]), col)
			n.draw_colored_polygon(PackedVector2Array([Vector2(-6, -28), Vector2(0, -40 - s), Vector2(6, -28)]), Color(0.95, 0.97, 1))
		"cactus":
			n.draw_rect(Rect2(-4, -26, 8, 26), col)
			n.draw_rect(Rect2(-12, -18, 8, 4), col)
			n.draw_rect(Rect2(-12, -24, 4, 8), col)
		_:
			n.draw_colored_polygon(PackedVector2Array([Vector2(-14, 0), Vector2(-9, -16 - s), Vector2(6, -20), Vector2(14, 0)]), col)
			n.draw_line(Vector2(-9, -16 - s), Vector2(0, 0), col.darkened(0.25), 1.5)

func _spawn_player() -> void:
	player = CityPlayer.create(team[0], layout)
	player.position = state.pos if state.pos != Vector2.ZERO else FieldLayout.cell_to_world(layout.entrance + Vector2i(1, 0))
	_world.add_child(player)
	_hud.player = player

func _spawn_monsters() -> void:
	var enemies: Array = node.get("enemies", ["bandit_thug"])
	var rng = RandomNumberGenerator.new()
	rng.seed = hash([node_id, state.day])
	var count = 6 if node.type == WorldDB.NodeType.WILD else 8
	for i in count:
		var id = "m%d" % i
		var e: String = enemies[rng.randi() % enemies.size()]
		var group = rng.randi_range(1, 3 if node.type == WorldDB.NodeType.DUNGEON else 2)
		var cell = layout.random_spot(rng, 9.0)
		if state.defeated.has(id): continue
		var m = FieldMonster.create(id, e, group, layout)
		m.position = FieldLayout.cell_to_world(cell)
		m.player = player
		m.encountered.connect(_on_encounter)
		_world.add_child(m)

## แหล่งวัตถุดิบ (ตามรายการ gather ของพื้นที่) จำนวนตามผลผลิตของพื้นที่
func _spawn_resources() -> void:
	var gather: Dictionary = node.get("gather", {})
	if gather.is_empty(): return
	var rng = RandomNumberGenerator.new()
	rng.seed = hash([node_id, "res", state.day])
	var count = int(8 * sect.get_node_yield(node_id))
	var mats = gather.keys()
	for i in count:
		var id = "r%d" % i
		if state.gathered.has(id): continue
		var mat: String = mats[rng.randi() % mats.size()]
		var amount = max(1, rng.randi_range(gather[mat][0], gather[mat][1]))
		var cell = layout.random_spot(rng, 3.0)
		var n = Node2D.new()
		n.position = FieldLayout.cell_to_world(cell)
		var ore = mat in ["iron_ore", "cold_iron", "star_metal", "spirit_stone", "stone"]
		n.draw.connect(func():
			if ore:
				n.draw_colored_polygon(PackedVector2Array([Vector2(-10, 4), Vector2(-6, -8), Vector2(6, -10), Vector2(11, 4)]), Color(0.45, 0.42, 0.4))
				n.draw_circle(Vector2(-1, -3), 3, Color(0.75, 0.85, 1.0))
				n.draw_circle(Vector2(4, 0), 2, Color(0.75, 0.85, 1.0))
			else:
				for k in 3:
					n.draw_line(Vector2(-6 + k * 6, 4), Vector2(-6 + k * 6 + (k - 1) * 3, -10), Color(0.25, 0.55, 0.3), 2.0)
				n.draw_circle(Vector2(0, -11), 3.5, Color(0.8, 0.95, 0.5)))
		_world.add_child(n)
		var a = InteractableArea.make("gather", "เก็บ%s" % MaterialDB.get_material_name(mat), Vector2(44, 44), { "id": id, "mat": mat, "amount": amount, "node": n }, true)
		n.add_child(a)
		_hud.track(a)
		a.interacted.connect(_on_gather)

func _on_gather(a: InteractableArea) -> void:
	var p = a.payload
	var amount = int(ceil(p.amount * (1.0 + team[0].get_stat("gathering") * 0.05)))
	sect.add_material(p.mat, amount)
	state.gathered.append(p.id)
	_note("เก็บ %s x%d" % [MaterialDB.get_material_name(p.mat), amount])
	VFX.burst(_world, p.node.global_position, Color(0.6, 1, 0.6), 18)
	p.node.queue_free()

## ของดรอปจากการต่อสู้ที่เพิ่งชนะ ตกกระจายรอบตำแหน่งผู้เล่น (เดินชนเพื่อเก็บ)
func _spawn_loot() -> void:
	var pending: Dictionary = state.pending_loot
	if not pending.is_empty():
		var i = 0
		for mat in pending:
			var offset = Vector2(cos(i * 1.7), sin(i * 1.7)) * (28 + i * 6)
			state.loot.append({ "mat": mat, "amount": pending[mat], "pos": player.position + offset })
			i += 1
		state.pending_loot = {}
	for item in state.loot.duplicate():
		var n = Node2D.new()
		n.position = item.pos
		n.draw.connect(func():
			n.draw_circle(Vector2(0, 2), 7, Color(0, 0, 0, 0.25))
			n.draw_rect(Rect2(-6, -10, 12, 10), Color(0.75, 0.55, 0.3))
			n.draw_rect(Rect2(-6, -10, 12, 3), Color(0.95, 0.8, 0.4)))
		_world.add_child(n)
		var a = InteractableArea.make("loot", "", Vector2(26, 26), { "item": item, "node": n }, true)
		a.auto_trigger = true
		n.add_child(a)
		_hud.track(a)
		a.interacted.connect(_on_loot)

func _on_loot(a: InteractableArea) -> void:
	var item = a.payload.item
	if not state.loot.has(item): return
	state.loot.erase(item)
	sect.add_material(item.mat, item.amount)
	_note("เก็บของดรอป: %s x%d" % [MaterialDB.get_material_name(item.mat), item.amount])
	VFX.burst(_world, a.payload.node.global_position, Color(1, 0.85, 0.4), 16)
	a.payload.node.queue_free()

# ══════════════════════════════════════════
# หมอก Fog of War
# ══════════════════════════════════════════

func _build_fog() -> void:
	_fog_img = Image.create_empty(FieldLayout.W, FieldLayout.H, false, Image.FORMAT_RGBA8)
	_fog_img.fill(Color(0.02, 0.02, 0.04, 1))
	var saved: PackedByteArray = state.fog
	if saved.size() == FieldLayout.W * FieldLayout.H:
		for y in FieldLayout.H:
			for x in FieldLayout.W:
				if saved[y * FieldLayout.W + x] > 0: _fog_img.set_pixel(x, y, Color(0, 0, 0, 0))
	else:
		state.fog = PackedByteArray()
		state.fog.resize(FieldLayout.W * FieldLayout.H)
	_fog_tex = ImageTexture.create_from_image(_fog_img)
	_fog = Sprite2D.new()
	_fog.texture = _fog_tex
	_fog.centered = false
	_fog.scale = Vector2(FieldLayout.TILE, FieldLayout.TILE)
	_fog.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_fog.z_index = 50
	add_child(_fog)
	_reveal(true)

func sight_radius() -> float:
	var r = StatSys.sight_tiles(team[0])
	if sect.time_phase == 2 or layout.theme_id == "cave": r *= 0.7
	return r

func _reveal(force := false) -> void:
	var cell = FieldLayout.world_to_cell(player.global_position)
	if cell == _last_cell and not force: return
	_last_cell = cell
	var r = sight_radius()
	var ri = int(ceil(r))
	var changed = false
	for dy in range(-ri, ri + 1):
		for dx in range(-ri, ri + 1):
			var c = cell + Vector2i(dx, dy)
			if c.x < 0 or c.y < 0 or c.x >= FieldLayout.W or c.y >= FieldLayout.H: continue
			if Vector2(dx, dy).length() > r: continue
			var i = c.y * FieldLayout.W + c.x
			if state.fog[i] == 0:
				state.fog[i] = 1
				_fog_img.set_pixel(c.x, c.y, Color(0, 0, 0, 0))
				changed = true
	if changed: _fog_tex.update(_fog_img)

# ══════════════════════════════════════════
# ต่อสู้
# ══════════════════════════════════════════

func _on_encounter(m: FieldMonster) -> void:
	if _frozen: return
	_frozen = true
	# แช่แข็งฉาก: หยุดทุกอย่างแล้วตัดเข้าฉากต่อสู้
	for c in _world.get_children(): c.set_process(false)
	player.set_physics_process(false)
	_note("%s ปะทะ%s!" % [team[0].disciple_name, EnemyDB.ENEMIES[m.enemy_id].name])
	VFX.flash(get_node("UI/Root"), Color(1, 0.2, 0.1, 0.35), 0.35)
	state.pos = player.position
	state.fighting = m.monster_id
	var enemies: Array[Dictionary] = []
	for e in m.group: enemies.append(EnemyDB.get_enemy(e))
	GlobalGame.combat_allies.assign(team.slice(0, 4))
	GlobalGame.combat_enemies.assign(enemies)
	var owner: String = sect.node_owner.get(node_id, "")
	GlobalGame.combat_context = { "type": "field", "node": node_id, "faction": owner if FactionSys.is_hostile(sect, owner) else "" }
	GlobalGame.combat_return_scene = "res://scene/map/field_scene.tscn"
	GlobalGame.combat_bonus_money = 0
	GlobalGame.combat_bonus_task = ""
	GlobalGame.save_game()
	await get_tree().create_timer(0.4).timeout
	get_tree().change_scene_to_file(GlobalGame.COMBAT_SCENE)

# ══════════════════════════════════════════
# UI
# ══════════════════════════════════════════

func _build_ui() -> void:
	var layer = CanvasLayer.new()
	layer.name = "UI"
	add_child(layer)
	var root = Control.new()
	root.name = "Root"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var top = PanelContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	root.add_child(top)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	top.add_child(row)
	row.add_child(UIKit.button("< กลับแผนที่โลก", _leave))
	var title = UIKit.label("%s · %s" % [node.name, layout.theme.name], 20, WuxiaTheme.BRONZE.lightened(0.2))
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(title)
	_info = UIKit.label("", 14, WuxiaTheme.PAPER_DIM)
	_info.autowrap_mode = TextServer.AUTOWRAP_OFF
	_info.clip_text = true
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_info)
	_hud = InteractionHUD.new()
	root.add_child(_hud)
	var bottom = PanelContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -64
	root.add_child(bottom)
	_log = UIKit.label("WASD/คลิกเดิน · Shift วิ่งหนี · C ย่องเบา (มอนสเตอร์สังเกตเห็นยาก) · [E] เก็บวัตถุดิบ · มอนสเตอร์ชนตัว = เข้าฉากต่อสู้", 15)
	bottom.add_child(_log)

func _note(text: String) -> void:
	_log.text = text

func _process(_delta: float) -> void:
	if player == null or _frozen: return
	_reveal()
	var d = team[0]
	_info.text = "%s · ทีม %d คน · ความเร็วเดิน x%.2f (ว่องไว %d, ตัวเบา %d) · ระยะมองเห็น %.1f ช่อง (สัมผัสวิญญาณ %d) · %s" % [
		d.disciple_name, team.size(), player.speed_mult, d.get_stat("agi"), d.get_stat("movement_arts"), sight_radius(), d.get_stat("perception"), GlobalGame.get_clock_text()]

func _unhandled_input(event: InputEvent) -> void:
	if _frozen: return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_C: player.toggle_sneak()
			KEY_SPACE: GlobalGame.paused = not GlobalGame.paused
	elif event is InputEventMouseButton and event.pressed:
		var cam: Camera2D = player.get_node("Camera")
		match event.button_index:
			MOUSE_BUTTON_LEFT: player.walk_to(get_global_mouse_position())
			MOUSE_BUTTON_WHEEL_UP: cam.zoom = (cam.zoom * 1.1).clamp(Vector2(0.8, 0.8), Vector2(2.5, 2.5))
			MOUSE_BUTTON_WHEEL_DOWN: cam.zoom = (cam.zoom / 1.1).clamp(Vector2(0.8, 0.8), Vector2(2.5, 2.5))

func _leave() -> void:
	state.pos = Vector2.ZERO
	GlobalGame.save_game()
	get_tree().change_scene_to_file("res://scene/map/world_map.tscn")
