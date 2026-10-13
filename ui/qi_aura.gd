extends Node2D
class_name QiAura

## ออร่าลมปราณวนรอบตัวศิษย์ สีตามธาตุ ความหนาแน่น/ขนาดตามระดับขั้น
## ใช้: var aura = QiAura.create(disciple, 18.0); some_control.add_child(aura)

var particles: CPUParticles2D

static func create(d: DiscipleData, radius: float = 18.0) -> QiAura:
	var aura = QiAura.new()
	var major = CultivationSys.get_realm_info(d.level).major_index
	aura.setup(CultivationSys.get_aura_color(d.element, d.level), radius, major)
	return aura

func setup(color: Color, radius: float, intensity: int) -> void:
	particles = CPUParticles2D.new()
	particles.amount = 10 + intensity * 6
	particles.lifetime = 1.6
	particles.preprocess = 1.6
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE_SURFACE
	particles.emission_sphere_radius = radius
	particles.direction = Vector2.UP
	particles.spread = 30.0
	particles.gravity = Vector2(0, -15)
	particles.initial_velocity_min = 4.0
	particles.initial_velocity_max = 12.0 + intensity * 2.0
	# วนรอบตัว
	particles.orbit_velocity_min = 0.15
	particles.orbit_velocity_max = 0.3
	particles.scale_amount_min = 1.5
	particles.scale_amount_max = 3.0 + intensity * 0.4

	var ramp = Gradient.new()
	ramp.set_color(0, Color(color, 0.0))
	ramp.add_point(0.2, Color(color, 0.85))
	ramp.set_color(ramp.get_point_count() - 1, Color(color.lightened(0.3), 0.0))
	particles.color_ramp = ramp
	add_child(particles)
