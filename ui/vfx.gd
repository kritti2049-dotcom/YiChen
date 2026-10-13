extends RefCounted
class_name VFX

## เอฟเฟกต์ภาพ: สั่นจอ, แสงวาบ, ฟ้าผ่า (ทัณฑ์สวรรค์), ระเบิดปราณ

static func screen_shake(target: Control, strength: float = 12.0, duration: float = 0.5) -> void:
	var origin = target.position
	var tw = target.create_tween()
	var steps = int(duration / 0.04)
	for i in steps:
		var falloff = 1.0 - float(i) / steps
		var offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * strength * falloff
		tw.tween_property(target, "position", origin + offset, 0.04)
	tw.tween_property(target, "position", origin, 0.04)

static func flash(parent: Control, color: Color = Color(1, 1, 1, 0.8), duration: float = 0.35) -> void:
	var rect = ColorRect.new()
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(rect)
	var tw = rect.create_tween()
	tw.tween_property(rect, "modulate:a", 0.0, duration)
	tw.tween_callback(rect.queue_free)

## สายฟ้าฟาดจากขอบบนจอลงที่ to_point
static func lightning(parent: Control, to_point: Vector2, color: Color = Color(0.75, 0.8, 1.0)) -> void:
	var points = PackedVector2Array()
	var start = Vector2(to_point.x + randf_range(-120, 120), -10)
	var segments = 12
	for i in segments + 1:
		var t = float(i) / segments
		var p = start.lerp(to_point, t)
		if i > 0 and i < segments:
			p.x += randf_range(-28, 28)
		points.append(p)

	for layer in [[16.0, Color(color, 0.25)], [7.0, Color(color, 0.6)], [3.0, Color(1, 1, 1, 1)]]:
		var line = Line2D.new()
		line.points = points
		line.width = layer[0]
		line.default_color = layer[1]
		line.joint_mode = Line2D.LINE_JOINT_ROUND
		parent.add_child(line)
		var tw = line.create_tween()
		tw.tween_property(line, "modulate:a", 0.0, 0.45).set_delay(0.08)
		tw.tween_callback(line.queue_free)
	flash(parent, Color(color, 0.55), 0.3)

## ระเบิดอนุภาคปราณ ณ ตำแหน่ง pos
static func burst(parent: Node, pos: Vector2, color: Color, amount: int = 70) -> void:
	var p = CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = 1.2
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 320.0
	p.damping_min = 120.0
	p.damping_max = 200.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 6.0
	var ramp = Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.add_point(0.25, color)
	ramp.set_color(ramp.get_point_count() - 1, Color(color, 0.0))
	p.color_ramp = ramp
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)

## ฉากทะลวงคอขวด: สั่นจอ + ระเบิดปราณ + (ถ้าขั้นสูง) ทัณฑ์อัสนีสวรรค์หลายสาย
static func breakthrough(parent: Control, color: Color, with_tribulation: bool, strikes: int = 3) -> void:
	var center = parent.size / 2.0
	if with_tribulation:
		for i in strikes:
			lightning(parent, center + Vector2(randf_range(-60, 60), randf_range(-20, 40)))
			screen_shake(parent, 18.0, 0.35)
			await parent.get_tree().create_timer(0.45).timeout
	screen_shake(parent, 10.0, 0.5)
	burst(parent, center, color)
	flash(parent, Color(color, 0.4), 0.6)
