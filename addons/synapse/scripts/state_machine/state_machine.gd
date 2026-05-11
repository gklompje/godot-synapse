@tool
@icon("uid://brducfl5b54hv")

## A state machine manager that allows you to create rich state machines that can extend your game's
## functionality using composable [SynapseBehavior] nodes.

class_name SynapseStateMachine
extends Node

const SAVE_DATA_GODOT_VERSION = &"godot_version"
const SAVE_DATA_PLUGIN_VERSION = &"plugin_version"
const SAVE_DATA_STATE_MACHINE_ACTIVE = &"state_machine_active"
const SAVE_DATA_STATES := &"states"
const SAVE_DATA_BEHAVIORS := &"behaviors"
const SAVE_DATA_PARAMETERS := &"parameters"
const SAVE_DATA_PARAMETER_VALUE := &"parameters"

signal pre_created
signal created
signal data_set

@export var data: SynapseStateMachineData:
	set(value):
		if value == null:
			data = SynapseStateMachineData.new()
		else:
			data = value
		update_configuration_warnings()
		data_set.emit()

## If [code]true[/code] (the default), this state machine will activate itself once it is fully
## initialized. Otherwise, it will wait until [method activate] is called.[br][br]
## Has no effect when this state machine is nested within another state machine, since the parent
## state machine controls activation in that case.
@export var activate_on_create := true

var is_created := false
var root: SynapseState
var all_states: Dictionary[StringName, SynapseState] = {}
var all_behaviors: Dictionary[StringName, SynapseBehavior] = {}
var all_parameters: Dictionary[StringName, SynapseParameter] = {}

@warning_ignore("shadowed_variable")
func _init(root: SynapseState = null) -> void:
	if Engine.is_editor_hint():
		return
	self.root = root

## ---------------- OVERRIDES ----------------

func _get_property_list() -> Array[Dictionary]:
	return [
		{
			"name": SynapseStateMachineEditorInspectorPlugin.PARAMETER_GROUP, # SynapseStateMachineEditorInspectorPlugin injects parameter properties here
			"type": TYPE_NIL,
			"usage": PROPERTY_USAGE_GROUP
		},
		{
			"name": SynapseStateMachineEditorInspectorPlugin.PARAMETER_GROUP_SENTINEL,
			"type": TYPE_NIL,
			"usage": PROPERTY_USAGE_EDITOR # prevents Godot from pruning the category for being empty (the plugin will hide this parameter)
		}
	]

func _ready() -> void:
	if data == null:
		data = SynapseStateMachineData.new()

	if not Engine.is_editor_hint():
		# do this first because child state machines need to substitute their parameters with these
		_load_parameters()
	for state_data: SynapseStateData in data.states.values():
		state_data.notify_state_machine_pre_created(self)

	call_deferred(&"_deferred_ready")

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if Engine.is_editor_hint():
		if not data:
			warnings.append("Resource 'data' is required")
	else:
		if not root:
			warnings.append("No root state defined")

	if data:
		if not data.root_state:
			warnings.append("No root state defined")
		for state_data: SynapseStateData in data.states.values():
			if not state_data.parent_name and state_data.name != data.root_state:
				warnings.append("State '" + state_data.name + "' has no parent")
			for warning in state_data.get_configuration_warnings(self):
				warnings.append("[State '%s'] %s" % [state_data.name, warning.get(SynapseEntityData.ConfigurationWarningKey.TEXT)])

		for parameter_data: SynapseParameterData in data.parameters.values():
			for warning in parameter_data.get_configuration_warnings(self):
				warnings.append("[Parameter '%s'] %s" % [parameter_data.name, warning.get(SynapseEntityData.ConfigurationWarningKey.TEXT)])

		for behavior_data: SynapseBehaviorData in data.behaviors.values():
			var behavior_warnings := behavior_data.get_configuration_warnings(self)
			if behavior_warnings:
				var behavior := get_node(behavior_data.node_path)
				if behavior and is_same(behavior.owner, owner):
					warnings.append("Behavior Node '%s' has warnings" % [behavior.name])
				else:
					for warning in behavior_warnings:
						warnings.append("[Behavior '%s'] %s" % [behavior_data.name, warning.get(SynapseEntityData.ConfigurationWarningKey.TEXT)])

		for signal_bridge_data: SynapseSignalBridgeData in data.signal_bridges.values():
			for warning in signal_bridge_data.get_configuration_warnings(self):
				warnings.append("[Signal Bridge '%s'] %s" % [signal_bridge_data.name, warning.get(SynapseEntityData.ConfigurationWarningKey.TEXT)])

	return warnings

## ---------------- PUBLIC METHODS ----------------

func activate() -> void:
	root.enter()

func deactivate() -> void:
	root.exit()

func is_active(state_name: StringName) -> bool:
	var state: SynapseState = all_states.get(state_name)
	if state:
		return state.active
	return false

## Returns a dictionary containing this state machine's save data.[br][br]
## If the state machine was active before this method was called, it will be deactiated until saving
## is complete. This method only creates the save data in memory, so the caller is responsible for
## writing the returned data to the file system (e.g. using [ConfigFile]).
@warning_ignore("unused_parameter")
func get_save_data() -> Dictionary[StringName, Variant]:
	var was_active := root.active
	if was_active:
		deactivate()

	var state_save_datas: Dictionary[StringName, Dictionary] = {}
	var behavior_save_datas: Dictionary[StringName, Dictionary] = {}
	var parameter_save_datas: Dictionary[StringName, Dictionary] = {}
	for state_name in all_states:
		var state_save_data := all_states[state_name].get_save_data()
		if not state_save_data.is_empty():
			state_save_datas[state_name] = state_save_data
	for behavior_name in all_behaviors:
		var behavior_save_data := all_behaviors[behavior_name].get_save_data()
		if not behavior_save_data.is_empty():
			behavior_save_datas[behavior_name] = behavior_save_data
	for parameter_name in all_parameters:
		parameter_save_datas[parameter_name] = { SAVE_DATA_PARAMETER_VALUE: all_parameters[parameter_name].get_value_for_saving() }

	if was_active:
		activate()

	return {
		SAVE_DATA_STATES: state_save_datas,
		SAVE_DATA_BEHAVIORS: behavior_save_datas,
		SAVE_DATA_PARAMETERS: parameter_save_datas,
		SAVE_DATA_GODOT_VERSION : Engine.get_version_info()["string"],
		SAVE_DATA_PLUGIN_VERSION : SynapseVersionInfo.STRING,
		SAVE_DATA_STATE_MACHINE_ACTIVE : was_active,
	}

## Loads the given save data created by [method get_save_data].[br][br]
## If the state machine was active before this method was called, it will be deactiated until
## loading is complete.[br][br]
## Loading is performed in the following order:[br]
## 1. Set [SynapseParameter] values (in arbitrary order)[br]
## 2. Call [method SynapseBehavior.load_save_data] on only those behaviors that returned
## non-[code]null[/code] values from [method SynapseBehavior.get_save_data] (in arbitrary order)[br]
## 3. Call [method SynapseState.load_save_data] on only those states that returned
## non-[code]null[/code] values from [method SynapseState.get_save_data] (in arbitrary order)
@warning_ignore("unused_parameter")
func load_save_data(save_data: Dictionary) -> void:
	var was_active := root.active
	if was_active:
		deactivate()

	var state_save_datas: Dictionary[StringName, Dictionary] = save_data[SAVE_DATA_STATES]
	var behavior_save_datas: Dictionary[StringName, Dictionary] = save_data[SAVE_DATA_BEHAVIORS]
	var parameter_save_datas: Dictionary[StringName, Dictionary] = save_data[SAVE_DATA_PARAMETERS]

	for parameter_name in parameter_save_datas:
		all_parameters[parameter_name].set_from_saved_value(parameter_save_datas[parameter_name][SAVE_DATA_PARAMETER_VALUE], self)
	for behavior_name in behavior_save_datas:
		all_behaviors[behavior_name].load_save_data(behavior_save_datas[behavior_name])
	for state_name in state_save_datas:
		all_states[state_name].load_save_data(state_save_datas[state_name])

	if was_active:
		activate()

## ---------------- INTERNAL METHODS ----------------

func _deferred_ready() -> void:
	if Engine.is_editor_hint():
		if data:
			for behavior_data: SynapseBehaviorData in data.behaviors.values():
				var behavior: SynapseBehavior = get_node(behavior_data.node_path)
				if not behavior.is_node_ready():
					call_deferred(&"_deferred_ready")
					return
				(get_node(behavior_data.node_path) as SynapseBehavior).state_machine = self
			if not owner.is_node_ready():
				call_deferred(&"_deferred_ready")
				return
			# hackery to force configuration warnings to update reliably
			var parent := get_parent()
			var idx := get_index()
			parent.move_child(self, 0)
			parent.move_child(self, idx)
			update_configuration_warnings()
		return

	for state_data: SynapseStateData in data.states.values():
		if not state_data.is_ready(self):
			call_deferred(&"_deferred_ready")
			return
	pre_created.emit()

	if data:
		if not root and data.root_state:
			root = _load_state(data.root_state)

		# do this last because some states can substitute parameters during loading
		_init_behaviors()
		_init_state_signals()
		_init_parameter_signals()
		_init_signal_bridges()

	var warnings := _get_configuration_warnings()
	if not warnings.is_empty():
		for warning in warnings:
			push_warning(warning)
		push_error("Freeing ", self, " due to configuration warnings. Path: ", get_path())
		queue_free()
		return

	for behavior: SynapseBehavior in all_behaviors.values():
		behavior._state_machine_created()
	is_created = true
	created.emit()

	if activate_on_create:
		activate()

func _load_state(state_name: StringName) -> SynapseState:
	if all_states.has(state_name):
		return all_states[state_name]

	var child_states := _load_all_child_states_of(state_name)
	var state := data.states[state_name].instantiate_state(self, child_states, _load_behaviors_owned_by(state_name))
	all_states[state_name] = state

	return state

func _load_behaviors_owned_by(state_name: StringName) -> Array[SynapseBehavior]:
	var behaviors: Array[SynapseBehavior] = []
	for behavior_name in data.states[state_name].behavior_names:
		var behavior_data := data.behaviors[behavior_name]
		if all_behaviors.has(behavior_data.name):
			continue # already registered

		var behavior := get_node(behavior_data.node_path) as SynapseBehavior
		if not behavior:
			push_error("[Behavior '" + behavior_data.name + "'] Unable to find behavior node at path: " + str(behavior_data.node_path))
			continue

		behavior.state_machine = self
		all_behaviors[behavior_data.name] = behavior
		behaviors.append(behavior)

	return behaviors

func _load_all_child_states_of(parent_state_name: StringName) -> Array[SynapseState]:
	var child_states: Array[SynapseState] = []
	for child_state_name in data.states[parent_state_name].child_names:
		child_states.append(_load_state(child_state_name))
	return child_states

func _load_parameters() -> void:
	for parameter_name in data.parameters:
		var parameter_data := data.parameters[parameter_name]
		if not all_parameters.has(parameter_name):
			all_parameters[parameter_name] = parameter_data.parameter.duplicate(true)

func _init_behaviors() -> void:
	for behavior_name in all_behaviors:
		var behavior := all_behaviors[behavior_name]
		var behavior_data := data.behaviors[behavior_name]
		behavior.owner_state = all_states[behavior_data.owner_state_name]
		for variable_name in behavior_data.parameters:
			behavior.set(variable_name, all_parameters[behavior_data.parameters[variable_name]])
		for callable_name in behavior_data.connected_signals:
			for signal_source_data: SynapseSignalSourceData in behavior_data.connected_signals[callable_name]:
				var callable_data := behavior_data.create_callable_data(callable_name, self)
				callable_data.connect_signal(signal_source_data.signal_data.load_signal(self), callable_data.load_callable(self), self)

func _init_state_signals() -> void:
	for state_name in all_states:
		var state_data := data.states[state_name]
		for method_name in state_data.connected_signals:
			for signal_source_data: SynapseSignalSourceData in state_data.connected_signals[method_name]:
				var callable_data := state_data.create_callable_data(method_name, self)
				callable_data.connect_signal(signal_source_data.signal_data.load_signal(self), callable_data.load_callable(self), self)

func _init_parameter_signals() -> void:
	for parameter_name in all_parameters:
		var parameter_data := data.parameters[parameter_name]
		for method_name in parameter_data.connected_signals:
			for signal_source_data: SynapseSignalSourceData in parameter_data.connected_signals[method_name]:
				var callable_data := parameter_data.create_callable_data(method_name, self)
				callable_data.connect_signal(signal_source_data.signal_data.load_signal(self), callable_data.load_callable(self), self)

func _init_signal_bridges() -> void:
	for signal_bridge_data: SynapseSignalBridgeData in data.signal_bridges.values():
		signal_bridge_data.create_bridge(self)

func get_runtime_object_from(ref: SynapseEntityReferenceData) -> Object:
	match ref.entity_type:
		SynapseStateMachineData.EntityType.STATE:
			return all_states[ref.entity_name]
		SynapseStateMachineData.EntityType.BEHAVIOR:
			return all_behaviors[ref.entity_name]
		SynapseStateMachineData.EntityType.PARAMETER:
			return all_parameters[ref.entity_name]
	push_warning("Cannot find runtime object corresponding to unknown reference entity type: ", ref)
	return null
