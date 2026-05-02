# 🔗 Demo: Node Paths & References

## 📝 Summary
This demo showcases the various ways to reference **Nodes** and **NodePaths** within a Synapse state
machine.

### 🕹️ What It Does
The demo uses a simple behavior to assign unique colors to different icons in the scene. Each icon
is targeted using a different referencing mechanism supported by Godot.

### 🎓 What It Teaches
Check out [node_path_demo_behavior.gd](node_path_demo_behavior.gd) to see these patterns in action:

* **Standard References:** Using `get_node()` or `@onready` within a behavior works exactly as it
does in any other Godot script.
* **Behavior Context:** NodePaths inside a behavior script resolve relative to the **Behavior node**
itself.
* **⚠️ Parameter Context:** This is the most important distinction—NodePaths stored in a
**BehaviorParameter** must be resolved via the **State Machine** (e.g.,
`state_machine.get_node(my_param.value)`). This is because parameters are shared assets owned by the
machine, not a specific behavior.

---

## 💡 Additional Notes

### 🛠️ Runtime Resolution
The State Machine editor stores parameter NodePaths relative to the **State Machine node**. These
are resolved automatically when the machine is instantiated at runtime.

### ⏱️ Initialization Timing
Behaviors cannot always reliably read parameter values during the standard `_ready()` call because
the state machine might still be linking data.
* **Best Practice:** Use the `_state_machine_created()` callback in your behaviors for any
initialization logic that depends on parameter values.

### 🏠 Property Storage
Any Node references or NodePaths defined directly on your `SynapseBehavior` script properties (via
`@export`) are stored and handled by the scene system as usual.

---


| [⬅️ Back to Demos](../README.md) |
| :---: |
