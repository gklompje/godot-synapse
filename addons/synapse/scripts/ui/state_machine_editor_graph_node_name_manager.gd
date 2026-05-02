@tool
class_name SynapseStateMachineEditorGraphNodeNameManager
extends Control

signal update_requested(proposed_name: String)

@onready var name_line_edit: LineEdit = %NameLineEdit
@onready var name_label: Label = %NameLabel

@export var editable := false:
	set(value):
		editable = value
		if is_instance_valid(name_line_edit):
			name_line_edit.visible = editable
		if is_instance_valid(name_label):
			name_label.visible = not editable

@export var name_value: StringName:
	set(value):
		name_value = value
		if is_instance_valid(name_line_edit):
			name_line_edit.text = name_value
		if is_instance_valid(name_label):
			name_label.text = name_value

func _ready() -> void:
	name_line_edit.text = name_value
	name_label.text = name_value
	name_line_edit.visible = editable
	name_label.visible = not editable

func _on_name_line_edit_editing_toggled(toggled_on: bool) -> void:
	if not toggled_on and name_value != name_line_edit.text:
		update_requested.emit(name_line_edit.text)

func _on_name_line_edit_text_submitted(new_text: String) -> void:
	if name_value != name_line_edit.text:
		update_requested.emit(new_text)
