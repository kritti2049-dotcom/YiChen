extends Node2D

## Demo ที่เล่นได้ทันที ไม่ต้องต่อ node/resource ใดๆ เพิ่ม
## วิธีใช้: attach สคริปต์นี้เข้ากับ node "BattleTest" (ลบ script battle_unit.gd
## ที่ผูกกับ HeroUnit/EnemyUnit ออกก่อนก็ได้ ไม่จำเป็นต้องใช้ตอนนี้)
## กด Run (F5) แล้วกดปุ่มบนจอเพื่อโจมตีสลับกันไปมา

var hero_hp: int = 100
var hero_max_hp: int = 100
var hero_attack: int = 15

var enemy_hp: int = 80
var enemy_max_hp: int = 80
var enemy_attack: int = 10

var is_hero_turn: bool = true
var battle_over: bool = false

var hero_label: Label
var enemy_label: Label
var log_label: Label
var attack_button: Button

func _ready() -> void:
	# พื้นหลังกันจอดำมืดเกินไป
	var bg = ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.15)
	bg.size = Vector2(800, 600)
	add_child(bg)

	# กล่องตัวแทน Hero (สีฟ้า ฝั่งซ้าย)
	var hero_box = ColorRect.new()
	hero_box.color = Color(0.2, 0.5, 0.9)
	hero_box.size = Vector2(100, 100)
	hero_box.position = Vector2(150, 250)
	add_child(hero_box)

	# กล่องตัวแทน Enemy (สีแดง ฝั่งขวา)
	var enemy_box = ColorRect.new()
	enemy_box.color = Color(0.9, 0.3, 0.3)
	enemy_box.size = Vector2(100, 100)
	enemy_box.position = Vector2(550, 250)
	add_child(enemy_box)

	# ตัวหนังสือแสดง HP ของ Hero
	hero_label = Label.new()
	hero_label.position = Vector2(100, 200)
	hero_label.add_theme_font_size_override("font_size", 20)
	add_child(hero_label)

	# ตัวหนังสือแสดง HP ของ Enemy
	enemy_label = Label.new()
	enemy_label.position = Vector2(500, 200)
	enemy_label.add_theme_font_size_override("font_size", 20)
	add_child(enemy_label)

	# ข้อความ log บอกว่าเกิดอะไรขึ้น
	log_label = Label.new()
	log_label.position = Vector2(150, 400)
	log_label.add_theme_font_size_override("font_size", 18)
	log_label.text = "กดปุ่มด้านล่างเพื่อเริ่มต่อสู้"
	add_child(log_label)

	# ปุ่มโจมตี
	attack_button = Button.new()
	attack_button.text = "โจมตี!"
	attack_button.position = Vector2(320, 470)
	attack_button.size = Vector2(160, 50)
	attack_button.pressed.connect(_on_attack_pressed)
	add_child(attack_button)

	_update_labels()

func _on_attack_pressed() -> void:
	if battle_over:
		return

	if is_hero_turn:
		enemy_hp = max(0, enemy_hp - hero_attack)
		log_label.text = "Hero โจมตี Enemy! (-%d dmg)" % hero_attack
	else:
		hero_hp = max(0, hero_hp - enemy_attack)
		log_label.text = "Enemy โจมตี Hero! (-%d dmg)" % enemy_attack

	_update_labels()
	_check_battle_end()

	if not battle_over:
		is_hero_turn = not is_hero_turn
		# ให้ enemy โจมตีอัตโนมัติหลัง delay สั้นๆ ถ้าถึงตาศัตรู
		if not is_hero_turn:
			attack_button.disabled = true
			await get_tree().create_timer(0.6).timeout
			if not battle_over:
				_on_attack_pressed()
			attack_button.disabled = false

func _update_labels() -> void:
	hero_label.text = "Hero HP: %d / %d" % [hero_hp, hero_max_hp]
	enemy_label.text = "Enemy HP: %d / %d" % [enemy_hp, enemy_max_hp]

func _check_battle_end() -> void:
	if enemy_hp <= 0:
		log_label.text = "Hero ชนะ! 🎉"
		battle_over = true
		attack_button.disabled = true
	elif hero_hp <= 0:
		log_label.text = "Enemy ชนะ... กูแพ้"
		battle_over = true
		attack_button.disabled = true
