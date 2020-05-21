extends Node

onready var destructibleBox = preload("res://DestructibleBox.tscn")
onready var boxScript = preload("res://DestructibleBox.gd")
onready var player = preload("res://Player.tscn")
onready var playerScript = preload("res://Player.gd")
var boxTexture = preload("res://Sprites/Box/box.png")
const prefs = preload("res://Utils/constant.gd")

func spawn_player(pos, type):
	var p = player.instance()
	p.set_script(playerScript)
	p.add_to_group("Destroyable")
	p.add_to_group("Player")
	p.z_index = 3
	p.type = type
	p.position = pos
	self.add_child(p)

# Todo clean
func _ready():
	$GameTrack.play()
	for x in range(prefs.START_X, prefs.END_X):
		for y in range(prefs.START_Y, prefs.END_Y):
			if x%2 == 1 and y % 2 == 1:
				var box = destructibleBox.instance()
				box.z_index = 0
				box.get_node("Sprite").set_texture(boxTexture)
				box.add_to_group("Box")
				box.position = Vector2(x*prefs.CELL_SIZE, y*prefs.CELL_SIZE) + Vector2(prefs.CELL_SIZE/2, prefs.CELL_SIZE)
				var root = get_tree().get_root()
				self.add_child(box)
			elif (abs(x-prefs.START_X)<=1 or abs(x-(prefs.END_X-1))<=1) \
				and (abs(y-prefs.START_Y)<=1 or abs(y-(prefs.END_Y-1))<=1):
				continue
			elif randi()%3+1 != 2:
				var box = destructibleBox.instance()
				box.set_script(boxScript)
				box.z_index = 0
				box.add_to_group("Destroyable")
				box.add_to_group("Box")
				box.position = Vector2(x*prefs.CELL_SIZE, y*prefs.CELL_SIZE)+ Vector2(prefs.CELL_SIZE/2, prefs.CELL_SIZE)
				self.add_child(box)
	# Players
	self.spawn_player(Vector2(prefs.START_X * prefs.CELL_SIZE, prefs.START_Y * prefs.CELL_SIZE) + Vector2(30, 30), "")
	self.spawn_player(Vector2(prefs.START_X * prefs.CELL_SIZE, prefs.END_Y * prefs.CELL_SIZE) + Vector2(30, -30), "Red_")
	self.spawn_player(Vector2(prefs.END_X * prefs.CELL_SIZE, prefs.START_Y * prefs.CELL_SIZE) + Vector2(-30, 30), "Dark_")
	self.spawn_player(Vector2(prefs.END_X * prefs.CELL_SIZE, prefs.END_Y * prefs.CELL_SIZE) + Vector2(-30, -30), "Pink_")