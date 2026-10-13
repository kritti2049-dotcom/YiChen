extends Node2D

## ฉากต่อสู้แบบกราฟิก: ฝั่งซ้าย = สำนักเรา, ฝั่งขวา = ศัตรู
## ตัวละครเป็น Sprite2D, ใช้วิชาแล้วมีเอฟเฟกต์ตามประเภท (กระบี่บิน, คลื่นฝ่ามือ, เข็มลับ, หมอกพิษ, ค่ายกล, ปราณฟื้นฟู)
## พร้อมตัวเลขดาเมจเด้งขึ้นมา (Floating Damage Text) และคลิกที่ศัตรูเพื่อเลือกเป้าหมาย
## สถานะผิดปกติ: สกัดจุด (ขยับไม่ได้ 3 เทิร์น), พิษ (เสีย HP ทุกเทิร์น), พิษกู่ (ติดตัวหลังจบการต่อสู้ ต้องให้หมอรักษา)
## ค่าพลังทุกตัวมาจาก StatSys (รากฐาน x ขั้นบำเพ็ญ + อุปกรณ์) ทั้งศิษย์และศัตรู
## ใช้วิชา/โจมตีด้วยอาวุธ = ได้ EXP ความชำนาญอาวุธสายนั้น (MasterySys)

const STATUS_NAMES = { "seal": "สกัดจุด", "poison": "พิษ", "gu": "พิษกู่" }

@onready var log_box: RichTextLabel = %LogBox
@onready var turn_label: Label = %TurnLabel
@onready var btn_attack: Button = %BtnAttack
@onready var btn_skill: Button = %BtnSkill
@onready var btn_flee: Button = %BtnFlee
@onready var result_panel: Control = %ResultPanel
@onready var result_label: Label = %ResultLabel

var allies: Array = []
var enemies: Array = []
var turn_queue: Array = []

var current_actor: Dictionary = {}
var current_turn: int = 1
var is_combat_over: bool = false
var selected_target: Dictionary = {}
var _busy := false

func _ready() -> void:
	btn_attack.pressed.connect(_on_attack_pressed)
	btn_skill.pressed.connect(_on_skill_pressed)
	btn_flee.pressed.connect(_on_flee_pressed)
	%BtnReturn.pressed.connect(_on_return_pressed)
	%Landscape.hour = 15.0
	%Arena.draw.connect(_draw_ground)

	_init_combatants()
	_layout_units()
	_update_ui()
	_start_next_round()

# ══════════════════════════════════════════
# สร้างตัวละครบนสนาม
# ══════════════════════════════════════════

func _init_combatants() -> void:
	allies.clear()
	for d in GlobalGame.combat_allies:
		# รวมโบนัสจากขั้นพลังและอุปกรณ์สวมใส่
		var hp = d.get_combat_max_hp()
		allies.append(_make_combatant({
			"name": d.disciple_name, "is_ally": true, "hp": hp, "max_hp": hp,
			"atk": d.get_combat_attack(), "def": d.get_combat_defense(), "spd": d.get_combat_speed(),
			"passives": d.get_passives(), "ref": d,
			"color": CultivationSys.get_aura_color(d.element, d.level),
		}, ArtGen.get_figure(d)))

	enemies.clear()
	var mult: float = BuildingDB.diff(GlobalGame.current_sect.difficulty).enemy
	for e in GlobalGame.combat_enemies:
		# ความยากส่งผลกับความแข็งแกร่งของศัตรู
		e.max_hp = int(e.get("max_hp", 100) * mult)
		e.attack = int(e.get("attack", 10) * mult)
		e.defense = int(e.get("defense", 5) * mult)
		var ehp = e.get("max_hp", 100)
		enemies.append(_make_combatant({
			"name": e.get("name", "ศัตรู"), "is_ally": false, "hp": ehp, "max_hp": ehp,
			"atk": e.get("attack", 10), "def": e.get("defense", 5), "spd": e.get("speed", 10),
			"passives": [], "ref": e, "color": Color(0.9, 0.3, 0.3), "status_attack": e.get("status_attack", ""),
		}, EnemyDB.get_texture(e)))
	if not enemies.is_empty():
		selected_target = enemies[0]
	_log_msg("[color=yellow]=== เริ่มการต่อสู้ชี้ชะตา! ===[/color] (คลิกที่ศัตรูเพื่อเลือกเป้าหมาย)")

func _make_combatant(data: Dictionary, texture: Texture2D) -> Dictionary:
	data["shield"] = 0
	data["last_stand_used"] = false
	data["skill_cd"] = 0
	data["status"] = {}
	var node = Node2D.new()
	var ring = Node2D.new()
	ring.name = "Ring"
	ring.draw.connect(func(): _draw_ring(ring, data))
	node.add_child(ring)
	var sprite = Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = texture
	sprite.scale = Vector2(1.7, 1.7)
	sprite.offset = Vector2(0, -texture.get_height() / 2.0)
	node.add_child(sprite)
	var top = -texture.get_height() * 1.7 - 8
	var bar = ProgressBar.new()
	bar.name = "HP"
	bar.show_percentage = false
	bar.position = Vector2(-45, top - 12)
	bar.size = Vector2(90, 10)
	bar.max_value = data.max_hp
	bar.value = data.hp
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(bar)
	var label = Label.new()
	label.text = data.name
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_color", Color(0.6, 1, 0.6) if data.is_ally else Color(1, 0.6, 0.55))
	label.position = Vector2(-70, top - 34)
	label.size = Vector2(140, 20)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.add_child(label)
	var status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 11)
	status_label.add_theme_color_override("font_color", Color(0.85, 0.6, 1))
	status_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	status_label.add_theme_constant_override("outline_size", 3)
	status_label.position = Vector2(-70, 4)
	status_label.size = Vector2(140, 16)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.add_child(status_label)
	data["status_label"] = status_label
	data["node"] = node
	data["sprite"] = sprite
	data["bar"] = bar
	data["ring"] = ring
	%Arena.add_child(node)
	return data

func _layout_units() -> void:
	var vs = get_viewport_rect().size
	for group in [[allies, vs.x * 0.24, 1], [enemies, vs.x * 0.66, -1]]:
		var list: Array = group[0]
		var n = list.size()
		# ยืนสลับฟันปลา 2 แถว ให้ชื่อ/หลอดเลือดไม่ทับกัน
		var spacing = min(115.0, 260.0 / max(1, n - 1))
		for i in n:
			var u: Dictionary = list[i]
			var pos = Vector2(group[1] - group[2] * (i % 2) * 120, vs.y * 0.5 + (i - (n - 1) / 2.0) * spacing)
			u.home = pos
			u.node.position = pos
	%Arena.queue_redraw()

func _draw_ground() -> void:
	var vs = get_viewport_rect().size
	%Arena.draw_rect(Rect2(0, vs.y * 0.36, vs.x, vs.y * 0.64), Color(0.32, 0.3, 0.24, 0.55))
	for i in 3:
		%Arena.draw_line(Vector2(0, vs.y * (0.4 + i * 0.13)), Vector2(vs.x, vs.y * (0.42 + i * 0.13)), Color(0.15, 0.12, 0.08, 0.25), 2.0)

func _draw_ring(ring: Node2D, data: Dictionary) -> void:
	if data.hp <= 0: return
	var color = Color(0, 0, 0, 0)
	if is_same(data, current_actor): color = Color(1, 0.85, 0.3, 0.9)
	elif is_same(data, selected_target): color = Color(1, 0.25, 0.2, 0.9)
	ring.draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.35))
	ring.draw_circle(Vector2.ZERO, 34, Color(0, 0, 0, 0.3))
	if color.a > 0:
		ring.draw_arc(Vector2.ZERO, 38, 0, TAU, 40, color, 4.0)

# ══════════════════════════════════════════
# ลำดับเทิร์น
# ══════════════════════════════════════════

func _start_next_round() -> void:
	if is_combat_over: return
	turn_label.text = "เทิร์นที่ %d" % current_turn
	current_turn += 1
	turn_queue.clear()
	turn_queue.append_array(allies)
	turn_queue.append_array(enemies)
	turn_queue.sort_custom(func(a, b): return a.spd > b.spd)
	_next_turn()

func _next_turn() -> void:
	if _check_win_loss(): return
	if turn_queue.is_empty():
		_start_next_round()
		return
	current_actor = turn_queue.pop_front()
	if current_actor.hp <= 0:
		_next_turn()
		return
	_on_turn_start(current_actor)
	_update_ui()
	if current_actor.hp <= 0:
		_next_turn()
		return
	# ถูกสกัดจุด: ข้ามเทิร์น
	if current_actor.status.get("seal", 0) > 0:
		current_actor.status.seal -= 1
		if current_actor.status.seal <= 0: current_actor.status.erase("seal")
		_log_msg("[color=violet]%s ถูกสกัดจุด ขยับตัวไม่ได้![/color]" % current_actor.name)
		_float_text(current_actor, "สกัดจุด!", Color(0.85, 0.6, 1), 20)
		_update_ui()
		_set_buttons(false)
		await get_tree().create_timer(0.7).timeout
		_next_turn()
		return
	if current_actor.is_ally:
		_log_msg("ถึงตาของ [color=green]%s[/color] โปรดเลือกการกระทำ" % current_actor.name)
		_set_buttons(true)
	else:
		_set_buttons(false)
		_enemy_turn()

func _set_buttons(enabled: bool) -> void:
	btn_attack.disabled = not enabled
	btn_flee.disabled = not enabled
	var skill = _get_best_skill(current_actor) if enabled else ""
	btn_skill.disabled = not enabled or skill == "" or current_actor.skill_cd > 0
	if not enabled:
		btn_skill.text = "ใช้วิชา"
	elif skill == "":
		btn_skill.text = "ใช้วิชา (ยังไม่มีวิชา)"
	elif current_actor.skill_cd > 0:
		btn_skill.text = "%s (พักวิชา %d เทิร์น)" % [skill, current_actor.skill_cd]
	else:
		btn_skill.text = "ใช้วิชา: " + skill

## ต้นเทิร์น: ลดคูลดาวน์วิชา, โล่ไร้พ่ายหมดอายุ, สกิลติดตัวฟื้นฟู HP
func _on_turn_start(actor: Dictionary) -> void:
	actor.skill_cd = max(0, actor.skill_cd - 1)
	actor.shield = 0
	if actor.passives.has("regen") and actor.hp < actor.max_hp:
		var heal = int(actor.max_hp * 0.1)
		actor.hp = min(actor.max_hp, actor.hp + heal)
		_float_text(actor, "+%d" % heal, Color(0.5, 1, 0.5))
		_log_msg("[color=lime]%s ฟื้นฟู HP %d (ปราณฟื้นคืน)[/color]" % [actor.name, heal])
	# พิษ / พิษกู่ กัดกินทุกเทิร์น
	for st in ["poison", "gu"]:
		if actor.status.has(st) and actor.hp > 0:
			var dmg = max(1, int(actor.max_hp * (0.06 if st == "poison" else 0.04)))
			actor.hp = max(1 if st == "gu" else 0, actor.hp - dmg)
			_float_text(actor, "-%d" % dmg, Color(0.6, 1, 0.4), 22)
			_log_msg("[color=green]%s ถูก%sกัดกิน เสีย HP %d[/color]" % [actor.name, STATUS_NAMES[st], dmg])
			if st == "poison":
				actor.status.poison -= 1
				if actor.status.poison <= 0: actor.status.erase("poison")
	if actor.hp <= 0:
		_on_unit_down(actor)

func _enemy_turn() -> void:
	await get_tree().create_timer(0.6).timeout
	if is_combat_over: return
	var alive = allies.filter(func(a): return a.hp > 0)
	if alive.is_empty():
		_next_turn()
		return
	await _basic_attack(current_actor, alive.pick_random())
	await get_tree().create_timer(0.3).timeout
	_next_turn()

# ══════════════════════════════════════════
# การกระทำของผู้เล่น
# ══════════════════════════════════════════

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mp = get_global_mouse_position()
		for e in enemies:
			if e.hp > 0 and mp.distance_to(e.node.position + Vector2(0, -50)) < 60:
				selected_target = e
				_update_ui()
				return

func _get_target() -> Dictionary:
	if selected_target.is_empty() or selected_target.hp <= 0:
		var alive = enemies.filter(func(e): return e.hp > 0)
		selected_target = alive[0] if not alive.is_empty() else {}
	return selected_target

func _on_attack_pressed() -> void:
	if _busy or current_actor.is_empty() or not current_actor.is_ally: return
	var target = _get_target()
	if target.is_empty(): return
	_busy = true
	_set_buttons(false)
	await _basic_attack(current_actor, target)
	_busy = false
	_next_turn()

## วิชาที่ให้ผลดีที่สุด (โบนัสวิชา x ระดับความชำนาญ) ไม่นับวิชาตัวเบา/วิชาที่ไม่มีพลัง
func _get_best_skill(actor: Dictionary) -> String:
	if actor.is_empty() or not actor.is_ally: return ""
	return actor.ref.get_best_attack_skill()

## เพิ่มความชำนาญอาวุธให้ศิษย์ และแจ้งเมื่อเลื่อนระดับ
func _gain_mastery(actor: Dictionary, type: String, amount: int) -> void:
	if not actor.is_ally or type == "": return
	if MasterySys.gain(actor.ref, type, amount):
		var lv = MasterySys.get_level(actor.ref, type)
		_log_msg("[color=gold]%s ชำนาญ%sขึ้น! ระดับ %d (%s)[/color]" % [actor.name, MasterySys.type_name(type), lv, MasterySys.RANK_NAMES[lv]])
		_float_text(actor, "ชำนาญ%s Lv%d" % [MasterySys.type_name(type), lv], Color(1, 0.85, 0.4), 16, -50)

func _is_healing_skill(info: Dictionary) -> bool:
	return info.type == "internal" and (info.desc.contains("ฟื้นฟู") or info.desc.contains("รักษา"))

func _on_skill_pressed() -> void:
	if _busy or current_actor.is_empty() or not current_actor.is_ally: return
	var skill = _get_best_skill(current_actor)
	if skill == "":
		_on_attack_pressed()
		return
	_busy = true
	_set_buttons(false)
	var actor = current_actor
	var info = SkillDB.get_skill(skill)
	actor.skill_cd = 2
	_log_msg("[color=cyan]%s ใช้วิชา [b]%s[/b] (ขั้น%s)![/color]" % [actor.name, skill, SkillDB.TIER_NAMES[info.tier]])
	_float_text(actor, skill, Color(0.6, 0.9, 1), 18, -30)

	var mastery_type = MasterySys.skill_type(skill)
	var mastery_lv = MasterySys.skill_level(actor.ref, skill)
	_gain_mastery(actor, mastery_type, MasterySys.GAIN_SKILL_USE)
	if _is_healing_skill(info):
		await _fx_heal(actor)
		var heal = int(actor.max_hp * (0.1 + info.power / 300.0))
		actor.hp = min(actor.max_hp, actor.hp + heal)
		_float_text(actor, "+%d" % heal, Color(0.5, 1, 0.5), 28)
		_log_msg("[color=cyan]%s ฟื้นฟู HP %d[/color]" % [actor.name, heal])
	else:
		var alive = enemies.filter(func(e): return e.hp > 0)
		# วิชาค่ายกล/พิษ โจมตีศัตรูทุกตัว (แรงลดลง) วิชาอื่นโจมตีเป้าหมายเดียว
		var is_area = info.type in ["formation", "poison"]
		var targets = alive if is_area else [_get_target()]
		await _fx_skill(actor, targets, info.type)
		for t in targets:
			_apply_hit(actor, t, int(StatSys.skill_damage(actor.atk, info.power, mastery_lv) * (0.8 if is_area else 1.5)))
			if t.hp > 0:
				if info.desc.contains("สกัดจุด") or info.desc.contains("แช่แข็ง") or info.desc.contains("ขยับไม่ได้") or info.desc.contains("กักขัง"):
					if randf() < 0.7: _apply_status(t, "seal")
				elif info.type == "poison":
					_apply_status(t, "gu" if info.tier >= 3 else "poison")
	_update_ui()
	await get_tree().create_timer(0.4).timeout
	_busy = false
	_next_turn()

func _on_flee_pressed() -> void:
	if _busy: return
	_log_msg("[color=gray]%s ตัดสินใจหลบหนี![/color]" % current_actor.name)
	_end_combat(false)

# ══════════════════════════════════════════
# คำนวณความเสียหาย
# ══════════════════════════════════════════

func _apply_hit(attacker: Dictionary, defender: Dictionary, bonus_power: int = 0) -> void:
	var dmg = max(1, attacker.atk + bonus_power - (defender.def / 2.0))
	dmg = int(dmg * randf_range(0.9, 1.1))
	var crit = false
	var extra = ""

	# สกิลติดตัวจากของวิเศษ
	if attacker.passives.has("crit") and randf() < 0.25:
		dmg *= 2
		crit = true
		extra += " [color=orange](คริติคอล!)[/color]"
	if defender.passives.has("guard"):
		dmg = int(dmg * 0.85)
	if defender.shield > 0:
		dmg = 0
		extra += " [color=lightblue](ถูกโล่ไร้พ่ายสกัดไว้!)[/color]"

	defender.hp = max(0, defender.hp - dmg)
	var c1 = "green" if attacker.is_ally else "red"
	var c2 = "red" if attacker.is_ally else "green"
	_log_msg("[color=%s]%s[/color] โจมตี [color=%s]%s[/color] เสียหาย [b]%d[/b]%s" % [c1, attacker.name, c2, defender.name, dmg, extra])

	if dmg == 0 and defender.shield > 0:
		_float_text(defender, "โล่ไร้พ่าย!", Color(0.6, 0.85, 1), 22)
	else:
		_float_text(defender, ("%d!" % dmg) if crit else str(dmg), Color(1, 0.6, 0.2) if crit else Color(1, 1, 1), 34 if crit else 26)
		_hit_flash(defender)

	if attacker.passives.has("lifesteal") and dmg > 0:
		var heal = int(dmg * 0.2)
		attacker.hp = min(attacker.max_hp, attacker.hp + heal)
		_float_text(attacker, "+%d" % heal, Color(0.5, 1, 0.5), 20)

	if defender.hp > 0 and defender.passives.has("last_stand") and not defender.last_stand_used and defender.hp < defender.max_hp * 0.25:
		defender.last_stand_used = true
		defender.shield = 1
		_log_msg("[color=lightblue]%s ใกล้ตาย! ของวิเศษกางโล่ไร้พ่ายคุ้มกาย 1 เทิร์น[/color]" % defender.name)
		VFX.burst(%FX, defender.node.position + Vector2(0, -50), Color(0.6, 0.85, 1), 30)

	if defender.hp <= 0:
		_on_unit_down(defender)
	_update_ui()

func _on_unit_down(u: Dictionary) -> void:
	if u.get("down", false): return
	u.down = true
	_log_msg("[color=%s]%s[/color] ล้มลงแล้ว!" % ["green" if u.is_ally else "red", u.name])
	var tw = create_tween()
	tw.tween_property(u.sprite, "modulate", Color(0.4, 0.4, 0.4, 0.45), 0.5)
	tw.parallel().tween_property(u.sprite, "rotation", deg_to_rad(80 if u.is_ally else -80), 0.5)
	u.bar.hide()

func _apply_status(u: Dictionary, st: String) -> void:
	match st:
		"seal": u.status["seal"] = 3
		"poison": u.status["poison"] = 3
		"gu": u.status["gu"] = true
	_float_text(u, STATUS_NAMES[st] + "!", Color(0.85, 0.6, 1), 20, -24)
	_log_msg("[color=violet]%s ติดสถานะ %s![/color]" % [u.name, STATUS_NAMES[st]])
	_update_ui()

# ══════════════════════════════════════════
# แอนิเมชันและเอฟเฟกต์
# ══════════════════════════════════════════

## พุ่งเข้าฟัน แล้วถอยกลับที่เดิม
func _basic_attack(attacker: Dictionary, defender: Dictionary) -> void:
	var start: Vector2 = attacker.home
	var hit_pos = start.lerp(defender.node.position, 0.75)
	var tw = create_tween()
	tw.tween_property(attacker.node, "position", hit_pos, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	_slash(defender.node.position + Vector2(0, -55), attacker.color)
	_apply_hit(attacker, defender)
	if attacker.is_ally:
		_gain_mastery(attacker, MasterySys.weapon_type(attacker.ref.equipped_weapon), MasterySys.GAIN_BASIC_ATTACK)
	var st: String = attacker.get("status_attack", "")
	if st != "" and defender.hp > 0 and randf() < 0.3:
		_apply_status(defender, st)
	var back = create_tween()
	back.tween_property(attacker.node, "position", start, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await back.finished

func _slash(center: Vector2, color: Color) -> void:
	var line = Line2D.new()
	line.width = 6
	line.default_color = Color(color.lightened(0.4), 0.95)
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	var pts = PackedVector2Array()
	for i in 9:
		var a = lerp(-2.3, -0.6, i / 8.0)
		pts.append(center + Vector2(cos(a), sin(a)) * 42)
	line.points = pts
	%FX.add_child(line)
	var tw = line.create_tween()
	tw.tween_property(line, "modulate:a", 0.0, 0.3)
	tw.tween_callback(line.queue_free)

func _hit_flash(u: Dictionary) -> void:
	var tw = create_tween()
	tw.tween_property(u.sprite, "modulate", Color(1, 0.35, 0.35), 0.06)
	tw.tween_property(u.sprite, "modulate", Color(1, 1, 1), 0.2)
	var kb = create_tween()
	var dir = -1.0 if u.is_ally else 1.0
	kb.tween_property(u.node, "position", u.home + Vector2(dir * 10, 0), 0.06)
	kb.tween_property(u.node, "position", u.home, 0.15)

func _float_text(u: Dictionary, text: String, color: Color, font_size: int = 26, y_offset: float = 0.0) -> void:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02))
	l.add_theme_constant_override("outline_size", 6)
	l.size = Vector2(160, 40)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = u.node.position + Vector2(-80 + randf_range(-12, 12), -150 + y_offset)
	%FX.add_child(l)
	var tw = l.create_tween()
	tw.tween_property(l, "position:y", l.position.y - 45, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.35)
	tw.tween_callback(l.queue_free)

## เอฟเฟกต์วิชาตามประเภท
func _fx_skill(actor: Dictionary, targets: Array, type: String) -> void:
	var from: Vector2 = actor.node.position + Vector2(0, -60)
	var color: Color = actor.color
	match type:
		"sword", "spear":
			for t in targets: await _fly_projectile(_make_sword(color), from, t.node.position + Vector2(0, -55), 0.35, true, color)
		"hidden_weapon":
			for t in targets:
				for i in 3:
					_fly_projectile(_make_needle(color), from + Vector2(0, i * 8 - 8), t.node.position + Vector2(0, -55 + i * 10 - 10), 0.25 + i * 0.05, true, color)
				await get_tree().create_timer(0.35).timeout
		"palm", "internal":
			for t in targets: await _fly_projectile(_make_wave(color), from, t.node.position + Vector2(0, -55), 0.4, false, color)
		"poison":
			for t in targets: _poison_cloud(t.node.position + Vector2(0, -40))
			await get_tree().create_timer(0.6).timeout
		"formation":
			await _formation(targets, color)
		_:
			for t in targets: await _fly_projectile(_make_wave(color), from, t.node.position + Vector2(0, -55), 0.4, false, color)
	for t in targets:
		VFX.burst(%FX, t.node.position + Vector2(0, -55), color, 25)

func _fly_projectile(node: Node2D, from: Vector2, to: Vector2, duration: float, rotate_to: bool, color: Color = Color.WHITE) -> void:
	node.position = from
	if rotate_to: node.rotation = (to - from).angle()
	%FX.add_child(node)
	var trail = CPUParticles2D.new()
	trail.amount = 24
	trail.lifetime = 0.35
	trail.local_coords = false
	trail.spread = 20
	trail.gravity = Vector2.ZERO
	trail.initial_velocity_min = 5
	trail.initial_velocity_max = 20
	trail.scale_amount_min = 2
	trail.scale_amount_max = 4
	trail.color = Color(color.lightened(0.3), 0.7)
	node.add_child(trail)
	var tw = create_tween()
	tw.tween_property(node, "position", to, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tw.finished
	node.queue_free()

func _make_sword(color: Color) -> Node2D:
	var root = Node2D.new()
	var blade = Polygon2D.new()
	blade.polygon = PackedVector2Array([Vector2(-26, -3), Vector2(20, -3), Vector2(32, 0), Vector2(20, 3), Vector2(-26, 3)])
	blade.color = Color(0.9, 0.93, 1.0)
	root.add_child(blade)
	var guard = Polygon2D.new()
	guard.polygon = PackedVector2Array([Vector2(-27, -9), Vector2(-23, -9), Vector2(-23, 9), Vector2(-27, 9)])
	guard.color = Color(0.85, 0.7, 0.3)
	root.add_child(guard)
	var glow = Polygon2D.new()
	glow.polygon = PackedVector2Array([Vector2(-30, -8), Vector2(24, -6), Vector2(40, 0), Vector2(24, 6), Vector2(-30, 8)])
	glow.color = Color(color, 0.35)
	glow.show_behind_parent = true
	root.add_child(glow)
	root.modulate = Color(1, 1, 1)
	return root

func _make_needle(color: Color) -> Node2D:
	var p = Polygon2D.new()
	p.polygon = PackedVector2Array([Vector2(-10, -1), Vector2(10, 0), Vector2(-10, 1)])
	p.color = color.lightened(0.5)
	return p

func _make_wave(color: Color) -> Node2D:
	var root = Node2D.new()
	for r in [[26.0, 0.25], [17.0, 0.5], [9.0, 0.95]]:
		var circle = Polygon2D.new()
		var pts = PackedVector2Array()
		for i in 20:
			pts.append(Vector2(cos(i * TAU / 20), sin(i * TAU / 20)) * r[0])
		circle.polygon = pts
		circle.color = Color(color.lightened(0.2), r[1])
		root.add_child(circle)
	var tw = root.create_tween().set_loops(4)
	tw.tween_property(root, "scale", Vector2(1.25, 1.25), 0.06)
	tw.tween_property(root, "scale", Vector2(1, 1), 0.06)
	return root

func _poison_cloud(pos: Vector2) -> void:
	var p = CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.explosiveness = 0.6
	p.amount = 40
	p.lifetime = 1.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 30
	p.gravity = Vector2(0, -30)
	p.initial_velocity_max = 20
	p.scale_amount_min = 6
	p.scale_amount_max = 12
	var ramp = Gradient.new()
	ramp.set_color(0, Color(0.5, 0.95, 0.3, 0.8))
	ramp.set_color(1, Color(0.2, 0.5, 0.1, 0.0))
	p.color_ramp = ramp
	%FX.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)

## ค่ายกล: วงอักขระทองใต้เท้าศัตรู แล้วเสาแสงพุ่งขึ้น
func _formation(targets: Array, color: Color) -> void:
	var rings: Array = []
	for t in targets:
		var ring = Line2D.new()
		var pts = PackedVector2Array()
		for i in 33:
			pts.append(Vector2(cos(i * TAU / 32) * 50, sin(i * TAU / 32) * 18))
		ring.points = pts
		ring.width = 3
		ring.default_color = Color(1, 0.85, 0.35)
		ring.position = t.node.position
		ring.scale = Vector2(0.2, 0.2)
		%FX.add_child(ring)
		rings.append(ring)
		ring.create_tween().tween_property(ring, "scale", Vector2(1, 1), 0.35)
	await get_tree().create_timer(0.4).timeout
	for i in targets.size():
		var t = targets[i]
		var pillar = Line2D.new()
		pillar.points = PackedVector2Array([t.node.position, t.node.position + Vector2(0, -200)])
		pillar.width = 26
		pillar.default_color = Color(color.lightened(0.4), 0.6)
		%FX.add_child(pillar)
		var tw = pillar.create_tween()
		tw.tween_property(pillar, "modulate:a", 0.0, 0.4)
		tw.tween_callback(pillar.queue_free)
		var rtw = rings[i].create_tween()
		rtw.tween_property(rings[i], "modulate:a", 0.0, 0.4)
		rtw.tween_callback(rings[i].queue_free)
	await get_tree().create_timer(0.2).timeout

func _fx_heal(actor: Dictionary) -> void:
	var p = CPUParticles2D.new()
	p.position = actor.node.position + Vector2(0, -20)
	p.one_shot = true
	p.explosiveness = 0.3
	p.amount = 40
	p.lifetime = 0.9
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(30, 10)
	p.direction = Vector2.UP
	p.spread = 15
	p.gravity = Vector2(0, -80)
	p.initial_velocity_min = 30
	p.initial_velocity_max = 70
	p.scale_amount_min = 3
	p.scale_amount_max = 6
	p.color = Color(0.5, 1, 0.6, 0.8)
	%FX.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)
	await get_tree().create_timer(0.5).timeout

# ══════════════════════════════════════════
# จบการต่อสู้
# ══════════════════════════════════════════

func _check_win_loss() -> bool:
	if allies.all(func(a): return a.hp <= 0):
		_end_combat(false)
		return true
	if enemies.all(func(e): return e.hp <= 0):
		_end_combat(true)
		return true
	return false

func _end_combat(is_win: bool) -> void:
	if is_combat_over: return
	is_combat_over = true
	current_actor = {}
	_set_buttons(false)
	result_panel.show()
	var sect = GlobalGame.current_sect

	if is_win:
		result_label.add_theme_color_override("font_color", Color.GREEN)
		# แจกของรางวัล
		var t_money = GlobalGame.combat_bonus_money
		var t_food = 0
		var t_exp = 0
		var luck = 0
		for a in allies: luck = max(luck, a.ref.get_stat("luck"))
		var drops = {}
		for e in GlobalGame.combat_enemies:
			t_money += e.get("reward_money", 0)
			t_food += e.get("reward_food", 0)
			t_exp += e.get("reward_exp", 0)
			var d = EnemyDB.roll_drops(e, luck)
			for m in d: drops[m] = drops.get(m, 0) + d[m]

		sect.money += t_money
		sect.food += t_food
		var ctx_type: String = GlobalGame.combat_context.get("type", "")
		if ctx_type == "field":
			# ของดรอปตกที่พื้นในพื้นที่สำรวจ (เดินเก็บเอง) และมอนสเตอร์ตัวนี้หายไปจากพื้นที่
			var fs = GlobalGame.field_state
			for m in drops: fs.pending_loot[m] = fs.pending_loot.get(m, 0) + drops[m]
			fs.defeated.append(fs.get("fighting", ""))
		else:
			sect.add_materials(drops)
		var alive = allies.filter(func(a): return a.hp > 0)
		for a in alive:
			a.ref.gain_experience(int(t_exp / float(alive.size())), sect.current_day)
		if GlobalGame.combat_bonus_task != "":
			sect.completed_world_tasks.append(GlobalGame.combat_bonus_task)

		var summary = "ชนะการต่อสู้ ได้รับเงิน %d เสบียง %d และ EXP %d" % [t_money, t_food, t_exp]
		if not drops.is_empty():
			summary += ("\nของดรอปตกอยู่ที่พื้น (เดินไปเก็บ): " if ctx_type == "field" else "\nของดรอป: ") + MaterialDB.format_list(drops)
		for a in alive: PawnSys.add_thought(a.ref, sect, "won_battle")
		if GlobalGame.combat_context.get("type", "") == "raid":
			StorytellerSystem.raid_won(sect, GlobalGame.combat_enemies, alive.map(func(a): return a.ref), GlobalGame.combat_context.raid, GlobalGame.sect_manager)
		var ctx_text = _apply_context_win(alive)
		if ctx_text != "": summary += "\n" + ctx_text
		sect.log_event(sect.current_day, summary)
		_log_msg("[color=green]%s[/color]" % summary)
		result_label.text = "ได้รับชัยชนะ!\n" + summary
		for a in alive:
			VFX.burst(%FX, a.node.position + Vector2(0, -60), Color(1, 0.85, 0.4), 40)
	else:
		result_label.add_theme_color_override("font_color", Color.RED)
		# ศิษย์ที่ล้มในการต่อสู้: บาดเจ็บ / เส้นชีพจรขาด / อาจถูกสังหาร (ตามความยาก)
		var ctx = GlobalGame.combat_context
		var fid: String = ctx.get("faction", "")
		var death_chance: float = BuildingDB.diff(sect.difficulty).death + (0.15 if fid != "" else 0.0)
		if ctx.get("type", "") in ["spar", "arena", "recruit_duel", "city_guard"]: death_chance = 0.0
		if ctx.get("type", "") == "field":
			# แพ้ในพื้นที่สำรวจ: ทีมถอยกลับแผนที่โลก
			GlobalGame.combat_return_scene = "res://scene/map/world_map.tscn"
			GlobalGame.field_state = {}
		if ctx.get("type", "") == "city_guard":
			var fine = int(max(0, sect.money) * 0.15)
			sect.money -= fine
			sect.active_contract = {}
			sect.log_event(sect.current_day, "[color=red]ทหารหลวงจับตัวได้ ต้องจ่ายค่าไถ่ %d เงิน และสัญญาลอบสังหาร (ถ้ามี) ถูกยกเลิก[/color]" % fine)
			FactionSys.change_rel(sect, "player", "f_court", -5)
		var hurt: Array[String] = []
		var dead: Array[String] = []
		var log_fn = func(t): sect.log_event(sect.current_day, t)
		for a in allies:
			if a.hp > 0: continue
			if randf() < death_chance:
				var killer = FactionDB.FACTIONS[fid].name if fid != "" else "ศัตรู"
				FactionSys.on_disciple_killed(sect, a.ref, fid, "ถูก%sสังหารในการต่อสู้" % killer, log_fn)
				HealthSystem.on_death(sect, a.ref)
				dead.append(a.ref.disciple_name)
				continue
			# บาดแผลตามอวัยวะ (ระบบร่างกาย) + อาการภายใน
			for n in randi_range(1, 2): PawnSys.injure(a.ref, randf_range(5, 14), "บาดเจ็บจากการต่อสู้")
			PawnSys.add_thought(a.ref, sect, "lost_battle")
			StressSystem.add(a.ref, 25.0)
			a.ref.injury_days = randi_range(2, 5)
			a.ref.add_ailment("meridian_damage" if randf() < 0.4 else "internal_injury")
			if a.ref.status != DiscipleData.DiscipleStatus.MISSION:
				a.ref.status = DiscipleData.DiscipleStatus.INJURED
			hurt.append(a.ref.disciple_name)
		if ctx.get("type", "") == "raid":
			# แพ้ศึกป้องกันสำนัก: ถูกปล้นสะดม (บาดแผลคิดไปแล้วด้านบน)
			StorytellerSystem.raid_lost(sect, [], ctx.raid, GlobalGame.sect_manager)
		var text = "ศิษย์พ่ายแพ้และล่าถอย"
		if not hurt.is_empty(): text += " (บาดเจ็บ: %s)" % ", ".join(hurt)
		if not dead.is_empty(): text += " (เสียชีวิต: %s)" % ", ".join(dead)
		sect.log_event(sect.current_day, text)
		result_label.text = "พ่ายแพ้...\n" + text
	# พิษกู่ที่ติดตัวกลับไป ต้องให้หมอรักษา
	for a in allies:
		if a.status.has("gu") and a.ref.status != DiscipleData.DiscipleStatus.DEPARTED:
			a.ref.add_ailment("gu_poison")
			sect.log_event(sect.current_day, "[color=red]%s ติดพิษกู่กลับมา! ต้องให้หมอถอนพิษภายใน 20 วัน[/color]" % a.ref.disciple_name)
	GlobalGame.combat_bonus_money = 0
	GlobalGame.combat_bonus_task = ""
	GlobalGame.combat_context = {}

## ผลพิเศษเมื่อชนะ ตามบริบทของการต่อสู้ (ยึดพื้นที่ / บุกตีสำนัก / ประลอง / ปราบปราม)
func _apply_context_win(alive: Array) -> String:
	var sect = GlobalGame.current_sect
	var ctx = GlobalGame.combat_context
	var fid: String = ctx.get("faction", "")
	var node_id: String = ctx.get("node", "")
	var fame = 5 + (10 if fid != "" else 0)
	for a in alive: a.ref.add_fame(fame)
	var text = ""
	match ctx.get("type", "hunt"):
		"claim":
			sect.node_owner[node_id] = "player"
			if fid != "": sect.factions[fid].relation -= 15
			text = "ยึดครอง%s สำเร็จ! (รายได้ +%d/วัน)" % [WorldDB.NODES[node_id].name, FactionSys.NODE_INCOME]
			if sect.count_owned_nodes() - 1 >= 5: ArchiveSys.unlock_achievement("conqueror")
			for extra in LandmarkSys.on_claim(sect, node_id): text += "\n" + extra
		"siege":
			text = FactionSys.on_siege_won(sect, fid)
			for a in alive: a.ref.add_fame(30)
		"arena":
			var fame_gain: int = ctx.get("fame", 20)
			for a in alive: a.ref.add_fame(fame_gain)
			sect.prestige += fame_gain / 2
			text = "ชนะการประลองยุทธ์หลวง! ชื่อเสียง +%d" % fame_gain
		"city_guard":
			FactionSys.change_rel(sect, "player", "f_court", -5)
			FactionSys.change_rel(sect, "player", "f_hawk", -10)
			text = "ฝ่าวงล้อมทหารยามหนีออกมาได้ แต่ราชสำนักเริ่มเพ่งเล็งสำนักเรา"
		"roster_spar":
			text = RosterSys.on_spar_win(sect, ctx.get("roster_id", ""))
		"recruit_duel":
			if sect.get_active_disciples().size() < sect.get_max_disciples():
				var npc = NPCGenerator.generate_npc(1, max(1, int(ctx.get("recruit_level", 5)) - 2))
				npc.ambition = "ค้นหาความหมายของวิถียุทธ์"
				sect.disciples.append(npc)
				for s in npc.innate_skills: sect.add_library_skill(s)
				text = "จอมยุทธ์พเนจร %s ยอมรับความพ่ายแพ้และขอเข้าร่วมสำนัก (%s พลังรบ %d)" % [npc.disciple_name, npc.realm_name, npc.get_power_rating()]
			else:
				for a in alive: a.ref.add_fame(20)
				text = "ชนะจอมยุทธ์พเนจร แต่สำนักเต็มแล้ว ได้แค่ชื่อเสียง"
		"spar":
			sect.factions[fid].relation = min(100, sect.factions[fid].relation + 5)
			sect.prestige += 10
			text = "ชนะการประลองกับ%s ชื่อเสียงสำนักเพิ่มขึ้น" % FactionDB.FACTIONS[fid].name
		_:
			# ดันเจี้ยน/ศัตรูระดับสูง มีโอกาสได้คัมภีร์สมบูรณ์
			var max_level = 0
			for e in GlobalGame.combat_enemies: max_level = max(max_level, e.get("level", 1))
			if max_level >= 6 and randf() < 0.15:
				var tier = SkillDB.Tier.HEAVEN if max_level >= 12 else SkillDB.Tier.EARTH
				var skill = SkillDB.get_random_skill_by_tier(tier)
				if sect.add_library_skill(skill):
					text = "พบคัมภีร์วิชา %s (ขั้น%s) ในซากศัตรู!" % [skill, SkillDB.TIER_NAMES[tier]]
	if text != "": sect.log_event(sect.current_day, "[color=gold]%s[/color]" % text)
	return text

func _on_return_pressed() -> void:
	GlobalGame.save_game()
	get_tree().change_scene_to_file(GlobalGame.combat_return_scene)

func _update_ui() -> void:
	for u in allies + enemies:
		u.bar.value = u.hp
		var fill = StyleBoxFlat.new()
		fill.bg_color = Color(0.3, 0.85, 0.35) if u.hp > u.max_hp * 0.3 else Color(0.9, 0.25, 0.2)
		u.bar.add_theme_stylebox_override("fill", fill)
		u.ring.queue_redraw()
	var t = selected_target
	for u in allies + enemies:
		var parts: Array[String] = []
		for st in u.status:
			parts.append(STATUS_NAMES[st] + (" %d" % u.status[st] if u.status[st] is int else ""))
		u.status_label.text = " ".join(parts)
	%TargetLabel.text = "เป้าหมาย: %s (HP %d/%d) - คลิกศัตรูเพื่อเปลี่ยน" % [t.name, t.hp, t.max_hp] if not t.is_empty() and t.hp > 0 else "เป้าหมาย: -"

func _log_msg(msg: String) -> void:
	log_box.append_text(msg + "\n")
