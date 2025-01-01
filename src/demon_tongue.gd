extends Node3D
class_name DemonTongue

#region StateMachine
const STATE_IDLE = "idle"
const STATE_EXTEND = "extend"
const STATE_RETRACT = "retract"

var previous_state = STATE_IDLE
var current_state = STATE_IDLE

signal state_changed

func change_state(new_state):
	previous_state = current_state
	var exit_func = current_state + "_exit"
	if has_method(exit_func):
		call(exit_func)
	# Set new state
	current_state = new_state
	var enter_func = new_state + "_enter"
	if has_method(enter_func):
		call(enter_func)
	state_changed.emit()
#endregion

@onready var sprite : Sprite3D = $BallSprite3D

@export var tongue_length = 2.0
@export var tongue_speed = 2.0

var _t : float = 0.0
var _tongue_extension_vector : Vector3

var is_attacking : bool:
	get: return current_state != STATE_IDLE


func _ready() -> void:
	if is_multiplayer_authority():
		sprite.modulate.a = 0.5


func shoot():
	_tongue_extension_vector = Vector3(0, 0, tongue_length)
	change_state(STATE_EXTEND)


func _process(delta: float) -> void:
	if has_method(current_state):
		call(current_state, delta)


# State functions

func idle(delta):
	visible = false

func extend_enter():
	sprite.position = Vector3.ZERO
	visible = true

func extend(delta):
	_t += delta * tongue_speed
	sprite.position = sprite.position.lerp(-_tongue_extension_vector, _t)
	if _t > 1:
		_t = 0
		change_state(STATE_RETRACT)

func retract(delta):
	_t += delta * tongue_speed * 2
	sprite.position = sprite.position.lerp(Vector3.ZERO, _t)
	if _t > 1:
		_t = 0
		change_state(STATE_IDLE)


# Signal callbacks
func _on_hitbox_body_entered(body: Node3D) -> void:
	var player = body as Player
	# Cancel conditions
	if !player: return
	if player.get_multiplayer_authority() == get_multiplayer_authority(): return # Own demon tongue
	if player.demon: return
	if player.tag_immune: return
	# Visual cue for success
	#sprite.hide()
	# Notify server
	if is_multiplayer_authority():
		var game = get_tree().get_first_node_in_group("game")
		game.rpc_id(1, "on_demon_touched_player", player.peer_id)
