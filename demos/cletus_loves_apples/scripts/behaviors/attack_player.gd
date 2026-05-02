@tool
class_name SynapseDemoAttackPlayerBehavior
extends SynapseBehavior

signal player_attacked

@export var detector: Area2D

static func get_category() -> StringName:
	return SynapseBehavior.CATEGORY_DEMOS

func _get_signal_relays() -> Array[RuntimeSignalRelay]:
	return [
		SignalRelay.of(detector.body_entered, player_attacked.emit),
	]
