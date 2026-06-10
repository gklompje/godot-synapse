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
const SAVE_DATA_PARAMETER_VALUE := &"parameters" # FIXME: "value" (needs migration!)

const SYNC_DATA_STATE_MACHINE_ACTIVE = &"active"
const SYNC_DATA_STATES := &"states"
const SYNC_DATA_PARAMETERS := &"parameters"
const SYNC_DATA_PARAMETER_VALUE := &"value"

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

## If [code]true[/code] (the default), this state machine will automatically participate in
## multiplayer synchronization using Godot's high-level multiplayer API when connected to peers.
## Disable this if you don't want to synchronize this state machine, or if you are using a custom
## multiplayer synchronization method.
@export var multiplayer_sync_enabled := false

## The rate (ticks per second) at which differential sync updates are sent to multiplayer peers.
@export var multiplayer_differential_sync_tps := 30.0

## The rate (ticks per second) at which full sync updates are sent to multiplayer peers.
@export var multiplayer_full_sync_tps := 1.0

var is_created := false
var root: SynapseState
var all_states: Dictionary[StringName, SynapseState] = {}
var all_behaviors: Dictionary[StringName, SynapseBehavior] = {}
var all_parameters: Dictionary[StringName, SynapseParameter] = {}

var _sync_signals_connected := false
var _multiplayer_sync_data_baseline := {}
var _time_since_last_differential_sync := 0.0
var _time_since_last_full_sync := 0.0
var _ignore_parameter_value_set_for_sync := false

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

func _physics_process(delta: float) -> void:
	if not is_created:
		return
	_multiplayer_tick(delta)

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

	if save_data.has(SAVE_DATA_STATE_MACHINE_ACTIVE):
		if save_data[SAVE_DATA_STATE_MACHINE_ACTIVE]:
			activate()
	elif was_active:
		activate()

## Returns the multiplayer sync data for this state machine, to send to peers.[br][br]
## If [param differential] is [code]true[/code], only returns the parameter values that have changed
## since the last time differential data was cleared.[br][br]
## If [param differential] is [code]true[/code], the differential data cache is cleared such that
## the next call to this method with [code]differential=true[/code] will only return data that has
## changed after the call with [code]clear_differential=true[/code].
func get_multiplayer_sync_data(differential: bool, clear_differential: bool = true) -> Dictionary:
	if differential:
		# TODO: states (if server... does differential states even make sense? maybe send the whole bunch if *any* state changes occurred)
		var return_data := _multiplayer_sync_data_baseline.duplicate()
		if clear_differential:
			_multiplayer_sync_data_baseline.clear()
		return return_data

	var sync_data := {}
	var is_server := multiplayer.is_server()
	var is_owner := is_multiplayer_authority()

	# server is always authoritative for state replication
	# TODO: provide option to let client owner do this?
	if is_server:
		var state_sync_datas: Dictionary = {}
		for state_name in all_states:
			var state_sync_data := all_states[state_name].get_sync_data()
			if not state_sync_data.is_empty():
				state_sync_datas[state_name] = state_sync_data
		if not state_sync_datas.is_empty():
			sync_data[SYNC_DATA_STATES] = state_sync_datas

	var parameter_sync_datas: Dictionary = {}
	for parameter_name in all_parameters:
		var parameter := all_parameters[parameter_name]
		if parameter.should_replicate(is_server, is_owner):
			parameter_sync_datas[parameter_name] = { SYNC_DATA_PARAMETER_VALUE: parameter.get_value_for_multiplayer_sync() }
	if not parameter_sync_datas.is_empty():
		sync_data[SYNC_DATA_PARAMETERS] = parameter_sync_datas

	if clear_differential:
		_multiplayer_sync_data_baseline.clear()
	return sync_data

## Applies the specified multiplayer sync data produced by another peer's
## [method get_multiplayer_sync_data] to this state machine.[br][br]
func apply_multiplayer_sync_data(sync_data: Dictionary) -> void:
	# states
	var state_sync_datas: Dictionary = sync_data.get(SYNC_DATA_STATES, {})
	for state_name: StringName in state_sync_datas:
		var state_sync_data: Variant = state_sync_datas[state_name]
		if state_sync_data is Dictionary:
			@warning_ignore("unsafe_cast")
			all_states[state_name].apply_sync_data(state_sync_data as Dictionary)
	var parameter_sync_datas: Dictionary = sync_data.get(SYNC_DATA_PARAMETERS, {})

	# parameters (suppress differential tracking while we update them, to prevent duplicate sync spam)
	_ignore_parameter_value_set_for_sync = true
	for parameter_name: StringName in parameter_sync_datas:
		all_parameters[parameter_name].set_from_multiplayer_sync_value(parameter_sync_datas[parameter_name][SYNC_DATA_PARAMETER_VALUE], self)
	_ignore_parameter_value_set_for_sync = false

## ---------------- RPC METHODS ----------------

@rpc("any_peer", "call_remote", "reliable")
func sync_multiplayer_data_full(sync_data: Dictionary) -> void:
	_sync_multiplayer_data(sync_data, multiplayer.get_remote_sender_id(), false)

@rpc("any_peer", "call_remote", "unreliable_ordered")
func sync_multiplayer_data_differential(sync_data: Dictionary) -> void:
	_sync_multiplayer_data(sync_data, multiplayer.get_remote_sender_id(), true)

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

	if multiplayer_sync_enabled:
		multiplayer.peer_connected.connect(_on_multiplayer_peer_connected)
		multiplayer.server_disconnected.connect(_on_multiplayer_server_disconnected)

		if multiplayer.has_multiplayer_peer() and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.ConnectionStatus.CONNECTION_CONNECTED:
			var is_server := multiplayer.is_server()
			var is_owner := is_multiplayer_authority()
			for peer_id in multiplayer.get_peers():
				_handle_multiplayer_peer_connected(peer_id, is_server, is_owner)

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

func _sync_multiplayer_data(sync_data: Dictionary, sender_id: int, differential: bool) -> void:
	if sender_id == 0:
		push_error("Local invocation of RPC method _sync_multiplayer_data not supported- use apply_multiplayer_sync_data")
		return

	if not multiplayer.is_server() and sender_id != 1:
		# never accept calls from anyone but the server
		push_warning("Rejecting sync data from non-server peer ", sender_id, ": ", sync_data)
		return

	if is_created:
		_handle_multiplayer_sync_data(sync_data, sender_id, differential)
	elif not differential:
		# full sync data is important- queue it for processing when we're ready
		# TODO: clobber by peer ID
		created.connect(_handle_multiplayer_sync_data.bind(sync_data, sender_id, differential), CONNECT_ONE_SHOT)

func _handle_multiplayer_sync_data(sync_data: Dictionary, sender_id: int, differential: bool) -> void:
	var is_server := multiplayer.is_server()
	var sender_is_server := sender_id == 1

	if is_server and sender_is_server:
		push_error("Unable to reconcile who is the server. This state machine thinks it is the server, but got data from a peer ID 1.")
		return

	# only include state data if it's from the server
	var valid_data := {}
	if sender_is_server:
		# trust the server
		valid_data = sync_data
	else:
		# only include parameter values we know the peer is supposed to send
		var sender_is_owner := sender_id == get_multiplayer_authority()
		if sync_data.has(SYNC_DATA_PARAMETERS) and sync_data[SYNC_DATA_PARAMETERS] is Dictionary:
			var valid_param_data := {}
			var param_sync_data: Dictionary = sync_data[SYNC_DATA_PARAMETERS]
			for parameter_name: StringName in param_sync_data:
				# TODO: parameter validation
				var parameter: SynapseParameter = all_parameters.get(parameter_name)
				if parameter and parameter.should_replicate(false, sender_is_owner):
					valid_param_data[parameter_name] = param_sync_data[parameter_name]
			if not valid_param_data.is_empty():
				valid_data[SYNC_DATA_PARAMETERS] = valid_param_data

	if valid_data.is_empty():
		return

	apply_multiplayer_sync_data(valid_data)
	if is_server:
		# broadcast update from server to all clients
		for peer_id in multiplayer.get_peers():
			if peer_id != sender_id:
				if differential:
					sync_multiplayer_data_differential.rpc_id(peer_id, valid_data)
				else:
					sync_multiplayer_data_full.rpc_id(peer_id, valid_data)

func _multiplayer_tick(delta: float) -> void:
	if not multiplayer_sync_enabled or multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.ConnectionStatus.CONNECTION_CONNECTED:
		return

	_time_since_last_differential_sync += delta
	_time_since_last_full_sync += delta
	var full := _time_since_last_full_sync >= 1.0 / multiplayer_full_sync_tps
	var differential := not full and _time_since_last_differential_sync >= 1.0 / multiplayer_differential_sync_tps
	if full or differential:
		var sync_data := get_multiplayer_sync_data(differential)
		if not sync_data.is_empty():
			if multiplayer.is_server():
				# broadcast server data to everyone
				if differential:
					sync_multiplayer_data_differential.rpc(sync_data)
				else:
					sync_multiplayer_data_full.rpc(sync_data)
			else:
				# send client data to server
				if differential:
					sync_multiplayer_data_differential.rpc_id(1, sync_data)
				else:
					sync_multiplayer_data_full.rpc_id(1, sync_data)

		if full:
			_time_since_last_full_sync = 0.0
		_time_since_last_differential_sync = 0.0

func _handle_multiplayer_peer_connected(id: int, is_server: bool, is_owner: bool) -> void:
	if not _sync_signals_connected:
		for parameter_name in all_parameters:
			var parameter := all_parameters[parameter_name]
			if parameter.should_replicate(is_server, is_owner):
				@warning_ignore("unsafe_property_access", "unsafe_method_access")
				parameter.value_set.connect(_on_parameter_value_set_for_sync.bind(parameter_name))
		_sync_signals_connected = true

	var full_sync_data := get_multiplayer_sync_data(false, false)
	if is_server:
		# send server data to new peer
		sync_multiplayer_data_full.rpc_id(id, full_sync_data)
	else:
		# send client data to server (to forward to all peers, including the new peer)
		sync_multiplayer_data_full.rpc_id(1, full_sync_data)
		_time_since_last_differential_sync = 0.0
		_time_since_last_full_sync = 0.0

## ---------------- SIGNAL HANDLERS ----------------

func _on_multiplayer_peer_connected(id: int) -> void:
	var is_server := multiplayer.is_server()
	var is_owner := is_multiplayer_authority()
	if is_created:
		_handle_multiplayer_peer_connected(id, is_server, is_owner)
	else:
		created.connect(_handle_multiplayer_peer_connected.bind(id, is_server, is_owner), CONNECT_ONE_SHOT)

func _on_multiplayer_server_disconnected() -> void:
	if _sync_signals_connected:
		for parameter_name in all_parameters:
			var parameter := all_parameters[parameter_name]
			@warning_ignore("unsafe_property_access")
			var sig: Signal = parameter.value_set
			if sig.is_connected(_on_parameter_value_set_for_sync):
				sig.disconnect(_on_parameter_value_set_for_sync)
	_sync_signals_connected = false

func _on_parameter_value_set_for_sync(_new_value: Variant, parameter_name: StringName) -> void:
	if _ignore_parameter_value_set_for_sync:
		return
	# TODO: set value to sentinel (e.g. 'true'), only call get_value_for_multiplayer_sync() when sending
	_multiplayer_sync_data_baseline.get_or_add(SYNC_DATA_PARAMETERS, {})[parameter_name] = { SYNC_DATA_PARAMETER_VALUE: all_parameters[parameter_name].get_value_for_multiplayer_sync() }
