@icon("uid://brducfl5b54hv")
class_name SynapseStateMachineState
extends SynapseState

const SAVE_DATA_STATE_MACHINE_SAVE_DATA := &"state_machine_save_data"

var state_machine: SynapseStateMachine

@warning_ignore("shadowed_variable", "shadowed_variable_base_class")
func _init(name: StringName, state_machine: SynapseStateMachine, behaviors: Array[SynapseBehavior] = []) -> void:
	super(name, behaviors)
	self.state_machine = state_machine

func enter() -> void:
	super()
	state_machine.activate()

func exit() -> void:
	state_machine.deactivate()
	super()

func get_save_data() -> Dictionary:
	var state_machine_save_data := state_machine.get_save_data()
	# we don't want the state machine to wake up during loading- our parent state machine handles activation after loading
	state_machine_save_data[SynapseStateMachine.SAVE_DATA_STATE_MACHINE_ACTIVE] = false
	return {
		SAVE_DATA_STATE_MACHINE_SAVE_DATA: state_machine_save_data,
	}

func load_save_data(save_data: Dictionary) -> void:
	@warning_ignore("unsafe_cast")
	state_machine.load_save_data(save_data[SAVE_DATA_STATE_MACHINE_SAVE_DATA] as Dictionary)
