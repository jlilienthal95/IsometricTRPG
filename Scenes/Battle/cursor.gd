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
var _grid: BattleGrid = null
var _base_z: int = 0	# scene-authored z_index (terrain-level cursor)

# the grid cell the cursor currently sits on. Sentinel = "nowhere yet", so the
# first real placement always counts as a change and emits.
var cell: Vector3i = Vector3i(999, 999, 999)

# initializes the cursor with its sprite node reference and the grid (for the
# object-top z bump). _base_z captures the scene-authored terrain-level z_index.
func setup(grid: BattleGrid = null) -> void:
	is_visible = _cursor.visible
	_grid = grid
	_base_z = z_index

# moves the cursor to the given world position / grid cell, announcing the new
# cell if it actually changed
func move_cursor(destination: Vector2, target_cell: Vector3i) -> void:
	global_position = destination
	z_index = _cursor_z(target_cell)
	if target_cell != cell:
		cell = target_cell
		cell_changed.emit(cell)

# an object-top tile sits under an object drawn at UNOCCLUDED_ACTOR_Z_INDEX, so
# the cursor must clear that band (and the tile highlights above it) there;
# everywhere else it stays at its normal terrain-level z.
func _cursor_z(target_cell: Vector3i) -> int:
	if _grid != null:
		var tile := _grid.get_tile(target_cell)
		if tile != null and tile.is_object_top:
			# above the object (and its highlights) but below a unit standing there
			return Constants.UNOCCLUDED_ACTOR_Z_INDEX + 4
	return _base_z

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
