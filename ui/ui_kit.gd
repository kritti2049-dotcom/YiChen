extends RefCounted
class_name UIKit

## ตัวช่วยสร้าง UI ในโค้ด (หน้าต่างป๊อปอัป, ปุ่ม, ป้ายข้อความ)

## สร้างหน้าต่างป๊อปอัปกลางจอ คืนค่า { "root": Control (ไว้ queue_free), "content": VBoxContainer }
static func open_window(parent: Node, title: String, size := Vector2(720, 520)) -> Dictionary:
	var root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP

	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var panel = PanelContainer.new()
	# ไม่ให้หน้าต่างใหญ่เกินจอ (ขนาดฐานของจอ 1152x648 ถูกขยายตามหน้าต่างเกม)
	var view = parent.get_viewport().get_visible_rect().size if parent.is_inside_tree() else Vector2(1152, 648)
	panel.custom_minimum_size = size.min(view - Vector2(24, 24))
	center.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var header = HBoxContainer.new()
	vbox.add_child(header)
	var lbl = label(title, 24, WuxiaTheme.BRONZE.lightened(0.2))
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(lbl)
	header.add_child(button("ปิด", func(): root.queue_free()))
	vbox.add_child(HSeparator.new())

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 6)
	scroll.add_child(content)

	parent.add_child(root)
	return { "root": root, "content": content }

static func clear(node: Node) -> void:
	for c in node.get_children():
		c.queue_free()

static func label(text: String, font_size: int = 16, color = null) -> Label:
	var l = Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if font_size != 16:
		l.add_theme_font_size_override("font_size", font_size)
	if color != null:
		l.add_theme_color_override("font_color", color)
	return l

static func rich(text: String) -> RichTextLabel:
	var r = RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.text = text
	return r

static func button(text: String, callback: Callable, disabled := false) -> Button:
	var b = Button.new()
	b.text = text
	b.disabled = disabled
	b.pressed.connect(callback)
	return b

## แถวแนวนอน: ป้ายข้อความ (ขยายเต็ม) + ปุ่มต่างๆ ด้านขวา
static func row(text: String, buttons: Array = [], color = null) -> HBoxContainer:
	var h = HBoxContainer.new()
	var l = label(text, 16, color)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	for b in buttons:
		h.add_child(b)
	return h

## ข้อความแจ้งเตือนลอยขึ้นมุมบนกลางจอ แล้วหายไปเอง
static func toast(parent: Node, text: String, color := Color(1, 0.85, 0.5)) -> void:
	var panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l = label(text, 16, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(l)
	panel.custom_minimum_size = Vector2(420, 0)
	panel.position = Vector2(parent.get_viewport().get_visible_rect().size.x / 2.0 - 210, 70)
	parent.add_child(panel)
	var tw = panel.create_tween()
	tw.tween_interval(1.8)
	tw.tween_property(panel, "modulate:a", 0.0, 0.5)
	tw.tween_callback(panel.queue_free)

static func section(text: String) -> Label:
	return label("── %s ──" % text, 18, WuxiaTheme.BRONZE)
