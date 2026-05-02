@tool
class_name SynapseDemoWidgetRotatorBehavior
extends SynapseBehavior

@export var widget: SynapseDemoRotatingIconWidget

var _rotation_radians := 0.0

static func get_category() -> StringName:
	return SynapseBehavior.CATEGORY_DEMOS

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_rotation_radians = fmod(_rotation_radians + PI * delta, TAU)
	widget.set_icon_rotation(_rotation_radians)
