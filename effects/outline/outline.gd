@tool
class_name OutlineEffect
extends PostEffectResource

@export var line_width: float = 1.0
@export var line_color: Color = Color.BLACK
@export var depth_threshold: float = 0.1

func _init() -> void:
	needs_depth = true

func _build_push_constant(screen_size: Vector2i, view: int) -> PackedFloat32Array:
	return PackedFloat32Array([
		float(screen_size.x),
		float(screen_size.y),
		float(view),
		line_width,
		depth_threshold,
		line_color.r,
		line_color.g,
		line_color.b,
		0.0,
	])
