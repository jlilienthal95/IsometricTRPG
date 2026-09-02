class_name Cursor
extends Node2D

# Emitted whenever the cursor settles on a NEW grid cell. The cursor is the
# authority on "what the player is pointing at" — CharacterInfo listens to this
# rather than the raw mouse cell, so freezing the cursor freezes the panel with
# it instead of following the mouse to whatever it drifts over.
signal cell_changed(cell: Vector3i)

@onready var _cursor: AnimatedSprite2D = $CursorSprite

var is_visible: bool = false
var _is_frozen: bool = false

# the grid cell the cursor currently sits on. Sentinel = "nowhere yet", so the
# first real placement always counts as a change and emits.
var cell: Vector3i = Vector3i(999, 999, 999)

# initializes the cursor with its sprite node reference
func setup() -> void:
	is_visible = _cursor.visible

# moves the cursor to the given world position / grid cell, announcing the new
# cell if it actually changed
func move_cursor(destination: Vector2, target_cell: Vector3i) -> void:
	global_position = destination
	if target_cell != cell:
		cell = target_cell
		cell_changed.emit(cell)

func hide_cursor() -> void:
	if is_visible:
		_cursor.visible = false
		is_visible = false

func show_cursor() -> void:
	if not is_visible:
		_cursor.visible = true
		is_visible = true

func freeze_cursor() -> void:
	if _is_frozen:
		return
	_is_frozen = true

func unfreeze_cursor() -> void:
	if not _is_frozen:
		return
	_is_frozen = false
	
func get_is_frozen() -> bool:
	return _is_frozen
