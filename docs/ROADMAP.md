# 🗺️ Synapse Roadmap

This roadmap outlines the planned evolution of Synapse from its current **Alpha** state toward a
stable **1.0** release. As an alpha project, these priorities may shift based on community feedback.

## 🛠 Phase 1: Observability & Debugging
*Goal: Give users the tools to see exactly what their state machines are doing at runtime.*

- **Runtime Debugger UI**
  - A drop-in UI control for user scenes (built using a Synapse state machine!), AND/OR a Debugger
dock UI.
  - Ability to select and inspect any active state machine in the scene tree.
  - Visual representation of states, active status, and nested behaviors.
  - Live parameter value inspector.
- **Behavior Debug Drawing**
  - Visual debugging for `SynapseBehavior` using a composition-based approach, drawing 2D/3D shapes
to the scene canvas.
- **Editor UX Polish**
  - Search bar to quickly scroll/select nodes in the graph.
  - Node warning indicators (including slot-level warnings).
  - Validation to ensure parameter values are not empty (with user toggle).

## 🧩 Phase 2: Data Integrity & Stability
*Goal: Solve core architectural "landmines" regarding node references and data safety.*

- **Robust Reference Tracking**
  - Investigate Scene Unique Names or internal UUIDs to prevent broken references when moving
behaviors in the scene tree.
  - Improve handling of nested state machine parameters when source nodes are renamed or hidden.
  - Switch to internal IDs (or direct scene object references where appropriate) for entity
references instead of user created names.
- **Safe Refactoring Tools**
  - **Convert to/from Sub-Machine:** One-click (and undo-able) tool to "nest" a complex state into
its own sub-machine or merge it back.
- **Smart Data Handling**
  - Fix duplication issues where re-assigning saved data resources creates a "mess" in the
inspector.

## ⚡ Phase 3: Workflow & DX (Developer Experience)
*Goal: Streamline the "Quality of Life" when building complex systems.*

- **Blackboard Generation**
  - Automatically generate a typed Blackboard script from declared parameters.
  - Store configuration in `@export_storage`.
  - Expose a `.blackboard` property on the `StateMachine` for easy access.
- **Visual Organization**
  - Show/Hide toggles for states/behaviors/parameters to reduce graph clutter.
  - Drag connections between ports to create parameters on the fly.
- **Expanded Signal Support**
  - Allow signal bridges to handle return values, exposing them as output ports for parameter
wiring.
- **Editor Public API**
  - Separate editor methods into public API vs private utility.
  - Document public API methods.

## 🚀 Phase 4: Advanced Architecture (The Road to 1.0)
*Goal: Unlock high-performance and dynamic use cases.*

- **Dynamic State Management**
  - Enable runtime addition and removal of states and behaviors.
  - Optimized support for "Manager" state machines handling large groups of entities.
- **Refined State Logic**
  - **Combiner:** Configure multiple initially active states.
  - **Sequence:** Optional auto-looping for sequence transitions.

---

*Found a bug or have a suggestion? Please open an **Enhancement** issue
[on GitHub](https://github.com/gklompje/godot-synapse/issues)!*
