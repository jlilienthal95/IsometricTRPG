class_name StatusEffect
extends Resource

enum StatusEffect {
	NONE,
	# Movement/Action
	SLOW,
	HASTE,
	STOP,
	IMMOBILIZE,
	DISABLE,
	SLEEP,
	CONFUSE,
	# Offensive
	POISON,
	BLIND,
	SILENCE,
	CHARM,
	BERSERK,
	PETRIFY,
	DOOM,
	# Defensive
	REGEN,
	PROTECT,
	SHELL,
	REFLECT,
	INVISIBLE,
	FLOAT,
	# Stat modifiers
	ATTACK_UP,
	ATTACK_DOWN,
	DEFENSE_UP,
	DEFENSE_DOWN,
	MAGIC_UP,
	MAGIC_DOWN,
	SPEED_UP,
	SPEED_DOWN,
	# Critical
	CRIT_UP,
	CRIT_DOWN,
}
