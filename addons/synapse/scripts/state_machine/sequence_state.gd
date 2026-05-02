@icon("uid://rg32ebo2fcoe")

## A specialized selector that only allows transitions in a fixed sequence
## When advanced past its final state, the sequence will loop back to its first state
class_name SynapseSequenceState
extends SynapseSelectorState

var sequence: Array[SynapseState]
var index: int = 0

@warning_ignore("shadowed_variable", "shadowed_variable_base_class")
func _init(name: StringName, sequence: Array[SynapseState], behaviors: Array[SynapseBehavior] = []) -> void:
	self.sequence = sequence
	var transition_sequence: Dictionary[StringName, Transitions] = {}
	for i in range(len(sequence)):
		transition_sequence[sequence[i].name] = Transitions.new([sequence[_get_next_index(i)].name])
	super(name, sequence, transition_sequence, behaviors)

func _get_next_index(i: int) -> int:
	return (i + 1) % len(sequence)

func advance() -> bool:
	var new_index := _get_next_index(index)
	if select(sequence[new_index].name):
		index = new_index
		return true
	push_error("[", name, "] Failed to advance - index=", index, ", new_index=", new_index, "; valid transitions are: ", allowed_transitions.keys())
	return false

func advance_to(state_name: StringName) -> bool:
	assert(contained_states.has(state_name), "Cannot advance to unknown state: " + state_name)
	while selected_state.name != state_name:
		var advanced := advance()
		if not advanced:
			push_error("[", name, "] Failed to advance to ", state_name, "; current=", selected_state.name, "; active=", active)
			return false
	return true

func reset() -> bool:
	return advance_to(sequence[0].name)

func load_save_data(save_data: Dictionary) -> void:
	super(save_data)
	for i in range(len(sequence)):
		if selected_state.name == sequence[i].name:
			index = i
			return
	push_warning("Unable to find sequence state during load - resetting")
	reset()
