extends Area2D
class_name InteractableArea

## จุดปฏิสัมพันธ์สำเร็จรูป (ใช้ร่วมกันทุกฉากเดิน: สำนัก / เมือง / พื้นที่สำรวจ)
## วางทับหน้าประตูอาคาร ตัว NPC หรือของบนพื้น เมื่อผู้เล่น (collision layer 2) เดินเข้ามาในระยะ
## จะยิง player_entered / player_exited ฉากหลักใช้แสดงปุ่ม "[E] ..." และเรียก interacted เมื่อกด
## ใช้ผ่านฉาก res://ui/interactable_area.tscn หรือ InteractableArea.make(...)

signal player_entered(area: InteractableArea)
signal player_exited(area: InteractableArea)
signal interacted(area: InteractableArea)

const SCENE_PATH = "res://ui/interactable_area.tscn"

## ข้อความบนปุ่ม เช่น "เข้า หอหลอมโอสถ"
@export var prompt_text: String = "ตรวจสอบ"
## ชนิดของจุด (door / npc / exit / loot / building ...) ฉากหลักใช้ตัดสินใจว่าจะทำอะไร
@export var action: String = ""
## เก็บผ่านโดยอัตโนมัติเมื่อเดินชน (ไม่ต้องกดปุ่ม) เช่น ของดรอปบนพื้น
@export var auto_trigger: bool = false
## ข้อมูลเพิ่มเติม (เช่น service id, NPC, building id)
var payload: Dictionary = {}

static func make(p_action: String, text: String, size: Vector2, p_payload := {}, round_shape := false) -> InteractableArea:
	var a: InteractableArea = load(SCENE_PATH).instantiate()
	a.action = p_action
	a.prompt_text = text
	a.payload = p_payload
	var shape: CollisionShape2D = a.get_node("Shape")
	if round_shape:
		var c = CircleShape2D.new()
		c.radius = size.x / 2.0
		shape.shape = c
	else:
		var r = RectangleShape2D.new()
		r.size = size
		shape.shape = r
	return a

func _ready() -> void:
	body_entered.connect(func(b): if b is CharacterBody2D and b.collision_layer & 2: player_entered.emit(self))
	body_exited.connect(func(b): if b is CharacterBody2D and b.collision_layer & 2: player_exited.emit(self))

func trigger() -> void:
	interacted.emit(self)
