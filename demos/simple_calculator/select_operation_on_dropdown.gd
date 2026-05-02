@tool
class_name SynapseDemoSelectOperationOnDropdownBehavior
extends SynapseBehavior

signal select_add
signal select_subtract
signal select_multiply
signal select_divide

@export_node_path("OptionButton") var option_button: NodePath

var _signals: Array[Signal] = []

static func get_category() -> StringName:
	return SynapseBehavior.CATEGORY_DEMOS

func _unsuspend() -> void:
	_register_option("+", select_add)
	_register_option("-", select_subtract)
	_register_option("×", select_multiply)
	_register_option("/", select_divide)

func _suspend() -> void:
	(get_node(option_button) as OptionButton).clear()
	_signals.clear()

func _register_option(text: String, sig: Signal) -> void:
	(get_node(option_button) as OptionButton).add_item(text)
	_signals.append(sig)

func _get_signal_relays() -> Array[RuntimeSignalRelay]:
	return [
		SignalRelay.of((get_node(option_button) as OptionButton).item_selected, _on_operation_selected),
	]

func _on_operation_selected(index: int) -> void:
	_signals[index].emit()
