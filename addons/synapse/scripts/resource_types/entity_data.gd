@abstract
@tool
class_name SynapseEntityData
extends Resource

enum ConfigurationWarningKey {
	## The warning text
	TEXT,
}

@export_storage var name: StringName
@export_storage var graph_pos: Vector2
@export_storage var connected_signals: Dictionary[StringName, Array] = {} # method name : [SynapseSignalSourceData]

## Override this method to customize configuration warnings displayed in the editor.[br][br]
## The returned dictionary's keys must be values of [enum ConfigurationWarningKey].
@warning_ignore("unused_parameter")
func get_configuration_warnings(state_machine: SynapseStateMachine) -> Array[Dictionary]:
	return []

## Called by the editor to discover method definitions of the runtime entity that signals can be
## connected to.[br][br]
## The returned value should match the format of [method Object.get_method_list].[br][br]
## Also called during state machine initialization when connecting signal arguments.
@warning_ignore("unused_parameter")
func get_callable_infos_for_signals(state_machine: SynapseStateMachine) -> Array[Dictionary]:
	return []

## Called by the editor to discover signal definitions of the runtime entity that can be connected
## to callables.[br][br]
## The returned value should match the format of [method Object.get_signal_list].[br][br]
## Also called during state machine initialization when connecting signal arguments.
@warning_ignore("unused_parameter")
func get_signal_infos_for_callables(state_machine: SynapseStateMachine) -> Array[Dictionary]:
	return []

## Called by the editor to determine if a parameter can be associated with the given
## property.[br][br]
## If this method returns [code]true[/code], [method reference_parameter] may be called with the
## same arguments.
@warning_ignore("unused_parameter")
func can_reference_parameter(parameter_data: SynapseParameterData, property_name: StringName, state_machine: SynapseStateMachine) -> bool:
	return false

## Called by the editor to add a reference to the given parameter.[br][br]
## Returns the type of access (used to determine the connection direction).[br][br]
## This method will only be called if [method can_reference_parameter] returned [code]true[/code]
## when previously called with the same arguments.[br][br]
## This method is called as part of an undoable operation. The editor's [EditorUndoRedoManager]
## ([code]editor.undo_redo[/code]) will already have an active undo/redo action.
@warning_ignore("unused_parameter")
func reference_parameter_undoable(parameter_data: SynapseParameterData, property_name: StringName, editor: SynapseStateMachineEditor) -> SynapseParameterData.Access:
	return SynapseParameterData.Access.RO

## Called by the editor to remove a reference to a parameter.[br][br]
## This method is called when the parameter in question is being deleted, and when the connection is
## deleted directly in the editor.[br][br]
## This method is called as part of an undoable operation. The editor's [EditorUndoRedoManager]
## ([code]editor.undo_redo[/code]) will already have an active undo/redo action. Override this
## method to add custom undo/redo steps.
@warning_ignore("unused_parameter")
func release_parameter_undoable(parameter_data: SynapseParameterData, property_name: StringName, editor: SynapseStateMachineEditor) -> void:
	return

## Called by the editor to discover all the parameter references held by this entity.[br][br]
## Used during validation, initial graph setup, and when deleting parameters.
@warning_ignore("unused_parameter")
func get_parameter_references(state_machine: SynapseStateMachine) -> Array[SynapseParameterReferenceData]:
	return []

## Called when an entity has been renamed, to ensure references to it are updated.
@warning_ignore("unused_parameter")
func notify_entity_renamed(entity_data: SynapseEntityData, previous_name: StringName) -> void:
	pass

## Called by the editor to construct a callable data source that will be used to connect signals to
## at runtime.[br][br]
## [param callable_name] will be a [code]name[/code] property of one of the callables returned by
## [method get_callable_infos_for_signals].
@warning_ignore("unused_parameter")
func create_callable_data(callable_name: StringName, state_machine: SynapseStateMachine) -> SynapseCallableData:
	return null

## Called by the editor to construct a signal data source that will be used to connect to callables
## at runtime.[br][br]
## [param signal_name] will be a [code]name[/code] property of one of the signals returned by
## [method get_signal_infos_for_callables].
@warning_ignore("unused_parameter")
func create_signal_data(signal_name: StringName, state_machine: SynapseStateMachine) -> SynapseSignalData:
	return null
