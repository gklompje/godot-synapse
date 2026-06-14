# Working With States
States are the building blocks of a state machine. In Synapse, states don't directly exectute any
game logic, but are intended only for modelling the control flow, leaving logic to be handled by
[Behavoirs](behaviors.md). Synapse includes the state types described below, but you can also
[create your own state types](../tutorials/custom_states.md) if you're up for some scripting.

A state can be either "active" or "inactive". The process of activating a state is called
"entering" the state, and deactivating it is called "exiting" it. States that have children will
always exit their child states when they themselves are exited. Any number of states can be active
at the same time, depending on how the graph is set up.

Each state machine must have a single root state. When a state machine is activated, the root state
is entered. From the root, states form a graph through their (one-to-many) parent/child
relationships. The structure of this graph, and the specific types of states it is composed of,
define the control flow of a state machine.

Some states allow their children to be "selected". Selection is independent of entering and exiting.
If the parent is inactive, a selected state is simply marked for activation so it is entered when
the parent is entered. If the parent is active at the time of selection, the child state will
immediately be entered.

## State Types
### <img src="../../addons/synapse/icons/state.svg" width="18" height="18"> State
The most basic state that has no children. Also called a "leaf" state.

### <img src="../../addons/synapse/icons/combiner_state.svg" width="18" height="18"> Combiner
A state that can have any number of children, any combination of which can be active (entered) at a
time. The combiner gets told which states to "select". While the combiner is active, only its
selected states are active.

### <img src="../../addons/synapse/icons/selector_state.svg" width="18" height="18"> Selector
A state that can have any number of children, only one of which can be active at a given time. The
selector gets told which state to "select", and it ensures that only that state is active while the
selector is active.

For a child state to be selectable, there must be a transition defined from the currently selected
child state to the child state being selected. All selector child states except the first state must
be reachable through transitions.

### <img src="../../addons/synapse/icons/sequence_state.svg" width="18" height="18"> Sequence
A special kind of [Selector](#-selector) that automatically creates transitions between its child
states in an ordered sequence. A sequence can "advance", which selects the next child in the chain.
It can also be "reset", which selects the first child (by looping through the sequence to the end
and wrapping around to the first child).

When first entered, a sequence will enter its first child state. Sequences automatically manage
their child state transition connections. These are simply visual representations based on the
internal sequence order. To change the sequence, you can re-order the child states in the sequence's
graph node's "children" container.

### <img src="../../addons/synapse/icons/state_machine.svg" width="18" height="18"> State Machine
A state machine, nested within another state machine, represented as a state. This type of state
is like a leaf state in that it can't have any direct children inside its parent state machine, but
internally it treats its root state as a child state. Entering a state machine state activates its
inner state machine, which enters its root state.

A state machine states also exposes its parameters that are marked as public/visible to the parent
state machine. When these parameters are assigned in the parent state machine, the parent state
machine's parameter *overrides* the child state machine's parameters during state machine
initialization at runtime, i.e. it leaves the child state machine's data resource untouched so any
unassigned parameters in the parent state machine will retain their defaults defined in the child
state machine.

A state machine node can only be assigned to one parent state machine in a given scene, but you can
add many identical state machines (for example, one for each enemy) to the same state machine if
they are contained in different child scene instances.

| [← Previous: Working with Behaviors](behaviors.md) | [Manual](README.md) | [Next: Working with Signals →](signals.md)
| :--- | :---: | ---: |
