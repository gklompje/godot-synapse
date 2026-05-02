extends SynapseParameter
class_name SynapseRect2Parameter

signal value_set(new_value: Rect2)

@export var value: Rect2:
	set(new_value):
		value = new_value
		value_set.emit(new_value)
