@tool
## Toggles the light bulb sprite frame to on or off, and sets the current draw to the light bulb's
## rating while on (zero while off).
class_name SynapseDemoToggleLightBulbBehavior
extends SynapseBehavior

@export var current_rating: SynapseFloatParameter
@export var sprite: Sprite2D
@export var on: bool
@export var off_frame := 0
@export var on_frame := 1
@export var current: SynapseFloatParameter

static func get_category() -> StringName:
	return SynapseBehavior.CATEGORY_DEMOS

func _get_read_only_parameters() -> PackedStringArray:
	return ["current_rating"]

func _unsuspend() -> void:
	if on:
		sprite.frame = on_frame
		current.value = -current_rating.value
	else:
		sprite.frame = off_frame
		current.value = 0.0
