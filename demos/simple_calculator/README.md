# 🔢 Demo: Simple Calculator

## 📝 Summary
This demo showcases how to use **composition** with modular `Behavior` nodes to build a functional
calculator.

### 🕹️ What It Does
The [SimpleCalculator.tscn](SimpleCalculator.tscn) scene features a basic UI:
* Two **SpinBoxes** provide the operands (`a` and `b`).
* An **OptionButton** selects the operator (`+`, `-`, `*`, or `/`).
* A **Label** dynamically displays the calculation result.

### 🎓 What It Teaches
The main lesson here is **functional decomposition**. You'll see how to break down distinct logic
(addition, subtraction, etc.) into separate `Behavior` scripts assigned to specific `State` nodes,
all while sharing data through a unified set of `BehaviorParameter` nodes.

Additionally, this demo illustrates how to use **SignalRelays** to trigger recalculations only when
the relevant inputs change.

---

## 💡 Additional Notes

### 🏗️ Architecture
The State Machine uses a **Selector State** as its root to handle the operation switching:
1. **The Math:** Each operation state (Add, Subtract, etc.) reads from shared `FloatParameter`s `a`
and `b` and writes to the `result` parameter.
2. **The Trigger:** SignalRelays ensure that only the currently active operation state performs its
calculation, preventing unnecessary background processing.

### 🛠️ UI Management
The root Selector state owns the UI behaviors, keeping them **always active**:
* **[SyncParameterWithSpinBox](sync_float_parameter_with_spin_box.gd):** Keeps parameters `a` and
`b` in sync with the UI inputs.
* **[SelectOperationOnDropdown](select_operation_on_dropdown.gd):** Toggles the state machine
based on the operator selection. It uses **Signal Bridges** to avoid hard-coding state names.
* **[UpdateLabel](update_label.gd):** Listens for changes to the `result` parameter and updates
the UI label automatically.

---


| [⬅️ Back to Demos](../README.md) |
| :---: |
