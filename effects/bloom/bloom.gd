@tool
class_name BloomEffect
extends PostEffect

@export var threshold: float = 1.0
@export var intensity: float = 0.8
@export var blur_radius: float = 1.0
@export var blur_passes: int = 3

var _bright_shader: RID
var _bright_pipeline: RID
var _blur_shader: RID
var _blur_pipeline: RID
var _combine_shader: RID
var _combine_pipeline: RID

var _intermediate_a: RID
var _intermediate_b: RID
var _intermediate_size: Vector2i

func _init() -> void:
	_is_multi_pass = true

func _build_push_constant(screen_size: Vector2i, view: int) -> PackedFloat32Array:
	return PackedFloat32Array([
		float(screen_size.x),
		float(screen_size.y),
		float(view),
		threshold,
		intensity,
		blur_radius,
		float(blur_passes),
		0.0,
	])

func _load_shader(p_rd: RenderingDevice, path: String) -> RID:
	var shader_file := load(path) as RDShaderFile
	if shader_file:
		return p_rd.shader_create_from_spirv(shader_file.get_spirv())
	return RID()

func _ensure_intermediate(p_rd: RenderingDevice, size: Vector2i) -> void:
	if _intermediate_size == size and _intermediate_a.is_valid():
		return
	for t in [_intermediate_a, _intermediate_b]:
		if t.is_valid():
			p_rd.free_rid(t)
	var fmt := RDTextureFormat.new()
	fmt.width = size.x
	fmt.height = size.y
	# RGBA16F, not the R8G8B8A8_UNORM this used to be. The bright pass writes
	# `lum - threshold`, which exceeds 1.0 for any input bright enough to matter,
	# and a UNORM buffer clamps that away: 22.6% of pixels differed, up to
	# 50/255, on an HDR test scene, and 20.4% on the shipped demo (measured with
	# capture/bloom_hdr_probe/). Costs about +14% of bloom's GPU time.
	# B10G11R11_UFLOAT would fix it for free at the same 32-bit width, but
	# storage-image support for it is not mandatory in Vulkan and this addon is
	# only tested against one driver, so it was not adopted.
	#
	# Keep this in step with the `rgba16f` qualifier on the intermediate
	# bindings in bloom_bright/blur/combine.glsl.
	fmt.format = RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
	fmt.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
	_intermediate_a = p_rd.texture_create(fmt, RDTextureView.new())
	_intermediate_b = p_rd.texture_create(fmt, RDTextureView.new())
	_intermediate_size = size

func _render_multi_pass(p_rd: RenderingDevice, p_runner: Object, p_render_scene_buffers: RenderSceneBuffers, p_view: int, p_size: Vector2i, p_color_image: RID) -> void:
	if not _bright_pipeline.is_valid():
		_bright_shader = _load_shader(p_rd, "res://effects/bloom/bloom_bright.glsl")
		_bright_pipeline = p_rd.compute_pipeline_create(_bright_shader)
		_blur_shader = _load_shader(p_rd, "res://effects/bloom/bloom_blur.glsl")
		_blur_pipeline = p_rd.compute_pipeline_create(_blur_shader)
		_combine_shader = _load_shader(p_rd, "res://effects/bloom/bloom_combine.glsl")
		_combine_pipeline = p_rd.compute_pipeline_create(_combine_shader)

	if not _bright_pipeline.is_valid() or not _blur_pipeline.is_valid() or not _combine_pipeline.is_valid():
		return

	_ensure_intermediate(p_rd, p_size)

	@warning_ignore("integer_division")
	var x_groups: int = (p_size.x - 1) / 8 + 1
	@warning_ignore("integer_division")
	var y_groups: int = (p_size.y - 1) / 8 + 1

	# push_constant[2] holds view in Pass 1/3, reused as the blur pass index in Pass 2
	var push_constant := PackedFloat32Array([
		float(p_size.x), float(p_size.y), float(p_view),
		threshold, intensity, blur_radius, float(blur_passes), 0.0
	])

	# Pass 1: Bright — color_image → intermediate_a
	var bright_uniform := RDUniform.new()
	bright_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	bright_uniform.binding = 0
	bright_uniform.add_id(p_color_image)
	var bright_uniform2 := RDUniform.new()
	bright_uniform2.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	bright_uniform2.binding = 1
	bright_uniform2.add_id(_intermediate_a)
	var bright_set := UniformSetCacheRD.get_cache(_bright_shader, 0, [bright_uniform, bright_uniform2])

	var cl: int = p_rd.compute_list_begin()
	p_rd.compute_list_bind_compute_pipeline(cl, _bright_pipeline)
	p_rd.compute_list_bind_uniform_set(cl, bright_set, 0)
	p_rd.compute_list_set_push_constant(cl, push_constant.to_byte_array(), push_constant.size() * 4)
	p_rd.compute_list_dispatch(cl, x_groups, y_groups, 1)
	p_rd.compute_list_end()

	# Pass 2: Blur — ping-pong between intermediate_a and intermediate_b
	for i in range(blur_passes):
		var src := _intermediate_a if i % 2 == 0 else _intermediate_b
		var dst := _intermediate_b if i % 2 == 0 else _intermediate_a

		var blur_uniform := RDUniform.new()
		blur_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
		blur_uniform.binding = 0
		blur_uniform.add_id(src)
		var blur_uniform2 := RDUniform.new()
		blur_uniform2.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
		blur_uniform2.binding = 1
		blur_uniform2.add_id(dst)
		var blur_set := UniformSetCacheRD.get_cache(_blur_shader, 0, [blur_uniform, blur_uniform2])

		push_constant[2] = float(i)

		cl = p_rd.compute_list_begin()
		p_rd.compute_list_bind_compute_pipeline(cl, _blur_pipeline)
		p_rd.compute_list_bind_uniform_set(cl, blur_set, 0)
		p_rd.compute_list_set_push_constant(cl, push_constant.to_byte_array(), push_constant.size() * 4)
		p_rd.compute_list_dispatch(cl, x_groups, y_groups, 1)
		p_rd.compute_list_end()

	# Pass 3: Combine — color_image + final blur → color_image
	var final_blur := _intermediate_a if blur_passes % 2 == 0 else _intermediate_b

	var combine_uniform := RDUniform.new()
	combine_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	combine_uniform.binding = 0
	combine_uniform.add_id(p_color_image)
	var combine_uniform2 := RDUniform.new()
	combine_uniform2.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	combine_uniform2.binding = 1
	combine_uniform2.add_id(final_blur)
	var combine_set := UniformSetCacheRD.get_cache(_combine_shader, 0, [combine_uniform, combine_uniform2])

	push_constant[2] = float(p_view)

	cl = p_rd.compute_list_begin()
	p_rd.compute_list_bind_compute_pipeline(cl, _combine_pipeline)
	p_rd.compute_list_bind_uniform_set(cl, combine_set, 0)
	p_rd.compute_list_set_push_constant(cl, push_constant.to_byte_array(), push_constant.size() * 4)
	p_rd.compute_list_dispatch(cl, x_groups, y_groups, 1)
	p_rd.compute_list_end()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		var r := RenderingServer.get_rendering_device()
		if r:
			for p in [_bright_pipeline, _blur_pipeline, _combine_pipeline]:
				if p.is_valid():
					r.free_rid(p)
			for s in [_bright_shader, _blur_shader, _combine_shader]:
				if s.is_valid():
					r.free_rid(s)
			for t in [_intermediate_a, _intermediate_b]:
				if t.is_valid():
					r.free_rid(t)
