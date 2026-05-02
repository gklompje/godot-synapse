@tool
@abstract
@icon("uid://c1mjn5rsw7v6a")

## Unit of functionality managed by a [SynapseStateMachine]'s internal [SynapseState]s.
##
## Behaviors follow the state machine's flow. When a state is entered and exited, it suspends and
## unsuspends all its behaviors accordingly.[br][br]
## Like regular [Node]s, behaviors are meant to encapsulate game functionality and lean into Godot's
## composition-over-inheritance model. By creating custom behaviors for all of your scene logic, you
## can cut down on (or eliminate entirely) custom per-scene scripts and make your code more
## reusable. Behaviors can share data with each other and other game code using
## [SynapseParameter]s.[br][br]
## Behaviors must be annotated with [annotation @GDScript.@tool] and declare a
## [code]class_name[/code] to be supported by the state machine editor.[br][br]
## For example:
## [codeblock]
## @tool
## class_name MyAwesomeBehavior
## extends SynapseBehavior
## 
## @export var magic_number: SynapseIntParameter
## @export_node_path("CharacterBody2D") var my_character: NodePath
## @export var node_path_parameter: SynapseNodePathParameter
##
## func _unsuspend() -> void:
## 	print("Hello, world!")
##
## func _suspend() -> void:
## 	print("Goodbye, cruel world!")
##
## func _physics_process(delta: float) -> void:
## 	# `NodePath`s defined on the behavior will resolve normally (i.e. calling `get_node` works)
## 	get_node(my_character).move_and_slide()
## 	
## 	# However, `NodePath` values on [SynapseParameter]s in the state machine editor are relative to
## 	# the *state machine* (because they can be shared across behaviors)
## 	var my_node: Node = state_machine.get_node(node_path_parameter.value)
## 	print("I found my node!", my_node)
##
## func _get_signal_relays() -> Array[RuntimeSignalRelay]:
## 	return [
## 		SignalRelay.for_parameter(magic_number, _on_magic_number_value_set),
## 	]
##
## func _on_magic_number_value_set(new_value: int) -> void:
## 	print("The magic number is ", new_value)
## [/codeblock]
extends Node
class_name SynapseBehavior

const SAVE_DATA_CUSTOM_DATA := &"custom_data"

const CATEGORY_NONE := &""
const CATEGORY_DEMOS := &"Demos"
const CATEGORY_MATH := &"Math"
const CATEGORY_UTILITY := &"Utility"

## The state machine to which this behavior belongs. Set by the state machine editor, or during
## state machine initialization. Don't set directly.
var state_machine: SynapseStateMachine:
	set(value):
		if is_instance_valid(state_machine):
			state_machine.tree_exiting.disconnect(_on_state_machine_tree_exiting)
		state_machine = value
		if state_machine:
			state_machine.tree_exiting.connect(_on_state_machine_tree_exiting)
		update_configuration_warnings()

## The state to which this behavior belongs. Set during state machine initialization. Don't set
## directly.
var owner_state: SynapseState

var _suspended := true
var _signal_relays: Array[SignalRelay]
var _cached_data_configuration_warnings := PackedStringArray()

## A signal relay is automatically connected when the behavior is unsuspended, and disconnected
## when it is suspended.
@abstract
class SignalRelay:
	## Creates a signal relay associated with the given signal.
	static func of(sig: Signal, callable: Callable) -> RuntimeSignalRelay:
		return RuntimeSignalRelay.new(sig, callable)

	## Creates a signal relay associated with the given [SynapseParameter]'s
	## <code>value_set</code> signal. [param callable] will also be invoked with the current
	## parameter's value when the behavior is unsuspended.
	static func for_parameter(parameter: SynapseParameter, callable: Callable) -> SignalRelayForParameter:
		return SignalRelayForParameter.new(parameter, callable)

	## Creates a signal relay that can be connected using the state machine editor[br][br]
	## [param name] must be unique among the behavior's member (property/method/signal) names, or it
	## will fail to display in the editor.
	static func connector(name: StringName, callable: Callable) -> SignalRelayConnector:
		return SignalRelayConnector.new(name, callable)

	var _signals: Array[Signal] = []
	var _callable: Callable

	func _init(callable: Callable) -> void:
		_callable = callable

	## Adds a signal to the relay. Also called during state machine initialization to attach signals
	## for signal bridges and direct signal connections created in the editor.
	func add_signal(sig: Signal) -> void:
		_signals.append(sig)

	## Connects the signal. Called by the behavior when it is unsuspended.
	func enable() -> void:
		for sig in _signals:
			sig.connect(_callable)

	## Disconnects the signal. Called by the behavior when it is suspended.
	func disable() -> void:
		for sig in _signals:
			sig.disconnect(_callable)

class RuntimeSignalRelay extends SignalRelay:
	func _init(sig: Signal, callable: Callable) -> void:
		super(callable)
		add_signal(sig)

class SignalRelayForParameter extends RuntimeSignalRelay:
	var _parameter: SynapseParameter

	func _init(parameter: SynapseParameter, callable: Callable) -> void:
		@warning_ignore("unsafe_cast")
		super(parameter.get("value_set") as Signal, callable)
		_parameter = parameter

	func enable() -> void:
		super()
		_callable.call(_parameter.get("value"))

class SignalRelayConnector extends SignalRelay:
	var _name := &""
	var _bridged_signals: Array[SignalRelay] = []

	func _init(name: StringName, callable: Callable) -> void:
		super(callable)
		_name = name

	func get_name() -> StringName:
		return _name

	## Called during state machine initialization to create signal bridges. Not meant to be
	## called directly.
	func get_callable() -> Callable:
		return _callable

	## Called during state machine initialization to create signal bridges. Not meant to be
	## called directly.
	func connect_bridged_signal(sig: Signal, callable: Callable) -> void:
		_bridged_signals.append(RuntimeSignalRelay.new(sig, callable))

	func enable() -> void:
		super()
		for m in _bridged_signals:
			m.enable()

	func disable() -> void:
		super()
		for m in _bridged_signals:
			m.disable()

func _init() -> void:
	process_mode = PROCESS_MODE_DISABLED

## Called by [SynapseBehaviorData] during state machine validation to inject configuration warnings.
func set_data_configuration_warnings(warnings: PackedStringArray) -> void:
	_cached_data_configuration_warnings = warnings
	update_configuration_warnings()

func _get_configuration_warnings() -> PackedStringArray:
	return _cached_data_configuration_warnings

func _on_state_machine_tree_exiting() -> void:
	state_machine = null

## Returns a category used to group behaviors in the editor.[br][br]
## Implement your own [code]static func get_category() -> StringName[/code] to provide a custom
## category.[br][br]
## Returns [constant SynapseBehavior.CATEGORY_NONE] by default.
static func get_category() -> StringName:
	return CATEGORY_NONE

## Return the type name used in the editor menus, graph nodes, etc.[br][br]
## [param script] is the behavior's script, for introspection.[br][br]
## By default, this method returns the script's [code]class_name[/code] and strips the prefix
## [code]"Synapse"[/code] and suffix [code]"Behavior"[/code].
static func get_type_name(script: Script) -> String:
	@warning_ignore("unsafe_cast")
	var type_name := SynapseClassUtil.get_script_class_name(script)
	var start_index := 0
	var length := -1
	if type_name.begins_with("Synapse"):
		start_index = len("Synapse")
	if type_name.ends_with("Behavior"):
		length = len(type_name) - len("Behavior") - start_index
	return type_name.substr(start_index, length)

## By default, all exported variables are considered required and will be flagged by the state
## machine validation if not set. Override this method to declare which parameters are optional to
## allow initialization to continue without them. Behaviors are expected to gracefully handle
## optional parameters without assigned values.[br][br]
## The returned array should contain the parameter variable names as declared by this behavior's
## script, not their [member SynapseParameter.name] values.
func _get_optional_properties() -> PackedStringArray:
	return []

## Override this method to return the [SignalRelay]s that this behavior should connect to while it
## is not suspended.[br][br]
## This method should not be called directly - see [method get_signal_relays].
func _get_signal_relays() -> Array[RuntimeSignalRelay]:
	return []

## Returns the [SignalRelayConnector]s that can be connected in the editor.[br][br]
## This method should not be overridden. To customize the methods that can be connected, override
## [method _get_visible_methods].
func get_signal_relay_connectors() -> Array[SignalRelayConnector]:
	var connectors: Array[SignalRelayConnector] = []
	for callable in _get_visible_methods():
		connectors.append(SignalRelay.connector(callable.get_method(), callable))
	return connectors

## Override this method to declare which parameters are only read, not assigned, by this behavior.
## By default, any declared [SynapseParameter] is considered writable. This affects how they
## display and are connected in the state machine editor. Writable parameters trigger additional
## validations.[br][br]
## The returned array should contain the parameter variable names as declared by this behavior, not
## their [member SynapseParameter.name] values.
func _get_read_only_parameters() -> PackedStringArray:
	return []

## Defines the methods that can be connected in the editor.[br][br]
## Override this method to return a list of methods that are visible in the editor. Returned
## callables must be members of this behavior.[br][br]
## By default, returns all the public methods declared by this script and all the *scripts* it
## inherits from (excluding custom getters and setters, and methods defined on [SynapseBehavior]).
## A method is considered "public" if its name does not start with an underscore ([code]_[/code]).
func _get_visible_methods() -> Array[Callable]:
	var excluded_prefixes := [
		"@", # getters and setters
		"_", # private methods
	]
	var excluded_method_names := {}
	var behavior_script := load("uid://0hhnx8a155mt") as Script
	for m in behavior_script.get_script_method_list():
		excluded_method_names[m["name"]] = true

	var callables: Array[Callable] = []
	var already_defined := {}
	@warning_ignore("unsafe_cast")
	for method_def in (get_script() as Script).get_script_method_list():
		if method_def["flags"] != MethodFlags.METHOD_FLAGS_DEFAULT:
			# static, variadic, abstract, etc.
			continue
		@warning_ignore("unsafe_cast")
		var method_name := method_def["name"] as StringName
		if not already_defined.has(method_name)\
				and not excluded_method_names.has(method_name)\
				and not excluded_prefixes.any(func(p: String) -> bool: return method_name.begins_with(p)):
			callables.append(get(method_name))
			already_defined[method_name] = true
	return callables

## Defines the signals that can be connected in the editor.[br][br]
## Override this method to return a list of signals that are visible in the editor. Returned signals
## must be members of this behavior.[br][br]
## By default, returns all the signals declared by this script and all the *scripts* it inherits
## from.
func _get_visible_signals() -> Array[Signal]:
	var signals: Array[Signal] = []
	@warning_ignore("unsafe_cast")
	for signal_def in (get_script() as Script).get_script_signal_list():
		@warning_ignore("unsafe_cast")
		signals.append(get(signal_def["name"] as StringName))
	return signals

## Return the variable names that are required for this behavior to function. This will be the
## difference between all exported script variables (see [method Object.get_property_list]) and
## what's returned by [method _get_read_only_parameters].
func get_required_properties() -> PackedStringArray:
	var optional_params := _get_optional_properties()
	var required_params: PackedStringArray = []
	var script_usage := PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_SCRIPT_VARIABLE
	for prop in get_property_list():
		if prop["usage"] & script_usage != script_usage:
			continue
		if prop["name"] in optional_params:
			continue
		@warning_ignore("unsafe_cast")
		required_params.append(prop["name"] as StringName)
	return required_params

## Return the [SynapseParameter] variable names that this behavior can change. See
## [method _get_read_only_parameters].
func get_writable_parameters() -> PackedStringArray:
	var ro_params := _get_read_only_parameters()
	if not ro_params:
		return get_parameters()
	var rw_params: PackedStringArray = []
	for param in get_parameters():
		if not param in ro_params:
			rw_params.append(param)
	return rw_params

## Return the variable names of all the parameters accessed by this behavior. Mostly used by state
## machine internals.
func get_parameters() -> Array[StringName]:
	var params: Array[StringName] = []
	var inheritance_map := SynapseClassUtil.build_inheritance_map()
	for property_dict in get_property_list():
		@warning_ignore("unsafe_cast")
		if property_dict["class_name"] and SynapseClassUtil.is_assignable_from(property_dict["class_name"] as StringName, &"SynapseParameter", inheritance_map):
			@warning_ignore("unsafe_cast")
			params.append(property_dict["name"] as StringName)
	return params

## Return all signal relays defined for this behavior.[br][br]
## This method combines [method _get_signal_relays] and [method _get_signal_relay_connectors]
## and caches the resulting array so it returns the same objects on repeated calls.
func get_signal_relays() -> Array[SignalRelay]:
	if not _signal_relays:
		_signal_relays = []
		_signal_relays.append_array(get_signal_relay_connectors())
		if not Engine.is_editor_hint(): # runtime signal relays don't resolve in the editor
			_signal_relays.append_array(_get_signal_relays())
	return _signal_relays

## Called by the state machine to suspend the behavior. Not intended to be called directly.
func suspend() -> void:
	if _suspended:
		return
	for signal_relay in get_signal_relays():
		signal_relay.disable()
	_suspended = true
	process_mode = PROCESS_MODE_DISABLED
	_suspend()

## Called after the behavior is suspended. Subclasses should override this to add custom suspension
## logic.
func _suspend() -> void:
	pass

## Called by the state machine to unsuspend the behavior. Not intended to be called directly.
func unsuspend() -> void:
	if not _suspended:
		return
	_suspended = false
	process_mode = PROCESS_MODE_INHERIT
	_unsuspend()
	for signal_relay in get_signal_relays():
		signal_relay.enable()

## Called after the behavior is unsuspended. Subclasses should override this to add custom
## unsuspension logic.
func _unsuspend() -> void:
	pass

## Return [code]true[/code] if the behavior is currently suspended.
func is_suspended() -> bool:
	return _suspended

## Called after the state machine is fully initialized. Because behaviors can be located anywhere in
## the scene tree, the state machine defers its initialization to ensure that all behavior nodes
## have been created. In particular, any exported properties of the behavior are not guaranteed to
## be set prior to this method being called. Override this method to implement custom initialization
## as you normally would in [method _ready].
func _state_machine_created() -> void:
	pass

## Returns a resource containing this behavior's save data.[br][br]
## To add custom save data, see [method _get_save_data].
func get_save_data() -> Dictionary:
	var custom_data := _get_custom_save_data()
	if custom_data.is_empty():
		return {}
	return { SAVE_DATA_CUSTOM_DATA: custom_data }

## Override this method to add custom save data.[br][br]
## The returned resource will be included in [method get_save_data], and passed to
## [method _load_custom_save_data] when loading.[br][br]
## You do not need to save [SynapseParameter] [code]value[/code]s here- that will be done by the
## state machine. See [method SynapseStateMachine.get_save_data] for more details on saving.
func _get_custom_save_data() -> Dictionary:
	return {}

## Loads the given save data created by [method get_save_data].[br][br]
## Called automatically when the state machine loads from its save data. See
## [method SynapseStateMachine.load_save_data] for more details on loading like the order in which
## data is loaded.
func load_save_data(save_data: Dictionary) -> void:
	if save_data.has(SAVE_DATA_CUSTOM_DATA):
		@warning_ignore("unsafe_cast")
		_load_custom_save_data(save_data[SAVE_DATA_CUSTOM_DATA] as Dictionary)

## Called by [method load_save_data] to load custom save data created by
## [method _get_custom_save_data].[br][br]
## See [method SynapseStateMachine.load_save_data] for more details on loading.
@warning_ignore("unused_parameter")
func _load_custom_save_data(custom_save_data: Dictionary) -> void:
	pass
