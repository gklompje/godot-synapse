@tool
class_name SynapseDemoAnimationTreeTravelBehavior
extends SynapseBehavior

@export var animation_tree: AnimationTree

var _playback: AnimationNodeStateMachinePlayback

static func get_category() -> StringName:
	return CATEGORY_DEMOS

func _state_machine_created() -> void:
	_playback = animation_tree.get("parameters/playback")

func travel(target_state: StringName) -> void:
	_playback.travel(target_state)
