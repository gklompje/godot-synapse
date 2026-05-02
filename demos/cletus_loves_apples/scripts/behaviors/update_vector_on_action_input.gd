@tool
class_name SynapseDemoUpdateVectorOnActionInput
extends SynapseBehavior

@export var vector: SynapseVector2Parameter
@export var input_left: SynapseInputActionParameter
@export var input_right: SynapseInputActionParameter
@export var input_up: SynapseInputActionParameter
@export var input_down: SynapseInputActionParameter

static func get_category() -> StringName:
	return SynapseBehavior.CATEGORY_DEMOS

func _get_read_only_parameters() -> PackedStringArray:
	return ["input_left", "input_right", "input_up", "input_down"]

func _unsuspend() -> void:
	vector.value = Input.get_vector(input_left.value, input_right.value, input_down.value, input_up.value)

func _unhandled_input(event: InputEvent) -> void:
	for action: StringName in [input_left.value, input_right.value, input_up.value, input_down.value]:
		if event.is_action(action):
			vector.value = Input.get_vector(input_left.value, input_right.value, input_down.value, input_up.value)
			return
