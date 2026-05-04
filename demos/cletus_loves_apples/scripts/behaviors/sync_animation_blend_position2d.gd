@tool

## Continually updates an [AnimationTreeStateMachine]'s blend position parameters to match a
## direction parameter.[br][br]
class_name SynapseDemoSyncAnimationBlendPositionToFacingDirection2D
extends SynapseBehavior

@export var animation_tree: AnimationTree
@export var blend_space_1d_blend_position_parameter: String # name of the 1D blend animation state
@export var blend_space_2d_blend_position_parameter: String # name of the 2D blend animation state
@export var facing_direction_normal: SynapseVector2Parameter # input direction to apply to blend positions

static func get_category() -> StringName:
	return SynapseBehavior.CATEGORY_DEMOS

func _get_read_only_parameters() -> PackedStringArray:
	return ["facing_direction_normal"]

func _get_optional_properties() -> PackedStringArray:
	return ["blend_space_1d_blend_position_parameter", "blend_space_2d_blend_position_parameter"]

func _get_configuration_warnings() -> PackedStringArray:
	if not blend_space_1d_blend_position_parameter and not blend_space_2d_blend_position_parameter:
		return ["Must specify 1D and/or 2D blend position parameter"]
	return []

func _on_facing_direction_normal_value_set(new_value: Vector2) -> void:
	# don't update the blend position when the direction is zero (avoids flipping when a character stops)
	if new_value == Vector2.ZERO:
		return

	if blend_space_1d_blend_position_parameter:
		animation_tree.set(blend_space_1d_blend_position_parameter, new_value.x)
	if blend_space_2d_blend_position_parameter:
		animation_tree.set(blend_space_2d_blend_position_parameter, new_value)

func _get_signal_relays() -> Array[RuntimeSignalRelay]:
	return [
		# update the blend parameter(s) when the direction changes
		SignalRelay.for_parameter(facing_direction_normal, _on_facing_direction_normal_value_set),
	]
