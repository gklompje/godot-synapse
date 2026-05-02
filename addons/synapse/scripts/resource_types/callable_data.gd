@abstract
class_name SynapseCallableData
extends Resource

@abstract
func load_callable(state_machine: SynapseStateMachine) -> Callable

@warning_ignore("unused_parameter")
func connect_signal(sig: Signal, callable: Callable, state_machine: SynapseStateMachine) -> void:
	sig.connect(callable)
