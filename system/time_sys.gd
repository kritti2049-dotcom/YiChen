extends RefCounted
class_name TimeSys

## ระบบเวลาในวัน: เช้า กลางวัน เย็น ค่ำ
## เวลาเดิน 1 ชั่วโมงในเกม ทุกๆ REAL_SECONDS_PER_HOUR วินาทีจริง ขณะอยู่หน้าสำนัก
## และหยุดที่ DAY_END (ดึกแล้ว ต้องกดข้ามวัน)

const DAY_START = 6.0
const DAY_END = 23.0
const REAL_SECONDS_PER_HOUR = 6.0

static func get_phase_name(hour: float) -> String:
	if hour < 11.0: return "ยามเช้า"
	if hour < 16.0: return "กลางวัน"
	if hour < 19.0: return "ยามเย็น"
	return "ยามค่ำ"

static func format_clock(hour: float) -> String:
	return "%02d:%02d" % [int(hour), int(fmod(hour, 1.0) * 60)]

## จุดสีอ้างอิงของแต่ละช่วงเวลา (hour, sky_top, sky_bottom, sun, ink, mist, overlay)
const KEYS = [
	[6.0, Color(0.55, 0.6, 0.75), Color(0.95, 0.75, 0.55), Color(1.0, 0.7, 0.4), Color(0.18, 0.17, 0.2), Color(1, 0.95, 0.9), Color(0.1, 0.05, 0.1, 0.1)],
	[11.0, Color(0.55, 0.7, 0.85), Color(0.9, 0.9, 0.85), Color(1.0, 0.95, 0.75), Color(0.15, 0.15, 0.15), Color(1, 1, 1), Color(0, 0, 0, 0.0)],
	[16.0, Color(0.5, 0.65, 0.8), Color(0.92, 0.88, 0.78), Color(1.0, 0.9, 0.65), Color(0.15, 0.14, 0.13), Color(1, 1, 0.95), Color(0, 0, 0, 0.0)],
	[18.5, Color(0.4, 0.3, 0.45), Color(0.95, 0.55, 0.3), Color(1.0, 0.5, 0.25), Color(0.16, 0.1, 0.1), Color(1, 0.8, 0.7), Color(0.2, 0.05, 0.0, 0.12)],
	[21.0, Color(0.06, 0.07, 0.15), Color(0.15, 0.17, 0.3), Color(0.9, 0.9, 1.0), Color(0.04, 0.04, 0.07), Color(0.6, 0.65, 0.8), Color(0.0, 0.02, 0.1, 0.3)],
	[23.0, Color(0.03, 0.03, 0.08), Color(0.08, 0.09, 0.18), Color(0.9, 0.9, 1.0), Color(0.02, 0.02, 0.04), Color(0.5, 0.55, 0.7), Color(0.0, 0.02, 0.1, 0.4)],
]

static func get_light(hour: float) -> Dictionary:
	var h = clamp(hour, KEYS[0][0], KEYS[-1][0])
	for i in range(KEYS.size() - 1):
		var a = KEYS[i]
		var b = KEYS[i + 1]
		if h <= b[0]:
			var t = (h - a[0]) / (b[0] - a[0])
			return {
				"sky_top": a[1].lerp(b[1], t),
				"sky_bottom": a[2].lerp(b[2], t),
				"sun": a[3].lerp(b[3], t),
				"ink": a[4].lerp(b[4], t),
				"mist": a[5].lerp(b[5], t),
				"overlay": a[6].lerp(b[6], t),
			}
	return get_light(KEYS[-1][0])
