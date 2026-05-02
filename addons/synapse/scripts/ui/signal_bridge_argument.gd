@tool
class_name SynapseSignalBridgeArgument
extends HBoxContainer

signal argument_selected(argument_name: StringName)

@onready var icon_texture_rect: TextureRect = %IconTextureRect
@onready var name_label: Label = %NameLabel
@onready var signal_source_argument_option_button: OptionButton = %SignalSourceArgumentOptionButton

var _options: Array[StringName] = []

func set_property_def(property_def: Dictionary, has_default: bool = false, default_value: Variant = null) -> void:
	if has_default:
		name_label.text = "%s (= %s)" % [property_def["name"], default_value]
	else:
		name_label.text = property_def["name"]
	icon_texture_rect.texture = SynapseClassUtil.get_type_icon(property_def)

func hide_argument_options() -> void:
	signal_source_argument_option_button.hide()

func show_argument_options() -> void:
	if _options.size() > 0:
		signal_source_argument_option_button.show()

func select_argument(option_name: StringName) -> void:
	var index := _options.find(option_name)
	if index == -1:
		push_warning("Unknown signal argument name '", option_name, "', defaulting to 0")
		index = 0
	signal_source_argument_option_button.select(index)

func set_argument_options(argument_names: Array[StringName], selected_index: int = -1) -> void:
	_options.clear()
	signal_source_argument_option_button.clear()

	if argument_names.is_empty():
		hide_argument_options()
		return

	_options.append_array(argument_names)
	_options.sort_custom(func(s1: String, s2: String) -> bool: return s1.naturalcasecmp_to(s2) < 0)
	for option in _options:
		signal_source_argument_option_button.add_item(option)
	if selected_index > 0:
		signal_source_argument_option_button.select(selected_index)
	show_argument_options()

func _on_signal_source_argument_option_button_item_selected(index: int) -> void:
	argument_selected.emit(_options[index])
