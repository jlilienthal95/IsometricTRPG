extends Node2D

var _cursor: Sprite2D = null
var is_visible: bool = false

# initializes the cursor with its sprite node reference
func setup(cursor: Sprite2D) -> void:
	_cursor = cursor
	is_visible = cursor.visible

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
