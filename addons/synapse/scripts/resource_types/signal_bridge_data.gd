@tool
class_name SynapseSignalBridgeData
extends SynapseEntityData

const CALLABLE_NAME := &"__bridge_callable"

@export_storage var callable_target_data: SynapseCallableTargetData
@export_storage var wired_parameters: Dictionary[StringName, StringName] = {} # callable argument name : signal argument name
@export_storage var property_references: Dictionary[StringName, SynapseEntityPropertyReferenceData] = {} # callable argument name : reference

@warning_ignore("shadowed_variable", "shadowed_variable_base_class")
static func create(name: StringName, signal_source_data: SynapseSignalSourceData, callable_target_data: SynapseCallableTargetData) -> SynapseSignalBridgeData:
	var bridge := SynapseSignalBridgeData.new()
	bridge.name = name
	bridge.connected_signals = { CALLABLE_NAME: [signal_source_data] }
	bridge.callable_target_data = callable_target_data
	return bridge

func create_bridge(state_machine: SynapseStateMachine) -> void:
	@warning_ignore("unsafe_cast")
	var sig: Signal = (connected_signals[SynapseSignalBridgeData.CALLABLE_NAME][0] as SynapseSignalSourceData).signal_data.load_signal(state_machine)
	var callable := callable_target_data.callable_data.load_callable(state_machine)

	var signal_def: Dictionary
	for s in sig.get_object().get_signal_list():
		if s["name"] == sig.get_name():
			signal_def = s
			break
	var signal_arg_indexes: Dictionary[String, int] = {}
	var signal_args: Array = signal_def["args"]
	for i in signal_args.size():
		signal_arg_indexes[signal_args[i]["name"]] = i
	var method_def: Dictionary
	for m in callable.get_object().get_method_list():
		if m["name"] == callable.get_method():
			method_def = m
			break
	@warning_ignore("unsafe_cast")
	var method_args := method_def["args"] as Array
	@warning_ignore("unsafe_cast")
	var default_args := method_def["default_args"] as Array
	var available_defaults: Array[Variant] = []
	var required_arg_count := callable.get_argument_count() - default_args.size()
	var arg_getters: Array[Callable] = []
	for i in property_references.size() + wired_parameters.size():
		@warning_ignore("unsafe_cast")
		var arg_name := method_args[i]["name"] as String
		if property_references.has(arg_name):
			var ref := property_references[arg_name]
			var prop: Variant = state_machine.get_runtime_object_from(ref.entity_reference).get(ref.property_name)
			arg_getters.append(func(_args: Array) -> Variant: return prop)
		elif wired_parameters.has(arg_name):
			var arg_index := signal_arg_indexes[wired_parameters[arg_name]]
			arg_getters.append(func(args: Array) -> Variant: return args[arg_index])
		elif i >= required_arg_count and available_defaults.size() > i - required_arg_count:
			# e.g.
			# my_func(a, b, c=99)
			# required_arg_count = 2
			# available_defaults = [99]
			var default_value: Variant = available_defaults[i - required_arg_count]
			arg_getters.append(func(_args: Array) -> Variant: return default_value)
		else:
			push_warning("Cannot connect signal bridge - missing argument ", i)
			return Callable()

	var wrapper: Callable
	match arg_getters.size():
		0:
			wrapper = func(..._args: Array) -> void:
				callable.call()
		1:
			wrapper = func(...args: Array) -> void:
				callable.call(
					arg_getters[0].call(args),
				)
		2:
			wrapper = func(...args: Array) -> void:
				callable.call(
					arg_getters[0].call(args),
					arg_getters[1].call(args),
				)
		3:
			wrapper = func(...args: Array) -> void:
				callable.call(
					arg_getters[0].call(args),
					arg_getters[1].call(args),
					arg_getters[2].call(args),
				)
		4:
			wrapper = func(...args: Array) -> void:
				callable.call(
					arg_getters[0].call(args),
					arg_getters[1].call(args),
					arg_getters[2].call(args),
					arg_getters[3].call(args),
				)
		5:
			wrapper = func(...args: Array) -> void:
				callable.call(
					arg_getters[0].call(args),
					arg_getters[1].call(args),
					arg_getters[2].call(args),
					arg_getters[3].call(args),
					arg_getters[4].call(args),
				)
		6:
			wrapper = func(...args: Array) -> void:
				callable.call(
					arg_getters[0].call(args),
					arg_getters[1].call(args),
					arg_getters[2].call(args),
					arg_getters[3].call(args),
					arg_getters[4].call(args),
					arg_getters[5].call(args),
				)
		7:
			wrapper = func(...args: Array) -> void:
				callable.call(
					arg_getters[0].call(args),
					arg_getters[1].call(args),
					arg_getters[2].call(args),
					arg_getters[3].call(args),
					arg_getters[4].call(args),
					arg_getters[5].call(args),
					arg_getters[6].call(args),
				)
		8:
			wrapper = func(...args: Array) -> void:
				callable.call(
					arg_getters[0].call(args),
					arg_getters[1].call(args),
					arg_getters[2].call(args),
					arg_getters[3].call(args),
					arg_getters[4].call(args),
					arg_getters[5].call(args),
					arg_getters[6].call(args),
					arg_getters[7].call(args),
				)
		9:
			wrapper = func(...args: Array) -> void:
				callable.call(
					arg_getters[0].call(args),
					arg_getters[1].call(args),
					arg_getters[2].call(args),
					arg_getters[3].call(args),
					arg_getters[4].call(args),
					arg_getters[5].call(args),
					arg_getters[6].call(args),
					arg_getters[7].call(args),
					arg_getters[8].call(args),
				)
		10:
			wrapper = func(...args: Array) -> void:
				callable.call(
					arg_getters[0].call(args),
					arg_getters[1].call(args),
					arg_getters[2].call(args),
					arg_getters[3].call(args),
					arg_getters[4].call(args),
					arg_getters[5].call(args),
					arg_getters[6].call(args),
					arg_getters[7].call(args),
					arg_getters[8].call(args),
					arg_getters[9].call(args),
				)
		_:
			push_error("Too many arguments for signal bridge - not connecting")
			wrapper = func(..._args: Array) -> void:
				pass

	callable_target_data.callable_data.connect_signal(sig, wrapper, state_machine)

func get_configuration_warnings(state_machine: SynapseStateMachine) -> Array[Dictionary]:
	var warnings: Array[Dictionary] = []
	var callable_info := {}

	var target_entity := state_machine.data.get_entity_from(callable_target_data.target_entity_reference)
	for info in target_entity.get_callable_infos_for_signals(state_machine):
		if info["name"] == callable_target_data.callable_id:
			callable_info = info
			break
	if callable_info:
		@warning_ignore("unsafe_cast")
		var required_arg_count := (callable_info["args"] as Array).size() - (callable_info["default_args"] as Array).size()
		for i in required_arg_count:
			@warning_ignore("unsafe_cast")
			var argument_name := callable_info["args"][i]["name"] as String
			if property_references.has(argument_name) or wired_parameters.has(argument_name):
				continue
			warnings.append({ ConfigurationWarningKey.TEXT: "Missing required argument '%s'" % [argument_name] })
	else:
		push_warning("Unable to locate callable info for '", callable_target_data.callable_id ,"' on: ", callable_target_data.target_entity_reference)

	return warnings
