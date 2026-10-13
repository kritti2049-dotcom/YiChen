extends Control
class_name AlchemyMinigame

## มินิเกมหลอมโอสถ: คุมอุณหภูมิเตาให้อยู่ใน "โซนไฟพอดี" ที่เคลื่อนไหวไปมา
## กดค้างปุ่ม [เติมไฟ] หรือ Spacebar เพื่อเร่งไฟ ปล่อยเพื่อให้เตาเย็นลง
## ยิ่งอยู่ในโซนนาน คุณภาพยายิ่งสูง  (-1 = ล้มเหลว, 0-3 = ขั้นต่ำ..ขั้นสมบูรณ์)

signal finished(quality: int)

const DURATION = 12.0
const HEAT_RATE = 0.55
const COOL_RATE = 0.38

var pill_name: String = ""
var zone_width: float = 0.2

var _temp: float = 0.2
var _elapsed: float = 0.0
var _in_zone_time: float = 0.0
var _running: bool = false
var _heating_button: bool = false

var _gauge: Control
var _info: Label
var _btn_heat: Button
var _btn_start: Button

func setup(p_pill_name: String, p_zone_width: float) -> void:
	pill_name = p_pill_name
	zone_width = p_zone_width

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 420)
	center.add_child(panel)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)

	v.add_child(UIKit.label("หอหลอมโอสถ: %s" % pill_name, 24, WuxiaTheme.BRONZE.lightened(0.2)))
	v.add_child(UIKit.label("กดค้าง [เติมไฟ] หรือ Spacebar เพื่อเร่งไฟ ปล่อยเพื่อลดไฟ\nคุมเข็มอุณหภูมิให้อยู่ในโซนสีเขียว (โซนจะเลื่อนไปมา) ตลอด %d วินาที" % int(DURATION), 15, WuxiaTheme.PAPER_DIM))

	_gauge = Control.new()
	_gauge.custom_minimum_size = Vector2(580, 70)
	_gauge.draw.connect(_draw_gauge)
	v.add_child(_gauge)

	_info = UIKit.label("พร้อมเมื่อไหร่ กด [จุดเตา]", 18)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_info)

	var h = HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 20)
	v.add_child(h)
	_btn_start = UIKit.button("จุดเตา", _start)
	_btn_start.custom_minimum_size = Vector2(160, 50)
	h.add_child(_btn_start)
	_btn_heat = Button.new()
	_btn_heat.text = "เติมไฟ"
	_btn_heat.custom_minimum_size = Vector2(200, 60)
	_btn_heat.disabled = true
	_btn_heat.button_down.connect(func(): _heating_button = true)
	_btn_heat.button_up.connect(func(): _heating_button = false)
	h.add_child(_btn_heat)

func _start() -> void:
	_running = true
	_btn_start.disabled = true
	_btn_heat.disabled = false
	_btn_heat.grab_focus()

func _zone_center() -> float:
	return clamp(0.5 + 0.25 * sin(_elapsed * 0.9) + 0.1 * sin(_elapsed * 2.3 + 1.0), zone_width / 2.0, 1.0 - zone_width / 2.0)

func _process(delta: float) -> void:
	if not _running: return
	_elapsed += delta
	var heating = _heating_button or Input.is_key_pressed(KEY_SPACE)
	_temp = clamp(_temp + (HEAT_RATE if heating else -COOL_RATE) * delta, 0.0, 1.0)
	if abs(_temp - _zone_center()) <= zone_width / 2.0:
		_in_zone_time += delta
	var ratio = _in_zone_time / max(_elapsed, 0.001)
	_info.text = "เวลา %.1f / %d วินาที   |   ความแม่นยำ %d%%" % [_elapsed, int(DURATION), int(ratio * 100)]
	_gauge.queue_redraw()
	if _elapsed >= DURATION:
		_finish()

func _finish() -> void:
	_running = false
	_btn_heat.disabled = true
	var ratio = _in_zone_time / DURATION
	var quality = -1
	if ratio >= 0.93: quality = 3
	elif ratio >= 0.8: quality = 2
	elif ratio >= 0.6: quality = 1
	elif ratio >= 0.35: quality = 0

	if quality >= 0:
		var color: Color = RecipeDB.PILL_QUALITY_COLORS[quality]
		_info.text = "หลอมสำเร็จ! ความแม่นยำ %d%% ได้ %s [%s]%s" % [int(ratio * 100), pill_name, RecipeDB.PILL_QUALITY_NAMES[quality], "  PERFECT!" if quality == 3 else ""]
		_info.add_theme_color_override("font_color", color)
		VFX.burst(self, size / 2.0, color, 50)
	else:
		_info.text = "ไฟไม่สม่ำเสมอ (ความแม่นยำ %d%%) วัตถุดิบไหม้เป็นเถ้าถ่าน..." % int(ratio * 100)
		_info.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
	_btn_start.text = "ปิด"
	_btn_start.disabled = false
	_btn_start.pressed.disconnect(_start)
	_btn_start.pressed.connect(func():
		finished.emit(quality)
		queue_free())

func _draw_gauge() -> void:
	var w = _gauge.size.x
	var h = _gauge.size.y
	# ราง
	_gauge.draw_rect(Rect2(0, 20, w, 30), Color(0.12, 0.08, 0.06))
	# ไล่สีความร้อนจากเย็นไปร้อน
	for i in 20:
		var t = i / 20.0
		_gauge.draw_rect(Rect2(w * t, 44, w / 20.0 + 1, 6), Color(0.3, 0.4, 0.9).lerp(Color(1, 0.3, 0.1), t))
	# โซนไฟพอดี
	var zc = _zone_center()
	_gauge.draw_rect(Rect2(w * (zc - zone_width / 2.0), 20, w * zone_width, 24), Color(0.3, 0.9, 0.4, 0.55))
	# เข็มอุณหภูมิ
	var x = w * _temp
	_gauge.draw_line(Vector2(x, 10), Vector2(x, h - 6), Color(1, 0.95, 0.8), 4)
	_gauge.draw_circle(Vector2(x, 10), 7, Color(1, 0.6, 0.2))
