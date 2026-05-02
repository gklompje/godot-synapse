@tool
class_name SynapseDemoToggleMenuBehavior
extends SynapseBehavior

signal menu_toggled

@export var action: SynapseInputActionParameter
@export var game_started: SynapseBoolParameter

static func get_category() -> StringName:
	return CATEGORY_DEMOS

func _input(event: InputEvent) -> void:
	if event.is_action(action.value) and action.is_just_pressed() and game_started.value:
		menu_toggled.emit()

func _get_read_only_parameters() -> PackedStringArray:
	return ["action", "game_started"]
