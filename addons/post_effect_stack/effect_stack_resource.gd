@tool
class_name EffectStackResource
extends Resource

@export var effects: Array[PostEffect] = []

func get_enabled_effects() -> Array[PostEffect]:
	var result: Array[PostEffect] = []
	for e in effects:
		if e and e.enabled:
			result.append(e)
	return result
