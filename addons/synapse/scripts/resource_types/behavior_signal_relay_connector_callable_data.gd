class_name SynapseBehaviorSignalRelayConnectorCallableData
extends SynapseCallableData

@export var behavior_name: StringName
@export var signal_relay_connector_name: StringName

@warning_ignore("shadowed_variable")
static func of(behavior_name: StringName, signal_relay_connector_name: StringName) -> SynapseBehaviorSignalRelayConnectorCallableData:
	var data := SynapseBehaviorSignalRelayConnectorCallableData.new()
	data.behavior_name = behavior_name
	data.signal_relay_connector_name = signal_relay_connector_name
	return data

func load_callable(state_machine: SynapseStateMachine) -> Callable:
	return _get_relay_connector(state_machine).get_callable()

func connect_signal(sig: Signal, callable: Callable, state_machine: SynapseStateMachine) -> void:
	var connector := _get_relay_connector(state_machine)
	if is_same(connector.get_callable(), callable):
		connector.add_signal(sig)
	else:
		connector.connect_bridged_signal(sig, callable)

func _get_relay_connector(state_machine: SynapseStateMachine) -> SynapseBehavior.SignalRelayConnector:
	var behavior := state_machine.all_behaviors[behavior_name] as SynapseBehavior
	for signal_relay in behavior.get_signal_relays():
		if signal_relay is SynapseBehavior.SignalRelayConnector:
			var signal_relay_name := (signal_relay as SynapseBehavior.SignalRelayConnector).get_name()
			if signal_relay_name == signal_relay_connector_name:
				return signal_relay
	push_warning("Cannot find signal relay connector '", signal_relay_connector_name, "' on behavior '", behavior_name, "' to connect signal to")
	return null
