extends Node

## GameManager (Autoload): เก็บ Model ทั้งหมดของเกม (สำนัก ศิษย์ เซฟสล็อต นาฬิกา 3 ช่วงเวลา)
## หน้าจอต่างๆ (View) ส่งคำสั่งผ่าน controller (GameController) แล้วรอ Signal ผลลัพธ์กลับมาวาดใหม่

signal phase_changed(phase: int)
signal day_changed(day: int)
signal sect_event_logged(event: Dictionary)
signal game_over

const SLOT_COUNT = 3
const PHASE_NAMES = ["เช้า", "บ่าย", "กลางคืน"]
## วินาทีจริงต่อ 1 ช่วงเวลา ที่ความเร็ว x1 (1 วัน = 3 ช่วง)
const SECONDS_PER_PHASE = 20.0
const SPEEDS = [1, 2, 4, 8]
## จังหวะจำลองต่อช่วงเวลา (ระบบศิษย์ทำงานทีละ tick ดู SectManager.sim_tick)
const TICKS_PER_PHASE = 120

## ตัวแปรเก็บข้อมูลเซฟเกมปัจจุบัน
var current_sect: SectData
var current_slot: int = 1
var _last_autosave_ms := 0
## 0 = ง่าย, 1 = ปานกลาง, 2 = นรก (ค่าจริงเก็บใน current_sect.difficulty)
var difficulty: int = 1

## ตัวจัดการสำนัก (อยู่ตลอดทุกฉาก เวลาจึงเดินต่อเนื่องได้)
var sect_manager: SectManager
## Controller ของ MVC: รับคำสั่งจากหน้าจอ ตรวจสอบ แก้ข้อมูล แล้วยิง Signal ผลลัพธ์
var controller: GameController

## นาฬิกา: เปิดเฉพาะฉากที่เป็นโลกจำลอง (หน้าสำนัก / แผนที่โลก)
var clock_enabled := false
var paused := false
var speed_index := 0
var _tick_accum := 0.0

## ตัวละครที่เลือกดูโปรไฟล์
var selected_disciple: DiscipleData
## เมืองที่กำลังเข้าไป (id จาก WorldDB)
var selected_city_id: String = ""
## ตำแหน่งอวตารในเมืองก่อนตัดเข้าฉากต่อสู้ (กลับมาแล้วยืนที่เดิม)
var city_return_id: String = ""
var city_return_pos: Vector2 = Vector2.ZERO
## พื้นที่สำรวจแบบเดินเอง: โหนดที่กำลังสำรวจ ทีมที่ลงพื้นที่ และสถานะพื้นที่ (คงอยู่ระหว่างตัดเข้าฉากต่อสู้)
var field_node: String = ""
var field_team: Array[DiscipleData] = []
var field_state: Dictionary = {}

## ระบบต่อสู้
## ฉากต่อสู้ที่ทุกจุดเรียกใช้ (สนามกริด) — ฉากเก่า combat_scene.tscn จะลบหลังย้ายครบ (ดู plan_combat_and_art.md)
const COMBAT_SCENE = "res://scene/combat/grid_combat_scene.tscn"
var combat_allies: Array[DiscipleData] = []
var combat_enemies: Array[Dictionary] = [] # เก็บข้อมูลศัตรู
## ฉากที่จะกลับไปหลังจบการต่อสู้
var combat_return_scene: String = "res://scene/test_sect.tscn"
## ฉากที่จะกลับไปเมื่อปิดแฟ้มประวัติศิษย์ (ค่าเริ่ม = หน้าสำนัก)
var profile_return_scene: String = "res://scene/test_sect.tscn"
## เงินรางวัลพิเศษเมื่อชนะ (เช่น จากภารกิจล่าค่าหัว)
var combat_bonus_money: int = 0
var combat_bonus_task: String = ""
## บริบทของการต่อสู้ { "type": hunt/claim/siege/spar/bounty, "node": node_id, "faction": faction_id }
var combat_context: Dictionary = {}

func _ready() -> void:
	# ธีม UI สไตล์กำลังภายใน ใช้กับทุกฉาก
	var theme = WuxiaTheme.build()
	get_tree().root.theme = theme
	# ธีมของหน้าต่างหลักไม่ส่งต่อผ่าน CanvasLayer จึงใส่ให้ Control ตัวบนสุดที่อยู่ใต้ CanvasLayer เอง
	get_tree().node_added.connect(func(node):
		if node is Control and node.theme == null and node.get_parent() is CanvasLayer:
			node.theme = theme)
	sect_manager = SectManager.new()
	add_child(sect_manager)
	sect_manager.sect_event_logged.connect(func(e): sect_event_logged.emit(e))
	controller = GameController.new()
	add_child(controller)

## เริ่มใช้งานสำนัก (หลังสร้างใหม่/โหลด)
func set_sect(sect: SectData) -> void:
	current_sect = sect
	sect.ensure_defaults()
	difficulty = sect.difficulty
	sect_manager.join_sect(sect, 0)

# ══════════════════════════════════════════
# นาฬิกา 3 ช่วงเวลา (เช้า - บ่าย - กลางคืน)
# ══════════════════════════════════════════

func get_speed() -> int:
	return SPEEDS[speed_index]

func cycle_speed() -> void:
	speed_index = (speed_index + 1) % SPEEDS.size()

func _process(delta: float) -> void:
	if not clock_enabled or paused or current_sect == null or current_sect.is_game_over: return
	_tick_accum += delta * get_speed() * TICKS_PER_PHASE / SECONDS_PER_PHASE
	var budget = 200
	while _tick_accum >= 1.0 and budget > 0:
		_tick_accum -= 1.0
		budget -= 1
		sect_manager.sim_tick()
		if current_sect.phase_tick >= TICKS_PER_PHASE: advance_phase(true)
		if current_sect.is_game_over: return
	_tick_accum = min(_tick_accum, 5.0)
	current_sect.phase_progress = clampf((current_sect.phase_tick + _tick_accum) / TICKS_PER_PHASE, 0.0, 1.0)

## ผ่านไป 1 ช่วงเวลา (ช่วงกลางคืนจบ = ขึ้นวันใหม่)
## เรียกตรงๆ (ข้ามเวลา เช่น พักโรงเตี๊ยม/จำลองเร่งเวลา) จะจำลอง tick ที่เหลือของช่วงนี้ให้ครบก่อน
func advance_phase(natural := false) -> void:
	var sect = current_sect
	if not natural:
		while sect.phase_tick < TICKS_PER_PHASE and not sect.is_game_over:
			sect_manager.sim_tick()
	sect.phase_tick = 0
	sect.phase_progress = 0.0
	if sect.time_phase >= 2:
		sect.time_phase = 0
		sect_manager.process_daily_update()
		# เซฟอัตโนมัติรายวัน แต่ไม่ถี่กว่า 15 วินาทีจริง (เล่นเร็วหลายเท่าแล้วเซฟทุกวันทำให้ภาพสะดุด)
		if Time.get_ticks_msec() - _last_autosave_ms > 15000:
			_last_autosave_ms = Time.get_ticks_msec()
			save_game()
		day_changed.emit(sect.current_day)
		if sect.get_active_disciples().is_empty() and not sect.is_game_over:
			EndingSys.trigger(sect, "collapse")
			sect_manager.log_event("[color=red]ไม่เหลือศิษย์สักคน... สำนัก%s ล่มสลายแล้ว[/color]" % sect.sect_name)
			save_game()
			game_over.emit()
	else:
		sect.time_phase += 1
	sect_manager.process_phase(sect.time_phase)
	phase_changed.emit(sect.time_phase)

## ชั่วโมงสำหรับคำนวณแสง (เช้า 6-12, บ่าย 12-18, กลางคืน 18-24)
func get_hour() -> float:
	if current_sect == null: return 12.0
	return 6.0 + (current_sect.time_phase + current_sect.phase_progress) * 6.0

## ความคืบหน้าของวัน 0-1 (ใช้ให้ศิษย์บนแผนที่โลกเดินต่อเนื่อง)
func get_day_fraction() -> float:
	if current_sect == null: return 0.0
	return (current_sect.time_phase + current_sect.phase_progress) / 3.0

func get_clock_text() -> String:
	if current_sect == null: return ""
	# แสดงนาฬิกาด้วย ให้เห็นว่าเวลาเดินอยู่ (1 ช่วง = 6 ชั่วโมงในเกม)
	var h = get_hour()
	return "วันที่ %d · %s %02d:%02d" % [current_sect.current_day, PHASE_NAMES[current_sect.time_phase], int(h) % 24, int(fmod(h, 1.0) * 60) / 10 * 10]

# ══════════════════════════════════════════
# เซฟสล็อต
# ══════════════════════════════════════════

func slot_path(slot: int) -> String:
	return "user://save_slot_%d.tres" % slot

func save_game(slot: int = -1) -> void:
	if slot < 0: slot = current_slot
	if current_sect != null:
		ResourceSaver.save(current_sect, slot_path(slot))

func load_game(slot: int = -1) -> bool:
	if slot < 0: slot = current_slot
	var save_path = slot_path(slot)
	if ResourceLoader.exists(save_path):
		var sect = ResourceLoader.load(save_path, "", ResourceLoader.CACHE_MODE_IGNORE) as SectData
		if sect != null:
			current_slot = slot
			set_sect(sect)
			return true
	return false

## ข้อมูลสรุปของสล็อต (ว่าง = {})
func slot_info(slot: int) -> Dictionary:
	var path = slot_path(slot)
	if not ResourceLoader.exists(path): return {}
	var sect = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as SectData
	if sect == null: return {}
	var founder = sect.get_founder()
	return {
		"sect_name": sect.sect_name, "day": sect.current_day, "disciples": sect.get_active_disciples().size(),
		"founder": founder.disciple_name if founder else "-", "difficulty": BuildingDB.diff(sect.difficulty).name,
		"game_over": sect.is_game_over, "leader": sect.wulin_leader == "player",
		"mode": WorldMode.MODES.get(sect.world_mode, WorldMode.MODES.story).name,
	}

func delete_slot(slot: int) -> void:
	if FileAccess.file_exists(slot_path(slot)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(slot_path(slot)))
