@tool
## Charges or drains the battery based on the input current- a negative current drains, and a
## positive current charges. Also updates the battery's progress bar to show its charge, and the
## sprite to indicate if it's empty, charging/draining, or full.
class_name SynapseDemoChargeOrDrainBattery
extends SynapseBehavior

@export var sprite: Sprite2D
@export var progress_bar: ProgressBar
@export var empty_frame := 0
@export var charging_frame := 1
@export var full_frame := 2
@export var current: SynapseFloatParameter
@export var charge_rate: SynapseFloatParameter
@export var charge: SynapseFloatParameter

static func get_category() -> StringName:
	return SynapseBehavior.CATEGORY_DEMOS

func _get_read_only_parameters() -> PackedStringArray:
	return ["current", "charge_rate"]

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	charge.value = minf(100.0, maxf(0.0, charge.value + charge_rate.value * delta * current.value))

func _get_signal_relays() -> Array[RuntimeSignalRelay]:
	return [
		SignalRelay.for_parameter(charge, _on_charge_value_set),
	]

func _on_charge_value_set(new_value: float) -> void:
	progress_bar.value = new_value
	if new_value <= 0.0:
		sprite.frame = empty_frame
	elif new_value >= 100.0:
		sprite.frame = full_frame
	else:
		sprite.frame = charging_frame
