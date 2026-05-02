@tool
class_name SynapseDemoSmoothMotion2D
extends SynapseDemoCharacterBehavior2D

@export var movement_direction_normal: SynapseVector2Parameter
@export var acceleration: SynapseFloatParameter
@export var deceleration: SynapseFloatParameter
@export var max_speed: SynapseFloatParameter
@export var terrain_movement_speed: SynapseFloatParameter

static func get_category() -> StringName:
	return SynapseBehavior.CATEGORY_DEMOS

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	if movement_direction_normal.value == Vector2.ZERO:
		var slow := deceleration.value * delta * character.velocity.normalized()
		if slow.length_squared() > character.velocity.length_squared():
			character.velocity = Vector2.ZERO
		else:
			character.velocity -= slow
	else:
		character.velocity = (character.velocity + acceleration.value * delta * movement_direction_normal.value)

	character.velocity = character.velocity.limit_length(max_speed.value * terrain_movement_speed.value)
	character.move_and_slide()

func _get_read_only_parameters() -> PackedStringArray:
	return ["movement_direction_normal", "acceleration", "deceleration", "max_speed", "terrain_movement_speed"]
