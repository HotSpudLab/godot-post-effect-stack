@tool
class_name EffectStackRunner
extends CompositorEffect

@export var stack_resource: EffectStackResource

var rd: RenderingDevice
var nearest_sampler: RID
var _pipeline_cache: Dictionary
var mutex := Mutex.new()

func _init() -> void:
	rd = RenderingServer.get_rendering_device()
	effect_callback_type = CompositorEffect.EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	var sampler_state := RDSamplerState.new()
	sampler_state.min_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	sampler_state.mag_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	nearest_sampler = rd.sampler_create(sampler_state)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(rd):
		mutex.lock()
		for key in _pipeline_cache:
			var entry: Dictionary = _pipeline_cache[key]
			if entry.has("pipeline") and entry["pipeline"].is_valid():
				rd.free_rid(entry["pipeline"])
			if entry.has("shader") and entry["shader"].is_valid():
				rd.free_rid(entry["shader"])
		_pipeline_cache.clear()
		if nearest_sampler.is_valid():
			rd.free_rid(nearest_sampler)
		mutex.unlock()

func _get_pipeline(effect: PostEffectResource) -> RID:
	if not effect or not effect.shader_file:
		return RID()

	var path := effect.shader_file.resource_path
	if _pipeline_cache.has(path):
		var entry: Dictionary = _pipeline_cache[path]
		if entry["pipeline"].is_valid():
			return entry["pipeline"]

	mutex.lock()
	if _pipeline_cache.has(path):
		var old: Dictionary = _pipeline_cache[path]
		if old["pipeline"].is_valid():
			rd.free_rid(old["pipeline"])
		if old["shader"].is_valid():
			rd.free_rid(old["shader"])

	var spirv := effect.shader_file.get_spirv()
	var shader := rd.shader_create_from_spirv(spirv)
	var pipeline := rd.compute_pipeline_create(shader)
	_pipeline_cache[path] = { "shader": shader, "pipeline": pipeline }
	mutex.unlock()
	return pipeline

func _render_callback(p_effect_callback_type: EffectCallbackType, p_render_data: RenderData) -> void:
	if not rd or not stack_resource:
		return
	if p_effect_callback_type != effect_callback_type:
		return

	var effects := stack_resource.get_enabled_effects()
	if effects.is_empty():
		return

	var matching: Array[PostEffectResource] = []
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
			if not effect._is_ready():
				continue

			if effect._is_multi_pass:
				effect._render_multi_pass(rd, self, render_scene_buffers, view, size, color_image)
				continue

			var pipeline := _get_pipeline(effect)
			if not pipeline.is_valid():
				continue

			var uniform := RDUniform.new()
			uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
			uniform.binding = 0
			uniform.add_id(color_image)
			var uniforms: Array = [uniform]

			if effect.needs_depth:
				var depth_image: RID = render_scene_buffers.get_depth_layer(view)
				if depth_image.is_valid():
					var depth_uniform := RDUniform.new()
					depth_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
					depth_uniform.binding = 1
					depth_uniform.add_id(nearest_sampler)
					depth_uniform.add_id(depth_image)
					uniforms.append(depth_uniform)

			var additional := effect._get_additional_uniforms()
			for u in additional:
				uniforms.append(u)

			var shader: RID = _pipeline_cache[effect.shader_file.resource_path]["shader"]
			var uniform_set := UniformSetCacheRD.get_cache(shader, 0, uniforms)

			var push_constant := effect._build_push_constant(size, view)

			var compute_list := rd.compute_list_begin()
			rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
			rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
			rd.compute_list_set_push_constant(compute_list, push_constant.to_byte_array(), push_constant.size() * 4)
			rd.compute_list_dispatch(compute_list, x_groups, y_groups, 1)
			rd.compute_list_end()
