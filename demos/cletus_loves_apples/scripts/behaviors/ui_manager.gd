@tool

## Handles UI events for the menu state machine.
class_name SynapseDemoCletusMenuManagerBehavior
extends SynapseBehavior

signal new_game_pressed # emitted when the "New Game" button is pressed, to trigger resetting the game state machine
signal save_pressed # emitted when pressing the "Save" button, to tell the game state machine to save its state
signal load_pressed # emitted when pressing the "Load" button, to tell the game state machine to load

# UI node references
@onready var menu_overlay: Control = %MenuOverlay
@onready var game_over_label: Label = %GameOverLabel
@onready var new_game_button: Button = %NewGameButton
@onready var save_button: Button = %SaveButton
@onready var load_button: Button = %LoadButton
@onready var quit_button: Button = %QuitButton

@export var save_file_path: SynapseFilePathParameter # where to save the game state machine save data
@export var game_started: SynapseBoolParameter # game active state, to hide the save button when there is nothing to save

func _unsuspend() -> void:
	# don't show the load button if there is no save file
	load_button.disabled = not save_file_path.exists()

	# show the menu
	menu_overlay.show()

func _suspend() -> void:
	# hide the menu, and the game over label (in case it was there because the game ended)
	menu_overlay.hide()
	game_over_label.hide()

static func get_category() -> StringName:
	return CATEGORY_DEMOS

func _get_read_only_parameters() -> PackedStringArray:
	return ["save_file_path", "game_started", "score"]

func _get_signal_relays() -> Array[RuntimeSignalRelay]:
	return [
		SignalRelay.for_parameter(game_started, _on_game_started_value_set),
		SignalRelay.of(new_game_button.pressed, new_game_pressed.emit),
		SignalRelay.of(save_button.pressed, _on_save_button_pressed),
		SignalRelay.of(load_button.pressed, load_pressed.emit),
		SignalRelay.of(quit_button.pressed, get_tree().quit),
	]

func _on_save_button_pressed() -> void:
	save_pressed.emit()
	# if saving was successful, we can show the load button
	load_button.disabled = not save_file_path.exists()

## Should be called when the game ends to show the "Game Over" label, e.g. when Cletus dies
func game_over() -> void:
	game_over_label.show()

func _on_game_started_value_set(new_value: bool) -> void:
	# allow saving once the game has started
	save_button.disabled = not new_value
