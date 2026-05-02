class_name SynapseDemoRotatingIconWidget
extends MarginContainer

signal rotation_requested(on: bool)

@onready var rotation_control: Control = %RotationControl
@onready var label: Label = %Label

func set_label_text(text: String) -> void:
	label.text = text

func set_icon_rotation(angle_radians: float) -> void:
	rotation_control.rotation = angle_radians

func _on_rotating_check_button_toggled(toggled_on: bool) -> void:
	rotation_requested.emit(toggled_on)
