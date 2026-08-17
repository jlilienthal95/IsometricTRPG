class_name HoverButton
extends Button

signal focused(button: Button)
signal unfocused

func _ready() -> void:
	mouse_entered.connect(func(): focused.emit(self))
	mouse_exited.connect(func(): unfocused.emit())
	focus_entered.connect(func(): focused.emit(self))
	focus_exited.connect(func(): focused.emit())
