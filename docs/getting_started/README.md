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
1. **Installation:** Copy `addons/synapse` into your project's `addons/` directory.
2. **Enable:** Go to `Project -> Project Settings -> Plugins` and enable Synapse.
3. **Core Concepts:** If you haven't already, give the [Core Concepts](../concepts.md) a quick read
so you know what to expect.
4. Copy the `demos` directory into your project- this guide uses some of their components.

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

## Scene Setup
The first thing we need to do is add a state machine node to a scene. For this guide we will just
create a new empty 2D scene to work with.

Next, we add a **SynapseStateMachine** node to the scene so we end up with:
<p align="center">
  <img src="./media/scene_tree_1.png" alt="Starter scene tree" />
</p>

We just renamed our state machine to "FirstSM" because "SynapseStateMachine" is a bit long, but pick
any name you like. Next, if we select the state machine node in the scene tree we see a bottom panel
dock appear (if you want to see the icons, you can enable them in `Editor` → `Editor Settings...`
and then under the `Editor` section look for `Bottom Dock Tab Style`):
<p align="center">
   <img src="./media/bottom_panel_dock.png" alt="Bottom panel dock" />
</p>

The Synapse editor should open up automatically, but if it doesn't just click on the "Synapse"
bottom dock tab. When first enabling the plugin (and whenever Godot is started with it enabled), you
may be greeted with the below dialog in the dock:
<p align="center">
  <img src="./media/caching.png" alt="Script caching dialog" />
</p>

Upon loading up, Synapse searches through the current project's files looking for any scripts that
extend its functionality, such as custom states and behaviors. This should only take a few seconds
to complete and only happens on startup. Any new scripts and changes to existing scripts will be
picked up incrementally when you save a file.

Now that we have our basic scene set up, it's time to start building our state machine. For that,
head over to [Part 1: Building a State Machine](getting_started-1.md).

| [Back to Documentation](../README.md) | [Next: Part 1 →](getting_started-1.md) |
| :--- | ---: |
