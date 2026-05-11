@tool
class_name SynapseEntityPropertyReferenceData
extends Resource

@export_storage var entity_reference: SynapseEntityReferenceData
@export_storage var property_name: StringName

@warning_ignore("shadowed_variable")
static func create(entity_reference: SynapseEntityReferenceData, property_name: StringName) -> SynapseEntityPropertyReferenceData:
	var ref := SynapseEntityPropertyReferenceData.new()
	ref.entity_reference = entity_reference
	ref.property_name = property_name
	return ref

func _to_string() -> String:
	return "%s.%s" % [entity_reference, property_name]
