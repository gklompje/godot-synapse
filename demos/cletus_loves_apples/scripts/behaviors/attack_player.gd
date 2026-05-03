@tool

## Emits [signal player_attacked] whenever a body (player) enters the [Area2D].[br][br]
## The signal is handled by the slime manager, which in turn emits a signal that the game state
## machine hooks up to the player state machine to apply the damage.
class_name SynapseDemoAttackPlayerBehavior
extends SynapseBehavior

signal player_attacked # emitted when a player enters the area

@export var detector: Area2D # Area2D that detects the player (body)

static func get_category() -> StringName:
	return SynapseBehavior.CATEGORY_DEMOS

func _get_signal_relays() -> Array[RuntimeSignalRelay]:
	return [
		SignalRelay.of(detector.body_entered, player_attacked.emit),
	]
