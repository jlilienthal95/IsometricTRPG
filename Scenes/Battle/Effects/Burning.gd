extends Node2D
@onready var sprite: AnimatedSprite2D = $"."
@onready var area: Area2D = $Area2D

const NORMAL_ALPHA: float = 1.0
const OCCUPIED_ALPHA: float = 0.7

var _occupant_count: int = 0
