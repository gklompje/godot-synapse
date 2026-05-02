@tool
class_name SynapseDemoSyncAnimationBlendPositionToFacingDirection2D
extends SynapseBehavior

@export var animation_tree: AnimationTree
@export var blend_space_1d_blend_position_parameter: String
@export var blend_space_2d_blend_position_parameter: String
@export var facing_direction_normal: SynapseVector2Parameter

var _blend_position: Vector2

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
	_full_sync(new_value)

func _full_sync(dir: Vector2) -> void:
	if dir == Vector2.ZERO:
		return
	_blend_position = dir
	_update_blend_tree()

func _on_animation_tree_updated(_ignore: Variant = null) -> void:
	_update_blend_tree()

func _update_blend_tree() -> void:
	if blend_space_1d_blend_position_parameter:
		animation_tree.set(blend_space_1d_blend_position_parameter, _blend_position.x)
	if blend_space_2d_blend_position_parameter:
		animation_tree.set(blend_space_2d_blend_position_parameter, _blend_position)

func _get_signal_relays() -> Array[RuntimeSignalRelay]:
	return [
		SignalRelay.for_parameter(facing_direction_normal, _on_facing_direction_normal_value_set),
		# see https://forum.godotengine.org/t/animationtree-animation-started-animation-finished-not-firing/56199/2
		# (tree signals don't work for looping animations: https://github.com/godotengine/godot/commit/ecd895a8602ce67818af06226e804bd843108a6a#diff-eee4fe50a680a1b41951e634570be14c6572ccbbe953a1aca8a15bb3874dfc33R126)
		SignalRelay.of(animation_tree.mixer_applied, _on_animation_tree_updated),
		SignalRelay.of(animation_tree.animation_started, _on_animation_tree_updated),
	]
