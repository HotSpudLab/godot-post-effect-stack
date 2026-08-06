@tool
class_name EffectStackResource
extends Resource

@export var effects: Array[PostEffectResource] = []

func get_enabled_effects() -> Array[PostEffectResource]:
	var result: Array[PostEffectResource] = []
	for e in effects:
		if e and e.enabled:
			result.append(e)
	return result
