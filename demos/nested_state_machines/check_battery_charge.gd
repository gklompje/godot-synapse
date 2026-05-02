@tool
## Selects the "On" state if battery charge is above the "on" threshold, and the "Off" state when it
## falls below the "off" threshold.
class_name SynapseDemoCheckBatteryChargeBehavior
extends SynapseBehavior

signal switch_on
signal switch_off

@export var battery_charge: SynapseFloatParameter
@export var battery_on_threshold: SynapseFloatParameter
@export var battery_off_threshold: SynapseFloatParameter

static func get_category() -> StringName:
	return SynapseBehavior.CATEGORY_DEMOS

func _get_read_only_parameters() -> PackedStringArray:
	return ["battery_charge", "battery_on_threshold", "battery_off_threshold"]

func _get_signal_relays() -> Array[RuntimeSignalRelay]:
	return [
		SignalRelay.for_parameter(battery_charge, _on_battery_charge_value_set),
	]

func _on_battery_charge_value_set(new_value: float) -> void:
	if new_value >= battery_on_threshold.value:
		switch_on.emit()
	elif new_value <= battery_off_threshold.value:
		switch_off.emit()
