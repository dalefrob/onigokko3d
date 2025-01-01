extends CharacterBody3D
class_name Player

const MAX_RUNNER_SPEED = 3.5
const MAX_SPRINT_SPEED = 7.0
const MAX_DEMON_SPEED = 3.0

var _game_ref : Game

# Client only vars
@export var sync_position : Vector3
@export var sync_rotation : Vector3

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

@onready var player_skin = $PlayerSkin
@onready var demon_skin = $DemonSkin

@onready var head : Node3D = $Head
@onready var camera : Camera3D = $Head/Camera3D
@onready var namelabel : Label3D = $Label3D
@onready var hitbox : Area3D = $Hitbox

@onready var immune_timer : Timer = $ImmuneTimer
@onready var demon_tongue := $Head/DemonTongue

@onready var hud : HUD = $HUD

# Vars
var energy = 100.0
var speed = 5.0
var jump_velocity = 4.5

@export var current_anim = "Idle"

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
	if is_multiplayer_authority():
		hud.energy_bar.show()
		
	demon_skin.hide()
	player_skin.show()
	
	namelabel.show()
	namelabel.text = _player_info.name
	namelabel.modulate = Color.WHITE
	sprite.modulate = _player_info.color


func _setup_demon():
	demon_skin.show()
	player_skin.hide()
	
	hud.energy_bar.hide()
	namelabel.hide()
	sprite.modulate = Color.WHITE


func _ready() -> void:
	_game_ref = get_tree().get_first_node_in_group("game")
	
	if is_multiplayer_authority():
		_game_ref.game_announcement.connect(on_game_announcement)
		hud.show()
		# Hide local models
		player_skin.hide_local_models()
		demon_skin.hide_local_models()
		camera.make_current()
	
	_setup_runner()



#region UICallbacks
func on_game_announcement(message : String):
	hud.show_message(message)
#endregion


func _input(event: InputEvent) -> void:
	if !is_multiplayer_authority():
		return
	
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
		rotate_y(-motion_event.relative.x * 0.003)



func _process(delta: float) -> void:
	# Update the sprites of all the other players
	update_sprite()


func _physics_process(delta: float) -> void:
	player_skin.animation_player.play(current_anim, 0.5)
	
	if !is_multiplayer_authority():
		interpolate_movement(delta)
		return
	
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		jump.rpc()
	
	speed = MAX_DEMON_SPEED if demon else MAX_RUNNER_SPEED
	
	# Handle skills.
	if Input.is_action_pressed("primary") and !demon:
		if energy > 1:
			sprint()
	elif Input.is_action_just_pressed("primary") and demon:
		shoot.rpc()
	else:
		if energy < 100.0:
			energy += 0.25
	
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("strafe_left", "strafe_right", "move_forward", "move_backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()
	
	if is_on_floor():
		if velocity.length() > 0:
			current_anim = "Run"
		else:
			current_anim = "Idle"
	else:
		if velocity.y < 0:
			current_anim = "Fall"
	
	# Update sync values to send
	sync_position = position
	sync_rotation = rotation


# Move towards the last position
func interpolate_movement(delta : float):
	position = position.move_toward(sync_position, delta * speed * 2)
	var hrot : Vector3 = rotation
	hrot.y = lerp_angle(hrot.y, sync_rotation.y, delta * speed * 2)
	hrot.x = sync_rotation.x
	hrot.z = sync_rotation.z
	rotation = hrot


@rpc("authority", "call_local", "unreliable")
func jump():
	velocity.y = jump_velocity
	current_anim = "Jump"


@rpc("authority", "call_local", "reliable")
func shoot():
	if demon:
		demon_skin.attack()


func sprint():
	if energy > 0:
		energy -= 1
		speed = MAX_SPRINT_SPEED


func update_sprite():
	sprite.shaded = !demon_tongue.is_attacking
		
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
