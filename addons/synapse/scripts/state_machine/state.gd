@icon("uid://db62s30spivmp")

## The most basic type of state that stands on its own, and from which more complex states are
## derived.[br][br]
## A state is owned and managed by a [SynapseStateMachine]. Complex state types contain and manage
## a set of child states they own, to model more intricate control flow patterns.[br][br]
## A state can have any number of [SynapseBehavior]s assigned to it. When the state is entered and
## exited, it unsuspends and suspends its behaviors accordingly.[br][br]
## To implement a custom state, three things are required:[br]
## 1. A new state type that extends [SynapseState] (or one of the other state types).[br]
## 2. A [SynapseStateData] resource type used to configure the state in the editor, and instantiate
## it at runtime.[br]
## 3. (If applicable) Any custom data required to preserve and restore the state's internals for
## saving and loading, implemented in [method get_save_data] and [method load_save_data].
class_name SynapseState
extends RefCounted

## Unique name of this state within the state machine.
var name: StringName
var behaviors: Array[SynapseBehavior]
var active := false

## Emitted when this state is entered.
signal entered

## Emitted when this state is exited.
signal exited

@warning_ignore("shadowed_variable")
func _init(name: StringName, behaviors: Array[SynapseBehavior] = []) -> void:
	self.name = name
	self.behaviors = behaviors

## Enters (activates) this state, and unsuspends the [SynapseBehavior]s it directly owns.[br][br]
## Should only be called by the state machine and parent states.
func enter() -> void:
	if active:
		return
	active = true
	for behavior in behaviors:
		behavior.unsuspend()
	entered.emit()

## Exits (deactivates) this state, and suspends the [SynapseBehavior]s it directly owns.[br][br]
## Should only be called by the state machine and parent states.
func exit() -> void:
	if not active:
		return
	for i in range(len(behaviors) - 1, -1, -1):
		behaviors[i].suspend()
	active = false
	exited.emit()

## Returns a dictionary containing this state's save data.[br][br]
## Called when the state machine is being saved. Override this method to populate the dictionary
## with any custom state save data. The returned dictionary will be included in the state machine's
## save data when it is saved, and passed to [method load_save_data] when loading.[br][br]
## States do not need to save whether or not they or their children are [i]active[/i]. Parent states
## only need to record which of their child states are [i]selected[/i] (i.e. will be activated when
## the parent state is activated again).[br][br]
## States [b]should not[/b] enter/exit themselves during saving/loading, as that is managed by the
## state machine.[br][br]
## See [method SynapseStateMachine.get_save_data] for more details on saving.
@warning_ignore("unused_parameter")
func get_save_data() -> Dictionary:
	return {}

## Loads the given save data created by [method get_save_data].[br][br]
## Called automatically when the state machine loads from its save. States [b]should not[/b]
## enter/exit themselves or their children during saving/loading, as that is managed by the state
## machine.[br][br] See [method SynapseStateMachine.load_save_data] for more details on loading.
@warning_ignore("unused_parameter")
func load_save_data(save_data: Dictionary) -> void:
	pass
