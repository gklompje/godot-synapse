@tool

## Manages the game's state machine, to reset it when a new game is started.[br][br]
## Also updates the score when an apple is consumed, and stops the game when Cletus dies.
class_name SynapseDemoGameManagerBehavior
extends SynapseBehavior

@export var game_started: SynapseBoolParameter # set to indicate whether or not the game is active
@export var score: SynapseIntParameter # apples eaten

var _new_game_state: Dictionary

static func get_category() -> StringName:
	return CATEGORY_DEMOS

func _unsuspend() -> void:
	game_started.value = true

func _state_machine_created() -> void:
	# store the state machine's state when it first loads, to reset it when a new game is started
	_new_game_state = state_machine.get_save_data()

func reset() -> void:
	# resetting is just loading the save data captured on a fresh state machine
	state_machine.load_save_data(_new_game_state)

func apple_consumed() -> void:
	score.value += 1

func player_died() -> void:
	# oh no!
	game_started.value = false
