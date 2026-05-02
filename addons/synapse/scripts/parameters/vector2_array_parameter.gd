extends SynapseParameter
class_name SynapseVector2ArrayParameter

signal value_set(new_value: PackedVector2Array)

@export var value: PackedVector2Array:
	set(new_value):
		value = new_value
		value_set.emit(new_value)
