@tool
class_name SynapseStateMachineEditor
extends GraphEdit

const DELETE_CONNECTION_DISTANCE_THRESHOLD := 80.0
const INPUT_KEY__DELETE_CONNECTION := KEY_ALT
const INPUT_KEY__FORCE_SIGNAL_BRIDGE := KEY_CTRL

enum ConnectionType {
	NONE,
	PARENT, # child's input connection
	CHILD, # parent's output connection to child(ren)
	TRANSITION_FROM, # state's input from sibling that can transition to it
	TRANSITION_TO, # state's output to sibling it can transition to
	BEHAVIOR_IN, # behavior input from owning state
	BEHAVIOR_OUT, # state's output to owned behavior(s)
	PARAMETER_RO, # behavior's LHS for a read-only parameter
	PARAMETER_RW, # behavior's RHS for a read/write parameter
	PARAMETER_READER, # parameter's RHS for reader behavior
	PARAMETER_WRITER, # parameter's LHS for writer behavior
	SIGNAL_OUT, # signal RHS for emitting
	SIGNAL_IN, # signal LHS for receiving
	PROPERTY_REFERENCE_OUT, # property reference provider
	PROPERTY_REFERENCE_IN, # property reference receiver
	EXPOSE_CALLABLE, # root sentinel output slot for exposing callables
	EXPOSE_SIGNAL, # root sentinel input slot for exposing signals
}

class ConnectionProxy:
	signal remove_requested

	var from_graph_node: SynapseStateMachineEditorGraphNode
	var from_slot: StringName
	var to_graph_node: SynapseStateMachineEditorGraphNode
	var to_slot: StringName
	var graph_connection: Dictionary = {} # empty while not added to the graph

	func _get_node_descr(node: SynapseStateMachineEditorGraphNode, slot_name: StringName) -> String:
		if node is SynapseRootSentinelGraphNode:
			return "RootSentinel." + slot_name
		else:
			return "[%s]%s.%s" % [SynapseStateMachineData.get_entity_type_name(node.get_entity_type()), node.get_entity_name(), slot_name]

	func _to_string() -> String:
		return "%s → %s" % [_get_node_descr(from_graph_node, from_slot), _get_node_descr(to_graph_node, to_slot)]

	func get_midpoint() -> Vector2:
		if graph_connection.is_empty():
			return Vector2.ZERO
		var start_pos := from_graph_node.position_offset + from_graph_node.get_output_port_position(from_graph_node.get_output_port_number(from_slot))
		var end_pos := to_graph_node.position_offset + to_graph_node.get_input_port_position(to_graph_node.get_input_port_number(to_slot))
		return (start_pos + end_pos) / 2.0

	@warning_ignore("shadowed_variable")
	static func of(from_node: SynapseStateMachineEditorGraphNode, from_slot: StringName, to_node: SynapseStateMachineEditorGraphNode, to_slot: StringName) -> ConnectionProxy:
		var proxy := ConnectionProxy.new()
		proxy.from_graph_node = from_node
		proxy.from_slot = from_slot
		proxy.to_graph_node = to_node
		proxy.to_slot = to_slot
		return proxy

@onready var add_state_popup_menu: PopupMenu = %AddStatePopupMenu
@onready var add_behavior_popup_menu: PopupMenu = %AddBehaviorPopupMenu
@onready var add_parameter_with_value_type_popup_menu: PopupMenu = %AddParameterWithValueTypePopupMenu
@onready var add_entity_popup_menu: PopupMenu = %AddEntityPopupMenu
@onready var erase_confirmation_dialog: ConfirmationDialog = %EraseConfirmationDialog
@onready var delete_connection_button: TextureButton = %DeleteConnectionButton

# environment
var state_machine: SynapseStateMachine
var undo_redo: EditorUndoRedoManager
var resource_cache: SynapseStateMachineEditorResourceCache
var previous_data: SynapseStateMachineData # keep a reference to disconnect signals when it's removed

# graph nodes
var root_sentinel: SynapseRootSentinelGraphNode
var state_graph_nodes: Dictionary[StringName, SynapseStateGraphNode] = {}
var behavior_graph_nodes: Dictionary[StringName, SynapseBehaviorGraphNode] = {}
var parameter_graph_nodes: Dictionary[StringName, SynapseParameterGraphNode] = {}
var signal_bridge_graph_nodes: Dictionary[StringName, SynapseSignalBridgeGraphNode] = {}

# connections
var _connections_dirty := false
var _connection_proxies: Array[ConnectionProxy]

# temporary variables used by multi-step UI actions
var _graph_position: Vector2
var _parent_is_root: bool
var _parent_state_name: StringName
var _state_data_options: Dictionary[int, Array] # [ <menu_option_number> : [ SynapseStateData, SynapseStateData.get_options()[<n>] ] 
var _behavior_add_menu_scripts: Dictionary[int, Script]
var _parameter_link_target: SynapseStateMachineEditorGraphNode
var _parameter_link_target_slot_name: StringName
var _closest_connection_proxy_for_deletion: ConnectionProxy
var _closest_connection_curve: Curve2D

## ---------------- OVERRIDES ----------------

func _gui_input(event: InputEvent) -> void:
	if Input.is_key_pressed(INPUT_KEY__DELETE_CONNECTION):
		if event is InputEventMouseMotion:
			update_closest_removable_connection((get_local_mouse_position() + scroll_offset) / zoom)
	else:
		_closest_connection_proxy_for_deletion = null
		_closest_connection_curve = null
		delete_connection_button.hide()

func _is_node_hover_valid(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> bool:
	if is_same(from_node, to_node):
		# can't connect to self
		return false

	var from_graph_node := get_node(NodePath(from_node)) as SynapseStateMachineEditorGraphNode
	var to_graph_node := get_node(NodePath(to_node)) as SynapseStateMachineEditorGraphNode
	if not from_graph_node or not to_graph_node:
		return false

	var from_connection_type := from_graph_node.get_connection_type_for_output_port(from_port)
	var to_connection_type := to_graph_node.get_connection_type_for_input_port(to_port)
	if not is_valid_connection_type(from_connection_type, to_connection_type):
		return false

	var from_slot_name := from_graph_node.get_slot_name_for_output_port(from_port)
	var to_slot_name := to_graph_node.get_slot_name_for_input_port(to_port)

	if from_connection_type == ConnectionType.EXPOSE_CALLABLE and from_graph_node is SynapseRootSentinelGraphNode and from_slot_name == SynapseRootSentinelGraphNode.SLOT_EXPOSE_SIGNAL_OR_CALLABLE:
		var callable_name: StringName = to_graph_node.get_signal_receive_slot_callable_info(to_slot_name)["name"]
		var entity := state_machine.data.get_entity(to_graph_node.get_entity_type(), to_graph_node.get_entity_name())
		return not state_machine.data.exposed_callables.values().any(func(ref: SynapseEntityPropertyReferenceData) -> bool: return ref.entity_reference.references(entity) and ref.property_name == callable_name)
	elif to_connection_type == ConnectionType.EXPOSE_SIGNAL and to_graph_node is SynapseRootSentinelGraphNode and to_slot_name == SynapseRootSentinelGraphNode.SLOT_EXPOSE_SIGNAL_OR_CALLABLE:
		var signal_name: StringName = from_graph_node.get_emitted_signal_info(from_slot_name)["name"]
		var entity := state_machine.data.get_entity(from_graph_node.get_entity_type(), from_graph_node.get_entity_name())
		return not state_machine.data.exposed_signals.values().any(func(ref: SynapseEntityPropertyReferenceData) -> bool: return ref.entity_reference.references(entity) and ref.property_name == signal_name)
	elif to_connection_type == ConnectionType.PROPERTY_REFERENCE_IN and to_graph_node is SynapseSignalBridgeGraphNode:
		var argument_info := (to_graph_node as SynapseSignalBridgeGraphNode).get_argument_info(to_slot_name)
		if not SynapseClassUtil.is_argument_compatible(from_graph_node.get_runtime_property_info(from_slot_name), argument_info):
			return false
		@warning_ignore("unsafe_cast")
		var argument_name := argument_info["name"] as String
		var signal_bridge_data := state_machine.data.signal_bridges[to_graph_node.get_entity_name()]
		return not signal_bridge_data.property_references.has(argument_name)\
				or signal_bridge_data.property_references[argument_name].entity_reference.entity_type != from_graph_node.get_entity_type()\
				or signal_bridge_data.property_references[argument_name].entity_reference.entity_name != from_graph_node.get_entity_name()
	elif from_connection_type == ConnectionType.SIGNAL_OUT and to_connection_type == ConnectionType.SIGNAL_IN:
		if to_graph_node.can_receive_signals():
			@warning_ignore("unsafe_cast")
			var signal_name := from_graph_node.get_emitted_signal_info(from_slot_name)["name"] as StringName
			@warning_ignore("unsafe_cast")
			var callable_name := to_graph_node.get_signal_receive_slot_callable_info(to_slot_name)["name"] as StringName
			return not state_machine.data.has_existing_signal_connection(from_graph_node.get_entity_type(), from_graph_node.get_entity_name(), signal_name, to_graph_node.get_entity_type(), to_graph_node.get_entity_name(), callable_name)
	elif from_graph_node is SynapseStateGraphNode and to_graph_node is SynapseBehaviorGraphNode:
		return state_machine.data.behaviors[to_graph_node.get_entity_name()].owner_state_name != from_graph_node.get_entity_name()
	elif from_graph_node is SynapseRootSentinelGraphNode and from_connection_type == ConnectionType.CHILD:
		# already the root
		return state_machine.data.root_state != to_graph_node.get_entity_name()
	elif from_graph_node is SynapseStateGraphNode and to_graph_node is SynapseStateGraphNode:
		match from_connection_type:
			ConnectionType.TRANSITION_TO:
				var from_state_data := state_machine.data.states[from_graph_node.get_entity_name()]
				var to_state_data := state_machine.data.states[to_graph_node.get_entity_name()]
				if from_state_data.parent_name != to_state_data.parent_name:
					return false
				return state_machine.data.states[from_state_data.parent_name].can_create_child_transition(from_state_data, to_state_data)
			ConnectionType.CHILD:
				if state_machine.data.states[to_graph_node.get_entity_name()].parent_name == from_graph_node.get_entity_name():
					# already related
					return false
				else:
					var from_state_data := state_machine.data.states[from_graph_node.get_entity_name()]
					var max_child_count := from_state_data.get_max_child_count()
					if max_child_count >= 0 and state_machine.data.states[from_graph_node.get_entity_name()].child_names.size() >= max_child_count:
						return false

					# prevent cyclic ancestry
					var current_parent_state_name := from_graph_node.get_entity_name()
					while current_parent_state_name:
						if current_parent_state_name == to_graph_node.get_entity_name():
							return false
						current_parent_state_name = state_machine.data.states[current_parent_state_name].parent_name
				return true
			_:
				return false
	elif from_graph_node is SynapseParameterGraphNode and from_connection_type == ConnectionType.PARAMETER_READER and to_connection_type == ConnectionType.PARAMETER_RO:
		var parameter_data := state_machine.data.parameters[from_graph_node.get_entity_name()]
		var referencing_entity_data := state_machine.data.get_entity(to_graph_node.get_entity_type(), to_graph_node.get_entity_name())
		return referencing_entity_data.can_reference_parameter(parameter_data, to_slot_name, state_machine)
	elif to_graph_node is SynapseParameterGraphNode and from_connection_type == ConnectionType.PARAMETER_RW and to_connection_type == ConnectionType.PARAMETER_WRITER:
		var parameter_data := state_machine.data.parameters[to_graph_node.get_entity_name()]
		var referencing_entity_data := state_machine.data.get_entity(from_graph_node.get_entity_type(), from_graph_node.get_entity_name())
		return referencing_entity_data.can_reference_parameter(parameter_data, from_slot_name, state_machine)

	return false

## ---------------- "private" METHODS ----------------

func _clear_graph() -> void:
	# clear root sentinel
	if is_instance_valid(root_sentinel):
		root_sentinel.queue_free()
		root_sentinel = null

	# clear state graph nodes
	for graph_node: SynapseStateGraphNode in state_graph_nodes.values():
		graph_node.queue_free()
	state_graph_nodes.clear()

	# clear behavior graph nodes
	for graph_node: SynapseBehaviorGraphNode in behavior_graph_nodes.values():
		graph_node.queue_free()
	behavior_graph_nodes.clear()

	# clear parameter graph nodes
	for graph_node: SynapseParameterGraphNode in parameter_graph_nodes.values():
		graph_node.queue_free()
	parameter_graph_nodes.clear()

	# clear signal bridge graph nodes
	for graph_node: SynapseSignalBridgeGraphNode in signal_bridge_graph_nodes.values():
		graph_node.queue_free()
	signal_bridge_graph_nodes.clear()

	# clear graph connections
	_connection_proxies.clear()
	update_connections()

	# reset offset & zoom
	scroll_offset = Vector2.ZERO
	zoom = 1.0

func _dissociate_data(data: SynapseStateMachineData) -> void:
	data.root_state_set.disconnect(_on_state_machine_data_root_state_set)
	data.entity_renamed.disconnect(_on_state_machine_data_entity_renamed)
	data.entity_callable_exposed.disconnect(_on_state_machine_data_entity_callable_exposed)
	data.entity_callable_unexposed.disconnect(_on_state_machine_data_entity_callable_unexposed)
	data.exposed_entity_callable_renamed.disconnect(_on_state_machine_data_exposed_entity_callable_renamed)
	data.entity_signal_exposed.disconnect(_on_state_machine_data_entity_signal_exposed)
	data.entity_signal_unexposed.disconnect(_on_state_machine_data_entity_signal_unexposed)
	data.exposed_entity_signal_renamed.disconnect(_on_state_machine_data_exposed_entity_signal_renamed)
	data.state_added.disconnect(_on_state_machine_data_state_added)
	data.state_removed.disconnect(_on_state_machine_data_state_removed)
	data.state_child_added.disconnect(_on_state_machine_data_state_child_added)
	data.state_child_removed.disconnect(_on_state_machine_data_state_child_removed)
	data.state_child_order_changed.disconnect(_on_state_machine_data_state_child_order_changed)
	data.state_behavior_order_changed.disconnect(_on_state_machine_data_state_behavior_order_changed)
	data.state_connected_to_signal.disconnect(_on_state_machine_data_state_connected_to_signal)
	data.state_disconnected_from_signal.disconnect(_on_state_machine_data_state_disconnected_from_signal)
	data.behavior_added.disconnect(_on_state_machine_data_behavior_added)
	data.behavior_removed.disconnect(_on_state_machine_data_behavior_removed)
	data.behavior_added_to_state.disconnect(_on_state_machine_data_behavior_added_to_state)
	data.behavior_removed_from_state.disconnect(_on_state_machine_data_behavior_removed_from_state)
	data.behavior_connected_to_signal.disconnect(_on_state_machine_data_behavior_connected_to_signal)
	data.behavior_disconnected_from_signal.disconnect(_on_state_machine_data_behavior_disconnected_from_signal)
	data.parameter_added.disconnect(_on_state_machine_data_parameter_added)
	data.parameter_removed.disconnect(_on_state_machine_data_parameter_removed)
	data.parameter_reference_added.disconnect(_on_state_machine_data_parameter_reference_added)
	data.parameter_reference_removed.disconnect(_on_state_machine_data_parameter_reference_removed)
	data.parameter_exposed_set.disconnect(_on_state_machine_data_parameter_exposed_set)
	data.parameter_connected_to_signal.disconnect(_on_state_machine_data_parameter_connected_to_signal)
	data.parameter_disconnected_from_signal.disconnect(_on_state_machine_data_parameter_disconnected_from_signal)
	data.signal_bridge_added.disconnect(_on_state_machine_data_signal_bridge_added)
	data.signal_bridge_removed.disconnect(_on_state_machine_data_signal_bridge_removed)
	data.signal_bridge_signal_property_wired.disconnect(_on_state_machine_data_signal_bridge_signal_property_wired)
	data.signal_bridge_signal_property_unwired.disconnect(_on_state_machine_data_signal_bridge_signal_property_unwired)
	data.signal_bridge_property_reference_assigned.disconnect(_on_state_machine_data_signal_bridge_property_reference_assigned)
	data.signal_bridge_property_reference_unassigned.disconnect(_on_state_machine_data_signal_bridge_property_reference_unassigned)

	for state_data: SynapseStateData in previous_data.states.values():
		state_data.teardown_in_editor(self, previous_data)

## ---------------- "public" METHODS ----------------

# typically this stuff goes in _ready, but we don't want this to run when opening the editor scene
@warning_ignore("shadowed_variable")
func prepare_in_plugin(undo_redo_manager: EditorUndoRedoManager, resource_cache: SynapseStateMachineEditorResourceCache) -> void:
	self.undo_redo = undo_redo_manager
	self.resource_cache = resource_cache

	add_valid_connection_type(ConnectionType.CHILD, ConnectionType.PARENT)
	add_valid_connection_type(ConnectionType.TRANSITION_TO, ConnectionType.TRANSITION_FROM)
	add_valid_connection_type(ConnectionType.BEHAVIOR_OUT, ConnectionType.BEHAVIOR_IN)
	add_valid_connection_type(ConnectionType.PARAMETER_READER, ConnectionType.PARAMETER_RO)
	add_valid_connection_type(ConnectionType.PARAMETER_RW, ConnectionType.PARAMETER_WRITER)
	add_valid_connection_type(ConnectionType.SIGNAL_OUT, ConnectionType.SIGNAL_IN)
	add_valid_connection_type(ConnectionType.PARAMETER_READER, ConnectionType.PROPERTY_REFERENCE_IN)
	add_valid_connection_type(ConnectionType.PROPERTY_REFERENCE_OUT, ConnectionType.PROPERTY_REFERENCE_IN)
	add_valid_connection_type(ConnectionType.SIGNAL_OUT, ConnectionType.EXPOSE_SIGNAL)
	add_valid_connection_type(ConnectionType.EXPOSE_CALLABLE, ConnectionType.SIGNAL_IN)

	var erase_button := Button.new()
	erase_button.icon = SynapseStateMachineEditorResourceManager.Icons.get_icon(SynapseStateMachineEditorResourceManager.Icons.UI_ERASE_STATE_MACHINE)
	erase_button.tooltip_text = "Erase the entire state machine. Can be undone."
	erase_button.pressed.connect(_on_erase_button_pressed)
	get_menu_hbox().add_child(erase_button)

@warning_ignore("shadowed_variable")
func select_state_machine(state_machine: SynapseStateMachine) -> void:
	if is_same(state_machine, self.state_machine):
		return
	load_state_machine(state_machine)

@warning_ignore("shadowed_variable")
func load_state_machine(state_machine: SynapseStateMachine) -> void:
	unload_state_machine()

	self.state_machine = state_machine
	self.state_machine.data_set.connect(_on_state_machine_data_set)
	self.state_machine.tree_exiting.connect(unload_state_machine)
	if state_machine.data:
		_on_state_machine_data_set()
	else:
		state_machine.data = SynapseStateMachineData.new()

func unload_state_machine() -> void:
	if is_instance_valid(state_machine):
		state_machine.data_set.disconnect(_on_state_machine_data_set)
		state_machine.tree_exiting.disconnect(unload_state_machine)

		if state_machine.data:
			_dissociate_data(state_machine.data)
	previous_data = null

	_clear_graph()
	state_machine = null

func refresh_graph() -> void:
	if state_machine:
		load_state_machine(state_machine)

# called when a parameter value is updated by the inspector plugin
func notify_parameter_value_updated(parameter_name: StringName) -> void:
	parameter_graph_nodes[parameter_name].value_editor.update_property()
	state_machine.update_configuration_warnings()

## ---------------- INTERNAL UTILITIES ----------------

func get_behavior_for(behavior_data: SynapseBehaviorData) -> SynapseBehavior:
	var behavior := state_machine.get_node(behavior_data.node_path) as SynapseBehavior
	if not behavior:
		push_error("Unable to find behavior at path relative to state machine: ", behavior_data.node_path)
		return null
	return behavior

func create_behavior_graph_node(behavior_data: SynapseBehaviorData) -> SynapseBehaviorGraphNode:
	var graph_node := SynapseStateMachineEditorResourceManager.Scenes.instantiate_behavior_graph_node()
	@warning_ignore("unsafe_cast")
	add_child(graph_node)
	graph_node.name = behavior_data.name
	graph_node.position_offset = behavior_data.graph_pos
	behavior_graph_nodes[behavior_data.name] = graph_node
	graph_node.dragged.connect(_on_behavior_node_moved.bind(graph_node))
	graph_node.name_update_requested.connect(_on_behavior_name_change_requested.bind(graph_node))
	graph_node.setup_for(behavior_data, state_machine)
	graph_node.slots_updated.connect(update_connections)
	return graph_node

func create_state_graph_node(state_name: StringName, pos: Vector2) -> SynapseStateGraphNode:
	var graph_node := SynapseStateMachineEditorResourceManager.Scenes.instantiate_state_graph_node()
	graph_node.position_offset = pos
	add_child(graph_node)
	graph_node.name = state_name
	graph_node.name_update_requested.connect(_on_state_name_change_requested.bind(graph_node))
	state_graph_nodes[state_name] = graph_node
	graph_node.dragged.connect(_on_state_node_moved.bind(graph_node))
	graph_node.state_child_order_changed.connect(_on_state_graph_node_child_order_changed.bind(state_name))
	graph_node.behavior_order_changed.connect(_on_state_graph_node_behavior_order_changed.bind(state_name))
	graph_node.slots_updated.connect(update_connections)
	return graph_node

func create_parameter_graph_node(parameter_data: SynapseParameterData) -> SynapseParameterGraphNode:
	var graph_node := SynapseStateMachineEditorResourceManager.Scenes.instantiate_parameter_graph_node()
	@warning_ignore("unsafe_cast")
	graph_node.position_offset = parameter_data.graph_pos
	add_child(graph_node)
	graph_node.name = parameter_data.name
	parameter_graph_nodes[parameter_data.name] = graph_node
	graph_node.dragged.connect(_on_parameter_node_moved.bind(graph_node))
	graph_node.name_update_requested.connect(_on_parameter_name_change_requested.bind(graph_node))
	graph_node.setup_for(state_machine.data.parameters[parameter_data.name], undo_redo, state_machine)
	graph_node.parameter_value_set.connect(_on_parameter_value_set)
	graph_node.slots_updated.connect(update_connections)
	return graph_node

func create_signal_bridge_graph_node(signal_bridge_data: SynapseSignalBridgeData) -> SynapseSignalBridgeGraphNode:
	var graph_node := SynapseStateMachineEditorResourceManager.Scenes.instantiate_signal_bridge_graph_node()
	@warning_ignore("unsafe_cast")
	graph_node.position_offset = signal_bridge_data.graph_pos
	add_child(graph_node)
	graph_node.name = signal_bridge_data.name
	signal_bridge_graph_nodes[signal_bridge_data.name] = graph_node
	graph_node.dragged.connect(_on_signal_bridge_node_moved.bind(graph_node))
	graph_node.name_update_requested.connect(_on_signal_bridge_name_change_requested.bind(graph_node))
	@warning_ignore("unsafe_cast")
	var signal_source_data := signal_bridge_data.connected_signals[SynapseSignalBridgeData.CALLABLE_NAME][0] as SynapseSignalSourceData
	var source_graph_node := get_graph_node_for_reference(signal_source_data.source_entity_reference)
	var source_slot_name := source_graph_node.get_slot_name_for_emitted_signal_name(signal_source_data.signal_id)
	var target_graph_node := get_graph_node_for_reference(signal_bridge_data.callable_target_data.target_entity_reference)
	var target_slot_name := target_graph_node.get_slot_name_for_signal_receive_callable_name(signal_bridge_data.callable_target_data.callable_id)
	graph_node.setup_for(signal_bridge_data, source_graph_node.get_emitted_signal_info(source_slot_name), target_graph_node.get_signal_receive_slot_callable_info(target_slot_name))
	graph_node.slots_updated.connect(update_connections)
	graph_node.signal_argument_wired.connect(_on_signal_bridge_argument_wired.bind(graph_node))
	graph_node.signal_argument_unwired.connect(_on_signal_bridge_argument_unwired.bind(graph_node))
	return graph_node

func validate_state_name(proposed_name: String) -> StringName:
	return SynapseGUIUtil.validate_name(proposed_name, Callable.create(state_graph_nodes, "has"))

func validate_behavior_name(proposed_name: String) -> StringName:
	return SynapseGUIUtil.validate_name(proposed_name, Callable.create(behavior_graph_nodes, "has"))

func validate_parameter_name(proposed_name: String) -> StringName:
	return SynapseGUIUtil.validate_name(proposed_name, Callable.create(parameter_graph_nodes, "has"))

func validate_signal_bridge_name(proposed_name: String) -> StringName:
	return SynapseGUIUtil.validate_name(proposed_name, Callable.create(signal_bridge_graph_nodes, "has"))

func set_root_sentinel_position(pos: Vector2) -> void:
	root_sentinel.position_offset = pos
	state_machine.data.root_pos = pos
	state_machine.data.emit_changed()

func set_state_node_position(state_name: StringName, pos: Vector2) -> void:
	state_graph_nodes[state_name].position_offset = pos
	state_machine.data.states[state_name].graph_pos = pos
	state_machine.data.emit_changed()

func set_behavior_graph_node_position(behavior_name: StringName, pos: Vector2) -> void:
	behavior_graph_nodes[behavior_name].position_offset = pos
	state_machine.data.behaviors[behavior_name].graph_pos = pos
	state_machine.data.emit_changed()

func set_parameter_graph_node_position(parameter_name: StringName, pos: Vector2) -> void:
	parameter_graph_nodes[parameter_name].position_offset = pos
	state_machine.data.parameters[parameter_name].graph_pos = pos
	state_machine.data.emit_changed()

func set_signal_bridge_graph_node_position(signal_bridge_name: StringName, pos: Vector2) -> void:
	signal_bridge_graph_nodes[signal_bridge_name].position_offset = pos
	state_machine.data.signal_bridges[signal_bridge_name].graph_pos = pos
	state_machine.data.emit_changed()

func set_signal_bridge_name(current_name: StringName, new_name: StringName) -> void:
	state_machine.data.rename_entity(SynapseStateMachineData.EntityType.SIGNAL_BRIDGE, current_name, new_name)

func populate_state_add_menu(menu: PopupMenu) -> int:
	_state_data_options.clear()
	var current_id := 1000
	var datas: Array[SynapseStateData] = []
	for data_script in resource_cache.get_cached_state_data_scripts():
		@warning_ignore("unsafe_cast")
		datas.append((data_script.load_script() as GDScript).new())
	datas.sort_custom(func(d1: SynapseStateData, d2: SynapseStateData) -> bool: return d1.get_type_name().naturalcasecmp_to(d2.get_type_name()) < 0)
	for data in datas:
		var data_options := data.get_options(state_machine)
		if data_options.size() >= 1:
			var data_menu := menu
			if data_options.size() > 1:
				data_menu = PopupMenu.new()
				menu.add_submenu_node_item(data.get_type_name(), data_menu, current_id)
				menu.set_item_icon(menu.get_item_index(current_id), data.get_type_icon())
				data_menu.id_pressed.connect(_on_add_state_popup_menu_item_selected)
				current_id += 1
			for option in data_options:
				_state_data_options[current_id] = [ data, option ]
				@warning_ignore("unsafe_cast")
				data_menu.add_icon_item(option[SynapseStateData.Option.ICON] as Texture2D, option[SynapseStateData.Option.NAME] as String, current_id)
				current_id += 1
	return current_id

func show_state_add_popup(pos: Vector2) -> void:
	add_state_popup_menu.position = pos
	add_state_popup_menu.clear(true)
	add_state_popup_menu.add_separator("Add State")
	populate_state_add_menu(add_state_popup_menu)
	add_state_popup_menu.popup()

func populate_behaviors_by_category(menu: PopupMenu) -> int:
	var script_categories: Dictionary[StringName, Array] = {}
	for script in SynapseClassUtil.find_scripts_implementing(&"SynapseBehavior"):
		if not script.get_global_name():
			push_warning("Found script extending SynapseBehavior without a global class_name - ignoring: ", script.resource_path)
			continue
		var category := SynapseBehavior.CATEGORY_NONE
		var script_category: Variant = SynapseClassUtil.call_static_method_on_script_or_base_classes(script, &"get_category")
		if script_category:
			category = script_category
		@warning_ignore("unsafe_cast")
		(script_categories.get_or_add(category, []) as Array).append([script.get_global_name(), script])

	_behavior_add_menu_scripts.clear()
	var script_category_keys := script_categories.keys()
	script_category_keys.sort_custom(func(a: StringName, b: StringName) -> bool:
		if a == SynapseBehavior.CATEGORY_NONE:
			return false
		elif b == SynapseBehavior.CATEGORY_NONE:
			return true
		else:
			return a.naturalcasecmp_to(b)
	)
	var menu_id := 1
	for category: StringName in script_category_keys:
		var class_names_and_scripts := script_categories[category]
		@warning_ignore("unsafe_cast")
		class_names_and_scripts.sort_custom(func(a1: Array, a2: Array) -> bool: return (a1[0] as String).naturalcasecmp_to(a2[0] as String) < 0)
		var menu_to_populate := menu
		if category != SynapseBehavior.CATEGORY_NONE:
			menu_to_populate = PopupMenu.new()
			menu_to_populate.id_pressed.connect(_on_add_behavior_popup_menu_id_pressed)
			menu.add_submenu_node_item(category, menu_to_populate, menu_id)
			menu_id += 1
		for class_name_and_script: Array in class_names_and_scripts:
			@warning_ignore("unsafe_cast")
			var type_name := SynapseClassUtil.call_static_method_on_script_or_base_classes(class_name_and_script[1] as Script, &"get_type_name", class_name_and_script[1] as Script) as String
			@warning_ignore("unsafe_cast")
			menu_to_populate.add_icon_item(SynapseClassUtil.get_script_icon(class_name_and_script[1] as Script), type_name, menu_id)
			_behavior_add_menu_scripts[menu_id] = class_name_and_script[1]
			menu_id += 1
	return menu_id

func show_behavior_add_popup(pos: Vector2) -> void:
	add_behavior_popup_menu.clear(true)
	add_behavior_popup_menu.add_separator("Create new:")

	var menu_id := populate_behaviors_by_category(add_behavior_popup_menu)

	var behaviors: Array[SynapseBehavior] = []
	for behavior: SynapseBehavior in SynapseClassUtil.find_all_child_nodes_of(state_machine.owner, &"SynapseBehavior"):
		if not is_instance_valid(behavior.state_machine):
			behaviors.append(behavior)
	if behaviors:
		add_behavior_popup_menu.add_separator("Unused in scene:")
		for behavior in behaviors:
			@warning_ignore("unsafe_cast")
			add_behavior_popup_menu.add_icon_item(SynapseClassUtil.get_script_icon(behavior.get_script() as Script), behavior.name, menu_id)
			add_behavior_popup_menu.set_item_metadata(add_behavior_popup_menu.get_item_index(menu_id), state_machine.get_path_to(behavior))
			menu_id += 1

	add_behavior_popup_menu.position = pos
	add_behavior_popup_menu.popup()

func add_behavior_from_script(owner_state_name: StringName, behavior_script: Script, pos: Vector2) -> void:
	@warning_ignore("unsafe_cast")
	var behavior_name := validate_behavior_name(SynapseClassUtil.call_static_method_on_script_or_base_classes(behavior_script, &"get_type_name", behavior_script) as String)
	var behavior_data := SynapseBehaviorData.create_from_script(behavior_name, behavior_script, pos, state_machine)
	var behavior := get_behavior_for(behavior_data)
	if not behavior:
		return
	state_machine.remove_child(behavior) # awkward, but we need the undo/redo manager to handle this part

	undo_redo.create_action("Add behavior " + behavior_name, UndoRedo.MERGE_DISABLE, state_machine)
	undo_redo.add_do_method(state_machine, "add_child", behavior)
	undo_redo.add_do_method(behavior, "set", "owner", state_machine.owner)
	undo_redo.add_do_method(state_machine.data, "add_behavior", behavior_data)
	if not owner_state_name.is_empty():
		undo_redo.add_do_method(state_machine.data, "add_behavior_to_owner_state", behavior_name, owner_state_name)
	undo_redo.add_do_method(behavior, "set", "state_machine", state_machine)
	undo_redo.add_do_reference(behavior)
	if not owner_state_name.is_empty():
		undo_redo.add_undo_method(state_machine.data, "remove_behavior_from_owner_state", behavior_name)
	undo_redo.add_undo_method(state_machine.data, "remove_entity", SynapseStateMachineData.EntityType.BEHAVIOR, behavior_name)
	undo_redo.add_undo_method(state_machine, "remove_child", behavior)
	undo_redo.add_undo_method(behavior, "set", "state_machine", null)
	undo_redo.commit_action()

func add_behavior_from_existing_node(owner_state_name: StringName, behavior: SynapseBehavior, pos: Vector2) -> void:
	var behavior_name := validate_behavior_name(behavior.name)
	var behavior_data := SynapseBehaviorData.create_from_existing_node(behavior_name, behavior, pos, state_machine)

	undo_redo.create_action("Link behavior " + behavior_name, UndoRedo.MERGE_DISABLE, state_machine)
	undo_redo.add_do_method(state_machine.data, "add_behavior", behavior_data)
	undo_redo.add_do_method(state_machine.data, "add_behavior_to_owner_state", behavior_name, owner_state_name)
	undo_redo.add_do_method(behavior, "set", "state_machine", state_machine)
	undo_redo.add_undo_method(state_machine.data, "remove_behavior_from_owner_state", behavior_name)
	undo_redo.add_undo_method(state_machine.data, "remove_entity", SynapseStateMachineData.EntityType.BEHAVIOR, behavior_name)
	undo_redo.add_undo_method(behavior, "set", "state_machine", null)
	undo_redo.commit_action()

func show_parameter_add_popup(target: SynapseStateMachineEditorGraphNode, target_slot_name: StringName, parameter_class_name: StringName, pos: Vector2) -> void:
	var scripts := SynapseClassUtil.find_scripts_implementing(parameter_class_name)
	if scripts.is_empty():
		return

	if scripts.size() == 1:
		@warning_ignore("unsafe_cast")
		create_parameter_linked_to((scripts[0] as GDScript).new() as SynapseParameter, target, target_slot_name, _graph_position)
	else:
		_parameter_link_target = target
		_parameter_link_target_slot_name = target_slot_name
		add_parameter_with_value_type_popup_menu.clear()
		scripts.sort_custom(func(s1: Script, s2: Script) -> bool: return s1.get_global_name().naturalcasecmp_to(s2.get_global_name()) < 0)
		var id := 1
		for script in scripts:
			add_parameter_with_value_type_popup_menu.add_icon_item(SynapseClassUtil.get_script_icon(script), script.get_global_name(), id)
			add_parameter_with_value_type_popup_menu.set_item_metadata(add_parameter_with_value_type_popup_menu.get_item_index(id), script)
			id += 1

		add_parameter_with_value_type_popup_menu.position = pos
		add_parameter_with_value_type_popup_menu.popup()

func show_add_parameter_with_value_type_popup_menu(target: SynapseStateMachineEditorGraphNode, target_slot_name: StringName, property_info: Dictionary, pos: Vector2) -> void:
	_parameter_link_target = target
	_parameter_link_target_slot_name = target_slot_name
	var inheritance_map := SynapseClassUtil.build_inheritance_map()
	var compatible_parameter_scripts: Array[Script] = []
	for cached_script in resource_cache.get_cached_parameter_scripts():
		var script := cached_script.load_script()
		if script.is_abstract():
			continue
		if not script.get_global_name():
			continue
		for prop in script.get_script_property_list():
			if prop["name"] == "value":
				if SynapseClassUtil.is_argument_compatible(prop, property_info, inheritance_map):
					compatible_parameter_scripts.append(script)
				break
	if compatible_parameter_scripts.is_empty():
		push_warning("No compatible SynapseParameter implementations found")
		return

	if compatible_parameter_scripts.size() == 1:
		if target is SynapseSignalBridgeGraphNode:
			@warning_ignore("unsafe_cast")
			create_parameter_linked_to_signal_bridge((compatible_parameter_scripts[0] as GDScript).new() as SynapseParameter, target as SynapseSignalBridgeGraphNode, target_slot_name, _graph_position)
		else:
			push_warning("Not supported")
		return

	add_parameter_with_value_type_popup_menu.clear()
	compatible_parameter_scripts.sort_custom(func(s1: Script, s2: Script) -> bool: return s1.get_global_name().naturalcasecmp_to(s2.get_global_name()) < 0)
	var id := 1
	for script in compatible_parameter_scripts:
		add_parameter_with_value_type_popup_menu.add_icon_item(SynapseClassUtil.get_script_icon(script), script.get_global_name(), id)
		add_parameter_with_value_type_popup_menu.set_item_metadata(add_parameter_with_value_type_popup_menu.get_item_index(id), script)
		id += 1

	add_parameter_with_value_type_popup_menu.position = pos
	add_parameter_with_value_type_popup_menu.popup()

func erase_signal_bridge_undoable(signal_bridge_name: StringName) -> void:
	var signal_bridge_data := state_machine.data.signal_bridges[signal_bridge_name]

	# property references
	for callable_arg_name in signal_bridge_data.property_references:
		var entity_property_reference_data := signal_bridge_data.property_references[callable_arg_name]
		undo_redo.add_do_method(state_machine.data, "unassign_signal_bridge_property_reference", signal_bridge_name, callable_arg_name)
		undo_redo.add_undo_method(state_machine.data, "assign_signal_bridge_property_reference", signal_bridge_name, entity_property_reference_data, callable_arg_name)

	# wired signal arguments
	for callable_arg_name in signal_bridge_data.wired_parameters:
		var signal_arg_name := signal_bridge_data.wired_parameters[callable_arg_name]
		undo_redo.add_do_method(state_machine.data, "unwire_signal_bridge_signal_argument", signal_bridge_name, callable_arg_name)
		undo_redo.add_undo_method(state_machine.data, "wire_signal_bridge_signal_argument", signal_bridge_name, signal_arg_name, callable_arg_name)

	undo_redo.add_do_method(state_machine.data, "remove_entity", SynapseStateMachineData.EntityType.SIGNAL_BRIDGE, signal_bridge_name)
	undo_redo.add_undo_method(state_machine.data, "add_signal_bridge", signal_bridge_data)

func signal_source_is_contained_in(signal_source_data: SynapseSignalSourceData, state_names: Array[StringName], behavior_names: Array[StringName], parameter_names: Array[StringName]) -> bool:
	match signal_source_data.source_entity_reference.entity_type:
		SynapseStateMachineData.EntityType.STATE:
			return state_names.has(signal_source_data.source_entity_reference.entity_name)
		SynapseStateMachineData.EntityType.BEHAVIOR:
			return behavior_names.has(signal_source_data.source_entity_reference.entity_name)
		SynapseStateMachineData.EntityType.PARAMETER:
			return parameter_names.has(signal_source_data.source_entity_reference.entity_name)
	push_warning("Cannot determine signal source for unknown entity type: ", SynapseStateMachineData.get_entity_type_name(signal_source_data.source_entity_reference.entity_type))
	return false

func erase(undo_action: String, state_names: Array[StringName], behavior_names: Array[StringName], parameter_names: Array[StringName], signal_bridge_names: Array[StringName], reset_view: bool = false) -> void:
	undo_redo.create_action(undo_action, UndoRedo.MERGE_DISABLE, state_machine, true)

	var is_being_deleted := func(entity_data: SynapseEntityData) -> bool:
		var being_deleted := false
		if entity_data is SynapseParameterData:
			being_deleted = parameter_names.has(entity_data.name)
		elif entity_data is SynapseBehaviorData:
			being_deleted = behavior_names.has(entity_data.name)
		elif entity_data is SynapseStateData:
			being_deleted = state_names.has(entity_data.name)
		elif entity_data is SynapseSignalBridgeData:
			being_deleted = signal_bridge_names.has(entity_data.name)
		return being_deleted

	# exposed callables & signals
	for public_callable_name in state_machine.data.exposed_callables:
		var ref := state_machine.data.exposed_callables[public_callable_name]
		var entity := state_machine.data.get_entity_from(ref.entity_reference)
		if is_being_deleted.call(entity):
			undo_redo.add_do_method(state_machine.data, "unexpose_callable", public_callable_name)
			undo_redo.add_undo_method(state_machine.data, "expose_callable", ref.entity_reference.entity_type, ref.entity_reference.entity_name, ref.property_name, public_callable_name, state_machine)
	for public_signal_name in state_machine.data.exposed_signals:
		var ref := state_machine.data.exposed_signals[public_signal_name]
		var entity := state_machine.data.get_entity_from(ref.entity_reference)
		if is_being_deleted.call(entity):
			undo_redo.add_do_method(state_machine.data, "unexpose_signal", public_signal_name)
			undo_redo.add_undo_method(state_machine.data, "expose_signal", ref.entity_reference.entity_type, ref.entity_reference.entity_name, ref.property_name, public_signal_name, state_machine)

	for state_name in state_machine.data.states:
		var state_data := state_machine.data.states[state_name]

		# custom state stuff
		state_data.notify_erase_undoable(self, state_names, behavior_names, parameter_names, signal_bridge_names)

		# TODO: unify this with parameters and behaviors (signal bridges are a bit different, though)
		# state signal connections
		var signal_connections := state_data.connected_signals
		if state_names.has(state_name):
			# this state is being deleted, delete all signal connections *to* it
			for callable_id in signal_connections:
				for signal_source_data: SynapseSignalSourceData in signal_connections[callable_id]:
					undo_redo.add_do_method(state_machine.data, "disconnect_signal", signal_source_data, SynapseStateMachineData.EntityType.STATE, state_name, callable_id)
					undo_redo.add_undo_method(state_machine.data, "connect_signal", signal_source_data, SynapseStateMachineData.EntityType.STATE, state_name, callable_id)
		else:
			# this state is not being deleted, delete all signal connections to it *from* entities being deleted
			for callable_id in signal_connections:
				for signal_source_data: SynapseSignalSourceData in signal_connections[callable_id]:
					if signal_source_is_contained_in(signal_source_data, state_names, behavior_names, parameter_names):
						undo_redo.add_do_method(state_machine.data, "disconnect_signal", signal_source_data, SynapseStateMachineData.EntityType.STATE, state_name, callable_id)
						undo_redo.add_undo_method(state_machine.data, "connect_signal", signal_source_data, SynapseStateMachineData.EntityType.STATE, state_name, callable_id)

	# behavior signal connections
	for behavior_name in state_machine.data.behaviors:
		var behavior_data := state_machine.data.behaviors[behavior_name]
		if behavior_names.has(behavior_name):
			# this behavior is being deleted, delete all signal connections *to* it
			for callable_id in behavior_data.connected_signals:
				for signal_source_data: SynapseSignalSourceData in behavior_data.connected_signals[callable_id]:
					undo_redo.add_do_method(state_machine.data, "disconnect_signal", signal_source_data, SynapseStateMachineData.EntityType.BEHAVIOR, behavior_name, callable_id)
					undo_redo.add_undo_method(state_machine.data, "connect_signal", signal_source_data, SynapseStateMachineData.EntityType.BEHAVIOR, behavior_name, callable_id)
		else:
			# this behavior is not being deleted, delete all signal connections to it *from* entities being deleted
			for callable_id in behavior_data.connected_signals:
				for signal_source_data: SynapseSignalSourceData in behavior_data.connected_signals[callable_id]:
					if signal_source_is_contained_in(signal_source_data, state_names, behavior_names, parameter_names):
						undo_redo.add_do_method(state_machine.data, "disconnect_signal", signal_source_data, SynapseStateMachineData.EntityType.BEHAVIOR, behavior_name, callable_id)
						undo_redo.add_undo_method(state_machine.data, "connect_signal", signal_source_data, SynapseStateMachineData.EntityType.BEHAVIOR, behavior_name, callable_id)

	for parameter_name in state_machine.data.parameters:
		var parameter_data := state_machine.data.parameters[parameter_name]
		if parameter_names.has(parameter_name):
			# this parameter is being deleted, delete all signal connections *to* it
			for method_name in parameter_data.connected_signals:
				for signal_source_data: SynapseSignalSourceData in parameter_data.connected_signals[method_name]:
					undo_redo.add_do_method(state_machine.data, "disconnect_signal", signal_source_data, SynapseStateMachineData.EntityType.PARAMETER, parameter_name, method_name)
					undo_redo.add_undo_method(state_machine.data, "connect_signal", signal_source_data, SynapseStateMachineData.EntityType.PARAMETER, parameter_name, method_name)
		else:
			# this parameter is not being deleted, delete all signal connections to it *from* entities being deleted
			for method_name in parameter_data.connected_signals:
				for signal_source_data: SynapseSignalSourceData in parameter_data.connected_signals[method_name]:
					if signal_source_is_contained_in(signal_source_data, state_names, behavior_names, parameter_names):
						undo_redo.add_do_method(state_machine.data, "disconnect_signal", signal_source_data, SynapseStateMachineData.EntityType.PARAMETER, parameter_name, method_name)
						undo_redo.add_undo_method(state_machine.data, "connect_signal", signal_source_data, SynapseStateMachineData.EntityType.PARAMETER, parameter_name, method_name)

	# signal bridges
	for signal_bridge_name in state_machine.data.signal_bridges:
		if signal_bridge_name in signal_bridge_names:
			erase_signal_bridge_undoable(signal_bridge_name)
		else:
			# signal bridge should be deleted if either of its connected entities is being deleted
			var signal_bridge_data := state_machine.data.signal_bridges[signal_bridge_name]
			@warning_ignore("unsafe_cast")
			var source_entity := state_machine.data.get_entity_from((signal_bridge_data.connected_signals[SynapseSignalBridgeData.CALLABLE_NAME][0] as SynapseSignalSourceData).source_entity_reference)
			var target_entity := state_machine.data.get_entity_from(signal_bridge_data.callable_target_data.target_entity_reference)
			if is_being_deleted.call(source_entity) or is_being_deleted.call(target_entity):
				erase_signal_bridge_undoable(signal_bridge_name)
			else:
				# clear all argument references to entities being deleted
				for callable_arg_name in signal_bridge_data.property_references:
					var ref := signal_bridge_data.property_references[callable_arg_name]
					if is_being_deleted.call(state_machine.data.get_entity_from(ref.entity_reference)):
						undo_redo.add_do_method(state_machine.data, "unassign_signal_bridge_property_reference", signal_bridge_name, callable_arg_name)
						undo_redo.add_undo_method(state_machine.data, "assign_signal_bridge_property_reference", signal_bridge_name, ref, callable_arg_name)

	# parameter references
	for entity_data in state_machine.data.get_all_entities():
		var being_deleted: bool = is_being_deleted.call(entity_data)
		for ref in entity_data.get_parameter_references(state_machine):
			if being_deleted or parameter_names.has(ref.parameter_name):
				var parameter_data := state_machine.data.parameters[ref.parameter_name]
				entity_data.release_parameter_undoable(parameter_data, ref.property_name, self)

	for parameter_name in parameter_names:
		# parameters themselves
		var parameter_data := state_machine.data.parameters[parameter_name]
		undo_redo.add_do_method(state_machine.data, "remove_entity", SynapseStateMachineData.EntityType.PARAMETER, parameter_name)
		undo_redo.add_undo_method(state_machine.data, "add_parameter", parameter_data)

	# state behavior ordering
	for behavior_name in behavior_names:
		var behavior_data := state_machine.data.behaviors[behavior_name]
		if behavior_data.owner_state_name:
			undo_redo.add_undo_method(state_machine.data, "order_behaviors", behavior_data.owner_state_name, state_machine.data.states[behavior_data.owner_state_name].behavior_names.duplicate())

	# behaviors
	for behavior_name in behavior_names:
		var behavior_data := state_machine.data.behaviors[behavior_name]

		# state ownership
		if behavior_data.owner_state_name:
			undo_redo.add_do_method(state_machine.data, "remove_behavior_from_owner_state", behavior_name)
			undo_redo.add_undo_method(state_machine.data, "add_behavior_to_owner_state", behavior_name, behavior_data.owner_state_name)

		# behaviors themselves
		undo_redo.add_do_method(state_machine.data, "remove_entity", SynapseStateMachineData.EntityType.BEHAVIOR, behavior_name)
		undo_redo.add_undo_method(state_machine.data, "add_behavior", behavior_data)

		# behavior scene tree nodes
		var behavior := get_behavior_for(behavior_data)
		if behavior:
			undo_redo.add_undo_reference(behavior)
			undo_redo.add_do_method(behavior, "set", "state_machine", null)
			undo_redo.add_undo_method(behavior, "set", "state_machine", state_machine)
			if behavior_data.managed:
				undo_redo.add_do_method(state_machine, "remove_child", behavior)
				undo_redo.add_undo_method(behavior, "set", "owner", state_machine.owner)
				undo_redo.add_undo_method(state_machine, "add_child", behavior)

	# state child ordering matters (e.g. for sequence state transitions) - capture these before (and undo after) the states themselves
	var parents_to_reorder_children: Array[StringName] = []
	for state_name in state_names:
		var state_data := state_machine.data.states[state_name]
		if state_data.parent_name and not parents_to_reorder_children.has(state_data.parent_name):
			parents_to_reorder_children.append(state_data.parent_name)
			undo_redo.add_undo_method(state_machine.data, "order_child_states", state_data.parent_name, state_machine.data.states[state_data.parent_name].child_names.duplicate())
		if state_data.child_names:
			undo_redo.add_undo_method(state_machine.data, "order_child_states", state_data.name, state_data.child_names.duplicate())

	# state parent/child relationships
	for state_name in state_names:
		var state_data := state_machine.data.states[state_name]
		if state_data.parent_name:
			undo_redo.add_do_method(state_machine.data, "remove_state_from_parent", state_data.name)
			undo_redo.add_undo_method(state_machine.data, "add_state_to", state_data.name, state_data.parent_name)
		for child_name in state_data.child_names:
			if not state_names.has(child_name): # others already removed above
				undo_redo.add_do_method(state_machine.data, "remove_state_from_parent", child_name)
				undo_redo.add_undo_method(state_machine.data, "add_state_to", child_name, state_data.name)

	# states
	for state_name in state_names:
		# update root state
		if state_name == state_machine.data.root_state:
			undo_redo.add_do_method(state_machine.data, "set", "root_state", &"")
			undo_redo.add_undo_method(state_machine.data, "set", "root_state", state_name)

		# remove behaviors
		var state_data := state_machine.data.states[state_name]
		for behavior_name in state_data.behavior_names:
			if not behavior_names.has(behavior_name): # others already removed above
				undo_redo.add_do_method(state_machine.data, "remove_behavior_from_owner_state", behavior_name)
				undo_redo.add_undo_method(state_machine.data, "add_behavior_to_owner_state", behavior_name, state_name)

		# remove state
		undo_redo.add_do_method(state_machine.data, "remove_entity", SynapseStateMachineData.EntityType.STATE, state_name)
		undo_redo.add_undo_method(state_machine.data, "add_state", state_data)

	# view
	if reset_view:
		undo_redo.add_do_method(state_machine.data, "set", "editor_scroll_offset", Vector2.ZERO)
		undo_redo.add_do_method(state_machine.data, "set", "editor_zoom", 1.0)
		undo_redo.add_do_method(state_machine.data, "set", "root_pos", Vector2.ZERO)
		undo_redo.add_do_method(self, "sync_view")
		undo_redo.add_undo_method(self, "sync_view")
		undo_redo.add_undo_method(state_machine.data, "set", "root_pos", state_machine.data.root_pos)
		undo_redo.add_undo_method(state_machine.data, "set", "editor_zoom", state_machine.data.editor_zoom)
		undo_redo.add_undo_method(state_machine.data, "set", "editor_scroll_offset", state_machine.data.editor_scroll_offset)

	undo_redo.commit_action()

func sync_view() -> void:
	root_sentinel.position_offset = state_machine.data.root_pos
	zoom = state_machine.data.editor_zoom
	if state_machine.data.editor_scroll_offset == Vector2.ZERO and state_machine.data.editor_zoom == 1.0:
		# new/erased data (probably) - reposition so the root sentinel's RHS is in the center
		state_machine.data.editor_scroll_offset = (root_sentinel.position_offset + Vector2(root_sentinel.size.x, root_sentinel.size.y / 2.0)) * zoom - size / 2.0
		state_machine.data.emit_changed()
	scroll_offset = state_machine.data.editor_scroll_offset

func get_graph_node_for_entity(entity_type: SynapseStateMachineData.EntityType, entity_name: StringName) -> SynapseStateMachineEditorGraphNode:
	match entity_type:
		SynapseStateMachineData.EntityType.STATE:
			return state_graph_nodes.get(entity_name)
		SynapseStateMachineData.EntityType.BEHAVIOR:
			return behavior_graph_nodes.get(entity_name)
		SynapseStateMachineData.EntityType.PARAMETER:
			return parameter_graph_nodes.get(entity_name)
		SynapseStateMachineData.EntityType.SIGNAL_BRIDGE:
			return signal_bridge_graph_nodes.get(entity_name)
		_:
			push_warning("Unknown entity type: ", entity_type)
	return null

func get_graph_node_for(entity_data: SynapseEntityData) -> SynapseStateMachineEditorGraphNode:
	if entity_data is SynapseStateData:
		return state_graph_nodes[entity_data.name]
	if entity_data is SynapseBehaviorData:
		return behavior_graph_nodes[entity_data.name]
	if entity_data is SynapseParameterData:
		return parameter_graph_nodes[entity_data.name]
	if entity_data is SynapseSignalBridgeData:
		return signal_bridge_graph_nodes[entity_data.name]

	push_error("Unknown entity data type: ", entity_data)
	return null

func get_graph_node_for_reference(reference: SynapseEntityReferenceData) -> SynapseStateMachineEditorGraphNode:
	return get_graph_node_for(state_machine.data.get_entity_from(reference))

func create_signal_connection(signal_source_data: SynapseSignalSourceData, to_entity: SynapseEntityData, to_callable_id: StringName) -> void:
	var from_graph_node := get_graph_node_for_reference(signal_source_data.source_entity_reference)
	var to_graph_node := get_graph_node_for(to_entity)
	var from_slot_name := from_graph_node.get_slot_name_for_emitted_signal_name(signal_source_data.signal_id)
	var to_slot_name := to_graph_node.get_slot_name_for_signal_receive_callable_name(to_callable_id)
	var connection_proxy := ConnectionProxy.of(from_graph_node, from_slot_name, to_graph_node, to_slot_name)
	var callable_info := to_graph_node.get_signal_receive_slot_callable_info(to_slot_name)
	@warning_ignore("unsafe_cast")
	connection_proxy.remove_requested.connect(remove_signal_connection_user_action.bind(signal_source_data, to_entity, callable_info["name"] as StringName))
	add_connection(connection_proxy)
	update_configuration_warnings()

func remove_signal_connection(signal_source_data: SynapseSignalSourceData, to_entity: SynapseEntityData, to_callable_id: StringName) -> void:
	var from_graph_node := get_graph_node_for_reference(signal_source_data.source_entity_reference)
	var to_graph_node := get_graph_node_for(to_entity)
	var from_slot_name := from_graph_node.get_slot_name_for_emitted_signal_name(signal_source_data.signal_id)
	var to_slot_name := to_graph_node.get_slot_name_for_signal_receive_callable_name(to_callable_id)
	remove_connection_between(from_graph_node, from_slot_name, to_graph_node, to_slot_name)
	update_configuration_warnings()

func add_connection(proxy: ConnectionProxy) -> void:
	_connection_proxies.append(proxy)
	update_connections()

func remove_connection(proxy: ConnectionProxy) -> void:
	_connection_proxies.erase(proxy)
	if not proxy.graph_connection.is_empty():
		@warning_ignore("unsafe_cast")
		disconnect_node(proxy.graph_connection["from_node"] as StringName, proxy.graph_connection["from_port"] as int, proxy.graph_connection["to_node"] as StringName, proxy.graph_connection["to_port"] as int)
		proxy.graph_connection.clear()

func remove_connection_between(from_node: SynapseStateMachineEditorGraphNode, from_slot: StringName, to_node: SynapseStateMachineEditorGraphNode, to_slot: StringName) -> void:
	for c in _connection_proxies:
		if is_same(c.from_graph_node, from_node) and c.from_slot == from_slot\
				and is_same(c.to_graph_node, to_node) and c.to_slot == to_slot:
			remove_connection(c)
			return

func update_closest_removable_connection(pos: Vector2) -> void:
	var closest_distance_squared := DELETE_CONNECTION_DISTANCE_THRESHOLD * DELETE_CONNECTION_DISTANCE_THRESHOLD
	var closest_connection: ConnectionProxy
	var p1: Vector2
	var p2: Vector2
	for c in _connection_proxies:
		var curr_p1 := c.from_graph_node.position_offset + c.from_graph_node.get_output_port_position(c.from_graph_node.get_output_port_number(c.from_slot))
		var curr_p2 := c.to_graph_node.position_offset + c.to_graph_node.get_input_port_position(c.to_graph_node.get_input_port_number(c.to_slot))
		var bbox := Rect2(curr_p1, Vector2.ZERO).expand(curr_p2).grow(DELETE_CONNECTION_DISTANCE_THRESHOLD)
		if bbox.has_point(pos):
			var closest_point := Geometry2D.get_closest_point_to_segment(pos, curr_p1, curr_p2)
			var distance_squared := pos.distance_squared_to(closest_point)
			if distance_squared < closest_distance_squared and not c.get_signal_connection_list(&"remove_requested").is_empty():
				closest_distance_squared = distance_squared
				closest_connection = c
				p1 = curr_p1
				p2 = curr_p2

	if closest_connection:
		if not is_same(_closest_connection_proxy_for_deletion, closest_connection):
			_closest_connection_proxy_for_deletion = closest_connection
			var handle_length := absf(p2.x - p1.x) * connection_lines_curvature
			var c1 := Vector2(handle_length, 0)
			var c2 := Vector2(-handle_length, 0)
			_closest_connection_curve = Curve2D.new()
			_closest_connection_curve.add_point(p1, Vector2.ZERO, c1)
			_closest_connection_curve.add_point(p2, c2, Vector2.ZERO)
		delete_connection_button.position = (_closest_connection_curve.get_closest_point(pos) * zoom) - scroll_offset - delete_connection_button.size / 2.0
		move_child(delete_connection_button, -1) # so other elements don't swallow the click
		delete_connection_button.show()
	else:
		_closest_connection_proxy_for_deletion = null
		_closest_connection_curve = null
		delete_connection_button.hide()

func find_first_connection_matching(predicate: Callable) -> ConnectionProxy:
	for c in _connection_proxies:
		if predicate.call(c):
			return c
	return null

func find_connections_matching(predicate: Callable) -> Array[ConnectionProxy]:
	var matched_connections: Array[ConnectionProxy] = []
	for c in _connection_proxies:
		if predicate.call(c):
			matched_connections.append(c)
	return matched_connections

func update_connections() -> void:
	if not _connections_dirty:
		_connections_dirty = true
		recreate_all_connections.call_deferred()

func recreate_all_connections() -> void:
	if not _connections_dirty:
		return
	clear_connections()
	var valid_connection_proxies: Array[ConnectionProxy] = []
	for c in _connection_proxies:
		var from_port := c.from_graph_node.get_output_port_number(c.from_slot)
		var to_port := c.to_graph_node.get_input_port_number(c.to_slot)
		if from_port >= 0 and to_port >= 0:
			connect_node(c.from_graph_node.name, from_port, c.to_graph_node.name, to_port)
			c.graph_connection = connections[-1]
			valid_connection_proxies.append(c)
		else:
			push_warning("Not drawing invalid connection: ", c)
	_connection_proxies = valid_connection_proxies
	_connections_dirty = false

func create_parameter_from_script(script: Script, pos: Vector2) -> void:
	var new_parameter_name := validate_parameter_name(script.get_global_name())
	@warning_ignore("unsafe_cast")
	var parameter := (script as GDScript).new() as SynapseParameter
	var parameter_data := SynapseParameterData.create(new_parameter_name, parameter, pos)
	undo_redo.create_action("Add parameter " + new_parameter_name, UndoRedo.MERGE_DISABLE, state_machine)
	undo_redo.add_do_method(state_machine.data, "add_parameter", parameter_data)
	undo_redo.add_undo_method(state_machine.data, "remove_entity", SynapseStateMachineData.EntityType.PARAMETER, new_parameter_name)
	undo_redo.commit_action()

func create_parameter_linked_to(parameter: SynapseParameter, graph_node: SynapseStateMachineEditorGraphNode, slot_name: StringName, pos: Vector2) -> void:
	var new_parameter_name := validate_parameter_name(slot_name)
	var referencing_entity_data := state_machine.data.get_entity(graph_node.get_entity_type(), graph_node.get_entity_name())
	var parameter_data := SynapseParameterData.create(new_parameter_name, parameter, pos)
	undo_redo.create_action("Add parameter " + new_parameter_name, UndoRedo.MERGE_DISABLE, state_machine)
	undo_redo.add_do_method(state_machine.data, "add_parameter", parameter_data)
	referencing_entity_data.reference_parameter_undoable(parameter_data, slot_name, self)
	undo_redo.add_undo_method(state_machine.data, "remove_entity", SynapseStateMachineData.EntityType.PARAMETER, new_parameter_name)
	undo_redo.commit_action()

func create_parameter_linked_to_signal_bridge(parameter: SynapseParameter, signal_bridge_graph_node: SynapseSignalBridgeGraphNode, slot_name: StringName, pos: Vector2) -> void:
	var new_parameter_name := validate_parameter_name(slot_name)
	var signal_bridge_data := state_machine.data.signal_bridges[signal_bridge_graph_node.get_entity_name()]
	var has_value := false
	for prop in parameter.get_property_list():
		if prop["name"] == &"value":
			has_value = true
			break
	if not has_value:
		push_warning("No property named 'value' on parameter type '", parameter.get_class(), "'")
		return
	var parameter_data := SynapseParameterData.create(new_parameter_name, parameter, pos)
	var entity_property_reference_data := SynapseEntityPropertyReferenceData.create(SynapseEntityReferenceData.from(parameter_data), &"value")
	@warning_ignore("unsafe_cast")
	var argument_name := signal_bridge_graph_node.get_argument_info(slot_name)["name"] as String

	undo_redo.create_action("Add parameter " + new_parameter_name, UndoRedo.MERGE_DISABLE, state_machine)
	if signal_bridge_data.property_references.has(argument_name):
		# remove existing assignment
		undo_redo.add_do_method(state_machine.data, "unassign_signal_bridge_property_reference", signal_bridge_data.name, argument_name)
	undo_redo.add_do_method(state_machine.data, "add_parameter", parameter_data)
	undo_redo.add_do_method(state_machine.data, "assign_signal_bridge_property_reference", signal_bridge_data.name, entity_property_reference_data, argument_name)
	undo_redo.add_undo_method(state_machine.data, "unassign_signal_bridge_property_reference", signal_bridge_data.name, argument_name)
	undo_redo.add_undo_method(state_machine.data, "remove_entity", SynapseStateMachineData.EntityType.PARAMETER, new_parameter_name)
	if signal_bridge_data.property_references.has(argument_name):
		# re-add previous assignment
		undo_redo.add_undo_method(state_machine.data, "assign_signal_bridge_property_reference", signal_bridge_data.name, signal_bridge_data.property_references[argument_name], argument_name)
	undo_redo.commit_action()

func remove_state_as_root() -> void:
	if state_machine.data.root_state.is_empty():
		push_warning("No root state assigned in data")
		return
	undo_redo.create_action("Remove " + state_machine.data.root_state + " as root", UndoRedo.MERGE_DISABLE, state_machine)
	undo_redo.add_do_method(state_machine.data, "set", "root_state", &"")
	undo_redo.add_undo_method(state_machine.data, "set", "root_state", state_machine.data.root_state)
	undo_redo.commit_action()

func remove_child_state_from_parent(child_state_name: StringName) -> void:
	var child_state_data := state_machine.data.states[child_state_name]
	var parent_state_name := child_state_data.parent_name
	var parent_state_data := state_machine.data.states[parent_state_name]
	undo_redo.create_action("Remove " + child_state_name + " from " + parent_state_name, UndoRedo.MERGE_DISABLE, state_machine)
	undo_redo.add_undo_method(state_machine.data, "add_state_to", child_state_name, parent_state_name)
	parent_state_data.remove_child_state_undoable(self, child_state_data)
	undo_redo.add_do_method(state_machine.data, "remove_state_from_parent", child_state_name)
	undo_redo.commit_action()

func remove_behavior_from_owner_state(behavior_name: StringName) -> void:
	var behavior_data := state_machine.data.behaviors[behavior_name]
	undo_redo.create_action("Remove " + behavior_name + " from " + behavior_data.owner_state_name, UndoRedo.MERGE_DISABLE, state_machine)
	undo_redo.add_do_method(state_machine.data, "remove_behavior_from_owner_state", behavior_name)
	undo_redo.add_undo_method(state_machine.data, "add_behavior_to_owner_state", behavior_name, behavior_data.owner_state_name)
	undo_redo.commit_action()

func remove_parameter_reference(parameter_data: SynapseParameterData, referencing_entity: SynapseEntityData, property_name: StringName) -> void:
	undo_redo.create_action("Remove parameter '" + parameter_data.name + "' reference", UndoRedo.MERGE_DISABLE, state_machine)
	referencing_entity.release_parameter_undoable(parameter_data, property_name, self)
	undo_redo.commit_action()

func remove_signal_bridge(signal_bridge_name: StringName) -> void:
	undo_redo.create_action("Remove " + signal_bridge_name, UndoRedo.MERGE_DISABLE, state_machine, true)
	erase_signal_bridge_undoable(signal_bridge_name)
	undo_redo.commit_action()

func remove_signal_bridge_property_reference(signal_bridge_name: StringName, argument_name: StringName) -> void:
	var signal_bridge_data := state_machine.data.signal_bridges[signal_bridge_name]
	undo_redo.create_action("Unbind " + argument_name, UndoRedo.MERGE_DISABLE, state_machine)
	undo_redo.add_do_method(state_machine.data, "unassign_signal_bridge_property_reference", signal_bridge_name, argument_name)
	undo_redo.add_undo_method(state_machine.data, "assign_signal_bridge_property_reference", signal_bridge_name, signal_bridge_data.property_references[argument_name], argument_name)
	undo_redo.commit_action()

func remove_signal_connection_user_action(signal_source_data: SynapseSignalSourceData, to_entity: SynapseEntityData, callable_id: StringName) -> void:
	var entity_type := SynapseStateMachineData.get_entity_type(to_entity)
	var entity_name := SynapseStateMachineData.get_entity_name(to_entity)
	undo_redo.create_action("Disconnect signal", UndoRedo.MERGE_DISABLE, state_machine)
	undo_redo.add_do_method(state_machine.data, "disconnect_signal", signal_source_data, entity_type, entity_name, callable_id)
	undo_redo.add_undo_method(state_machine.data, "connect_signal", signal_source_data, entity_type, entity_name, callable_id)
	undo_redo.commit_action()

## ---------------- SIGNAL HANDLERS ----------------

func _on_root_sentinel_node_moved(old_pos: Vector2, new_pos: Vector2) -> void:
	undo_redo.create_action("Move root sentinel", UndoRedo.MERGE_DISABLE, state_machine)
	undo_redo.add_do_method(self, "set_root_sentinel_position", new_pos)
	undo_redo.add_undo_method(self, "set_root_sentinel_position", old_pos)
	undo_redo.commit_action()

func _on_state_node_moved(old_pos: Vector2, new_pos: Vector2, state_node: SynapseStateGraphNode) -> void:
	var state_name := state_node.get_entity_name()
	undo_redo.create_action("Move " + state_name, UndoRedo.MERGE_DISABLE, state_machine)
	undo_redo.add_do_method(self, "set_state_node_position", state_name, new_pos)
	undo_redo.add_undo_method(self, "set_state_node_position", state_name, old_pos)
	undo_redo.commit_action()

func _on_state_name_change_requested(proposed_state_name: String, state_node: SynapseStateGraphNode) -> void:
	var current_name := state_node.get_entity_name()
	if proposed_state_name == current_name:
		return
	var new_name := validate_state_name(proposed_state_name)
	if current_name == new_name:
		return

	undo_redo.create_action("Rename " + current_name, UndoRedo.MERGE_DISABLE, state_machine)
	undo_redo.add_do_method(state_machine.data, "rename_entity", SynapseStateMachineData.EntityType.STATE, current_name, new_name)
	undo_redo.add_undo_method(state_machine.data, "rename_entity", SynapseStateMachineData.EntityType.STATE, new_name, current_name)
	undo_redo.commit_action()

func _on_behavior_node_moved(old_pos: Vector2, new_pos: Vector2, behavior_graph_node: SynapseBehaviorGraphNode) -> void:
	var behavior_name := behavior_graph_node.get_entity_name()
	undo_redo.create_action("Move " + behavior_name, UndoRedo.MERGE_DISABLE, state_machine)
	undo_redo.add_do_method(self, "set_behavior_graph_node_position", behavior_name, new_pos)
	undo_redo.add_undo_method(self, "set_behavior_graph_node_position", behavior_name, old_pos)
	undo_redo.commit_action()

func _on_behavior_name_change_requested(proposed_behavior_name: String, behavior_node: SynapseBehaviorGraphNode) -> void:
	var current_name := behavior_node.get_entity_name()
	if proposed_behavior_name == current_name:
		return
	var new_name := validate_behavior_name(proposed_behavior_name)
	if current_name == new_name:
		return

	undo_redo.create_action("Rename " + current_name, UndoRedo.MERGE_DISABLE, state_machine)
	undo_redo.add_do_method(state_machine.data, "rename_entity", SynapseStateMachineData.EntityType.BEHAVIOR, current_name, new_name)
	undo_redo.add_undo_method(state_machine.data, "rename_entity", SynapseStateMachineData.EntityType.BEHAVIOR, new_name, current_name)
	undo_redo.commit_action()

func _on_parameter_node_moved(old_pos: Vector2, new_pos: Vector2, parameter_graph_node: SynapseParameterGraphNode) -> void:
	var parameter_name := parameter_graph_node.get_entity_name()
	undo_redo.create_action("Move " + parameter_name, UndoRedo.MERGE_DISABLE, state_machine)
	undo_redo.add_do_method(self, "set_parameter_graph_node_position", parameter_name, new_pos)
	undo_redo.add_undo_method(self, "set_parameter_graph_node_position", parameter_name, old_pos)
	undo_redo.commit_action()

func _on_parameter_name_change_requested(proposed_parameter_name: String, parameter_node: SynapseParameterGraphNode) -> void:
	var current_name := parameter_node.get_entity_name()
	if proposed_parameter_name == current_name:
		return
	var new_name := validate_parameter_name(proposed_parameter_name)
	if current_name == new_name:
		return

	undo_redo.create_action("Rename " + current_name, UndoRedo.MERGE_DISABLE, state_machine)
	undo_redo.add_do_method(state_machine.data, "rename_entity", SynapseStateMachineData.EntityType.PARAMETER, current_name, new_name)
	undo_redo.add_undo_method(state_machine.data, "rename_entity", SynapseStateMachineData.EntityType.PARAMETER, new_name, current_name)
	undo_redo.commit_action()

func _on_signal_bridge_node_moved(old_pos: Vector2, new_pos: Vector2, signal_bridge_graph_node: SynapseSignalBridgeGraphNode) -> void:
	var signal_bridge_name := signal_bridge_graph_node.get_entity_name()
	undo_redo.create_action("Move " + signal_bridge_name, UndoRedo.MERGE_DISABLE, state_machine)
	undo_redo.add_do_method(self, "set_signal_bridge_graph_node_position", signal_bridge_name, new_pos)
	undo_redo.add_undo_method(self, "set_signal_bridge_graph_node_position", signal_bridge_name, old_pos)
	undo_redo.commit_action()

func _on_signal_bridge_name_change_requested(proposed_signal_bridge_name: String, signal_bridge_node: SynapseSignalBridgeGraphNode) -> void:
	var current_name := signal_bridge_node.get_entity_name()
	if proposed_signal_bridge_name == current_name:
		return
	var new_name := validate_signal_bridge_name(proposed_signal_bridge_name)
	if current_name == new_name:
		return

	undo_redo.create_action("Rename " + current_name, UndoRedo.MERGE_DISABLE, state_machine)
	undo_redo.add_do_method(self, "set_signal_bridge_name", current_name, new_name)
	undo_redo.add_undo_method(self, "set_signal_bridge_name", new_name, current_name)
	undo_redo.commit_action()

func _on_connection_to_empty(from_node: StringName, from_port: int, release_position: Vector2) -> void:
	var graph_node := get_node(NodePath(from_node)) as SynapseStateMachineEditorGraphNode
	var pos := get_screen_position() + release_position
	var connection_type := graph_node.get_connection_type_for_output_port(from_port)
	_graph_position = (release_position + scroll_offset) / zoom
	if graph_node is SynapseRootSentinelGraphNode and connection_type == ConnectionType.CHILD:
		_parent_is_root = true
		show_state_add_popup(pos)
	elif graph_node is SynapseStateGraphNode:
		_parent_is_root = false
		var state_node := graph_node as SynapseStateGraphNode
		_parent_state_name = state_node.get_entity_name()
		match connection_type:
			ConnectionType.CHILD:
				var state_data := state_machine.data.states[_parent_state_name]
				var max_child_count := state_data.get_max_child_count()
				var child_count := 0
				child_count = state_data.child_names.size()
				if max_child_count >= 0 and child_count >= max_child_count:
					return
				show_state_add_popup(pos)
			ConnectionType.BEHAVIOR_OUT:
				show_behavior_add_popup(pos)
			_:
				var state_data := state_machine.data.states[state_node.get_entity_name()]
				state_data.attempt_connection_to_empty(self, connection_type, state_node.get_slot_name_for_output_port(from_port), _graph_position)
	elif graph_node is SynapseBehaviorGraphNode and connection_type == ConnectionType.PARAMETER_RW:
		var slot_name := graph_node.get_slot_name_for_output_port(from_port)
		var behavior_data := state_machine.data.behaviors[graph_node.get_entity_name()]
		var behavior := get_behavior_for(behavior_data)
		if behavior:
			@warning_ignore("unsafe_cast")
			var parameter_class_name := SynapseClassUtil.get_script_property_class_name(behavior.get_script() as Script, slot_name)
			show_parameter_add_popup(graph_node, slot_name, parameter_class_name, pos)

func _on_connection_from_empty(to_node: StringName, to_port: int, release_position: Vector2) -> void:
	var graph_node := get_node(NodePath(to_node)) as SynapseStateMachineEditorGraphNode
	var pos := get_screen_position() + release_position
	var connection_type := graph_node.get_connection_type_for_input_port(to_port)
	_graph_position = (release_position + scroll_offset) / zoom

	if graph_node is SynapseBehaviorGraphNode and connection_type == ConnectionType.PARAMETER_RO:
		var slot_name := graph_node.get_slot_name_for_input_port(to_port)
		var behavior_data := state_machine.data.behaviors[graph_node.get_entity_name()]
		var behavior := get_behavior_for(behavior_data)
		if behavior:
			@warning_ignore("unsafe_cast")
			var parameter_class_name := SynapseClassUtil.get_script_property_class_name(behavior.get_script() as Script, slot_name)
			show_parameter_add_popup(graph_node, slot_name, parameter_class_name, pos)
	elif graph_node is SynapseStateGraphNode:
		var state_data := state_machine.data.states[graph_node.get_entity_name()]
		state_data.attempt_connection_to_empty(self, connection_type, graph_node.get_slot_name_for_input_port(to_port), _graph_position)
	elif graph_node is SynapseSignalBridgeGraphNode:
		var slot_name := graph_node.get_slot_name_for_input_port(to_port)
		show_add_parameter_with_value_type_popup_menu(graph_node, slot_name, (graph_node as SynapseSignalBridgeGraphNode).get_argument_info(slot_name), pos)

func _on_add_behavior_popup_menu_id_pressed(id: int) -> void:
	if _behavior_add_menu_scripts.has(id):
		add_behavior_from_script(_parent_state_name, _behavior_add_menu_scripts[id], _graph_position)
	else:
		@warning_ignore("unsafe_cast")
		add_behavior_from_existing_node(_parent_state_name, state_machine.get_node(add_behavior_popup_menu.get_item_metadata(add_behavior_popup_menu.get_item_index(id)) as NodePath) as SynapseBehavior, _graph_position)

func _on_add_state_popup_menu_item_selected(id: int) -> void:
	var new_state_name: StringName
	var data_and_option := _state_data_options[id]
	@warning_ignore("unsafe_cast")
	new_state_name = validate_state_name(data_and_option[1][SynapseStateData.Option.NAME] as String)
	@warning_ignore("unsafe_cast")
	var state_data := data_and_option[0] as SynapseStateData
	state_data.name = new_state_name
	state_data.graph_pos = _graph_position
	@warning_ignore("unsafe_cast")
	state_data.init_from_option(data_and_option[1] as Dictionary)

	undo_redo.create_action("Add state " + new_state_name, UndoRedo.MERGE_DISABLE, state_machine)
	undo_redo.add_do_method(state_machine.data, "add_state", state_data)
	if _parent_is_root:
		undo_redo.add_do_method(state_machine.data, "set", "root_state", new_state_name)
		undo_redo.add_undo_method(state_machine.data, "set", "root_state", state_machine.data.root_state)
	elif not _parent_state_name.is_empty():
		undo_redo.add_do_method(state_machine.data, "add_state_to", new_state_name, _parent_state_name)
		undo_redo.add_undo_method(state_machine.data, "remove_state_from_parent", new_state_name)
	undo_redo.add_undo_method(state_machine.data, "remove_entity", SynapseStateMachineData.EntityType.STATE, new_state_name)
	undo_redo.commit_action()

func _on_add_parameter_with_value_type_popup_menu_id_pressed(id: int) -> void:
	var parameter_script: Script = add_parameter_with_value_type_popup_menu.get_item_metadata(add_parameter_with_value_type_popup_menu.get_item_index(id))
	@warning_ignore("unsafe_cast")
	var parameter := (parameter_script as GDScript).new() as SynapseParameter
	if _parameter_link_target is SynapseBehaviorGraphNode:
		create_parameter_linked_to(parameter, _parameter_link_target, _parameter_link_target_slot_name, _graph_position)
	elif _parameter_link_target is SynapseSignalBridgeGraphNode:
		create_parameter_linked_to_signal_bridge(parameter, _parameter_link_target as SynapseSignalBridgeGraphNode, _parameter_link_target_slot_name, _graph_position)
	else:
		push_warning("Not supported")
		return

func _on_connection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	if is_same(from_node, to_node):
		return

	var from_graph_node := get_node(NodePath(from_node)) as SynapseStateMachineEditorGraphNode
	var to_graph_node := get_node(NodePath(to_node)) as SynapseStateMachineEditorGraphNode
	var from_connection_type := from_graph_node.get_connection_type_for_output_port(from_port)
	var to_connection_type := to_graph_node.get_connection_type_for_input_port(to_port)
	var from_slot_name := from_graph_node.get_slot_name_for_output_port(from_port)
	var to_slot_name := to_graph_node.get_slot_name_for_input_port(to_port)

	if from_connection_type == ConnectionType.EXPOSE_CALLABLE and from_graph_node is SynapseRootSentinelGraphNode and from_slot_name == SynapseRootSentinelGraphNode.SLOT_EXPOSE_SIGNAL_OR_CALLABLE:
		var callable_name: StringName = to_graph_node.get_signal_receive_slot_callable_info(to_slot_name)["name"]
		var public_name := SynapseGUIUtil.validate_name(callable_name, func(n: StringName) -> bool: return state_machine.data.exposed_callables.has(n))
		undo_redo.create_action("Expose '" + public_name + "'", UndoRedo.MERGE_DISABLE, state_machine)
		undo_redo.add_do_method(state_machine.data, "expose_callable", to_graph_node.get_entity_type(), to_graph_node.get_entity_name(), callable_name, public_name, state_machine)
		undo_redo.add_undo_method(state_machine.data, "unexpose_callable", public_name)
		undo_redo.commit_action()
	elif to_connection_type == ConnectionType.EXPOSE_SIGNAL and to_graph_node is SynapseRootSentinelGraphNode and to_slot_name == SynapseRootSentinelGraphNode.SLOT_EXPOSE_SIGNAL_OR_CALLABLE:
		var signal_name: StringName = from_graph_node.get_emitted_signal_info(from_slot_name)["name"]
		var public_name := SynapseGUIUtil.validate_name(signal_name, func(n: StringName) -> bool: return state_machine.data.exposed_signals.has(n))
		undo_redo.create_action("Expose '" + public_name + "'", UndoRedo.MERGE_DISABLE, state_machine)
		undo_redo.add_do_method(state_machine.data, "expose_signal", from_graph_node.get_entity_type(), from_graph_node.get_entity_name(), signal_name, public_name, state_machine)
		undo_redo.add_undo_method(state_machine.data, "unexpose_signal", public_name)
		undo_redo.commit_action()
	elif to_connection_type == ConnectionType.PROPERTY_REFERENCE_IN and to_graph_node is SynapseSignalBridgeGraphNode:
		var signal_bridge_data := state_machine.data.signal_bridges[to_graph_node.get_entity_name()]
		@warning_ignore("unsafe_cast")
		var entity_property_reference_data := SynapseEntityPropertyReferenceData.create(from_graph_node.get_entity_reference(), from_graph_node.get_runtime_property_info(from_slot_name)["name"] as StringName)
		@warning_ignore("unsafe_cast")
		var argument_name := (to_graph_node as SynapseSignalBridgeGraphNode).get_argument_info(to_slot_name)["name"] as String
		undo_redo.create_action("Assign " + from_graph_node.get_entity_name() + "." + entity_property_reference_data.property_name + " -> " + to_graph_node.get_entity_name() + "." + to_slot_name, UndoRedo.MERGE_DISABLE, state_machine)
		if signal_bridge_data.property_references.has(argument_name):
			# remove existing assignment
			undo_redo.add_do_method(state_machine.data, "unassign_signal_bridge_property_reference", signal_bridge_data.name, argument_name)
		undo_redo.add_do_method(state_machine.data, "assign_signal_bridge_property_reference", to_graph_node.get_entity_name(), entity_property_reference_data, argument_name)
		undo_redo.add_undo_method(state_machine.data, "unassign_signal_bridge_property_reference", to_graph_node.get_entity_name(), argument_name)
		if signal_bridge_data.property_references.has(argument_name):
			# re-add previous assignment
			undo_redo.add_undo_method(state_machine.data, "assign_signal_bridge_property_reference", signal_bridge_data.name, signal_bridge_data.property_references[argument_name], argument_name)
		undo_redo.commit_action()
	elif from_connection_type == ConnectionType.SIGNAL_OUT and to_connection_type == ConnectionType.SIGNAL_IN:
		var signal_info := from_graph_node.get_emitted_signal_info(from_slot_name)
		var callable_info := to_graph_node.get_signal_receive_slot_callable_info(to_slot_name)
		@warning_ignore("unsafe_cast")
		var signal_name := signal_info["name"] as StringName
		@warning_ignore("unsafe_cast")
		var callable_name := callable_info["name"] as StringName
		if signal_info.is_empty() or callable_info.is_empty():
			return
		var signal_source_data := state_machine.data.create_signal_source_data_for(state_machine, from_graph_node.get_entity_type(), from_graph_node.get_entity_name(), signal_name)
		undo_redo.create_action("Connect signal " + from_graph_node.get_entity_name() + "." + signal_name + " -> " + to_graph_node.get_entity_name() + "." + callable_name + "()", UndoRedo.MERGE_DISABLE, state_machine)
		if Input.is_key_pressed(INPUT_KEY__FORCE_SIGNAL_BRIDGE) or not SynapseClassUtil.is_signature_compatible(signal_info, callable_info):
			var signal_bridge_data := SynapseSignalBridgeData.create(
				validate_signal_bridge_name(signal_source_data.signal_id + "__" + to_slot_name),
				signal_source_data,
				state_machine.data.create_callable_target_data_for(state_machine, to_graph_node.get_entity_type(), to_graph_node.get_entity_name(), callable_name)
			)
			signal_bridge_data.graph_pos = (from_graph_node.position_offset + to_graph_node.position_offset) / 2.0
			undo_redo.add_do_method(state_machine.data, "add_signal_bridge", signal_bridge_data)
			undo_redo.add_undo_method(state_machine.data, "remove_entity", SynapseStateMachineData.EntityType.SIGNAL_BRIDGE, signal_bridge_data.name)
		else:
			undo_redo.add_do_method(state_machine.data, "connect_signal", signal_source_data, to_graph_node.get_entity_type(), to_graph_node.get_entity_name(), callable_name)
			undo_redo.add_undo_method(state_machine.data, "disconnect_signal", signal_source_data, to_graph_node.get_entity_type(), to_graph_node.get_entity_name(), callable_name)
		undo_redo.commit_action()
	elif from_graph_node is SynapseStateGraphNode and to_graph_node is SynapseBehaviorGraphNode:
		var new_state_graph_node := from_graph_node as SynapseStateGraphNode
		var behavior_graph_node := to_graph_node as SynapseBehaviorGraphNode
		var current_owner_name := state_machine.data.behaviors[behavior_graph_node.get_entity_name()].owner_state_name
		if current_owner_name == new_state_graph_node.get_entity_name():
			# already assigned
			return
		undo_redo.create_action("Set " + behavior_graph_node.get_entity_name() + " owner to " + new_state_graph_node.get_entity_name(), UndoRedo.MERGE_DISABLE, state_machine)
		if current_owner_name:
			undo_redo.add_do_method(state_machine.data, "remove_behavior_from_owner_state", behavior_graph_node.get_entity_name())
		undo_redo.add_do_method(state_machine.data, "add_behavior_to_owner_state", behavior_graph_node.get_entity_name(), new_state_graph_node.get_entity_name())
		undo_redo.add_undo_method(state_machine.data, "remove_behavior_from_owner_state", behavior_graph_node.get_entity_name())
		if current_owner_name:
			undo_redo.add_undo_method(state_machine.data, "add_behavior_to_owner_state", behavior_graph_node.get_entity_name(), current_owner_name)
		undo_redo.commit_action()
	elif from_graph_node is SynapseRootSentinelGraphNode and to_graph_node is SynapseStateGraphNode and from_connection_type == ConnectionType.CHILD:
		if state_machine.data.root_state == to_graph_node.get_entity_name():
			# already the root
			return
		var state_data := state_machine.data.states[to_graph_node.get_entity_name()]
		undo_redo.create_action("Assign root state", UndoRedo.MERGE_DISABLE, state_machine)
		undo_redo.add_undo_method(state_machine.data, "set", "root_state", state_machine.data.root_state)
		if state_data.parent_name:
			undo_redo.add_undo_method(state_machine.data, "add_state_to", state_data.name, state_data.parent_name)
			# child order matters (e.g. for sequence state transitions)
			undo_redo.add_undo_method(state_machine.data, "order_child_states", state_data.parent_name, state_machine.data.states[state_data.parent_name].child_names.duplicate())
			state_machine.data.states[state_data.parent_name].remove_child_state_undoable(self, state_data)
			undo_redo.add_do_method(state_machine.data, "remove_state_from_parent", state_data.name)
		undo_redo.add_do_method(state_machine.data, "set", "root_state", state_data.name)
		undo_redo.commit_action()
	elif from_graph_node is SynapseStateGraphNode and to_graph_node is SynapseStateGraphNode and from_connection_type == ConnectionType.CHILD:
		# reparent a state
		var parent_state_graph_node := from_graph_node as SynapseStateGraphNode
		var child_state_graph_node := to_graph_node as SynapseStateGraphNode
		if state_machine.data.states[child_state_graph_node.get_entity_name()].parent_name == parent_state_graph_node.get_entity_name():
			# already related
			return

		var parent_state_data := state_machine.data.states[parent_state_graph_node.get_entity_name()]
		var max_child_count := parent_state_data.get_max_child_count()
		if max_child_count >= 0 and state_machine.data.states[parent_state_graph_node.get_entity_name()].child_names.size() >= max_child_count:
			push_warning(parent_state_data.get_type_name(), " '", parent_state_graph_node.get_entity_name(), "' cannot have", " more" if max_child_count > 0 else "", " children")
			return

		var child_state_data := state_machine.data.states[child_state_graph_node.get_entity_name()]
		undo_redo.create_action("Set " + child_state_graph_node.get_entity_name() + " parent to " + parent_state_graph_node.get_entity_name(), UndoRedo.MERGE_DISABLE, state_machine)
		undo_redo.add_undo_method(state_machine.data, "remove_state_from_parent", child_state_graph_node.get_entity_name())
		if child_state_data.parent_name:
			undo_redo.add_undo_method(state_machine.data, "add_state_to", child_state_graph_node.get_entity_name(), child_state_data.parent_name)
			# child order matters (e.g. for sequence state transitions)
			undo_redo.add_undo_method(state_machine.data, "order_child_states", child_state_data.parent_name, state_machine.data.states[child_state_data.parent_name].child_names.duplicate())
			state_machine.data.states[child_state_data.parent_name].remove_child_state_undoable(self, child_state_data)
			undo_redo.add_do_method(state_machine.data, "remove_state_from_parent", child_state_graph_node.get_entity_name())
		elif state_machine.data.root_state == child_state_data.name:
			undo_redo.add_do_method(state_machine.data, "set", "root_state", &"")
		undo_redo.add_do_method(state_machine.data, "add_state_to", child_state_graph_node.get_entity_name(), parent_state_graph_node.get_entity_name())
		if state_machine.data.root_state == child_state_data.name:
			undo_redo.add_undo_method(state_machine.data, "set", "root_state", child_state_data.name)
		undo_redo.commit_action()
	elif from_graph_node is SynapseStateGraphNode and to_graph_node is SynapseStateGraphNode and from_connection_type == ConnectionType.TRANSITION_TO:
		var from_state_data := state_machine.data.states[from_graph_node.get_entity_name()]
		var to_state_data := state_machine.data.states[to_graph_node.get_entity_name()]
		if from_state_data.parent_name != to_state_data.parent_name:
			return
		var parent_state_data := state_machine.data.states[from_state_data.parent_name]
		if parent_state_data.can_create_child_transition(from_state_data, to_state_data):
			parent_state_data.create_child_transition(self, from_state_data, to_state_data)
			state_machine.update_configuration_warnings()
	elif from_graph_node is SynapseParameterGraphNode and from_connection_type == ConnectionType.PARAMETER_READER and to_connection_type == ConnectionType.PARAMETER_RO:
		var parameter_data := state_machine.data.parameters[from_graph_node.get_entity_name()]
		var referencing_entity_data := state_machine.data.get_entity(to_graph_node.get_entity_type(), to_graph_node.get_entity_name())
		undo_redo.create_action("Reference parameter '%s'" % [parameter_data.name], UndoRedo.MERGE_DISABLE, state_machine)
		referencing_entity_data.reference_parameter_undoable(parameter_data, to_slot_name, self)
		undo_redo.commit_action()
	elif to_graph_node is SynapseParameterGraphNode and from_connection_type == ConnectionType.PARAMETER_RW and to_connection_type == ConnectionType.PARAMETER_WRITER:
		var parameter_data := state_machine.data.parameters[to_graph_node.get_entity_name()]
		var referencing_entity_data := state_machine.data.get_entity(from_graph_node.get_entity_type(), from_graph_node.get_entity_name())
		undo_redo.create_action("Reference parameter '%s'" % [parameter_data.name], UndoRedo.MERGE_DISABLE, state_machine)
		referencing_entity_data.reference_parameter_undoable(parameter_data, from_slot_name, self)
		undo_redo.commit_action()

func _on_delete_nodes_request(nodes: Array[StringName]) -> void:
	var state_names: Array[StringName] = []
	var behavior_names: Array[StringName] = []
	var parameter_names: Array[StringName] = []
	var signal_bridge_names: Array[StringName] = []

	for node_name in nodes:
		var node := get_node(NodePath(node_name))
		var entity_name: StringName
		if node is SynapseRootSentinelGraphNode:
			continue
		elif node is SynapseStateGraphNode:
			entity_name = (node as SynapseStateGraphNode).get_entity_name()
			state_names.append(entity_name)
		elif node is SynapseBehaviorGraphNode:
			entity_name = (node as SynapseBehaviorGraphNode).get_entity_name()
			behavior_names.append(entity_name)
		elif node is SynapseParameterGraphNode:
			entity_name = (node as SynapseParameterGraphNode).get_entity_name()
			parameter_names.append(entity_name)
		elif node is SynapseSignalBridgeGraphNode:
			entity_name = (node as SynapseSignalBridgeGraphNode).get_entity_name()
			signal_bridge_names.append(entity_name)
		else:
			push_warning("Don't know how to delete ", node)
			continue

	if state_names or behavior_names or parameter_names or signal_bridge_names:
		erase("Delete node(s)", state_names, behavior_names, parameter_names, signal_bridge_names)

func _on_erase_button_pressed() -> void:
	erase_confirmation_dialog.popup_centered()

func _on_erase_confirmation_dialog_confirmed() -> void:
	erase("Erase state machine", state_machine.data.states.keys(), state_machine.data.behaviors.keys(), state_machine.data.parameters.keys(), state_machine.data.signal_bridges.keys(), true)

func _on_parameter_value_set() -> void:
	state_machine.notify_property_list_changed() # force the inspector plugin to refresh
	state_machine.update_configuration_warnings()

func _on_state_machine_data_set() -> void:
	_clear_graph()

	if previous_data:
		_dissociate_data(previous_data)
	previous_data = state_machine.data
	if not state_machine.data:
		state_machine.update_configuration_warnings()
		return # should not happen (but could transiently?)

	# root sentinel
	root_sentinel = SynapseStateMachineEditorResourceManager.Scenes.instantiate_root_sentinel_graph_node()
	add_child(root_sentinel)
	root_sentinel.setup_for(state_machine)
	root_sentinel.dragged.connect(_on_root_sentinel_node_moved)
	root_sentinel.slots_updated.connect(update_connections)
	root_sentinel.exposed_callable_rename_requested.connect(_on_exposed_callable_rename_requested)
	root_sentinel.exposed_signal_rename_requested.connect(_on_exposed_signal_rename_requested)

	# reposition to last offset & zoom
	sync_view()

	# create state graph nodes (and their parent/child connections)
	var backlog: Array[SynapseStateData] = []
	backlog.append_array(state_machine.data.states.values())
	while backlog:
		for i in range(len(backlog) - 1, -1, -1):
			var state_data := backlog[i]
			if not state_data.parent_name or state_data.parent_name in state_graph_nodes:
				backlog.erase(state_data)
				_on_state_machine_data_state_added(state_data, true)
				if state_data.parent_name:
					_on_state_machine_data_state_child_added(state_data, state_machine.data.states[state_data.parent_name])
	_on_state_machine_data_root_state_set(state_machine.data.root_state)

	# create behavior graph nodes (and their connections to their owner states)
	for behavior_data: SynapseBehaviorData in state_machine.data.behaviors.values():
		_on_state_machine_data_behavior_added(behavior_data)
		if behavior_data.owner_state_name:
			_on_state_machine_data_behavior_added_to_state(behavior_data, state_machine.data.states[behavior_data.owner_state_name])

	# create parameter graph nodes
	for parameter_name in state_machine.data.parameters:
		var parameter_data := state_machine.data.parameters[parameter_name]
		_on_state_machine_data_parameter_added(parameter_data)

	for state_data: SynapseStateData in state_machine.data.states.values():
		# Do this last for bulk loading because some states depend on other graph nodes existing
		state_data.prepare_in_editor(self)

	# create parameter reference connections
	for entity_data in state_machine.data.get_all_entities():
		for ref in entity_data.get_parameter_references(state_machine):
			var parameter_data := state_machine.data.parameters[ref.parameter_name]
			_on_state_machine_data_parameter_reference_added(parameter_data, entity_data, ref.property_name, ref.access)

	# signal bridges can only connect once all graph nodes exist
	# (note: signal bridges can't connect to each other, yet, so we don't bother with ordering here)
	for signal_bridge_data: SynapseSignalBridgeData in state_machine.data.signal_bridges.values():
		_on_state_machine_data_signal_bridge_added(signal_bridge_data)
		for callable_argument_name in signal_bridge_data.property_references:
			var entity_property_reference_data := signal_bridge_data.property_references[callable_argument_name]
			_on_state_machine_data_signal_bridge_property_reference_assigned(signal_bridge_data, entity_property_reference_data, callable_argument_name)
		for callable_argument_name in signal_bridge_data.wired_parameters:
			var signal_arg_name := signal_bridge_data.wired_parameters[callable_argument_name]
			_on_state_machine_data_signal_bridge_signal_property_wired(signal_bridge_data, signal_arg_name, callable_argument_name)

	# signal connections can only be shown once all graph nodes exist
	for state_data: SynapseStateData in state_machine.data.states.values():
		for callable_id in state_data.connected_signals:
			for signal_source_data: SynapseSignalSourceData in state_data.connected_signals[callable_id]:
				create_signal_connection(signal_source_data, state_data, callable_id)
	for behavior_data: SynapseBehaviorData in state_machine.data.behaviors.values():
		for callable_id in behavior_data.connected_signals:
			for signal_source_data: SynapseSignalSourceData in behavior_data.connected_signals[callable_id]:
				create_signal_connection(signal_source_data, behavior_data, callable_id)
	for parameter_data: SynapseParameterData in state_machine.data.parameters.values():
		for callable_id in parameter_data.connected_signals:
			for signal_source_data: SynapseSignalSourceData in parameter_data.connected_signals[callable_id]:
				create_signal_connection(signal_source_data, parameter_data, callable_id)

	# exposed callables and signals can only be shown once all graph nodes exist
	for public_callable_name in state_machine.data.exposed_callables:
		var ref := state_machine.data.exposed_callables[public_callable_name]
		_on_state_machine_data_entity_callable_exposed(state_machine.data.get_entity_from(ref.entity_reference), ref.property_name, public_callable_name)
	for public_signal_name in state_machine.data.exposed_signals:
		var ref := state_machine.data.exposed_signals[public_signal_name]
		_on_state_machine_data_entity_signal_exposed(state_machine.data.get_entity_from(ref.entity_reference), ref.property_name, public_signal_name)

	# listen for changes
	state_machine.data.root_state_set.connect(_on_state_machine_data_root_state_set)
	state_machine.data.entity_renamed.connect(_on_state_machine_data_entity_renamed)
	state_machine.data.entity_callable_exposed.connect(_on_state_machine_data_entity_callable_exposed)
	state_machine.data.entity_callable_unexposed.connect(_on_state_machine_data_entity_callable_unexposed)
	state_machine.data.exposed_entity_callable_renamed.connect(_on_state_machine_data_exposed_entity_callable_renamed)
	state_machine.data.entity_signal_exposed.connect(_on_state_machine_data_entity_signal_exposed)
	state_machine.data.entity_signal_unexposed.connect(_on_state_machine_data_entity_signal_unexposed)
	state_machine.data.exposed_entity_signal_renamed.connect(_on_state_machine_data_exposed_entity_signal_renamed)
	state_machine.data.state_added.connect(_on_state_machine_data_state_added)
	state_machine.data.state_removed.connect(_on_state_machine_data_state_removed)
	state_machine.data.state_child_added.connect(_on_state_machine_data_state_child_added)
	state_machine.data.state_child_removed.connect(_on_state_machine_data_state_child_removed)
	state_machine.data.state_child_order_changed.connect(_on_state_machine_data_state_child_order_changed)
	state_machine.data.state_behavior_order_changed.connect(_on_state_machine_data_state_behavior_order_changed)
	state_machine.data.state_connected_to_signal.connect(_on_state_machine_data_state_connected_to_signal)
	state_machine.data.state_disconnected_from_signal.connect(_on_state_machine_data_state_disconnected_from_signal)
	state_machine.data.behavior_added.connect(_on_state_machine_data_behavior_added)
	state_machine.data.behavior_removed.connect(_on_state_machine_data_behavior_removed)
	state_machine.data.behavior_added_to_state.connect(_on_state_machine_data_behavior_added_to_state)
	state_machine.data.behavior_removed_from_state.connect(_on_state_machine_data_behavior_removed_from_state)
	state_machine.data.behavior_connected_to_signal.connect(_on_state_machine_data_behavior_connected_to_signal)
	state_machine.data.behavior_disconnected_from_signal.connect(_on_state_machine_data_behavior_disconnected_from_signal)
	state_machine.data.parameter_added.connect(_on_state_machine_data_parameter_added)
	state_machine.data.parameter_removed.connect(_on_state_machine_data_parameter_removed)
	state_machine.data.parameter_reference_added.connect(_on_state_machine_data_parameter_reference_added)
	state_machine.data.parameter_reference_removed.connect(_on_state_machine_data_parameter_reference_removed)
	state_machine.data.parameter_exposed_set.connect(_on_state_machine_data_parameter_exposed_set)
	state_machine.data.parameter_connected_to_signal.connect(_on_state_machine_data_parameter_connected_to_signal)
	state_machine.data.parameter_disconnected_from_signal.connect(_on_state_machine_data_parameter_disconnected_from_signal)
	state_machine.data.signal_bridge_added.connect(_on_state_machine_data_signal_bridge_added)
	state_machine.data.signal_bridge_removed.connect(_on_state_machine_data_signal_bridge_removed)
	state_machine.data.signal_bridge_signal_property_wired.connect(_on_state_machine_data_signal_bridge_signal_property_wired)
	state_machine.data.signal_bridge_signal_property_unwired.connect(_on_state_machine_data_signal_bridge_signal_property_unwired)
	state_machine.data.signal_bridge_property_reference_assigned.connect(_on_state_machine_data_signal_bridge_property_reference_assigned)
	state_machine.data.signal_bridge_property_reference_unassigned.connect(_on_state_machine_data_signal_bridge_property_reference_unassigned)

	state_machine.update_configuration_warnings()

func _on_state_graph_node_child_order_changed(child_state_names: Array[StringName], parent_state_name: StringName) -> void:
	undo_redo.create_action("Change '" + parent_state_name + "' child order", UndoRedo.MERGE_DISABLE, state_machine)
	undo_redo.add_do_method(state_machine.data, "order_child_states", parent_state_name, child_state_names)
	undo_redo.add_undo_method(state_machine.data, "order_child_states", parent_state_name, state_machine.data.states[parent_state_name].child_names.duplicate())
	undo_redo.commit_action()

func _on_state_graph_node_behavior_order_changed(behavior_names: Array[StringName], state_name: StringName) -> void:
	undo_redo.create_action("Change '" + state_name + "' behavior order", UndoRedo.MERGE_DISABLE, state_machine)
	undo_redo.add_do_method(state_machine.data, "order_behaviors", state_name, behavior_names)
	undo_redo.add_undo_method(state_machine.data, "order_behaviors", state_name, state_machine.data.states[state_name].behavior_names.duplicate())
	undo_redo.commit_action()

func _on_state_machine_data_root_state_set(new_root_state_name: StringName) -> void:
	for c in _connection_proxies:
		if c.from_graph_node is SynapseRootSentinelGraphNode:
			remove_connection(c)
			break
	if new_root_state_name:
		var connection_proxy := ConnectionProxy.of(root_sentinel, SynapseRootSentinelGraphNode.SLOT_ROOT_STATE, state_graph_nodes[new_root_state_name], SynapseStateGraphNode.SLOT_PARENT)
		connection_proxy.remove_requested.connect(remove_state_as_root)
		add_connection(connection_proxy)
	state_machine.update_configuration_warnings()

func _on_state_machine_data_entity_renamed(entity_data: SynapseEntityData, previous_name: StringName) -> void:
	var graph_node := get_graph_node_for_entity(SynapseStateMachineData.get_entity_type(entity_data), previous_name)
	if not graph_node:
		return
	graph_node.set_entity_name(entity_data.name)

	var graph_node_map: Dictionary
	if graph_node is SynapseStateGraphNode:
		graph_node_map = state_graph_nodes
	elif graph_node is SynapseBehaviorGraphNode:
		graph_node_map = behavior_graph_nodes
	elif graph_node is SynapseParameterGraphNode:
		graph_node_map = parameter_graph_nodes
	elif graph_node is SynapseSignalBridgeGraphNode:
		graph_node_map = signal_bridge_graph_nodes
	graph_node_map.erase(previous_name)
	graph_node_map[entity_data.name] = graph_node

	state_machine.update_configuration_warnings()
	state_machine.notify_property_list_changed() # refreshes state machine inspector plugin (which lists parameters)

func _on_state_machine_data_state_added(state_data: SynapseStateData, bulk: bool = false) -> void:
	var state_graph_node := create_state_graph_node(state_data.name, state_data.graph_pos)
	state_graph_node.setup_for(state_machine, state_data)
	if not bulk:
		state_data.prepare_in_editor(self)
		state_machine.update_configuration_warnings()

func _on_state_machine_data_state_removed(state_data: SynapseStateData) -> void:
	state_data.teardown_in_editor(self, state_machine.data)
	state_graph_nodes[state_data.name].queue_free()
	state_graph_nodes.erase(state_data.name)
	state_machine.update_configuration_warnings()

func _on_state_machine_data_state_child_removed(child_state_data: SynapseStateData, parent_state_data: SynapseStateData) -> void:
	var parent_graph_node := state_graph_nodes[parent_state_data.name]
	var child_graph_node := state_graph_nodes[child_state_data.name]
	parent_graph_node.set_child_names(parent_state_data.child_names)
	remove_connection_between(parent_graph_node, SynapseStateGraphNode.SLOT_CHILDREN, child_graph_node, SynapseStateGraphNode.SLOT_PARENT)
	state_machine.update_configuration_warnings()

func _on_state_machine_data_state_child_added(child_state_data: SynapseStateData, parent_state_data: SynapseStateData) -> void:
	var child_graph_node := state_graph_nodes[child_state_data.name]
	var parent_graph_node := state_graph_nodes[parent_state_data.name]
	parent_graph_node.set_child_names(parent_state_data.child_names)
	var connection_proxy := ConnectionProxy.of(parent_graph_node, SynapseStateGraphNode.SLOT_CHILDREN, child_graph_node, SynapseStateGraphNode.SLOT_PARENT)
	connection_proxy.remove_requested.connect(remove_child_state_from_parent.bind(child_state_data.name))
	add_connection(connection_proxy)
	state_machine.update_configuration_warnings()

func _on_state_machine_data_state_child_order_changed(parent_state_data: SynapseStateData) -> void:
	var parent_graph_node := state_graph_nodes[parent_state_data.name]
	parent_graph_node.set_child_names(parent_state_data.child_names)
	state_machine.update_configuration_warnings()

func _on_state_machine_data_state_behavior_order_changed(state_data: SynapseStateData) -> void:
	var state_graph_node := state_graph_nodes[state_data.name]
	state_graph_node.set_behavior_names(state_data.behavior_names)

func _on_state_machine_data_behavior_added(behavior_data: SynapseBehaviorData) -> void:
	create_behavior_graph_node(behavior_data)
	var behavior := get_behavior_for(behavior_data)
	if behavior:
		behavior.state_machine = state_machine
	state_machine.update_configuration_warnings()

func _on_state_machine_data_behavior_removed(behavior_data: SynapseBehaviorData) -> void:
	behavior_graph_nodes[behavior_data.name].queue_free()
	behavior_graph_nodes.erase(behavior_data.name)
	state_machine.update_configuration_warnings()

func _on_state_machine_data_behavior_added_to_state(behavior_data: SynapseBehaviorData, state_data: SynapseStateData) -> void:
	var behavior_graph_node := behavior_graph_nodes[behavior_data.name]
	var state_graph_node := state_graph_nodes[state_data.name]
	var connection_proxy := ConnectionProxy.of(state_graph_node, SynapseStateGraphNode.SLOT_BEHAVIORS, behavior_graph_node, SynapseBehaviorGraphNode.SLOT_OWNER_STATE)
	connection_proxy.remove_requested.connect(remove_behavior_from_owner_state.bind(behavior_data.name))
	add_connection(connection_proxy)
	state_graph_node.set_behavior_names(state_data.behavior_names)
	state_machine.update_configuration_warnings()

func _on_state_machine_data_behavior_removed_from_state(behavior_data: SynapseBehaviorData, state_data: SynapseStateData) -> void:
	var state_graph_node := state_graph_nodes[state_data.name]
	var behavior_graph_node := behavior_graph_nodes[behavior_data.name]
	state_graph_node.set_behavior_names(state_data.behavior_names)
	remove_connection_between(state_graph_node, SynapseStateGraphNode.SLOT_BEHAVIORS, behavior_graph_node, SynapseBehaviorGraphNode.SLOT_OWNER_STATE)
	state_machine.update_configuration_warnings()

func _on_state_machine_data_parameter_added(parameter_data: SynapseParameterData) -> void:
	create_parameter_graph_node(parameter_data)
	state_machine.notify_property_list_changed() # refreshes state machine inspector plugin (which lists parameters)
	state_machine.update_configuration_warnings()

func _on_state_machine_data_parameter_removed(parameter_data: SynapseParameterData) -> void:
	parameter_graph_nodes[parameter_data.name].queue_free()
	parameter_graph_nodes.erase(parameter_data.name)
	state_machine.notify_property_list_changed() # refreshes state machine inspector plugin (which lists parameters)
	state_machine.update_configuration_warnings()

func _on_state_machine_data_parameter_reference_added(parameter_data: SynapseParameterData, entity_data: SynapseEntityData, property_name: StringName, access: SynapseParameterData.Access) -> void:
	var parameter_graph_node := parameter_graph_nodes[parameter_data.name]
	var referencing_graph_node := get_graph_node_for(entity_data)
	var connection_proxy: ConnectionProxy
	if access == SynapseParameterData.Access.RW:
		connection_proxy = ConnectionProxy.of(referencing_graph_node, property_name, parameter_graph_node, SynapseParameterGraphNode.SLOT_ACCESS)
	else:
		connection_proxy = ConnectionProxy.of(parameter_graph_node, SynapseParameterGraphNode.SLOT_ACCESS, referencing_graph_node, property_name)
	connection_proxy.remove_requested.connect(remove_parameter_reference.bind(parameter_data, entity_data, property_name))
	add_connection(connection_proxy)
	state_machine.update_configuration_warnings()

func _on_state_machine_data_parameter_reference_removed(parameter_data: SynapseParameterData, entity_data: SynapseEntityData, property_name: StringName, access: SynapseParameterData.Access) -> void:
	var parameter_graph_node := parameter_graph_nodes[parameter_data.name]
	var referencing_graph_node := get_graph_node_for(entity_data)
	if access == SynapseParameterData.Access.RW:
		remove_connection_between(referencing_graph_node, property_name, parameter_graph_node, SynapseParameterGraphNode.SLOT_ACCESS)
	else:
		remove_connection_between(parameter_graph_node, SynapseParameterGraphNode.SLOT_ACCESS, referencing_graph_node, property_name)
	state_machine.update_configuration_warnings()

func _on_state_machine_data_parameter_exposed_set(_parameter_data: SynapseParameterData) -> void:
	state_machine.notify_property_list_changed() # force the inspector plugin to refresh

func _on_scroll_offset_changed(offset: Vector2) -> void:
	if state_machine and state_machine.data:
		state_machine.data.editor_scroll_offset = offset
		state_machine.data.editor_zoom = zoom
		state_machine.data.emit_changed()

func _on_state_machine_data_state_connected_to_signal(state_data: SynapseStateData, method_name: StringName, signal_source_data: SynapseSignalSourceData) -> void:
	create_signal_connection(signal_source_data, state_data, method_name)

func _on_state_machine_data_state_disconnected_from_signal(state_data: SynapseStateData, method_name: StringName, signal_source_data: SynapseSignalSourceData) -> void:
	remove_signal_connection(signal_source_data, state_data, method_name)

func _on_state_machine_data_behavior_connected_to_signal(behavior_data: SynapseBehaviorData, signal_relay_connector_name: StringName, signal_source_data: SynapseSignalSourceData) -> void:
	create_signal_connection(signal_source_data, behavior_data, signal_relay_connector_name)

func _on_state_machine_data_behavior_disconnected_from_signal(behavior_data: SynapseBehaviorData, signal_relay_connector_name: StringName, signal_source_data: SynapseSignalSourceData) -> void:
	remove_signal_connection(signal_source_data, behavior_data, signal_relay_connector_name)

func _on_state_machine_data_parameter_connected_to_signal(parameter_data: SynapseParameterData, method_name: StringName, signal_source_data: SynapseSignalSourceData) -> void:
	create_signal_connection(signal_source_data, parameter_data, method_name)

func _on_state_machine_data_parameter_disconnected_from_signal(parameter_data: SynapseParameterData, method_name: StringName, signal_source_data: SynapseSignalSourceData) -> void:
	remove_signal_connection(signal_source_data, parameter_data, method_name)

func _on_state_machine_data_signal_bridge_added(signal_bridge_data: SynapseSignalBridgeData) -> void:
	var signal_bridge_graph_node := create_signal_bridge_graph_node(signal_bridge_data)
	@warning_ignore("unsafe_cast")
	var signal_source_data := signal_bridge_data.connected_signals[SynapseSignalBridgeData.CALLABLE_NAME][0] as SynapseSignalSourceData
	var source_graph_node := get_graph_node_for_reference(signal_source_data.source_entity_reference)
	var target_graph_node := get_graph_node_for_reference(signal_bridge_data.callable_target_data.target_entity_reference)
	var source_slot_name := source_graph_node.get_slot_name_for_emitted_signal_name(signal_source_data.signal_id)
	var target_slot_name := target_graph_node.get_slot_name_for_signal_receive_callable_name(signal_bridge_data.callable_target_data.callable_id)
	var source_connection_proxy := ConnectionProxy.of(source_graph_node, source_slot_name, signal_bridge_graph_node, SynapseSignalBridgeGraphNode.SLOT_BRIDGE)
	source_connection_proxy.remove_requested.connect(remove_signal_bridge.bind(signal_bridge_data.name))
	add_connection(source_connection_proxy)
	var target_connection_proxy := ConnectionProxy.of(signal_bridge_graph_node, SynapseSignalBridgeGraphNode.SLOT_BRIDGE, target_graph_node, target_slot_name)
	target_connection_proxy.remove_requested.connect(remove_signal_bridge.bind(signal_bridge_data.name))
	add_connection(target_connection_proxy)
	state_machine.update_configuration_warnings()

func _on_state_machine_data_signal_bridge_removed(signal_bridge_data: SynapseSignalBridgeData) -> void:
	var signal_bridge_graph_node := signal_bridge_graph_nodes[signal_bridge_data.name]
	@warning_ignore("unsafe_cast")
	var signal_source_data := signal_bridge_data.connected_signals[SynapseSignalBridgeData.CALLABLE_NAME][0] as SynapseSignalSourceData
	var source_graph_node := get_graph_node_for_reference(signal_source_data.source_entity_reference)
	var target_graph_node := get_graph_node_for_reference(signal_bridge_data.callable_target_data.target_entity_reference)
	var source_slot_name := source_graph_node.get_slot_name_for_emitted_signal_name(signal_source_data.signal_id)
	var target_slot_name := target_graph_node.get_slot_name_for_signal_receive_callable_name(signal_bridge_data.callable_target_data.callable_id)
	remove_connection_between(source_graph_node, source_slot_name, signal_bridge_graph_node, SynapseSignalBridgeGraphNode.SLOT_BRIDGE)
	remove_connection_between(signal_bridge_graph_node, SynapseSignalBridgeGraphNode.SLOT_BRIDGE, target_graph_node, target_slot_name)
	signal_bridge_graph_node.queue_free()
	signal_bridge_graph_nodes.erase(signal_bridge_data.name)
	state_machine.update_configuration_warnings()

func _on_state_machine_data_signal_bridge_property_reference_assigned(signal_bridge_data: SynapseSignalBridgeData, entity_property_reference_data: SynapseEntityPropertyReferenceData, argument_name: StringName) -> void:
	var signal_bridge_graph_node := signal_bridge_graph_nodes[signal_bridge_data.name]
	var to_slot_name := signal_bridge_graph_node.get_slot_name_for_callable_argument_name(argument_name)
	signal_bridge_graph_node.notify_property_reference_assigned(to_slot_name)
	var entity_graph_node := get_graph_node_for_reference(entity_property_reference_data.entity_reference)
	@warning_ignore("unsafe_cast")
	var connection_proxy := ConnectionProxy.of(entity_graph_node, entity_graph_node.get_slot_name_for_runtime_property_name(entity_property_reference_data.property_name), signal_bridge_graph_node, to_slot_name)
	connection_proxy.remove_requested.connect(remove_signal_bridge_property_reference.bind(signal_bridge_data.name, argument_name))
	add_connection(connection_proxy)
	state_machine.update_configuration_warnings()

func _on_state_machine_data_signal_bridge_property_reference_unassigned(signal_bridge_data: SynapseSignalBridgeData, entity_property_reference_data: SynapseEntityPropertyReferenceData, argument_name: StringName) -> void:
	var signal_bridge_graph_node := signal_bridge_graph_nodes[signal_bridge_data.name]
	var to_slot_name := signal_bridge_graph_node.get_slot_name_for_callable_argument_name(argument_name)
	signal_bridge_graph_node.notify_property_reference_unassigned(to_slot_name)
	var entity_graph_node := get_graph_node_for_reference(entity_property_reference_data.entity_reference)
	@warning_ignore("unsafe_cast")
	remove_connection_between(entity_graph_node, entity_graph_node.get_slot_name_for_runtime_property_name(entity_property_reference_data.property_name), signal_bridge_graph_node, to_slot_name)
	state_machine.update_configuration_warnings()

func _on_state_machine_data_signal_bridge_signal_property_wired(signal_bridge_data: SynapseSignalBridgeData, signal_arg_name: StringName, callable_arg_name: StringName) -> void:
	var signal_bridge_graph_node := signal_bridge_graph_nodes[signal_bridge_data.name]
	var to_slot_name := signal_bridge_graph_node.get_slot_name_for_callable_argument_name(callable_arg_name)
	signal_bridge_graph_node.notify_signal_argument_wired(to_slot_name, signal_arg_name)
	state_machine.update_configuration_warnings()

func _on_state_machine_data_signal_bridge_signal_property_unwired(signal_bridge_data: SynapseSignalBridgeData, callable_arg_name: StringName) -> void:
	var signal_bridge_graph_node := signal_bridge_graph_nodes[signal_bridge_data.name]
	var to_slot_name := signal_bridge_graph_node.get_slot_name_for_callable_argument_name(callable_arg_name)
	signal_bridge_graph_node.notify_signal_argument_unwired(to_slot_name)
	state_machine.update_configuration_warnings()

func _on_state_machine_data_entity_callable_exposed(entity_data: SynapseEntityData, callable_name: StringName, public_name: StringName) -> void:
	root_sentinel.recreate_slots(state_machine)
	var from_slot_name := root_sentinel.get_slot_name_for_exposed_callable(public_name)
	var to_graph_node := get_graph_node_for(entity_data)
	var to_slot_name := to_graph_node.get_slot_name_for_signal_receive_callable_name(callable_name)
	var proxy := ConnectionProxy.of(root_sentinel, from_slot_name, to_graph_node, to_slot_name)
	add_connection(proxy)
	proxy.remove_requested.connect(_on_exposed_callable_unexposed.bind(public_name))

func _on_state_machine_data_entity_callable_unexposed(_entity_data: SynapseEntityData, _callable_name: StringName, public_name: StringName) -> void:
	var slot_name := root_sentinel.get_slot_name_for_exposed_callable(public_name)
	remove_connection(find_first_connection_matching(func(c: ConnectionProxy) -> bool: return is_same(c.from_graph_node, root_sentinel) and c.from_slot == slot_name))
	root_sentinel.recreate_slots(state_machine)

func _on_state_machine_data_exposed_entity_callable_renamed(entity_data: SynapseEntityData, callable_name: StringName, previous_public_name: StringName, new_public_name: StringName) -> void:
	_on_state_machine_data_entity_callable_unexposed(entity_data, callable_name, previous_public_name)
	_on_state_machine_data_entity_callable_exposed(entity_data, callable_name, new_public_name)

func _on_state_machine_data_entity_signal_exposed(entity_data: SynapseEntityData, signal_name: StringName, public_name: StringName) -> void:
	root_sentinel.recreate_slots(state_machine)
	var to_slot_name := root_sentinel.get_slot_name_for_exposed_signal(public_name)
	var from_graph_node := get_graph_node_for(entity_data)
	var from_slot_name := from_graph_node.get_slot_name_for_emitted_signal_name(signal_name)
	var proxy := ConnectionProxy.of(from_graph_node, from_slot_name, root_sentinel, to_slot_name)
	add_connection(proxy)
	proxy.remove_requested.connect(_on_exposed_signal_unexposed.bind(public_name))

func _on_state_machine_data_entity_signal_unexposed(_entity_data: SynapseEntityData, _signal_name: StringName, public_name: StringName) -> void:
	var slot_name := root_sentinel.get_slot_name_for_exposed_signal(public_name)
	remove_connection(find_first_connection_matching(func(c: ConnectionProxy) -> bool: return is_same(c.to_graph_node, root_sentinel) and c.to_slot == slot_name))
	root_sentinel.recreate_slots(state_machine)

func _on_state_machine_data_exposed_entity_signal_renamed(entity_data: SynapseEntityData, signal_name: StringName, previous_public_name: StringName, new_public_name: StringName) -> void:
	_on_state_machine_data_entity_signal_unexposed(entity_data, signal_name, previous_public_name)
	_on_state_machine_data_entity_signal_exposed(entity_data, signal_name, new_public_name)

func _on_signal_bridge_argument_wired(signal_argument_name: StringName, callable_argument_name: StringName, signal_bridge_graph_node: SynapseSignalBridgeGraphNode) -> void:
	undo_redo.create_action("Bind signal argument to callable argument", UndoRedo.MERGE_DISABLE, state_machine)
	undo_redo.add_do_method(state_machine.data, "wire_signal_bridge_signal_argument", signal_bridge_graph_node.get_entity_name(), signal_argument_name, callable_argument_name)
	undo_redo.add_undo_method(state_machine.data, "unwire_signal_bridge_signal_argument", signal_bridge_graph_node.get_entity_name(), callable_argument_name)
	undo_redo.commit_action()

func _on_signal_bridge_argument_unwired(callable_argument_name: StringName, signal_bridge_graph_node: SynapseSignalBridgeGraphNode) -> void:
	var signal_argument_name := state_machine.data.signal_bridges[signal_bridge_graph_node.get_entity_name()].wired_parameters[callable_argument_name]
	undo_redo.create_action("Unbind callable argument", UndoRedo.MERGE_DISABLE, state_machine)
	undo_redo.add_do_method(state_machine.data, "unwire_signal_bridge_signal_argument", signal_bridge_graph_node.get_entity_name(), callable_argument_name)
	undo_redo.add_undo_method(state_machine.data, "wire_signal_bridge_signal_argument", signal_bridge_graph_node.get_entity_name(), signal_argument_name, callable_argument_name)
	undo_redo.commit_action()

func _on_connection_delete_button_pressed() -> void:
	if not _closest_connection_proxy_for_deletion:
		return
	_closest_connection_proxy_for_deletion.remove_requested.emit()
	_closest_connection_proxy_for_deletion = null
	delete_connection_button.hide()

func _on_exposed_callable_unexposed(public_name: StringName) -> void:
	var ref := state_machine.data.exposed_callables[public_name]
	if not ref:
		push_warning("Unable to find exposed callable: '", public_name, "'")
		return
	undo_redo.create_action("Stop exposing '" + public_name + "'", UndoRedo.MERGE_DISABLE, state_machine)
	undo_redo.add_do_method(state_machine.data, "unexpose_callable", public_name)
	undo_redo.add_undo_method(state_machine.data, "expose_callable", ref.entity_reference.entity_type, ref.entity_reference.entity_name, ref.property_name, public_name, state_machine)
	undo_redo.commit_action()

func _on_exposed_callable_rename_requested(previous_public_name: StringName, requested_new_public_name: StringName) -> void:
	var ref := state_machine.data.exposed_callables[previous_public_name]
	if not ref:
		push_warning("Unable to find exposed callable: '", previous_public_name, "'")
		return
	var new_public_name := SynapseGUIUtil.validate_name(requested_new_public_name, func(n: StringName) -> bool: return n != previous_public_name and state_machine.data.exposed_callables.has(n))
	undo_redo.create_action("Rename exposed callable", UndoRedo.MERGE_DISABLE, state_machine)
	undo_redo.add_do_method(state_machine.data, "rename_exposed_callable", previous_public_name, new_public_name)
	undo_redo.add_undo_method(state_machine.data, "rename_exposed_callable", new_public_name, previous_public_name)
	undo_redo.commit_action()

func _on_exposed_signal_unexposed(public_name: StringName) -> void:
	var ref := state_machine.data.exposed_signals[public_name]
	if not ref:
		push_warning("Unable to find exposed signal: '", public_name, "'")
		return
	undo_redo.create_action("Stop exposing '" + public_name + "'", UndoRedo.MERGE_DISABLE, state_machine)
	undo_redo.add_do_method(state_machine.data, "unexpose_signal", public_name)
	undo_redo.add_undo_method(state_machine.data, "expose_signal", ref.entity_reference.entity_type, ref.entity_reference.entity_name, ref.property_name, public_name, state_machine)
	undo_redo.commit_action()

func _on_exposed_signal_rename_requested(previous_public_name: StringName, requested_new_public_name: StringName) -> void:
	var ref := state_machine.data.exposed_signals[previous_public_name]
	if not ref:
		push_warning("Unable to find exposed signal: '", previous_public_name, "'")
		return
	var new_public_name := SynapseGUIUtil.validate_name(requested_new_public_name, func(n: StringName) -> bool: return n != previous_public_name and state_machine.data.exposed_signals.has(n))
	undo_redo.create_action("Rename exposed signal", UndoRedo.MERGE_DISABLE, state_machine)
	undo_redo.add_do_method(state_machine.data, "rename_exposed_signal", previous_public_name, new_public_name)
	undo_redo.add_undo_method(state_machine.data, "rename_exposed_signal", new_public_name, previous_public_name)
	undo_redo.commit_action()

func _on_popup_request(at_position: Vector2) -> void:
	add_entity_popup_menu.position = get_screen_position() + at_position
	add_entity_popup_menu.clear(true)
	_graph_position = (at_position + scroll_offset) / zoom

	add_entity_popup_menu.add_separator("Add:")

	var parameter_submenu := PopupMenu.new()
	parameter_submenu.id_pressed.connect(_on_add_parameter_request.bind(parameter_submenu))
	add_entity_popup_menu.add_submenu_node_item("Parameter", parameter_submenu)
	var parameter_scripts: Array[Script] = []
	for parameter_script in resource_cache.get_cached_parameter_scripts():
		var script := parameter_script.load_script()
		if script.is_abstract():
			continue
		if not script.get_global_name():
			continue
		for prop in script.get_script_property_list():
			if prop["name"] == "value":
				parameter_scripts.append(script)
				break
	parameter_scripts.sort_custom(func(s1: Script, s2: Script) -> bool: return s1.get_global_name().naturalcasecmp_to(s2.get_global_name()) < 0)
	for id in len(parameter_scripts):
		var script := parameter_scripts[id]
		parameter_submenu.add_icon_item(SynapseClassUtil.get_script_icon(script), script.get_global_name())
		parameter_submenu.set_item_metadata(parameter_submenu.get_item_index(id), script)

	_parent_is_root = false
	_parent_state_name = &""

	var behavior_submenu := PopupMenu.new()
	add_entity_popup_menu.add_submenu_node_item("Behavior", behavior_submenu)
	populate_behaviors_by_category(behavior_submenu)

	var state_submenu := PopupMenu.new()
	add_entity_popup_menu.add_submenu_node_item("State", state_submenu)
	state_submenu.id_pressed.connect(_on_add_state_popup_menu_item_selected)
	populate_state_add_menu(state_submenu)

	add_entity_popup_menu.popup()

func _on_add_parameter_request(id: int, menu: PopupMenu) -> void:
	var parameter_script: Script = menu.get_item_metadata(menu.get_item_index(id))
	create_parameter_from_script(parameter_script, _graph_position)
