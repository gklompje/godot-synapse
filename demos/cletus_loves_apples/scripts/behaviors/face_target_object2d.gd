@tool
class_name SynapseDemoFaceTargetObjectBehavior
extends SynapseDemoCharacterBehavior2D

@export var target_object: SynapseNodePathParameter
@export var target_direction: SynapseVector2Parameter

static func get_category() -> StringName:
	return SynapseBehavior.CATEGORY_DEMOS

func _physics_process(_delta: float) -> void:
	if target_object.value.is_empty() or not state_machine.has_node(target_object.value):
		return
	var obj := state_machine.get_node(target_object.value) as Node2D
	target_direction.value = (obj.global_position - character.global_position).normalized()

func _get_read_only_parameters() -> PackedStringArray:
	return ["target_object"]
