class_name TileEvent
extends RefCounted

# A single thing that happened ON a tile, handed to every effect present on
# that tile via EffectHandler.on_tile_event. Deliberately event-shaped rather
# than actor-shaped: an ability striking an occupied tile and an arrow landing
# on an empty one both flow through the same hook, so effects like SLIPPERY
# (slide the occupant) or MAGNETIC (grab the projectile) each decide what a
# given event means to them.

enum Type {
	NONE,
	ABILITY_HIT,		# an ability's blow landed on the actor occupying this tile
	PROJECTILE_LANDED,	# a projectile arrived at this tile (occupied or not)
}

var type: Type = Type.NONE
var caster: Unit = null		# the source actor — origin of knockback/attribution

static func create(type: Type, caster: Unit) -> TileEvent:
	var event = TileEvent.new()
	event.type = type
	event.caster = caster
	return event
