@tool
class_name ChromaticAberrationEffect
extends PostEffectResource

@export var strength: float = 0.005
@export var radial: bool = true

func _build_push_constant(screen_size: Vector2i, view: int) -> PackedFloat32Array:
	return PackedFloat32Array([
		float(screen_size.x),
		float(screen_size.y),
		float(view),
		strength,
		float(radial),
		0.0,
		0.0,
		0.0,
	])
