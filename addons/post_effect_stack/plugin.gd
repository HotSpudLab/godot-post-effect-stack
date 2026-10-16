@tool
extends EditorPlugin

var _inspector: EditorInspectorPlugin

func _enter_tree() -> void:
	_inspector = preload("res://addons/post_effect_stack/stack_inspector.gd").new()
	_inspector.resource_requested.connect(_edit_resource)
	add_inspector_plugin(_inspector)

func _exit_tree() -> void:
	remove_inspector_plugin(_inspector)
	_inspector = null

func _edit_resource(resource: Resource) -> void:
	get_editor_interface().edit_resource(resource)
