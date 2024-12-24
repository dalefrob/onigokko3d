extends CharacterBody3D
class_name Player

var peer_id = 0

@export var _player_info = Network.player_info:
	get: return _player_info
	set(value): 
		_player_info = value

var player_name : String:
	get: return _player_info.name

# Sprite rects
@export var player_costume : CostumeResource = preload("res://costumes/default_player.tres")
@export var demon_costume : CostumeResource = preload("res://costumes/default_demon.tres")

var costume : CostumeResource:
	get: return demon_costume if demon else player_costume

# Children nodes
@onready var sprite : Sprite3D = $Sprite3D
@onready var head : Node3D = $Head
@onready var camera : Camera3D = $Head/Camera3D
@onready var namelabel : Label3D = $Label3D
@onready var hitbox : Area3D = $Hitbox
@onready var immune_timer : Timer = $ImmuneTimer

# Movements
var speed = 5.0
var JUMP_VELOCITY = 4.5

# Attributes
@export var tag_immune = false:
	set(value):
		tag_immune = value
		if value == true:
			immune_timer.start(3)


@export var demon : bool = false:
	get: return demon
	set(value):
		demon = value
		if demon: _setup_demon()
		else: _setup_runner()


func _setup_runner():
	namelabel.text = _player_info.name
	namelabel.modulate = Color.WHITE
	sprite.modulate = _player_info.color
	speed = 4.8


func _setup_demon():
	namelabel.text = "DEMON"
	namelabel.modulate = Color.DEEP_PINK
	sprite.modulate = Color.WHITE
	speed = 5.0

func _ready() -> void:
	if !is_multiplayer_authority():
		set_physics_process(false)
		return
	
	# Code beyond here is local
	_setup_runner()
	camera.make_current()


func _process(delta: float) -> void:
	# Update the sprites of all the other players
	update_sprite()


func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		jump.rpc()

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("strafe_left", "strafe_right", "move_forward", "move_backward")
	var direction := (head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()

@rpc("authority", "call_local", "unreliable")
func jump():
	velocity.y = JUMP_VELOCITY


func _input(event: InputEvent) -> void:
	# ESC
	var key_event = event as InputEventKey
	if key_event:
		if key_event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Click events
	var click_event = event as InputEventMouseButton
	if click_event:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Motion
	var motion_event = event as InputEventMouseMotion
	if motion_event:
		head.rotate_y(-motion_event.relative.x * 0.003)


func update_sprite():
	# set the sprite direction based on the way the player is looking
	var curr_camera = get_viewport().get_camera_3d()
	var dot_a : float = curr_camera.global_basis.z.dot(head.global_basis.z)
	var cross_a : Vector3 = curr_camera.global_basis.z.cross(head.global_basis.z)
	var angle_deg = rad_to_deg(acos(dot_a))
	# Set the texture
	sprite.texture = costume.texture
	sprite.position.y = 0.5 if demon else 0 # Raise demon sprite a little
	# 0 is facing same way - back sprite
	if angle_deg <= 60:
		sprite.region_rect = costume.back_rect
	# 180 is facing opposite way - front sprite
	elif angle_deg >= 120:
		sprite.region_rect = costume.front_rect
	else:
		# left of right
		sprite.region_rect = costume.right_rect
		if cross_a.y > 0:
			sprite.flip_h = true
		else:
			sprite.flip_h = false


func _on_hitbox_body_entered(body: Node3D) -> void:
	var player = body as Player
	if player != self:
		if demon and is_multiplayer_authority():
			if player.tag_immune: # Can't tag immune
				return
			var game = get_tree().get_first_node_in_group("game")
			game.rpc_id(1, "on_demon_touched_player", player.peer_id)
		


func _on_immune_timer_timeout() -> void:
	tag_immune = false
