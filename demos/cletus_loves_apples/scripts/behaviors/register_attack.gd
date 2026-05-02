@tool
class_name SynapseDemoRegisterAttackBehavior
extends SynapseBehavior

signal attack_registered

static func get_category() -> StringName:
	return CATEGORY_DEMOS

func register_attack() -> void:
	attack_registered.emit()
