@tool
class_name SynapseSignalSourceData
extends Resource

@export_storage var source_entity: SynapseEntityData
@export_storage var signal_id: StringName
@export_storage var signal_data: SynapseSignalData

@warning_ignore("shadowed_variable")
static func of(source_entity: SynapseEntityData, signal_id: StringName, signal_data: SynapseSignalData) -> SynapseSignalSourceData:
	var data := SynapseSignalSourceData.new()
	data.source_entity = source_entity
	data.signal_id = signal_id
	data.signal_data = signal_data
	return data

func _to_string() -> String:
	return "%s.%s" % [source_entity, signal_id]

func is_from(from_entity: SynapseEntityData, from_signal_id: StringName) -> bool:
	return source_entity == from_entity and signal_id == from_signal_id
