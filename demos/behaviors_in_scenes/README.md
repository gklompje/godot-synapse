# 🧩 Demo: Behaviors in Scenes

## 📝 Summary
This demo showcases the different ways in which `Behavior` nodes can be associated with a
`StateMachine` within a scene tree.

### 🕹️ What It Does
Each icon is assigned to a specific state containing a behavior that handles rotation. 
* Clicking the **Option Button** below an icon triggers a state transition in the root Combiner
state.
* This "unsuspends" the associated rotator behavior, causing the icon to spin.
* The selection logic itself is handled by behaviors owned by the root state, ensuring they are
always active to listen for button signals.

### 🎓 What It Teaches
This demo illustrates that behaviors can be placed **anywhere** in your scene tree—including deep
within nested child scenes—and still be managed by a top-level state machine.

---

## 💡 Additional Notes

### 🛠️ Behavior Setup
Open the State Machine editor to see how the three different association types are configured:
1. **📦 Managed** - Behavior nodes automatically created and deleted by the editor as children of
the State Machine.
2. **🏠 Local** - Manual behavior nodes placed directly in the current scene.
3. **🛰️ Remote** - Behavior nodes contained inside a separate child scene.

### 🔄 How the Icon Rotates
The rotating icons are part of a custom UI widget
([rotating_icon_widget.gd](rotating_icon_widget.gd)). The widget doesn't rotate itself; it simply:
* Fires a `rotation_requested` signal when toggled.
* Exposes a `set_icon_rotation` method for behaviors to call.

### 🧠 Behavior Logic
* **Rotator Behaviors:** All use [widget_rotator_behavior.gd](widget_rotator_behavior.gd). While
unsuspended, they continuously update the widget's rotation.
* **Selector Behaviors:** 
	1. Listen for the widget's signal.
	2. Use a **Signal Bridge** to pass the specific state name to the root Combiner's `select()`
or `deselect()` functions.
	3. This effectively toggles the "Rotator" states on and off.

### 🚀 Practical Tips
While you *can* mix and match these styles, consistency is key:
* **Stick to Managed Behaviors** for most tasks to keep your scene tree clean.
* **Use Remote Behaviors** when the behavior needs to interact with nodes encapsulated inside a
child scene. Keeping the behavior inside that child scene ensures it always has access to the nodes
it needs to control.

---


| [⬅️ Back to Demos](../README.md) |
| :---: |
