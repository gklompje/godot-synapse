# 📂 Demo: Nested State Machines

## 📝 Summary
This demo showcases how you can model `StateMachine`s as states within another state machine using
**StateMachineState**, and how to share **Parameters** between them.

### 🕹️ What It Does
The system simulates a small power grid based on a day/night cycle:
1. **🌍 Outer Machine:** Manages the time of day and rotates the sun/moon icons.
2. **☀️ Solar Panel:** Generates current based on the sun's position (peak at noon).
3. **🔋 Battery:** Charges when current is positive and drains when it is negative.
4. **💡 Light Bulb:** Automatically switches on when the battery has a charge.

The outer machine synchronizes the generated power, battery level, and light status across these
sub-systems.

### 🎓 What It Teaches
Just like scripts and scene trees, state machines become unwieldy as they grow. This demo
illustrates how to **compartmentalize logic** into modular, nested machines. Keeping your UI,
characters, and environment logic in separate nested machines makes your game easier to maintain and
scale.

---

## 💡 Additional Notes

### 🛰️ Linking Across Scenes
When a `StateMachine` exists in your scene tree, it appears as an option when adding a new state in
the editor. 
* Entering the state calls the nested machine's `activate()` method.
* Exiting the state calls `deactivate()`.
* **Note:** You should avoid manually activating/deactivating nested machines via code to prevent
state desync.

### 🔄 Sharing Parameters
Nested state machines expose their internal parameters to the parent.
* **Wiring:** Dragging a nested parameter out creates a "bridge" parameter in the outer machine.
* **Synchronization:** To keep two machines in sync, connect the `value_set` signal of a "source"
parameter to the `.value` setter of a "target" parameter. This creates a live data bridge between
independent machines.

### 📜 Behaviors & Scripts
Explore these scripts to see the math and logic behind the simulation:
* **Environment:** [day_night_cycle.gd](day_night_cycle.gd)
* **Solar:** [update_solar_panel_current_from_hour.gd](update_solar_panel_current_from_hour.gd)
* **Battery:** [charge_or_drain_battery.gd](charge_or_drain_battery.gd)
* **Light:** [check_light_bulb_current.gd](check_light_bulb_current.gd) &
[toggle_light_bulb.gd](toggle_light_bulb.gd)

---


| [⬅️ Back to Demos](../README.md) |
| :---: |
