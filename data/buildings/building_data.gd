extends Resource
class_name BuildingData

## ข้อมูลอาคาร/สิ่งปลูกสร้างในสำนัก
## สร้างใหม่: คลิกขวาใน FileSystem > New Resource > BuildingData

@export var building_name: String = "อาคารใหม่"

@export_group("Cost & Requirements")
## ค่าใช้จ่ายในการสร้าง (เงิน)
@export var cost_money: int = 100
## ค่าใช้จ่ายในการสร้าง (เสบียง)
@export var cost_food: int = 50

@export_group("Effects & Function")
## ประเภทของ Effect อาคาร (เช่น "training_speed", "max_disciples", "resource_generation")
@export var effect_type: String = ""
## ค่าความแรงของ Effect
@export var effect_value: float = 0.0

## คำอธิบายอาคาร
@export_multiline var description: String = ""
