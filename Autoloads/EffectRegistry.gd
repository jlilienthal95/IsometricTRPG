# EffectRegistry.gd
extends Node

const HANDLERS_PATH := "res://Resources/Effects/Handlers/"

var _handlers: Dictionary = {}

func _ready() -> void:
	_autoload_handlers()

# EffectRegistry.gd
func _autoload_handlers() -> void:
	var dir = DirAccess.open(HANDLERS_PATH)
	if dir == null:
		push_error("EffectRegistry: could not open handlers directory")
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".gd"):
			var script = load(HANDLERS_PATH + file_name)
			var instance = script.new()
			var effect_id = instance.get_effect_id()
			if effect_id != EffectId.Id.NONE:
				_handlers[effect_id] = instance
		file_name = dir.get_next()
	dir.list_dir_end()

	_assert_full_coverage()

func _assert_full_coverage() -> void:
	for id in EffectId.Id.values():
		if id == EffectId.Id.NONE:
			continue
		if not _handlers.has(id):
			push_warning("EffectRegistry: no handler registered for effect_id " + EffectId.Id.keys()[id])

func get_handler(effect_id: EffectId.Id) -> EffectHandler:
	return _handlers.get(effect_id, null)
