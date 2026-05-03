@tool
@abstract

## Base class for behaviors that reference a [CharacterBody2D]
class_name SynapseDemoCharacterBehavior2D
extends SynapseBehavior

static func get_category() -> StringName:
	return SynapseBehavior.CATEGORY_DEMOS

@export var character: CharacterBody2D
