class_name InputHandler
extends Node

signal cell_selected(cell: Vector2i)
signal cell_hovered(cell: Vector2i)
signal cell_cancelled(cell: Vector2i)

var _reference_layer: TileMapLayer = null
var _last_hovered_cell: Vector2i = Vector2i(-999,999)

#func _input_error(event: String, expected: ) -> void:
	#push_error("BattleManager: %s called in wrong state. Expected %s, got %s" % [
		#func_name,
		#BattleState.keys()[expected],
		#BattleState.keys()[current_state]
	#])

func setup(reference_layer: TileMapLayer) -> void:
	_reference_layer = reference_layer

func _unhandled_input(event: InputEvent) -> void:
	if _reference_layer == null:
		return
	if event is InputEventMouseMotion:
		var cell = _get_cell_under_mouse()
		if cell != _last_hovered_cell:
			_last_hovered_cell = cell
			#emit_signal("cell hovered", cell)
	if event is InputEventMouseButton:
		if event.is_action_pressed("menu_select"):
			var cell = _get_cell_under_mouse()
			emit_signal("cell_selected", cell)
		if event.is_action_pressed("menu_cancel"):
			emit_signal("cell_cancelled")

func _get_cell_under_mouse() -> Vector2i:
	var mouse_pos = _reference_layer.get_global_mouse_position();
	#print("mouse pos: ", mouse_pos);
	var local_pos = _reference_layer.to_local(mouse_pos);
	#print("local pos: " ,local_pos)
	var local_to_map = _reference_layer.local_to_map(local_pos);
	return local_to_map;

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
