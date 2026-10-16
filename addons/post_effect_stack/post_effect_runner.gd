@tool
class_name PostEffectRunner
extends CompositorEffect

@export var effect_resource: PostEffect:
	set(value):
		effect_resource = value
		if effect_resource:
			effect_callback_type = effect_resource.effect_callback_type

var rd: RenderingDevice
## Same dispatch path as `EffectStackRunner`. This runner used to carry its own
## copy of it, which is how it ended up missing multi-pass support until
## 893605f; there is one copy now.
var dispatch: PostEffectDispatch

func _init() -> void:
	rd = RenderingServer.get_rendering_device()
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	dispatch = PostEffectDispatch.new(rd)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(rd) and dispatch:
		dispatch.free_resources()

func _render_callback(p_effect_callback_type: EffectCallbackType, p_render_data: RenderData) -> void:
	if not rd or not effect_resource or not effect_resource.enabled:
		return
	if p_effect_callback_type != effect_resource.effect_callback_type:
		return

	var render_scene_buffers: RenderSceneBuffers = p_render_data.get_render_scene_buffers()
	if not render_scene_buffers:
		return

	var size: Vector2i = render_scene_buffers.get_internal_size()
	if size.x == 0 and size.y == 0:
		return

	@warning_ignore("integer_division")
	var x_groups: int = (size.x - 1) / 8 + 1
	@warning_ignore("integer_division")
	var y_groups: int = (size.y - 1) / 8 + 1

	var view_count: int = render_scene_buffers.get_view_count()
	for view in range(view_count):
		var color_image: RID = render_scene_buffers.get_color_layer(view)
		dispatch.render(effect_resource, self, render_scene_buffers, view, size, color_image, x_groups, y_groups)
