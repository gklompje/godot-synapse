# Core Concepts
## <img src="../addons/synapse/icons/state_machine.svg" width="18" height="18"> State Machine
A state machine like most others. A state machine needs a root state (the entry point), and manages
all the internal stuff around entering and exiting states.

State machines support saving and loading of themselves and all their contained entities (states,
behaviors, parameters, etc.) providing a single point through which to persist and restore game
state.

A state machine can also be nested within another state machine, acting like a state within its
parent state machine.

## <img src="../addons/synapse/icons/root_state.svg" width="18" height="18"> State
States are just entry points for game logic, but don't *do* much by themselves. States can be either
active (when entered), or inactive (when exited). States aren't entered/exited directly, but rather
through the actions of their parent states (or the state machine itself in the case of the root
state).

Unlike many state machine implementations, Synapse doesn't model states as Godot nodes. Nodes are
powerful, but too heavyweight as they include functionality like per-frame processing which
Synapse states don't need (because they don't implement game logic). Also, node visual relationships
are restricted to that of parent/child since nodes are part of a scene *tree*, not an arbitrary
graph, whereas Synapse supports all kinds of relationships between entities, making a graph
representation more suitable.

***Note:*** *States are only created when the state machine initializes at runtime (what you see in
the editor is just a visual representation of their configuration).*

To learn more about the different kinds of states Synapse supports, including which states control
others, see [Working With States](manual/states.md).

## <img src="../addons/synapse/icons/behavior.svg" width="18" height="18"> Behavior
Behaviors are the brains of the state machine. Where [States](#-state) specify control flow,
behaviors implement logic. A behavior is just a node assigned to a particular state (called its
owner). The state machine will suspend and unsuspend it in accordance with its owner state.
Behaviors are meant to be customized, making them ideal extension points for integrating your game
logic with the state machine.

You can place behavior nodes anywhere in the scene tree (including nested within sub-scenes) and
link them to a state machine. However, in most cases you can simply use the Synapse editor to create
them for you from a drop-down menu, in which case they're just created as child nodes of the state
machine- such behavior nodes are called "managed" because the editor will delete them when no longer
referenced in the state machine. Because behavior nodes are independent of the structure of the
state machine, you can easily restructure your state machine and re-assign behaviors to different
states as your game's needs evolve.

To learn more about behaviors, see [Working with Behaviors](manual/behaviors.md).

## <img src="../addons/synapse/icons/parameter.svg" width="18" height="18"> Parameter
A parameter is just a wrapper around a variable of your choosing. Parameters are modeled as
resources in Godot, which means they can be shared anywhere in your game, and they can maintain
persistent state across state machine saving and loading cycles.

The Synapse editor visually represents how behaviors and other entities reference parameters, which
allows you to easily keep track of how the data in your game is used within the state machine. It's
also great for debugging, since you can quickly find which entities are responsible for producing a
problematic value.

Parameter implementations for many Godot standard types are included, but you can eaily create new
parameter types for those that aren't (yet) supported, including your game's custom types.

To learn more about parameters, see [Working with Parameters](manual/parameters.md).

## <img src="../addons/synapse/icons/signal_bridge.svg" width="18" height="18"> Signal Bridge
An adaptor that allows you to connect a signal to a callable while customizing the individual method
arguments. Signal bridges are mainly used to connect a signal to a method with an incompatible
signature, but are also useful for overriding method arguments.

A signal bridge exposes a connectable input for each method argument, and supports two ways of
supplying a value:
1. **Wiring** in a compatible signal argument, by selecting it from the list of options.
2. **Linking** to a value specified elsewhere, such as the name of a state or a
[Parameter](#-parameter) value.

Using signal bridges is more flexible than using `Callable.bind()` since signal bridges support
arbitrary argument assignment order- they only require that you specify all arguments that don't
have defaults in the target method. Note, however, that this flexibility comes at a slight
performance cost as each parameter is internally connected through a sub-method that is invoked each
time the signal fires.

To learn more about how Synapse allows you to connect signals, including signal bridges, see
[Working with Signals](manual/signals.md).

| [Back to Documentation](./README.md) |
| :---: |
