extends SynapseParameter
class_name SynapseVector2iParameter

signal value_set(new_value: Vector2i)

@export var value: Vector2i:
	set(new_value):
		value = new_value
		value_set.emit(new_value)
