extends Node2D

#@onready var cursor: Sprite2D = $CursorSprite;

var _cursor: Sprite2D = null

var is_visible = false

func setup(cursor: Sprite2D) -> void:
	_cursor = cursor
	is_visible = cursor.visible

func move_cursor(cell: Vector2i) -> void:
	_cursor.global_position = Vector2(cell)
	

func hide_cursor() -> void:
	if is_visible:
		_cursor.visible = false
		is_visible = false
	
func show_cursor() -> void:
	if not is_visible:
		_cursor.visible = true
		is_visible = true
