extends RefCounted
class_name AnimalDB

## ข้อมูลสัตว์ในอาณาเขต (ดู AnimalSys) — แต่ละชนิดมี behavior ต่างกัน
## hp, speed = ช่อง/รอบคิด (รอบคิดทุก AnimalSys.UPDATE_TICKS tick)
## herd/pack = ขนาดกลุ่มที่เกิดพร้อมกัน, fire_affinity = ชอบอยู่ใกล้ไฟ (0-1), graze = กินหญ้าได้ต่อรอบ
## flee = ระยะที่เห็นหมาป่าแล้ววิ่งหนี, produce_food = เสบียงต่อวันเมื่อเป็นสัตว์เลี้ยง, value = มูลค่าทรัพย์สิน
## predator = ล่าสัตว์อื่น, fear_fire = กลัวไฟ, forest = เดินในป่าได้, spawn_target = จำนวนที่ระบบพยายามรักษาไว้บนแผนที่

const SPECIES = {
	"cow": {
		"name": "วัว", "hp": 30.0, "speed": 0.45, "herd": [3, 5], "fire_affinity": 0.9, "graze": 0.16, "flee": 8.0,
		"produce_food": 2, "value": 120, "forest": false, "spawn_target": 8, "tame_days": 3.0,
		"desc": "กินหญ้า เคี้ยวเอื้อง ชอบแสงและความอบอุ่นจากไฟยามค่ำ เลี้ยงด้วยคำสั่งจับมาเลี้ยง ให้นมทุกวัน และช่วยให้แปลงเกษตรใกล้ๆ ได้ผลดี",
		"meat": 30, "hide": 1, "bounty": 0,
	},
	"pig": {
		"name": "หมู", "hp": 25.0, "speed": 0.4, "herd": [2, 4], "fire_affinity": 0.5, "graze": 0.14, "flee": 7.0,
		"produce_food": 0, "value": 80, "forest": false, "spawn_target": 6, "tame_days": 4.0,
		"desc": "ขุดดินหารากไม้ ชอบเกลือกโคลน ชอบไออุ่นจากไฟ สั่งล่าหรือใช้คำสั่งจับมาเลี้ยงได้",
		"meat": 24, "hide": 1, "bounty": 0,
	},
	"chicken": {
		"name": "ไก่", "hp": 8.0, "speed": 0.8, "herd": [3, 6], "fire_affinity": 0.7, "graze": 0.1, "flee": 10.0,
		"produce_food": 1, "value": 25, "forest": true, "spawn_target": 12, "tame_days": 2.0,
		"desc": "ตัวเล็ก คุ้ยเขี่ยหาเมล็ดพืช ตกใจวิ่งหนีเวลาคนเข้าใกล้ ชอบแสงไฟยามค่ำ เลี้ยงด้วยคำสั่งจับมาเลี้ยงแล้วออกไข่ทุกวัน",
		"meat": 4, "hide": 0, "bounty": 0,
	},
	"wolf": {
		"name": "หมาป่า", "hp": 40.0, "speed": 1.0, "pack": [2, 3], "fire_affinity": 0.0, "predator": true, "fear_fire": 1.0, "flee": 0.0,
		"produce_food": 0, "value": 0, "forest": true, "spawn_target": 0, "tame_days": 0.0,
		"desc": "ออกล่าเป็นฝูงโดยเฉพาะยามค่ำ เลือกเหยื่ออ่อนแอที่อยู่ไกลไฟ กลัวไฟและหอยามเว้นแต่หิวจัด",
		"meat": 0, "hide": 1, "bounty": 25,
	},
}
