extends Node3D
class_name PlayerSkin

@onready var animation_player : AnimationPlayer = $AnimationPlayer

func hide_local_models():
	$Armature/Skeleton3D/body.hide()
