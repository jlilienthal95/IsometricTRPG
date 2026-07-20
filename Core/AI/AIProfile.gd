class_name AIProfile
extends Resource

# resource: personality weights + intelligence rank
enum Intelligence { DUMB, NORMAL, SMART }

@export var intelligence: Intelligence = Intelligence.NORMAL
@export var weights: Dictionary = {
	"expected_damage": 1.0,
	"kill_potential": 2.0,
	"target_weakness": 0.0,   # 0 disables — early enemies don't see weaknesses
	"destination_safety": 1.0,
	"effect_synergy": 0.0,    # tier c stays dormant until late-game profiles
	"distance_to_threat": 0.5,
	"resource_efficiency": 0.5,
}
