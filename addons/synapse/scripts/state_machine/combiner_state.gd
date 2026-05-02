@icon("uid://fjqcakgsj7rs")

## Any combination of contained states can be selected
## When a state is selected, it will be entered if the combiner state is active
## When a state is deselected, it will be exited if the combiner state is active
## When exited, all selected states will also be exited
class_name SynapseCombinerState
extends SynapseState

const SAVE_DATA_SELECTED_STATES := &"selected_states"

var contained_states: Dictionary[StringName, SynapseState] = {}
var selected_states: Dictionary[StringName, SynapseState]

@warning_ignore("shadowed_variable", "shadowed_variable_base_class")
func _init(name: StringName, contained_states: Array[SynapseState], behaviors: Array[SynapseBehavior] = []) -> void:
	super(name, behaviors)
	assert(len(contained_states) > 0, "SynapseCombinerState must have at least one contained state")
	for state in contained_states:
		self.contained_states[state.name] = state

func enter() -> void:
	super()
	for state: SynapseState in selected_states.values():
		state.enter()

func exit() -> void:
	for state: SynapseState in selected_states.values():
		state.exit()
	super()

func select(state_name: StringName) -> bool:
	if selected_states.has(state_name):
		return true

	var state: SynapseState = contained_states.get(state_name)
	if not state:
		push_error("[", name, "] No such contained state to select: ", state_name)
		return false

	selected_states[state.name] = state
	if active:
		state.enter()
	return true

func deselect(state_name: StringName) -> bool:
	var state: SynapseState = selected_states.get(state_name)
	if not state:
		push_error("[", name, "] No such contained state to deselect: ", state_name)
		return false

	if active:
		state.exit()
	selected_states.erase(state.name)
	return true

func get_save_data() -> Dictionary:
	return {
		SAVE_DATA_SELECTED_STATES: selected_states.keys(),
	}

func load_save_data(save_data: Dictionary) -> void:
	# don't have to worry about exiting and entering children here- this method is only called while the state machine is deactivated
	selected_states.clear()
	@warning_ignore("unsafe_cast")
	for state_name in (save_data[SAVE_DATA_SELECTED_STATES] as Array[StringName]):
		selected_states[state_name] = contained_states[state_name]
