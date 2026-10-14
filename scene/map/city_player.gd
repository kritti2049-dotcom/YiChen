extends CharacterBody2D
class_name CityPlayer

## ตัวละครอวตารของผู้เล่นในเมือง
## - เดิน 8 ทิศด้วย WASD / ลูกศร (Shift = วิ่ง, C = ย่องเบา) หรือคลิกเมาส์เพื่อเดินไปยังจุดนั้น (Point & Click ด้วย AStar)
## - Camera2D ติดตามตัวละคร
## - อยู่บน collision layer 2 (ทหารยามใช้ RayCast2D มองผ่านเฉพาะ layer 1 = อาคาร/กำแพง)
## - ความเร็วเดินผูกกับค่าพลังของศิษย์ (ความว่องไว + วิชาตัวเบา ดู StatSys.walk_speed_mult)
## - ใช้ได้ทุกฉากเดิน: layout ต้องมี find_path(from, to), is_shadow(cell), size_px()

const SPEED = 130.0
const RUN_MULT = 1.6
const SNEAK_MULT = 0.5

var layout
var disciple: DiscipleData
var speed_mult := 1.0
var sneaking := false
var _path := PackedVector2Array()
var _sprite: Sprite2D
## ทิศที่ปุ่ม D (ขวา) และ W (หน้า) พาไป ในพิกัดโลก 2D (ฉาก 3D ที่หมุนกล้องได้ตั้งค่านี้)
var move_right := Vector2.RIGHT
var move_forward := Vector2.UP
var _t := 0.0

static func create(d: DiscipleData, p_layout) -> CityPlayer:
	var p = CityPlayer.new()
	p.layout = p_layout
	p.disciple = d
	p.speed_mult = StatSys.walk_speed_mult(d)
	p.collision_layer = 2
	p.collision_mask = 1
	p.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 9.0
	shape.shape = circle
	p.add_child(shape)
	p._sprite = Sprite2D.new()
	p._sprite.texture = ArtGen.get_figure(d)
	p._sprite.offset = Vector2(0, -30)
	p._sprite.scale = Vector2(0.95, 0.95)
	p.add_child(p._sprite)
	var cam = Camera2D.new()
	cam.name = "Camera"
	cam.zoom = Vector2(1.5, 1.5)
	cam.position_smoothing_enabled = true
	var b: Rect2 = p_layout.bounds() if p_layout.has_method("bounds") else Rect2(Vector2(0, -40), p_layout.size_px() + Vector2(0, 40))
	cam.limit_left = int(b.position.x)
	cam.limit_top = int(b.position.y)
	cam.limit_right = int(b.end.x)
	cam.limit_bottom = int(b.end.y)
	p.add_child(cam)
	return p

## คลิกเพื่อเดินไปยังจุดหมาย
func walk_to(target: Vector2) -> void:
	_path = layout.find_path(global_position, target)
	if not _path.is_empty(): _path.remove_at(0)

func toggle_sneak() -> void:
	sneaking = not sneaking
	_sprite.modulate = Color(0.55, 0.6, 0.75, 0.75) if sneaking else Color.WHITE

func is_in_shadow() -> bool:
	return layout.is_shadow(layout.world_to_cell(global_position))

func _physics_process(delta: float) -> void:
	var input = Vector2(
		float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)),
		float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)))
	var speed = SPEED * speed_mult * (SNEAK_MULT if sneaking else (RUN_MULT if Input.is_key_pressed(KEY_SHIFT) else 1.0))
	if input != Vector2.ZERO:
		_path.clear()
		velocity = (move_right * input.x + move_forward * -input.y).normalized() * speed
	elif not _path.is_empty():
		var to = _path[0] - global_position
		if to.length() < 4.0:
			_path.remove_at(0)
			velocity = Vector2.ZERO
		else:
			velocity = to.normalized() * speed
	else:
		velocity = Vector2.ZERO
	move_and_slide()
	# เดินกระเด้ง + หันซ้ายขวา
	if velocity.length() > 1.0:
		_t += delta * (6.0 if sneaking else 11.0)
		_sprite.position.y = -abs(sin(_t)) * 2.5
		if absf(velocity.x) > 1.0: _sprite.flip_h = velocity.x < 0
	else:
		_sprite.position.y = 0
