@tool
class_name ChromaticAberrationEffect
extends PostEffect

## Chromatic aberration.
##
## This effect samples pixels other than the one it writes, so it cannot read
## the colour buffer it runs on: neighbouring workgroups may already have
## overwritten the pixels it wants to read, which makes the output depend on
## execution order. It sets `needs_source_snapshot = true` and the runner binds
## a snapshot of the colour buffer at binding 1 for it to read instead.
##
## Until 2026-08-16 this effect built that snapshot itself through
## `_render_multi_pass()`, about 90 lines of texture allocation and pipeline
## management that any second effect of this kind would have had to copy.

@export var strength: float = 0.005
@export var radial: bool = true

func _init() -> void:
	needs_source_snapshot = true

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
