@tool
class_name ActorMarker
extends Node2D

@export var actor_data: BattleActorData = null:
	set(value):
		actor_data = value
		_preview_dirty = true

@export_tool_button("Refresh Preview")
var refresh_preview_action: Callable = _refresh_preview


var _preview_instance: Node2D = null
var _previewed_scene: PackedScene = null
var _preview_dirty := true


func _ready() -> void:
	if Engine.is_editor_hint():
		set_notify_transform(true)
		_preview_dirty = true
		_update_preview()


func _notification(what: int) -> void:
	if not Engine.is_editor_hint():
		return

	if what == NOTIFICATION_TRANSFORM_CHANGED:
		_update_preview()

func _refresh_preview() -> void:
	print("[ActorMarker] Manual preview refresh")
	_preview_dirty = true
	_update_preview()

func _update_preview() -> void:
	if not Engine.is_editor_hint():
		return

	if actor_data == null:
		_clear_preview()
		return

	var scene: PackedScene = null

	if actor_data is BattleObjectData:
		scene = actor_data.scene

	elif actor_data is UnitData:
		if actor_data.scene_override != null:
			scene = actor_data.scene_override
		else:
			print("job: ", actor_data.job.job_name)
			scene = actor_data.job.scene

	else:
		_clear_preview()
		return

	if scene == null:
		print("[ActorMarker] ActorData has no scene")
		_clear_preview()
		return

	if _preview_instance != null and _previewed_scene == scene:
		return

	_create_preview(scene)

func _create_preview(scene: PackedScene) -> void:
	_clear_preview()

	print("[ActorMarker] Creating preview: ", scene.resource_path)

	_preview_instance = scene.instantiate()

	add_child(_preview_instance)

	_preview_instance.position = Vector2.ZERO
	_preview_instance.z_index = 1000
	_preview_instance.z_as_relative = false

	if _preview_instance == null:
		print("[ActorMarker] ERROR: Could not instantiate preview")
		return

	_previewed_scene = scene

	add_child(_preview_instance)
	_preview_instance.position = Vector2.ZERO

	

func _clear_preview() -> void:
	if _preview_instance != null:
		_preview_instance.queue_free()

	_preview_instance = null
	_previewed_scene = null

func _force_preview_to_front(node: Node) -> void:
	if node is CanvasItem:
		node.z_as_relative = false
		node.z_index = 1000

	for child in node.get_children():
		_force_preview_to_front(child)
