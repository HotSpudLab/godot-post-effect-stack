extends Node3D

@export var grain_effect: GrainEffect

func _process(delta: float) -> void:
	if grain_effect:
		grain_effect.time += delta
