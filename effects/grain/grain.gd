@tool
class_name GrainEffect
extends PostEffectResource

@export var intensity: float = 0.3
@export var time: float = 0.0

func _build_push_constant(screen_size: Vector2i, view: int) -> PackedFloat32Array:
	return PackedFloat32Array([
		float(screen_size.x),
		float(screen_size.y),
		float(view),
		intensity,
		time,
		0.0,
	])
