@tool
class_name EffectStackRunner
extends CompositorEffect

@export var stack_resource: EffectStackResource

var rd: RenderingDevice
## Pipeline cache, snapshot machinery and the binding order all live here, and
## are shared with `PostEffectRunner`. See `effect_dispatch.gd`.
var dispatch: PostEffectDispatch

func _init() -> void:
	rd = RenderingServer.get_rendering_device()
	effect_callback_type = CompositorEffect.EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	dispatch = PostEffectDispatch.new(rd)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(rd) and dispatch:
		dispatch.free_resources()

func _render_callback(p_effect_callback_type: EffectCallbackType, p_render_data: RenderData) -> void:
	if not rd or not stack_resource:
		return
	if p_effect_callback_type != effect_callback_type:
		return

	var effects := stack_resource.get_enabled_effects()
	if effects.is_empty():
		return

	var matching: Array[PostEffect] = []
	for e in effects:
		if e.effect_callback_type == p_effect_callback_type:
			matching.append(e)
	if matching.is_empty():
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
		for effect in matching:
			dispatch.render(effect, self, render_scene_buffers, view, size, color_image, x_groups, y_groups)
