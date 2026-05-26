# Getting Started

First off, welcome to Synapse and thank you for taking the time to try it out. If you find this
addon useful, please consider starring it [on GitHub](https://github.com/gklompje/godot-synapse).
Please report bugs or suggest features on the
[GitHub Issues page](https://github.com/gklompje/godot-synapse/issues).

This guide assumes you are comfortable using the Godot editor for common tasks like creating scenes,
adding nodes, setting properties through the inspector, etc. (Godot's
[Step by step](https://docs.godotengine.org/en/stable/getting_started/step_by_step/index.html) guide
is a great place to start if you aren't!)

## Installation
### Requirements
* Godot 4.6+

### Instructions
1. **Installation:**
	* **Godot Asset Library (Recommended, Godot 4.6):**
		* Click on the AssetLib tab at the top of the editor.
		* Search for "Synapse" and select "Synapse: Graph-Based State Machine".
		* Click Download. Once downloaded, click Install. Ensure that the addons/synapse folder is selected.
	* **Godot Asset Store (Recommended, Godot 4.7+):**
		* Click on the Asset Store tab at the top of the editor.
		* Search for "Synapse" and select "Synapse: Graph-Based State Machine".
		* Click Download. When downloaded, click Install. Ensure that the addons/synapse folder is selected.
	* **Manual Installation (Alternative):**
		* Download or clone this repository.
		* Copy the `addons/synapse` folder into your project's `addons/` directory.
2. **Enable:** Go to `Project -> Project Settings -> Plugins` and enable Synapse.
3. **Core Concepts:** If you haven't already, give the [Core Concepts](../concepts.md) a quick read
so you know what to expect.
4. Download ([link](https://github.com/gklompje/godot-synapse/releases/download/v0.1.1-alpha/demos.zip))
and extract the `demos` directory into your project- this guide uses some of their components.

### Hide Synapse Internal Classes (Recommended)
Synapse makes heavy use of global class names internally. Godot includes all of these global classes
in its "Add New Node" dialog by default, but it is unlikely you'll need to use any of those directly
in your project. To help keep the dialog clean, Synapse includes a feature profile that you can
import that will hide its internal classes. The file is located at
`addons/synapse/editor_feature_profile.profile`.

To import it, go to `Editor` → `Manage Editor Features` and press the `Import` button, select the
above file, then press OK. That's it!

If you are already using a custom feature profile, you will need to edit your profile because Godot
only supports having one active profile. To do this, export your profile from the above menu (or
just find it under `editor_features` in the
[editor config directory](https://docs.godotengine.org/en/stable/classes/class_editorpaths.html#class-editorpaths-method-get-config-dir)),
then open up both files in a text editor and copy the list of `disabled_classes` in the provided
file over to your profile, then re-import it.

With the initial setup out of the way, it's time to start building your first state machine. Head
over to [Part 1: Building a State Machine](getting_started-1.md).

| [Back to Documentation](../README.md) | [Next: Part 1 →](getting_started-1.md) |
| :--- | ---: |
