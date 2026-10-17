@tool
class_name ScanlineEffect
extends PostEffect

@export var line_count: int = 480
@export var intensity: float = 0.5
@export var smoothness: float = 0.5

func _build_push_constant(screen_size: Vector2i, view: int) -> PackedFloat32Array:
	return PackedFloat32Array([
		float(screen_size.x),
		float(screen_size.y),
		float(view),
		float(line_count),
		intensity,
		smoothness,
		0.0,
		0.0,
	])
