@tool
class_name BasicAdjustEffect
extends PostEffect

## Direct image adjustments for look-building. Zero is the identity value.
@export_range(-1.0, 1.0, 0.01) var brightness: float = 0.0
@export_range(-1.0, 1.0, 0.01) var contrast: float = 0.0
@export_range(-180.0, 180.0, 1.0) var hue: float = 0.0
@export_range(-1.0, 1.0, 0.01) var saturation: float = 0.0

func _build_push_constant(screen_size: Vector2i, view: int) -> PackedFloat32Array:
	return PackedFloat32Array([
		float(screen_size.x),
		float(screen_size.y),
		float(view),
		0.0,
		brightness,
		contrast,
		hue,
		saturation,
	])
