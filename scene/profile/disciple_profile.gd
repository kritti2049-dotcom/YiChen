extends Control

## แฟ้มประวัติศิษย์ แบ่งเป็นแท็บ: ข้อมูลส่วนตัว / สถิติและค่าพลัง / วิทยายุทธ์ / อุปกรณ์และยา / ผังขั้นบำเพ็ญ
## View ของ MVC: ปุ่มต่างๆ ส่งคำสั่งไปที่ GlobalGame.controller แล้ววาดใหม่เมื่อได้ Signal disciple_changed

const CATS = {
	"Physical": { "name": "ร่างกาย", "color": Color(0.85, 0.45, 0.4) },
	"Spiritual": { "name": "จิตวิญญาณ", "color": Color(0.45, 0.75, 0.85) },
	"Mental": { "name": "สติปัญญา", "color": Color(0.7, 0.5, 0.85) },
	"Social": { "name": "สังคม/การทูต", "color": Color(0.85, 0.75, 0.35) },
	"Combat": { "name": "ศาสตร์การต่อสู้", "color": Color(0.9, 0.35, 0.35) },
	"Crafting": { "name": "วิชาชีพ/ผลิต", "color": Color(0.45, 0.8, 0.5) },
}

var d: DiscipleData
var sect: SectData

func _ready() -> void:
	d = GlobalGame.selected_disciple
	sect = GlobalGame.current_sect
	if d == null or sect == null:
		get_tree().change_scene_to_file.call_deferred("res://scene/test_sect.tscn")
		return
	d.ensure_defaults()
	%BtnBack.pressed.connect(func():
		GlobalGame.save_game()
		var back = GlobalGame.profile_return_scene
		GlobalGame.profile_return_scene = "res://scene/test_sect.tscn"
		get_tree().change_scene_to_file(back))

	# รูปหน้าตัวละคร + ออร่าปราณรอบรูป
	%Portrait.texture = ArtGen.get_portrait(d)
	var aura = QiAura.create(d, 92.0)
	aura.position = Vector2(100, 100)
	aura.show_behind_parent = true
	%Portrait.add_child(aura)
	var tree = RealmTree.create(d)
	tree.name = "ผังขั้นบำเพ็ญ"
	%Tabs.add_child(tree)
	_mind_box = _add_tab("จิตใจ")
	_body_box = _add_tab("สถานะ & พรสวรรค์")
	_work_box = _add_tab("ทักษะงาน")
	GlobalGame.controller.disciple_changed.connect(_on_disciple_changed)
	GlobalGame.controller.action_result.connect(_on_action_result)
	_refresh_all()

var _mind_box: VBoxContainer
var _body_box: VBoxContainer
var _work_box: VBoxContainer

func _add_tab(tab_name: String) -> VBoxContainer:
	var scroll = ScrollContainer.new()
	scroll.name = tab_name
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	%Tabs.add_child(scroll)
	return box

func _on_disciple_changed(changed: DiscipleData) -> void:
	if changed == d: _refresh_all()

func _on_action_result(ok: bool, message: String) -> void:
	UIKit.toast(self, message, Color(0.6, 1, 0.6) if ok else Color(1, 0.55, 0.45))

func _refresh_all() -> void:
	_build_side()
	_build_bio(%BioBox)
	_build_stats(%StatsBox)
	_build_skills(%SkillsBox)
	_build_gear(%GearBox)
	if _mind_box:
		PawnPanels.mind(_mind_box, d, sect, GlobalGame.sect_manager, _refresh_all)
		PawnPanels.body(_body_box, d, sect, GlobalGame.sect_manager, _refresh_all)
		PawnPanels.skills(_work_box, d)

func _get_location_text(target_d: DiscipleData) -> String:
	if target_d.status == DiscipleData.DiscipleStatus.MISSION:
		var target_name = WorldDB.get_node_data(target_d.mission_target).get("name", target_d.mission_target)
		match target_d.mission_phase:
			"stationed":
				return "ประจำการอยู่ที่ %s" % target_name
			"going":
				return "เดินทางไป %s (อีก %d วัน)" % [target_name, target_d.mission_days_left]
			"working":
				return "เก็บวัตถุดิบที่ %s (อีก %d วัน)" % [target_name, target_d.mission_days_left]
			"returning":
				return "เดินทางกลับสำนัก (อีก %d วัน)" % target_d.mission_days_left
			_:
				return target_name if target_name != "" else "นอกสำนัก"
	return "ภายในสำนักใหญ่"

func _build_side() -> void:
	%NameLabel.text = d.get_display_name()
	var info = CultivationSys.get_realm_info(d.level)
	var req_exp = CultivationSys.get_required_exp(d.level)
	%RealmLabel.text = d.realm_name + (" - พร้อมทะลวง!" if info.is_bottleneck and d.experience >= req_exp else "")
	%RealmLabel.add_theme_color_override("font_color", Color(1, 0.45, 0.4) if info.is_bottleneck and d.experience >= req_exp else Color(1, 0.8, 0.2))
	%ExpBar.max_value = req_exp
	%ExpBar.value = min(d.experience, req_exp)
	%ExpLabel.text = "EXP %d / %d" % [d.experience, req_exp]
	%StatusLabel.text = "📍 ที่อยู่: %s\nสถานะ: %s" % [_get_location_text(d), d.get_status_text()]
	%CombatLabel.text = "HP %d | ATK %d | DEF %d | SPD %d\nพลังรบรวม %d (ตัวคูณขั้น x%.2f)" % [d.get_combat_max_hp(), d.get_combat_attack(), d.get_combat_defense(), d.get_combat_speed(), d.get_power_rating(), d.get_realm_multiplier()]

func _card(border: Color) -> Array:
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.13, 0.1)
	style.border_width_left = 4
	style.border_color = border
	style.set_corner_radius_all(4)
	style.content_margin_left = 12
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	panel.add_child(v)
	return [panel, v]

# ══════════════════════════════════════════
# Tab 1: ข้อมูลส่วนตัว
# ══════════════════════════════════════════

func _build_bio(c: VBoxContainer) -> void:
	UIKit.clear(c)
	c.add_child(UIKit.section("ตำแหน่ง & ตัวตน"))
	var loc_str = _get_location_text(d)
	var loc_col = Color(0.4, 0.85, 1.0) if d.status == DiscipleData.DiscipleStatus.MISSION else Color(0.6, 1.0, 0.6)
	c.add_child(UIKit.label("📍 ตำแหน่งปัจจุบัน: %s" % loc_str, 16, loc_col))
	var lifespan = CultivationSys.get_lifespan(d.level)
	var race_info = BackgroundDB.RACES.get(d.race, {})
	c.add_child(UIKit.label("เพศ: %s   |   เผ่า: %s   |   ธาตุรากวิญญาณ: %s" % [d.gender, d.race, d.element], 16, CultivationSys.get_aura_color(d.element, d.level)))
	if race_info.get("desc", "") != "":
		var bonus_text = ""
		for k in race_info.bonus:
			bonus_text += " %s %+d" % [StatSys.STATS_DEF[k].name, race_info.bonus[k]]
		c.add_child(UIKit.label("%s%s" % [race_info.desc, (" (สายเลือด:" + bonus_text + ")") if bonus_text != "" else ""], 14, WuxiaTheme.PAPER_DIM))
	c.add_child(UIKit.label("อายุ %d ปี / อายุขัย %s ปี   |   %s" % [d.age, "อมตะ" if lifespan < 0 else str(lifespan), CultivationSys.get_realm_desc(d.level)], 15))
	c.add_child(UIKit.label("ความทะเยอทะยาน: %s   |   ความภักดี %d   |   อารมณ์ %d   |   ความอิ่ม %d%%   |   %s" % [d.ambition, d.loyalty, d.mood, d.hunger, "เด็ก (โตวันที่ %d)" % d.grow_day if d.is_child else "ผู้ใหญ่"], 15))

	c.add_child(UIKit.section("ยุทธภพ"))
	c.add_child(UIKit.label("ฉายา: %s   |   ชื่อเสียง %d   |   กำลังทำ: %s" % [d.title if d.title != "" else "(ยังไม่มี - ชื่อเสียงถึง 100 จะได้ฉายา)", d.fame, SectView.activity_text(d)], 15, Color(1, 0.85, 0.4)))
	if d.feud_target != "":
		c.add_child(UIKit.label("ความแค้น: ผูกใจเจ็บกับ%s เพื่อ %s (ความแค้น %d) — อาจแอบหนีไปล้างแค้นเอง!" % [FactionDB.FACTIONS[d.feud_target].name, d.feud_for, d.feud_intensity], 15, Color(1, 0.4, 0.35)))
	for a in d.ailments:
		var info = AilmentDB.get_ailment(a.id)
		c.add_child(UIKit.label("อาการ: %s (เป็นมา %d วัน) — %s" % [info.name, a.days, info.desc], 15, Color(0.85, 0.6, 1)))
	if d.disabled:
		c.add_child(UIKit.label("พิการถาวร: เส้นชีพจรขาดโดยไม่ได้รับการรักษา พลังต่อสู้ลดครึ่ง ออกรบไม่ได้", 15, Color(1, 0.4, 0.35)))

	c.add_child(UIKit.section("ภูมิหลัง"))
	c.add_child(UIKit.label(d.background_story, 16))

	c.add_child(UIKit.section("พรสวรรค์และอุปนิสัย (%d)" % d.ext_traits.size()))
	if d.ext_traits.is_empty():
		c.add_child(UIKit.label("ไม่มีพรสวรรค์พิเศษ", 14, WuxiaTheme.PAPER_DIM))
	for t_name in d.ext_traits:
		var info = TraitDB.get_trait(t_name)
		var positive: bool = info.get("is_positive", true)
		var col = Color(0.45, 0.85, 0.45) if positive else Color(0.95, 0.45, 0.4)
		var card = _card(col)
		c.add_child(card[0])
		var cat_name = CATS.get(info.get("category", ""), {}).get("name", "ทั่วไป")
		card[1].add_child(UIKit.label("%s   [สาย%s · %s]" % [t_name, cat_name, "พรสวรรค์" if positive else "ข้อบกพร่อง"], 17, col))
		card[1].add_child(UIKit.label(info.get("desc", ""), 14, WuxiaTheme.PAPER_DIM))
		var effect = TraitDB.get_effect_text(t_name)
		if effect != "":
			card[1].add_child(UIKit.label("ผลลัพธ์: " + effect, 15, WuxiaTheme.PAPER))

	if not d.memory_log.is_empty():
		c.add_child(UIKit.section("ความทรงจำล่าสุด"))
		for m in d.memory_log.slice(-6):
			c.add_child(UIKit.label("วันที่ %d: %s" % [m.day, m.text], 14))
	if not d.relationships.is_empty():
		c.add_child(UIKit.section("ความสัมพันธ์"))
		for other in d.relationships:
			var r = d.relationships[other]
			c.add_child(UIKit.label("%s - %s (ความสนิท %+d)" % [other, r.type, int(r.affinity)], 14))

# ══════════════════════════════════════════
# Tab 2: สถิติและค่าพลัง (แสดงที่มาของทุกตัวเลข)
# ══════════════════════════════════════════

func _format_breakdown(parts: Array) -> String:
	var text = ""
	for i in parts.size():
		var p = parts[i]
		if i == 0:
			text = "%s %d" % [p.src, p.val]
		else:
			text += "  %s %s %d" % ["+" if p.val >= 0 else "-", p.src, abs(p.val)]
	return text

func _build_stats(c: VBoxContainer) -> void:
	UIKit.clear(c)
	c.add_child(UIKit.label("ค่าพลังแบ่งเป็น 3 ชั้น: [1] รากฐานแต่กำเนิด (คนธรรมดา 1-5) x [2] ตัวคูณขั้นบำเพ็ญ + [3] อุปกรณ์/บัฟ — ทุกค่าแสดงที่มาของตัวเลข", 14, WuxiaTheme.PAPER_DIM))

	# ค่าพลังต่อสู้ 3 ชั้น
	c.add_child(UIKit.section("ค่าพลังต่อสู้ (ขั้น %s ตัวคูณ x%.2f)" % [d.realm_name, d.get_realm_multiplier()]))
	var b = d.get_combat_breakdown()
	var base_text = {
		"hp": "10 + ทนทาน %d x8" % d.get_stat("vit"),
		"atk": "1 + แข็งแกร่ง %d" % d.get_stat("str"),
		"def": "(ทนทาน %d + ป้องกันตัว %d) x0.5" % [d.get_stat("vit"), d.get_stat("defense_arts")],
		"spd": "ว่องไว %d + ตัวเบา %d x0.5" % [d.get_stat("agi"), d.get_stat("movement_arts")],
	}
	var names = { "hp": "HP", "atk": "พลังโจมตี", "def": "พลังป้องกัน", "spd": "ความเร็ว" }
	var totals = { "hp": d.get_combat_max_hp(), "atk": d.get_combat_attack(), "def": d.get_combat_defense(), "spd": d.get_combat_speed() }
	for k in names:
		var part = b[k]
		c.add_child(UIKit.label("%s: %d  =  [%s = %.1f] x %.2f + อุปกรณ์ %d%s" % [names[k], totals[k], base_text[k], part.base, part.mult, part.gear, " (พิการ ลดครึ่ง)" if d.disabled else ""], 15))
	var skill = d.get_best_attack_skill()
	var bonus = StatSys.skill_bonus(SkillDB.get_skill(skill).power) if skill != "" else 0.0
	var mlv = MasterySys.skill_level(d, skill) if skill != "" else 0
	c.add_child(UIKit.label("พลังรบรวม %d  =  พลังโจมตี %d x2 + HP %d / 5 + ความเร็ว %d x1.5 + โบนัสวิชา %.1f x ระดับความชำนาญ %d%s" % [d.get_power_rating(), totals.atk, totals.hp, totals.spd, bonus, max(1, mlv), (" (" + skill + ")") if skill != "" else ""], 15, Color(1, 0.85, 0.4)))

	for cat_key in CATS:
		var cat = CATS[cat_key]
		var card = _card(cat.color)
		c.add_child(card[0])
		card[1].add_child(UIKit.label(cat.name, 19, cat.color))
		for stat_key in StatSys.STATS_DEF:
			var def = StatSys.STATS_DEF[stat_key]
			if def.cat != cat_key: continue
			var value = d.get_stat(stat_key)
			var h = HBoxContainer.new()
			var name_l = UIKit.label(def.name, 15)
			name_l.custom_minimum_size = Vector2(120, 0)
			name_l.autowrap_mode = TextServer.AUTOWRAP_OFF
			name_l.tooltip_text = def.desc
			name_l.mouse_filter = Control.MOUSE_FILTER_PASS
			h.add_child(name_l)
			var val_l = UIKit.label("%d %s" % [value, StatSys.grade_name(value)], 15, Color(1, 0.92, 0.7))
			val_l.custom_minimum_size = Vector2(90, 0)
			val_l.autowrap_mode = TextServer.AUTOWRAP_OFF
			h.add_child(val_l)
			var bar = ProgressBar.new()
			bar.custom_minimum_size = Vector2(120, 12)
			bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			bar.show_percentage = false
			bar.max_value = StatSys.POTENTIAL_CAP
			bar.value = value
			var fill = StyleBoxFlat.new()
			fill.bg_color = cat.color
			fill.set_corner_radius_all(3)
			bar.add_theme_stylebox_override("fill", fill)
			h.add_child(bar)
			var src_l = UIKit.label("= " + _format_breakdown(d.get_stat_breakdown(stat_key)), 13, WuxiaTheme.PAPER_DIM)
			src_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(src_l)
			card[1].add_child(h)

# ══════════════════════════════════════════
# Tab 3: วิทยายุทธ์
# ══════════════════════════════════════════

func _build_skills(c: VBoxContainer) -> void:
	UIKit.clear(c)
	c.add_child(UIKit.label("ความจุวิชา %d / %d (ตามค่าความจำ)   |   วิชาถนัด: %s" % [d.learned_skills.size(), d.get_max_skills(), SkillDB.TYPE_NAMES.get(d.affinity_style, d.affinity_style)], 15, WuxiaTheme.PAPER_DIM))
	_build_mastery(c)
	var innate: Array = d.innate_skills.filter(func(s): return d.learned_skills.has(s))
	var learned: Array = d.learned_skills.filter(func(s): return not d.innate_skills.has(s))
	c.add_child(UIKit.section("วิชาติดตัวมาแต่แรก (%d)" % innate.size()))
	if innate.is_empty():
		c.add_child(UIKit.label("เข้าสำนักมามือเปล่า ไม่มีวิชาติดตัว", 14, WuxiaTheme.PAPER_DIM))
	for s in innate: _add_skill_card(c, s)
	c.add_child(UIKit.section("วิชาที่เรียนรู้ในสำนัก (%d)" % learned.size()))
	if learned.is_empty():
		c.add_child(UIKit.label("ยังไม่ได้เรียนวิชาเพิ่ม (ศึกษาได้ที่หอตำรา หรือเรียนจากอาจารย์)", 14, WuxiaTheme.PAPER_DIM))
	for s in learned: _add_skill_card(c, s)

## ความชำนาญอาวุธ 6 สาย (ใช้วิชา/โจมตีด้วยอาวุธ/ศึกษาคัมภีร์ = ได้ EXP ความชำนาญ)
func _build_mastery(c: VBoxContainer) -> void:
	c.add_child(UIKit.section("ความชำนาญอาวุธ"))
	c.add_child(UIKit.label("เกณฑ์เรียนวิชา: ขั้นปฐพีต้องชำนาญระดับ %d, นภา %d, เซียน %d, เทวะ %d (วิชาปราณ/ตัวเบา/ค่ายกลไม่ต้องใช้)" % [MasterySys.REQUIRED_LEVEL[2], MasterySys.REQUIRED_LEVEL[3], MasterySys.REQUIRED_LEVEL[4], MasterySys.REQUIRED_LEVEL[5]], 13, WuxiaTheme.PAPER_DIM))
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	c.add_child(grid)
	for t in MasterySys.TYPES:
		var xp = MasterySys.get_exp(d, t)
		var lv = MasterySys.get_level(d, t)
		var col: Color = MasterySys.TYPES[t].color
		var box = VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var next = MasterySys.exp_for_level(lv + 1)
		box.add_child(UIKit.label("%s  ระดับ %d (%s)  EXP %d%s" % [MasterySys.TYPES[t].name, lv, MasterySys.RANK_NAMES[lv], xp, (" / %d" % next) if lv < MasterySys.MAX_LEVEL else ""], 14, col if lv > 0 else WuxiaTheme.PAPER_DIM))
		var bar = ProgressBar.new()
		bar.custom_minimum_size = Vector2(0, 8)
		bar.show_percentage = false
		bar.min_value = MasterySys.exp_for_level(lv)
		bar.max_value = max(bar.min_value + 1, next)
		bar.value = clampi(xp, int(bar.min_value), int(bar.max_value))
		var fill = StyleBoxFlat.new()
		fill.bg_color = col
		bar.add_theme_stylebox_override("fill", fill)
		box.add_child(bar)
		grid.add_child(box)

func _add_skill_card(c: VBoxContainer, s: String) -> void:
	var info = SkillDB.get_skill(s)
	if info.is_empty():
		c.add_child(UIKit.label(s, 15))
		return
	var col: Color = SkillDB.TIER_COLORS[info.tier]
	var card = _card(col)
	c.add_child(card[0])
	card[1].add_child(UIKit.label("%s   [ขั้น%s · %s · พลัง %d]" % [s, SkillDB.TIER_NAMES[info.tier], SkillDB.TYPE_NAMES.get(info.type, info.type), info.power], 17, col))
	card[1].add_child(UIKit.label(info.desc, 14, WuxiaTheme.PAPER))
	var mt = MasterySys.skill_type(s)
	if mt != "":
		card[1].add_child(UIKit.label("สายความชำนาญ: %s ระดับ %d (โบนัสพลังรบ %.1f x %d)" % [MasterySys.type_name(mt), MasterySys.get_level(d, mt), StatSys.skill_bonus(info.power), max(1, MasterySys.get_level(d, mt))], 13, MasterySys.TYPES[mt].color))
	var usage = "วิชาเสริม (ไม่ใช้โจมตีในการต่อสู้)"
	if info.type != "movement" and info.power > 0:
		if info.type == "internal" and (info.desc.contains("ฟื้นฟู") or info.desc.contains("รักษา")):
			usage = "ในการต่อสู้: ฟื้นฟู HP ตนเอง"
		elif info.type in ["formation", "poison"]:
			usage = "ในการต่อสู้: โจมตีศัตรูทุกตัว (ความเสียหายเพิ่ม %d x0.8)" % StatSys.skill_damage(d.get_combat_attack(), info.power, MasterySys.skill_level(d, s))
		else:
			usage = "ในการต่อสู้: โจมตีเป้าหมายเดียว (ความเสียหายเพิ่ม %d x1.5)" % StatSys.skill_damage(d.get_combat_attack(), info.power, MasterySys.skill_level(d, s))
	card[1].add_child(UIKit.label(usage, 13, WuxiaTheme.PAPER_DIM))

# ══════════════════════════════════════════
# Tab 4: อุปกรณ์และยา
# ══════════════════════════════════════════

func _build_gear(c: VBoxContainer) -> void:
	UIKit.clear(c)
	var in_transit = d.status == DiscipleData.DiscipleStatus.MISSION and d.mission_phase in ["going", "returning", "working"] and not d.is_founder
	var loc_str = _get_location_text(d)
	var loc_col = Color(0.4, 0.85, 1.0) if d.status == DiscipleData.DiscipleStatus.MISSION else Color(0.6, 1.0, 0.6)
	c.add_child(UIKit.label("📍 พิกัดของศิษย์: %s" % loc_str, 15, loc_col))
	
	var header_note = ""
	if in_transit:
		header_note = " (กำลังเดินทางกลางป่า เบิกของจากสำนักใหญ่ไม่ได้)"
	elif d.status == DiscipleData.DiscipleStatus.MISSION:
		header_note = " (ประจำการนอกสำนัก: สลับของติดตัวได้ หรือเบิกด่วนจากสำนักใหญ่)"
	c.add_child(UIKit.section("อุปกรณ์สวมใส่" + header_note))
	
	for type in EquipmentData.EquipType.values():
		var eq = d.get_equipped(type)
		var slot_name = EquipmentDB.TYPE_NAMES[type]
		if eq:
			c.add_child(UIKit.row("%s: %s [%s]\n%s" % [slot_name, eq.item_name, eq.get_rarity_name(), eq.get_stat_text()], [
				UIKit.button("ถอด", func(): GlobalGame.controller.request_unequip.emit(d, type), false)
			], eq.get_rarity_color()))
		else:
			c.add_child(UIKit.label("%s: - ว่าง -" % slot_name, 15, WuxiaTheme.PAPER_DIM))
		
		# รายการของในย่ามติดตัว (Carried Gear)
		for item in d.carried_equipment:
			if item.type != type: continue
			c.add_child(UIKit.row("    🎒 สัมภาระติดตัว: %s [%s] %s" % [item.item_name, item.get_rarity_name(), item.get_stat_text().replace("\n", " ")], [
				UIKit.button("สวมใส่", func(): GlobalGame.controller.request_equip.emit(d, item), false)
			], item.get_rarity_color()))
		
		# รายการของในคลังสำนักใหญ่ (Sect Armory)
		for item in sect.equipment_storage:
			if item.type != type: continue
			var can_fetch = not in_transit
			var btn_text = "สวมใส่" if d.status != DiscipleData.DiscipleStatus.MISSION else "เบิกใส่ด่วน"
			c.add_child(UIKit.row("    🏛️ คลังสำนักใหญ่: %s [%s] %s" % [item.item_name, item.get_rarity_name(), item.get_stat_text().replace("\n", " ")], [
				UIKit.button(btn_text, func(): GlobalGame.controller.request_equip.emit(d, item), not can_fetch)
			], item.get_rarity_color().darkened(0.15)))

	c.add_child(UIKit.section("ใช้ยา"))
	for pill_id in ["healing_pill", "qi_pill", "marrow_pill", "calm_tea"]:
		var count = sect.count_pills(pill_id)
		var r = RecipeDB.PILLS[pill_id]
		c.add_child(UIKit.row("%s (มี %d) - %s" % [r.name, count, r.desc], [
			UIKit.button("ใช้", func():
				GlobalGame.controller.request_use_pill.emit(d, pill_id)
				VFX.burst(self, get_global_mouse_position(), Color(0.6, 1, 0.7), 30), count == 0 or in_transit)
		]))
