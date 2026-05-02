@tool
class_name SynapseEditorReorderableList
extends Container

signal item_order_changed(items: Array[StringName])

@onready var item_container: VBoxContainer = %ItemContainer

func append_item(text: StringName) -> void:
	for item: SynapseEditorReorderableListItem in item_container.get_children():
		if item.text == text:
			push_error("Cannot add duplicate item: ", text)
			return

	var item := SynapseStateMachineEditorResourceManager.Scenes.instantiate_reorderable_list_item()
	item_container.add_child(item)
	item.text = text
	item.move_up_requested.connect(_on_item_move_up_requested.bind(item))
	item.move_down_requested.connect(_on_item_move_down_requested.bind(item))
	_update_items()

func clear() -> void:
	for item in item_container.get_children():
		item_container.remove_child(item)
		item.queue_free()

func _on_item_move_up_requested(item: SynapseEditorReorderableListItem) -> void:
	var index := item_container.get_children().find(item)
	if index <= 0:
		return
	item.notify_about_to_move()
	item_container.move_child(item, index - 1)
	_update_items()
	_emit_item_order_changed()

func _on_item_move_down_requested(item: SynapseEditorReorderableListItem) -> void:
	var index := item_container.get_children().find(item)
	if index < 0 or index == item_container.get_child_count() - 1:
		return
	item.notify_about_to_move()
	item_container.move_child(item, index + 1)
	_update_items()
	_emit_item_order_changed()

func _emit_item_order_changed() -> void:
	var child_names: Array[StringName] = []
	for child in item_container.get_children():
		child_names.append((child as SynapseEditorReorderableListItem).text)
	item_order_changed.emit(child_names)

func _update_items() -> void:
	var num_items := item_container.get_child_count()
	for i in num_items:
		(item_container.get_child(i) as SynapseEditorReorderableListItem).notify_relative_position(i == 0, i == num_items - 1)
