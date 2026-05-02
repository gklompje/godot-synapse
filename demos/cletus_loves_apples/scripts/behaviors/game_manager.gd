@tool
class_name SynapseDemoGameManagerBehavior
extends SynapseBehavior

@export var game_started: SynapseBoolParameter
@export var score: SynapseIntParameter

var _new_game_state: Dictionary

static func get_category() -> StringName:
	return CATEGORY_DEMOS

func _unsuspend() -> void:
	game_started.value = true

func _state_machine_created() -> void:
	_new_game_state = state_machine.get_save_data()

func reset() -> void:
	state_machine.load_save_data(_new_game_state)

func apple_consumed() -> void:
	score.value += 1

func player_died() -> void:
	game_started.value = false
