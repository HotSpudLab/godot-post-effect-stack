@tool
class_name PostEffectRunner
extends CompositorEffect

@export var effect_resource: PostEffectResource:
	set(value):
		effect_resource = value
		if effect_resource:
			effect_callback_type = effect_resource.effect_callback_type

var rd: RenderingDevice
var shader: RID
var pipeline: RID
var nearest_sampler: RID
var mutex := Mutex.new()
var _loaded_path: String = ""

func _init() -> void:
	rd = RenderingServer.get_rendering_device()
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	var sampler_state := RDSamplerState.new()
	sampler_state.min_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	sampler_state.mag_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	nearest_sampler = rd.sampler_create(sampler_state)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and rd:
		mutex.lock()
		if pipeline.is_valid():
			rd.free_rid(pipeline)
		if shader.is_valid():
			rd.free_rid(shader)
		if nearest_sampler.is_valid():
			rd.free_rid(nearest_sampler)
		mutex.unlock()

func _check_shader() -> bool:
	if not effect_resource or not effect_resource.shader_file:
		return false

	var path := effect_resource.shader_file.resource_path
	if path == _loaded_path and pipeline.is_valid():
		return true

	mutex.lock()
	if pipeline.is_valid():
		rd.free_rid(pipeline)
		pipeline = RID()
	if shader.is_valid():
		rd.free_rid(shader)
		shader = RID()

	var spirv := effect_resource.shader_file.get_spirv()
	shader = rd.shader_create_from_spirv(spirv)
	pipeline = rd.compute_pipeline_create(shader)
	_loaded_path = path
	var ok := shader.is_valid() and pipeline.is_valid()
	mutex.unlock()
	return ok

func _render_callback(p_effect_callback_type: EffectCallbackType, p_render_data: RenderData) -> void:
	if not rd or not effect_resource or not effect_resource.enabled:
		return
	if p_effect_callback_type != effect_resource.effect_callback_type:
		return
	if not _check_shader():
		return
	if not effect_resource._is_ready():
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
	var z_groups: int = 1

	var view_count: int = render_scene_buffers.get_view_count()
	for view in range(view_count):
		var color_image: RID = render_scene_buffers.get_color_layer(view)

		var uniform := RDUniform.new()
		uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
		uniform.binding = 0
		uniform.add_id(color_image)
		var uniforms: Array = [uniform]

		if effect_resource.needs_depth:
			var depth_image: RID = render_scene_buffers.get_depth_layer(view)
			if depth_image.is_valid():
				var depth_uniform := RDUniform.new()
				depth_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
				depth_uniform.binding = 1
				depth_uniform.add_id(nearest_sampler)
				depth_uniform.add_id(depth_image)
				uniforms.append(depth_uniform)

		var additional := effect_resource._get_additional_uniforms()
		for u in additional:
			uniforms.append(u)
		var uniform_set := UniformSetCacheRD.get_cache(shader, 0, uniforms)

		var push_constant := effect_resource._build_push_constant(size, view)

		var compute_list := rd.compute_list_begin()
		rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
		rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
		rd.compute_list_set_push_constant(compute_list, push_constant.to_byte_array(), push_constant.size() * 4)
		rd.compute_list_dispatch(compute_list, x_groups, y_groups, z_groups)
		rd.compute_list_end()
