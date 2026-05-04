@tool

## Sets the direction parameter to zero when unsuspended. Used to stop character motions when they
## reach certain states, like idle or dying.
class_name SynapseDemoStandStillBehavior
extends SynapseBehavior

@export var target_direction: SynapseVector2Parameter

static func get_category() -> StringName:
	return SynapseBehavior.CATEGORY_DEMOS

func _unsuspend() -> void:
	target_direction.value = Vector2.ZERO
