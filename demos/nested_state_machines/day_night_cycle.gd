@tool
## Increases the time (hour) based on the "hours_per_second" value, and rotates the sun and moon
## sprites accordingly.
class_name SynapseDemoDayNightCycleBehavior
extends SynapseBehavior

@export var sun_sprite: Sprite2D
@export var moon_sprite: Sprite2D
@export var hours_per_second: SynapseFloatParameter
@export var hour: SynapseFloatParameter
@export var camera: Camera2D

static func get_category() -> StringName:
	return SynapseBehavior.CATEGORY_DEMOS

func _get_read_only_parameters() -> PackedStringArray:
	return ["hours_per_second"]

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	hour.value = fmod(hour.value + hours_per_second.value * delta, 24.0)

func _get_signal_relays() -> Array[RuntimeSignalRelay]:
	return [
		SignalRelay.for_parameter(hour, _on_hour_value_set),
	]

func _on_hour_value_set(new_value: float) -> void:
	var screen_center_global_pos := camera.get_screen_center_position()
	var hour_angle := new_value / 24.0 * TAU
	moon_sprite.global_position.x = screen_center_global_pos.x + 160.0 * cos(hour_angle - PI / 2.0)
	moon_sprite.global_position.y = screen_center_global_pos.y + 160.0 * sin(hour_angle - PI / 2.0)
	sun_sprite.global_position.x = screen_center_global_pos.x + 160.0 * cos(hour_angle + PI / 2.0)
	sun_sprite.global_position.y = screen_center_global_pos.y + 160.0 * sin(hour_angle + PI / 2.0)
