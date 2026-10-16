@tool
extends RefCounted
## Shared editor appearance; values and input behavior stay with native controls.

static func prepare_slider(slider: HSlider) -> void:
	if slider.is_inside_tree():style_slider(slider)
	else:slider.ready.connect(style_slider.bind(slider),CONNECT_ONE_SHOT)

static func style_slider(slider: HSlider) -> void:
	var scale := EditorInterface.get_editor_scale() if Engine.is_editor_hint() else 1.0
	for item in ["slider","grabber_area","grabber_area_highlight"]:
		var style := slider.get_theme_stylebox(item).duplicate() as StyleBox
		style.content_margin_top=6.0*scale
		style.content_margin_bottom=6.0*scale
		if style is StyleBoxLine:style.thickness=roundi(12.0*scale)
		slider.add_theme_stylebox_override(item,style)
	for item in ["grabber","grabber_highlight","grabber_disabled"]:
		var texture := slider.get_theme_icon(item)
		if texture==null:continue
		var source := texture.get_image()
		if source==null or source.is_empty():continue
		# Theme textures may share image data. Never resize the shared source.
		var artwork := source.duplicate() as Image
		var height := maxi(1,roundi(22.0*scale))
		var width := maxi(1,roundi(height*float(artwork.get_width())/artwork.get_height()))
		artwork.resize(width,height,Image.INTERPOLATE_LANCZOS)
		slider.add_theme_icon_override(item,ImageTexture.create_from_image(artwork))
