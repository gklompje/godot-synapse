@tool
class_name SynapseDemoSaveLoadBehavior
extends SynapseBehavior

static func get_category() -> StringName:
	return CATEGORY_DEMOS

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

func save_state_machine(file_path: String) -> void:
	var config := ConfigFile.new()
	config.set_value("SaveData", "state_machine", state_machine.get_save_data())
	config.save(file_path)
