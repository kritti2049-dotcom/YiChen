extends RefCounted
class_name WuxiaTheme

## ธีม UI สไตล์กำลังภายใน: แผงไม้สีเข้ม ขอบทองสำริด ตัวอักษรสีกระดาษสา
## ถูกตั้งเป็นธีมของหน้าต่างหลักใน GlobalGame._ready() จึงมีผลกับทุกฉาก

const INK = Color(0.08, 0.07, 0.06)
const WOOD = Color(0.30, 0.19, 0.11)
const WOOD_LIGHT = Color(0.40, 0.26, 0.15)
const WOOD_DARK = Color(0.20, 0.12, 0.07)
const BRONZE = Color(0.75, 0.58, 0.32)
const PAPER = Color(0.93, 0.88, 0.76)
const PAPER_DIM = Color(0.70, 0.65, 0.55)
const CINNABAR = Color(0.78, 0.22, 0.18)

static func build() -> Theme:
	var t = Theme.new()

	# ── ปุ่ม: แผ่นไม้ ขอบสำริด ──
	t.set_stylebox("normal", "Button", _box(WOOD, BRONZE.darkened(0.25), 2, 4))
	t.set_stylebox("hover", "Button", _box(WOOD_LIGHT, BRONZE, 2, 4))
	t.set_stylebox("pressed", "Button", _box(WOOD_DARK, BRONZE.lightened(0.2), 2, 4))
	t.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), BRONZE.lightened(0.3), 1, 4))
	t.set_stylebox("disabled", "Button", _box(Color(0.18, 0.15, 0.13), Color(0.35, 0.3, 0.25), 2, 4))
	t.set_color("font_color", "Button", PAPER)
	t.set_color("font_hover_color", "Button", Color(1.0, 0.95, 0.8))
	t.set_color("font_pressed_color", "Button", BRONZE.lightened(0.3))
	t.set_color("font_disabled_color", "Button", Color(0.5, 0.45, 0.4))

	# ── แผง: หมึกเข้มโปร่งแสง ขอบทอง ──
	var panel = _box(Color(INK, 0.88), BRONZE.darkened(0.35), 2, 6)
	t.set_stylebox("panel", "Panel", panel)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "PopupPanel", panel)

	# ── ตัวอักษร ──
	t.set_color("font_color", "Label", PAPER)
	t.set_color("default_color", "RichTextLabel", PAPER)
	t.set_color("font_color", "CheckBox", PAPER)
	t.set_color("font_color", "LineEdit", PAPER)
	t.set_color("font_color", "OptionButton", PAPER)
	t.set_stylebox("normal", "OptionButton", _box(WOOD, BRONZE.darkened(0.25), 2, 4))
	t.set_stylebox("hover", "OptionButton", _box(WOOD_LIGHT, BRONZE, 2, 4))
	t.set_stylebox("normal", "LineEdit", _box(Color(0.1, 0.08, 0.06), BRONZE.darkened(0.4), 1, 3))

	# ── แถบหลอด ──
	t.set_stylebox("background", "ProgressBar", _box(Color(0.12, 0.1, 0.08), BRONZE.darkened(0.5), 1, 3))
	t.set_stylebox("fill", "ProgressBar", _box(CINNABAR, Color(0, 0, 0, 0), 0, 3))
	t.set_color("font_color", "ProgressBar", PAPER)

	# ── แท็บ (แฟ้มเอกสาร) ──
	t.set_stylebox("panel", "TabContainer", _box(Color(INK, 0.9), BRONZE.darkened(0.35), 2, 4))
	t.set_stylebox("tab_selected", "TabContainer", _box(WOOD_LIGHT, BRONZE, 2, 4))
	t.set_stylebox("tab_unselected", "TabContainer", _box(WOOD_DARK, BRONZE.darkened(0.45), 1, 4))
	t.set_stylebox("tab_hovered", "TabContainer", _box(WOOD, BRONZE.darkened(0.1), 1, 4))
	t.set_color("font_selected_color", "TabContainer", Color(1.0, 0.92, 0.7))
	t.set_color("font_unselected_color", "TabContainer", PAPER_DIM)
	t.set_color("font_hovered_color", "TabContainer", PAPER)

	# ── Tooltip: กระดาษสา ตัวหมึก ──
	t.set_stylebox("panel", "TooltipPanel", _box(PAPER, WOOD, 2, 4))
	t.set_color("font_color", "TooltipLabel", INK)

	t.set_color("font_separator_color", "HSeparator", BRONZE)
	t.set_stylebox("separator", "HSeparator", _line(BRONZE.darkened(0.3)))
	return t

static func _box(bg: Color, border: Color, border_w: int, radius: int) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s

static func _line(color: Color) -> StyleBoxLine:
	var s = StyleBoxLine.new()
	s.color = color
	s.thickness = 1
	return s
