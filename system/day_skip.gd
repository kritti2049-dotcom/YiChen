extends RefCounted
class_name DaySkip

## ข้ามเวลาไปเช้าวันถัดไป (ใช้ได้ทุกช่วงเวลา) — จำลองครบทุก tick เหมือนปล่อยเวลาเดินเอง (ก่อสร้าง ผลผลิต ศึกษา สัตว์ ฯลฯ)
## หยุดกลางทางทันทีถ้ามีเรื่องให้ตัดสินใจ (ศัตรูบุก / พ่อค้าเร่ / เนื้อเรื่อง / จุดจบ) แล้วคืน "รายงานสรุป" ว่าเกิดอะไรขึ้นบ้าง

const RES_KEYS = [["money", "เงิน"], ["food", "เสบียง"], ["meals", "สำรับ"]]
const MAT_KEYS = [["wood", "ไม้"], ["stone", "หิน"], ["spirit_grass", "หญ้าวิญญาณ"], ["iron_ore", "แร่เหล็ก"], ["scripture_fragment", "คัมภีร์ชำรุด"], ["beast_hide", "หนังสัตว์"]]

static func _snapshot(sect: SectData) -> Dictionary:
	var sites := {}
	var levels := {}
	for inst in sect.structures:
		levels[inst.uid] = int(inst.level)
		if not inst.site.is_empty(): sites[inst.uid] = float(inst.site.work) / maxf(1.0, float(inst.site.required))
	var study := {}
	for d in sect.get_active_disciples():
		if d.study_skill != "": study[d] = [d.study_skill, d.study_progress, d.learned_skills.size()]
	var res := {}
	for k in RES_KEYS: res[k[0]] = int(sect.get(k[0]))
	for k in MAT_KEYS: res[k[0]] = sect.get_material_count(k[0])
	return {
		"day": sect.current_day, "phase": sect.time_phase, "res": res, "sites": sites, "levels": levels, "study": study,
		"library": sect.library_skills.duplicate(), "people": sect.get_active_disciples().size(),
		"log_tail": sect.event_log.back() if not sect.event_log.is_empty() else null,
	}

## ข้ามแบบทีละช่วง (ให้ฉากแสดงการนอนพัก/นาฬิกาเดินระหว่างจำลอง): begin -> step ซ้ำจนคืนค่าไม่ว่าง -> finish
static func begin(sect: SectData) -> Dictionary:
	return _snapshot(sect)

## จำลองต่อไม่เกิน max_ticks · คืน "" = ยังไม่จบ, "done" = ถึงเช้าแล้ว, อื่นๆ = เหตุผลที่หยุด
static func step(sect: SectData, mgr: SectManager, b: Dictionary, max_ticks: int) -> String:
	for i in max_ticks:
		if sect.is_game_over: return "done"
		mgr.sim_tick()
		if sect.phase_tick >= GlobalGame.TICKS_PER_PHASE:
			GlobalGame.advance_phase(true)
			if sect.current_day > int(b.day) and sect.time_phase == 0: return "done"
		if not sect.pending_event.is_empty():
			return "ศัตรูบุกสำนัก!" if sect.pending_event.get("type", "") == "raid" else "มีผู้มาเยือนที่ประตูสำนัก"
		if not sect.pending_story.is_empty(): return "มีเหตุการณ์สำคัญเกิดขึ้น"
		if sect.pending_ending != "": return "สำนักมาถึงทางแยกสำคัญ"
	return ""

static func finish(sect: SectData, b: Dictionary, result: String) -> Dictionary:
	return _report(sect, b, "" if result == "done" else result)

## ข้ามถึงเช้าวันใหม่ทันที (ไม่มีภาพประกอบ) คืนรายงาน { lines, log, stopped }
static func skip_to_morning(sect: SectData, mgr: SectManager) -> Dictionary:
	var b = begin(sect)
	var r = ""
	var guard = 0
	while r == "" and guard < 50:
		r = step(sect, mgr, b, 100)
		guard += 1
	return finish(sect, b, r)

static func _report(sect: SectData, b: Dictionary, stopped: String) -> Dictionary:
	var lines: Array[String] = []
	lines.append("วันที่ %d (%s) → วันที่ %d (%s)" % [b.day, _phase_name(b.phase), sect.current_day, _phase_name(sect.time_phase)])
	# ทรัพยากร
	var parts: Array[String] = []
	for k in RES_KEYS:
		var dv = int(sect.get(k[0])) - int(b.res[k[0]])
		if dv != 0: parts.append("%s %+d" % [k[1], dv])
	for k in MAT_KEYS:
		var dv = sect.get_material_count(k[0]) - int(b.res[k[0]])
		if dv != 0: parts.append("%s %+d" % [k[1], dv])
	if not parts.is_empty(): lines.append("คลัง: " + " · ".join(parts))
	# ก่อสร้าง
	for inst in sect.structures:
		var name = BuildingDB.inst_name(inst)
		var lv_before = int(b.levels.get(inst.uid, -1))
		if lv_before >= 0 and int(inst.level) > lv_before:
			lines.append("[color=gold]%s %s (ระดับ %d)[/color]" % [name, "สร้างเสร็จ" if lv_before == 0 else "อัปเกรดเสร็จ", int(inst.level)])
		elif not inst.site.is_empty():
			var now = float(inst.site.work) / maxf(1.0, float(inst.site.required))
			var was = float(b.sites.get(inst.uid, 0.0))
			lines.append("ไซต์%s คืบหน้า %d%% → %d%%%s" % [name, int(was * 100), int(now * 100), "  (ไม่มีคนสร้าง!)" if now <= was else ""])
	# ศึกษาวิชา
	for d in b.study:
		var st: Array = b.study[d]
		if d.learned_skills.has(st[0]):
			lines.append("[color=cyan]%s ศึกษาจนสำเร็จวิชา %s[/color]" % [d.disciple_name, st[0]])
		elif d.study_skill == st[0]:
			lines.append("%s ศึกษา %s %d%% → %d%%" % [d.disciple_name, st[0], int(st[1]), int(d.study_progress)])
	# วิชาใหม่ในหอตำรา
	var new_skills = sect.library_skills.filter(func(s): return not b.library.has(s))
	if not new_skills.is_empty(): lines.append("[color=cyan]วิชาใหม่เข้าหอตำรา: %s[/color]" % ", ".join(new_skills))
	var dp = sect.get_active_disciples().size() - int(b.people)
	if dp != 0: lines.append("จำนวนศิษย์ %+d (ตอนนี้ %d คน)" % [dp, sect.get_active_disciples().size()])
	# เหตุการณ์ที่บันทึกระหว่างข้าม (ตัดสีออกไว้แสดงในรายงาน)
	var log: Array[String] = []
	var start = maxi(0, sect.event_log.size() - 20) if b.log_tail != null else 0
	if b.log_tail != null:
		for i in range(sect.event_log.size() - 1, -1, -1):
			if is_same(sect.event_log[i], b.log_tail):
				start = i + 1
				break
	for i in range(start, sect.event_log.size()):
		log.append(str(sect.event_log[i].text))
	return { "lines": lines, "log": log, "stopped": stopped }

static func _phase_name(p: int) -> String:
	return ["เช้า", "บ่าย", "ค่ำ"][clampi(p, 0, 2)]
