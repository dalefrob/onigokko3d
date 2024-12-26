extends Control
class_name HUD

@onready var messagebox : RichTextLabel = $MessageBox
@onready var energy_bar : TextureProgressBar = $EnergyBar

@export_node_path("Player") var player_node : NodePath
@onready var _player_ref = get_node(player_node)

func show_message(bbcode_message):
	messagebox.append_text(bbcode_message + "\n")

func _process(delta: float) -> void:
	energy_bar.value = _player_ref.energy
