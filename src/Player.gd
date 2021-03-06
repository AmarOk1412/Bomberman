# BSD 3-Clause License
#
# Copyright (c) 2020, Sébastien Blin <sebastien.blin@enconn.fr>
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
#
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
#
# * Neither the name of the copyright holder nor the names of its
#   contributors may be used to endorse or promote products derived from
#   this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

extends KinematicBody2D
onready var bombPacked = preload("res://src/Bomb.tscn")
onready var bombScript = preload("res://src/Bomb.gd")
onready var anim = get_node("AnimationPlayer")
const prefs = preload("res://src/Utils/constant.gd")

# Player movement speed
var speed = 300
var bombs = 1
var radius = 2
var repelBombs = false
var pushBombs = false
var type = ""
var exploded = false
var finished = false

# Network
puppet var puppet_pos = Vector2()
puppet var puppet_motion = Vector2()

# Effects
var timerEffect = Timer.new()
enum Effect {
	None,
	Slow,
	Fast,
	Inverted,
	SmallBomb,
	Flu
}
var currentEffect = Effect.None
const EFFECT_DURATION = 15

enum Direction {
	Up,
	Down,
	Left,
	Right
}
var lastDir = Direction.Down
var playerName = ""

func _physics_process(delta):
	if exploded or finished:
		return
	# Get player input
	var direction: Vector2
	var motion: Vector2

	if is_network_master():
		if currentEffect == Effect.Inverted:
			if self.timerDetection and not self.timerDetection.is_stopped():
				direction = -1 * self.lastSwipe
			else:
				direction.x = Input.get_action_strength("ui_left") - Input.get_action_strength("ui_right")
				direction.y = Input.get_action_strength("ui_up") - Input.get_action_strength("ui_down")
			anim.flip_h = Input.is_action_pressed("ui_right") || lastDir == Direction.Left
		else:
			if self.timerDetection and not self.timerDetection.is_stopped():
				direction = self.lastSwipe
			else:
				direction.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
				direction.y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
			anim.flip_h = Input.is_action_pressed("ui_left") || lastDir == Direction.Left

		if currentEffect == Effect.Flu:
			rpc("drop", get_tree().get_network_unique_id())
		# If input is digital, normalize it for diagonal movement
		if abs(direction.x) == 1 and abs(direction.y) == 1:
			direction = direction.normalized()

		# Apply movement
		var playerSpeed = speed
		if currentEffect == Effect.Slow:
			playerSpeed = 100
		elif currentEffect == Effect.Fast:
			playerSpeed = speed * 10
		motion = direction * playerSpeed
		rset("puppet_motion", motion)
		rset("puppet_pos", position)
	else:
		position = puppet_pos
		motion = puppet_motion

	if motion.y > 0:
		lastDir = Direction.Down
		anim.play(type + "Down")
	elif motion.y < 0:
		lastDir = Direction.Up
		anim.play(type + "Up")
	elif motion.x > 0:
		lastDir = Direction.Right
		anim.play(type + "Right")
	elif motion.x < 0:
		lastDir = Direction.Left
		anim.play(type + "Right")
	elif lastDir == Direction.Down:
		anim.play(type + "Base")
	elif lastDir == Direction.Up:
		anim.play(type + "BaseRevert")
	else:
		anim.play(type + "Side")

	var movement = motion * delta
	move_and_collide(movement)
	if not is_network_master():
		puppet_pos = position # To avoid jitter

func push():
	if not self.pushBombs or self.finished:
		return
	var offsetVec = Vector2()
	if lastDir == Direction.Right:
		offsetVec = Vector2(120, 0)
	elif lastDir == Direction.Left:
		offsetVec = Vector2( -120, 0)
	elif lastDir == Direction.Up:
		offsetVec = Vector2(0, -120)
	elif lastDir == Direction.Down:
		offsetVec = Vector2(0, 120)
	var checkPos = self.position + offsetVec
	var root = get_tree().get_root()
	var tileMap = root.get_node("Game").get_node("Map")
	var tilePos = tileMap.world_to_map(checkPos)
	for bomb in get_tree().get_nodes_in_group("Bomb"):
		var bombPos = tileMap.world_to_map(bomb.get_position())
		if tilePos == bombPos:
			bomb.push(offsetVec*2)
			break

#################### Android

var swipeStart = Vector2()
var lastSwipe = Vector2()
var timerDetection = null

func set_swipe(direction):
	if not self.timerDetection:
		self.timerDetection = Timer.new()
	if self.timerDetection.is_stopped():
		self.timerDetection.start()
	print(direction)
	if abs(direction.x) < 0.1:
		direction.x = 0
	if abs(direction.y) < 0.1:
		direction.y = 0
	self.lastSwipe = direction.normalized()

func end_detection():
	if self.timerDetection:
		self.timerDetection.stop()

func _input(ev):
	if self.finished:
		return
	if is_network_master():
		if ev is InputEventScreenDrag:
			set_swipe(ev.relative)
		elif ev is InputEventScreenTouch:
			if not ev.pressed:
				end_detection()
		else:
			if Input.is_action_just_pressed("ui_accept"):
				rpc("drop", get_tree().get_network_unique_id())
			if Input.is_action_just_pressed("ui_second_action"):
				push()

sync func drop(id):
	if get_network_master() != id:
		return
	if self.bombs <= 0 or self.finished:
		return
	var root = get_tree().get_root()
	var tileMap = root.get_node("Game").get_node("Map")
	var tilePos = tileMap.world_to_map(self.position)
	for bomb in get_tree().get_nodes_in_group("Bomb"):
		var bombPos = tileMap.world_to_map(bomb.position)
		if tilePos == bombPos:
			return
	bombs -= 1
	var bomb = bombPacked.instance()
	bomb.set_script(bombScript)
	bomb.add_to_group("Destroyable")
	bomb.add_to_group("Bomb")
	bomb.z_index = 2
	bomb.from_player = self
	bomb.position = (tilePos * prefs.CELL_SIZE) + Vector2(prefs.CELL_SIZE/2, prefs.CELL_SIZE/2)
	var finalRadius = self.radius
	if self.currentEffect == Effect.SmallBomb:
		finalRadius = 1
	bomb.setRadius(finalRadius)
	tileMap.add_child(bomb)

func _ready():
	anim.play(type + "Base")

func explode():
	exploded = true
	anim.play("Blew")
	anim.connect("animation_finished", self, "queue_free")

func removeEffect():
	currentEffect = Effect.None

func near(bomb):
	if self.finished:
		return
	if self.repelBombs:
		if bomb.position.x - prefs.CELL_SIZE/2 > self.position.x:
			bomb.moveVector = Vector2(1,0)
		elif bomb.position.x + prefs.CELL_SIZE/2 < self.position.x:
			bomb.moveVector = Vector2(-1,0)
		elif bomb.position.y - prefs.CELL_SIZE/2 > self.position.y:
			bomb.moveVector = Vector2(0,1)
		elif bomb.position.y + prefs.CELL_SIZE/2 < self.position.y:
			bomb.moveVector = Vector2(0,-1)

func affect():
	if self.finished:
		return
	timerEffect.stop()
	# Note: random effect and avoid None
	currentEffect = Effect.values()[randi()%(Effect.size() - 1) + 1]
	timerEffect.connect("timeout", self, "removeEffect")
	add_child(timerEffect)
	timerEffect.start(EFFECT_DURATION)

func announce_push():
	if self.finished:
		return
	if is_network_master():
		push()

func announce_drop():
	if self.finished:
		return
	rpc("drop", get_tree().get_network_unique_id())