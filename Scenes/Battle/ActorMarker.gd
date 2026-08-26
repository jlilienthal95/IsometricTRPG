@tool
class_name ActorMarker
extends Node2D

@export var actor_data: BattleActorData = null:
	set(value):
		actor_data = value
		_update_preview()

@export var actor_type: BattleActorData.Type = BattleActorData.Type.PLAYER  # ignored for objects
@onready var preview_sprite: Sprite2D = $PreviewSprite

func _ready() -> void:
	if Engine.is_editor_hint():
		_update_preview()
	else:
		preview_sprite.visible = false  # hide preview at runtime

func _update_preview() -> void:
	if not Engine.is_editor_hint():
		return
	if preview_sprite == null:
		return
	if actor_data is UnitData and actor_data.job != null and actor_data.job.portrait != null:
		preview_sprite.texture = actor_data.job.portrait
	else:
		preview_sprite.texture = null
