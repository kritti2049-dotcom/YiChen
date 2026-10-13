extends Control
class_name InteractionHUD

## ตัวจัดการจุดปฏิสัมพันธ์ของฉากเดิน: จำว่าผู้เล่นอยู่ใกล้ InteractableArea ไหนบ้าง
## แสดงปุ่ม "[E] ..." ที่จุดใกล้สุด, กด E / F / คลิกปุ่ม = เรียก trigger() ของจุดนั้น
## จุดที่ตั้ง auto_trigger (เช่น ของดรอปบนพื้น) จะทำงานทันทีที่เดินชน

var player: Node2D
## ปิดการทำงานชั่วคราว (เช่น ตอนเปิดหน้าต่าง UI ทับฉาก)
var blocked := false
var _near: Array[InteractableArea] = []
var _button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_button = Button.new()
	_button.add_theme_font_size_override("font_size", 18)
	_button.custom_minimum_size = Vector2(320, 44)
	_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_button.offset_left = -160
	_button.offset_right = 160
	_button.offset_top = -140
	_button.offset_bottom = -96
	_button.visible = false
	_button.pressed.connect(interact)
	add_child(_button)

## ลงทะเบียนจุดปฏิสัมพันธ์
func track(area: InteractableArea) -> void:
	area.player_entered.connect(_on_enter)
	area.player_exited.connect(_on_exit)
	area.tree_exiting.connect(func(): _on_exit(area))

func _on_enter(area: InteractableArea) -> void:
	if area.auto_trigger:
		area.trigger()
		return
	if not _near.has(area): _near.append(area)
	refresh()

func _on_exit(area: InteractableArea) -> void:
	_near.erase(area)
	refresh()

func nearest() -> InteractableArea:
	var best: InteractableArea = null
	var best_d = INF
	for a in _near:
		if not is_instance_valid(a) or not a.monitoring: continue
		if not is_instance_valid(player): return null
		var d = a.global_position.distance_to(player.global_position)
		if d < best_d:
			best_d = d
			best = a
	return best

func refresh() -> void:
	var a = nearest()
	_button.visible = a != null and not blocked
	if a: _button.text = "[E] " + a.prompt_text

func interact() -> void:
	if blocked: return
	var a = nearest()
	if a: a.trigger()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_E, KEY_F]:
		if not blocked and nearest() != null:
			interact()
			get_viewport().set_input_as_handled()
