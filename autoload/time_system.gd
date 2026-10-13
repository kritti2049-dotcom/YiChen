extends Node

signal time_changed(phase_name)
signal day_passed(day)

enum TimePhase { MORNING, AFTERNOON, NIGHT }
var current_phase: TimePhase = TimePhase.MORNING
var current_day: int = 1

var tick_timer: Timer

func _ready() -> void:
	tick_timer = Timer.new()
	tick_timer.wait_time = 5.0 # 5 วินาทีชีวิตจริง = 1 ช่วงเวลาในเกม
	tick_timer.autostart = true
	tick_timer.timeout.connect(_on_tick)
	add_child(tick_timer)

func _on_tick() -> void:
	if current_phase == TimePhase.MORNING:
		current_phase = TimePhase.AFTERNOON
	elif current_phase == TimePhase.AFTERNOON:
		current_phase = TimePhase.NIGHT
	elif current_phase == TimePhase.NIGHT:
		current_phase = TimePhase.MORNING
		current_day += 1
		day_passed.emit(current_day)
		
	time_changed.emit(_get_phase_name())

func _get_phase_name() -> String:
	match current_phase:
		TimePhase.MORNING: return "เช้า"
		TimePhase.AFTERNOON: return "บ่าย"
		TimePhase.NIGHT: return "กลางคืน"
	return ""
