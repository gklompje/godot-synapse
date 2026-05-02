@tool
class_name SynapseDemoWidgetStateSelectorBehavior
extends SynapseBehavior

signal select
signal deselect

@export var widget: SynapseDemoRotatingIconWidget
@export var description: String

static func get_category() -> StringName:
	return SynapseBehavior.CATEGORY_DEMOS

func _unsuspend() -> void:
	widget.set_label_text(description)

func _get_signal_relays() -> Array[RuntimeSignalRelay]:
	return [
		SignalRelay.of(widget.rotation_requested, _on_widget_rotation_requested),
	]

func _on_widget_rotation_requested(on: bool) -> void:
	if on:
		select.emit()
	else:
		deselect.emit()
