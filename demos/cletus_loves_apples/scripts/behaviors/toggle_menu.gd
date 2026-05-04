@tool

## Emits a signal to switch between the menu and game states when an input action occurs.[br][br]
## Prevents exiting the menu if the game is not running.
class_name SynapseDemoToggleMenuBehavior
extends SynapseBehavior

signal menu_toggled # emitted when the main state machine should switch between the menu and game states

@export var action: SynapseInputActionParameter # input action to toggle menu
@export var game_started: SynapseBoolParameter # parameter from game state machine that determines if the game is active, and we can exit the menu

static func get_category() -> StringName:
	return CATEGORY_DEMOS

func _input(event: InputEvent) -> void:
	if event.is_action(action.value) and action.is_just_pressed() and game_started.value:
		menu_toggled.emit()

func _get_read_only_parameters() -> PackedStringArray:
	return ["action", "game_started"]
