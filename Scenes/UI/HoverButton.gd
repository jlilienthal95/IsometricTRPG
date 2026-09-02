class_name HoverButton
extends Button

signal focused(button: Button)
signal unfocused

# optional — not every HoverButton carries a hover label (e.g. the info-icon
# button in CharacterInfo has none), so look it up non-fatally instead of $
@onready var action_label: Label = get_node_or_null("ActionLabel")

func _ready() -> void:
	mouse_entered.connect(func(): focused.emit(self))
	mouse_exited.connect(func(): unfocused.emit())
	focus_entered.connect(func(): focused.emit(self))
	focus_exited.connect(func(): unfocused.emit())
