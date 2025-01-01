extends Node3D
class_name DemonGhost

@onready var tongue : DemonTongue = $DemonTongue
@onready var animation_player : AnimationPlayer = $AnimationPlayer

var _player_ref : Player

func _ready() -> void:
	_player_ref = get_parent() as Player

func hide_local_models():
	$Head.hide()
	$Hair.hide()
	$Pins.hide()


func attack():
	animation_player.play("attack")
