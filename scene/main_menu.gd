extends Control

func _ready() -> void:
	# เชื่อมต่อปุ่มกับฟังก์ชัน
	%TestSectButton.pressed.connect(_on_test_sect_pressed)
	%WorldMapButton.pressed.connect(_on_world_map_pressed)
	%BattleTestButton.pressed.connect(_on_battle_test_pressed)
	%QuitButton.pressed.connect(_on_quit_pressed)

func _on_test_sect_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/test_sect.tscn")

func _on_world_map_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/map/world_map.tscn")

func _on_battle_test_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/battle_test.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
