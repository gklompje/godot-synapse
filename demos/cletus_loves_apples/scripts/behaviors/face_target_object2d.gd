@tool

## Updates a direction parameter to face from a character to some target object.[br][br]
## Used by Cletus to move towards apples, and slimes to move toward Cletus.
class_name SynapseDemoFaceTargetObjectBehavior
extends SynapseDemoCharacterBehavior2D

@export var target_object: SynapseNodePathParameter # object to move toward
@export var target_direction: SynapseVector2Parameter # direction parameter to set such that it faces from the character to the object

static func get_category() -> StringName:
	return SynapseBehavior.CATEGORY_DEMOS

func _physics_process(_delta: float) -> void:
	if target_object.value.is_empty() or not state_machine.has_node(target_object.value):
		# object is not in sight
		return

	# set the direction to the normalized vector from the character to the object
	var obj := state_machine.get_node(target_object.value) as Node2D
	target_direction.value = (obj.global_position - character.global_position).normalized()

func _get_read_only_parameters() -> PackedStringArray:
	return ["target_object"]
