extends Control

## หน้าสร้างเจ้าสำนัก (Point-Buy + Meta-Progression)
## - แต้มเริ่มต้น = BASE_POINTS + โบนัสจากความสำเร็จในหอเกียรติยศ
## - ใช้แต้มซื้อ: ค่ารากฐาน (3 แต้ม = ทุกค่าในหมวด +1), พรสวรรค์ (ราคาตามความแรง), วิชาเริ่มต้น (ราคาตามขั้น)
## - รับข้อบกพร่อง (ดีบัฟ) เพื่อได้แต้มคืนมาแลกของโหดๆ
## - วิชาเริ่มต้นมีแค่วิชาพื้นฐาน วิชาอื่นต้องเคย "ได้คัมภีร์" ในรอบก่อนๆ (ArchiveSys) จึงจะปลดล็อก
## - ปรับหน้าตาตัวละครเอง (ทรงผม สีผม สีผิว ชุด) แสดงผลบน Avatar ทันที

const BASE_POINTS = 20
## ราคาการเพิ่มค่ารากฐานทั้งหมวด +1 และจำนวนครั้งสูงสุดต่อหมวด
const STAT_LEVEL_COST = 3
const MAX_STAT_LEVELS = 4
const MAX_TRAITS = 3
const MAX_FLAWS = 3
const MAX_SKILLS = 3
const SKILL_COST = [0, 2, 5, 10, 18, 30]
const HAIR_COLOR_NAMES = ["ดำขลับ", "น้ำตาลเข้ม", "น้ำตาลทอง", "ขาวเงิน", "แดงเลือดนก", "น้ำเงินหมึก", "ส้มจิ้งจอก", "ฟ้าน้ำแข็ง"]
const ROBE_NAMES = ["น้ำเงินคราม", "แดงชาด", "เขียวหยก", "ขาวนวล", "ดำทมิฬ", "น้ำตาลทอง", "ม่วงพลอย", "ฟ้าคราม"]
const SKIN_NAMES = ["ขาวผ่อง", "ผิวน้ำผึ้ง", "ผิวแทน"]
const CATS = [
	{ "key": "Physical", "name": "ร่างกาย" }, { "key": "Spiritual", "name": "จิตวิญญาณ" }, { "key": "Mental", "name": "สติปัญญา" },
	{ "key": "Social", "name": "สังคม" }, { "key": "Combat", "name": "ต่อสู้" }, { "key": "Crafting", "name": "วิชาชีพ" },
]

## ตัวละครที่กำลังสร้าง (ใช้แสดง Avatar ตัวอย่าง)
var preview := DiscipleData.new()
var cat_points := {}
var picked_traits: Array[String] = []
var picked_flaws: Array[String] = []
var picked_skills: Array[String] = []

var input_name: LineEdit
var input_seed: LineEdit
var opt_gender: OptionButton
var opt_role: OptionButton
var opt_diff: OptionButton
var opt_slot: OptionButton
var opt_site: OptionButton
var opt_mode: OptionButton
var opt_teller: OptionButton
var spin_money: SpinBox
var spin_food: SpinBox
var portrait: TextureRect
var points_label: Label
var summary_label: Label
var btn_start: Button
var _tabs: TabContainer
var _stat_box: VBoxContainer
var _trait_box: VBoxContainer
var _flaw_box: VBoxContainer
var _skill_box: VBoxContainer

func _ready() -> void:
	for c in CATS: cat_points[c.key] = 0
	preview.portrait_seed = randi() % 1000000 + 1
	preview.gender = "ชาย"
	preview.race = "มนุษย์"
	preview.element = "ไฟ"
	preview.appearance = { "hair_style": 0, "hair_color": 0, "skin": 0, "robe": 0 }
	_build_ui()
	_refresh_all()

# ══════════════════════════════════════════
# สร้าง UI
# ══════════════════════════════════════════

func _build_ui() -> void:
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	add_child(margin)
	var root = VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	root.add_child(header)
	header.add_child(UIKit.button("< กลับ", func(): get_tree().change_scene_to_file("res://scene/main_menu.tscn")))
	var title = UIKit.label("สร้างเจ้าสำนัก", 26, WuxiaTheme.BRONZE.lightened(0.2))
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	header.add_child(title)
	points_label = UIKit.label("", 22, Color(1, 0.85, 0.4))
	points_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	points_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(points_label)
	btn_start = UIKit.button("ก่อตั้งสำนัก!", _on_btn_start_pressed)
	btn_start.custom_minimum_size = Vector2(180, 44)
	header.add_child(btn_start)

	var main = HBoxContainer.new()
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 12)
	root.add_child(main)

	# ── คอลัมน์ซ้าย: Avatar + หน้าตา ──
	var left_panel = PanelContainer.new()
	left_panel.custom_minimum_size = Vector2(300, 0)
	main.add_child(left_panel)
	var left_scroll = ScrollContainer.new()
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_panel.add_child(left_scroll)
	var left = VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.add_child(left)
	var center = CenterContainer.new()
	left.add_child(center)
	portrait = TextureRect.new()
	portrait.custom_minimum_size = Vector2(150, 150)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	center.add_child(portrait)
	input_name = LineEdit.new()
	input_name.placeholder_text = "ชื่อเจ้าสำนัก"
	left.add_child(_field("ชื่อ", input_name))
	opt_gender = _option(["ชาย", "หญิง"], func(i):
		preview.gender = ["ชาย", "หญิง"][i]
		_refresh_portrait())
	left.add_child(_field("เพศ", opt_gender))
	var elements = CultivationSys.ELEMENT_COLORS.keys()
	left.add_child(_field("ธาตุรากวิญญาณ", _option(elements, func(i):
		preview.element = elements[i]
		_refresh_portrait())))
	left.add_child(_field("ทรงผม", _option(ArtGen.HAIR_STYLE_NAMES, func(i): _set_look("hair_style", i))))
	left.add_child(_field("สีผม", _option(HAIR_COLOR_NAMES, func(i): _set_look("hair_color", i))))
	left.add_child(_field("สีผิว", _option(SKIN_NAMES, func(i): _set_look("skin", i))))
	left.add_child(_field("ชุดคลุม", _option(ROBE_NAMES, func(i): _set_look("robe", i))))
	left.add_child(UIKit.button("สุ่มใบหน้าใหม่", func():
		preview.portrait_seed = randi() % 1000000 + 1
		_refresh_portrait()))

	# ── คอลัมน์ขวา: แท็บ ──
	_tabs = TabContainer.new()
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(_tabs)
	_tabs.add_child(_build_sect_tab())
	_stat_box = _add_scroll_tab("สเตตัส")
	_trait_box = _add_scroll_tab("พรสวรรค์")
	_flaw_box = _add_scroll_tab("ข้อบกพร่อง (+แต้ม)")
	_skill_box = _add_scroll_tab("วิชาเริ่มต้น")

	summary_label = UIKit.label("", 14, WuxiaTheme.PAPER_DIM)
	root.add_child(summary_label)

var _mode_desc: Label
var _teller_desc: Label

## รายการที่ตั้งสำนัก: โหมดเนื้อเรื่องเลือกมณฑลได้ / โหมดแซนด์บ็อกซ์ตำแหน่งสุ่มตาม Seed
func _update_sites() -> void:
	var sandbox = opt_mode.selected == 1
	_mode_desc.text = WorldMode.MODES["sandbox" if sandbox else "story"].desc + ("
ตำแหน่งสำนักต่างๆ ตายตัวตามตำนาน แต่รหัสสร้างโลกจะสุ่มความสัมพันธ์ เจ้าเมือง ผลผลิต และเหตุการณ์" if not sandbox else "")
	opt_site.clear()
	if sandbox:
		for i in 5: opt_site.add_item("จุดเริ่มต้นที่ %d (ตำแหน่งสุ่มตามรหัสสร้างโลก)" % (i + 1))
	else:
		for s in WorldDB.LORE_START_SITES: opt_site.add_item("%s (%s)" % [s.name, WorldDB.LORE_REGIONS[s.region].name])

func _field(label_text: String, control: Control) -> HBoxContainer:
	var h = HBoxContainer.new()
	var l = UIKit.label(label_text, 15)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.custom_minimum_size = Vector2(110, 0)
	h.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(control)
	return h

func _option(items: Array, on_select: Callable) -> OptionButton:
	var o = OptionButton.new()
	for it in items: o.add_item(str(it))
	o.item_selected.connect(on_select)
	return o

func _add_scroll_tab(tab_name: String) -> VBoxContainer:
	var scroll = ScrollContainer.new()
	scroll.name = tab_name
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	_tabs.add_child(scroll)
	return box

func _build_sect_tab() -> Control:
	var scroll = ScrollContainer.new()
	scroll.name = "สำนัก & โลก"
	var box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	opt_role = _option(["เจ้าสำนัก (เริ่มรวบรวมลมปราณขั้น 5)", "จอมยุทธ์พเนจร (เริ่มจากขั้น 1 เงินครึ่งเดียว)"], func(_i): _refresh_all())
	box.add_child(_field("บทบาท", opt_role))
	opt_diff = _option(BuildingDB.DIFFICULTY.map(func(d): return d.name), func(i):
		spin_money.get_parent().visible = i == 3
		spin_food.get_parent().visible = i == 3
		_refresh_all())
	opt_diff.select(1)
	box.add_child(_field("ความยาก", opt_diff))
	box.add_child(UIKit.label("ความยากส่งผลกับ 4X: ศัตรูแข็งแกร่งขึ้น, สำนักอื่นขยายอาณาเขตเร็วขึ้น, ศิษย์ตายได้จริงเมื่อแพ้\nง่าย: ศัตรู x0.8, สำนักอื่นขยายทุก 35 วัน, ไม่มีใครตาย | ปานกลาง: x1.0, ทุก 20 วัน, ตาย 10% | นรก: x1.5, ทุก 10 วัน, ตาย 25%", 13, WuxiaTheme.PAPER_DIM))
	spin_money = SpinBox.new()
	spin_money.max_value = 100000
	spin_money.value = 1500
	box.add_child(_field("เงินเริ่มต้น", spin_money))
	spin_food = SpinBox.new()
	spin_food.max_value = 100000
	spin_food.value = 500
	box.add_child(_field("เสบียงเริ่มต้น", spin_food))
	spin_money.get_parent().visible = false
	spin_food.get_parent().visible = false
	opt_slot = OptionButton.new()
	for slot in range(1, GlobalGame.SLOT_COUNT + 1):
		var info = GlobalGame.slot_info(slot)
		opt_slot.add_item("สล็อต %d - %s" % [slot, "ว่าง" if info.is_empty() else "%s วันที่ %d (จะถูกเขียนทับ!)" % [info.sect_name, info.day]])
	var first_empty = 0
	for slot in range(1, GlobalGame.SLOT_COUNT + 1):
		if GlobalGame.slot_info(slot).is_empty():
			first_empty = slot - 1
			break
	opt_slot.select(first_empty)
	box.add_child(_field("บันทึกลงสล็อต", opt_slot))
	var tellers = StorytellerDB.STORYTELLERS.keys()
	opt_teller = _option(tellers.map(func(t): return "%s (%s)" % [StorytellerDB.STORYTELLERS[t].name, StorytellerDB.STORYTELLERS[t].style]), func(i): _teller_desc.text = StorytellerDB.STORYTELLERS[tellers[i]].desc)
	box.add_child(_field("เจตจำนงสวรรค์", opt_teller))
	_teller_desc = UIKit.label(StorytellerDB.STORYTELLERS[tellers[0]].desc + " (ภัยผูกกับความมั่งคั่งของสำนัก)", 13, WuxiaTheme.PAPER_DIM)
	box.add_child(_teller_desc)
	opt_mode = _option(["story", "sandbox"].map(func(m): return WorldMode.MODES[m].name), func(_i): _update_sites())
	box.add_child(_field("โหมดเกม", opt_mode))
	_mode_desc = UIKit.label("", 13, WuxiaTheme.PAPER_DIM)
	box.add_child(_mode_desc)
	opt_site = OptionButton.new()
	box.add_child(_field("ที่ตั้งสำนัก", opt_site))
	_update_sites()
	input_seed = LineEdit.new()
	input_seed.placeholder_text = "เว้นว่างเพื่อสุ่ม เช่น 12345 หรือ ชื่ออะไรก็ได้"
	box.add_child(_field("รหัสสร้างโลก", input_seed))
	var archive = ArchiveSys.data()
	box.add_child(UIKit.section("หอเกียรติยศ (ข้ามเซฟ)"))
	box.add_child(UIKit.label("ความสำเร็จ %d / %d (+%d แต้มเริ่มต้น) | คัมภีร์ที่ปลดล็อก %d | วิชาตกทอดของสำนักรุ่นก่อน %d | เล่นมาแล้ว %d รอบ" % [archive.achievements.size(), ArchiveSys.ACHIEVEMENTS.size(), ArchiveSys.bonus_points(), archive.unlocked_skills.size(), archive.legacy_skills.size(), int(archive.get("runs", 0))], 14))
	return scroll

# ══════════════════════════════════════════
# แต้ม
# ══════════════════════════════════════════

func _total_points() -> int:
	return BASE_POINTS + ArchiveSys.bonus_points()

static func trait_value(t: String) -> int:
	return max(1, int(round(abs(TraitDB.get_net_value(t)) * 0.75)))

func _skill_cost(s: String) -> int:
	return SKILL_COST[SkillDB.get_skill(s).get("tier", 1)]

func _spent() -> int:
	var total = 0
	for k in cat_points: total += cat_points[k] * STAT_LEVEL_COST
	for t in picked_traits: total += trait_value(t)
	for t in picked_flaws: total -= trait_value(t)
	for s in picked_skills: total += _skill_cost(s)
	return total

func _remaining() -> int:
	return _total_points() - _spent()

func _refresh_all() -> void:
	_refresh_portrait()
	_build_stats()
	_build_traits(_trait_box, true)
	_build_traits(_flaw_box, false)
	_build_skills()
	var rem = _remaining()
	points_label.text = "แต้มคงเหลือ: %d / %d" % [rem, _total_points()]
	points_label.add_theme_color_override("font_color", Color(1, 0.4, 0.35) if rem < 0 else Color(1, 0.85, 0.4))
	btn_start.disabled = rem < 0
	summary_label.text = "พรสวรรค์: %s | ข้อบกพร่อง: %s | วิชา: %s" % [
		", ".join(picked_traits) if not picked_traits.is_empty() else "-",
		", ".join(picked_flaws) if not picked_flaws.is_empty() else "-",
		", ".join(picked_skills) if not picked_skills.is_empty() else "-"]

func _set_look(key: String, value: int) -> void:
	preview.appearance[key] = value
	_refresh_portrait()

func _refresh_portrait() -> void:
	portrait.texture = ArtGen.get_portrait(preview)

func _build_stats() -> void:
	UIKit.clear(_stat_box)
	_stat_box.add_child(UIKit.label("ค่ารากฐานของคนธรรมดาสุ่ม 1-5 ตอนก่อตั้งสำนัก | %d แต้ม = ทุกค่าในหมวดนั้น +1 (สูงสุด +%d ต่อหมวด, เพดานรากฐาน %d)\nค่าพลังต่อสู้จริง = รากฐาน x ตัวคูณขั้นบำเพ็ญ + อุปกรณ์ ดังนั้นตอนเริ่มเกมพลังรบรวมจะอยู่ราว 15-30" % [STAT_LEVEL_COST, MAX_STAT_LEVELS, StatSys.POTENTIAL_CAP], 14, WuxiaTheme.PAPER_DIM))
	for c in CATS:
		var key = c.key
		var stats = StatSys.STATS_DEF.keys().filter(func(k): return StatSys.STATS_DEF[k].cat == key).map(func(k): return StatSys.STATS_DEF[k].name)
		var row = UIKit.row("%s: +%d (ใช้ %d แต้ม)\n%s" % [c.name, cat_points[key], cat_points[key] * STAT_LEVEL_COST, ", ".join(stats)], [
			UIKit.button(" - ", func():
				cat_points[key] = max(0, cat_points[key] - 1)
				_refresh_all(), cat_points[key] == 0),
			UIKit.button(" + ", func():
				cat_points[key] += 1
				_refresh_all(), _remaining() < STAT_LEVEL_COST or cat_points[key] >= MAX_STAT_LEVELS),
		])
		_stat_box.add_child(row)

func _build_traits(box: VBoxContainer, positive: bool) -> void:
	UIKit.clear(box)
	var picked = picked_traits if positive else picked_flaws
	var limit = MAX_TRAITS if positive else MAX_FLAWS
	box.add_child(UIKit.label(("เลือกพรสวรรค์ได้สูงสุด %d อย่าง (ราคาตามความแรงของผล)" % limit) if positive else ("รับข้อบกพร่องได้สูงสุด %d อย่าง แลกแต้มคืนมาซื้อของโหดๆ" % limit), 14, WuxiaTheme.PAPER_DIM))
	for t in TraitDB.TRAITS:
		var info = TraitDB.TRAITS[t]
		if info.is_positive != positive: continue
		var value = trait_value(t)
		var cb = CheckBox.new()
		cb.text = "%s  [%s %d แต้ม]  —  %s" % [t, "ราคา" if positive else "ได้คืน", value, TraitDB.get_effect_text(t)]
		cb.tooltip_text = info.desc
		cb.button_pressed = picked.has(t)
		cb.disabled = not picked.has(t) and (picked.size() >= limit or (positive and _remaining() < value))
		cb.add_theme_color_override("font_color", Color(0.6, 1, 0.6) if positive else Color(1, 0.6, 0.55))
		cb.toggled.connect(func(on):
			if on and not picked.has(t): picked.append(t)
			elif not on: picked.erase(t)
			_refresh_all())
		box.add_child(cb)

func _build_skills() -> void:
	UIKit.clear(_skill_box)
	_skill_box.add_child(UIKit.label("เลือกได้สูงสุด %d วิชา | ราคา: มนุษย์ 2, ปฐพี 5, นภา 10, เซียน 18, เทวะ 30\nวิชาที่ยังล็อกอยู่ ต้องเคยได้คัมภีร์นั้นจากการเล่นรอบก่อนๆ (ดรอป/แดนลับ/ประมูล/ถอดรหัส) ระบบจะจำไว้ในหอเกียรติยศ" % MAX_SKILLS, 13, WuxiaTheme.PAPER_DIM))
	var names = SkillDB.all_skill_names()
	names.sort_custom(func(a, b): return SkillDB.get_skill(a).tier < SkillDB.get_skill(b).tier)
	var locked = 0
	for s in names:
		var info = SkillDB.get_skill(s)
		if not ArchiveSys.is_skill_unlocked(s):
			locked += 1
			continue
		var cost = SKILL_COST[info.tier]
		var cb = CheckBox.new()
		cb.text = "[%s] %s%s  (%s พลัง %d)  ราคา %d แต้ม" % [SkillDB.TIER_NAMES[info.tier], s, " ★วิชาตกทอด" if info.get("custom", false) else "", SkillDB.TYPE_NAMES.get(info.type, info.type), info.power, cost]
		cb.tooltip_text = info.desc
		cb.button_pressed = picked_skills.has(s)
		cb.disabled = not picked_skills.has(s) and (picked_skills.size() >= MAX_SKILLS or _remaining() < cost)
		cb.add_theme_color_override("font_color", SkillDB.TIER_COLORS[info.tier])
		cb.toggled.connect(func(on):
			if on and not picked_skills.has(s): picked_skills.append(s)
			elif not on: picked_skills.erase(s)
			_refresh_all())
		_skill_box.add_child(cb)
	_skill_box.add_child(UIKit.label("ยังล็อกอยู่อีก %d วิชา" % locked, 14, Color(0.6, 0.55, 0.5)))

# ══════════════════════════════════════════
# ก่อตั้งสำนัก
# ══════════════════════════════════════════

var _overwrite_ok := false

func _on_btn_start_pressed() -> void:
	if _remaining() < 0: return
	var slot_path = GlobalGame.slot_path(opt_slot.selected + 1)
	if not _overwrite_ok and FileAccess.file_exists(slot_path):
		var dlg = ConfirmationDialog.new()
		dlg.title = "เซฟเดิมมีอยู่แล้ว"
		dlg.dialog_text = "สล็อต %d มีเซฟอยู่แล้ว จะเขียนทับด้วยสำนักใหม่ไหม? (ระบบจะสำรองของเดิมไว้เป็นไฟล์ .bak)" % (opt_slot.selected + 1)
		dlg.confirmed.connect(func():
			_overwrite_ok = true
			_on_btn_start_pressed())
		add_child(dlg)
		dlg.popup_centered()
		return
	if FileAccess.file_exists(slot_path):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(slot_path), ProjectSettings.globalize_path(slot_path) + ".bak")
	var char_name = input_name.text.strip_edges()
	if char_name == "":
		char_name = "จอมยุทธ์นิรนาม"
	var role_id = opt_role.selected
	var diff_id = opt_diff.selected
	var slot = opt_slot.selected + 1

	var new_sect = SectData.new()
	new_sect.sect_name = "สำนัก" + char_name
	new_sect.difficulty = diff_id
	match diff_id:
		0: new_sect.money = 2000; new_sect.food = 700
		1: new_sect.money = 1200; new_sect.food = 450
		2: new_sect.money = 600; new_sect.food = 250
		3: new_sect.money = int(spin_money.value); new_sect.food = int(spin_food.value)
	if role_id == 1:
		new_sect.sect_name = "ค่ายพักแรมของ" + char_name
		if diff_id != 3:
			new_sect.money /= 2
			new_sect.food /= 2
	# ที่ดินว่างเปล่า: วัสดุตั้งต้นเล็กน้อยไว้สร้างอาคารหลังแรก
	new_sect.add_materials({ "wood": 60, "stone": 40 })

	var main_char = DiscipleData.new()
	main_char.disciple_name = char_name
	main_char.is_founder = true
	main_char.gender = preview.gender
	main_char.race = "มนุษย์"
	main_char.portrait_seed = preview.portrait_seed
	main_char.element = preview.element
	main_char.appearance = preview.appearance.duplicate()
	main_char.age = 20
	main_char.loyalty = 100

	# ค่ารากฐาน: สุ่ม 1-5 + แต้มที่ซื้อ (บันทึกที่มาทุกรายการ)
	NPCGenerator.roll_base_stats(main_char)
	for key in StatSys.STATS_DEF:
		var lv = cat_points.get(StatSys.STATS_DEF[key].cat, 0)
		main_char.add_stat(key, lv, "แต้มที่ซื้อตอนสร้างตัวละคร (%d แต้ม)" % (lv * STAT_LEVEL_COST))
	var all_traits: Array[String] = []
	all_traits.append_array(picked_traits)
	all_traits.append_array(picked_flaws)
	for t in all_traits:
		TraitDB.apply_trait_effects(main_char, t)
	main_char.ext_traits.assign(all_traits)
	main_char.personality_traits.assign(all_traits)
	main_char.learned_skills.assign(picked_skills)
	main_char.innate_skills.assign(picked_skills)
	for s in picked_skills:
		MasterySys.grant_background(main_char, s)
	main_char.background_story = "ผู้ก่อตั้ง%s %s" % [new_sect.sect_name, BackgroundDB.generate_story("มนุษย์")]

	main_char.level = 5 if role_id == 0 else 1
	main_char.realm_name = CultivationSys.get_realm_info(main_char.level).name
	main_char.comprehension = main_char.get_stat("comprehension")
	main_char.aptitude_root = main_char.get_stat("aptitude")
	main_char.status = DiscipleData.DiscipleStatus.IDLE
	main_char.job = "construction"
	new_sect.disciples.append(main_char)

	# ศิษย์รุ่นแรก 2 คนไว้เป็นแรงงานตัดไม้/ขุดหิน
	var first = NPCGenerator.generate_npc(0, 1)
	var second = NPCGenerator.generate_npc(0, 1)
	new_sect.disciples.append_array([first, second])
	for d in new_sect.disciples:
		for s in d.innate_skills: new_sect.add_library_skill(s)

	new_sect.world_version = 2
	new_sect.storyteller = StorytellerDB.STORYTELLERS.keys()[opt_teller.selected]
	new_sect.world_mode = "sandbox" if opt_mode.selected == 1 else "story"
	new_sect.start_site = WorldDB.LORE_START_SITES[opt_site.selected].id if opt_mode.selected == 0 else "sb_site_%d" % opt_site.selected
	var seed_text = input_seed.text.strip_edges()
	if seed_text != "":
		new_sect.world_seed = int(seed_text) if seed_text.is_valid_int() else abs(hash(seed_text))

	ArchiveSys.new_run()
	GlobalGame.current_slot = slot
	GlobalGame.set_sect(new_sect)
	GlobalGame.paused = false
	GlobalGame.save_game()
	get_tree().change_scene_to_file("res://scene/test_sect.tscn")
