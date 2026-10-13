extends Node2D
class_name FieldMonster

## มอนสเตอร์บนพื้นที่สำรวจ (Overworld Encounter)
## - Area2D ระยะสายตา: ผู้เล่นเดินเข้ามาในวง = วิ่งไล่ (ผู้เล่นที่ย่องเบาจะถูกสังเกตเห็นในระยะครึ่งเดียว)
## - Area2D ตัว: ชนผู้เล่น = ยิง encountered -> ฉากหลักตัดเข้าฉากต่อสู้ (กลุ่มศัตรู 1-3 ตัวตาม group)
## - ไม่เห็นผู้เล่น = เดินเตร็ดเตร่รอบจุดเกิด ไล่ไปไกลเกินไปจะยอมแพ้กลับที่เดิม

signal encountered(monster: FieldMonster)

const WANDER_SPEED = 35.0
const CHASE_SPEED = 105.0
const SIGHT = 150.0
const LEASH = 420.0

var monster_id: String
var enemy_id: String
## รายชื่อศัตรูในกลุ่ม (id จาก EnemyDB)
var group: Array[String] = []
var layout: FieldLayout
var player: CityPlayer
var home: Vector2
var chasing := false

var _sprite: Sprite2D
var _sight: Area2D
var _touch: Area2D
var _alert_label: Label
var _path := PackedVector2Array()
var _wait := 0.0
var _repath := 0.0
var _t := 0.0
var _rng := RandomNumberGenerator.new()
var _fired := false

static func create(p_id: String, p_enemy: String, count: int, p_layout: FieldLayout) -> FieldMonster:
	var m = FieldMonster.new()
	m.monster_id = p_id
	m.enemy_id = p_enemy
	for i in count: m.group.append(p_enemy)
	m.layout = p_layout
	m._rng.seed = hash(p_id)
	var e = EnemyDB.ENEMIES[p_enemy]
	m._sprite = Sprite2D.new()
	m._sprite.texture = EnemyDB.get_texture(EnemyDB.get_enemy(p_enemy))
	m._sprite.offset = Vector2(0, -m._sprite.texture.get_height() / 2.0)
	m._sprite.scale = Vector2(0.85, 0.85) if e.art == "human" else Vector2(0.75, 0.75)
	m.add_child(m._sprite)
	var label = Label.new()
	label.text = "%s%s · พลัง ~%d" % [e.name, (" x%d" % count) if count > 1 else "", EnemyDB.get_power(p_enemy) * count]
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(1, 0.6, 0.5))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 3)
	label.position = Vector2(-80, -m._sprite.texture.get_height() * 0.85 - 18)
	label.size = Vector2(160, 14)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	m.add_child(label)
	m._alert_label = Label.new()
	m._alert_label.text = "!"
	m._alert_label.add_theme_font_size_override("font_size", 22)
	m._alert_label.add_theme_color_override("font_color", Color(1, 0.3, 0.2))
	m._alert_label.position = Vector2(-5, label.position.y - 26)
	m._alert_label.visible = false
	m.add_child(m._alert_label)
	m._sight = m._make_area(SIGHT)
	m._touch = m._make_area(18.0)
	return m

func _make_area(radius: float) -> Area2D:
	var a = Area2D.new()
	a.collision_layer = 0
	a.collision_mask = 2
	a.monitorable = false
	var shape = CollisionShape2D.new()
	var c = CircleShape2D.new()
	c.radius = radius
	shape.shape = c
	a.add_child(shape)
	add_child(a)
	return a

func _ready() -> void:
	home = position
	_sight.body_entered.connect(func(b):
		if b == player:
			# ย่องเบาจะถูกสังเกตเห็นเมื่อเข้ามาใกล้กว่าครึ่งระยะเท่านั้น (ตรวจใน _process)
			chasing = not player.sneaking
			_alert_label.visible = chasing)
	_touch.body_entered.connect(func(b):
		if b == player and not _fired:
			_fired = true
			encountered.emit(self))

func _process(delta: float) -> void:
	if player == null: return
	var to_player = player.global_position - global_position
	if not chasing and player.sneaking and to_player.length() < SIGHT * 0.5:
		chasing = true
		_alert_label.visible = true
	if chasing and (global_position.distance_to(home) > LEASH or to_player.length() > SIGHT * 2.2):
		chasing = false
		_alert_label.visible = false
		_path = layout.find_path(position, home)
	if chasing:
		_repath -= delta
		if _repath <= 0.0:
			_repath = 0.35
			PathService.request(layout, position, player.global_position, self, _set_chase_path)
		_move(delta, CHASE_SPEED)
	elif not _move(delta, WANDER_SPEED):
		_wait -= delta
		if _wait <= 0.0:
			_wait = _rng.randf_range(1.5, 4.0)
			var c = FieldLayout.world_to_cell(home) + Vector2i(_rng.randi_range(-3, 3), _rng.randi_range(-3, 3))
			if layout.is_walkable(c): PathService.request(layout, position, FieldLayout.cell_to_world(c), self, func(p): _path = p)

func _set_chase_path(p: PackedVector2Array) -> void:
	_path = p
	if not _path.is_empty(): _path.remove_at(0)

func _move(delta: float, speed: float) -> bool:
	if _path.is_empty():
		_sprite.position.y = 0
		return false
	var to = _path[0] - position
	if to.length() < 3.0:
		_path.remove_at(0)
		return true
	position += to.normalized() * min(speed * delta, to.length())
	_t += delta * 10.0
	_sprite.position.y = -abs(sin(_t)) * 2.0
	_sprite.flip_h = to.x < 0
	return true
