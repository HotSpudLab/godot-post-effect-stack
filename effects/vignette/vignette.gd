@tool
class_name VignetteEffect
extends PostEffectResource

@export var intensity: float = 0.5
@export var smoothness: float = 0.3
@export var color: Color = Color.BLACK

func _build_push_constant(screen_size: Vector2i, view: int) -> PackedFloat32Array:
	return PackedFloat32Array([
		float(screen_size.x),
		float(screen_size.y),
		float(view),
		intensity,
		color.r,
		color.g,
		color.b,
		smoothness,
	])
