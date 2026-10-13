extends Node
class_name PathService

## คิวคำขอหาเส้นทาง: จำกัดจำนวนคำขอต่อเฟรม แบ่งคิวข้ามเฟรม (คำขอพร้อมกันเป็นร้อยไม่ทำให้เฟรมกระตุก)
## ฉากเดิน (เมือง/พื้นที่สำรวจ) สร้างไว้ 1 ตัว: NPC/มอนสเตอร์เรียก PathService.request(...) แทนการหาทางเองทันที
## ผู้เล่นหาทางทันที (ไม่ต้องรอคิว)

const MAX_PER_FRAME = 4

static var current: PathService

var _queue: Array = []

func _enter_tree() -> void:
	current = self

func _exit_tree() -> void:
	if current == self: current = null

## ขอเส้นทาง: callback(path: PackedVector2Array) ถูกเรียกเมื่อหาเสร็จ (เฟรมนี้หรือเฟรมถัดไป)
static func request(layout, from: Vector2, to: Vector2, owner: Object, callback: Callable) -> void:
	if current == null:
		callback.call(layout.find_path(from, to))
		return
	# คำขอเดิมของเจ้าของเดียวกันยังไม่ทันได้ทำ = แทนที่ (เอาเป้าหมายล่าสุด)
	for q in current._queue:
		if q.owner == owner:
			q.from = from
			q.to = to
			q.callback = callback
			return
	current._queue.append({ "layout": layout, "from": from, "to": to, "owner": owner, "callback": callback })

func pending() -> int:
	return _queue.size()

func _process(_delta: float) -> void:
	var n = 0
	while not _queue.is_empty() and n < MAX_PER_FRAME:
		var q = _queue.pop_front()
		n += 1
		if not is_instance_valid(q.owner): continue
		q.callback.call(q.layout.find_path(q.from, q.to))
