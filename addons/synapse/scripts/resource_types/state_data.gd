@tool
## The base data type for a [SynapseState], which can be extended to implement custom states.
##
## This resource type defines various methods which define its interactions with the editor. Its
## main purpose is to provide editor functionality to help set up the state, which is then created
## at runtime using [method instantiate_state].[br][br]
## When implementing custom states, you should create a script that extends this class and annotate
## it with [annotation @GDScript.@tool]. Then, create a script for a custom state extending from
## [SynapseState], and return a new instance of it in [method instantiate_state]. You should also provide
## a name and icon for your state type through [method get_type_name] and [method get_type_icon].
class_name SynapseStateData
extends SynapseEntityData

## Defines the keys for instantiable option dictionaries - see [method get_options].
enum Option {
	ICON,
	NAME,
	DATA,
}

## The name of this state's parent state (or empty if it's the root state).
@export_storage var parent_name: StringName
## The names of the child states assigned to this state.
@export_storage var child_names: Array[StringName] = []
## The names of the [SynapseBehavior]s owned by this state.
@export_storage var behavior_names: Array[StringName] = []

func _to_string() -> String:
	return "%s {parent_name=%s, child_names=%s, graph_pos=%s}" % [name, parent_name, child_names, graph_pos]

## Called at runtime to instantiate the state from this data object. Override this method to construct a custom [SynapseState] implementation.
@warning_ignore("unused_parameter")
func instantiate_state(state_machine: SynapseStateMachine, child_states: Array[SynapseState], behaviors: Array[SynapseBehavior]) -> SynapseState:
	return SynapseState.new(name, behaviors)

## The type of this state. Used when displaying this state in the editor.
func get_type_name() -> StringName:
	return &"State"

## The icon associated with this state. Used when displaying this state in the editor.
func get_type_icon() -> Texture2D:
	return SynapseStateMachineEditorResourceManager.Icons.get_icon(SynapseStateMachineEditorResourceManager.Icons.STATE_STATE)

## Defines the options from which this state can be created.[br][br]
## By default, only one option will appear for this state in the editor's popup list when adding a new state. If your state has multiple variations,
## you can give each a name and icon, as well as an arbitrary data value which will be passed to [method init_from_option] when that option is selected.
@warning_ignore("unused_parameter")
func get_options(state_machine: SynapseStateMachine) -> Array[Dictionary]: # [ { ICON: my_icon, NAME: "My Option", DATA: 42 } ]
	return [
		{
			Option.NAME: get_type_name(),
			Option.ICON: get_type_icon(),
			Option.DATA: null,
		}
	]

## Called to initialize the state after it was created in the editor. See [method get_options] - unless
## that method is overridden, [param option_data] will be [code]null[/code].
@warning_ignore("unused_parameter")
func init_from_option(option_data: Dictionary) -> void:
	pass

## Called when this state is loaded in the editor, either when a new instance of it is created or when
## an existing state machine is loaded.[br][br]
## Only use this method for setting up the editor- actions like altering the state machine data may
## not work correctly since this method is called while the editor is not fully initialized.[br][br]
## This method is called after the editor has created graph nodes for all states/behaviors/parameters,
## so it is safe to reference other graph nodes for e.g. creating connections between nodes.[br][br]
## If this state needs to connect to the editor's [SynapseStateMachineData] ([code]state_machine.data[/code])
## signals, this method is the appropriate place to do that.
@warning_ignore("unused_parameter")
func prepare_in_editor(editor: SynapseStateMachineEditor) -> void:
	pass

## Called when this state is deleted from the editor. Godot should automatically disconnect any
## signals this state's methods are connected to (e.g. during [method prepare_in_editor]), but it
## it is good practice to disconnect any signals here.[br][br]
## [b]NB:[/b] By the time this method is called, [code]editor.state_machine[/code] may already refer
## to a different state machine than that to which this state belongs.[br][br]
## [param previous_data] contains the [SynapseStateMachineData] that was present on
## [editor.state_machine.data] data when [method prepare_in_editor] was previously called, i.e. the
## data resource containing this state, because this method may be called [i]after[/i] the state
## machine's data has been changed. Use this to, for example, disconnect from
## [param previous_data]'s signals.
@warning_ignore("unused_parameter")
func teardown_in_editor(editor: SynapseStateMachineEditor, previous_data: SynapseStateMachineData) -> void:
	pass

## Called to customize this state's [SynapseStateGraphNode] representation in the editor.
@warning_ignore("unused_parameter")
func prepare_state_graph_node(state_machine: SynapseStateMachine, state_graph_node: SynapseStateGraphNode) -> void:
	pass

## Returns the maximum number of child states this state can hold ([code]0[/code] by default). Note
## that [code]-1[/code] means "unlimited".
func get_max_child_count() -> int:
	return 0

## Called by the state machine during runtime initialization to determine if this state is fully
## initialized. If it returns [code]false[/code], the state machine will keep deferring its
## initialization and try again until it returns [code]true[/code]. Use this when your state depends
## on other nodes or resources being fully initialized at runtime.
@warning_ignore("unused_parameter")
func is_ready(state_machine: SynapseStateMachine) -> bool:
	return true

## Called by the editor when a connection from this state's owning [SynapseStateGraphNode] is being dragged
## to an empty section of the graph. Used for more advanced states that instantiate other resources
## with their own graph nodes. Note this is not called when child states or behaviors are added.
@warning_ignore("unused_parameter")
func attempt_connection_to_empty(editor: SynapseStateMachineEditor, connection_type: SynapseStateMachineEditor.ConnectionType, slot_name: StringName, graph_position: Vector2) -> void:
	pass

## Called when one or more nodes are about to be erased as part of an undoable operation. The
## editor's [EditorUndoRedoManager] ([code]editor.undo_redo[/code]) will already have an active
## undo/redo action. Override this method to add custom undo/redo steps. Note the active undo action
## has [code]backward_undo_ops[/code] set to [code]true[/code] (see
## [method EditorUndoRedoManager.create_action]).
@warning_ignore("unused_parameter")
func notify_erase_undoable(editor: SynapseStateMachineEditor, erased_state_names: Array[StringName], erased_behavior_names: Array[StringName], erased_parameter_names: Array[StringName], erased_signal_bridge_names: Array[StringName]) -> void:
	pass

## Called to determine whether two child states of this state can be connected via a [enum SynapseStateMachineEditor.ConnectionType]
## of [code]TRANSITION_FROM[/code] to [code]TRANSITION_TO[/code]. See [method create_child_transition]. Child transitions are
## disabled by default.[br][br]
## If you want your state to support child transitions, you must persist the transitions in a custom property of your state data.
## Also note that your state data is responsible for calling [method SynapseStateGraphNode.add_child_slot] and [method SynapseStateGraphNode.remove_child_slot]
## whenever child states are added to or removed from it. For this you will need to subscribe to various signals defined on [SynapseStateMachineData]
## and implement [method remove_child_state_undoable]. For an example, see [SynapseSelectorStateData].
@warning_ignore("unused_parameter")
func can_create_child_transition(from_state_data: SynapseStateData, to_state_data: SynapseStateData) -> bool:
	return false

## Called when a child transition is being made. See [can_create_child_transition], without which this method will not be called.
@warning_ignore("unused_parameter")
func create_child_transition(editor: SynapseStateMachineEditor, from_state_data: SynapseStateData, to_state_data: SynapseStateData) -> void:
	pass

## Called to define the undo operation when a new child state is added in the editor. The editor's
## [EditorUndoRedoManager] ([code]editor.undo_redo[/code]) will already have an active undo/redo action.
## Typically used to manage child transitions and adding/removing such slots from child states' [SynapseStateGraphNode]s.
@warning_ignore("unused_parameter")
func remove_child_state_undoable(editor: SynapseStateMachineEditor, child_state_data: SynapseStateData) -> void:
	pass

## Called during state machine initialization when the state machine's [method Node._ready] method
## is complete, but it has not yet started its (deferred) initialization.
@warning_ignore("unused_parameter")
func notify_state_machine_pre_created(state_machine: SynapseStateMachine) -> void:
	pass

func create_callable_data(callable_name: StringName, _state_machine: SynapseStateMachine) -> SynapseCallableData:
	return SynapseStateMethodCallableData.of(name, callable_name)

@warning_ignore("unused_parameter")
func get_signal_infos_for_callables(state_machine: SynapseStateMachine) -> Array[Dictionary]:
	# { "name": "entered", "args": [], "default_args": [], "flags": 1, "id": 0, "return": { "name": "", "class_name": &"", "type": 0, "hint": 0, "hint_string": "", "usage": 6 } }
	# { "name": "exited", "args": [], "default_args": [], "flags": 1, "id": 0, "return": { "name": "", "class_name": &"", "type": 0, "hint": 0, "hint_string": "", "usage": 6 } }
	return [
		{ "name": "entered", "args": [], "default_args": [] },
		{ "name": "exited", "args": [], "default_args": [] },
	]

@warning_ignore("unused_parameter")
func create_signal_data(signal_name: StringName, _state_machine: SynapseStateMachine) -> SynapseSignalData:
	return SynapseStateSignalData.of(name, signal_name)
