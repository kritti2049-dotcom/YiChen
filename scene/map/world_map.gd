extends Control

@onready var info_panel = $InfoPanel
@onready var location_name_label = $InfoPanel/VBoxContainer/NameLabel
@onready var location_desc_label = $InfoPanel/VBoxContainer/DescLabel
@onready var travel_time_label = $InfoPanel/VBoxContainer/TravelTimeLabel

var current_selected_location: LocationData

func _ready() -> void:
	# ปิดหน้าต่างข้อมูลไว้ก่อนตอนเริ่มเกม
	if info_panel:
		info_panel.hide()
	
	# ผูกปุ่มจาก UI
	if has_node("MapContainer/BtnTown"):
		var btn = $MapContainer/BtnTown
		# สร้างข้อมูลสถานที่จำลองเพื่อทดสอบ
		var town_data = LocationData.new()
		town_data.location_name = "เมืองเริ่มต้น"
		town_data.description = "เมืองเล็กๆ สำหรับผู้เริ่มต้นฝึกตน"
		town_data.travel_days = 2
		town_data.is_unlocked = true
		btn.pressed.connect(_on_location_clicked.bind(town_data))
		
	if has_node("InfoPanel/VBoxContainer/DispatchButton"):
		$InfoPanel/VBoxContainer/DispatchButton.pressed.connect(_on_dispatch_button_pressed)
		
	if has_node("BackButton"):
		$BackButton.pressed.connect(_on_back_button_pressed)

## ฟังก์ชันนี้จะถูกเรียกเมื่อผู้เล่นคลิกปุ่มสถานที่บนแผนที่
func _on_location_clicked(loc_data: LocationData) -> void:
	if not loc_data or not loc_data.is_unlocked:
		print("สถานที่นี้ยังไม่ปลดล็อก!")
		return
		
	current_selected_location = loc_data
	
	# อัปเดต UI หน้าต่างข้อมูล
	if info_panel:
		location_name_label.text = loc_data.location_name
		location_desc_label.text = loc_data.description
		travel_time_label.text = "ใช้เวลาเดินทาง: %d วัน" % loc_data.travel_days
		info_panel.show()

## ฟังก์ชันสำหรับปุ่ม "ส่งศิษย์" ภายใน InfoPanel
func _on_dispatch_button_pressed() -> void:
	if current_selected_location:
		print("กำลังส่งศิษย์ไปยัง...", current_selected_location.location_name)
		# TODO: เปิดหน้าต่างเลือกศิษย์เพื่อส่งไปทำภารกิจ

func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/main_menu.tscn")
