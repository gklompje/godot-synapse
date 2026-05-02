@tool
class_name SynapseDemoTestBehavior
extends SynapseBehavior

# all signals expose an output port
signal test_signal(test_name: String, test_number: int)

# a regular node property
@export var test_name: String

# a parameter property
@export var test_number: SynapseIntParameter

# just to keep things organized in menus etc.
static func get_category() -> StringName:
	return SynapseBehavior.CATEGORY_DEMOS

# called when this behavior is unsuspended
func _unsuspend() -> void:
	print("DemoTest (test_name='", test_name, "'): unsuspended with test_number=", test_number.value)
	await get_tree().create_timer(1.0).timeout
	test_signal.emit(test_name, test_number.value)

# called when this behavior is suspended
func _suspend() -> void:
	print("DemoTest (test_name='", test_name, "'): suspended with test_number=", test_number.value)

## hint to the editor that we only read from 'test_number', turning it into an input port
func _get_read_only_parameters() -> PackedStringArray:
	return ["test_number"]

# signals that automatically connect and disconnect when this behavior unsuspends and suspends, respectively
func _get_signal_relays() -> Array[RuntimeSignalRelay]:
	return [
		SignalRelay.for_parameter(test_number, _on_test_number_value_set),
	]

# signal handler that fires when 'test_number' is set
func _on_test_number_value_set(new_value: int) -> void:
	print("DemoTest (test_name='", test_name, "'): test_number is now ", new_value)

# public methods expose input ports that signals can connect to
func call_me(signal_name: String, signal_number: int) -> void:
	print("DemoTest (test_name='", test_name, "'): signal relay called with signal_name='", signal_name, "' and signal_number=", signal_number)
