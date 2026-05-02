extends Node2D

@onready var state_machine: SynapseStateMachine = %StateMachine

func _on_state_machine_created() -> void:
	var combiner := state_machine.all_states[&"Combiner"] as SynapseCombinerState
	combiner.select(&"SolarPanelStateMachine")
	combiner.select(&"BatteryStateMachine")
	combiner.select(&"LightBulbStateMachine")
