@tool
class_name PixelateEffect
extends PostEffect

@export var block_size: int = 8

func _build_push_constant(screen_size: Vector2i, view: int) -> PackedFloat32Array:
	return PackedFloat32Array([
		float(screen_size.x),
		float(screen_size.y),
		float(view),
		float(block_size),
	])
