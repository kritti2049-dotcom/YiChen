extends Resource
class_name TileData

@export var tile_name: String = "Plains"
@export var texture: Texture2D
@export var walkable: bool = true
@export var move_cost: int = 1  ## เดินผ่าน tile นี้เสีย movement point เท่าไหร่
@export var defense_bonus: int = 0  ## บาง tile ให้ bonus defense (เช่น ป่า, ภูเขา)

## สำหรับ 4X: resource ที่ผลิตได้ถ้ายึดครอง tile นี้ (เช่น {"food": 2, "gold": 1})
@export var yields: Dictionary = {}
