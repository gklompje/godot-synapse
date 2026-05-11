@tool

## Smoothly updates a character's velocity based on a desired movement direction and calls
## [method CharacterBody2D.move_and_slide] to apply movement.[br][br]
## Each frame, this behavior sets the velocity according to a direction parameter as follows:[br]
## 1. When the direction is non-zero, applies acceleration in the movement direction each frame.[br]
## 2. When the direction is zero, applies deceleration in the opposite direction of the velocity.
class_name SynapseDemoSmoothMotion2D
extends SynapseDemoCharacterBehavior2D

@export var movement_direction_normal: SynapseVector2Parameter # desired movement direction (input)
@export var acceleration: SynapseFloatParameter # acceleration in movement direction
@export var deceleration: SynapseFloatParameter # deceleration when movement direction is not set
@export var max_speed: SynapseFloatParameter # maximum speed to accelerate to
@export var terrain_movement_speed: SynapseFloatParameter # velocity multiplier

static func get_category() -> StringName:
	return SynapseBehavior.CATEGORY_DEMOS

func _get_read_only_parameters() -> PackedStringArray:
	return ["movement_direction_normal", "acceleration", "deceleration", "max_speed", "terrain_movement_speed"]

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	if movement_direction_normal.value == Vector2.ZERO:
		# decelerate
		var slow := deceleration.value * delta * character.velocity.normalized()
		if slow.length_squared() > character.velocity.length_squared():
			# we're slow enough, just do a dead stop to avoid oscillating
			character.velocity = Vector2.ZERO
		else:
			character.velocity -= slow
	else:
		# accelerate
		character.velocity = (character.velocity + acceleration.value * delta * movement_direction_normal.value)

	# limit to max speed, and apply terrain speed multiplier
	character.velocity = character.velocity.limit_length(max_speed.value * terrain_movement_speed.value)

	# go!
	character.move_and_slide()

func _get_custom_save_data() -> Dictionary:
	# we save the character's velocity so the motion isn't cancelled when loading,
	# and so motion isn't carried over when starting a new game (the initially saved value is zero)
	return {
		&"velocity": character.velocity,
	}

func _load_custom_save_data(custom_save_data: Dictionary) -> void:
	character.velocity = custom_save_data[&"velocity"]
