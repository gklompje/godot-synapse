@tool
class_name SynapseDemoCletusMenuManagerBehavior
extends SynapseBehavior

signal new_game_pressed
signal save_pressed
signal load_pressed

@onready var menu_overlay: Control = %MenuOverlay
@onready var game_over_label: Label = %GameOverLabel
@onready var new_game_button: Button = %NewGameButton
@onready var save_button: Button = %SaveButton
@onready var load_button: Button = %LoadButton
@onready var quit_button: Button = %QuitButton

@export var save_file_path: SynapseFilePathParameter
@export var game_started: SynapseBoolParameter

func _unsuspend() -> void:
	load_button.disabled = not save_file_path.exists()
	menu_overlay.show()

func _suspend() -> void:
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
	load_button.disabled = not save_file_path.exists()

func game_over() -> void:
	game_over_label.show()

func _on_game_started_value_set(new_value: bool) -> void:
	save_button.disabled = not new_value
