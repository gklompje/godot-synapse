@tool

## Sets a direction parameter based on the specified directional input actions using
## [method Input.get_vector].
class_name SynapseDemoUpdateVectorOnActionInput
extends SynapseBehavior

@export var vector: SynapseVector2Parameter # direction parameter to set
@export var input_left: SynapseInputActionParameter # -X input action
@export var input_right: SynapseInputActionParameter # +X input action
@export var input_up: SynapseInputActionParameter # -Y input action (Godot's Y axis points downward on screen)
@export var input_down: SynapseInputActionParameter # +Y input action (Godot's Y axis points downward on screen)

static func get_category() -> StringName:
	return SynapseBehavior.CATEGORY_DEMOS

func _get_read_only_parameters() -> PackedStringArray:
	return ["input_left", "input_right", "input_up", "input_down"]

func _unsuspend() -> void:
	# sync the vector when this behavior unsuspends, since the direction was probably being set by a different state while this behavior was suspended
	vector.value = Input.get_vector(input_left.value, input_right.value, input_up.value, input_down.value)

func _unhandled_input(event: InputEvent) -> void:
	for action: StringName in [input_left.value, input_right.value, input_up.value, input_down.value]:
		if event.is_action(action):
			vector.value = Input.get_vector(input_left.value, input_right.value, input_up.value, input_down.value)
			return
