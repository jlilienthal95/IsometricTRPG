class_name HoverButton
extends Button

signal focused(button: Button)
signal unfocused

@onready var action_label: Label = $ActionLabel

func _ready() -> void:
	mouse_entered.connect(func(): focused.emit(self))
	mouse_exited.connect(func(): unfocused.emit())
	focus_entered.connect(func(): focused.emit(self))
	focus_exited.connect(func(): unfocused.emit())
