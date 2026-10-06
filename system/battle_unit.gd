extends Node2D
class_name BattleUnit

## ตัวแทน unit หนึ่งตัวในสนามรบจริง (แยกจาก UnitData ซึ่งเป็นแค่ "แม่แบบ")
## unit_data คือ template, ส่วนตัวแปรด้านล่างคือสถานะปัจจุบันระหว่างต่อสู้

@export var unit_data: UnitData
@export var equipped_items: Array[ItemData] = []

var current_hp: int
var is_player_controlled: bool = true

signal died(unit)
signal hp_changed(current: int, max: int)

func _ready() -> void:
	if unit_data:
		current_hp = get_total_stat("max_hp")
		hp_changed.emit(current_hp, get_total_stat("max_hp"))

## รวม stat จาก unit_data + item ที่ใส่อยู่ทั้งหมด
func get_total_stat(stat_name: String) -> int:
	var base_value: int = unit_data.get(stat_name)
	var modifier_key := stat_name.replace("max_", "") + "_modifier"
	for item in equipped_items:
		if modifier_key in item:
			base_value += item.get(modifier_key)
	return base_value

func take_damage(amount: int) -> void:
	var mitigated = max(1, amount - get_total_stat("defense"))
	current_hp = max(0, current_hp - mitigated)
	hp_changed.emit(current_hp, get_total_stat("max_hp"))
	if current_hp <= 0:
		died.emit(self)

func heal(amount: int) -> void:
	current_hp = min(get_total_stat("max_hp"), current_hp + amount)
	hp_changed.emit(current_hp, get_total_stat("max_hp"))
