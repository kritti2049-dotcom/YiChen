extends Node2D
class_name CityBuilding

## อาคารในเมืองแบบ 2.5D (มุมมองเฉียง 3/4): ผนังด้านหน้า + หลังคาโค้งแบบจีนคลุมฐานอาคาร
## ตำแหน่งของโหนด = ขอบล่างกึ่งกลางฐาน (ใช้ y-sort ให้ตัวละครเดินหน้า/หลังอาคารได้ถูกต้อง)
## มี StaticBody2D (layer 1) กันเดินทะลุ และบังสายตาทหารยาม

const WALL_H = 34.0

var info: Dictionary
var kind: String
var rect_px: Rect2 # พื้นที่ฐาน (พิกัดภายในโหนด)
var night := false

static func create(b: Dictionary) -> CityBuilding:
	var node = CityBuilding.new()
	node.kind = b.kind
	node.info = CityDB.BUILDINGS[b.kind]
	# สีประจำสำนัก (ผังสำนักใส่สีหลังคา/ผนังทับค่าเริ่มต้น)
	if b.has("roof") or b.has("wall"):
		node.info = node.info.duplicate()
		if b.has("roof"): node.info.roof = b.roof
		if b.has("wall"): node.info.wall = b.wall
	var r: Rect2i = b.rect
	var T = CityLayout.TILE
	node.position = Vector2(r.position.x * T + r.size.x * T / 2.0, r.end.y * T)
	node.rect_px = Rect2(-r.size.x * T / 2.0, -r.size.y * T, r.size.x * T, r.size.y * T)
	var body = StaticBody2D.new()
	body.collision_layer = 1
	var shape = CollisionShape2D.new()
	var box = RectangleShape2D.new()
	box.size = node.rect_px.size - Vector2(4, 4)
	shape.shape = box
	shape.position = node.rect_px.get_center()
	body.add_child(shape)
	node.add_child(body)
	if node.info.service != "" or b.kind == "house":
		# แสงไฟลอดหน้าต่างยามค่ำ
		var light = DayNight.make_light(Color(1, 0.72, 0.4), 0.9 if b.kind == "house" else 1.3, 0.8)
		light.position = Vector2(0, -WALL_H * 0.6)
		node.add_child(light)
	if node.info.service != "":
		var sign = Label.new()
		sign.text = b.name
		sign.add_theme_font_size_override("font_size", 12)
		sign.add_theme_color_override("font_color", Color(1, 0.9, 0.55))
		sign.add_theme_color_override("font_outline_color", Color(0.15, 0.05, 0.02))
		sign.add_theme_constant_override("outline_size", 4)
		sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sign.position = Vector2(-90, node.rect_px.position.y - 40)
		sign.size = Vector2(180, 16)
		node.add_child(sign)
	return node

func _draw() -> void:
	var r = rect_px
	var wall: Color = info.wall
	var roof: Color = info.roof
	var front_top = r.end.y - WALL_H
	if info.get("tent", false):
		_draw_tent(r, wall, roof)
		return
	# เงาบนพื้น
	draw_rect(Rect2(r.position.x + 6, r.end.y - 6, r.size.x, 10), Color(0, 0, 0, 0.25))
	# ผนังด้านหน้า + เสา
	draw_rect(Rect2(r.position.x + 4, front_top, r.size.x - 8, WALL_H), wall)
	for i in int(r.size.x / 32.0) + 1:
		var x = r.position.x + 4 + i * (r.size.x - 8) / max(1, int(r.size.x / 32.0))
		draw_line(Vector2(x, front_top), Vector2(x, r.end.y), wall.darkened(0.45), 3.0)
	# หน้าต่าง (มีแสงไฟตอนกลางคืน)
	var win_col = Color(1, 0.8, 0.4) if night else wall.darkened(0.35)
	for i in range(1, int(r.size.x / 32.0)):
		var x = r.position.x + i * 32 - 6
		if absf(x + 6) < 14: continue
		draw_rect(Rect2(x, front_top + 9, 12, 10), win_col)
	# ประตู
	draw_rect(Rect2(-10, r.end.y - 24, 20, 24), Color(0.2, 0.1, 0.06))
	draw_rect(Rect2(-12, r.end.y - 26, 24, 3), Color(0.55, 0.15, 0.1))
	# หลังคาโค้ง คลุมความลึกของอาคาร
	var eave = 10.0
	var top = r.position.y - 16
	var pts = PackedVector2Array([
		Vector2(r.position.x - eave, front_top + 4), Vector2(r.position.x - eave - 6, front_top - 4),
		Vector2(r.position.x + 6, top), Vector2(r.end.x - 6, top),
		Vector2(r.end.x + eave + 6, front_top - 4), Vector2(r.end.x + eave, front_top + 4),
	])
	draw_colored_polygon(pts, roof)
	# แนวกระเบื้อง
	for i in 6:
		var y = top + (front_top - top) * (i + 1) / 7.0
		draw_line(Vector2(r.position.x - 2, y), Vector2(r.end.x + 2, y), roof.darkened(0.2), 1.5)
	draw_line(Vector2(r.position.x + 6, top), Vector2(r.end.x - 6, top), roof.lightened(0.3), 4.0)
	draw_polyline(PackedVector2Array([Vector2(r.position.x - eave - 6, front_top - 4), Vector2(r.position.x - eave - 12, front_top - 12)]), roof.lightened(0.2), 3.0)
	draw_polyline(PackedVector2Array([Vector2(r.end.x + eave + 6, front_top - 4), Vector2(r.end.x + eave + 12, front_top - 12)]), roof.lightened(0.2), 3.0)
	if kind == "palace":
		draw_rect(Rect2(-40, top - 26, 80, 28), roof.darkened(0.1))
		draw_colored_polygon(PackedVector2Array([Vector2(-58, top - 20), Vector2(-40, top - 40), Vector2(40, top - 40), Vector2(58, top - 20)]), roof)
	elif kind == "arena":
		draw_rect(Rect2(r.position.x + 20, front_top - 10, r.size.x - 40, 8), Color(0.8, 0.2, 0.15))

func _draw_tent(r: Rect2, wall: Color, roof: Color) -> void:
	var c = Vector2(0, r.end.y - r.size.y * 0.35)
	draw_rect(Rect2(r.position.x + 6, r.end.y - 6, r.size.x - 4, 8), Color(0, 0, 0, 0.22))
	draw_rect(Rect2(r.position.x + 4, c.y - 6, r.size.x - 8, r.end.y - c.y + 6), wall)
	draw_colored_polygon(PackedVector2Array([Vector2(r.position.x, c.y), Vector2(0, r.position.y - 10), Vector2(r.end.x, c.y)]), roof)
	draw_rect(Rect2(-9, r.end.y - 20, 18, 20), Color(0.25, 0.15, 0.1))
	draw_line(Vector2(0, r.position.y - 10), Vector2(0, r.position.y - 24), Color(0.4, 0.3, 0.2), 2.0)
