# Working with Signals
One of Godot's best features is that it allows you to create interactions between components without
creating coupling in code. This guide assumes you are familiar with how they work (if not, Godot's
[Using Signals](https://docs.godotengine.org/en/stable/getting_started/step_by_step/signals.html) is
th best place to start). Synapse allows you to connect signals visually through the editor, which
enables you to build rich interconnected state machines while still making it really easy to see how
states, behaviors, etc. interact with each other.

To connect a signal in the Synapse editor, you need two things:
1. ![Dark Icon](../../addons/synapse/icons/signal.svg#gh-dark-mode-only)![Light Icon](../../addons/synapse/icons/signal_dark.svg#gh-light-mode-only) A signal output port, and
1. ![Dark Icon](../../addons/synapse/icons/method.svg#gh-dark-mode-only)![Light Icon](../../addons/synapse/icons/method_dark.svg#gh-light-mode-only) A callable input port.

All you need to do is drag a connection between a callable port and a signal port and that callable
will be called whenever the signal is emitted- this is handled using Godot's native `Signal.connect`
method at runtime similar to how you connect signals in the Godot inspector.

(Note that Synapse doesn't support connecting an entity to itself, so you won't be able to e.g. make
a behavoir's signal call its own method- you can do that in code instead.)

When connecting a signal to a callable, Synapse will try to determine whether the signal's arguments
match those of the callable. If they do, it simply connects the two. If they don't, it will instead
create a signal bridge to allow you to resolve the differences- we'll explore these in more detail
in [Signal Bridges](#signal-bridges), but let's first talk about how the different entities support
signals and callables and how to add your own.

## Signal and Callable Ports
Each Synapse entity type has its own way of exposing callable and signal ports, so let's go through
them one by one.

*Parameters* have a fixed `set_value` callable and `value_set` signal. Since parameters are meant to
be pure data containers, this is all they offer. `set_value` is straightforward- it will just set
the `value` property of the parameter when called. `value_set` is similar, but note that it is
called every time the parameter value is set, even if the value itself did not change.

*Behaviors* are the most natural place to add your own signals and callables. By default, all
"public" (not prefixed by an underscore, "`_`") methods and signals are automatically exposed as
ports by Synapse. However, should you want to customize the list of signals and callables you can
override `_get_visible_methods` and `_get_visible_signals`. One thing to note in particular about
behaviors is that their exposed methods are wrapped in something called a "signal relay" (more on
those below), which prevents these methods from being called while the behavior is suspended. This
is almost always what you want, because a behavior is associated with a state and an inactive state
shouldn't *do* anything.

*States* have `entered` and `exited` signals, which are useful for one-off actions like setting a
parameter to a particular value, but for anything else you should probably just create a behavior.
Each type of state has its own set of callables, usually for manipulating its child states. By
connecting these methods to signals from various entities, you can fully control the flow of the
state machine. For example, if a behavior responsible for health triggers a `damage_taken` signal,
you can toggle a state that will display visual effects like flashing the character's health bar.
Unlike with behaviors, state callables can be called even while the state is inactive. When doing
so, they will still keep track of the intended active/inactive status of their their child states,
but the relevant child states will only be entered when their parent state is entered.

## Signal Relays
Behaviors have a special way of dealing with signals, called signal relays. As mentioned above,
relays primarily act to disconnect signals from behavior methods while the behavior is suspended.
While you can create relays by exposing public methods as defined above, you can also add additional
relays in code by overriding the `_get_signal_relays` method that returns an array of signal relays.
There are two main ways in which you will typically create relays:
* `SignalRelay.of(<signal>, <callable>)` - this method acts similarly to
`<signal>.connect(<callable>)` and is usually how you would connect to signals defined by
non-Synapse objects (like a UI button's `pressed` signal).
* `SignalRelay.for_parameter(<parameter>, <callable>)` - this method is for keeping a behavior in
sync with a parameter's value as it changes. It basically does the same thing as
`SignalRelay.of(<parameter>.value_set, <callable>)`, but `for_parameter` has the advantage of also
calling the connected callable with the parameter's current value when the behavior unsuspends. This
is handy to keep the behavior in sync with a parameter that can change while the behavior is
suspended (remember, the callable won't be called while the behavior is suspended!).

## Signal Bridges
As mentioned earlier, Synapse checks that a signal and callable have compatible arguments when you
connect them in the editor. When they are **not** compatible, it creates a new intermediate entity
called a signal bridge. Signal bridges essentially allow you to connect any signal to any callable,
with the requirement that you must specify any missing arguments. There are two ways in which
arguments can be set up in a signal bridge:
* **Wiring**: any argument emitted by the signal can be selected from the drop-down menu alongside
any callable argument with a compatible type.
* **Linking**: You can connect parameters, or in some cases value references like state names, to
the argument input. You cannot do this while an argument is already *wired* to that parameter- you
first need to select "unbound" from the drop-down.

Note that even if a signal and callable are compatible, you can force Synapse to create a signal
bridge by holding `Ctrl` (`Cmd` on Mac) while connecting them. This is useful for cases where you
want to override the arguments that get sent when the signal is emitted.

Signal bridges are currently limited to 10 callable arguments.

The last thing to consider about signal bridges is that their flexibililty comes at a slight
performance cost, because Synapse needs to create intermediate functions to map the wired and linked
inputs from the signal to the callable at runtime. You will almost never notice this cost, but take
note of it when dealing with performance sensitive parts of your game like a state that switches
every frame in an enemy state machine when you have many enemies in the scene.

## Exposing from Nested State Machines
When you nest a state machine within another state machine, you can also expose any signals and
callables from the child state machine to the parent. The `StateMachineState` in the parent state
machine will have ports for all of the child state machine's exposed signals and callables, just
like parameters that are marked public/visible. To expose a signal or callable, simply drag a
connection between it and the root sentinel's "expose"
![Dark Icon](../../addons/synapse/icons/parameter_visible.svg#gh-dark-mode-only)![Light Icon](../../addons/synapse/icons/parameter_visible_dark.svg#gh-light-mode-only)
port. Doing so will create a new slot on the root sentinel where you can customize the name if you
need to. To stop exposing it again, simply delete the connection (hold `Alt` and click the "X" on
the connection line).

## Conclusion
Synapse makes heavy use of signals because they're a powerful tool for managing interactions between
components of your game while still keeping the code decoupled. They are the primary way to manage
control flow in your state machine machines. By being visible on the state machine graph they make
it easy to keep track of how the different parts of your state machine interact.

In summary, you would commonly use signals in the following ways:
1. Add signals to your custom behaviors to trigger state transitions and call methods on other
behaviors.
1. Add public methods to your custom behaviors to respond to signals emitted by other entities.
1. Add signal relays to make behaviors respond to events like UI actions or parameter value updates.
1. Add signal bridges to connect incompatible signals and callables or override the arguments, for
example supplying a constant parameter.
1. Expose signals and callables from nested state machines to connect them to entities in the parent
state machine.

| [← Previous: Working with States](states.md) | [Manual](README.md) | [Next: Multiplayer State Machines →](multiplayer.md)
| :--- | :---: | ---: |
