@tool
class_name SynapseDemoStandStillBehavior
extends SynapseBehavior

@export var target_direction: SynapseVector2Parameter

static func get_category() -> StringName:
	return SynapseBehavior.CATEGORY_DEMOS

func _unsuspend() -> void:
	target_direction.value = Vector2.ZERO
