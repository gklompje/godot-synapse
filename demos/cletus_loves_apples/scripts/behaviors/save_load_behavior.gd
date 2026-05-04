@tool

## Deals with saving and loading the state machine to a specified file.[br][br]
## This behavior uses [ConfigFile] as the save file format since it natively supports storing all
## the data types the state machine produces, but you could use any format like JSON since the state
## machine's save data is just a big [Dictionary].
class_name SynapseDemoSaveLoadBehavior
extends SynapseBehavior

static func get_category() -> StringName:
	return CATEGORY_DEMOS

## Loads previously saved state from the specified file ([ConfigFile]) and applies it to the state
## machine.
func load_state_machine(file_path: String) -> void:
	if FileAccess.file_exists(file_path):
		var config := ConfigFile.new()
		var err := config.load(file_path)
		if err == OK:
			@warning_ignore("unsafe_cast")
			state_machine.load_save_data(config.get_value("SaveData", "state_machine") as Dictionary)
		else:
			push_warning("Cannot load, unable to parse: ", file_path)
	else:
		push_warning("Cannot load, file does not exist: ", file_path)

## Saves the state machine's current state to the specified file as a [ConfigFile].
func save_state_machine(file_path: String) -> void:
	var config := ConfigFile.new()
	config.set_value("SaveData", "state_machine", state_machine.get_save_data())
	config.save(file_path)
