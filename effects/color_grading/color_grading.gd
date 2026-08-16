@tool
class_name ColorGradingEffect
extends PostEffect

@export var lut_r: Texture2D
@export var lut_g: Texture2D
@export var lut_b: Texture2D
@export var intensity: float = 1.0

var _sampler_rid: RID

func _build_push_constant(screen_size: Vector2i, view: int) -> PackedFloat32Array:
	return PackedFloat32Array([
		float(screen_size.x),
		float(screen_size.y),
		float(view),
		intensity,
	])

func _is_ready() -> bool:
	if lut_r == null or lut_g == null or lut_b == null:
		return false
	return RenderingServer.texture_get_rd_texture(lut_r.get_rid()).is_valid() and \
		RenderingServer.texture_get_rd_texture(lut_g.get_rid()).is_valid() and \
		RenderingServer.texture_get_rd_texture(lut_b.get_rid()).is_valid()

func _get_additional_uniforms() -> Array[RDUniform]:
	var uniforms: Array[RDUniform] = []
	if lut_r:
		var u := RDUniform.new()
		u.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
		u.binding = 1
		u.add_id(_get_sampler_rid())
		u.add_id(RenderingServer.texture_get_rd_texture(lut_r.get_rid()))
		uniforms.append(u)
	if lut_g:
		var u := RDUniform.new()
		u.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
		u.binding = 2
		u.add_id(_get_sampler_rid())
		u.add_id(RenderingServer.texture_get_rd_texture(lut_g.get_rid()))
		uniforms.append(u)
	if lut_b:
		var u := RDUniform.new()
		u.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
		u.binding = 3
		u.add_id(_get_sampler_rid())
		u.add_id(RenderingServer.texture_get_rd_texture(lut_b.get_rid()))
		uniforms.append(u)
	return uniforms

func _get_sampler_rid() -> RID:
	if not _sampler_rid.is_valid():
		var rd := RenderingServer.get_rendering_device()
		var state := RDSamplerState.new()
		state.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
		state.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
		_sampler_rid = rd.sampler_create(state)
	return _sampler_rid

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if _sampler_rid.is_valid():
			var rd := RenderingServer.get_rendering_device()
			if rd:
				rd.free_rid(_sampler_rid)
