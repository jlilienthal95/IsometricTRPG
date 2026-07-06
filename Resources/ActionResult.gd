class_name ActionResult
extends RefCounted

var damage: int = 0
var is_critical: bool = false
var is_miss: bool = false
var status_effects: Array = []
var element: int = 0

static func create(damage: int, is_miss: bool, is_critical: bool = false, element: int = 0) -> ActionResult:
	var result = ActionResult.new()
	result.damage = damage
	result.is_miss = is_miss
	result.is_critical = is_critical
	result.element = element
	return result
