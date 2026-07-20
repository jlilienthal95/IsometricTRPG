class_name Cursor
extends Node2D

@onready var _cursor: AnimatedSprite2D = $CursorSprite

var is_visible: bool = false

# initializes the cursor with its sprite node reference
func setup() -> void:
	is_visible = _cursor.visible

# moves the cursor to the given world position
func move_cursor(destination: Vector2) -> void:
	global_position = destination

func hide_cursor() -> void:
	if is_visible:
		_cursor.visible = false
		is_visible = false

func show_cursor() -> void:
	if not is_visible:
		_cursor.visible = true
		is_visible = true
