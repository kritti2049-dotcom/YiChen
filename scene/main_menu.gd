extends Control

func _ready() -> void:
	GlobalGame.clock_enabled = false
	if has_node("%BtnNewGame"):
		%BtnNewGame.pressed.connect(_on_btn_new_pressed)
		%BtnLoadGame.pressed.connect(_on_btn_load_pressed)
		%BtnSettings.text = "หอเกียรติยศ"
		%BtnSettings.pressed.connect(_on_btn_archive_pressed)
		%BtnQuit.pressed.connect(_on_btn_quit_pressed)

func _on_btn_new_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/char_creation.tscn")

## เลือกสล็อตเซฟที่จะโหลด (หรือลบ)
func _on_btn_load_pressed() -> void:
	var w = UIKit.open_window(self, "เลือกเซฟ", Vector2(640, 360))
	_fill_slots(w)

func _fill_slots(w: Dictionary) -> void:
	UIKit.clear(w.content)
	for slot in range(1, GlobalGame.SLOT_COUNT + 1):
		var info = GlobalGame.slot_info(slot)
		if info.is_empty():
			w.content.add_child(UIKit.row("สล็อต %d: (ว่าง)" % slot, [], WuxiaTheme.PAPER_DIM))
			continue
		var text = "สล็อต %d: %s — %s | วันที่ %d | ศิษย์ %d คน | เจ้าสำนัก %s | ความยาก%s%s%s" % [
			slot, info.sect_name, info.mode, info.day, info.disciples, info.founder, info.difficulty,
			" | จ้าวยุทธภพ" if info.leader else "", " | ล่มสลายแล้ว" if info.game_over else ""]
		w.content.add_child(UIKit.row(text, [
			UIKit.button("โหลด", func():
				if GlobalGame.load_game(slot):
					get_tree().change_scene_to_file("res://scene/test_sect.tscn"), info.game_over),
			UIKit.button("ลบ", func():
				GlobalGame.delete_slot(slot)
				_fill_slots(w)),
		], Color(1, 0.5, 0.45) if info.game_over else WuxiaTheme.PAPER))

## หอเกียรติยศ: ความสำเร็จ / คัมภีร์ที่ปลดล็อก / วิชาตกทอด (ข้ามทุกเซฟ)
func _on_btn_archive_pressed() -> void:
	var w = UIKit.open_window(self, "หอเกียรติยศ", Vector2(760, 520))
	var c: VBoxContainer = w.content
	var data = ArchiveSys.data()
	c.add_child(UIKit.label("เล่นมาแล้ว %d รอบ | ความสำเร็จแต่ละอันให้แต้มเริ่มต้น +%d ตอนสร้างตัวละคร (ตอนนี้ +%d)" % [int(data.get("runs", 0)), ArchiveSys.POINTS_PER_ACHIEVEMENT, ArchiveSys.bonus_points()], 15, Color(1, 0.85, 0.4)))
	c.add_child(UIKit.section("ความสำเร็จ (%d / %d)" % [data.achievements.size(), ArchiveSys.ACHIEVEMENTS.size()]))
	for id in ArchiveSys.ACHIEVEMENTS:
		var a = ArchiveSys.ACHIEVEMENTS[id]
		var got = data.achievements.has(id)
		c.add_child(UIKit.label("%s %s — %s%s" % ["★" if got else "☆", a.name, a.desc, (" (%s)" % data.achievements[id]) if got else ""], 15, Color(1, 0.85, 0.4) if got else WuxiaTheme.PAPER_DIM))
	c.add_child(UIKit.section("คัมภีร์ที่ปลดล็อกเป็นวิชาเริ่มต้น (%d)" % data.unlocked_skills.size()))
	c.add_child(UIKit.label(", ".join(data.unlocked_skills) if not data.unlocked_skills.is_empty() else "ยังไม่มี — ได้คัมภีร์ในเกมแล้วจะปลดล็อกถาวร", 14))
	c.add_child(UIKit.section("วิชาตกทอดจากสำนักรุ่นก่อน (%d)" % data.legacy_skills.size()))
	for s in data.legacy_skills:
		var info = data.legacy_skills[s]
		c.add_child(UIKit.label("%s (ขั้น%s พลัง %d) - %s" % [s, SkillDB.TIER_NAMES[int(info.tier)], int(info.power), info.desc], 14, SkillDB.TIER_COLORS[int(info.tier)]))

func _on_btn_quit_pressed() -> void:
	get_tree().quit()
