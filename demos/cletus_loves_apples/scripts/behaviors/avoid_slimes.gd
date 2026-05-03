@tool

## Sets Cletus' movement direction such that it points away from all slimes in his detection range.
class_name SynapseDemoAvoidSlimesBehavior
extends SynapseBehavior

signal no_more_slimes # emitted to transition back to the idle state when all slimes have been successfully evaded

static func get_category() -> StringName:
	return CATEGORY_DEMOS

@export var cletus: CharacterBody2D # Cletus!
@export var detected_slimes: SynapseNodePathArrayParameter # array containing the currently detected slimes
@export var direction: SynapseVector2Parameter # direction parameter that governs Cletus' movement- we set this to avoid slimes

var _slimes: Array[Node2D] = [] # tracks slime nodes, for convenience
var _time_since_last_slime_seen := 0.0 # we want Cletus to keep running for some time after no more slimes are in range, so we don't immediately transition back to the avoiding state

func _get_read_only_parameters() -> PackedStringArray:
	return ["detected_slimes"]

func _get_signal_relays() -> Array[RuntimeSignalRelay]:
	return [
		SignalRelay.for_parameter(detected_slimes, _on_detected_slimes_value_set),
	]

func _suspend() -> void:
	_slimes.clear()

func _physics_process(delta: float) -> void:
	if _slimes.is_empty():
		# track the amount of time since we've not seen any slimes
		_time_since_last_slime_seen += delta
		if _time_since_last_slime_seen > 1.0:
			# it's been 1 second, so emit the signal that exits the avoiding state
			no_more_slimes.emit()
		return

	# calculate Cletus' direction based on where the slimes are
	# (the direction is the normalized vector of the sum of all slimes' directions *to* Cletus)
	var new_dir := Vector2.ZERO
	for slime in _slimes:
		# ignore invalid slimes
		if not is_instance_valid(slime) or slime.is_queued_for_deletion():
			continue
		new_dir += cletus.global_position - slime.global_position
	direction.value = new_dir.normalized()

func _on_detected_slimes_value_set(new_value: Array[NodePath]) -> void:
	# we want to reset the post-evasion timer only if there were slimes before
	var slimes_was_empty := _slimes.is_empty()
	_slimes.clear()

	# keep track of all the slime nodes, for convenient access elsewhere
	for node_path in new_value:
		if not state_machine.has_node(node_path):
			continue
		var slime := state_machine.get_node(node_path)
		if is_instance_valid(slime) and not slime.is_queued_for_deletion():
			_slimes.append(slime)

	# reset the post-evasion timer if there were slimes before, but there aren't any now
	# (see the comment on the `_time_since_last_slime_seen` property)
	if _slimes.is_empty() and not slimes_was_empty:
		_time_since_last_slime_seen = 0.0
