@tool
extends EditorScript

# Runs all registry/list generators in sequence.
# Open this script and run it (Ctrl+Shift+X) to regenerate everything at once.

const GENERATORS: Array[GDScript] = [
	preload("res://Tools/GenerateJobRegistry.gd"),
	preload("res://Tools/GenerateAbilityRegistry.gd"),
	preload("res://Tools/GenerateEffectRegistry.gd"),
	preload("res://Tools/GenerateEquipmentRegistry.gd"),
	preload("res://Tools/GenerateConsiderationsList.gd"),
]

func _run() -> void:
	print("=== Running all generators ===")
	for script in GENERATORS:
		var generator = script.new()
		generator._run()
	print("=== All generators complete ===")
