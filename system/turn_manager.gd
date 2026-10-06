extends Node
class_name TurnManager

## จัดคิวลำดับเทิร์นของ unit ทั้งหมดในการต่อสู้ เรียงตาม speed (มากไปน้อย)
## ใช้งาน: TurnManager.register_unit(unit) ตอน unit เข้าสู่สนามรบ
## แล้วเรียก TurnManager.start_battle() เพื่อเริ่มวนเทิร์น

signal turn_started(unit)
signal turn_ended(unit)
signal battle_ended

var turn_queue: Array = []
var current_unit = null
var current_index: int = -1

func register_unit(unit: Node) -> void:
	turn_queue.append(unit)
	_sort_queue()

func remove_unit(unit: Node) -> void:
	turn_queue.erase(unit)
	if turn_queue.is_empty():
		battle_ended.emit()

func _sort_queue() -> void:
	# เรียง unit ตาม speed จากมากไปน้อย ต้องมี property "unit_data.speed" ใน unit node
	turn_queue.sort_custom(func(a, b): return a.unit_data.speed > b.unit_data.speed)

func start_battle() -> void:
	current_index = -1
	_advance_turn()

func end_current_turn() -> void:
	if current_unit:
		turn_ended.emit(current_unit)
	_advance_turn()

func _advance_turn() -> void:
	if turn_queue.is_empty():
		battle_ended.emit()
		return
	current_index = (current_index + 1) % turn_queue.size()
	current_unit = turn_queue[current_index]
	turn_started.emit(current_unit)
