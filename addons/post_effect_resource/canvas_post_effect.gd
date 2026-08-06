extends CanvasLayer

@export var effect_material: Material

@onready var _rect: ColorRect = $ColorRect

func _ready() -> void:
	layer = 128
	if _rect == null:
		_rect = ColorRect.new()
		_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(_rect)
	_rect.material = effect_material
