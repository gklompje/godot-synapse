@tool
class_name SynapseDemoPositionRecorder2DBehavior
extends SynapseBehavior

@export var node2d: Node2D
@export var position: SynapseVector2Parameter

static func get_category() -> StringName:
	return CATEGORY_DEMOS

func _physics_process(_delta: float) -> void:
	var pos := node2d.global_position
	if pos != position.value:
		position.value = pos
