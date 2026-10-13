extends Control
class_name InkLandscape

## ฉากหลังภาพวาดพู่กันจีน (Ink Wash): ท้องฟ้า, ดวงอาทิตย์/ดวงจันทร์, ทิวเขา 3 ชั้น, ม่านหมอก
## สีแสงเปลี่ยนตามเวลาในวัน (hour 6-23) ผ่าน TimeSys

var hour: float = 6.0:
	set(v):
		hour = v
		queue_redraw()

var _ridges: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng = RandomNumberGenerator.new()
	rng.seed = 7741
	for layer in 3:
		var pts: Array[float] = []
		var h = 0.5
		for i in 33:
			h = clamp(h + rng.randf_range(-0.18, 0.18), 0.1, 1.0)
			pts.append(h)
		_ridges.append(pts)
	resized.connect(queue_redraw)

func _draw() -> void:
	var light = TimeSys.get_light(hour)
	var w = size.x
	var h = size.y

	# ท้องฟ้าไล่สี (วาดเป็นแถบ)
	var bands = 24
	for i in bands:
		var t = float(i) / bands
		var c = light.sky_top.lerp(light.sky_bottom, t)
		draw_rect(Rect2(0, h * t, w, h / bands + 1), c)

	# ดวงอาทิตย์ / ดวงจันทร์ เคลื่อนเป็นวงโค้งตามเวลา
	var t_sun = clamp((hour - 6.0) / 13.0, 0.0, 1.0)
	if hour < 19.0:
		var sun_pos = Vector2(w * (0.1 + 0.8 * t_sun), h * (0.42 - 0.3 * sin(t_sun * PI)))
		draw_circle(sun_pos, 46, Color(light.sun, 0.18))
		draw_circle(sun_pos, 26, light.sun)
	else:
		var t_moon = clamp((hour - 19.0) / 5.0, 0.0, 1.0)
		var moon_pos = Vector2(w * (0.2 + 0.6 * t_moon), h * (0.3 - 0.15 * sin(t_moon * PI)))
		draw_circle(moon_pos, 40, Color(0.85, 0.9, 1.0, 0.1))
		draw_circle(moon_pos, 20, Color(0.92, 0.94, 1.0))
		draw_circle(moon_pos + Vector2(8, -5), 17, light.sky_top) # จันทร์เสี้ยว

	# ทิวเขา 3 ชั้น (ไกล -> ใกล้) สีหมึกจางไปเข้ม
	for layer in 3:
		var base_y = h * (0.45 + layer * 0.12)
		var amp = h * (0.22 - layer * 0.04)
		var ink = light.ink.lerp(light.sky_bottom, 0.55 - layer * 0.25)
		var poly = PackedVector2Array([Vector2(0, h)])
		var pts: Array = _ridges[layer]
		for i in pts.size():
			poly.append(Vector2(w * i / float(pts.size() - 1), base_y - pts[i] * amp))
		poly.append(Vector2(w, h))
		draw_colored_polygon(poly, ink)
		# ม่านหมอกระหว่างชั้นเขา
		draw_rect(Rect2(0, base_y - amp * 0.1, w, amp * 0.35), Color(light.mist, 0.12))

	# ม่านทับทั้งฉาก (มืดลงตอนกลางคืน)
	if light.overlay.a > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), light.overlay)
