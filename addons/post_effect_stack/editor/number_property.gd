@tool
extends EditorProperty
## Emit standard Inspector property changes so Undo, revert and saving stay native.
const CONTROL_STYLE := preload("res://addons/post_effect_stack/editor/control_style.gd")
var slider: HSlider
var number: SpinBox
var _integer := false
var _syncing := false
var _dragging := false
var _locked := false

func configure(type: Variant.Type, hint: PropertyHint, hint_text: String) -> void:
	_integer=type==TYPE_INT
	var row := HBoxContainer.new()
	add_child(row)
	number=SpinBox.new()
	# Match the native Inspector, including the user's default float precision.
	number.step=1.0 if _integer else float(EditorInterface.get_editor_settings().get_setting("interface/inspector/default_float_step"))
	number.custom_minimum_size.x=68
	var parts := hint_text.split(",")
	if hint==PROPERTY_HINT_RANGE:
		number.min_value=float(parts[0])
		number.max_value=float(parts[1])
		if parts.size()>2 and parts[2].is_valid_float():number.step=float(parts[2])
		number.allow_greater=parts.has("or_greater")
		number.allow_lesser=parts.has("or_less")
		for part in parts:
			if part.begins_with("suffix:"):number.suffix=part.trim_prefix("suffix:")
		slider=HSlider.new()
		slider.min_value=number.min_value
		slider.max_value=number.max_value
		slider.step=number.step
		slider.exp_edit=parts.has("exp")
		slider.custom_minimum_size.x=64
		slider.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		row.add_child(slider)
		CONTROL_STYLE.prepare_slider(slider)
		add_focusable(slider)
		slider.drag_started.connect(func():_dragging=true)
		slider.drag_ended.connect(func(_changed: bool):_dragging=false;_change(number.value))
		slider.value_changed.connect(_change)
	else:
		# Unbounded exported numbers retain number entry rather than inventing limits.
		number.allow_greater=true
		number.allow_lesser=true
		number.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(number)
	add_focusable(number.get_line_edit())
	number.value_changed.connect(_change)
	set_label_reference(number)

func _change(value: float) -> void:
	if _syncing or _locked:return
	var result: Variant=int(round(value)) if _integer else value
	_syncing=true
	number.set_value_no_signal(float(result))
	if slider:slider.set_value_no_signal(float(result))
	_syncing=false
	emit_changed(get_edited_property(),result,&"",_dragging)

func _update_property() -> void:
	_syncing=true
	var value := float(get_edited_object().get(get_edited_property()))
	number.set_value_no_signal(value)
	if slider:slider.set_value_no_signal(value)
	_syncing=false

func _set_read_only(value: bool) -> void:
	_locked=value
	number.editable=not value
	if slider:slider.editable=not value
