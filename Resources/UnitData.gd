class_name UnitData
extends Resource

@export var unit_name: String = ""
@export var max_hp: int = 100
@export var current_hp: int = 100
@export var max_mp: int = 15
@export var current_mp: int = 15
@export var move_range: int = 3
@export var jump_height: int = 1  # max elevation difference for movement
@export var base_attack: int = 10  # max elevation difference for movement


# Elemental affinities — values are multipliers
# 1.0 = normal, 0.5 = resistant, 2.0 = weak, 0.0 = immune, -1.0 = absorbs
@export var elemental_affinities: Dictionary = {}  # Element: float
