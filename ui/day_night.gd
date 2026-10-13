extends CanvasModulate
class_name DayNight

## แสงตามเวลาในเกม (ใช้กับทุกฉาก 2.5D: สำนัก / เมือง / พื้นที่สำรวจ)
## อ่านชั่วโมงจากนาฬิกา 3 ช่วงของ GlobalGame (เช้า 6-12, บ่าย 12-18, กลางคืน 18-24)
## เช้าตรู่สว่างอมส้ม -> กลางวันสีปกติ -> เย็นสีทอง -> กลางคืนสีน้ำเงินมืด
## โหนดในกลุ่ม "night_light" (PointLight2D ของโคมไฟ/หน้าต่าง) จะเปิดเองเมื่อฟ้ามืด

const KEYS = [
	[6.0, Color(1.0, 0.78, 0.6)],
	[8.5, Color(1.0, 0.92, 0.8)],
	[11.0, Color(1, 1, 1)],
	[15.5, Color(1, 1, 1)],
	[17.5, Color(1.0, 0.82, 0.6)],
	[19.0, Color(0.55, 0.55, 0.8)],
	[21.0, Color(0.3, 0.34, 0.58)],
	[24.0, Color(0.26, 0.3, 0.52)],
]
## ชั่วโมงที่โคมไฟเริ่มติด
const LIGHTS_ON_HOUR = 17.8
## ความมืดเพิ่มเติม (เช่น ในถ้ำ/ดันเจี้ยน)
var darkness := 0.0
var _lights_on := false
var _light_count := -1

static func color_at(hour: float) -> Color:
	for i in range(KEYS.size() - 1):
		if hour <= KEYS[i + 1][0]:
			return KEYS[i][1].lerp(KEYS[i + 1][1], clampf((hour - KEYS[i][0]) / (KEYS[i + 1][0] - KEYS[i][0]), 0.0, 1.0))
	return KEYS[-1][1]

func _process(_delta: float) -> void:
	var h = GlobalGame.get_hour()
	color = color_at(h).darkened(darkness)
	var on = h >= LIGHTS_ON_HOUR or darkness > 0.3
	var count = get_tree().get_node_count_in_group("night_light")
	if on != _lights_on or count != _light_count:
		_lights_on = on
		_light_count = count
		for l in get_tree().get_nodes_in_group("night_light"):
			l.enabled = on

func lights_on() -> bool:
	return _lights_on

## แสงจุด (PointLight2D) แบบวงกลมนุ่ม ใช้กับโคมไฟ/หน้าต่าง/คบเพลิง ใส่กลุ่ม night_light ให้แล้ว
static func make_light(color := Color(1, 0.75, 0.45), scale := 1.6, energy := 1.1) -> PointLight2D:
	var light = PointLight2D.new()
	light.texture = _soft_texture()
	light.color = color
	light.energy = energy
	light.texture_scale = scale
	light.enabled = false
	light.add_to_group("night_light")
	return light

static var _tex: Texture2D
static func _soft_texture() -> Texture2D:
	if _tex == null:
		var g = Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var t = GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 128
		t.height = 128
		_tex = t
	return _tex
