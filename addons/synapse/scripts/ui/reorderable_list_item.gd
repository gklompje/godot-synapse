@tool
class_name SynapseEditorReorderableListItem
extends Control

signal move_up_requested
signal move_down_requested

var text: String:
	get():
		return label.text
	set(value):
		label.text = value

@onready var label: Label = %Label
@onready var button_container: VBoxContainer = %ButtonContainer
@onready var button_up: BaseButton = %ButtonUp
@onready var button_down: BaseButton = %ButtonDown

func _ready() -> void:
	button_container.modulate.a = 0.0
	button_container.hide()

func notify_about_to_move() -> void:
	button_up.visible = false
	button_down.visible = false
	_update_button_container_visibility(false)

func notify_relative_position(is_first: bool, is_last: bool) -> void:
	button_up.visible = not is_first
	button_down.visible = not is_last

	# only item can't be moved
	button_container.visible = not (is_first and is_last)

func _update_button_container_visibility(on: bool) -> void:
	button_container.modulate.a = 1.0 if on else 0.0

func _on_button_up_pressed() -> void:
	move_up_requested.emit()

func _on_button_down_pressed() -> void:
	move_down_requested.emit()

func _on_mouse_entered() -> void:
	_update_button_container_visibility(true)

func _on_mouse_exited() -> void:
	_update_button_container_visibility(false)

func _on_focus_entered() -> void:
	_update_button_container_visibility(true)

func _on_focus_exited() -> void:
	_update_button_container_visibility(false)
