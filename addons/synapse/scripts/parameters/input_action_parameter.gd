@tool
extends SynapseParameter
class_name SynapseInputActionParameter

signal value_set(new_value: StringName)

@export var value: StringName:
	set(new_value):
		value = new_value
		value_set.emit(new_value)

func _validate_property(property: Dictionary) -> void:
	if property["name"] == &"value":
		var actions: Array[StringName]
		for prop in ProjectSettings.get_property_list():
			@warning_ignore("unsafe_cast")
			var prop_name := prop["name"] as String
			if prop_name.begins_with("input/"):
				var action_name := prop_name.trim_prefix("input/")
				actions.append(action_name)
		property["hint"] = PROPERTY_HINT_ENUM
		property["hint_string"] = ",".join(actions)

func is_just_pressed() -> bool:
	return Input.is_action_just_pressed(value)

func is_just_released() -> bool:
	return Input.is_action_just_released(value)

func is_pressed() -> bool:
	return Input.is_action_pressed(value)
