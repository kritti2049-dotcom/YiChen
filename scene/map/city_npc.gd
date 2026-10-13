extends Node2D
class_name CityNPC

## บุคคลในเมือง เดินไปมาตามถนน (AStar) มี Area2D รอบตัวเป็นจุดปฏิสัมพันธ์ (เดินไปใกล้แล้วกด [F] คุย)
## role: citizen (ชาวเมือง), gossip (นักเล่าข่าว), spy (สายลับขายความลับ), quest (ผู้ว่าจ้างลับ),
##       wanderer (จอมยุทธ์พเนจร ท้าประลอง), guard (ทหารยามกลางคืน), target (เป้าหมายลอบสังหาร)
## ทหารยาม: มีกรวยการมองเห็น + RayCast2D เช็คว่ามีอาคาร/กำแพงบังหรือไม่ เห็นผู้เล่นนานพอ = ถูกจับได้

signal spotted_player

const SPEED = 42.0
const GUARD_SPEED = 55.0
## ระยะมองเห็นของยาม (ลดลงเมื่อผู้เล่นอยู่ในเงามืด / ย่องเบา) และครึ่งมุมของกรวยสายตา
const VISION_RANGE = 200.0
const VISION_HALF_ANGLE = deg_to_rad(40.0)

var role := "citizen"
var display_name := ""
var data := {}
var layout: CityLayout
var player: CityPlayer
## จุดลาดตระเวน (ยาม) หรือ จุดยืน (เป้าหมาย)
var waypoints: Array[Vector2] = []
var facing := Vector2.DOWN
var alert := 0.0

var area: InteractableArea
var _sprite: Sprite2D
var _label: Label
var _ray: RayCast2D
var _path := PackedVector2Array()
var _wait := 0.0
var _wp := 0
var _t := 0.0
var _rng := RandomNumberGenerator.new()

static func create(p_role: String, p_name: String, texture: Texture2D, p_layout: CityLayout, name_color := Color(0.95, 0.9, 0.8)) -> CityNPC:
	var n = CityNPC.new()
	n.role = p_role
	n.display_name = p_name
	n.layout = p_layout
	n._rng.randomize()
	n._sprite = Sprite2D.new()
	n._sprite.texture = texture
	n._sprite.offset = Vector2(0, -30)
	n._sprite.scale = Vector2(0.9, 0.9)
	n.add_child(n._sprite)
	n._label = Label.new()
	n._label.text = p_name
	n._label.add_theme_font_size_override("font_size", 10)
	n._label.add_theme_color_override("font_color", name_color)
	n._label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	n._label.add_theme_constant_override("outline_size", 3)
	n._label.position = Vector2(-60, -72)
	n._label.size = Vector2(120, 14)
	n._label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.add_child(n._label)
	# จุดปฏิสัมพันธ์ (ยามคุยด้วยไม่ได้)
	n.area = InteractableArea.make("npc", ("ลอบสังหาร " if p_role == "target" else "คุยกับ ") + p_name, Vector2(60, 60), {}, true)
	n.area.monitoring = p_role != "guard"
	n.add_child(n.area)
	if p_role == "guard":
		n._ray = RayCast2D.new()
		n._ray.collision_mask = 1
		n._ray.enabled = true
		n.add_child(n._ray)
	return n

func _process(delta: float) -> void:
	match role:
		"guard", "sentry": _patrol(delta)
		"target": _idle_turn(delta)
		_: _wander(delta)
	if role == "guard" and player != null: _watch(delta)
	if role == "guard" or role == "target": queue_redraw()

func _move_along(delta: float, speed: float) -> bool:
	if _path.is_empty(): return false
	var to = _path[0] - position
	if to.length() < 3.0:
		_path.remove_at(0)
		return true
	var step = to.normalized() * min(speed * delta, to.length())
	position += step
	facing = to.normalized()
	_t += delta * 9.0
	_sprite.position.y = -abs(sin(_t)) * 2.0
	_sprite.flip_h = facing.x < 0
	return true

func _wander(delta: float) -> void:
	if _move_along(delta, SPEED): return
	_sprite.position.y = 0
	_wait -= delta
	if _wait <= 0.0:
		_wait = _rng.randf_range(1.5, 5.0)
		PathService.request(layout, position, CityLayout.cell_to_world(layout.random_street_cell(_rng)), self, func(p): _path = p)

func _patrol(delta: float) -> void:
	if _move_along(delta, GUARD_SPEED): return
	_wait -= delta
	if _wait <= 0.0 and not waypoints.is_empty():
		_wait = 1.2
		_wp = (_wp + 1) % waypoints.size()
		PathService.request(layout, position, waypoints[_wp], self, func(p): _path = p)

## เป้าหมายลอบสังหาร: ยืนหันมองซ้ายขวาเป็นระยะ
func _idle_turn(delta: float) -> void:
	_wait -= delta
	if _wait <= 0.0:
		_wait = _rng.randf_range(2.0, 4.0)
		facing = facing.rotated(PI * 0.5 * (1 if _rng.randf() < 0.5 else -1))
		_sprite.flip_h = facing.x < 0

## ระยะมองเห็นจริง (ผู้เล่นซ่อนในเงา/ย่องเบา = มองเห็นยากขึ้น)
func vision_range() -> float:
	var r = VISION_RANGE
	if player.is_in_shadow(): r *= 0.5
	if player.sneaking: r *= 0.6
	return r

func can_see_player() -> bool:
	var to = player.global_position - global_position
	if to.length() > vision_range(): return false
	if absf(facing.angle_to(to)) > VISION_HALF_ANGLE: return false
	# RayCast2D: มีอาคาร/กำแพงบังสายตาหรือไม่
	_ray.target_position = to
	_ray.force_raycast_update()
	return not _ray.is_colliding()

func _watch(delta: float) -> void:
	if can_see_player():
		var dist = (player.global_position - global_position).length()
		alert += delta * (1.6 if dist < vision_range() * 0.5 else 0.8)
		if alert >= 1.0:
			alert = 1.0
			spotted_player.emit()
	else:
		alert = max(0.0, alert - delta * 0.35)

## วาดกรวยสายตาของยาม (สีเหลือง -> แดงเมื่อใกล้ถูกจับได้)
func _draw() -> void:
	if role != "guard": return
	if player == null: return
	var r = vision_range()
	var pts = PackedVector2Array([Vector2(0, -12)])
	for i in 9:
		var a = -VISION_HALF_ANGLE + VISION_HALF_ANGLE * 2.0 * i / 8.0
		pts.append(Vector2(0, -12) + facing.rotated(a) * r)
	draw_colored_polygon(pts, Color(1.0, 0.9 - alert * 0.7, 0.3 - alert * 0.3, 0.13 + alert * 0.15))
	if alert > 0.05:
		draw_rect(Rect2(-14, -78, 28, 4), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-14, -78, 28 * alert, 4), Color(1, 0.3, 0.2))
