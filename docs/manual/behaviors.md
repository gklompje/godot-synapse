# Working with Behaviors
Behaviors are responsible for adding logic to your state machine. They are the primary way by which
state machines interact with the rest of your game. They're also a great way to encapsulate logic
and create reusable, well, behaviors throughout your game. You can use them for anything from
controlling characters and animations to managing UI logic, or anything else you can write a script
for in Godot.

Synapse does include a handful of behaviors, but the intention is really for you to create your own
custom behaviors that implement logic specific to your game. To learn more, head over to the
[Creating Custom Behaviors](../tutorials/custom_behaviors.md) tutorial.

## Adding a Behavior to a State Machine
To add a behavior to a state machine, just drag out a connection from a state's "behaviors" port. If
there are any behaviors in the scene tree that aren't already associated with a state machinem, you
will find them under the "Unused in scene" section in the popup menu.

Because behaviors are highly customizable, the resulting node will look different depending on the
type of behavior you selected. They all have these in common, though:
	* An icon and a type in the title.
	* A script link button in the title bar. Clicking this will open up the behavior's script in the
Godot editor.
	* An editable name (must be unique among all behaviors in the state machine).
	* An `owner state` input port which identifies the state that owns the behavior. A behavior can
can only have one owner. You may reassign the behavior to a different state by dragging this
connection to it, which will remove the connection to the previous owner.

Depending on the behavior's implementation, you will also see a combination of the following:
* Input ports for any exposed methods.
* Output ports for any exposed signals.
* Input/output ports for any exported parameters. By default, a parameter is considered writable and
therefore will have an output port. If a behavior script declares a parameter as read only, the port
will change to an input port. This is purely a visual hint to make it easier to see how information
flows in the state machine (a behavior script can freely change the hint without corrupting the
state machine).

## Behaviors as Nodes
Unlike states that contain no runtime logic, behaviors are just regular nodes, with a few things
worth taking note of:
1. Behaviors that are added to the scene tree automatically by the editor are called "managed"
behaviors, because the Synapse graph editor creates them and will delete them if you delete the
graph node that references them.
1. If you manually add behavior nodes to your scene, they aren't automatically associated with any
state machine. You can link them to your state machine by creating a new behavior in the graph, and
then selecting them from the "Unused in scene" section in the popup menu. Behaviors can be linked
from anywhere, including child scenes, as long as they are only associated with a single state
machine.
1. Right now, Synapse doesn't support actions like deleting or moving behaviors around in the scene
tree once they are associated with a state machine in the editor. If you want to move a behavior
node you created (i.e. not a managed behavior) around, it's best to first delete it from the graph,
then move it, and then re-add it to the graph.
1. Synapse will try to stop you from editing properties that are derived from `SynapseParameter`
directly on behavior nodes. That's because parameters are meant to be modeled in the state machine
and assigned to behaviors using the graph editor.
1. Synapse will mark a required property (or parameter) as invalid if its value is either `null` or
logically empty (like an empty string, `NodePath`, dictionary, array, etc.). Primitives like `int`
or `Vector2` are always considered valid, since Godot assigns them a default (zero) value.

When creating behaviors you can use regular properties or parameters to model your data. Choosing
between the two comes down to answering the question, "Will anything else (states, behaviors, state
machines, etc.) reference this value?" If the answer is yes, then you probably want to use a
parameter.

| [← Previous: Working with Parameters](parameters.md) | [Manual](README.md) | [Next: Working with States →](states.md) |
| :--- | :---: | ---: |
