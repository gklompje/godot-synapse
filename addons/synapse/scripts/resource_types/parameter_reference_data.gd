class_name SynapseParameterReferenceData
extends Resource

@export_storage var property_name: StringName
@export_storage var parameter_name: StringName
@export_storage var access: SynapseParameterData.Access

func _to_string() -> String:
	return "%s → p{%s} [%s]" % [property_name, parameter_name, SynapseParameterData.access_to_string(access)]

@warning_ignore("shadowed_variable")
static func create(property_name: StringName, parameter_name: StringName, access: SynapseParameterData.Access) -> SynapseParameterReferenceData:
	var data := SynapseParameterReferenceData.new()
	data.property_name = property_name
	data.parameter_name = parameter_name
	data.access = access
	return data
