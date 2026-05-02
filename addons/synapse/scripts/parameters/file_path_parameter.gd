extends SynapseParameter
class_name SynapseFilePathParameter

signal value_set(new_value: String)

@export var value: String:
	set(new_value):
		value = new_value
		value_set.emit(new_value)

func exists() -> bool:
	return FileAccess.file_exists(value)
