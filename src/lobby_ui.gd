extends Control
class_name LobbyUI

@onready var address_edit : TextEdit = $VBoxContainer/TextEdit

@onready var player_name_edit : TextEdit = $VBoxContainer2/NameTextEdit
@onready var color_choices := $VBoxContainer2/GridContainer.get_children()
var picked_color : Color

var default_names = [
	"Oribon",
	"Elad",
	"Mannah",
	"Cupmang",
	"Gojira",
	"Darth Bonsuke"
]

var default_colors = [
	Color.RED,
	Color.BLUE,
	Color.GREEN,
	Color.YELLOW,
	Color.DEEP_PINK,
	Color.TEAL,
	Color.ORANGE
]

func _ready() -> void:
	player_name_edit.text = default_names.pick_random()
	picked_color = color_choices.pick_random().color
	for color_rect in color_choices:
		color_rect.gui_input.connect(on_color_rect_input.bind(color_rect.color))
	
	# Auto run on arguments
	var args = OS.get_cmdline_args()
	var is_server = "--server" in args
	if is_server:
		_on_host_button_pressed()

# On clicking a color choice
func on_color_rect_input(event, color):
	var click_event = event as InputEventMouseButton
	if click_event:
		if click_event.pressed:
			picked_color = color


func _on_host_button_pressed() -> void:
	Network.create_game()
	hide()


func _on_join_button_pressed() -> void:
	# TODO Validate
	# Update player information
	Network.player_info.name = player_name_edit.text
	Network.player_info.color = picked_color
	
	Network.join_game(address_edit.text)
	hide()
