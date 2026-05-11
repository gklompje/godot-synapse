@tool
class_name SynapseEntityReferenceData
extends Resource

@export_storage var entity_type: SynapseStateMachineData.EntityType
@export_storage var entity_name: StringName

@warning_ignore("shadowed_variable")
static func of(entity_type: SynapseStateMachineData.EntityType, entity_name: StringName) -> SynapseEntityReferenceData:
	var reference_data := SynapseEntityReferenceData.new()
	reference_data.entity_type = entity_type
	reference_data.entity_name = entity_name
	return reference_data

static func from(entity: SynapseEntityData) -> SynapseEntityReferenceData:
	return SynapseEntityReferenceData.of(SynapseStateMachineData.get_entity_type(entity), entity.name)

func _to_string() -> String:
	return "[%s]%s" % [SynapseStateMachineData.get_entity_type_name(entity_type), entity_name]

func references(entity: SynapseEntityData) -> bool:
	return entity_type == SynapseStateMachineData.get_entity_type(entity) and entity_name == entity.name
