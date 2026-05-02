@tool
class_name SynapseDemoSyncParameterWithSpinBoxBehavior
extends SynapseBehavior

@export_node_path("SpinBox") var spin_box: NodePath
@export var parameter: SynapseFloatParameter

static func get_category() -> StringName:
	return SynapseBehavior.CATEGORY_DEMOS

func _unsuspend() -> void:
	(get_node(spin_box) as SpinBox).value = parameter.value

func _get_signal_relays() -> Array[RuntimeSignalRelay]:
	return [
		SignalRelay.of((get_node(spin_box) as SpinBox).value_changed, _on_spin_box_value_changed),
	]

func _on_spin_box_value_changed(value: float) -> void:
	parameter.value = value
