@tool

## Used by slimes to keep track of Cletus.[br][br]
## Emits signals when Cletus enters or exits the detection area, to transition the slime to idle or
## pursuing states.
class_name SynapseDemoCheckPlayerBehavior
extends SynapseBehavior

static func get_category() -> StringName:
	return CATEGORY_DEMOS

signal player_found
signal player_lost

@export var player: SynapseNodePathParameter

func _get_read_only_parameters() -> PackedStringArray:
	return ["player"]

func _get_signal_relays() -> Array[RuntimeSignalRelay]:
	return [
		SignalRelay.for_parameter(player, _on_player_value_set),
	]

func _on_player_value_set(new_value: NodePath) -> void:
	if new_value.is_empty() or not state_machine.has_node(new_value) or state_machine.get_node(new_value).is_queued_for_deletion():
		player_lost.emit()
	else:
		player_found.emit()
