@tool
extends EditorInspectorPlugin
## Stack navigation and shared numeric appearance; keep normal Resource history.
signal resource_requested(resource: Resource)

func _text(japanese: String,english: String) -> String:
	return japanese if TranslationServer.get_tool_locale().begins_with("ja") else english

func _runners_for(object: Object) -> Array[EffectStackRunner]:
	var result: Array[EffectStackRunner] = []
	var compositor: Compositor
	if object is WorldEnvironment or object is Camera3D:
		compositor = object.compositor
	if compositor:
		for runner in compositor.compositor_effects:
			if runner is EffectStackRunner:
				result.append(runner)
	return result

func _can_handle(object: Object) -> bool:
	return object is PostEffect or not _runners_for(object).is_empty()

func _parse_begin(object: Object) -> void:
	if object is PostEffect:return
	add_custom_control(_build_shortcuts(object))

func _parse_property(object: Object,type: Variant.Type,name: String,hint: PropertyHint,hint_text: String,usage: int,_wide: bool) -> bool:
	if not object is PostEffect:return false
	if not (usage & PROPERTY_USAGE_EDITOR) or type not in [TYPE_INT,TYPE_FLOAT]:return false
	if hint not in [PROPERTY_HINT_NONE,PROPERTY_HINT_RANGE]:return false
	if hint==PROPERTY_HINT_RANGE:
		for option in hint_text.split(",").slice(3):
			if option not in ["or_greater","or_less","exp"] and not option.begins_with("suffix:"):
				return false
	var editor := preload("res://addons/post_effect_stack/editor/number_property.gd").new()
	editor.configure(type,hint,hint_text)
	var label := ""
	if TranslationServer.get_tool_locale().begins_with("ja"):
		label={"brightness":"明るさ","contrast":"コントラスト","hue":"色相","saturation":"彩度"}.get(name,"")
	add_property_editor(name,editor,false,label)
	return true

func _link(parent: Node, title: String, resource: Resource) -> Button:
	var button := Button.new()
	button.text = title
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.tooltip_text = title
	button.pressed.connect(func(): resource_requested.emit(resource))
	parent.add_child(button)
	return button

func _effect_name(effect: PostEffect) -> String:
	if not effect.resource_name.is_empty():
		return effect.resource_name
	if not effect.resource_path.is_empty():
		return effect.resource_path.get_file().get_basename().capitalize()
	var script := effect.get_script() as Script
	if script and not script.resource_path.is_empty():
		return script.resource_path.get_file().get_basename().capitalize()
	return "Post Effect"

func _build_shortcuts(object: Object) -> VBoxContainer:
	var panel := VBoxContainer.new()
	var heading := Label.new()
	heading.text = "Post Effect Stack"
	panel.add_child(heading)
	var runners := _runners_for(object)
	for index in runners.size():
		var runner := runners[index]
		_link(panel, _text("Runner %d — 実行設定","Runner %d — Settings") % (index + 1), runner)
		var stack := runner.stack_resource
		if stack == null:
			var missing := Label.new()
			missing.text = _text("スタック未設定。実行設定から割り当ててください。","No stack. Assign one in Runner settings.")
			missing.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			panel.add_child(missing)
			continue
		_link(panel, _text("スタックを編集（追加・削除・並び替え）","Edit Stack (Add / Remove / Reorder)"), stack)
		for position in stack.effects.size():
			var effect := stack.effects[position]
			if effect:
				var title := "%d. %s%s" % [position + 1, _effect_name(effect), "" if effect.enabled else _text("（無効）"," (Disabled)")]
				_link(panel, title, effect)
			else:
				var empty := Label.new()
				empty.text = _text("%d. （未設定）","%d. (Empty)") % (position + 1)
				panel.add_child(empty)
	return panel
