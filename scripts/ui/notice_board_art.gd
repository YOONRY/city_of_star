extends RefCounted

const WOOD := preload("res://assets/vendor/notice_board/wood.png")
const PARCHMENT := preload("res://assets/vendor/notice_board/parchment.png")

var board: StyleBoxTexture
var note: StyleBoxTexture
var selected_note: StyleBoxTexture
var completed_note: StyleBoxTexture
var pin: Texture2D
var selected_pin: Texture2D
var completed_pin: Texture2D


func _init() -> void:
	board = _make_board()
	note = _make_paper(Color("#DED5C2"), Color("#B4A68D"), Color("#655143"))
	selected_note = _make_paper(Color("#E9E1D0"), Color("#A6ADA1"), Color("#415A55"))
	completed_note = _make_paper(Color("#CCD8C6"), Color("#91A38A"), Color("#405944"))
	pin = _make_pin(Color("#A15846"))
	selected_pin = _make_pin(Color("#376F69"))
	completed_pin = _make_pin(Color("#477653"), true)


func _make_board() -> StyleBoxTexture:
	var grain := WOOD.get_image()
	var pixels := Image.create_empty(224, 176, false, Image.FORMAT_RGBA8)
	pixels.fill(Color("#211A17"))
	pixels.fill_rect(Rect2i(2, 2, 220, 172), Color("#8B6C50"))
	pixels.fill_rect(Rect2i(4, 4, 216, 168), Color("#6B4D3D"))
	pixels.fill_rect(Rect2i(10, 10, 204, 156), Color("#52392E"))
	pixels.fill_rect(Rect2i(12, 12, 200, 152), Color("#342722"))

	# Keep the tile's grain low-contrast behind full-width plank seams.
	var plank_colors := [Color("#61493B"), Color("#574135"), Color("#665044")]
	for plank in plank_colors.size():
		var base: Color = plank_colors[plank]
		var shade := base.darkened(0.12)
		var top := 16 + 48 * plank
		for y in range(1, 45):
			for x in 192:
				var grain_x := floori((x + plank * 23) / 6.0) % grain.get_width()
				var grain_y := floori((y + plank * 9) / 3.0) % grain.get_height()
				var color := base if grain.get_pixel(grain_x, grain_y).r > 0.3 else shade
				pixels.set_pixel(16 + x, top + y, color)
		pixels.fill_rect(Rect2i(16, top, 192, 1), base.lightened(0.12))
		pixels.fill_rect(Rect2i(16, top + 45, 192, 3), Color("#3A2B24"))
		pixels.fill_rect(Rect2i(34 + plank * 29, top + 15, 44, 2), shade)
		pixels.fill_rect(Rect2i(97 - plank * 18, top + 33, 66, 1), shade)

	for corner in [Vector2i(7, 7), Vector2i(215, 7), Vector2i(7, 167), Vector2i(215, 167)]:
		pixels.fill_rect(Rect2i(corner, Vector2i(4, 4)), Color("#362A25"))
		pixels.fill_rect(Rect2i(corner, Vector2i(3, 2)), Color("#C6AA7B"))
	return _nine_slice(pixels, 16, 24, 22)


func _make_paper(base: Color, edge: Color, outline: Color) -> StyleBoxTexture:
	var pixels := PARCHMENT.get_image().get_region(Rect2i(48, 0, 48, 48))
	pixels.convert(Image.FORMAT_RGBA8)
	for y in pixels.get_height():
		for x in pixels.get_width():
			var source := pixels.get_pixel(x, y)
			if source.a == 0.0:
				continue
			var color := base if source.r > 0.9 else (edge if source.r > 0.5 else outline)
			pixels.set_pixel(x, y, color)
	for fiber in [Rect2i(13, 11, 2, 1), Rect2i(32, 18, 2, 1), Rect2i(22, 29, 1, 1), Rect2i(34, 36, 3, 1)]:
		pixels.fill_rect(fiber, base.lerp(outline, 0.07))
	pixels.resize(96, 96, Image.INTERPOLATE_NEAREST)
	return _nine_slice(pixels, 12, 16, 10)


func _make_pin(color: Color, completed: bool = false) -> Texture2D:
	var pixels := Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
	pixels.fill_rect(Rect2i(4, 2, 8, 12), Color("#43382F"))
	pixels.fill_rect(Rect2i(2, 4, 12, 8), Color("#43382F"))
	pixels.fill_rect(Rect2i(4, 4, 8, 8), color)
	if completed:
		pixels.fill_rect(Rect2i(4, 7, 2, 2), Color("#F0EBDD"))
		pixels.fill_rect(Rect2i(6, 9, 2, 2), Color("#F0EBDD"))
		pixels.fill_rect(Rect2i(8, 7, 2, 2), Color("#F0EBDD"))
		pixels.fill_rect(Rect2i(10, 5, 2, 2), Color("#F0EBDD"))
	else:
		pixels.fill_rect(Rect2i(5, 5, 4, 2), color.lightened(0.48))
	return ImageTexture.create_from_image(pixels)


func _nine_slice(pixels: Image, margin: int, horizontal_padding: int, vertical_padding: int) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = ImageTexture.create_from_image(pixels)
	style.set_texture_margin_all(margin)
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	style.content_margin_left = horizontal_padding
	style.content_margin_right = horizontal_padding
	style.content_margin_top = vertical_padding
	style.content_margin_bottom = vertical_padding
	return style
