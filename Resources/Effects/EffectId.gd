# EffectId.gd
class_name EffectId
extends Resource

enum Id {
	NONE,

	# Fire
	BURNING,
	BLAZING,
	REDHOT,

	# Water / Ice
	SOAKED,
	FROZEN,
	SLIPPERY,

	# Wind
	WINDY,
	FEATHER,
	STAGGERED,

	# Electric / Magnetic
	ELECTRIFIED,
	ELECTRIFIED_CONDUCTED,
	MAGNETISED,
	INDUCTION,

	# Physical / Object Interaction
	SQUISHED,

	# Disease
	DISEASED,
	PLAGUED,

	# Movement / Action (classic)
	CONFUSE,
	DISABLE,
	HASTE,
	IMMOBILIZE,
	SLEEP,
	SLOW,
	STOP,

	# Offensive (classic)
	BERSERK,
	BLIND,
	CHARM,
	DOOM,
	PETRIFY,
	POISON,
	SILENCE,

	# Defensive (classic)
	FLOAT,
	INVISIBLE,
	PROTECT,
	REFLECT,
	REGEN,
	SHELL,

	# Stat Modifiers (classic)
	ATTACK_DOWN,
	ATTACK_UP,
	CRIT_DOWN,
	CRIT_UP,
	DEFENSE_DOWN,
	DEFENSE_UP,
	MAGIC_DOWN,
	MAGIC_UP,
	SPEED_DOWN,
	SPEED_UP,
}
