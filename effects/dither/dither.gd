@tool
class_name DitherEffect
extends PostEffect

enum DitherPattern { BAYER_4X4, BAYER_8X8 }

@export var strength: float = 0.2
@export var pattern: DitherPattern = DitherPattern.BAYER_4X4

func _build_push_constant(screen_size: Vector2i, view: int) -> PackedFloat32Array:
	return PackedFloat32Array([
		float(screen_size.x),
		float(screen_size.y),
		float(view),
		strength,
		float(pattern),
		0.0,
	])
