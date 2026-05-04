@tool

## A pure mechanical pass-through of a callable to a signal, mainly for visual clarity.[br][br]
## Used to receive the signal sent by a slime when it attacks Cletus, and transition Cletus to his
## Dead state. We could do more interesting things here like apply damage to a health bar, but right
## now it's just instant death.
class_name SynapseDemoRegisterAttackBehavior
extends SynapseBehavior

signal attack_registered

static func get_category() -> StringName:
	return CATEGORY_DEMOS

func register_attack() -> void:
	attack_registered.emit()
