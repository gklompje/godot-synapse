@tool
class_name SynapseEntityPropertyReferenceData
extends Resource

@export_storage var entity: SynapseEntityData
@export_storage var property_name: StringName

@warning_ignore("shadowed_variable")
static func create(entity: SynapseEntityData, property_name: StringName) -> SynapseEntityPropertyReferenceData:
	var ref := SynapseEntityPropertyReferenceData.new()
	ref.entity = entity
	ref.property_name = property_name
	return ref

func _to_string() -> String:
	return "%s.%s" % [entity, property_name]

func build_getter(state_machine: SynapseStateMachine) -> Callable:
	var object := state_machine.get_runtime_object_for(entity)
	return func(_a: Array) -> Variant: return object.get(property_name)
