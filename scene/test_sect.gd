extends Node2D

## หน้าสำนัก (2.5D): เวลาเดินเองอัตโนมัติ (เช้า - บ่าย - กลางคืน) กดหยุด/เร่งความเร็วได้
## ศิษย์ใช้ชีวิตตามตาราง มอบหมายงานยามเช้าได้จากรายชื่อด้านขวา
## เริ่มเกมใหม่เป็นที่ดินว่างเปล่า ต้องตัดไม้ ขุดหิน แล้วสั่งก่อสร้างอาคาร
## ผู้เล่นเป็นเจ้าสำนักที่มองจากมุมสูง: วางผัง ตั้งตารางงาน/ตารางเวลา นโยบาย และตัดสินใจเหตุการณ์ (ศิษย์ทำงานเอง)
## View ของ MVC: ปุ่มส่งคำสั่งไปที่ GlobalGame.controller และวาดใหม่เมื่อได้ Signal sect_changed

var sect_manager: SectManager
var test_sect: SectData

## หน้าต่างป๊อปอัปที่เปิดอยู่ (เก็บไว้เพื่อรีเฟรช/ปิด)
var _window: Dictionary = {}
var _window_builder: Callable
var _dragging := false
var _drag_moved := 0.0
var _list_dirty := true
var _window_dirty := false
var _list_timer := 2.0
## โหมดเดิน: บังคับเจ้าสำนักเดินในลานสำนัก
var _hud: InteractionHUD
## โหมดเดินในสำนักแบบ HD-2D (null = มุมมองผู้บริหาร)
var _walk3d: SectWalk3D
var _walk_button: Button

func _ready() -> void:
	setup_sect()
	%SectView.setup(test_sect)
	%SectView.building_clicked.connect(_on_building_clicked)
	%SectView.disciple_clicked.connect(_on_disciple_clicked)
	%SectView.layout_message.connect(func(t, ok): UIKit.toast(%UIRoot, t, Color(0.7, 1, 0.7) if ok else Color(1, 0.55, 0.45)))
	%SectView.building_entered.connect(_on_building_clicked)
	_hud = InteractionHUD.new()
	%UIRoot.add_child(_hud)
	%Camera.position = SectView.iso(Vector2(Territory.HOME)) + Vector2(0, 60)

	%PauseButton.pressed.connect(_toggle_pause)
	%SpeedButton.pressed.connect(func():
		GlobalGame.cycle_speed()
		_update_clock())
	var skip_btn = UIKit.button("ข้ามไปพรุ่งนี้ [N]", _skip_night)
	skip_btn.tooltip_text = "จำลองเวลาจนถึงเช้าวันถัดไป (ก่อสร้าง/ผลิต/ศึกษาเดินครบ) แล้วสรุปให้ดู · หยุดเองถ้ามีเรื่องให้ตัดสินใจ"
	%SpeedButton.get_parent().add_child(skip_btn)
	%SpeedButton.get_parent().move_child(skip_btn, %SpeedButton.get_index() + 1)
	%LogToggle.pressed.connect(func():
		%EventLog.visible = not %EventLog.visible
		%LogPanel.offset_top = -150 if %EventLog.visible else -40
		%LogToggle.text = "ย่อ" if %EventLog.visible else "ขยาย")

	_build_menu()
	GlobalGame.phase_changed.connect(_on_phase_changed)
	GlobalGame.day_changed.connect(func(_d):
		_list_dirty = true
		_window_dirty = true)
	GlobalGame.sect_event_logged.connect(_on_sect_event_logged)
	GlobalGame.game_over.connect(_on_game_over)
	GlobalGame.controller.sect_changed.connect(_on_sect_changed)
	GlobalGame.controller.action_result.connect(_on_action_result)
	GlobalGame.clock_enabled = true

	for e in test_sect.event_log.slice(-15):
		_add_log_entry("[color=yellow][วันที่ %d][/color] %s" % [e.day, e.text])
	update_ui()
	if test_sect.is_game_over:
		_on_game_over()

func _exit_tree() -> void:
	GlobalGame.clock_enabled = false

func setup_sect() -> void:
	if GlobalGame.current_sect == null:
		# เปิดฉากนี้ตรงๆ ในเอดิเตอร์: สร้างสำนักทดสอบ
		var sect = SectData.new()
		sect.sect_name = "สำนักกิเลนทะยาน"
		sect.money = 1000
		sect.food = 300
		sect.disciples.append_array(NPCGenerator.generate_starting_disciples())
		sect.disciples[0].is_founder = true
		GlobalGame.set_sect(sect)
	test_sect = GlobalGame.current_sect
	sect_manager = GlobalGame.sect_manager

func _build_menu() -> void:
	_walk_button = UIKit.button("เดินในสำนัก (Tab)", _toggle_walk)
	_walk_button.custom_minimum_size = Vector2(0, 40)
	_walk_button.add_theme_color_override("font_color", Color(0.7, 1, 0.75))
	%Menu.add_child(_walk_button)
	var big = Vector2(920, 640)
	var items = [
		["สำนัก (ภาพรวม)", Color(1, 0.9, 0.5), func(): _open_hub("home", "สำนัก", [["ภาพรวมและแจ้งเตือน", _build_overview_window]], big)],
		["ตึกและงาน", Color(0.75, 1, 0.6), func(): _goto_hub("work", -1)],
		["ศิษย์", Color(0.7, 1, 0.7), func(): _goto_hub("people", -1)],
		["ฝึกและวิชา", Color(0.5, 0.8, 1), func(): _open_hub("train", "ฝึกและวิชา", [
			["หอตำรา", _build_library_window], ["หอหลอมโอสถ", _build_alchemy_window], ["โรงหลอมศาสตรา", _build_forge_window],
			["ทะลวงคอขวด", _build_breakthrough_window], ["ผังขั้นบำเพ็ญ", _build_realm_window]], big)],
		["ยุทธภพ", Color(1, 0.6, 0.5), func(): _open_hub("world", "ยุทธภพ", [
			["การเมือง", _build_politics_window], ["ทำเนียบ", _build_rankings_window],
			["กองคาราวาน", func(c): SimWindows.caravan(c, test_sect, _refresh_window)],
			["เส้นทางสู่จุดจบ", _build_endings_window],
			["เจตจำนงสวรรค์", func(c): SimWindows.storyteller(c, test_sect, _refresh_window)]], big)],
		["คลัง", WuxiaTheme.PAPER, func(): _open_window("คลังสมบัติสำนัก", _build_storage_window)],
		["แผนที่โลก", Color(0.8, 0.6, 1), _on_btn_hunt_pressed],
		["เซฟ & กลับหน้าหลัก", WuxiaTheme.PAPER_DIM, func():
			GlobalGame.save_game()
			get_tree().change_scene_to_file("res://scene/main_menu.tscn")],
	]
	for item in items:
		var b = UIKit.button(item[0], item[2])
		b.custom_minimum_size = Vector2(0, 40)
		b.add_theme_color_override("font_color", item[1])
		%Menu.add_child(b)
	%Menu.add_child(UIKit.label("ลากเพื่อเลื่อนกล้อง | ล้อเมาส์ซูม\nคลิกอาคาร/ศิษย์ในลานสำนัก\nSpacebar = หยุดเวลา · N = ข้ามไปพรุ่งนี้", 12, WuxiaTheme.PAPER_DIM))

# ══════════════════════════════════════════
# เวลา
# ══════════════════════════════════════════

## ข้ามไปเช้าพรุ่งนี้ (กด [N] หรือปุ่มบนแถบบน ใช้ได้ทุกช่วงเวลา) — จำลองครบทุก tick แล้วขึ้นรายงานสรุป
func _skip_night() -> void:
	if not test_sect.pending_event.is_empty() or not test_sect.pending_story.is_empty() or test_sect.is_game_over: return
	var rep = DaySkip.skip_to_morning(test_sect, sect_manager)
	%SectView.refresh()
	if _walk3d != null: _walk3d.refresh()
	_list_dirty = true
	_open_window("รายงานประจำวัน", func(c): _build_day_report(c, rep), Vector2(760, 560))

func _build_day_report(c: VBoxContainer, rep: Dictionary) -> void:
	if rep.stopped != "":
		c.add_child(UIKit.label("⚠ หยุดข้ามเวลา: %s — ตัดสินใจก่อนแล้วค่อยข้ามต่อ" % rep.stopped, 16, Color(1, 0.6, 0.4)))
	var body = RichTextLabel.new()
	body.bbcode_enabled = true
	body.fit_content = true
	body.add_theme_font_size_override("normal_font_size", 15)
	body.text = "
".join(rep.lines)
	c.add_child(body)
	if not rep.log.is_empty():
		c.add_child(UIKit.section("เหตุการณ์ระหว่างนั้น (%d)" % rep.log.size()))
		var lg = RichTextLabel.new()
		lg.bbcode_enabled = true
		lg.fit_content = true
		lg.add_theme_font_size_override("normal_font_size", 13)
		lg.text = "
".join(rep.log.slice(-25).map(func(t): return "• " + t))
		c.add_child(lg)
	c.add_child(UIKit.button("ข้ามต่ออีกวัน [N]", func():
		_close_window()
		_skip_night(), rep.stopped != ""))

## เปิด/ปิดโหมดเดิน: ใช้เจ้าสำนัก (หรือศิษย์ที่อยู่ในสำนัก) เป็นอวตาร
func _toggle_walk() -> void:
	var d = test_sect.get_founder()
	if d == null or not d.is_available():
		var others = test_sect.disciples.filter(func(x): return x.is_available())
		if others.is_empty():
			UIKit.toast(%UIRoot, "ไม่มีศิษย์อยู่ในสำนักให้เดิน", Color(1, 0.55, 0.45))
			return
		d = others[0]
	# โหมดเดินแบบ HD-2D (ฉาก 3D) แทนมุมมองผู้บริหาร 2D ชั่วคราว
	var on = _walk3d == null
	if on:
		%SectView.end_mode()
		_walk3d = SectWalk3D.new()
		add_child(_walk3d)
		_walk3d.setup(test_sect, d)
		_walk3d.building_entered.connect(_on_building_clicked)
	else:
		_walk3d.queue_free()
		_walk3d = null
		%Camera.make_current()
	%SectView.visible = not on
	$BG.visible = not on
	# ซ่อนแผงรายชื่อ/บันทึกให้เห็นฉากเต็มตาตอนเดิน (เมนูซ้ายยังอยู่)
	$UI/UIRoot/RightPanel.visible = not on
	$UI/UIRoot/LogPanel.visible = not on
	_walk_button.text = "กลับมุมมองผู้บริหาร (Tab)" if on else "เดินในสำนัก (Tab)"
	if on: UIKit.toast(%UIRoot, "%s เดินในสำนัก: WASD/คลิกเดิน · Shift วิ่ง · ล้อเมาส์ซูม · หน้าอาคารกด [E] (ความเร็ว x%.2f จากความว่องไว)" % [d.disciple_name, StatSys.walk_speed_mult(d)])

# ── อีเวนต์เนื้อเรื่อง (หยุดเวลาจนกว่าผู้เล่นจะเลือก) ──

var _story_window := {}

func _open_story() -> void:
	var ch = StorySys.get_chapter(test_sect.pending_story.id)
	if ch.is_empty():
		test_sect.pending_story = {}
		return
	GlobalGame.paused = true
	_story_window = UIKit.open_window(%UIRoot, "【เนื้อเรื่อง】 " + ch.title, Vector2(720, 380))
	_story_window.content.add_child(UIKit.label(ch.text, 18))
	var choose = func(i):
		var text = StorySys.choose(test_sect, i)
		if text != "": UIKit.toast(%UIRoot, text)
		_story_window.root.queue_free()
		_story_window = {}
		GlobalGame.paused = false
		update_ui()
	if ch.options.is_empty():
		_story_window.content.add_child(UIKit.button("รับทราบ", choose.bind(-1)))
	for i in ch.options.size():
		var opt = ch.options[i]
		_story_window.content.add_child(UIKit.button(opt.text, choose.bind(i), test_sect.money < opt.get("cost", 0)))
	# ปิดหน้าต่างโดยไม่เลือก = ไม่เข้าไปเกี่ยวข้อง
	_story_window.root.tree_exited.connect(func():
		if not _story_window.is_empty():
			_story_window = {}
			StorySys.choose(test_sect, -1)
			GlobalGame.paused = false)

func _toggle_pause() -> void:
	GlobalGame.paused = not GlobalGame.paused
	_update_clock()

func _process(_delta: float) -> void:
	_update_clock()
	if not test_sect.pending_story.is_empty() and _story_window.is_empty():
		_open_story()
	elif test_sect.pending_ending != "" and _ending_window.is_empty() and not test_sect.is_game_over:
		_open_ending()
	elif not test_sect.pending_event.is_empty() and _event_window.is_empty() and _story_window.is_empty():
		_open_event()
	_list_timer -= _delta
	if _list_timer <= 0.0:
		_list_timer = 1.5
		_update_header()
		_sync_disciple_list()
	_hud.blocked = not _window.is_empty() and is_instance_valid(_window.root)
	if _walk3d != null:
		_walk3d.blocked = _hud.blocked or not _story_window.is_empty() or not _event_window.is_empty()
	if _list_dirty:
		_list_dirty = false
		_update_header()
		_sync_disciple_list()
	# หน้าต่างป๊อปอัปสร้างใหม่เฉพาะเมื่อข้อมูลเปลี่ยนจริง (ช่วงเวลา/วัน/การกระทำ) ไม่ใช่ทุกบรรทัดบันทึก
	if _window_dirty:
		_window_dirty = false
		_refresh_window()

func _update_clock() -> void:
	%Landscape.hour = GlobalGame.get_hour()
	%ClockLabel.text = GlobalGame.get_clock_text()
	%PhaseBar.value = test_sect.phase_progress
	%PauseButton.text = "เดินเวลา" if GlobalGame.paused else "หยุดเวลา"
	%SpeedButton.text = "x%d" % GlobalGame.get_speed()

func _on_phase_changed(_phase: int) -> void:
	%SectView.refresh()
	if _walk3d != null: _walk3d.refresh()
	_list_dirty = true
	_window_dirty = true

# ══════════════════════════════════════════
# UI หลัก
# ══════════════════════════════════════════

func update_ui(refresh_window := true) -> void:
	_update_header()
	_sync_disciple_list()
	if refresh_window: _refresh_window()

## แถบทรัพยากร/ข่าวบนจอ (เบา เรียกถี่ได้)
func _update_header() -> void:
	var s = test_sect
	%ResLabel.text = "เงิน %d | อาหาร %d | ไม้ %d | หิน %d | หญ้าวิญญาณ %d | คัมภีร์ชำรุด %d" % [s.money, s.food, s.get_material_count("wood"), s.get_material_count("stone"), s.get_material_count("spirit_grass"), s.get_material_count("scripture_fragment")]
	var news: Array[String] = []
	var day = s.current_day
	if WorldDB.is_secret_realm_open(day):
		news.append("แดนลับเปิดอยู่! (ปิดในอีก %d วัน)" % WorldDB.days_until_secret_realm_closes(day))
	else:
		news.append("แดนลับเปิดในอีก %d วัน" % WorldDB.days_until_secret_realm(day))
	news.append("ประชุมยุทธภพในอีก %d วัน" % (FactionSys.CONFERENCE_INTERVAL - day % FactionSys.CONFERENCE_INTERVAL))
	if s.wulin_leader != "":
		news.append("จ้าวยุทธภพ: " + ("สำนักเรา!" if s.wulin_leader == "player" else FactionDB.FACTIONS[s.wulin_leader].name))
	var wars = s.factions.keys().filter(func(f): return s.factions[f].war)
	if not wars.is_empty():
		news.append("ทำสงครามกับ: " + ", ".join(wars.map(func(f): return FactionDB.FACTIONS[f].name)))
	if not s.pending_tribute.is_empty():
		news.append("สิบขันทีเรียกส่วย %d (อีก %d วัน)" % [s.pending_tribute.amount, s.pending_tribute.deadline - day])
	for inst in s.construction_sites():
		news.append("กำลังสร้าง %s %d%%" % [BuildingDB.inst_name(inst), int(inst.site.work / inst.site.required * 100)])
	if not s.fires.is_empty(): news.append("ไฟไหม้ %d จุด!" % s.fires.size())
	if not s.animals.is_empty(): news.append(AnimalSys.summary(s))
	var stressed = s.get_active_disciples().filter(func(d): return d.stress >= StressSystem.WARN_AT)
	if not stressed.is_empty(): news.append("เครียดจัด: " + ", ".join(stressed.map(func(d): return d.disciple_name)))
	var idle = s.get_active_disciples().filter(func(d): return d.post == "" and d.is_available() and not d.is_child)
	if idle.size() > 0: news.append("ศิษย์ว่าง %d คน (มอบหมายเข้าตึก)" % idle.size())
	news.append("อาหาร %d ที่ · ภัย %d" % [s.meals, StorytellerSystem.threat_points(s)])
	news.append("ความยาก: " + BuildingDB.diff(s.difficulty).name)
	%NewsLabel.text = "  |  ".join(news)

	var favs = s.get_active_disciples().filter(func(d): return d.favorite or d.is_founder).size()
	%DisciplesTitle.text = "ศิษย์ที่ปักหมุด %d · ทั้งหมด %d / %d คน" % [favs, s.get_active_disciples().size(), s.get_max_disciples()]

## รายชื่อศิษย์ด้านขวา: สร้างแถวครั้งเดียวต่อคนแล้วอัปเดตค่าในที่เดิม (ไม่สร้างปุ่มใหม่ทุกครั้ง — กันภาพสะดุด)
var _rows := {} # DiscipleData -> { box, btn, mood, fill, status }

## แผงขวา: แสดงเฉพาะศิษย์ที่ปักหมุด (หัวใจ) + เจ้าสำนัก · ดูทั้งหมดได้จากปุ่ม "ทำเนียบศิษย์"
var _roster_btn: Button
var _fav_hint: Label

func _sync_disciple_list() -> void:
	if _roster_btn == null:
		_roster_btn = UIKit.button("ทำเนียบศิษย์ (ดูทั้งหมด)", func(): _open_window("ทำเนียบศิษย์", _build_roster_window, Vector2(1000, 640)))
		var vb = %DiscipleList.get_parent().get_parent()
		vb.add_child(_roster_btn)
		vb.move_child(_roster_btn, 1)
		_fav_hint = UIKit.label("ยังไม่ได้ปักหมุดใคร — เปิดทำเนียบศิษย์แล้วกด ♡ ที่การ์ด เพื่อให้ขึ้นที่นี่", 12, WuxiaTheme.PAPER_DIM)
		vb.add_child(_fav_hint)
		vb.move_child(_fav_hint, 2)
	_roster_btn.text = "ทำเนียบศิษย์ (ดูทั้งหมด %d คน)" % test_sect.get_active_disciples().size()
	var seen := {}
	var shown = test_sect.get_active_disciples().filter(func(d): return d.favorite or d.is_founder)
	_fav_hint.visible = shown.size() <= 1
	for d in shown:
		seen[d] = true
		var r = _rows.get(d)
		if r == null or not is_instance_valid(r.box):
			r = _make_disciple_row(d)
			_rows[d] = r
			%DiscipleList.add_child(r.box)
		_update_disciple_row(d, r)
	for d in _rows.keys():
		if not seen.has(d):
			_rows[d].box.queue_free()
			_rows.erase(d)

func _make_disciple_row(d: DiscipleData) -> Dictionary:
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	var row = HBoxContainer.new()
	var btn = Button.new()
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.clip_text = true
	btn.pressed.connect(func(): _on_disciple_clicked(d))
	# ข้อความชี้เมาส์คำนวณตอนชี้เท่านั้น (พลังรบคำนวณแพง)
	btn.mouse_entered.connect(func():
		btn.tooltip_text = "%s (ตัวคูณ x%.2f)
%s
พลังรบรวม %d | ชื่อเสียง %d" % [d.realm_name, d.get_realm_multiplier(), d.get_status_text(), d.get_power_rating(), d.fame])
	row.add_child(btn)
	if not d.is_founder:
		var unpin = Button.new()
		unpin.text = "♥"
		unpin.tooltip_text = "เลิกปักหมุด"
		unpin.add_theme_color_override("font_color", Color(1, 0.45, 0.5))
		unpin.pressed.connect(func():
			d.favorite = false
			_list_dirty = true
			_window_dirty = true)
		row.add_child(unpin)
	var mood = ProgressBar.new()
	mood.custom_minimum_size = Vector2(70, 10)
	mood.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mood.show_percentage = false
	var fill = StyleBoxFlat.new()
	mood.add_theme_stylebox_override("fill", fill)
	row.add_child(mood)
	box.add_child(row)
	var status = UIKit.label("", 11, WuxiaTheme.PAPER_DIM)
	status.autowrap_mode = TextServer.AUTOWRAP_OFF
	status.clip_text = true
	box.add_child(status)
	return { "box": box, "btn": btn, "mood": mood, "fill": fill, "status": status }

func _update_disciple_row(d: DiscipleData, r: Dictionary) -> void:
	var info = CultivationSys.get_realm_info(d.level)
	var ready_to_break = info.is_bottleneck and d.experience >= CultivationSys.get_required_exp(d.level)
	# แก้ค่าเฉพาะที่เปลี่ยนจริง (การตั้งข้อความ/สีทุกครั้งทำให้ UI คำนวณเลย์เอาต์ใหม่ทุกแถว = ภาพสะดุด)
	var text = "%s%s" % [d.get_display_name(), " (คอขวด!)" if ready_to_break else ""]
	if r.get("text") != text:
		r["text"] = text
		r.btn.text = text
	var color_key = 2 if d.feud_target != "" else (1 if ready_to_break else 0)
	if r.get("color_key") != color_key:
		r["color_key"] = color_key
		if color_key == 2: r.btn.add_theme_color_override("font_color", Color(1, 0.35, 0.3))
		elif color_key == 1: r.btn.add_theme_color_override("font_color", Color(1, 0.6, 0.5))
		else: r.btn.remove_theme_color_override("font_color")
	var mood_i = int(d.mood)
	if r.get("mood_i") != mood_i:
		r["mood_i"] = mood_i
		r.mood.value = d.mood
		r.mood.tooltip_text = "อารมณ์ %d (เป้าหมาย %d)" % [d.mood, d.mood_target]
		r.fill.bg_color = Color(0.45, 0.8, 1) if d.mood >= 35 else (Color(1, 0.6, 0.3) if d.mood >= 20 else Color(1, 0.3, 0.25))
	var st = "  %s · %s" % [d.realm_name, d.get_status_text()]
	if r.get("status_text") != st:
		r["status_text"] = st
		r.status.text = st
	var stressed = d.stress >= StressSystem.WARN_AT
	if r.get("stressed") != stressed:
		r["stressed"] = stressed
		r.status.add_theme_color_override("font_color", Color(1, 0.4, 0.35) if stressed else WuxiaTheme.PAPER_DIM)

# ── ทำเนียบศิษย์: การ์ด (หน้าสี่เหลี่ยม + ตัวละครยืน) กรอง/เรียงได้ ──
var _rf_status := 0
var _rf_style := 0
var _rf_sort := 0
var _rf_query := ""
const RF_STATUS = ["ทั้งหมด", "ปักหมุด ♥", "ว่างงาน", "ประจำตึก", "บาดเจ็บ/ป่วย", "ออกภารกิจ", "เครียดหนัก", "ใกล้คอขวด"]
const RF_SORT = ["พลังรบ", "ขั้นพลัง", "ชื่อ", "อารมณ์", "ชื่อเสียง"]

func _roster_match(d: DiscipleData) -> bool:
	if _rf_query != "" and not d.disciple_name.contains(_rf_query): return false
	match _rf_status:
		1: if not (d.favorite or d.is_founder): return false
		2: if not (d.post == "" and d.is_available()): return false
		3: if d.post == "": return false
		4: if d.injury_days <= 0 and d.ailments.is_empty(): return false
		5: if d.status != DiscipleData.DiscipleStatus.MISSION: return false
		6: if d.stress < StressSystem.WARN_AT: return false
		7:
			var info = CultivationSys.get_realm_info(d.level)
			if not info.is_bottleneck: return false
	if _rf_style > 0:
		var t: String = MasterySys.TYPES.keys()[_rf_style - 1]
		if MasterySys.best_type(d) != t: return false
	return true

func _rf_label(t: String) -> Label:
	var l = UIKit.label(t, 13, WuxiaTheme.PAPER_DIM)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l

func _build_roster_window(c: VBoxContainer) -> void:
	# แถบกรอง
	var bar = HFlowContainer.new()
	bar.add_theme_constant_override("h_separation", 8)
	var st = OptionButton.new()
	for s in RF_STATUS: st.add_item(s)
	st.selected = _rf_status
	st.item_selected.connect(func(i):
		_rf_status = i
		_refresh_window())
	bar.add_child(_rf_label("สถานะ:"))
	bar.add_child(st)
	var sty = OptionButton.new()
	sty.add_item("ทุกสาย")
	for t in MasterySys.TYPES: sty.add_item(MasterySys.type_name(t))
	sty.selected = _rf_style
	sty.item_selected.connect(func(i):
		_rf_style = i
		_refresh_window())
	bar.add_child(_rf_label("สายถนัด:"))
	bar.add_child(sty)
	var so = OptionButton.new()
	for s in RF_SORT: so.add_item(s)
	so.selected = _rf_sort
	so.item_selected.connect(func(i):
		_rf_sort = i
		_refresh_window())
	bar.add_child(_rf_label("เรียงตาม:"))
	bar.add_child(so)
	var q = LineEdit.new()
	q.placeholder_text = "ค้นชื่อ แล้วกด Enter"
	q.text = _rf_query
	q.custom_minimum_size = Vector2(160, 0)
	q.text_submitted.connect(func(t):
		_rf_query = t.strip_edges()
		_refresh_window())
	bar.add_child(q)
	c.add_child(bar)
	# รายชื่อหลังกรอง/เรียง (พลังรบคำนวณครั้งเดียวต่อคน)
	var list = test_sect.get_active_disciples().filter(_roster_match)
	var power := {}
	for d in list: power[d] = d.get_power_rating()
	match _rf_sort:
		0: list.sort_custom(func(a, b): return power[a] > power[b])
		1: list.sort_custom(func(a, b): return a.level > b.level)
		2: list.sort_custom(func(a, b): return a.disciple_name < b.disciple_name)
		3: list.sort_custom(func(a, b): return a.mood > b.mood)
		4: list.sort_custom(func(a, b): return a.fame > b.fame)
	c.add_child(UIKit.label("แสดง %d จาก %d คน · กด ♡ เพื่อปักหมุดไว้ที่แผงขวา · กดการ์ดเพื่อดูประวัติ" % [list.size(), test_sect.get_active_disciples().size()], 13, WuxiaTheme.BRONZE))
	var grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	c.add_child(grid)
	for d in list: grid.add_child(_roster_card(d, power[d]))

func _roster_card(d: DiscipleData, pwr: int) -> Control:
	var card = Button.new()
	card.custom_minimum_size = Vector2(205, 232)
	card.pressed.connect(func(): _on_disciple_clicked(d))
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.11, 0.09, 0.95)
	sb.border_color = Color(1, 0.75, 0.4) if (d.favorite or d.is_founder) else Color(0.45, 0.38, 0.26)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	card.add_theme_stylebox_override("normal", sb)
	var hov = sb.duplicate()
	hov.bg_color = Color(0.22, 0.18, 0.12, 0.98)
	card.add_theme_stylebox_override("hover", hov)
	var v = VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 6
	v.offset_right = -6
	v.offset_top = 6
	v.offset_bottom = -6
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 2)
	card.add_child(v)
	# รูปหน้าสี่เหลี่ยม + ตัวละครยืนเต็มตัว
	var pics = HBoxContainer.new()
	pics.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pics.alignment = BoxContainer.ALIGNMENT_CENTER
	var face = TextureRect.new()
	face.texture = ArtGen.get_portrait(d)
	face.custom_minimum_size = Vector2(84, 84)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var face_bg = PanelContainer.new()
	var fsb = StyleBoxFlat.new()
	fsb.bg_color = CultivationSys.get_aura_color(d.element, d.level).darkened(0.55)
	fsb.border_color = Color(0.7, 0.6, 0.4)
	fsb.set_border_width_all(1)
	face_bg.add_theme_stylebox_override("panel", fsb)
	face_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face_bg.add_child(face)
	pics.add_child(face_bg)
	var body = TextureRect.new()
	body.texture = HD2D.outlined(ArtGen.get_figure(d))
	body.custom_minimum_size = Vector2(60, 84)
	body.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	body.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pics.add_child(body)
	v.add_child(pics)
	var nm = UIKit.label(("★ " if d.is_founder else "") + d.disciple_name, 15, Color(1, 0.92, 0.75))
	nm.autowrap_mode = TextServer.AUTOWRAP_OFF
	nm.clip_text = true
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(nm)
	for t in [
		["%s" % d.realm_name, CultivationSys.get_aura_color(d.element, d.level).lightened(0.3)],
		["พลังรบ %d · %s" % [pwr, MasterySys.type_name(MasterySys.best_type(d)) if MasterySys.best_type(d) != "" else "ยังไม่ถนัดสายใด"], WuxiaTheme.PAPER],
		[(BuildingDB.inst_name(test_sect.instance(d.post)) if d.post != "" and not test_sect.instance(d.post).is_empty() else d.get_status_text()), WuxiaTheme.PAPER_DIM],
		["อารมณ์ %d · เครียด %d%%" % [int(d.mood), int(d.stress)], Color(1, 0.45, 0.4) if d.stress >= StressSystem.WARN_AT else WuxiaTheme.PAPER_DIM],
	]:
		var l = UIKit.label(t[0], 11, t[1])
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		l.clip_text = true
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(l)
	if not d.is_founder:
		var heart = Button.new()
		heart.text = "♥" if d.favorite else "♡"
		heart.tooltip_text = "เลิกปักหมุด" if d.favorite else "ปักหมุดไว้ที่แผงขวา"
		heart.add_theme_font_size_override("font_size", 18)
		heart.add_theme_color_override("font_color", Color(1, 0.4, 0.5) if d.favorite else Color(0.8, 0.75, 0.7))
		heart.flat = true
		heart.position = Vector2(170, 2)
		heart.pressed.connect(func():
			d.favorite = not d.favorite
			_list_dirty = true
			_refresh_window())
		card.add_child(heart)
	return card

func _on_sect_changed() -> void:
	_list_dirty = true
	_window_dirty = true
	%SectView.refresh()

func _on_action_result(ok: bool, message: String) -> void:
	if not ok: UIKit.toast(%UIRoot, message, Color(1, 0.55, 0.45))

func _on_disciple_clicked(d: DiscipleData) -> void:
	GlobalGame.save_game()
	GlobalGame.selected_disciple = d
	get_tree().change_scene_to_file("res://scene/profile/disciple_profile.tscn")

func _on_building_clicked(uid: String) -> void:
	var inst = test_sect.instance(uid)
	if inst.is_empty(): return
	var built = int(inst.level) > 0
	match inst.type:
		"scripture_pavilion" when built: _open_window("หอตำรา", _build_library_window)
		"alchemy_lab" when built: _open_window("หอหลอมโอสถ", _build_alchemy_window)
		"forging_pavilion" when built: _open_window("โรงหลอมศาสตรา", _build_forge_window)
		_: _open_building_detail(uid)

func _on_btn_hunt_pressed() -> void:
	GlobalGame.save_game()
	get_tree().change_scene_to_file("res://scene/map/world_map.tscn")

func _on_sect_event_logged(event: Dictionary) -> void:
	_add_log_entry("[color=yellow][วันที่ %d][/color] %s" % [event.day, event.text])
	_list_dirty = true

func _add_log_entry(msg: String) -> void:
	%EventLog.append_text(msg + "\n")

func _log(msg: String) -> void:
	sect_manager.log_event(msg)

func _on_game_over() -> void:
	GlobalGame.clock_enabled = false
	var w = UIKit.open_window(%UIRoot, "สำนักล่มสลาย", Vector2(520, 260))
	var founder = test_sect.get_founder()
	test_sect.pending_ending = ""
	w.content.add_child(UIKit.label(EndingSys.ending_text(test_sect, "collapse"), 16))
	for l in EndingSys.summary(test_sect): w.content.add_child(UIKit.label(l, 13, WuxiaTheme.PAPER_DIM))
	if founder: w.content.add_child(UIKit.label("เจ้าสำนัก: %s (%s)" % [founder.get_display_name(), founder.death_cause], 15, WuxiaTheme.PAPER_DIM))
	w.content.add_child(UIKit.button("กลับหน้าหลัก", func(): get_tree().change_scene_to_file("res://scene/main_menu.tscn")))

# ── กล้อง ──

func _unhandled_input(event: InputEvent) -> void:
	var cam: Camera2D = %Camera
	if _walk3d != null:
		# โหมดเดิน 3D รับอินพุตเดิน/คลิก/E เอง ที่นี่รับแค่หยุดเวลาและสลับโหมด
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_SPACE: _toggle_pause()
			elif event.keycode == KEY_TAB: _toggle_walk()
			elif event.keycode == KEY_N: _skip_night()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		_toggle_pause()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
		_toggle_walk()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_N:
		_skip_night()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE and %SectView.mode != "":
		%SectView.cancel_action()
	elif %SectView.mode != "" and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		%SectView.cancel_action()
	elif %SectView.avatar != null and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		%SectView.avatar.walk_to(%SectView.get_global_mouse_position())
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			cam.zoom = (cam.zoom * 1.1).clamp(Vector2(0.5, 0.5), Vector2(2.5, 2.5))
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			cam.zoom = (cam.zoom / 1.1).clamp(Vector2(0.5, 0.5), Vector2(2.5, 2.5))
		elif event.button_index == MOUSE_BUTTON_LEFT and %SectView.mode == "orders" and %SectView.avatar == null:
			if event.pressed: %SectView.order_press(%SectView.get_global_mouse_position())
			else: %SectView.order_release(%SectView.get_global_mouse_position())
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_dragging = true
				_drag_moved = 0.0
			else:
				_dragging = false
				if _drag_moved < 6.0 and %SectView.avatar == null:
					if %SectView.mode != "": %SectView.layout_click(%SectView.get_global_mouse_position())
					else: %SectView.pick(%SectView.get_global_mouse_position())
	elif event is InputEventMouseMotion and %SectView.mode == "orders" and %SectView.avatar == null:
		%SectView._overlay.queue_redraw()
		if event.button_mask & MOUSE_BUTTON_MASK_MIDDLE: cam.position -= event.relative / cam.zoom
	elif event is InputEventMouseMotion and _dragging and %SectView.avatar == null:
		cam.position -= event.relative / cam.zoom
		_drag_moved += event.relative.length()

# ══════════════════════════════════════════
# หน้าต่างป๊อปอัป
# ══════════════════════════════════════════

func _open_window(title: String, builder: Callable, size := Vector2(780, 520)) -> void:
	if not _window.is_empty() and is_instance_valid(_window.root):
		_window.root.queue_free()
	_window = UIKit.open_window(%UIRoot, title, size)
	_window_builder = builder
	builder.call(_window.content)

## หน้าต่างรวมหมวดแบบแท็บ: tabs = [[ชื่อแท็บ, ฟังก์ชันสร้างเนื้อหา(c)], ...] จำแท็บล่าสุดของแต่ละหมวด
var _hub_tab := {}

func _open_hub(id: String, title: String, tabs: Array, size: Vector2, start := -1) -> void:
	if start >= 0: _hub_tab[id] = start
	_open_window(title, func(c): _build_hub(c, id, tabs), size)

func _build_hub(c: VBoxContainer, id: String, tabs: Array) -> void:
	var cur = clampi(int(_hub_tab.get(id, 0)), 0, tabs.size() - 1)
	if tabs.size() > 1:
		var bar = HFlowContainer.new()
		for i in tabs.size():
			bar.add_child(UIKit.button(tabs[i][0], func():
				_hub_tab[id] = i
				_refresh_window(), i == cur))
		c.add_child(bar)
		c.add_child(HSeparator.new())
	tabs[cur][1].call(c)

## เปิดหมวด "ตึกและงาน"/"ศิษย์" ที่แท็บที่ต้องการ (-1 = แท็บล่าสุด) ใช้เป็นทางลัดจากหน้าภาพรวมด้วย
func _goto_hub(id: String, tab: int) -> void:
	var big = Vector2(920, 640)
	match id:
		"work": _open_hub("work", "ตึกและงาน", [["สร้าง / ย้ายตึก", _build_build_window], ["รายการตึก", _build_structures_window], ["มอบหมายศิษย์", _build_assign_window], ["สั่งงานบนแผนที่", _build_orders_window]], big, tab)
		"people": _open_hub("people", "ศิษย์", [["ทำเนียบศิษย์", _build_roster_window], ["ประตูสำนัก (ผู้สมัคร)", _build_applicant_window], ["นักโทษ", func(c): SimWindows.prisoners(c, test_sect, sect_manager, _refresh_window)]], big, tab)

## หน้า "ภาพรวมสำนัก": สถานะที่ต้องรู้ + แจ้งเตือนสิ่งที่ติดขัด + ปุ่มลัด
func _build_overview_window(c: VBoxContainer) -> void:
	var pawns = PawnSys.present(test_sect)
	var n = maxi(1, pawns.size())
	var able = ProductionSys.able(test_sect)
	var free = able.filter(func(d): return d.post == "")
	var food_days = (test_sect.food / 8.0 + test_sect.meals) / n
	var beds = BuildingDB.get_beds(test_sect)
	var hurt = pawns.filter(func(d): return d.status == DiscipleData.DiscipleStatus.INJURED).size()
	var stressed = pawns.filter(func(d): return d.stress >= StressSystem.WARN_AT).size()
	c.add_child(UIKit.label("วันที่ %d · เงิน %d · เสบียง %d (สำรับ %d) · ไม้ %d · หิน %d" % [test_sect.current_day, test_sect.money, test_sect.food, test_sect.meals, test_sect.get_material_count("wood"), test_sect.get_material_count("stone")], 15, WuxiaTheme.BRONZE))
	c.add_child(UIKit.label("เสบียงพอกิน ~%.1f วัน · ศิษย์ %d/%d คน (ว่าง %d · บาดเจ็บ %d · เครียดหนัก %d) · ที่นอน %d/%d" % [food_days, pawns.size(), test_sect.get_max_disciples(), free.size(), hurt, stressed, mini(beds, pawns.size()), pawns.size()], 15, WuxiaTheme.PAPER))
	c.add_child(UIKit.label("คิวคำสั่งงาน: ตัดไม้ %d · ทุบหิน %d · ล่าสัตว์ %d · ไซต์ก่อสร้างค้าง %d" % [OrderSys.count(test_sect, "chop"), OrderSys.count(test_sect, "mine"), OrderSys.count(test_sect, "hunt"), test_sect.construction_sites().size()], 14, WuxiaTheme.PAPER_DIM))
	c.add_child(HSeparator.new())
	var alerts: Array = []
	if food_days < 3.0: alerts.append(["เสบียงเหลือไม่ถึง 3 วัน! สร้างแปลงเกษตรหรือมอบหมายคนเพิ่ม", Color(1, 0.4, 0.35)])
	elif food_days < 6.0: alerts.append(["เสบียงเริ่มน้อย (~%.1f วัน)" % food_days, Color(1, 0.75, 0.4)])
	if test_sect.money < 0: alerts.append(["คลังเงินติดลบ ศิษย์เริ่มเสียศรัทธา", Color(1, 0.4, 0.35)])
	elif test_sect.money < 200: alerts.append(["เงินเหลือน้อย (%d)" % test_sect.money, Color(1, 0.75, 0.4)])
	if beds < pawns.size(): alerts.append(["ที่นอนไม่พอ %d คนต้องนอนกลางแจ้ง (สร้างเรือนนอน)" % (pawns.size() - beds), Color(1, 0.75, 0.4)])
	if stressed > 0: alerts.append(["ศิษย์เครียดหนัก %d คน เสี่ยงธาตุไฟแตกซ่าน" % stressed, Color(1, 0.55, 0.4)])
	if test_sect.applicants.size() > 0: alerts.append(["มีผู้สมัครรอที่ประตู %d คน" % test_sect.applicants.size(), Color(0.7, 1, 0.7)])
	var empty_names: Array[String] = []
	for inst in test_sect.structures:
		if not BuildingDB.POSTS.has(inst.type) or int(inst.level) <= 0: continue
		var st = ProductionSys.status_text(test_sect, inst)
		if st.begins_with("⚠ ไม่มีศิษย์ประจำ"): empty_names.append(BuildingDB.inst_name(inst))
		elif st.begins_with("⚠"): alerts.append(["%s: %s" % [BuildingDB.inst_name(inst), st.trim_prefix("⚠ ")], Color(1, 0.8, 0.45)])
	if not empty_names.is_empty():
		alerts.append(["ตึกที่ยังไม่มีศิษย์ประจำ %d หลัง: %s%s" % [empty_names.size(), ", ".join(empty_names.slice(0, 4)), " …" if empty_names.size() > 4 else ""], Color(1, 0.8, 0.45)])
	if not test_sect.orders.is_empty() and free.is_empty() and not test_sect.order_draft: alerts.append(["มีคำสั่งงานค้างแต่ไม่มีศิษย์ว่าง (ถอดคนออกจากตึก หรือเปิดตัวเลือกเกณฑ์ศิษย์ประจำตึกในหน้าสั่งงาน)", Color(1, 0.8, 0.45)])
	if not test_sect.construction_sites().is_empty() and ProductionSys.construction_points(test_sect) <= 0.0: alerts.append(["มีไซต์ก่อสร้างแต่ไม่มีแรงงาน (สร้างค่ายช่างหรือปล่อยศิษย์ว่าง)", Color(1, 0.8, 0.45)])
	if alerts.is_empty(): c.add_child(UIKit.label("✔ ตอนนี้ทุกอย่างราบรื่น", 15, Color(0.7, 1, 0.7)))
	else:
		c.add_child(UIKit.section("ต้องจัดการ (%d)" % alerts.size()))
		for al in alerts: c.add_child(UIKit.label("• " + al[0], 14, al[1]))
	c.add_child(HSeparator.new())
	c.add_child(UIKit.section("ทางลัด"))
	var row = HFlowContainer.new()
	row.add_child(UIKit.button("จัดศิษย์เข้าตึกอัตโนมัติ", func():
		var k = BuildingDB.auto_assign(test_sect)
		UIKit.toast(%UIRoot, "จัดศิษย์เข้าตึก %d คน" % k, Color(0.7, 1, 0.7) if k > 0 else Color(1, 0.8, 0.5))
		%SectView.refresh()
		_refresh_window()))
	row.add_child(UIKit.button("สร้างตึก", func(): _goto_hub("work", 0)))
	row.add_child(UIKit.button("มอบหมายศิษย์", func(): _goto_hub("work", 2)))
	row.add_child(UIKit.button("สั่งงานบนแผนที่", func(): _goto_hub("work", 3)))
	row.add_child(UIKit.button("ผู้สมัครที่ประตู", func(): _goto_hub("people", 1)))
	c.add_child(row)

func _close_window() -> void:
	if not _window.is_empty() and is_instance_valid(_window.root):
		_window.root.queue_free()
	_window = {}

## สร้างเนื้อหาหน้าต่างใหม่หลังข้อมูลเปลี่ยน
func _refresh_window() -> void:
	if _window.is_empty() or not is_instance_valid(_window.root): return
	UIKit.clear(_window.content)
	_window_builder.call(_window.content)

## เปิดมินิเกม: หยุดเวลาไว้ระหว่างเล่น
func _open_minigame(game: Control) -> void:
	var was_paused = GlobalGame.paused
	GlobalGame.paused = true
	game.tree_exited.connect(func(): GlobalGame.paused = was_paused)
	%UIRoot.add_child(game)

## ศิษย์ที่อยู่ในสำนักและว่าง เรียงตามค่าสเตตัสที่ระบุ (มากไปน้อย)
func _available_disciples(sort_stat: String = "") -> Array[DiscipleData]:
	var result: Array[DiscipleData] = []
	for d in test_sect.disciples:
		if d.is_available(): result.append(d)
	if sort_stat != "":
		result.sort_custom(func(a, b): return a.get_stat(sort_stat) > b.get_stat(sort_stat))
	return result

func _cost_text(money: int, mats: Dictionary) -> String:
	var parts: Array[String] = []
	if money > 0: parts.append("เงิน %d" % money)
	if not mats.is_empty(): parts.append(MaterialDB.format_list(mats))
	return ", ".join(parts)

func _can_afford(money: int, mats: Dictionary) -> bool:
	return test_sect.money >= money and test_sect.has_materials(mats)

func _pay(money: int, mats: Dictionary) -> void:
	test_sect.money -= money
	test_sect.consume_materials(mats)

# ── สิ่งปลูกสร้าง (ก่อสร้างด้วยแรงงานศิษย์) ──

## เมนู "สร้างตึก": เลือกชนิดแล้วไปวางบนพื้นที่โล่งได้เลย กี่หลังก็ได้ (ตึกหลักมีได้หลังเดียว)
func _build_build_window(c: VBoxContainer) -> void:
	c.add_child(UIKit.label("เงิน %d | ไม้ %d | หิน %d  ·  เลือกตึกแล้วคลิกวางบนพื้นที่โล่ง (ช่องหญ้า/ดิน) ศิษย์ว่างและค่ายช่างจะช่วยกันก่อสร้างทุกวัน · ถางป่าด้วย ค่ายตัดไม้" % [test_sect.money, test_sect.get_material_count("wood"), test_sect.get_material_count("stone")], 14, WuxiaTheme.BRONZE))
	var top = HBoxContainer.new()
	top.add_child(UIKit.button("ย้ายตึกที่มีอยู่", func():
		_close_window()
		%SectView.begin_move()
		UIKit.toast(%UIRoot, "โหมดย้ายตึก: คลิกตึกเพื่อยก → คลิกที่ว่างเพื่อวาง (ตึกที่สร้างเสร็จเสียค่าย้าย) · คลิกขวา/Esc ออก", Color(1, 0.9, 0.5))))
	top.add_child(UIKit.button("ออกจากโหมดวางผัง", func():
		%SectView.end_mode()
		GlobalGame.save_game()))
	c.add_child(top)
	for type in BuildingDB.BUILDINGS:
		var b = BuildingDB.BUILDINGS[type]
		var cost = BuildingDB.get_upgrade_cost(type, 0)
		var count = test_sect.instances(type).size()
		var unique_blocked = b.get("unique", false) and count > 0
		c.add_child(HSeparator.new())
		c.add_child(UIKit.label("%s  (%dx%d ช่อง · มีแล้ว %d หลัง)" % [b.name, b.size.x, b.size.y, count], 18, WuxiaTheme.PAPER))
		c.add_child(UIKit.label(b.desc, 12, WuxiaTheme.PAPER_DIM))
		if b.has("need_terrain"): c.add_child(UIKit.label("เงื่อนไข: ต้องวางติดช่อง%s" % Territory.NAMES[b.need_terrain], 12, Color(1, 0.8, 0.4)))
		c.add_child(UIKit.row("วัสดุ: %s | แรงงาน %d แต้ม" % [_cost_text(cost.money, cost.materials), int(BuildingDB.get_work_required(0))], [
			UIKit.button("มีได้หลังเดียว" if unique_blocked else "วางตึก", func():
				_close_window()
				%SectView.begin_build(type)
				UIKit.toast(%UIRoot, "วาง%s: เงาเขียว = วางได้ · คลิกวาง (วางต่อได้) · คลิกขวา/Esc ออก" % b.name, Color(0.7, 1, 0.7)), unique_blocked or not _can_afford(cost.money, cost.materials))
		]))

## เมนู "สั่งงานบนแผนที่": เลือกเครื่องมือแล้วลากกรอบบนฉาก (ตัดต้นไม้ ทุบหิน ล่าสัตว์ ได้ทุกที่ ไม่ต้องมีตึก)
func _build_orders_window(c: VBoxContainer) -> void:
	var free = OrderSys.free_workers(test_sect).size()
	c.add_child(UIKit.label("แรงงานว่างตอนนี้ %d คน (ศิษย์ที่ไม่ได้ประจำตึก) · คิวคำสั่ง: ตัดไม้ %d · ทุบหิน %d · ล่าสัตว์ %d" % [free, OrderSys.count(test_sect, "chop"), OrderSys.count(test_sect, "mine"), OrderSys.count(test_sect, "hunt")], 14, WuxiaTheme.BRONZE))
	c.add_child(UIKit.label("ลากเมาส์ซ้ายเป็นกรอบบนแผนที่ (คลิกเดียวก็ได้) · ลากกล้องด้วยเมาส์กลาง · คลิกขวา/Esc ออกจากโหมด · ล่าสัตว์ใช้ได้ทั้งสัตว์ป่าและสัตว์เลี้ยง (วัว หมู ไก่ หมาป่า) ได้เนื้อ+หนัง · หมาป่าสู้กลับและมีค่าหัว", 12, WuxiaTheme.PAPER_DIM))
	var draft = CheckBox.new()
	draft.text = "เกณฑ์ศิษย์ที่ประจำตึกมาช่วยเมื่อศิษย์ว่างไม่พอ (ตึกนั้นจะไม่ผลิตในวันที่ถูกเกณฑ์)"
	draft.button_pressed = test_sect.order_draft
	draft.toggled.connect(func(on): test_sect.order_draft = on)
	c.add_child(draft)
	var tools = [
		["chop", "ตัดต้นไม้ (ได้ไม้ %d/ต้น และถางที่ให้ปลูกสร้าง)" % OrderSys.WOOD_PER_TREE],
		["mine", "ทุบก้อนหิน (ได้หิน %d/ก้อน)" % OrderSys.STONE_PER_ROCK],
		["hunt", "ล่า/เชือดสัตว์ (วัว หมู ไก่ หมาป่า)"],
		["tame", "จับสัตว์ป่ามาเลี้ยง (วัว หมู ไก่ — ป้อนอาหาร/ฝึกให้เชื่อง)"],
		["cancel", "ยกเลิกคำสั่งในกรอบ"],
	]
	for t in tools:
		c.add_child(UIKit.button(t[1], func():
			_close_window()
			%SectView.begin_orders(t[0])
			UIKit.toast(%UIRoot, "โหมดสั่งงาน: ลากกรอบบนแผนที่ · คลิกขวา/Esc ออก", Color(0.75, 1, 0.6))))
	c.add_child(UIKit.button("ยกเลิกคำสั่งทั้งหมด", func():
		test_sect.orders = []
		%SectView.refresh()
		_refresh_window()))

## เมนู "สิ่งปลูกสร้าง": รายการตึกทุกหลังในสำนัก
func _build_structures_window(c: VBoxContainer) -> void:
	var pts = ProductionSys.construction_points(test_sect)
	c.add_child(UIKit.label("เงิน %d | ไม้ %d | หิน %d | ศิษย์ %d/%d   ·   แรงงานก่อสร้าง %.0f แต้ม/วัน" % [test_sect.money, test_sect.get_material_count("wood"), test_sect.get_material_count("stone"), test_sect.get_active_disciples().size(), test_sect.get_max_disciples(), pts], 14, WuxiaTheme.BRONZE))
	if test_sect.structures.is_empty():
		c.add_child(UIKit.label("ยังไม่มีตึก — เปิดเมนู 'สร้างตึก / วางผัง'", 15, WuxiaTheme.PAPER_DIM))
	for type in BuildingDB.BUILDINGS:
		for inst in test_sect.instances(type):
			var lv = int(inst.level)
			var line = BuildingDB.inst_name(inst) + (" Lv.%d" % lv if lv > 0 else "")
			if not inst.site.is_empty(): line += "  — กำลังก่อสร้าง %d%%" % int(inst.site.work / inst.site.required * 100)
			elif BuildingDB.POSTS.has(type): line += "  — ศิษย์ %d/%d" % [BuildingDB.post_members(test_sect, inst.uid).size(), BuildingDB.post_slots(test_sect, inst.uid)]
			c.add_child(UIKit.row(line, [
				UIKit.button("รายละเอียด", func(): _open_building_detail(inst.uid)),
				UIKit.button("ไปที่ตึก", func():
					%Camera.position = SectView.center_of(inst)
					_close_window()),
			]))

var _detail_uid := ""

func _open_building_detail(uid: String) -> void:
	_detail_uid = uid
	_open_window(BuildingDB.inst_name(test_sect.instance(uid)), _build_detail_window, Vector2(760, 600))

## รายละเอียดตึก 1 หลัง: อัปเกรด/ก่อสร้าง ศิษย์ที่ประจำ ย้าย รื้อ
func _build_detail_window(c: VBoxContainer) -> void:
	var inst = test_sect.instance(_detail_uid)
	if inst.is_empty():
		c.add_child(UIKit.label("ไม่พบตึกนี้แล้ว", 16))
		return
	var b = BuildingDB.BUILDINGS[inst.type]
	var lv = int(inst.level)
	c.add_child(UIKit.label("%s  ระดับ %d / %d" % [BuildingDB.inst_name(inst), lv, b.max_level] if lv > 0 else "%s  (ยังสร้างไม่เสร็จ)" % BuildingDB.inst_name(inst), 20, WuxiaTheme.PAPER))
	c.add_child(UIKit.label(b.desc, 13, WuxiaTheme.PAPER_DIM))
	c.add_child(UIKit.label(_building_effect_text(inst.type, lv), 14, Color(0.6, 0.9, 0.6)))
	var st = ProductionSys.status_text(test_sect, inst)
	if st != "": c.add_child(UIKit.label("สถานะ: " + st, 14, Color(1, 0.8, 0.4) if st.begins_with("⚠") else Color(0.7, 1, 0.7)))
	c.add_child(UIKit.label("เงิน %d | ไม้ %d | หิน %d" % [test_sect.money, test_sect.get_material_count("wood"), test_sect.get_material_count("stone")], 13, WuxiaTheme.BRONZE))
	if not inst.site.is_empty():
		var crew_n = ProductionSys.able(test_sect).filter(func(d): return ProductionSys.is_building(test_sect, d)).size()
		c.add_child(UIKit.label("ศิษย์ที่กำลังช่วยสร้าง %d คน (ศิษย์ว่าง + ช่างค่ายช่าง) — ถ้าไม่มีใครว่าง ไซต์จะไม่คืบหน้า" % crew_n, 13, WuxiaTheme.PAPER_DIM))
		c.add_child(UIKit.label("กำลังก่อสร้าง... %d / %d แต้มแรงงาน (วันละ ~%.0f แต้ม แบ่งตามไซต์)" % [int(inst.site.work), int(inst.site.required), ProductionSys.construction_points(test_sect)], 15, Color(0.95, 0.75, 0.3)))
	elif lv < b.max_level:
		var cost = BuildingDB.get_upgrade_cost(inst.type, lv)
		c.add_child(UIKit.row("อัปเกรดเป็นระดับ %d — วัสดุ: %s | แรงงาน %d แต้ม" % [lv + 1, _cost_text(cost.money, cost.materials), int(BuildingDB.get_work_required(lv))], [
			UIKit.button("อัปเกรด", func(): GlobalGame.controller.request_upgrade_building.emit(inst.uid), not _can_afford(cost.money, cost.materials))
		]))
	# ศิษย์ที่ประจำ
	if BuildingDB.POSTS.has(inst.type) and lv > 0:
		var slots = BuildingDB.post_slots(test_sect, inst.uid)
		var members = BuildingDB.post_members(test_sect, inst.uid)
		c.add_child(UIKit.section("ศิษย์ที่ประจำ (%d/%d) — %s" % [members.size(), slots, BuildingDB.POSTS[inst.type].out]))
		for d in members:
			c.add_child(UIKit.row("%s · เครียด %d%%%s" % [d.disciple_name, int(d.stress), (" · ฝึก" + MasterySys.type_name(MasterySys.train_type(d))) if inst.type == "training_ground" else ""], [
				UIKit.button("ถอดถอน", func():
					BuildingDB.assign_post(test_sect, d, "")
					_refresh_window()
					%SectView.refresh())]))
		if members.size() < slots:
			var free = test_sect.get_active_disciples().filter(func(d): return d.post == "" and d.is_available() and not d.is_child)
			var skill: String = BuildingDB.POSTS[inst.type].skill
			free.sort_custom(func(a, b2): return BuildingDB._aptitude(a, inst.type, skill) > BuildingDB._aptitude(b2, inst.type, skill))
			c.add_child(UIKit.label("ศิษย์ว่าง (เรียงตามความเหมาะสม):", 13, WuxiaTheme.PAPER_DIM))
			for d in free.slice(0, 8):
				var f = SimWindows.post_fit(d, inst.type)
				c.add_child(UIKit.row("%s · ทักษะ %.0f · เครียด %d%%" % [d.disciple_name, PawnSys.skill_lv(d, skill) if skill != "" else 0.0, int(d.stress)], [
					UIKit.button("ประจำที่นี่", func():
						var err = BuildingDB.assign_post(test_sect, d, inst.uid)
						if err != "": UIKit.toast(%UIRoot, err, Color(1, 0.55, 0.45))
						_refresh_window()
						%SectView.refresh())], MasterySys.fit_color(f) if inst.type == "training_ground" else null))
	if inst.type == "dormitory" and lv > 0:
		var beds = lv * 4
		c.add_child(UIKit.section("ระบบฟื้นฟูเรือนนอน (%d เตียง)" % beds))
		c.add_child(UIKit.label("เรือนนอนเป็นสถานที่พักผ่อนฟื้นฟูร่างกาย ไม่ใช่งานประจำ · กดสั่งศิษย์เข้านอนพักผ่อนเพื่อฟื้นฟู Rest เต็ม 100% และลดความเครียดทันที", 13, WuxiaTheme.PAPER_DIM))
		var pawns = test_sect.get_active_disciples().filter(func(d): return d.is_available() and not d.is_child)
		pawns.sort_custom(func(a, b2):
			if (a.stress >= 70 or a.needs.get("rest", 1.0) < 0.3) != (b2.stress >= 70 or b2.needs.get("rest", 1.0) < 0.3):
				return a.stress >= 70 or a.needs.get("rest", 1.0) < 0.3
			return a.stress > b2.stress)
		for d in pawns:
			var rest_pct = int(d.needs.get("rest", 1.0) * 100)
			var stress_pct = int(d.stress)
			var line = "%s · พักผ่อน %d%% · เครียด %d%%" % [d.disciple_name, rest_pct, stress_pct]
			c.add_child(UIKit.row(line, [
				UIKit.button("สั่งนอนพัก", func():
					var msg = BuildingDB.sleep_disciple(test_sect, d)
					sect_manager.log_event(msg)
					UIKit.toast(%UIRoot, msg, Color(0.6, 1.0, 0.6))
					_refresh_window()
					%SectView.refresh())
			], Color(1, 0.55, 0.45) if stress_pct >= 70 or rest_pct < 30 else null))
	if inst.type == "main_hall":
		c.add_child(UIKit.row("เหมืองลึก: %s (ได้แร่เหล็ก/เหล็กเย็น/ผลึกวิญญาณ แต่สั่นสะเทือนปลุกสัตว์อสูรใต้ดิน · ความสั่น %.2f)" % ["เปิด" if test_sect.deep_mining else "ปิด", test_sect.tremor], [
			UIKit.button("ปิดเหมืองลึก" if test_sect.deep_mining else "เปิดเหมืองลึก", func():
				test_sect.deep_mining = not test_sect.deep_mining
				_refresh_window())]))
		var active = test_sect.get_active_disciples().size()
		var recruit_cost = GlobalGame.controller.recruit_cost()
		var full = active >= test_sect.get_max_disciples()
		c.add_child(UIKit.row("ประกาศรับสมัครศิษย์ (%d/%d) ค่าใช้จ่าย เงิน %d" % [active, test_sect.get_max_disciples(), recruit_cost], [
			UIKit.button("ประกาศรับสมัคร" if not full else "ศิษย์เต็มแล้ว", func(): GlobalGame.controller.request_recruit.emit(), full or test_sect.money < recruit_cost)
		]))
	# ย้าย / รื้อ
	c.add_child(HSeparator.new())
	var row = HBoxContainer.new()
	if inst.site.is_empty():
		row.add_child(UIKit.button("ย้ายตึก (%s)" % ("ฟรี" if BuildingDB.move_cost(inst) == 0 else str(BuildingDB.move_cost(inst))), func():
			_close_window()
			%SectView.begin_move()
			%SectView.carry = inst.uid
			UIKit.toast(%UIRoot, "ยก%sแล้ว — คลิกที่ว่างเพื่อวาง · คลิกขวา/Esc ยกเลิก" % BuildingDB.inst_name(inst), Color(1, 0.9, 0.5))))
	if inst.type != "main_hall":
		row.add_child(UIKit.button("รื้อ (คืนวัสดุครึ่งหนึ่ง)", func():
			var err = BuildingDB.demolish(test_sect, inst.uid)
			if err != "": UIKit.toast(%UIRoot, err, Color(1, 0.55, 0.45))
			else:
				sect_manager.log_event("รื้อ%s" % BuildingDB.inst_name(inst))
				test_sect.terrain_dirty = true
				%SectView.refresh()
				_close_window()
				update_ui()))
	c.add_child(row)

func _building_effect_text(type: String, lv: int) -> String:
	match type:
		"main_hall": return "ศิษย์สูงสุด %d คน | อาณาเขต %d ลี้ | รายได้ +%d/วัน" % [BuildingDB.get_max_disciples(lv), BuildingDB.get_territory_size(lv), BuildingDB.get_territory_income(lv)]
		"dormitory": return "ที่นอน %d เตียง (ฟื้นฟู Rest เต็ม 100%% และลดความเครียดเมื่อสั่งนอนพัก หรือนอนหลับประจำวัน)" % (lv * 4)
		"training_ground": return "ศิษย์ที่ประจำได้ EXP ~%d/วัน/คน (คูณความเหมาะสมพรสวรรค์)" % int(40 * (1.0 + (lv - 1) * 0.15)) if lv > 0 else ""
		"scripture_pavilion": return "ถอดรหัสคัมภีร์ได้ถึงขั้น%s" % SkillDB.TIER_NAMES[clampi(lv, 1, 5)] if lv > 0 else "ยังถอดรหัสคัมภีร์ไม่ได้"
		"alchemy_lab": return "ปลดล็อกสูตรยาระดับ %d | โซนไฟพอดีกว้าง %d%%" % [lv, int(BuildingDB.get_alchemy_zone_width(lv, 0) * 100)]
		"forging_pavilion": return "ปลดล็อกสูตรระดับ %d | โบนัสความหายาก +%d%%" % [lv, int(BuildingDB.get_forge_rarity_bonus(lv, 0) * 100)] if lv > 0 else "ต้องสร้างให้เสร็จก่อน"
		"infirmary": return "โอกาสรักษาของหมอ +%d%%" % (lv * 15) if lv > 0 else ""
		"sect_formation": return "พลังป้องกันสำนัก +%d" % (lv * 25 + lv * lv * 25) if lv > 0 else ""
		"farm": return "เสบียง ~%d/วัน ต่อ 1 ศิษย์ฝีมือกลาง" % int(40 * (1.0 + (lv - 1) * 0.2)) if lv > 0 else ""
		"lumber_camp": return "ไม้ ~%d/วัน · ถางป่ารอบค่ายรัศมี %d ช่อง" % [int(8 * (1.0 + (lv - 1) * 0.1)), 6 + lv] if lv > 0 else ""
		"quarry": return "หิน ~%d/วัน (เปิดเหมืองลึกได้แร่เพิ่ม)" % int(5 * (1.0 + (lv - 1) * 0.1)) if lv > 0 else ""
		"kitchen": return "ทำสำรับ ~%d/วัน" % int(12 * (1.0 + (lv - 1) * 0.15)) if lv > 0 else ""
		"campfire": return "รัศมีไฟระดับ %d — สัตว์เลี้ยงชอบ สัตว์ป่าเกรงกลัว" % lv if lv > 0 else ""
		"watchtower": return "พลังป้องกัน +%d และไล่สัตว์ร้ายในรัศมี" % (lv * 12) if lv > 0 else ""
		"builders_hut": return "แรงงานก่อสร้าง +%.0f แต้ม/วัน/คน" % (12.0 * (1.0 + (lv - 1) * 0.2)) if lv > 0 else ""
	return ""

# ── มอบหมาย / ผู้สมัคร ──

func _build_applicant_window(c: VBoxContainer) -> void:
	SimWindows.applicants(c, test_sect, sect_manager, func():
		_refresh_window()
		%SectView.refresh()
		update_ui())

func _build_assign_window(c: VBoxContainer) -> void:
	SimWindows.assign_board(c, test_sect, _refresh_window)

# ── เหตุการณ์จากเจตจำนงสวรรค์ (ศัตรูบุก / คนพเนจร) ──

var _event_window := {}
var _ending_window := {}

## หน้าจอจุดจบ: ชนะ = เล่นต่อ/กลับหน้าหลัก, แพ้ = กลับหน้าหลัก (ดู EndingSys)
func _open_ending() -> void:
	var id: String = test_sect.pending_ending
	var info = EndingDB.ENDINGS.get(id, {})
	if info.is_empty():
		test_sect.pending_ending = ""
		return
	GlobalGame.paused = true
	var lose = info.kind == "lose"
	_ending_window = UIKit.open_window(%UIRoot, "【จุดจบ】 " + info.name, Vector2(760, 520))
	var c: VBoxContainer = _ending_window.content
	c.add_child(UIKit.label(info.name, 28, Color(1, 0.5, 0.45) if lose else Color(1, 0.85, 0.4)))
	c.add_child(UIKit.label(EndingSys.ending_text(test_sect, id), 17))
	c.add_child(UIKit.section("สรุปเส้นทางของสำนัก"))
	for l in EndingSys.summary(test_sect): c.add_child(UIKit.label(l, 14, WuxiaTheme.PAPER_DIM))
	if not lose:
		c.add_child(UIKit.button("เล่นต่อ (ตำนานยังไม่จบ)", func():
			test_sect.pending_ending = ""
			_ending_window.root.queue_free()
			_ending_window = {}
			GlobalGame.paused = false))
	c.add_child(UIKit.button("บันทึกและกลับหน้าหลัก", func():
		test_sect.pending_ending = ""
		GlobalGame.save_game()
		get_tree().change_scene_to_file("res://scene/main_menu.tscn")))

## หน้าต่างเส้นทางสู่จุดจบ: ความคืบหน้าของแต่ละจุดจบ + คำใบ้
func _build_endings_window(c: VBoxContainer) -> void:
	c.add_child(UIKit.label("จุดจบที่พบแล้ว %d / %d (ได้แต้มเริ่มต้นเพิ่มในเซฟถัดไป) · จุดจบแบบชนะเล่นต่อได้" % [EndingSys.seen(test_sect).size(), EndingDB.ENDINGS.size()], 13, WuxiaTheme.PAPER_DIM))
	for id in EndingDB.ORDER:
		var info = EndingDB.ENDINGS[id]
		var done = id in EndingSys.seen(test_sect)
		c.add_child(UIKit.section("%s%s — %d%%" % [info.name, " ✓ พบแล้ว" if done else "", int(EndingSys.progress(test_sect, id) * 100)]))
		c.add_child(UIKit.label(info.hint, 13, WuxiaTheme.PAPER_DIM))
		for cond in EndingSys.conditions(test_sect, id):
			var ok = cond.cur >= cond.need
			c.add_child(UIKit.label("  %s %s: %d / %d" % ["✓" if ok else "·", cond.text, cond.cur, cond.need], 13, Color(0.6, 1, 0.6) if ok else WuxiaTheme.PAPER))

func _open_event() -> void:
	var ev = test_sect.pending_event
	GlobalGame.paused = true
	match ev.type:
		"raid":
			_event_window = UIKit.open_window(%UIRoot, "ศัตรูบุกสำนัก!", Vector2(720, 400))
			var c: VBoxContainer = _event_window.content
			var enemies = StorytellerSystem.raid_enemies(test_sect)
			var power = 0
			for e in enemies: power += StatSys.combat_power(e.attack, e.max_hp, e.speed, 0, 0)
			c.add_child(UIKit.label("%s บุกมา %d ตน (คะแนนภัย %d · พลังรวม ~%d)" % [ev.who, enemies.size(), ev.points, power], 18, Color(1, 0.5, 0.4)))
			c.add_child(UIKit.label(", ".join(enemies.map(func(e): return e.name)), 14))
			var fighters = StorytellerSystem.defenders(test_sect)
			c.add_child(UIKit.label("ผู้พร้อมรบในสำนัก: %s" % ", ".join(fighters.map(func(d): return "%s (%d)" % [d.disciple_name, d.get_power_rating()])), 14, WuxiaTheme.PAPER_DIM))
			c.add_child(UIKit.button("นำศิษย์ออกรบเอง (ฉากต่อสู้ 4 คนที่เก่งที่สุด)", func():
				_close_event()
				GlobalGame.combat_allies.assign(fighters.slice(0, 4))
				GlobalGame.combat_enemies.assign(enemies)
				GlobalGame.combat_context = { "type": "raid", "node": "sect", "faction": ev.get("faction", ""), "raid": ev }
				GlobalGame.combat_return_scene = "res://scene/test_sect.tscn"
				GlobalGame.combat_bonus_money = 0
				GlobalGame.combat_bonus_task = ""
				test_sect.pending_event = {}
				GlobalGame.save_game()
				get_tree().change_scene_to_file(GlobalGame.COMBAT_SCENE), fighters.is_empty()))
			c.add_child(UIKit.button("ให้ค่ายกลและศิษย์ตั้งรับอัตโนมัติ", func():
				_close_event()
				StorytellerSystem.auto_defend(test_sect, sect_manager)
				update_ui()))
		"peddler":
			_event_window = UIKit.open_window(%UIRoot, "พ่อค้าเร่ขายคัมภีร์", Vector2(640, 320))
			var c: VBoxContainer = _event_window.content
			var info = SkillDB.get_skill(ev.skill)
			c.add_child(UIKit.label("'คัมภีร์ %s ขั้น%s ของแท้แน่นอนขอรับ! ข้าได้มาจากสำนักเก่าที่ล่มสลาย'" % [ev.skill, SkillDB.TIER_NAMES[int(info.get("tier", 1))]], 16, Color(1, 0.9, 0.6)))
			c.add_child(UIKit.label("ราคา %d เงิน · คัมภีร์จากพ่อค้าเร่บางเล่มเป็นของปลอม (เสี่ยงราว 1 ใน 3)" % ev.price, 14, WuxiaTheme.PAPER_DIM))
			c.add_child(UIKit.button("ซื้อ (%d)" % ev.price, func():
				_close_event()
				UIKit.toast(%UIRoot, RegEx.create_from_string("\\[/?[a-z]+[^\\]]*\\]").sub(SkillQuestSys.buy_peddler(test_sect, sect_manager), "", true), Color(1, 0.9, 0.6))
				update_ui(), test_sect.money < int(ev.price)))
			c.add_child(UIKit.button("ไล่ไป", func():
				test_sect.pending_event = {}
				_close_event()))
		_:
			test_sect.pending_event = {}
			GlobalGame.paused = false

func _close_event() -> void:
	if not _event_window.is_empty() and is_instance_valid(_event_window.root): _event_window.root.queue_free()
	_event_window = {}
	GlobalGame.paused = false

# ── หอตำรา ──

func _build_library_window(c: VBoxContainer) -> void:
	var lv = test_sect.get_building_level("scripture_pavilion")
	c.add_child(UIKit.section("ถอดรหัสคัมภีร์ชำรุด (หอตำราระดับ %d, มีคัมภีร์ชำรุด %d ชิ้น)" % [lv, test_sect.get_material_count("scripture_fragment")]))
	c.add_child(UIKit.label("สำนักไม่ได้มีวิชาแต่กำเนิด! แย่งชิงคัมภีร์ชำรุดจากดันเจี้ยน สำนักศัตรู แดนลับ หรือโรงประมูล แล้วนำมาถอดรหัส", 13, WuxiaTheme.PAPER_DIM))
	if lv == 0:
		c.add_child(UIKit.label("ต้องสร้างหอตำราก่อน", 15, Color(1, 0.6, 0.5)))
	elif test_sect.research_skill != "":
		c.add_child(UIKit.label("กำลังถอดรหัสคัมภีร์... เหลืออีก %d วัน" % test_sect.research_days_left, 16, Color(0.5, 0.8, 1)))
	else:
		for tier in range(1, 6):
			var cost = BuildingDB.get_research_cost(tier)
			var locked = tier > lv
			var text = "ถอดรหัสวิชาขั้น%s  (เงิน %d, คัมภีร์ชำรุด %d, %d วัน)" % [SkillDB.TIER_NAMES[tier], cost.money, cost.fragments, cost.days]
			if locked: text += "  [ต้องการหอตำราระดับ %d]" % tier
			c.add_child(UIKit.row(text, [UIKit.button("เริ่ม", func(): GlobalGame.controller.request_research.emit(tier),
				locked or test_sect.money < cost.money or test_sect.get_material_count("scripture_fragment") < cost.fragments)], SkillDB.TIER_COLORS[tier]))

	_build_study_section(c)
	c.add_child(UIKit.section("คัมภีร์ในหอตำรา (%d วิชา) — กด \"มอบให้ศิษย์\" เพื่อเลือกคนศึกษา" % test_sect.library_skills.size()))
	c.add_child(UIKit.label("ศิษย์ประจำหอตำราศึกษาวันละ 2 ครั้ง · ศิษย์ว่างศึกษาเองได้วันละ 1 ครั้ง · มีคนในสำนักรู้วิชานั้นอยู่แล้ว = ช่วยสอน เร็วขึ้น x1.5 · วิชาขั้นสูงต้องชำนาญถึงเกณฑ์ก่อน", 13, WuxiaTheme.PAPER_DIM))
	var sorted_skills = test_sect.library_skills.duplicate()
	sorted_skills.sort_custom(func(a, b): return SkillDB.get_skill(a).get("tier", 1) < SkillDB.get_skill(b).get("tier", 1))
	for s in sorted_skills:
		var info = SkillDB.get_skill(s)
		if info.is_empty(): continue
		var req = MasterySys.required_level(s)
		var req_text = " [ต้องชำนาญ%s ระดับ %d]" % [MasterySys.type_name(MasterySys.skill_type(s)), req] if req > 0 else ""
		var knowers = test_sect.get_active_disciples().filter(func(d): return d.learned_skills.has(s)).size()
		c.add_child(UIKit.row("[%s] %s%s (%s, พลัง %d)%s - %s · รู้แล้ว %d คน" % [SkillDB.TIER_NAMES[info.tier], s, " ★วิชาประจำสำนัก" if info.get("custom", false) else "", SkillDB.TYPE_NAMES.get(info.type, info.type), info.power, req_text, info.desc, knowers], [
			UIKit.button("มอบให้ศิษย์", func():
				_study_pick = s
				_refresh_window())], SkillDB.TIER_COLORS[info.tier]))
		if _study_pick == s: _build_study_picker(c, s)

	c.add_child(UIKit.section("คิดค้นวิชาเฉพาะของสำนัก (หลอมรวมวิชา)"))
	_build_fusion(c)

## ── มอบหมายวิชาให้ศิษย์ศึกษา ──
var _study_pick := ""

## รายการศิษย์ที่กำลังศึกษา + แถบความคืบหน้า + ยกเลิก
func _build_study_section(c: VBoxContainer) -> void:
	var studying = test_sect.get_active_disciples().filter(func(d): return d.study_skill != "")
	c.add_child(UIKit.section("ศิษย์ที่กำลังศึกษาวิชา (%d คน)" % studying.size()))
	if studying.is_empty():
		c.add_child(UIKit.label("ยังไม่มีใครได้รับมอบหมาย — เลือกวิชาด้านล่างแล้วกด \"มอบให้ศิษย์\"", 13, WuxiaTheme.PAPER_DIM))
	for d in studying:
		var rate = SectManager.study_rate(test_sect, d, d.study_skill)
		var at_lib = BuildingDB.post_type(test_sect, d) == "scripture_pavilion"
		var per_day = rate * (2.0 if at_lib else (1.0 if d.post == "" else 0.0))
		var block = MasterySys.block_reason(d, d.study_skill)
		var note = ("ติดเกณฑ์: " + block) if block != "" else ("~%.0f วัน" % ceilf((100.0 - d.study_progress) / per_day) if per_day > 0 else "ไม่ได้ศึกษา (ประจำงานอื่นอยู่ — ย้ายมาหอตำราหรือปล่อยว่าง)")
		var bar = ProgressBar.new()
		bar.custom_minimum_size = Vector2(140, 14)
		bar.value = d.study_progress
		bar.show_percentage = true
		var row = UIKit.row("%s → %s · %s%s" % [d.disciple_name, d.study_skill, note, " · มีอาจารย์ช่วยสอน" if SectManager.has_study_teacher(test_sect, d, d.study_skill) else ""], [
			bar,
			UIKit.button("ยกเลิก", func():
				d.study_skill = ""
				d.study_progress = 0.0
				_refresh_window())])
		c.add_child(row)

## เลือกศิษย์ให้ศึกษาวิชา s: เรียงตามความเหมาะ บอกเหตุผลถ้าเรียนไม่ได้
func _build_study_picker(c: VBoxContainer, s: String) -> void:
	var box = VBoxContainer.new()
	c.add_child(box)
	box.add_child(UIKit.label("   เลือกศิษย์ที่จะศึกษา %s:" % s, 14, Color(1, 0.9, 0.55)))
	var cands = test_sect.get_active_disciples().filter(func(d): return not d.is_child and not d.learned_skills.has(s))
	cands.sort_custom(func(a, b): return MasterySys.fit_skill(a, s) > MasterySys.fit_skill(b, s))
	if cands.is_empty():
		box.add_child(UIKit.label("   ทุกคนรู้วิชานี้แล้ว", 13, WuxiaTheme.PAPER_DIM))
	for d in cands.slice(0, 12):
		var fit = MasterySys.fit_skill(d, s)
		var block = MasterySys.block_reason(d, s)
		var full = d.learned_skills.size() >= d.get_max_skills()
		var notes: Array[String] = ["ความเหมาะ x%.2f" % fit, "ความเข้าใจ %d" % d.get_stat("comprehension")]
		if block != "": notes.append("(ต้องฝึกความชำนาญเพิ่ม — ศึกษาไปจะค่อยๆ ขึ้น)")
		if full: notes.append("จำวิชาได้เต็มแล้ว %d/%d" % [d.learned_skills.size(), d.get_max_skills()])
		if d.study_skill != "": notes.append("กำลังศึกษา %s อยู่ (จะเปลี่ยน)" % d.study_skill)
		box.add_child(UIKit.row("   %s (%s) · %s" % [d.disciple_name, d.realm_name, " · ".join(notes)], [
			UIKit.button("เลือก", func():
				d.study_skill = s
				d.study_progress = 0.0
				# ย้ายเข้าประจำหอตำราถ้ายังว่างที่ (เรียนเร็วกว่า) ไม่งั้นศึกษาเองตอนว่าง
				if BuildingDB.post_type(test_sect, d) != "scripture_pavilion":
					for inst in test_sect.instances("scripture_pavilion"):
						if int(inst.level) > 0 and BuildingDB.assign_post(test_sect, d, inst.uid) == "": break
				_study_pick = ""
				UIKit.toast(%UIRoot, "%s เริ่มศึกษา %s%s" % [d.disciple_name, s, " (ประจำหอตำรา)" if BuildingDB.post_type(test_sect, d) == "scripture_pavilion" else " (หอตำราเต็ม — ศึกษาตอนว่าง)"], Color(0.6, 0.9, 1))
				_refresh_window(), full)], MasterySys.fit_color(fit)))
	box.add_child(UIKit.button("   ยกเลิกการเลือก", func():
		_study_pick = ""
		_refresh_window()))

## หลอมรวม 2-3 วิชาที่ศิษย์ขั้นแกนทองคำขึ้นไปรู้ เป็นวิชาใหม่ (ตั้งชื่อเอง) ส่งต่อให้รุ่นต่อไปได้
var _fusion_master: DiscipleData
var _fusion_picked: Array = []

func _build_fusion(c: VBoxContainer) -> void:
	var masters = test_sect.get_active_disciples().filter(func(d): return CultivationSys.get_realm_info(d.level).major_index >= 3 and d.learned_skills.size() >= 2)
	if masters.is_empty():
		c.add_child(UIKit.label("ต้องมีศิษย์ (หรือเจ้าสำนัก) ที่บรรลุขั้นแกนทองคำขึ้นไป และรู้วิชาอย่างน้อย 2 วิชา", 14, WuxiaTheme.PAPER_DIM))
		return
	if _fusion_master == null or not masters.has(_fusion_master):
		_fusion_master = masters[0]
		_fusion_picked.clear()
	var opt = OptionButton.new()
	for m in masters: opt.add_item(m.get_display_name())
	opt.select(masters.find(_fusion_master))
	opt.item_selected.connect(func(i):
		_fusion_master = masters[i]
		_fusion_picked.clear()
		_refresh_window())
	c.add_child(UIKit.row("ปรมาจารย์ผู้คิดค้น:", [opt]))
	var flow = HFlowContainer.new()
	for s in _fusion_master.learned_skills:
		var cb = CheckBox.new()
		cb.text = s
		cb.button_pressed = _fusion_picked.has(s)
		cb.toggled.connect(func(on):
			if on and _fusion_picked.size() < 3 and not _fusion_picked.has(s): _fusion_picked.append(s)
			elif not on: _fusion_picked.erase(s)
			_refresh_window())
		flow.add_child(cb)
	c.add_child(flow)
	if _fusion_picked.size() < 2:
		c.add_child(UIKit.label("เลือกวิชาที่จะหลอมรวม 2-3 วิชา", 14, WuxiaTheme.PAPER_DIM))
		return
	var preview = _fusion_preview(_fusion_picked)
	var cost = 1000 * preview.tier
	c.add_child(UIKit.label("ผลลัพธ์: วิชาขั้น%s สาย%s พลัง %d (ค่าใช้จ่าย เงิน %d)" % [SkillDB.TIER_NAMES[preview.tier], SkillDB.TYPE_NAMES.get(preview.type, preview.type), preview.power, cost], 15, SkillDB.TIER_COLORS[preview.tier]))
	var name_edit = LineEdit.new()
	name_edit.placeholder_text = "ตั้งชื่อวิชา เช่น เพลงกระบี่%s" % test_sect.sect_name.trim_prefix("สำนัก")
	name_edit.custom_minimum_size = Vector2(300, 0)
	c.add_child(UIKit.row("ชื่อวิชา:", [name_edit, UIKit.button("คิดค้นวิชา", func(): _create_custom_skill(name_edit.text.strip_edges(), preview, cost), test_sect.money < cost)]))

func _fusion_preview(skills: Array) -> Dictionary:
	var max_tier = 1
	var total = 0
	var strongest = skills[0]
	for s in skills:
		var info = SkillDB.get_skill(s)
		max_tier = max(max_tier, info.tier)
		total += info.power
		if info.power > SkillDB.get_skill(strongest).power: strongest = s
	var tier = min(5, max_tier + (1 if skills.size() >= 3 else 0))
	return { "tier": tier, "type": SkillDB.get_skill(strongest).type, "power": int(total * 0.7) + 20 * tier, "sources": skills.duplicate() }

func _create_custom_skill(skill_name: String, preview: Dictionary, cost: int) -> void:
	if skill_name == "" or SkillDB.get_skill(skill_name).size() > 0 or test_sect.money < cost:
		_log("ชื่อวิชาว่างหรือซ้ำกับวิชาที่มีอยู่แล้ว")
		return
	test_sect.money -= cost
	var info = { "tier": preview.tier, "type": preview.type, "power": preview.power,
		"desc": "วิชาเฉพาะของ%s คิดค้นโดย %s หลอมรวมจาก %s" % [test_sect.sect_name, _fusion_master.disciple_name, ", ".join(preview.sources)] }
	test_sect.custom_skills[skill_name] = info
	SkillDB.register_custom({ skill_name: info })
	ArchiveSys.add_legacy_skill(skill_name, info)
	test_sect.add_library_skill(skill_name)
	_fusion_master.learned_skills.append(skill_name)
	_fusion_master.add_fame(50)
	ArchiveSys.unlock_achievement("custom_skill")
	_log("[color=gold]%s หลอมรวมวิชาจนคิดค้น [b]%s[/b] (ขั้น%s) ได้สำเร็จ! วิชานี้จะถูกบันทึกไว้ในหอเกียรติยศเพื่อส่งต่อให้รุ่นต่อไป[/color]" % [_fusion_master.disciple_name, skill_name, SkillDB.TIER_NAMES[preview.tier]])
	VFX.breakthrough(%UIRoot, SkillDB.TIER_COLORS[preview.tier], preview.tier >= 4)
	_fusion_picked.clear()
	update_ui()

# ── หอหลอมโอสถ ──

func _build_alchemy_window(c: VBoxContainer) -> void:
	var lv = test_sect.get_building_level("alchemy_lab")
	if lv == 0:
		c.add_child(UIKit.label("ยังไม่ได้สร้างหอหลอมโอสถ", 18, Color(1, 0.6, 0.5)))
		return
	var alchemist = _available_disciples("alchemy")
	var stat = alchemist[0].get_stat("alchemy") if not alchemist.is_empty() else 0
	var zone = BuildingDB.get_alchemy_zone_width(lv, stat)
	var helper_text = "ผู้ช่วยหลอมยา: %s (ปรุงยา %d)" % [alchemist[0].disciple_name, stat] if not alchemist.is_empty() else "ไม่มีศิษย์ว่างมาช่วย (โซนไฟจะแคบลง)"
	c.add_child(UIKit.label("หอหลอมโอสถระดับ %d | %s | โซนไฟพอดี %d%%" % [lv, helper_text, int(zone * 100)], 15, WuxiaTheme.PAPER_DIM))

	c.add_child(UIKit.section("สูตรยา (มินิเกมคุมไฟ - เวลาจะหยุดระหว่างหลอม)"))
	for id in RecipeDB.PILLS:
		var r = RecipeDB.PILLS[id]
		var locked = r.lab_level > lv
		var text = "%s: %s\nวัตถุดิบ: %s" % [r.name, r.desc, _cost_text(r.money, r.materials)]
		if locked: text += "  [ต้องการหอหลอมโอสถระดับ %d]" % r.lab_level
		c.add_child(UIKit.row(text, [UIKit.button("หลอมยา", func(): _start_alchemy(id, zone), locked or not _can_afford(r.money, r.materials))]))

	c.add_child(UIKit.section("ยาในคลัง"))
	_add_pill_list(c)

func _add_pill_list(c: VBoxContainer) -> void:
	if test_sect.pills.is_empty():
		c.add_child(UIKit.label("ยังไม่มียาในคลัง", 14, WuxiaTheme.PAPER_DIM))
	for key in test_sect.pills:
		var parts = key.split(":")
		var q = int(parts[1])
		c.add_child(UIKit.label("%s [%s] x%d" % [RecipeDB.PILLS[parts[0]].name, RecipeDB.PILL_QUALITY_NAMES[q], test_sect.pills[key]], 15, RecipeDB.PILL_QUALITY_COLORS[q]))

func _start_alchemy(pill_id: String, zone: float) -> void:
	var r = RecipeDB.PILLS[pill_id]
	if not _can_afford(r.money, r.materials): return
	_pay(r.money, r.materials)
	var game = AlchemyMinigame.new()
	game.setup(r.name, zone)
	game.finished.connect(func(quality: int):
		if quality >= 0:
			test_sect.add_pill(pill_id, quality)
			_log("[color=magenta][หอหลอมโอสถ][/color] หลอมสำเร็จ! ได้รับ [b]%s [%s][/b]" % [r.name, RecipeDB.PILL_QUALITY_NAMES[quality]])
		else:
			_log("[color=magenta][หอหลอมโอสถ][/color] หลอม%sล้มเหลว... วัตถุดิบกลายเป็นเถ้าถ่าน" % r.name)
		update_ui())
	_open_minigame(game)
	update_ui()

# ── โรงหลอมศาสตรา ──

var _forge_catalyst: String = ""

func _build_forge_window(c: VBoxContainer) -> void:
	var lv = test_sect.get_building_level("forging_pavilion")
	if lv == 0:
		c.add_child(UIKit.label("ยังไม่ได้สร้างโรงหลอมศาสตรา\nไปที่ [สิ่งปลูกสร้าง] เพื่อสร้างก่อน", 18, Color(1, 0.6, 0.5)))
		return
	var smiths = _available_disciples("forging")
	var stat = smiths[0].get_stat("forging") if not smiths.is_empty() else 0
	var bonus = BuildingDB.get_forge_rarity_bonus(lv, stat)
	c.add_child(UIKit.label("โรงหลอมศาสตราระดับ %d | ช่างตีเหล็ก: %s | โบนัสความหายาก +%d%%" % [lv, ("%s (หลอมศาสตรา %d)" % [smiths[0].disciple_name, stat]) if not smiths.is_empty() else "ไม่มี", int(bonus * 100)], 15, WuxiaTheme.PAPER_DIM))

	c.add_child(UIKit.section("วัตถุดิบเสริม (เพิ่มโอกาสได้ของหายาก)"))
	var cat_row = HBoxContainer.new()
	cat_row.add_child(UIKit.button("ไม่ใส่" + (" ✓" if _forge_catalyst == "" else ""), func():
		_forge_catalyst = ""
		_refresh_window()))
	for cat in RecipeDB.FORGE_CATALYSTS:
		var have = test_sect.get_material_count(cat)
		cat_row.add_child(UIKit.button("%s (มี %d)%s" % [MaterialDB.get_material_name(cat), have, " ✓" if _forge_catalyst == cat else ""], func():
			_forge_catalyst = cat
			_refresh_window(), have <= 0))
	c.add_child(cat_row)

	c.add_child(UIKit.section("สูตรหลอม"))
	for id in RecipeDB.FORGE:
		var r = RecipeDB.FORGE[id]
		var locked = r.forge_level > lv
		var text = "%s - %s" % [r.name, _cost_text(r.money, r.materials)]
		if locked: text += "  [ต้องการโรงหลอมระดับ %d]" % r.forge_level
		c.add_child(UIKit.row(text, [UIKit.button("หลอม", func(): _forge(id, bonus), locked or not _can_afford(r.money, r.materials))]))

func _forge(recipe_id: String, bonus: float) -> void:
	var r = RecipeDB.FORGE[recipe_id]
	if not _can_afford(r.money, r.materials): return
	_pay(r.money, r.materials)
	if _forge_catalyst != "" and test_sect.get_material_count(_forge_catalyst) > 0:
		test_sect.add_material(_forge_catalyst, -1)
		bonus += RecipeDB.FORGE_CATALYSTS[_forge_catalyst]
		if test_sect.get_material_count(_forge_catalyst) <= 0:
			_forge_catalyst = ""
	var eq = EquipmentDB.generate(r.type, EquipmentDB.roll_rarity(bonus))
	test_sect.equipment_storage.append(eq)
	_log("[color=orange][โรงหลอมศาสตรา][/color] หลอมได้ [color=#%s]%s [%s][/color] (%s)" % [eq.get_rarity_color().to_html(false), eq.item_name, eq.get_rarity_name(), eq.get_stat_text().replace("\n", " ")])
	VFX.burst(%UIRoot, %UIRoot.size / 2.0, eq.get_rarity_color(), 30 + int(eq.rarity) * 20)
	if eq.rarity >= EquipmentData.Rarity.EPIC:
		VFX.screen_shake(%UIRoot, 8.0, 0.4)
	update_ui()

# ── คลังสมบัติ ──

func _build_storage_window(c: VBoxContainer) -> void:
	c.add_child(UIKit.section("วัตถุดิบ"))
	if test_sect.materials.is_empty():
		c.add_child(UIKit.label("คลังว่างเปล่า ให้ศิษย์ตัดไม้/ขุดหิน ส่งออกไปเก็บวัตถุดิบ หรือซื้อในเมือง", 14, WuxiaTheme.PAPER_DIM))
	for id in test_sect.materials:
		var m = MaterialDB.get_material(id)
		c.add_child(UIKit.label("%s x%d  - %s" % [m.name, test_sect.materials[id], m.desc], 15, SkillDB.TIER_COLORS[m.rarity + 1]))
	c.add_child(UIKit.section("ยา"))
	_add_pill_list(c)
	c.add_child(UIKit.section("อุปกรณ์ (สวมใส่ได้ที่หน้าโปรไฟล์ศิษย์)"))
	if test_sect.equipment_storage.is_empty():
		c.add_child(UIKit.label("ยังไม่มีอุปกรณ์ในคลัง", 14, WuxiaTheme.PAPER_DIM))
	for eq in test_sect.equipment_storage:
		c.add_child(UIKit.label("[%s] %s (%s) %s" % [eq.get_rarity_name(), eq.item_name, eq.get_type_name(), eq.get_stat_text()], 15, eq.get_rarity_color()))

# ── การเมืองยุทธภพ ──

func _build_politics_window(c: VBoxContainer) -> void:
	var s = test_sect
	var day = s.current_day
	var leader = "ยังไม่มี" if s.wulin_leader == "" else FactionSys.fname(s.wulin_leader)
	c.add_child(UIKit.label("จ้าวยุทธภพ: %s   |   ประชุมพันธมิตรครั้งถัดไปในอีก %d วัน   |   ชื่อเสียงสำนักเรา: %d" % [leader, FactionSys.CONFERENCE_INTERVAL - day % FactionSys.CONFERENCE_INTERVAL, FactionSys.get_prestige(s)], 16, Color(1, 0.85, 0.4)))
	var preview = FactionSys.tally_votes(s)
	var lines: Array[String] = []
	for cand in preview.votes:
		lines.append("%s %d" % [FactionSys.fname(cand), preview.votes[cand]])
	c.add_child(UIKit.label("ถ้าประชุมวันนี้ ผลโหวตจะเป็น: " + ", ".join(lines) + "  (8 สำนักใหญ่โหวต: ความสัมพันธ์ + ชื่อเสียงของเรา เทียบกับพลัง แนวทาง และไมตรีระหว่างสำนัก)", 13, WuxiaTheme.PAPER_DIM))
	c.add_child(UIKit.label("พื้นที่ที่สำนักเรายึดครอง: %d แห่ง (รายได้ +%d/วัน)" % [s.count_owned_nodes() - 1, (s.count_owned_nodes() - 1) * FactionSys.NODE_INCOME], 14))
	if not s.pending_tribute.is_empty():
		var t = s.pending_tribute
		c.add_child(UIKit.row("%sเรียกส่วย %d เงิน (เหลือเวลา %d วัน) ถ้าไม่จ่าย ฝ่ายราชสำนักทั้งหมดจะไม่พอใจ" % [FactionSys.eunuch_leader(), t.amount, t.deadline - day], [
			UIKit.button("จ่ายส่วย", func(): GlobalGame.controller.request_pay_tribute.emit(), s.money < t.amount)], Color(0.8, 0.6, 1)))

	c.add_child(UIKit.section("ดุลอำนาจ (แต่ละฝ่ายมี AI เดินหมากของตัวเอง)"))
	for b in FactionSys.bloc_summary(s):
		c.add_child(UIKit.label("%s — พลังรวม %d · พื้นที่ %d แห่ง · %s" % [b.name, b.power, b.nodes, FactionDB.BLOCS[b.bloc].desc], 14, FactionDB.BLOCS[b.bloc].color))

	for bloc in FactionDB.BLOCS:
		c.add_child(UIKit.section(FactionDB.bloc_name(bloc)))
		var members = FactionDB.members_of(bloc)
		members.sort_custom(func(a, b): return s.factions[a].power > s.factions[b].power)
		for fid in members:
			var info = FactionDB.FACTIONS[fid]
			var f = s.factions[fid]
			var territory = s.node_owner.values().count(fid)
			var rel_color = Color(0.5, 1, 0.5) if f.relation >= 30 else (Color(1, 0.45, 0.4) if f.relation <= -30 else WuxiaTheme.PAPER)
			var text = "%s%s [%s] พลัง %d | ความสัมพันธ์ %+d | อาณาเขต %d%s" % [info.name, " ★" if info.great else "", info.align, f.power, f.relation, territory, " | ⚔ สงคราม" if f.war else ""]
			var buttons = [UIKit.button("ของกำนัล (%d)" % FactionSys.gift_cost(s, fid), func(): GlobalGame.controller.request_diplomacy.emit("gift", fid), s.money < FactionSys.gift_cost(s, fid))]
			if f.war:
				buttons.append(UIKit.button("สงบศึก (%d)" % FactionSys.peace_cost(s, fid), func(): GlobalGame.controller.request_diplomacy.emit("peace", fid), s.money < FactionSys.peace_cost(s, fid)))
			else:
				buttons.append(UIKit.button("ประกาศสงคราม", func(): GlobalGame.controller.request_diplomacy.emit("war", fid)))
			c.add_child(UIKit.row(text, buttons, rel_color))
	c.add_child(UIKit.label("★ = 8 สำนักใหญ่ที่มีสิทธิ์โหวต | บุกตีสำนักศัตรู / ประลอง / ยึดครองพื้นที่ ได้จากแผนที่โลก", 13, WuxiaTheme.PAPER_DIM))

# ── ทำเนียบยุทธภพ ──

func _build_rankings_window(c: VBoxContainer) -> void:
	c.add_child(UIKit.label("จัดอันดับตาม พลังต่อสู้ + ชื่อเสียง (ได้ชื่อเสียงจากการต่อสู้ แดนลับ ล้างแค้น ทะลวงขั้น) ชื่อเสียงถึง 100 จะได้ฉายา", 13, WuxiaTheme.PAPER_DIM))
	var ranks = FactionSys.get_rankings(test_sect)
	for i in min(30, ranks.size()):
		var r = ranks[i]
		var color = Color(1, 0.85, 0.4) if r.ours else WuxiaTheme.PAPER
		var title = (" '%s'" % r.title) if r.title != "" else ""
		c.add_child(UIKit.label("%2d. %s%s  —  %s  |  พลัง %d  ชื่อเสียง %d" % [i + 1, r.name, title, r.sect, r.power, r.fame], 15, color))

# ── ผังขั้นบำเพ็ญ ──

var _realm_target: DiscipleData

func _build_realm_window(c: VBoxContainer) -> void:
	var active = test_sect.get_active_disciples()
	if active.is_empty(): return
	if _realm_target == null or not active.has(_realm_target):
		_realm_target = test_sect.get_founder() if active.has(test_sect.get_founder()) else active[0]
	var opt = OptionButton.new()
	for d in active: opt.add_item("%s (%s)" % [d.get_display_name(), d.realm_name])
	opt.select(active.find(_realm_target))
	opt.item_selected.connect(func(i):
		_realm_target = active[i]
		_refresh_window())
	c.add_child(UIKit.row("ดูผังของ:", [opt]))
	var tree = RealmTree.create(_realm_target)
	tree.custom_minimum_size = Vector2(0, 420)
	c.add_child(tree)

# ── ทะลวงคอขวด ──

var _use_pill: bool = true

func _build_breakthrough_window(c: VBoxContainer) -> void:
	var pill_count = test_sect.count_pills("breakthrough_pill") + test_sect.count_pills("heaven_pill")
	var cb = CheckBox.new()
	cb.text = "ใช้ยาทะลวงปราณที่ดีที่สุดในคลัง (มี %d เม็ด)" % pill_count
	cb.button_pressed = _use_pill and pill_count > 0
	cb.disabled = pill_count == 0
	cb.toggled.connect(func(on): _use_pill = on)
	c.add_child(cb)
	c.add_child(UIKit.label("[ช่วยเดินลมปราณ] = เล่นมินิเกมต่อท่อลมปราณ สำเร็จ = ทะลวงแน่นอน, พลาด = ธาตุไฟแตกซ่าน (บาดเจ็บ/สเตตัสลด)\n[ให้ทะลวงเอง] = สุ่มตามโอกาส พลาดเสีย EXP 20%", 14, WuxiaTheme.PAPER_DIM))

	var count = 0
	for d in test_sect.disciples:
		var info = CultivationSys.get_realm_info(d.level)
		if not (info.is_bottleneck and d.experience >= CultivationSys.get_required_exp(d.level)): continue
		if not d.is_available(): continue
		count += 1
		var next_realm = CultivationSys.get_realm_info(d.level + 1).name
		var chance = CultivationSys.get_breakthrough_chance(d.level, d.aptitude_root)
		var tribulation = " [ทัณฑ์สวรรค์!]" if CultivationSys.has_tribulation(d.level) else ""
		c.add_child(HSeparator.new())
		c.add_child(UIKit.row("%s: %s -> %s%s\nโอกาสพื้นฐาน %d%%" % [d.disciple_name, d.realm_name, next_realm, tribulation, int(chance)], [
			UIKit.button("ช่วยเดินลมปราณ", func(): _breakthrough_minigame(d)),
			UIKit.button("ให้ทะลวงเอง", func(): _breakthrough_auto(d)),
		]))
	if count == 0:
		c.add_child(UIKit.label("ตอนนี้ยังไม่มีศิษย์คนไหนพร้อมทะลวงคอขวดขั้นใหญ่ (ต้องถึงขั้นสมบูรณ์และ EXP เต็ม)", 16))

## ใช้ยาทะลวงที่ดีที่สุด คืนค่าโบนัส {seconds, chance} (ว่างถ้าไม่ได้ใช้)
func _consume_breakthrough_pill() -> Dictionary:
	if not _use_pill: return {}
	for pill_id in ["heaven_pill", "breakthrough_pill"]:
		var q = test_sect.take_best_pill(pill_id)
		if q >= 0:
			_log("ใช้ %s [%s]" % [RecipeDB.PILLS[pill_id].name, RecipeDB.PILL_QUALITY_NAMES[q]])
			return RecipeDB.get_breakthrough_bonus(pill_id, q)
	return {}

func _breakthrough_minigame(d: DiscipleData) -> void:
	if not _window.is_empty() and is_instance_valid(_window.root):
		_window.root.queue_free()
	_window = {}
	var params = CultivationSys.get_meridian_puzzle_params(d.level, d.aptitude_root)
	var bonus = _consume_breakthrough_pill()
	var next_realm = CultivationSys.get_realm_info(d.level + 1).name
	var game = MeridianMinigame.new()
	game.setup("ช่วย %s เดินลมปราณทะลวงสู่ %s" % [d.disciple_name, next_realm], params.size, params.time + bonus.get("seconds", 0.0), CultivationSys.get_aura_color(d.element, d.level))
	game.finished.connect(func(success: bool):
		if success:
			_on_breakthrough_success(d)
		else:
			var result = d.suffer_qi_deviation(sect_manager.current_day)
			_log("[color=red]%s ธาตุไฟแตกซ่าน! %s[/color]" % [d.disciple_name, result])
			VFX.flash(%UIRoot, Color(0.8, 0.1, 0.1, 0.5), 0.5)
		update_ui())
	_open_minigame(game)

func _breakthrough_auto(d: DiscipleData) -> void:
	var bonus = _consume_breakthrough_pill()
	if d.attempt_breakthrough(bonus.get("chance", 0.0), sect_manager.current_day):
		_on_breakthrough_success(d, true)
	else:
		_log("[color=red]ล้มเหลว! %s ลมปราณตีกลับ เสีย EXP 20%%[/color]" % d.disciple_name)
		VFX.screen_shake(%UIRoot, 6.0, 0.3)
	update_ui()

func _on_breakthrough_success(d: DiscipleData, already_leveled := false) -> void:
	var tribulation = CultivationSys.has_tribulation(d.level - (1 if already_leveled else 0))
	if not already_leveled:
		d.complete_breakthrough(sect_manager.current_day)
	_log("[color=green]สำเร็จ! %s ทะลวงคอขวดเข้าสู่ %s![/color]%s" % [d.disciple_name, d.realm_name, " ฝ่าทัณฑ์อัสนีสวรรค์มาได้!" if tribulation else ""])
	VFX.breakthrough(%UIRoot, CultivationSys.get_aura_color(d.element, d.level), tribulation, 2 + CultivationSys.get_realm_info(d.level).major_index)
