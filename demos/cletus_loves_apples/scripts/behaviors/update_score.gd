@tool

## Updates the score label whenever the game's score parameter changes.
class_name SynapseDemoUpdateScoreBehavior
extends SynapseBehavior

@export var score: SynapseIntParameter

@onready var score_label: Label = %ScoreLabel

static func get_category() -> StringName:
	return CATEGORY_DEMOS

func _get_read_only_parameters() -> PackedStringArray:
	return ["score"]

func _get_signal_relays() -> Array[RuntimeSignalRelay]:
	return [
		SignalRelay.for_parameter(score, _on_score_value_updated),
	]

func _on_score_value_updated(new_value: int) -> void:
	score_label.text = "Score: %d" % [new_value]
