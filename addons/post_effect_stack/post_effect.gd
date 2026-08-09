@tool
class_name PostEffect
extends Resource

@export var shader_file: RDShaderFile
@export var effect_callback_type: CompositorEffect.EffectCallbackType = CompositorEffect.EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
@export var needs_depth: bool = false
@export var needs_normal_roughness: bool = false
@export var enabled: bool = true

@export var parameters: Dictionary = {}

func _build_push_constant(screen_size: Vector2i, view: int) -> PackedFloat32Array:
	return PackedFloat32Array([
		float(screen_size.x),
		float(screen_size.y),
		float(view),
		0.0,
	])

func _get_additional_uniforms() -> Array[RDUniform]:
	return []

func _is_ready() -> bool:
	return true

var _is_multi_pass: bool = false

func _render_multi_pass(p_rd: RenderingDevice, p_runner: Object, p_render_scene_buffers: RenderSceneBuffers, p_view: int, p_size: Vector2i, p_color_image: RID) -> void:
	pass
