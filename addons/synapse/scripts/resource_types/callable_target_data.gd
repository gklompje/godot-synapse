class_name SynapseCallableTargetData
extends Resource

@export_storage var target_entity_reference: SynapseEntityReferenceData
@export_storage var callable_id: StringName
@export_storage var callable_data: SynapseCallableData

@warning_ignore("shadowed_variable")
static func of(target_entity_reference: SynapseEntityReferenceData, callable_id: StringName, callable_data: SynapseCallableData) -> SynapseCallableTargetData:
	var data := SynapseCallableTargetData.new()
	data.target_entity_reference = target_entity_reference
	data.callable_id = callable_id
	data.callable_data = callable_data
	return data
