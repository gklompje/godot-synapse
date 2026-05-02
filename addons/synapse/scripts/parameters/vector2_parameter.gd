extends SynapseParameter
class_name SynapseVector2Parameter

signal value_set(new_value: Vector2)

@export var value: Vector2:
	set(new_value):
		value = new_value
		value_set.emit(new_value)
