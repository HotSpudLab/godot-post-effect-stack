@tool
class_name ChromaticAberrationEffect
extends PostEffect

## Chromatic aberration.
##
## This effect samples pixels other than the one it writes, so it cannot run
## in place on the colour buffer: neighbouring workgroups may already have
## overwritten the pixels it wants to read, which makes the output depend on
## execution order. It therefore runs as two passes -- snapshot, then read the
## snapshot -- through `_render_multi_pass()`.

@export var strength: float = 0.005
@export var radial: bool = true

var _shader: RID
var _pipeline: RID
var _source: RID
var _source_size: Vector2i

func _init() -> void:
	_is_multi_pass = true

func _build_push_constant(screen_size: Vector2i, view: int) -> PackedFloat32Array:
	return _push_constant(screen_size, view, 1.0)

func _push_constant(screen_size: Vector2i, view: int, mode: float) -> PackedFloat32Array:
	return PackedFloat32Array([
		float(screen_size.x),
		float(screen_size.y),
		float(view),
		strength,
		float(radial),
		mode,
		0.0,
		0.0,
	])

func _ensure(p_rd: RenderingDevice, p_size: Vector2i, p_color_image: RID) -> bool:
	if not _pipeline.is_valid():
		if not shader_file:
			return false
		_shader = p_rd.shader_create_from_spirv(shader_file.get_spirv())
		if not _shader.is_valid():
			return false
		_pipeline = p_rd.compute_pipeline_create(_shader)
		if not _pipeline.is_valid():
			return false

	if _source_size == p_size and _source.is_valid():
		return true

	if _source.is_valid():
		p_rd.free_rid(_source)

	# Match the colour buffer's own format rather than hardcoding one. Measured
	# on 2026-08-11 (capture/m4/m4_ca_snapshot.gd): an 8-bit snapshot happens to
	# round-trip values above 1.0 here too, so this is not currently load-bearing
	# -- it is here so the snapshot cannot silently disagree with its source if
	# the buffer format ever changes.
	var fmt := RDTextureFormat.new()
	fmt.width = p_size.x
	fmt.height = p_size.y
	fmt.format = p_rd.texture_get_format(p_color_image).format
	fmt.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
	_source = p_rd.texture_create(fmt, RDTextureView.new())
	_source_size = p_size
	return _source.is_valid()

func _render_multi_pass(p_rd: RenderingDevice, p_runner: Object, p_render_scene_buffers: RenderSceneBuffers, p_view: int, p_size: Vector2i, p_color_image: RID) -> void:
	if not _ensure(p_rd, p_size, p_color_image):
		return

	@warning_ignore("integer_division")
	var x_groups: int = (p_size.x - 1) / 8 + 1
	@warning_ignore("integer_division")
	var y_groups: int = (p_size.y - 1) / 8 + 1

	var color_uniform := RDUniform.new()
	color_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	color_uniform.binding = 0
	color_uniform.add_id(p_color_image)
	var source_uniform := RDUniform.new()
	source_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	source_uniform.binding = 1
	source_uniform.add_id(_source)
	var uniform_set := UniformSetCacheRD.get_cache(_shader, 0, [color_uniform, source_uniform])

	# Pass 1 writes the snapshot, pass 2 reads it. `compute_list_end()` between
	# them is what guarantees pass 2 sees a finished snapshot.
	for mode in [0.0, 1.0]:
		var push_constant := _push_constant(p_size, p_view, mode)
		var compute_list := p_rd.compute_list_begin()
		p_rd.compute_list_bind_compute_pipeline(compute_list, _pipeline)
		p_rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
		p_rd.compute_list_set_push_constant(compute_list, push_constant.to_byte_array(), push_constant.size() * 4)
		p_rd.compute_list_dispatch(compute_list, x_groups, y_groups, 1)
		p_rd.compute_list_end()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		var r := RenderingServer.get_rendering_device()
		if r:
			if _pipeline.is_valid():
				r.free_rid(_pipeline)
			if _shader.is_valid():
				r.free_rid(_shader)
			if _source.is_valid():
				r.free_rid(_source)
