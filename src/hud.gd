extends Control
class_name HUD

@onready var messagebox : RichTextLabel = $MessageBox

func show_message(bbcode_message):
	messagebox.append_text(bbcode_message + "\n")
